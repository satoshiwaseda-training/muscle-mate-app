"""
ルールエンジンのユニットテスト（計画書 v5 フェーズ 1）

実行方法（プロジェクトルートで）:
  cd backend
  python -m pytest tests/ -v

外部 AI に依存せず、純粋なロジックの検証のみを行う。
"""
from __future__ import annotations

from datetime import date

import pytest

from src.schemas.log import ExerciseLog, SessionLog, SetLog
from src.schemas.workout import (
    AdvisoryLevel,
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
from src.services.progression_service import analyze_progression
from src.services.rule_engine_service import build_workout_response


def _req(**overrides) -> WorkoutRequest:
    base = dict(
        goal=Goal.GENERAL,
        level=Level.BEGINNER,
        days_per_week=3,
        session_duration_minutes=60,
        equipment=[
            Equipment.BARBELL,
            Equipment.DUMBBELL,
            Equipment.MACHINE,
            Equipment.BODYWEIGHT,
        ],
    )
    base.update(overrides)
    return WorkoutRequest(**base)


def test_beginner_full_body_3days():
    res = build_workout_response(_req())
    assert res.success
    assert res.plan is not None
    assert len(res.plan.weekly_schedule) == 3
    assert res.advisory.level == AdvisoryLevel.NONE
    assert res.external_ai_used is False


def test_intermediate_upper_lower_4days():
    res = build_workout_response(
        _req(level=Level.INTERMEDIATE, days_per_week=4, goal=Goal.MUSCLE_GAIN)
    )
    assert res.success
    assert res.plan is not None
    assert len(res.plan.weekly_schedule) == 4
    names = {s.session_name for s in res.plan.weekly_schedule}
    assert "Upper" in names
    assert "Lower" in names


def test_advanced_ppl_5days():
    res = build_workout_response(
        _req(level=Level.ADVANCED, days_per_week=5, goal=Goal.MUSCLE_GAIN)
    )
    assert res.success
    assert res.plan is not None
    assert len(res.plan.weekly_schedule) == 5
    names = [s.session_name for s in res.plan.weekly_schedule]
    assert "Push" in names
    assert "Pull" in names
    assert "Legs" in names


def test_priority_lift_routes_to_strength_block():
    res = build_workout_response(
        _req(
            level=Level.INTERMEDIATE,
            days_per_week=4,
            priority_lift=PriorityLift.SQUAT,
        )
    )
    assert res.success
    assert res.plan is not None
    name = res.plan.plan_name
    first_session = res.plan.weekly_schedule[0].session_name
    assert ("BIG3" in name) or ("Squat" in first_session)


def test_big3_weight_is_calculated():
    res = build_workout_response(
        _req(
            goal=Goal.MUSCLE_GAIN,
            big3_max=Big3Max(
                bench_press_max=100, squat_max=120, deadlift_max=140
            ),
        )
    )
    assert res.success
    found_with_weight = False
    for sess in res.plan.weekly_schedule:
        for ex in sess.exercises:
            if ex.weight_kg is not None and ex.weight_kg > 0:
                found_with_weight = True
                assert ex.weight_kg == round(ex.weight_kg / 2.5) * 2.5
    assert found_with_weight


def test_no_big3_means_null_weight():
    res = build_workout_response(_req())
    assert res.success
    bench_weights = []
    for sess in res.plan.weekly_schedule:
        for ex in sess.exercises:
            if "Bench" in ex.name_en:
                bench_weights.append(ex.weight_kg)
    if bench_weights:
        assert all(w is None for w in bench_weights)


def test_injury_excludes_target_muscle_exercises():
    res = build_workout_response(
        _req(
            level=Level.INTERMEDIATE,
            days_per_week=4,
            goal=Goal.MUSCLE_GAIN,
            injury_history=[
                Injury(
                    region=MuscleGroup.SHOULDERS,
                    severity=InjurySeverity.MODERATE,
                )
            ],
        )
    )
    assert res.success
    for sess in res.plan.weekly_schedule:
        for ex in sess.exercises:
            assert MuscleGroup.SHOULDERS not in ex.target_muscles
    assert "partial_skip" in res.safety_flags


def test_severe_injury_partial_skip_flag():
    res = build_workout_response(
        _req(
            injury_history=[
                Injury(
                    region=MuscleGroup.LOWER_BACK,
                    severity=InjurySeverity.SEVERE,
                )
            ]
        )
    )
    assert res.success
    assert "partial_skip" in res.safety_flags
    assert res.advisory.level == AdvisoryLevel.PARTIAL_SKIP


def test_mild_injury_does_not_exclude():
    res = build_workout_response(
        _req(
            injury_history=[
                Injury(
                    region=MuscleGroup.SHOULDERS,
                    severity=InjurySeverity.MILD,
                )
            ]
        )
    )
    assert res.success
    assert "partial_skip" not in res.safety_flags


def test_all_excluded_returns_rest_advisory():
    excluded_regions = [
        MuscleGroup.CHEST,
        MuscleGroup.BACK,
        MuscleGroup.SHOULDERS,
        MuscleGroup.QUADS,
        MuscleGroup.HAMSTRINGS,
        MuscleGroup.GLUTES,
        MuscleGroup.BICEPS,
        MuscleGroup.TRICEPS,
        MuscleGroup.CALVES,
        MuscleGroup.CORE,
        MuscleGroup.LOWER_BACK,
    ]
    res = build_workout_response(
        _req(
            level=Level.INTERMEDIATE,
            days_per_week=4,
            goal=Goal.MUSCLE_GAIN,
            injury_history=[
                Injury(region=m, severity=InjurySeverity.SEVERE)
                for m in excluded_regions
            ],
        )
    )
    assert res.success
    assert res.plan is None
    assert res.advisory.level == AdvisoryLevel.REST_OR_CONSULT
    assert "session_suspended" in res.safety_flags


def test_external_ai_not_used_in_phase1():
    res = build_workout_response(_req())
    assert res.external_ai_used is False


def test_response_serializes_to_json():
    res = build_workout_response(
        _req(
            big3_max=Big3Max(
                bench_press_max=80, squat_max=100, deadlift_max=120
            )
        )
    )
    data = res.model_dump(mode="json")
    assert isinstance(data, dict)
    assert "success" in data
    assert "advisory" in data
    assert "safety_flags" in data
    assert "external_ai_used" in data
    assert data["external_ai_used"] is False


def test_pain_triggers_rest_advisory():
    log = SessionLog(
        session_date=date.today(),
        exercise_logs=[
            ExerciseLog(
                name_ja="Bench Press",
                name_en="Bench Press",
                sets=[
                    SetLog(weight_kg=80, reps=8, rpe=7, pain=False),
                    SetLog(weight_kg=80, reps=6, rpe=8, pain=True),
                ],
            )
        ],
    )
    flags, advisory, recs = analyze_progression(log)
    assert "pain_reported" in flags
    assert advisory.level == AdvisoryLevel.REST_OR_CONSULT
    assert recs == {}


def test_high_rpe_triggers_deload():
    log = SessionLog(
        session_date=date.today(),
        exercise_logs=[
            ExerciseLog(
                name_ja="Squat",
                name_en="Squat",
                sets=[
                    SetLog(weight_kg=100, reps=5, rpe=9.5),
                    SetLog(weight_kg=100, reps=5, rpe=9.5),
                ],
            )
        ],
    )
    flags, advisory, recs = analyze_progression(log)
    assert advisory.level == AdvisoryLevel.DELOAD


def test_normal_progression_compound_increases_2_5kg():
    log = SessionLog(
        session_date=date.today(),
        exercise_logs=[
            ExerciseLog(
                name_ja="Bench Press",
                name_en="Bench Press",
                sets=[
                    SetLog(weight_kg=80, reps=8, rpe=7),
                    SetLog(weight_kg=80, reps=8, rpe=7),
                    SetLog(weight_kg=80, reps=8, rpe=7),
                ],
            )
        ],
    )
    flags, advisory, recs = analyze_progression(log)
    assert advisory.level == AdvisoryLevel.NONE
    assert recs["Bench Press"]["action"] == "increase"
    assert recs["Bench Press"]["delta_kg"] == 2.5


def test_failed_target_stays_same_weight():
    log = SessionLog(
        session_date=date.today(),
        exercise_logs=[
            ExerciseLog(
                name_ja="Bench Press",
                name_en="Bench Press",
                sets=[
                    SetLog(weight_kg=80, reps=5, rpe=8),
                    SetLog(weight_kg=80, reps=8, rpe=8),
                ],
            )
        ],
    )
    flags, advisory, recs = analyze_progression(log)
    assert recs["Bench Press"]["action"] == "stay"
    assert recs["Bench Press"]["delta_kg"] == 0.0
