"""
advice_service と /workout/advice のテスト

- 純ルール、外部 AI 非使用、入力非永続化を検証
- 体重・年齢・目標・レベル・priority_lift で適切なカードが生成されること
"""
from __future__ import annotations

import os

import pytest
from fastapi.testclient import TestClient

from src.schemas.advice import AdviceCategory, AdviceSeverity
from src.schemas.workout import (
    Equipment,
    Goal,
    Injury,
    InjurySeverity,
    Level,
    MuscleGroup,
    PriorityLift,
    WorkoutRequest,
)
from src.services.advice_service import build_advice_response
from src.services.protein_calculator import (
    calculate_caffeine_dose_mg,
    calculate_protein,
)

os.environ.setdefault("APP_ENV", "development")
os.environ.setdefault("LLM_PROVIDER", "noop")
os.environ.setdefault("EXTERNAL_AI_BILLING_MODE", "free_only")


def _req(**overrides) -> WorkoutRequest:
    base = dict(
        goal=Goal.MUSCLE_GAIN,
        level=Level.INTERMEDIATE,
        days_per_week=4,
        session_duration_minutes=60,
        equipment=[Equipment.BARBELL, Equipment.DUMBBELL, Equipment.MACHINE],
    )
    base.update(overrides)
    return WorkoutRequest(**base)


# ── protein_calculator ─────────────────────────────────────────────────────

def test_protein_calc_basic():
    plan = calculate_protein(70, age=30)
    assert plan is not None
    assert plan.daily_min_g == 98
    assert plan.daily_max_g == 140
    assert plan.elderly_adjusted is False


def test_protein_calc_elderly_flag():
    plan = calculate_protein(60, age=55)
    assert plan is not None
    assert plan.elderly_adjusted is True


def test_protein_calc_returns_none_when_no_weight():
    assert calculate_protein(None) is None


def test_protein_calc_invalid_weight():
    assert calculate_protein(10) is None
    assert calculate_protein(500) is None


def test_caffeine_dose():
    d = calculate_caffeine_dose_mg(70)
    assert d is not None
    assert d["standard_mg"] == 350
    assert d["starter_mg"] == 210
    assert d["timing_min_before"] == 30


def test_caffeine_dose_none_without_weight():
    assert calculate_caffeine_dose_mg(None) is None


# ── advice_service ─────────────────────────────────────────────────────────

def test_advice_includes_protein_card_when_weight_provided():
    res = build_advice_response(_req(body_weight_kg=70))
    assert res.success
    cats = {c.category for c in res.cards}
    assert AdviceCategory.PROTEIN_INTAKE in cats


def test_advice_skips_protein_card_without_weight():
    res = build_advice_response(_req())
    cats = {c.category for c in res.cards}
    assert AdviceCategory.PROTEIN_INTAKE not in cats


def test_advice_fat_card_only_for_muscle_gain():
    res_mg = build_advice_response(_req(goal=Goal.MUSCLE_GAIN))
    res_end = build_advice_response(_req(goal=Goal.ENDURANCE))
    cats_mg = {c.category for c in res_mg.cards}
    cats_end = {c.category for c in res_end.cards}
    assert AdviceCategory.FAT_BALANCE in cats_mg
    assert AdviceCategory.FAT_BALANCE not in cats_end


def test_advice_big3_card_when_priority_lift_set():
    res = build_advice_response(_req(priority_lift=PriorityLift.SQUAT))
    cats = {c.category for c in res.cards}
    assert AdviceCategory.BIG3_PROGRESSION in cats


def test_advice_equipment_card_for_beginner():
    res = build_advice_response(_req(level=Level.BEGINNER))
    cats = {c.category for c in res.cards}
    assert AdviceCategory.EQUIPMENT_GUIDANCE in cats


def test_advice_no_equipment_card_for_advanced():
    res = build_advice_response(_req(level=Level.ADVANCED))
    cats = {c.category for c in res.cards}
    assert AdviceCategory.EQUIPMENT_GUIDANCE not in cats


def test_advice_safety_card_always_present():
    res = build_advice_response(_req())
    cats = {c.category for c in res.cards}
    assert AdviceCategory.SAFETY_NOTE in cats


def test_advice_external_ai_never_used():
    res = build_advice_response(_req(body_weight_kg=70))
    assert res.external_ai_used is False
    for c in res.cards:
        # evidence_refs はすべて theme_* または既知の OA 論文 ID
        for ref in c.evidence_refs:
            assert ref  # 空文字でないこと


def test_advice_card_count_max_8():
    res = build_advice_response(_req(
        body_weight_kg=70, age=30,
        goal=Goal.MUSCLE_GAIN, level=Level.BEGINNER,
        priority_lift=PriorityLift.BENCH,
    ))
    assert res.success
    assert 1 <= len(res.cards) <= 8


def test_advice_severity_values_valid():
    res = build_advice_response(_req(body_weight_kg=70))
    for c in res.cards:
        assert c.severity in (
            AdviceSeverity.INFO,
            AdviceSeverity.TIP,
            AdviceSeverity.WARNING,
        )


# ── /workout/advice エンドポイント ──────────────────────────────────────────

def _make_app():
    import importlib
    import main
    importlib.reload(main)
    return main.app


def test_advice_endpoint_returns_cards():
    app = _make_app()
    client = TestClient(app)
    r = client.post("/workout/advice", json={
        "goal": "muscle_gain",
        "level": "intermediate",
        "days_per_week": 4,
        "session_duration_minutes": 60,
        "equipment": ["barbell", "dumbbell", "machine"],
        "body_weight_kg": 70,
        "age": 30,
    })
    assert r.status_code == 200
    data = r.json()
    assert data["success"] is True
    assert data["external_ai_used"] is False
    assert len(data["cards"]) >= 3
    cats = {c["category"] for c in data["cards"]}
    assert "protein_intake" in cats
    assert "fat_balance" in cats
    assert "safety_note" in cats


def test_advice_endpoint_canary_not_leaked():
    """カナリア値が応答に漏れないこと（バリデーションエラーケース）"""
    import json
    app = _make_app()
    client = TestClient(app)
    canary = "DO_NOT_LOG_ADVICE_canary_xyz"
    r = client.post("/workout/advice", json={
        "goal": "invalid_goal",
        "level": "beginner",
        "equipment": ["barbell"],
        "notes": canary,
    })
    body = json.dumps(r.json(), ensure_ascii=False)
    assert canary not in body


def test_advice_endpoint_does_not_send_external_ai_even_with_optin():
    """同意ヘッダ true でも /advice は外部 AI を呼ばない（純ルール）"""
    app = _make_app()
    client = TestClient(app)
    r = client.post(
        "/workout/advice",
        headers={"X-External-AI-Optin": "true"},
        json={
            "goal": "muscle_gain",
            "level": "intermediate",
            "days_per_week": 4,
            "session_duration_minutes": 60,
            "equipment": ["barbell"],
            "body_weight_kg": 70,
        },
    )
    assert r.status_code == 200
    assert r.json()["external_ai_used"] is False


# ── Step H: 新カード（怪我配慮・減量・ターゲット筋群）テスト ──────────────

def test_advice_injury_card_shown_when_injury_history():
    res = build_advice_response(_req(
        injury_history=[
            Injury(region=MuscleGroup.SHOULDERS, severity=InjurySeverity.MODERATE)
        ],
    ))
    cats = {c.category for c in res.cards}
    assert AdviceCategory.INJURY_CARE in cats
    # severity は WARNING
    injury_card = next(c for c in res.cards if c.category == AdviceCategory.INJURY_CARE)
    assert injury_card.severity == AdviceSeverity.WARNING


def test_advice_injury_card_skipped_without_history():
    res = build_advice_response(_req())
    cats = {c.category for c in res.cards}
    assert AdviceCategory.INJURY_CARE not in cats


def test_advice_weight_loss_card_only_for_weight_loss():
    res_wl = build_advice_response(_req(goal=Goal.WEIGHT_LOSS))
    res_mg = build_advice_response(_req(goal=Goal.MUSCLE_GAIN))
    cats_wl = {c.category for c in res_wl.cards}
    cats_mg = {c.category for c in res_mg.cards}
    assert AdviceCategory.WEIGHT_LOSS_DIET in cats_wl
    assert AdviceCategory.WEIGHT_LOSS_DIET not in cats_mg


def test_advice_weight_loss_card_personalized_with_weight():
    res = build_advice_response(_req(
        goal=Goal.WEIGHT_LOSS, body_weight_kg=80,
    ))
    wl_card = next(c for c in res.cards if c.category == AdviceCategory.WEIGHT_LOSS_DIET)
    # 80kg × 1.6-2.2 g/kg = 128-176 g
    assert wl_card.numeric_targets["protein_g_per_day_min"] == 128.0
    assert wl_card.numeric_targets["protein_g_per_day_max"] == 176.0
    assert "weekly_loss_kg_max" in wl_card.numeric_targets


def test_advice_muscle_group_focus_when_target_muscles_set():
    res = build_advice_response(_req(
        target_muscles=[MuscleGroup.CHEST, MuscleGroup.SHOULDERS],
    ))
    cats = {c.category for c in res.cards}
    assert AdviceCategory.MUSCLE_GROUP_FOCUS in cats


def test_advice_muscle_group_focus_skipped_without_target():
    res = build_advice_response(_req())
    cats = {c.category for c in res.cards}
    assert AdviceCategory.MUSCLE_GROUP_FOCUS not in cats


def test_advice_card_count_extended_to_12():
    """All conditions: cards stay within 12."""
    res = build_advice_response(_req(
        body_weight_kg=70, age=35,
        goal=Goal.WEIGHT_LOSS, level=Level.BEGINNER,
        priority_lift=PriorityLift.BENCH,
        target_muscles=[MuscleGroup.CHEST],
        injury_history=[Injury(region=MuscleGroup.SHOULDERS, severity=InjurySeverity.MILD)],
    ))
    assert res.success
    assert 1 <= len(res.cards) <= 12


# ── Step I: years_of_training / session_hour / session_log テスト ──────────

from datetime import date as _date
from src.schemas.log import ExerciseLog, SessionLog as _SessionLog, SetLog


def test_advice_big3_card_beginner_text():
    res = build_advice_response(_req(
        priority_lift=PriorityLift.SQUAT,
        years_of_training=0.5,
    ))
    big3 = next(c for c in res.cards if c.category == AdviceCategory.BIG3_PROGRESSION)
    assert "線形進行" in big3.body


def test_advice_big3_card_advanced_text():
    res = build_advice_response(_req(
        priority_lift=PriorityLift.SQUAT,
        years_of_training=5.0,
    ))
    big3 = next(c for c in res.cards if c.category == AdviceCategory.BIG3_PROGRESSION)
    assert "上級者" in big3.body


def test_advice_caffeine_evening_warning():
    res = build_advice_response(_req(body_weight_kg=70, session_hour=21))
    caf = next(c for c in res.cards if c.category == AdviceCategory.CAFFEINE_TIMING)
    assert caf.severity == AdviceSeverity.WARNING


def test_advice_caffeine_morning_tip():
    res = build_advice_response(_req(body_weight_kg=70, session_hour=7))
    caf = next(c for c in res.cards if c.category == AdviceCategory.CAFFEINE_TIMING)
    assert caf.severity == AdviceSeverity.TIP
    assert "朝" in caf.title or "朝" in caf.body


def test_advice_session_trend_card_with_pain():
    log = _SessionLog(
        session_date=_date.today(),
        exercise_logs=[ExerciseLog(
            name_ja="Bench", name_en="Bench",
            sets=[SetLog(weight_kg=80, reps=8, rpe=7, pain=True)],
        )],
    )
    res = build_advice_response(_req(), session_log=log)
    cats = {c.category for c in res.cards}
    assert AdviceCategory.SESSION_TREND in cats
    trend = next(c for c in res.cards if c.category == AdviceCategory.SESSION_TREND)
    assert trend.severity == AdviceSeverity.WARNING


def test_advice_session_trend_card_high_rpe():
    log = _SessionLog(
        session_date=_date.today(),
        exercise_logs=[ExerciseLog(
            name_ja="Squat", name_en="Squat",
            sets=[
                SetLog(weight_kg=100, reps=5, rpe=9.5),
                SetLog(weight_kg=100, reps=4, rpe=10.0),
            ],
        )],
    )
    res = build_advice_response(_req(), session_log=log)
    trend = next(c for c in res.cards if c.category == AdviceCategory.SESSION_TREND)
    assert trend.severity == AdviceSeverity.WARNING
    assert "デロード" in trend.body


def test_advice_session_trend_skipped_without_log():
    res = build_advice_response(_req())
    cats = {c.category for c in res.cards}
    assert AdviceCategory.SESSION_TREND not in cats


def test_advice_endpoint_with_session_log():
    app = _make_app()
    client = TestClient(app)
    r = client.post("/workout/advice/with-session", json={
        "request": {
            "goal": "muscle_gain",
            "level": "intermediate",
            "days_per_week": 4,
            "session_duration_minutes": 60,
            "equipment": ["barbell"],
            "body_weight_kg": 70,
        },
        "last_session": {
            "session_date": "2026-04-29",
            "exercise_logs": [{
                "name_ja": "Bench", "name_en": "Bench",
                "sets": [{"weight_kg": 80, "reps": 5, "rpe": 9.5, "pain": False}],
            }],
        },
    })
    assert r.status_code == 200
    cats = {c["category"] for c in r.json()["cards"]}
    assert "session_trend" in cats
    assert r.json()["external_ai_used"] is False
