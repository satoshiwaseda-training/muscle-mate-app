"""
ワークアウトプラン生成 ルーター
"""
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field
from src.schemas.workout import WorkoutRequest, WorkoutResponse
from src.services.gemini_service import generate_workout_plan
from src.services.entertainment_service import build_entertainment_result

router = APIRouter(prefix="/workout", tags=["workout"])


@router.post("/generate", response_model=WorkoutResponse)
async def generate(req: WorkoutRequest) -> WorkoutResponse:
    result = await generate_workout_plan(req)
    if not result.success:
        raise HTTPException(status_code=500, detail=result.error_message)
    return result


class EntertainmentRequest(BaseModel):
    total_kg: float = Field(..., ge=0, description="セッションの総挙上重量 (kg)")


@router.post("/entertainment")
async def entertainment(req: EntertainmentRequest) -> dict:
    """総挙上重量をエンタメ変換して返す"""
    return build_entertainment_result(req.total_kg)
