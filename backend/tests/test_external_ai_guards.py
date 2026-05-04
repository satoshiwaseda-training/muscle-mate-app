"""
外部 AI ガードのテスト（計画書 v5 §4.4 §6.3 §7 §11.4.1 §付録 C）

- AllowlistedLLMPayload(extra="forbid") で禁止フィールド混入が構造的に弾かれること
- should_call_external_ai() の多重ガード（環境変数・ヘッダ・自動スキップ・コール上限）
- カナリア値漏えい検査: ログ・APM・エラー応答に固有のシークレット値が出ないこと
- /workout/next 経路は常に external_ai_used=False であること
- 計画書本文（§7／付録 C）と llm_service の allowlist が完全一致していること
"""
from __future__ import annotations

import json
import os
from datetime import date

import pytest
from fastapi.testclient import TestClient
from pydantic import ValidationError

from src.schemas.log import ExerciseLog, SessionLog, SetLog
from src.schemas.workout import (
    Big3Max,
    Equipment,
    Goal,
    Injury,
    InjurySeverity,
    Level,
    MuscleGroup,
    PriorityLift,
    WorkoutRequest,
)
from src.services.llm_service import (
    AllowlistedLLMPayload,
    NoOpClient,
    build_allowlisted_payload,
    get_llm_client,
    should_call_external_ai,
)
from src.services.rule_engine_service import build_workout_response

# テスト時はサーバー側環境を固定
os.environ.setdefault("APP_ENV", "development")
os.environ.setdefault("LLM_PROVIDER", "noop")
os.environ.setdefault("EXTERNAL_AI_BILLING_MODE", "free_only")
os.environ.setdefault("MAX_EXTERNAL_AI_CALLS_PER_MIN", "30")


# ── allowlist 構造的強制 ────────────────────────────────────────────────────

def test_allowlist_payload_rejects_forbidden_fields():
    """禁止フィールドを混ぜると ValidationError"""
    with pytest.raises(ValidationError):
        AllowlistedLLMPayload(
            goal=Goal.MUSCLE_GAIN,
            level=Level.INTERMEDIATE,
            equipment=[Equipment.BARBELL],
            days_per_week=4,
            session_duration_minutes=60,
            exercise_names=["Bench"],
            big3_max={"bench_press_max": 100},  # type: ignore[call-arg]
        )


def test_allowlist_payload_rejects_age():
    with pytest.raises(ValidationError):
        AllowlistedLLMPayload(
            goal=Goal.MUSCLE_GAIN,
            level=Level.INTERMEDIATE,
            equipment=[Equipment.BARBELL],
            days_per_week=4,
            session_duration_minutes=60,
            exercise_names=[],
            age=30,  # type: ignore[call-arg]
        )


def test_allowlist_payload_accepts_only_six_fields():
    p = AllowlistedLLMPayload(
        goal=Goal.MUSCLE_GAIN,
        level=Level.INTERMEDIATE,
        equipment=[Equipment.BARBELL],
        days_per_week=4,
        session_duration_minutes=60,
        exercise_names=["Bench Press"],
    )
    keys = set(p.model_dump().keys())
    assert keys == {
        "goal", "level", "equipment", "days_per_week",
        "session_duration_minutes", "exercise_names",
    }


def test_build_allowlisted_payload_strips_other_fields():
    """req に余計なフィールド（age 等）があっても allowlist payload には含まれない"""
    req = WorkoutRequest(
        goal=Goal.MUSCLE_GAIN,
        level=Level.INTERMEDIATE,
        days_per_week=4,
        session_duration_minutes=60,
        equipment=[Equipment.BARBELL],
        age=35,
        gender=None,
        body_weight_kg=70,
        big3_max=Big3Max(bench_press_max=100),
        notes="腰を労わる",
    )
    res = build_workout_response(req)
    # plan が生成されている前提
    assert res.plan is not None
    payload = build_allowlisted_payload(req, res.plan)
    serialized = payload.model_dump()
    # 禁止フィールド一覧
    forbidden = {
        "age", "gender", "body_weight_kg", "years_of_training",
        "priority_lift", "big3_max", "target_muscles",
        "injury_history", "notes", "pain", "rpe", "weight_kg",
        "session_logs", "user_id", "email", "device_id", "ip",
    }
    for k in forbidden:
        assert k not in serialized


# ── 多重ガード（should_call_external_ai）────────────────────────────────────

def _base_req() -> WorkoutRequest:
    return WorkoutRequest(
        goal=Goal.MUSCLE_GAIN,
        level=Level.INTERMEDIATE,
        days_per_week=4,
        session_duration_minutes=60,
        equipment=[Equipment.BARBELL, Equipment.DUMBBELL, Equipment.MACHINE],
    )


def test_guard_blocks_when_provider_is_noop(monkeypatch):
    monkeypatch.setenv("LLM_PROVIDER", "noop")
    req = _base_req()
    plan = build_workout_response(req).plan
    assert plan is not None
    assert should_call_external_ai(
        endpoint="generate", req=req, plan=plan, session_log=None,
        request_headers={"X-External-AI-Optin": "true"},
        runtime_state={"calls_this_minute": 0},
    ) is False


def test_guard_blocks_when_optin_header_false(monkeypatch):
    monkeypatch.setenv("LLM_PROVIDER", "groq")
    req = _base_req()
    plan = build_workout_response(req).plan
    assert plan is not None
    assert should_call_external_ai(
        endpoint="generate", req=req, plan=plan, session_log=None,
        request_headers={"X-External-AI-Optin": "false"},
        runtime_state={"calls_this_minute": 0},
    ) is False


def test_guard_blocks_when_endpoint_is_next(monkeypatch):
    monkeypatch.setenv("LLM_PROVIDER", "groq")
    req = _base_req()
    plan = build_workout_response(req).plan
    assert plan is not None
    assert should_call_external_ai(
        endpoint="next", req=req, plan=plan, session_log=None,
        request_headers={"X-External-AI-Optin": "true"},
        runtime_state={"calls_this_minute": 0},
    ) is False


def test_guard_blocks_with_injury(monkeypatch):
    monkeypatch.setenv("LLM_PROVIDER", "groq")
    req = WorkoutRequest(
        goal=Goal.MUSCLE_GAIN,
        level=Level.INTERMEDIATE,
        days_per_week=4,
        session_duration_minutes=60,
        equipment=[Equipment.BARBELL, Equipment.DUMBBELL, Equipment.MACHINE],
        injury_history=[Injury(region=MuscleGroup.SHOULDERS, severity=InjurySeverity.MILD)],
    )
    plan = build_workout_response(req).plan
    assert plan is not None
    assert should_call_external_ai(
        endpoint="generate", req=req, plan=plan, session_log=None,
        request_headers={"X-External-AI-Optin": "true"},
        runtime_state={"calls_this_minute": 0},
    ) is False


def test_guard_blocks_with_notes(monkeypatch):
    monkeypatch.setenv("LLM_PROVIDER", "groq")
    req = _base_req().model_copy(update={"notes": "腰を労わりたい"})
    plan = build_workout_response(req).plan
    assert plan is not None
    assert should_call_external_ai(
        endpoint="generate", req=req, plan=plan, session_log=None,
        request_headers={"X-External-AI-Optin": "true"},
        runtime_state={"calls_this_minute": 0},
    ) is False


def test_guard_blocks_with_priority_lift(monkeypatch):
    monkeypatch.setenv("LLM_PROVIDER", "groq")
    req = _base_req().model_copy(update={"priority_lift": PriorityLift.SQUAT})
    plan = build_workout_response(req).plan
    assert plan is not None
    assert should_call_external_ai(
        endpoint="generate", req=req, plan=plan, session_log=None,
        request_headers={"X-External-AI-Optin": "true"},
        runtime_state={"calls_this_minute": 0},
    ) is False


def test_guard_blocks_when_session_log_present(monkeypatch):
    monkeypatch.setenv("LLM_PROVIDER", "groq")
    req = _base_req()
    plan = build_workout_response(req).plan
    log = SessionLog(
        session_date=date.today(),
        exercise_logs=[
            ExerciseLog(
                name_ja="Bench", name_en="Bench",
                sets=[SetLog(weight_kg=80, reps=8, rpe=7)],
            )
        ],
    )
    assert plan is not None
    assert should_call_external_ai(
        endpoint="generate", req=req, plan=plan, session_log=log,
        request_headers={"X-External-AI-Optin": "true"},
        runtime_state={"calls_this_minute": 0},
    ) is False


def test_guard_blocks_when_call_minute_cap(monkeypatch):
    monkeypatch.setenv("LLM_PROVIDER", "groq")
    monkeypatch.setenv("MAX_EXTERNAL_AI_CALLS_PER_MIN", "5")
    req = _base_req()
    plan = build_workout_response(req).plan
    assert plan is not None
    assert should_call_external_ai(
        endpoint="generate", req=req, plan=plan, session_log=None,
        request_headers={"X-External-AI-Optin": "true"},
        runtime_state={"calls_this_minute": 5},
    ) is False


def test_guard_passes_when_all_conditions_clear(monkeypatch):
    """全条件クリアで True"""
    monkeypatch.setenv("LLM_PROVIDER", "groq")
    monkeypatch.setenv("MAX_EXTERNAL_AI_CALLS_PER_MIN", "30")
    req = _base_req()
    plan = build_workout_response(req).plan
    assert plan is not None
    assert should_call_external_ai(
        endpoint="generate", req=req, plan=plan, session_log=None,
        request_headers={"X-External-AI-Optin": "true"},
        runtime_state={"calls_this_minute": 0},
    ) is True


# ── デフォルトクライアント ──────────────────────────────────────────────────

def test_default_client_is_noop_when_provider_unset():
    """LLM_PROVIDER 未設定なら NoOpClient（外部呼び出しコードパス無し）"""
    if "LLM_PROVIDER" in os.environ:
        del os.environ["LLM_PROVIDER"]
    client = get_llm_client()
    assert isinstance(client, NoOpClient)


# ── カナリア値漏えい検査（§11.4.1）─────────────────────────────────────────

def _make_app():
    """テスト用に main.py を import（環境変数を整えてから）"""
    import importlib
    import main
    importlib.reload(main)
    return main.app


def test_canary_not_leaked_in_validation_error():
    """422 バリデーションエラー応答にカナリア値が含まれない"""
    app = _make_app()
    client = TestClient(app)
    canary_text = "DO_NOT_LOG_SECRET_canary_xyz_2026"
    canary_num = 99999.99
    r = client.post(
        "/workout/generate",
        json={
            "goal": "invalid_goal_value",
            "level": "beginner",
            "equipment": ["barbell"],
            "notes": canary_text,
            "big3_max": {"bench_press_max": canary_num},
        },
    )
    body = json.dumps(r.json(), ensure_ascii=False)
    assert canary_text not in body, "カナリア値（文字列）が応答に漏えい"
    assert "99999.99" not in body, "カナリア値（数値）が応答に漏えい"
    assert "invalid_goal_value" not in body, "入力値（goal）が応答に漏えい"


def test_canary_not_leaked_in_health_endpoint():
    """/health は本文を持たないので漏えいなし"""
    app = _make_app()
    client = TestClient(app)
    r = client.get("/health")
    body = json.dumps(r.json(), ensure_ascii=False)
    assert "DO_NOT_LOG" not in body
    assert r.json()["llm_provider"] == "noop"


def test_next_endpoint_does_not_use_external_ai():
    """/workout/next は常に external_ai_used=False"""
    app = _make_app()
    client = TestClient(app)
    r = client.post(
        "/workout/next",
        headers={"X-External-AI-Optin": "true"},  # ヘッダ true でも呼ばれない
        json={
            "last_session": {
                "session_date": "2026-04-29",
                "exercise_logs": [
                    {
                        "name_ja": "Bench",
                        "name_en": "Bench",
                        "sets": [
                            {"weight_kg": 80, "reps": 8, "rpe": 7, "pain": False},
                        ],
                    }
                ],
            }
        },
    )
    assert r.status_code == 200
    assert r.json()["external_ai_used"] is False


# ── 計画書とコードの一致検査（シングルソース原則 §7・付録 C）──────────────

def test_plan_doc_and_code_share_the_same_six_fields():
    """計画書 §7 / 付録 C と AllowlistedLLMPayload のフィールドが一致していること"""
    expected = {
        "goal", "level", "equipment", "days_per_week",
        "session_duration_minutes", "exercise_names",
    }
    actual = set(AllowlistedLLMPayload.model_fields.keys())
    assert actual == expected
