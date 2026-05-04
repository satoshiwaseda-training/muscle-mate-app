"""
履歴ベースの提案最適化（history_optimizer + rule_engine 統合）テスト

`RecentHistorySummary` を渡したときに、ルールエンジンが論文ベースの
ヒューリスティクスで提案を最適化することを検証する。
"""
from __future__ import annotations

import pytest

from src.schemas.workout import (
    Equipment,
    Goal,
    Level,
    MuscleGroup,
    RecentHistorySummary,
    WorkoutRequest,
)
from src.services import history_optimizer
from src.services.rule_engine_service import build_workout_response


def _base_req(**overrides) -> WorkoutRequest:
    """テスト用の最小 WorkoutRequest"""
    defaults = {
        "goal": Goal.GENERAL,
        "level": Level.BEGINNER,
        "days_per_week": 1,
        "session_duration_minutes": 30,
        "equipment": [Equipment.BARBELL, Equipment.BODYWEIGHT],
    }
    defaults.update(overrides)
    return WorkoutRequest(**defaults)


# ── suggest_target_muscles ──────────────────────────────────────────────


def test_history_none_returns_none() -> None:
    """履歴がなければ何も提案しない"""
    req = _base_req()
    assert history_optimizer.suggest_target_muscles(req, None) is None


def test_user_target_muscles_take_precedence() -> None:
    """ユーザー明示指定があればそれを最優先"""
    req = _base_req(target_muscles=[MuscleGroup.CHEST])
    history = RecentHistorySummary(
        sessions_last_30_days=10,
        muscles_unworked_14d=["back", "shoulders"],
    )
    assert history_optimizer.suggest_target_muscles(req, history) == [
        MuscleGroup.CHEST
    ]


def test_underworked_muscles_get_proposed() -> None:
    """14 日放置されている筋群が候補として返る"""
    req = _base_req()
    history = RecentHistorySummary(
        sessions_last_30_days=10,
        recent_muscle_focus_7d={"chest": 4, "legs": 1},
        muscles_unworked_14d=["back", "shoulders"],
    )
    suggested = history_optimizer.suggest_target_muscles(req, history)
    assert suggested is not None
    assert MuscleGroup.BACK in suggested
    assert MuscleGroup.SHOULDERS in suggested


def test_pain_region_excludes_related_muscles() -> None:
    """痛み報告 (knee 2 回) があれば legs 系を提案しない"""
    req = _base_req()
    history = RecentHistorySummary(
        sessions_last_30_days=10,
        muscles_unworked_14d=["legs"],
        pain_reports_last_7d={"knee": 2},
    )
    suggested = history_optimizer.suggest_target_muscles(req, history)
    # 痛み除外で legs/quads/hamstrings は含まれない
    if suggested is not None:
        for m in suggested:
            assert m not in {
                MuscleGroup.QUADS,
                MuscleGroup.HAMSTRINGS,
                MuscleGroup.LEGS,
            }


# ── should_reduce_intensity ─────────────────────────────────────────────


def test_long_break_reduces_intensity() -> None:
    """7 日以上空いていれば強度を下げる"""
    history = RecentHistorySummary(
        last_session_days_ago=10,
        sessions_last_30_days=4,
    )
    assert history_optimizer.should_reduce_intensity(history) is True


def test_pain_reports_reduce_intensity() -> None:
    """痛み報告複数回 → 強度を下げる"""
    history = RecentHistorySummary(
        last_session_days_ago=2,
        pain_reports_last_7d={"shoulder": 3},
    )
    assert history_optimizer.should_reduce_intensity(history) is True


def test_normal_state_keeps_intensity() -> None:
    """直近セッションあり・痛みなし → 強度はそのまま"""
    history = RecentHistorySummary(
        last_session_days_ago=2,
        sessions_last_7_days=3,
        sessions_last_30_days=12,
    )
    assert history_optimizer.should_reduce_intensity(history) is False


def test_none_history_keeps_intensity() -> None:
    """履歴なし → 強度はそのまま"""
    assert history_optimizer.should_reduce_intensity(None) is False


# ── build_rationale ─────────────────────────────────────────────────────


def test_rationale_mentions_overworked_muscles() -> None:
    """7 日で 4 回以上鍛えた筋群が rationale に含まれる"""
    req = _base_req()
    history = RecentHistorySummary(
        sessions_last_7_days=4,
        sessions_last_30_days=12,
        recent_muscle_focus_7d={"chest": 4, "back": 0},
        muscles_unworked_14d=["back"],
    )
    suggested = history_optimizer.suggest_target_muscles(req, history)
    rationale = history_optimizer.build_rationale(
        req, history, "focused_session", suggested
    )
    assert rationale is not None
    full_text = rationale.summary + " ".join(rationale.bullets)
    assert "胸" in full_text
    assert "theme_training_meta_analysis" in rationale.evidence_refs


def test_rationale_mentions_break_recovery() -> None:
    """7 日以上の空白があれば復帰メッセージが入る"""
    req = _base_req()
    history = RecentHistorySummary(
        last_session_days_ago=10,
        sessions_last_7_days=0,
        sessions_last_30_days=4,
    )
    rationale = history_optimizer.build_rationale(req, history, "beginner_full_body", None)
    assert rationale is not None
    full_text = " ".join(rationale.bullets)
    assert "10 日" in full_text or "復帰" in rationale.summary
    assert "theme_rest_intervals" in rationale.evidence_refs


def test_rationale_none_when_no_history() -> None:
    """記録ゼロなら rationale を返さない（雛形の一般説明で十分）"""
    req = _base_req()
    assert history_optimizer.build_rationale(req, None, "beginner_full_body", None) is None
    history = RecentHistorySummary(
        last_session_days_ago=None, sessions_last_30_days=0
    )
    assert history_optimizer.build_rationale(req, history, "beginner_full_body", None) is None


# ── 統合: build_workout_response ──────────────────────────────────────────


def test_full_response_with_history_includes_rationale() -> None:
    """エンドツーエンドで rationale が response.plan に含まれる"""
    req = _base_req(
        recent_history=RecentHistorySummary(
            last_session_days_ago=1,
            sessions_last_7_days=4,
            sessions_last_30_days=12,
            recent_muscle_focus_7d={"chest": 4, "back": 0},
            muscles_unworked_14d=["back", "shoulders"],
            streak_days=8,
        ),
    )
    res = build_workout_response(req)
    assert res.success is True
    assert res.plan is not None
    assert res.plan.proposal_rationale is not None
    assert len(res.plan.proposal_rationale.bullets) >= 1
    # 提案ターゲットが back/shoulders に振り替わっていることを確認
    targets = res.plan.weekly_schedule[0].target_muscles
    assert any(t in {MuscleGroup.BACK, MuscleGroup.SHOULDERS} for t in targets)


def test_full_response_without_history_no_rationale() -> None:
    """履歴なしなら rationale も None"""
    req = _base_req()
    res = build_workout_response(req)
    assert res.success is True
    assert res.plan is not None
    assert res.plan.proposal_rationale is None
