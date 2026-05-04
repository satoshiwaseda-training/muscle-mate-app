"""
LLM 抽象化レイヤ（計画書 v5 §3.2 §6.3 §11.4 §11.7）

設計原則:
- 既定は NoOpClient（外部呼び出しコードパスが存在しない）
- LLM_PROVIDER=groq の時のみ GroqClient が候補
- 送信ペイロードは AllowlistedLLMPayload（extra="forbid"）で**構造的に**禁止フィールドを排除
- 同意ヘッダ・/next 経路・痛み・怪我等の自動スキップ条件を AND 条件で多重ガード
- すべて失敗時はルール結果をそのまま返す（fallback）
"""
from __future__ import annotations

import os
from typing import List, Literal, Optional, Protocol

from pydantic import BaseModel, ConfigDict

from src.schemas.log import SessionLog
from src.schemas.workout import (
    Equipment,
    Goal,
    Level,
    PriorityLift,
    WorkoutPlan,
    WorkoutRequest,
)


# ── ホワイトリスト送信ペイロード（計画書 §7・付録 C）────────────────────────

class AllowlistedLLMPayload(BaseModel):
    """外部 AI 送信 payload。送信可フィールドのみ列挙。

    extra="forbid" により、誤って禁止フィールドを混ぜたコードは
    Pydantic 検証で即座に例外になる（CI / ランタイム両方で検知）。
    """
    model_config = ConfigDict(extra="forbid")

    goal: Goal
    level: Level
    equipment: List[Equipment]
    days_per_week: int
    session_duration_minutes: int
    exercise_names: List[str]


# ── 多重ガード判定（v5 §6.3）────────────────────────────────────────────────

def should_call_external_ai(
    *,
    endpoint: Literal["generate", "next"],
    req: WorkoutRequest,
    plan: WorkoutPlan,
    session_log: Optional[SessionLog],
    request_headers: dict,
    runtime_state: dict,
) -> bool:
    """外部 AI を呼ぶべきか判定する純関数。

    判定が True になるのは以下が**すべて**満たされた時のみ:
      (0) endpoint != "next"
      (1) LLM_PROVIDER == "groq"
      (2) X-External-AI-Optin == "true"
      (3) 間接漏えい防止スキップ条件に該当しない
      (4) 月次・分次のコール上限を超えない
    """
    # (0) /workout/next は絶対呼ばない
    if endpoint == "next":
        return False

    # (1) サーバー側環境変数
    if os.environ.get("LLM_PROVIDER", "noop").lower() != "groq":
        return False

    # (2) クライアント同意ヘッダ
    optin = (request_headers.get("X-External-AI-Optin")
             or request_headers.get("x-external-ai-optin"))
    if optin != "true":
        return False

    # (3) 間接漏えい防止スキップ条件（v5 §4.4）
    if req.injury_history:
        return False
    if req.notes:
        return False
    if req.target_muscles:
        return False
    if req.priority_lift and req.priority_lift != PriorityLift.NONE:
        return False
    if plan.safety_flags:
        return False
    if session_log is not None:
        return False

    # (4) コール上限
    minute_cap = int(os.environ.get("MAX_EXTERNAL_AI_CALLS_PER_MIN", "30"))
    if runtime_state.get("calls_this_minute", 0) >= minute_cap:
        return False
    billing = os.environ.get("EXTERNAL_AI_BILLING_MODE", "free_only").lower()
    if billing == "paid_capped":
        month_cap = int(os.environ.get("MAX_EXTERNAL_AI_CALLS_PER_MONTH", "0"))
        if runtime_state.get("calls_this_month", 0) >= month_cap:
            return False
    # free_only: 月次カウンタは参照しない（Groq 側支払情報未登録で物理的に課金不可）

    return True


def build_allowlisted_payload(
    req: WorkoutRequest, plan: WorkoutPlan
) -> AllowlistedLLMPayload:
    """req と plan から allowlist された 6 フィールドのみを抽出する。

    extra="forbid" により、新フィールドを誤って渡そうとすると例外。
    """
    exercise_names: List[str] = []
    for sess in plan.weekly_schedule:
        for ex in sess.exercises:
            if ex.name_ja and ex.name_ja not in exercise_names:
                exercise_names.append(ex.name_ja)

    return AllowlistedLLMPayload(
        goal=req.goal,
        level=req.level,
        equipment=req.equipment,
        days_per_week=req.days_per_week,
        session_duration_minutes=req.session_duration_minutes,
        exercise_names=exercise_names,
    )


# ── クライアント抽象 ───────────────────────────────────────────────────────

class LLMClient(Protocol):
    async def enrich_text(self, payload: AllowlistedLLMPayload) -> dict: ...


class NoOpClient:
    """既定。外部呼び出しを行わない。"""

    async def enrich_text(self, payload: AllowlistedLLMPayload) -> dict:
        return {}


class GroqClient:
    """Groq の OpenAI 互換 API を呼ぶ最小実装（フェーズ 4 雛形）。

    実装は環境変数 GROQ_API_KEY が無い場合は NoOp フォールバック。
    JSON 強制 + ZDR 設定はアカウント側で実施（計画書 §11.6）。
    """

    def __init__(self) -> None:
        self.api_key = os.environ.get("GROQ_API_KEY")
        self.model = os.environ.get("GROQ_MODEL", "llama-3.3-70b-versatile")

    async def enrich_text(self, payload: AllowlistedLLMPayload) -> dict:
        if not self.api_key:
            return {}
        # 実呼び出しは将来実装。現時点では雛形として NoOp と同じ。
        # 実装時は httpx.AsyncClient で
        #   POST https://api.groq.com/openai/v1/chat/completions
        # を叩き、response_format={"type":"json_object"} で JSON 強制する。
        return {}


def get_llm_client() -> LLMClient:
    provider = os.environ.get("LLM_PROVIDER", "noop").lower()
    if provider == "groq":
        return GroqClient()
    return NoOpClient()
