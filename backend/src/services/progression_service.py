"""
プログレッションサービス（計画書 v5 §6.6 §4.2）

直前の SessionLog から「次回の推奨アクション」を純関数で導出する。
- user_id を持たない・サーバー側で永続化しない
- /workout/next 経路では外部 AI を呼ばない（v5 §6.3）
- 痛み報告時は §9.2 に従って自動代替せず、advisory で休止／専門家相談へ誘導
"""
from __future__ import annotations

from typing import List, Tuple

from src.schemas.log import SessionLog, SetLog
from src.schemas.workout import (
    Advisory,
    AdvisoryLevel,
    WorkoutResponse,
)


# ── ハードキャップ（計画書 §4.2 §9.3）─────────────────────────────────────
COMPOUND_INC_MAX_KG = 5.0
ISOLATION_INC_MAX_KG = 2.0

# ── プログレッション基準値 ──────────────────────────────────────────────────
COMPOUND_INC_KG = 2.5
ISOLATION_INC_KG = 1.0

# 簡易判定: 種目名に下記が含まれていればコンパウンド扱い
_COMPOUND_KEYWORDS = (
    "スクワット", "ベンチプレス", "デッドリフト", "オーバーヘッドプレス",
    "ロウ", "ローイング", "プレス", "Squat", "Bench", "Deadlift", "Press", "Row",
)


def _is_compound(name_ja: str, name_en: str) -> bool:
    return any(k in name_ja or k in name_en for k in _COMPOUND_KEYWORDS)


def _met_target_reps(set_log: SetLog, target_upper: int = 8) -> bool:
    """規定レップ上限を達成したか（簡易: 8 回以上で達成扱い）"""
    return set_log.reps >= target_upper


def analyze_progression(last_session: SessionLog) -> Tuple[List[str], Advisory, dict]:
    """直前セッションを解析し、次回への推奨を返す。

    Returns:
        (safety_flags, advisory, recommendations_by_exercise)
        recommendations_by_exercise: {種目名_ja: {"action": str, "delta_kg": float}}
    """
    safety_flags: List[str] = []
    recommendations: dict = {}

    has_pain = last_session.has_any_pain()
    max_rpe = last_session.max_rpe()

    # 痛み検出 → §9.2 の医療フローへ
    if has_pain:
        safety_flags = ["pain_reported", "session_suspended"]
        return (
            safety_flags,
            Advisory(
                level=AdvisoryLevel.REST_OR_CONSULT,
                title="今日はトレーニングを中止しましょう",
                body=(
                    "痛みが報告されています。本日の該当部位のメニュー生成を中止します。"
                    "軽い可動域運動と休養、必要に応じて医療専門家への相談をご検討ください。"
                ),
                actions=["rest", "mobility_easy", "consult_pro"],
            ),
            recommendations,
        )

    # 高 RPE 検出 → デロード提案
    if max_rpe is not None and max_rpe >= 9:
        safety_flags = ["high_rpe_detected"]
        return (
            safety_flags,
            Advisory(
                level=AdvisoryLevel.DELOAD,
                title="デロードを検討しましょう",
                body=(
                    "直近セッションで RPE 9 以上が記録されています。"
                    "重量を 10% 下げ、ボリュームを 30% 程度減らした回復週を入れることを推奨します。"
                ),
                actions=["accept_deload", "decline"],
            ),
            recommendations,
        )

    # 通常進行
    for ex in last_session.exercise_logs:
        all_met = all(_met_target_reps(s) for s in ex.sets)
        all_low_rpe = all(
            (s.rpe is None or s.rpe <= 8) for s in ex.sets
        )
        if all_met and all_low_rpe:
            inc = COMPOUND_INC_KG if _is_compound(ex.name_ja, ex.name_en) else ISOLATION_INC_KG
            cap = COMPOUND_INC_MAX_KG if _is_compound(ex.name_ja, ex.name_en) else ISOLATION_INC_MAX_KG
            recommendations[ex.name_ja] = {
                "action": "increase",
                "delta_kg": min(inc, cap),
            }
        else:
            recommendations[ex.name_ja] = {
                "action": "stay",
                "delta_kg": 0.0,
            }

    return (safety_flags, Advisory(level=AdvisoryLevel.NONE), recommendations)
