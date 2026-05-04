"""
筋トレメニューの厳密なJSONスキーマ定義 (Pydantic v2)
計画書 v5 に準拠。

- v5 で追加: WorkoutResponse の拡張（advisory / safety_flags / external_ai_used）
- v5 で追加: WorkoutRequest の任意フィールド（gender, body_weight_kg, years_of_training,
             injury_history, priority_lift）
- v5 で追加: Exercise の evidence_refs / safety_flags / progression_rule
- 外部 AI 送信ホワイトリスト（6 フィールドのみ）は llm_service.AllowlistedLLMPayload で
  別途強制（extra="forbid"）。本ファイルでは API 入出力を定義する。
"""
from __future__ import annotations

from datetime import date
from enum import Enum
from typing import List, Optional
from pydantic import BaseModel, ConfigDict, Field, field_validator


# ── Enums: 許可される値を列挙 ────────────────────────────────────────────────

class Goal(str, Enum):
    MUSCLE_GAIN   = "muscle_gain"     # 筋肥大
    WEIGHT_LOSS   = "weight_loss"     # 減量
    ENDURANCE     = "endurance"       # 持久力
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
    LOWER_BACK = "lower_back"
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


class Gender(str, Enum):
    MALE   = "male"
    FEMALE = "female"
    OTHER  = "other"
    PREFER_NOT_TO_SAY = "prefer_not_to_say"


class PriorityLift(str, Enum):
    NONE     = "none"
    BENCH    = "bench"
    SQUAT    = "squat"
    DEADLIFT = "deadlift"


class InjurySeverity(str, Enum):
    MILD     = "mild"
    MODERATE = "moderate"
    SEVERE   = "severe"


class AdvisoryLevel(str, Enum):
    """v5 §6.4 で追加: レスポンスのアクション強度"""
    NONE            = "none"
    PARTIAL_SKIP    = "partial_skip"     # 該当部位の種目だけ除外
    REST_OR_CONSULT = "rest_or_consult"  # 当日中止＋専門家相談
    DELOAD          = "deload"           # 強制デロード提案


# ── リクエスト: Flutter → FastAPI ────────────────────────────────────────────

class Big3Max(BaseModel):
    """BIG3の現在のMAX重量（kg）。外部 AI には送信しない（計画書 §7）。"""
    bench_press_max: Optional[float] = Field(None, ge=0, le=500, description="ベンチプレス MAX (kg)")
    squat_max: Optional[float] = Field(None, ge=0, le=500, description="スクワット MAX (kg)")
    deadlift_max: Optional[float] = Field(None, ge=0, le=500, description="デッドリフト MAX (kg)")

    def has_any(self) -> bool:
        return any([self.bench_press_max, self.squat_max, self.deadlift_max])


class Injury(BaseModel):
    """怪我履歴。Sensitive Info として扱い、外部 AI には送信しない（計画書 §7）。"""
    region: MuscleGroup = Field(..., description="部位")
    severity: InjurySeverity = Field(..., description="重症度")
    note: Optional[str] = Field(None, max_length=200, description="補足（任意）")


class RecentHistorySummary(BaseModel):
    """過去 30 日のトレーニング記録サマリ。

    端末内 SQLite から生成されてリクエスト時のみサーバーへ送信される。
    サーバー側は永続化せず、メニュー生成のヒントとしてのみ参照する。
    個別レコードの内容（重量・レップ等）は送信しない（集計値のみ）。

    根拠論文との対応:
        - sessions_last_7_days / muscles_unworked_14d
            → Currier 2023 BJSM (週 2-3 回 / 筋群が最適、頻度より週ボリューム重視)
        - last_session_days_ago
            → Buresh 2009 (セッション間 48h 休養)
        - recent_muscle_focus_7d
            → Currier 2023 + 一般原則 (同一筋群連続を避ける)
        - pain_reports_last_7d
            → 安全側ガード（injury_history と多重防御）
    """
    last_session_days_ago: Optional[int] = Field(
        None, ge=0, description="直近セッションからの経過日数（記録ゼロなら None）"
    )
    sessions_last_7_days: int = Field(
        0, ge=0, le=14, description="過去 7 日のセッション数"
    )
    sessions_last_30_days: int = Field(
        0, ge=0, le=60, description="過去 30 日のセッション数"
    )
    avg_weekly_volume_kg_30d: float = Field(
        0.0, ge=0, description="過去 30 日の平均週ボリューム (kg・全種目合計)"
    )
    recent_muscle_focus_7d: dict[str, int] = Field(
        default_factory=dict,
        description="過去 7 日に各筋群を鍛えた回数 例: {'chest': 3, 'back': 1}",
    )
    muscles_unworked_14d: List[str] = Field(
        default_factory=list,
        description="過去 14 日間 1 度も鍛えていない筋群 例: ['back', 'shoulders']",
    )
    streak_days: int = Field(
        0, ge=0, description="連続記録日数"
    )
    pain_reports_last_7d: dict[str, int] = Field(
        default_factory=dict,
        description="過去 7 日の痛み報告（部位別件数） 例: {'knee': 2}",
    )
    top_exercises_30d: List[str] = Field(
        default_factory=list, max_length=10,
        description="過去 30 日で実施回数が多い種目名（最大 10）",
    )


class WorkoutRequest(BaseModel):
    """ユーザーが入力する情報。永続保存しない（計画書 §11.4）。"""
    goal: Goal = Field(..., description="トレーニング目標")
    level: Level = Field(..., description="トレーニングレベル")
    days_per_week: int = Field(1, ge=1, le=7, description="セッション数（デフォルト1）")
    session_duration_minutes: int = Field(60, ge=10, le=240, description="1セッションの予定時間（分）")
    equipment: List[Equipment] = Field(..., min_length=1, description="使用可能な器具")
    target_muscles: Optional[List[MuscleGroup]] = Field(
        None, description="今日のターゲット筋群（指定しない場合は全身）。**外部 AI 送信時は自動スキップ条件**（§4.4）"
    )
    age: Optional[int] = Field(None, ge=10, le=100, description="年齢（任意・外部 AI 送信禁止）")
    notes: Optional[str] = Field(
        None, max_length=500, description="特記事項（怪我など）。**外部 AI 送信時は自動スキップ条件**（§4.4）"
    )
    big3_max: Optional[Big3Max] = Field(None, description="BIG3 MAX。外部 AI 送信禁止")

    # v5 で追加された任意フィールド
    gender: Optional[Gender] = Field(None, description="性別（任意・外部 AI 送信禁止）")
    body_weight_kg: Optional[float] = Field(
        None, ge=20, le=300, description="体重（任意・外部 AI 送信禁止）"
    )
    years_of_training: Optional[float] = Field(
        None, ge=0, le=80, description="トレーニング歴（年・任意・外部 AI 送信禁止）"
    )
    injury_history: Optional[List[Injury]] = Field(
        None,
        description="怪我履歴（任意・Sensitive Info）。**外部 AI 送信時は自動スキップ条件**（§4.4）",
    )
    priority_lift: Optional[PriorityLift] = Field(
        None,
        description=(
            "優先リフト（BIG3 強化向け雛形の選択に使用）。**none 以外を指定すると "
            "外部 AI 送信時は自動スキップ条件**（§4.4）"
        ),
    )

    # v6 (Step I) で追加: セッション開始予定時刻（0-23 の時間。任意）
    session_hour: Optional[int] = Field(
        None, ge=0, le=23,
        description="セッション開始予定時刻（24h、任意・カフェインカードの時刻調整用）",
    )

    # v1.0 (記録ベースの最適化) で追加: 過去 30 日のサマリ
    recent_history: Optional[RecentHistorySummary] = Field(
        None,
        description=(
            "端末内 SQLite から集計した過去 30 日のトレーニング記録サマリ。"
            "渡された場合、ルールエンジンは論文ベースのヒューリスティクスで"
            "提案を最適化する。サーバーは永続化しない。"
        ),
    )

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
    weight_kg: Optional[float] = Field(None, ge=0, description="推奨重量 (kg)")

    # v5 で追加
    evidence_refs: List[str] = Field(
        default_factory=list,
        description="この種目の根拠論文 evidence_id（例: ['schoenfeld_2017_volume']）",
    )
    safety_flags: List[str] = Field(
        default_factory=list,
        description="種目単位の安全フラグ（例: ['needs_spotter', 'high_intensity']）",
    )
    progression_rule: Optional[str] = Field(
        None,
        description="次回の進行ルール識別子（例: 'linear_+2.5kg', 'block_week2'）",
    )


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


class ProposalRationale(BaseModel):
    """提案根拠。論文ベースのルールが何を見て何を選んだかを記録。

    v1.0 で導入。AI 表記は一切使わず「論文ベースのルールが過去の記録から
    導いた結論」として説明する。
    """
    summary: str = Field(
        ...,
        description="1〜2 文の総括（例: 「直近 7 日でスクワット系が多いため、今日は背中中心」）",
    )
    bullets: List[str] = Field(
        default_factory=list,
        description="判断材料の箇条書き（最大 5 個）",
    )
    evidence_refs: List[str] = Field(
        default_factory=list,
        description=(
            "提案の根拠となった論文・プログラムの evidence_id 一覧 "
            "（例: ['theme_training_meta_analysis', 'beginner_full_body']）"
        ),
    )


class WorkoutPlan(BaseModel):
    """週間ワークアウトプラン"""
    plan_name: str = Field(..., description="プラン名")
    duration_weeks: int = Field(..., ge=1, le=52, description="推奨実施期間（週）")
    weekly_schedule: List[DaySession] = Field(..., min_length=1, description="週間スケジュール")
    general_advice: str = Field(..., description="食事・休養などの総合アドバイス")
    safety_flags: List[str] = Field(
        default_factory=list,
        description="プラン全体の安全フラグ（例: ['pain_reported', 'partial_skip']）",
    )
    proposal_rationale: Optional[ProposalRationale] = Field(
        None,
        description="提案根拠（履歴ベースの最適化が走った場合に格納）",
    )


# ── Advisory（v5 §6.4 で追加） ──────────────────────────────────────────────

class Advisory(BaseModel):
    """ユーザーへの推奨アクション。Flutter 分岐の主要シグナル。"""
    level: AdvisoryLevel = Field(AdvisoryLevel.NONE, description="アクションの強度")
    title: Optional[str] = Field(None, description="モーダル等のタイトル")
    body: Optional[str] = Field(None, description="本文")
    actions: List[str] = Field(
        default_factory=list,
        description="UI ボタン候補（例: ['rest', 'mobility_easy', 'consult_pro']）",
    )


# ── レスポンス: FastAPI → Flutter ────────────────────────────────────────────

class WorkoutResponse(BaseModel):
    """API レスポンスのルート。v5 で advisory / safety_flags / external_ai_used を正式追加。"""
    success: bool = Field(..., description="処理成功フラグ")
    plan: Optional[WorkoutPlan] = Field(
        None,
        description="生成されたプラン。advisory.level が rest_or_consult の時は null になり得る",
    )
    safety_flags: List[str] = Field(
        default_factory=list,
        description="トップレベルの安全フラグ。Flutter は本フィールドで分岐する",
    )
    advisory: Advisory = Field(
        default_factory=Advisory,
        description="ユーザーへの推奨アクション。Flutter は本フィールドで分岐する",
    )
    external_ai_used: bool = Field(
        False,
        description="本リクエストで外部 AI 補強が実行されたか。Flutter のメニュー画面では表示しない",
    )
    error_message: Optional[str] = Field(None, description="エラー詳細（success=false の時）")


# ── 目標別のトレーニング強度テーブル（%1RM）─ ルールエンジンで使用 ─────────

INTENSITY_TABLE = {
    "muscle_gain":     {"label": "筋肥大", "range": (70, 85), "primary": 77.5},
    "weight_loss":     {"label": "減量", "range": (60, 75), "primary": 67.5},
    "endurance":       {"label": "持久力", "range": (50, 70), "primary": 60.0},
    "general_fitness": {"label": "総合体力", "range": (65, 80), "primary": 72.5},
}
