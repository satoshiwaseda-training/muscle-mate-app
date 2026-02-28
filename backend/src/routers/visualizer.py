"""
筋肉ヒートマップ ビジュアライザー ルーター
─────────────────────────────────────────────────────────────
エンドポイント:
  POST /visualizer/heatmap
    → BIG3 実績からヒートマップ強度データを返す（Blender不要）

  POST /visualizer/render
    → Blender ヘッドレスレンダリングをバックグラウンドで実行
      Blender 未インストール時は 503 を返す

  GET  /visualizer/render/{job_id}
    → レンダリング済み画像を返す（PNG）
"""
from __future__ import annotations

import asyncio
from pathlib import Path
from typing import Optional

from fastapi import APIRouter, BackgroundTasks, HTTPException
from fastapi.responses import FileResponse
from pydantic import BaseModel, Field

from src.services.blender_sync_service import (
    Big3Progress,
    HeatmapData,
    blender_sync_service,
)

router = APIRouter(prefix="/visualizer", tags=["visualizer"])

# レンダリングジョブのキャッシュ（メモリ上、再起動でリセット）
_render_jobs: dict[str, HeatmapData] = {}


# ── リクエスト / レスポンス スキーマ ─────────────────────────────────────

class HeatmapRequest(BaseModel):
    """BIG3の現在値と目標値"""
    bench_current:    Optional[float] = Field(None, ge=0, le=500, description="ベンチプレス現在値 (kg)")
    bench_goal:       Optional[float] = Field(None, ge=0, le=500, description="ベンチプレス目標値 (kg)")
    squat_current:    Optional[float] = Field(None, ge=0, le=500, description="スクワット現在値 (kg)")
    squat_goal:       Optional[float] = Field(None, ge=0, le=500, description="スクワット目標値 (kg)")
    deadlift_current: Optional[float] = Field(None, ge=0, le=500, description="デッドリフト現在値 (kg)")
    deadlift_goal:    Optional[float] = Field(None, ge=0, le=500, description="デッドリフト目標値 (kg)")


class HeatmapResponse(BaseModel):
    """ヒートマップ強度データ（Flutter 向け）"""
    job_id:      str
    intensities: dict[str, float]
    progress_pct: dict[str, float]
    blender_available: bool
    render_status: str  # "none" | "queued" | "done" | "error"


# ── エンドポイント ────────────────────────────────────────────────────────

@router.post("/heatmap", response_model=HeatmapResponse)
async def get_heatmap(req: HeatmapRequest) -> HeatmapResponse:
    """
    BIG3 の現在値/目標値から筋肉強度データを計算して返す。
    Blender 不要。Flutter の MuscleVisualizer に直接渡せる形式。

    例) サトシさん: bench_current=115, bench_goal=120
    → chest 強度 ≈ 0.92 (高い), quads 強度 ≈ 0.58 など
    """
    progress = Big3Progress(
        bench_current=req.bench_current,
        bench_goal=req.bench_goal,
        squat_current=req.squat_current,
        squat_goal=req.squat_goal,
        deadlift_current=req.deadlift_current,
        deadlift_goal=req.deadlift_goal,
    )
    heatmap = blender_sync_service.calc_heatmap(progress)
    _render_jobs[heatmap.job_id] = heatmap

    return HeatmapResponse(
        job_id=heatmap.job_id,
        intensities=heatmap.intensities.to_dict(),
        progress_pct=heatmap.progress_pct,
        blender_available=heatmap.blender_available,
        render_status="none",
    )


@router.post("/render", response_model=HeatmapResponse)
async def trigger_render(
    req: HeatmapRequest,
    background_tasks: BackgroundTasks,
) -> HeatmapResponse:
    """
    Blender ヘッドレスレンダリングをトリガーする。
    Blender がインストールされていない場合は 503 を返す。
    レンダリングは非同期で実行される（完了後 GET /render/{job_id} で画像取得）。
    """
    if not blender_sync_service.blender_available:
        raise HTTPException(
            status_code=503,
            detail=(
                "Blender が見つかりません。"
                "https://www.blender.org/download/ からインストールし、"
                "PATH に追加してバックエンドを再起動してください。"
                "（強度データは /heatmap エンドポイントで常に取得できます）"
            ),
        )

    progress = Big3Progress(
        bench_current=req.bench_current,
        bench_goal=req.bench_goal,
        squat_current=req.squat_current,
        squat_goal=req.squat_goal,
        deadlift_current=req.deadlift_current,
        deadlift_goal=req.deadlift_goal,
    )
    heatmap = blender_sync_service.calc_heatmap(progress)
    heatmap.render_path = "queued"
    _render_jobs[heatmap.job_id] = heatmap

    async def _do_render(hm: HeatmapData):
        try:
            updated = await blender_sync_service.render_async(hm)
            _render_jobs[updated.job_id] = updated
        except Exception as e:
            hm.render_path = f"error: {e}"
            _render_jobs[hm.job_id] = hm

    background_tasks.add_task(_do_render, heatmap)

    return HeatmapResponse(
        job_id=heatmap.job_id,
        intensities=heatmap.intensities.to_dict(),
        progress_pct=heatmap.progress_pct,
        blender_available=True,
        render_status="queued",
    )


@router.get("/render/{job_id}")
async def get_render_result(job_id: str):
    """
    レンダリング済み画像を PNG で返す。
    - 未完了: 202 Accepted + JSON status
    - 完了:   200 + PNG image
    - エラー: 500
    """
    heatmap = _render_jobs.get(job_id)
    if heatmap is None:
        raise HTTPException(status_code=404, detail=f"job_id '{job_id}' が見つかりません")

    if heatmap.render_path is None or heatmap.render_path == "queued":
        return {"status": "queued", "job_id": job_id}

    if heatmap.render_path.startswith("error:"):
        raise HTTPException(status_code=500, detail=heatmap.render_path)

    path = Path(heatmap.render_path)
    if not path.exists():
        raise HTTPException(status_code=404, detail="レンダリング画像が見つかりません")

    return FileResponse(
        path=str(path),
        media_type="image/png",
        filename=f"muscle_heatmap_{job_id}.png",
    )
