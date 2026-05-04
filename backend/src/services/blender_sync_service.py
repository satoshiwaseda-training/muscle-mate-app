"""
Blender 同期サービス
─────────────────────────────────────────────────────────────
【役割】
1. ユーザーの1RM実績データから、各筋肉部位の「活性化強度」(0.0〜1.0) を算出
2. Blender Python スクリプト (muscle_heatmap.blend.py) を動的に生成
3. Blender をヘッドレスモードで起動してレンダリング
   - Blender 未インストール時は強度データ(JSON)のみ返す

【アーキテクチャ】
  WorkoutRecord (Flutter) → FastAPI → blender_sync_service → Blender (任意)
                                              ↓
                                    HeatmapData (JSON)  ← Flutter で直接描画可
                                    rendered_image.png  ← Blender がある場合

【使用方法】
  service = BlenderSyncService()
  heatmap = service.calc_heatmap(big3_current, big3_goal)
  result  = await service.render_async(heatmap, output_path)
"""
from __future__ import annotations

import asyncio
import json
import os
import shutil
import subprocess
import tempfile
import uuid
from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional

# Blender 実行ファイルのパス候補（OS別）
_BLENDER_CANDIDATES = [
    r"C:\Program Files\Blender Foundation\Blender 5.0\blender.exe",
    r"C:\Program Files\Blender Foundation\Blender 4.4\blender.exe",
    r"C:\Program Files\Blender Foundation\Blender 4.3\blender.exe",
    r"C:\Program Files\Blender Foundation\Blender 4.2\blender.exe",
    r"C:\Program Files\Blender Foundation\Blender 4.1\blender.exe",
    r"C:\Program Files\Blender Foundation\Blender 4.0\blender.exe",
    r"C:\Program Files\Blender Foundation\Blender\blender.exe",
    "/usr/bin/blender",
    "/usr/local/bin/blender",
    "/Applications/Blender.app/Contents/MacOS/Blender",
]

BLENDER_SCRIPT = Path(__file__).parent.parent.parent / "scripts" / "muscle_heatmap.blend.py"
RENDER_OUTPUT_DIR = Path(__file__).parent.parent.parent / "renders"


# ── データクラス ────────────────────────────────────────────────────────────

@dataclass
class MuscleIntensity:
    """各筋肉部位の強度データ (0.0 = 未使用, 1.0 = 最大活性)"""
    chest:      float = 0.0
    back:       float = 0.0
    shoulders:  float = 0.0
    biceps:     float = 0.0
    triceps:    float = 0.0
    quads:      float = 0.0
    hamstrings: float = 0.0
    glutes:     float = 0.0
    calves:     float = 0.0
    core:       float = 0.0

    def to_dict(self) -> dict[str, float]:
        return {
            "chest":      self.chest,
            "back":       self.back,
            "shoulders":  self.shoulders,
            "biceps":     self.biceps,
            "triceps":    self.triceps,
            "quads":      self.quads,
            "hamstrings": self.hamstrings,
            "glutes":     self.glutes,
            "calves":     self.calves,
            "core":       self.core,
        }

    def clamp(self) -> "MuscleIntensity":
        """全値を 0.0〜1.0 にクランプ"""
        return MuscleIntensity(**{k: max(0.0, min(1.0, v)) for k, v in self.to_dict().items()})


@dataclass
class Big3Progress:
    """BIG3の現在値と目標値"""
    bench_current:    Optional[float] = None  # kg
    bench_goal:       Optional[float] = None
    squat_current:    Optional[float] = None
    squat_goal:       Optional[float] = None
    deadlift_current: Optional[float] = None
    deadlift_goal:    Optional[float] = None


@dataclass
class HeatmapData:
    """Flutter / Blender に渡すヒートマップデータ"""
    job_id:          str
    intensities:     MuscleIntensity
    progress_pct:    dict[str, float]    # {"bench": 0.85, ...} 目標達成率
    render_path:     Optional[str] = None  # Blender レンダリング済み画像パス
    blender_available: bool = False


# ── 種目→筋肉寄与度テーブル ────────────────────────────────────────────────

# BIG3 各種目が各筋肉に与える寄与度 (合計は 1.0 前後、正規化しない)
_BIG3_CONTRIBUTION: dict[str, dict[str, float]] = {
    "bench_press": {
        "chest":     0.70,
        "shoulders": 0.20,
        "triceps":   0.20,
        "core":      0.05,
    },
    "squat": {
        "quads":     0.60,
        "glutes":    0.35,
        "hamstrings":0.20,
        "core":      0.25,
        "back":      0.15,
    },
    "deadlift": {
        "back":      0.55,
        "glutes":    0.40,
        "hamstrings":0.35,
        "quads":     0.25,
        "core":      0.20,
        "biceps":    0.10,
        "calves":    0.10,
    },
}


def _progress_ratio(current: Optional[float], goal: Optional[float]) -> float:
    """目標達成率 (0.0〜1.0)。goalが未設定なら currentを最大の80%とみなす"""
    if current is None:
        return 0.0
    if goal is None or goal <= 0:
        return 0.8  # 目標未設定 → 中程度の強度
    return min(1.0, current / goal)


class BlenderSyncService:
    """
    筋トレ実績 ↔ Blender を橋渡しするサービス。
    Blender が未インストールでも強度データ(JSON)は常に返す。
    """

    def __init__(self):
        self._blender_exe = self._find_blender()
        RENDER_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    # ── Public API ──────────────────────────────────────────────────────────

    def calc_heatmap(self, progress: Big3Progress) -> HeatmapData:
        """
        BIG3の進捗から筋肉部位ごとの強度を計算して HeatmapData を返す。
        Blenderレンダリングは行わない（軽量・同期）。
        """
        ratios = {
            "bench_press": _progress_ratio(progress.bench_current, progress.bench_goal),
            "squat":       _progress_ratio(progress.squat_current, progress.squat_goal),
            "deadlift":    _progress_ratio(progress.deadlift_current, progress.deadlift_goal),
        }

        # 各筋肉の強度 = Σ(種目寄与度 × 達成率)
        intensities: dict[str, float] = {m: 0.0 for m in MuscleIntensity.__dataclass_fields__}
        for exercise, ratio in ratios.items():
            for muscle, contribution in _BIG3_CONTRIBUTION[exercise].items():
                intensities[muscle] = intensities.get(muscle, 0.0) + contribution * ratio

        # 最大値で正規化（最も鍛えた部位が 1.0 になる）
        max_val = max(intensities.values()) or 1.0
        normalized = {m: v / max_val for m, v in intensities.items()}

        progress_pct = {
            "bench":    ratios["bench_press"],
            "squat":    ratios["squat"],
            "deadlift": ratios["deadlift"],
        }

        return HeatmapData(
            job_id=str(uuid.uuid4()),
            intensities=MuscleIntensity(**normalized).clamp(),
            progress_pct=progress_pct,
            blender_available=self._blender_exe is not None,
        )

    async def render_async(
        self,
        heatmap: HeatmapData,
        resolution: tuple[int, int] = (512, 1024),
    ) -> HeatmapData:
        """
        Blender をヘッドレスモードで起動してレンダリングする（非同期）。
        Blender が未インストールの場合は heatmap をそのまま返す。
        """
        if self._blender_exe is None:
            return heatmap

        output_path = RENDER_OUTPUT_DIR / f"{heatmap.job_id}.png"

        # 強度データを一時 JSON ファイルに書き出す（Blenderスクリプトが読み込む）
        with tempfile.NamedTemporaryFile(
            mode="w", suffix=".json", delete=False, encoding="utf-8"
        ) as f:
            json.dump(
                {
                    "intensities": heatmap.intensities.to_dict(),
                    "output_path": str(output_path),
                    "resolution_x": resolution[0],
                    "resolution_y": resolution[1],
                },
                f,
                ensure_ascii=False,
            )
            tmp_json = f.name

        try:
            cmd = [
                self._blender_exe,
                "--background",               # GUIなし
                "--python", str(BLENDER_SCRIPT),
                "--",                          # Blender引数の終端、以降がスクリプト引数
                tmp_json,
            ]
            proc = await asyncio.create_subprocess_exec(
                *cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
            )
            stdout, stderr = await asyncio.wait_for(proc.communicate(), timeout=120)

            if proc.returncode != 0:
                raise RuntimeError(
                    f"Blender レンダリング失敗 (exit {proc.returncode}):\n"
                    f"{stderr.decode(errors='replace')}"
                )

            heatmap.render_path = str(output_path)
        finally:
            os.unlink(tmp_json)

        return heatmap

    @property
    def blender_available(self) -> bool:
        return self._blender_exe is not None

    # ── Internal ────────────────────────────────────────────────────────────

    @staticmethod
    def _find_blender() -> Optional[str]:
        """OS上のBlenderを自動探索。見つからなければ None。"""
        # PATH から検索
        found = shutil.which("blender")
        if found:
            return found
        # 固定パス候補を確認
        for candidate in _BLENDER_CANDIDATES:
            if Path(candidate).exists():
                return candidate
        return None


# ── サービスのシングルトン ───────────────────────────────────────────────────
blender_sync_service = BlenderSyncService()
