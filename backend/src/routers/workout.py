"""
ワークアウトプラン生成 ルーター
"""
from fastapi import APIRouter, HTTPException
from src.schemas.workout import WorkoutRequest, WorkoutResponse
from src.services.gemini_service import generate_workout_plan

router = APIRouter(prefix="/workout", tags=["workout"])


@router.post("/generate", response_model=WorkoutResponse)
async def generate(req: WorkoutRequest) -> WorkoutResponse:
    """
    ユーザー情報を受け取り、Gemini でワークアウトプランを生成して返す。
    """
    result = await generate_workout_plan(req)
    if not result.success:
        raise HTTPException(status_code=500, detail=result.error_message)
    return result
