"""
セッションログスキーマ（計画書 v5 §6.5 / §6.6）

重要:
- user_id を持たない（v3 でステートレス化）
- サーバー側では永続化しない（FastAPI ハンドラ内のメモリのみ）
- /workout/next 経路では外部 AI を呼ばない（v5 §4.4 / §6.3）
"""
from __future__ import annotations

from datetime import date
from typing import List, Optional
from pydantic import BaseModel, Field

from src.schemas.workout import MuscleGroup


class SetLog(BaseModel):
    """1 セットの実施記録"""
    weight_kg: float = Field(..., ge=0, le=1000, description="実施重量 (kg)")
    reps: int = Field(..., ge=0, le=200, description="実施レップ数")
    rpe: Optional[float] = Field(None, ge=1, le=10, description="主観的運動強度 1-10")
    pain: bool = Field(False, description="このセットで痛みが出たか")
    pain_region: Optional[MuscleGroup] = Field(
        None, description="痛みが出た部位（pain=true 時のみ意味を持つ）"
    )


class ExerciseLog(BaseModel):
    """1 種目分の実施記録"""
    name_ja: str = Field(..., description="種目名（日本語）")
    name_en: str = Field(..., description="種目名（英語）")
    sets: List[SetLog] = Field(..., min_length=1, description="セットごとの記録")


class SessionLog(BaseModel):
    """1 セッションの実施記録。

    ※ user_id を意図的に持たない（計画書 §6.5）。
    端末から都度送信され、サーバー側では永続保存されない（§11.4）。
    """
    session_date: date = Field(..., description="セッション実施日")
    session_name: Optional[str] = Field(None, description="セッション名（例: 'Upper'）")
    exercise_logs: List[ExerciseLog] = Field(..., min_length=1, description="種目別ログ")

    def has_any_pain(self) -> bool:
        """痛み報告が含まれているか（外部 AI 自動スキップ判定に使用）"""
        return any(s.pain for el in self.exercise_logs for s in el.sets)

    def max_rpe(self) -> Optional[float]:
        """セッション全体の最大 RPE"""
        rpes = [s.rpe for el in self.exercise_logs for s in el.sets if s.rpe is not None]
        return max(rpes) if rpes else None


# ── リクエスト: Flutter → FastAPI ────────────────────────────────────────────

class NextWorkoutRequest(BaseModel):
    """次回メニュー最適化のリクエスト。

    Flutter から直近の SessionLog を渡す。サーバーは保存しない。
    """
    last_session: SessionLog = Field(..., description="直前セッションの実施ログ")
    next_day_of_week: Optional[str] = Field(
        None, description="次に生成したい曜日（指定なしの場合はサーバーで決定）"
    )
    # WorkoutRequest と同じく目標・レベル等の文脈を渡せるが、ここでは
    # 「直近ログから次回を最適化する」用途に絞り、最小情報のみとする。
