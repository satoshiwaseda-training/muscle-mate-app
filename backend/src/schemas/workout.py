"""
筋トレメニューの厳密なJSONスキーマ定義 (Pydantic v2)
AIの解析ミスを防ぐための「契約書」
FastAPI ↔ Flutter 間の共通フォーマット
"""
from __future__ import annotations

from enum import Enum
from typing import List, Optional
from pydantic import BaseModel, Field, field_validator


# ── Enums: 許可される値を列挙 ────────────────────────────────────────────────

class Goal(str, Enum):
    MUSCLE_GAIN   = "muscle_gain"    # 筋肥大
    WEIGHT_LOSS   = "weight_loss"    # 減量
    ENDURANCE     = "endurance"      # 持久力
    GENERAL       = "general_fitness" # 総合体力


class Level(str, Enum):
    BEGINNER     = "beginner"
    INTERMEDIATE = "intermediate"
    ADVANCED     = "advanced"


class Equipment(str, Enum):
    BARBELL    = "barbell"
    DUMBBELL   = "dumbbell"
    MACHINE    = "machine"
    BODYWEIGHT = "bodyweight"
    CABLE      = "cable"
    KETTLEBELL = "kettlebell"


class DayOfWeek(str, Enum):
    MONDAY    = "monday"
    TUESDAY   = "tuesday"
    WEDNESDAY = "wednesday"
    THURSDAY  = "thursday"
    FRIDAY    = "friday"
    SATURDAY  = "saturday"
    SUNDAY    = "sunday"


class MuscleGroup(str, Enum):
    CHEST      = "chest"
    BACK       = "back"
    SHOULDERS  = "shoulders"
    BICEPS     = "biceps"
    TRICEPS    = "triceps"
    LEGS       = "legs"
    QUADS      = "quads"
    HAMSTRINGS = "hamstrings"
    GLUTES     = "glutes"
    CALVES     = "calves"
    CORE       = "core"
    FULL_BODY  = "full_body"


# ── リクエスト: Flutter → FastAPI ────────────────────────────────────────────

class WorkoutRequest(BaseModel):
    """ユーザーが入力する情報"""
    goal: Goal = Field(..., description="トレーニング目標")
    level: Level = Field(..., description="トレーニングレベル")
    days_per_week: int = Field(..., ge=1, le=7, description="週のトレーニング日数")
    equipment: List[Equipment] = Field(..., min_length=1, description="使用可能な器具")
    age: Optional[int] = Field(None, ge=10, le=100, description="年齢")
    notes: Optional[str] = Field(None, max_length=500, description="特記事項（怪我など）")

    @field_validator("equipment")
    @classmethod
    def no_duplicate_equipment(cls, v: List[Equipment]) -> List[Equipment]:
        if len(v) != len(set(v)):
            raise ValueError("器具に重複があります")
        return v


# ── レスポンス内部モデル ─────────────────────────────────────────────────────

class Exercise(BaseModel):
    """1種目の定義"""
    name_ja: str = Field(..., description="種目名（日本語）", examples=["ベンチプレス"])
    name_en: str = Field(..., description="種目名（英語）", examples=["Bench Press"])
    sets: int = Field(..., ge=1, le=10, description="セット数")
    reps: str = Field(..., description="レップ数または秒数", examples=["8-12", "30秒"])
    rest_seconds: int = Field(..., ge=0, le=600, description="インターバル（秒）")
    equipment: Equipment = Field(..., description="使用器具")
    target_muscles: List[MuscleGroup] = Field(..., min_length=1, description="主動筋")
    coaching_point: str = Field(..., description="フォームのコツ・注意点")


class DaySession(BaseModel):
    """1日のセッション"""
    day_of_week: DayOfWeek = Field(..., description="曜日")
    session_name: str = Field(..., description="セッション名", examples=["胸・肩・三頭筋"])
    target_muscles: List[MuscleGroup] = Field(..., description="その日のターゲット筋群")
    estimated_duration_minutes: int = Field(..., ge=10, le=180, description="想定所要時間（分）")
    exercises: List[Exercise] = Field(..., min_length=1, description="種目リスト")

    @field_validator("exercises")
    @classmethod
    def max_exercises(cls, v: List[Exercise]) -> List[Exercise]:
        if len(v) > 12:
            raise ValueError("1セッションの種目数は12以内にしてください")
        return v


class WorkoutPlan(BaseModel):
    """週間ワークアウトプラン"""
    plan_name: str = Field(..., description="プラン名")
    duration_weeks: int = Field(..., ge=1, le=52, description="推奨実施期間（週）")
    weekly_schedule: List[DaySession] = Field(..., min_length=1, description="週間スケジュール")
    general_advice: str = Field(..., description="食事・休養などの総合アドバイス")


# ── レスポンス: FastAPI → Flutter ────────────────────────────────────────────

class WorkoutResponse(BaseModel):
    """APIレスポンスのルート"""
    success: bool = Field(..., description="処理成功フラグ")
    plan: Optional[WorkoutPlan] = Field(None, description="生成されたプラン")
    error_message: Optional[str] = Field(None, description="エラー詳細（successがfalseの時）")


# ── Gemini に渡す JSON スキーマ文字列（AIへの指示用）─────────────────────────

GEMINI_JSON_SCHEMA = """
{
  "plan_name": "string",
  "duration_weeks": integer,
  "weekly_schedule": [
    {
      "day_of_week": "monday|tuesday|wednesday|thursday|friday|saturday|sunday",
      "session_name": "string",
      "target_muscles": ["chest|back|shoulders|biceps|triceps|legs|quads|hamstrings|glutes|calves|core|full_body"],
      "estimated_duration_minutes": integer,
      "exercises": [
        {
          "name_ja": "string",
          "name_en": "string",
          "sets": integer,
          "reps": "string",
          "rest_seconds": integer,
          "equipment": "barbell|dumbbell|machine|bodyweight|cable|kettlebell",
          "target_muscles": ["muscle_group"],
          "coaching_point": "string"
        }
      ]
    }
  ],
  "general_advice": "string"
}
"""
