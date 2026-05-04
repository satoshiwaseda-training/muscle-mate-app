"""
ワークアウトプラン生成 ルーター（計画書 v5 §6.2 §4.2）

- POST /workout/generate: ルールベースで初回／週間プランを生成
- POST /workout/next: 直前 SessionLog から次回推奨を返す（**外部 AI を呼ばない**）
- POST /workout/entertainment: 既存維持（総挙上重量 → エンタメ変換）

すべてのエンドポイントは匿名・ステートレス（user_id を扱わない）。
リクエスト本文をログ・APM・DB・キャッシュに書き出さない（§11.4）。
"""
from __future__ import annotations

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

from typing import Optional
from src.schemas.workout import WorkoutRequest, WorkoutResponse, Advisory, AdvisoryLevel
from src.schemas.log import NextWorkoutRequest, SessionLog
from src.schemas.advice import AdviceResponse
from src.services.rule_engine_service import build_workout_response
from src.services.progression_service import analyze_progression
from src.services.advice_service import build_advice_response
from src.services.entertainment_service import build_entertainment_result


class AdviceRequest(BaseModel):
    """advice エンドポイントのリクエスト。WorkoutRequest を内包し、session_log は任意。"""
    request: WorkoutRequest
    last_session: Optional[SessionLog] = None

router = APIRouter(prefix="/workout", tags=["workout"])


# ── /workout/generate ───────────────────────────────────────────────────────

@router.post("/generate", response_model=WorkoutResponse)
async def generate(req: WorkoutRequest) -> WorkoutResponse:
    """ルールベースで週間プランを生成する。

    外部 AI は呼ばない（v5 既定）。フェーズ 4 で llm_service が導入された後でも、
    ヘッダ X-External-AI-Optin と環境変数 LLM_PROVIDER の AND 条件で初めて有効化される。
    """
    response = build_workout_response(req)
    if not response.success:
        # 入力値はエラーメッセージに含めない（§11.4）
        raise HTTPException(
            status_code=500,
            detail=response.error_message or "ルールエンジンでエラーが発生しました",
        )
    return response


# ── /workout/next ───────────────────────────────────────────────────────────

class NextWorkoutResponse(BaseModel):
    success: bool
    safety_flags: list[str] = []
    advisory: Advisory = Advisory(level=AdvisoryLevel.NONE)
    recommendations: dict = {}
    external_ai_used: bool = False  # 常に False（v5 §6.3）
    error_message: str | None = None


@router.post("/next", response_model=NextWorkoutResponse)
async def next_workout(req: NextWorkoutRequest) -> NextWorkoutResponse:
    """直前 SessionLog から次回への推奨を返す。

    本エンドポイントは外部 AI を**呼ばない**（計画書 v5 §6.3）。
    SessionLog 自体が痛み・RPE・実施重量を含むセンシティブ情報のため、
    allowlist が 6 フィールドであっても外部送信を行わない。
    """
    try:
        safety_flags, advisory, recommendations = analyze_progression(req.last_session)
        return NextWorkoutResponse(
            success=True,
            safety_flags=safety_flags,
            advisory=advisory,
            recommendations=recommendations,
            external_ai_used=False,
        )
    except Exception as e:
        return NextWorkoutResponse(
            success=False,
            error_message=f"プログレッション解析でエラーが発生しました: {type(e).__name__}",
        )


# ── /workout/advice ─────────────────────────────────────────────────────────

@router.post("/advice", response_model=AdviceResponse)
async def advice(req: WorkoutRequest) -> AdviceResponse:
    """Personalized advice cards. Pure rule-based. No external AI."""
    return build_advice_response(req)


@router.post("/advice/with-session", response_model=AdviceResponse)
async def advice_with_session(req: AdviceRequest) -> AdviceResponse:
    return build_advice_response(req.request, session_log=req.last_session)
