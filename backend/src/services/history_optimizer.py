"""
履歴ベースのトレーニング提案最適化（v1.0 で導入）

ユーザー端末から送られた `RecentHistorySummary` を読み、論文ベースのルール
（knowledge/summaries/ の MD と整合）でメニュー提案を補正する。

外部 AI を使わない決定論的なロジックのみ。出力は提案根拠テキスト・推奨
ターゲット筋群・強度補正フラグの 3 種類。

根拠論文・要約MD：
  - Currier 2023 BJSM (theme_training_meta_analysis.md)
        週 2-3 回 / 筋群が最適、頻度より週ボリュームを重視
  - Schoenfeld & Henselmans 2014/2016 (theme_rest_intervals.md)
        休息時間 2-3 分以上、48h セッション間休養
  - Buresh 2009 (theme_rest_intervals.md)
        セッション間休養の重要性
  - Schoenfeld 2010/2013 (theme_hypertrophy_mechanisms.md)
        筋肥大の機序、安全性確保

本モジュールは外部ネットワーク呼び出しを行わない。
"""
from __future__ import annotations

from typing import List, Optional

from src.schemas.workout import (
    Goal,
    Level,
    MuscleGroup,
    ProposalRationale,
    RecentHistorySummary,
    WorkoutRequest,
)


# ── 筋群名マッピング（フロントが送る文字列 → MuscleGroup enum） ────────────
# フロント側の集計関数も同じ文字列を使うこと（local_storage_service.dart）
_MUSCLE_KEY_TO_ENUM: dict[str, MuscleGroup] = {
    "chest": MuscleGroup.CHEST,
    "back": MuscleGroup.BACK,
    "shoulders": MuscleGroup.SHOULDERS,
    "biceps": MuscleGroup.BICEPS,
    "triceps": MuscleGroup.TRICEPS,
    "quads": MuscleGroup.QUADS,
    "hamstrings": MuscleGroup.HAMSTRINGS,
    "glutes": MuscleGroup.GLUTES,
    "calves": MuscleGroup.CALVES,
    "core": MuscleGroup.CORE,
    "legs": MuscleGroup.LEGS,
    "full_body": MuscleGroup.FULL_BODY,
}


# ── 痛み報告部位 → MuscleGroup マッピング ─────────────────────────────────
# pain_reports_last_7d のキー（部位名）から、避けるべき MuscleGroup を導く
_PAIN_REGION_TO_MUSCLES: dict[str, set[MuscleGroup]] = {
    "knee": {MuscleGroup.QUADS, MuscleGroup.HAMSTRINGS, MuscleGroup.LEGS},
    "lower_back": {MuscleGroup.BACK, MuscleGroup.GLUTES},
    "shoulder": {MuscleGroup.SHOULDERS, MuscleGroup.CHEST},
    "elbow": {MuscleGroup.BICEPS, MuscleGroup.TRICEPS},
    "wrist": {MuscleGroup.BICEPS, MuscleGroup.TRICEPS},
    "ankle": {MuscleGroup.CALVES, MuscleGroup.LEGS},
    "neck": {MuscleGroup.SHOULDERS},
    "hip": {MuscleGroup.GLUTES, MuscleGroup.HAMSTRINGS},
}


def _muscles_to_avoid_from_pain(history: RecentHistorySummary) -> set[MuscleGroup]:
    """直近 7 日に複数回の痛み報告がある部位の関連筋群を導出"""
    avoid: set[MuscleGroup] = set()
    for region, count in (history.pain_reports_last_7d or {}).items():
        if count >= 2:  # 単発は除く（測定誤差の可能性）
            avoid |= _PAIN_REGION_TO_MUSCLES.get(region.lower(), set())
    return avoid


def _muscles_overworked_recently(history: RecentHistorySummary) -> set[MuscleGroup]:
    """過去 7 日で 4 回以上鍛えた筋群（同筋群の連続/集中）

    Currier 2023 の知見に基づき、週 3 回を超える刺激は効率低下のため避ける
    （週 2-3 回 / 筋群が最適）。
    """
    over: set[MuscleGroup] = set()
    for muscle_key, count in (history.recent_muscle_focus_7d or {}).items():
        if count >= 4:
            enum_val = _MUSCLE_KEY_TO_ENUM.get(muscle_key.lower())
            if enum_val:
                over.add(enum_val)
    return over


def _muscles_underworked_long(history: RecentHistorySummary) -> List[MuscleGroup]:
    """14 日間鍛えていない筋群（バランス是正の優先候補）"""
    under: List[MuscleGroup] = []
    for muscle_key in (history.muscles_unworked_14d or []):
        enum_val = _MUSCLE_KEY_TO_ENUM.get(muscle_key.lower())
        if enum_val:
            under.append(enum_val)
    return under


def _is_returning_from_break(history: RecentHistorySummary) -> bool:
    """7 日以上空いている = 復帰セッション扱い → 強度低めに"""
    return (
        history.last_session_days_ago is not None
        and history.last_session_days_ago >= 7
    )


def suggest_target_muscles(
    req: WorkoutRequest,
    history: Optional[RecentHistorySummary],
) -> Optional[List[MuscleGroup]]:
    """履歴を参照して、今日の推奨ターゲット筋群を返す。

    優先度（高 → 低）:
      1. ユーザーが明示的に target_muscles を指定 → それを尊重
      2. 痛みのある部位は除外しつつ、14 日間放置されている筋群を優先
      3. 7 日で 4 回以上鍛えた筋群を避け、別の筋群を提案

    返り値が None の場合、ルールエンジンは既存ロジック（雛形ベース）にフォールバック。
    """
    # ユーザーが明示指定した場合は最優先
    if req.target_muscles:
        return req.target_muscles
    # 履歴がなければ提案しない
    if history is None or history.sessions_last_30_days == 0:
        return None

    avoid = _muscles_to_avoid_from_pain(history) | _muscles_overworked_recently(history)
    candidates = [m for m in _muscles_underworked_long(history) if m not in avoid]

    if candidates:
        # 上位 2 つまで（多すぎると 1 セッション内で消化困難）
        return candidates[:2]
    return None


def should_reduce_intensity(history: Optional[RecentHistorySummary]) -> bool:
    """直近セッションから 7 日以上空いているか、痛み報告が複数あれば強度を下げる"""
    if history is None:
        return False
    if _is_returning_from_break(history):
        return True
    if any(c >= 2 for c in (history.pain_reports_last_7d or {}).values()):
        return True
    return False


def build_rationale(
    req: WorkoutRequest,
    history: Optional[RecentHistorySummary],
    split_id: str,
    suggested_targets: Optional[List[MuscleGroup]],
) -> Optional[ProposalRationale]:
    """提案根拠テキストを組み立てる。AI 表記は使わない。

    history が None または空（記録ゼロ）なら None を返す（プログラム雛形の
    一般説明のみで十分）。
    """
    if history is None:
        return None
    if history.sessions_last_30_days == 0 and history.last_session_days_ago is None:
        return None

    bullets: List[str] = []
    evidence: List[str] = []

    # 1. ボリューム推移（Currier 2023 BJSM）
    if history.sessions_last_7_days >= 3:
        bullets.append(
            f"過去 7 日のセッション数は {history.sessions_last_7_days} 回。"
            "週 2〜3 回が論文上の最適頻度なので、今日は質を維持しましょう。"
        )
        evidence.append("theme_training_meta_analysis")
    elif history.sessions_last_7_days <= 1 and history.sessions_last_30_days >= 4:
        bullets.append(
            f"過去 7 日のセッションは {history.sessions_last_7_days} 回と少なめ。"
            "リズムを取り戻すために、無理のない強度から再開を提案しています。"
        )
        evidence.append("theme_training_meta_analysis")

    # 2. 復帰セッション（Buresh 2009）
    if _is_returning_from_break(history):
        bullets.append(
            f"直近セッションから {history.last_session_days_ago} 日空いています。"
            "復帰時は強度を 70% 程度から再開するのが安全です。"
        )
        evidence.append("theme_rest_intervals")

    # 3. 偏り是正（Currier 2023 BJSM）
    overworked = _muscles_overworked_recently(history)
    if overworked:
        names = "・".join(_jp_muscle(m) for m in overworked)
        bullets.append(
            f"過去 7 日で {names} を 4 回以上鍛えています。"
            "今日は別の筋群を中心に組んでいます。"
        )
        evidence.append("theme_training_meta_analysis")

    underworked = _muscles_underworked_long(history)
    if underworked and suggested_targets:
        names = "・".join(_jp_muscle(m) for m in suggested_targets)
        bullets.append(
            f"過去 14 日間鍛えていない {names} を本日のターゲットにしています。"
        )
        evidence.append("theme_training_meta_analysis")

    # 4. 痛み報告（安全側）
    pain_high = {r: c for r, c in (history.pain_reports_last_7d or {}).items() if c >= 2}
    if pain_high:
        names = "・".join(_jp_pain_region(r) for r in pain_high.keys())
        bullets.append(
            f"過去 7 日に {names} の痛み報告が複数回ありました。"
            "影響のある種目は除外し、軽負荷で組んでいます。"
        )
        evidence.append("theme_hypertrophy_mechanisms")

    # 5. ストリーク（モチベ）
    if history.streak_days >= 7:
        bullets.append(
            f"連続 {history.streak_days} 日継続中です。今日も習慣の継続を最優先に。"
        )

    if not bullets:
        return None  # 何も特記事項がなければ rationale 自体を出さない

    summary = _build_summary(req, history, split_id, suggested_targets)
    # 雛形 ID も evidence に加える
    program_evidence = _split_to_program_evidence(split_id)
    if program_evidence:
        evidence.append(program_evidence)

    return ProposalRationale(
        summary=summary,
        bullets=bullets[:5],  # 最大 5 件
        evidence_refs=list(dict.fromkeys(evidence)),  # 重複除去
    )


def _build_summary(
    req: WorkoutRequest,
    history: RecentHistorySummary,
    split_id: str,
    suggested_targets: Optional[List[MuscleGroup]],
) -> str:
    """1〜2 文の総括を作る"""
    if suggested_targets:
        names = "・".join(_jp_muscle(m) for m in suggested_targets)
        return f"過去 30 日の記録を見て、今日は{names}中心のメニューを組みました。"
    if _is_returning_from_break(history):
        return "ブランクからの復帰として、無理のない強度・量で組みました。"
    if history.sessions_last_7_days >= 3:
        return "今週はすでにしっかり積み上げています。今日は質を保つメニューです。"
    return "過去 30 日の記録から、今のあなたに合ったメニューを組みました。"


_MUSCLE_JP_MAP: dict[MuscleGroup, str] = {
    MuscleGroup.CHEST: "胸",
    MuscleGroup.BACK: "背中",
    MuscleGroup.SHOULDERS: "肩",
    MuscleGroup.BICEPS: "上腕二頭筋",
    MuscleGroup.TRICEPS: "上腕三頭筋",
    MuscleGroup.QUADS: "大腿四頭筋",
    MuscleGroup.HAMSTRINGS: "ハムストリングス",
    MuscleGroup.GLUTES: "臀部",
    MuscleGroup.CALVES: "ふくらはぎ",
    MuscleGroup.CORE: "体幹",
    MuscleGroup.LEGS: "脚",
    MuscleGroup.FULL_BODY: "全身",
}


def _jp_muscle(m: MuscleGroup) -> str:
    return _MUSCLE_JP_MAP.get(m, m.value)


_PAIN_JP_MAP: dict[str, str] = {
    "knee": "膝",
    "lower_back": "腰",
    "shoulder": "肩",
    "elbow": "肘",
    "wrist": "手首",
    "ankle": "足首",
    "neck": "首",
    "hip": "股関節",
}


def _jp_pain_region(region: str) -> str:
    return _PAIN_JP_MAP.get(region.lower(), region)


def _split_to_program_evidence(split_id: str) -> Optional[str]:
    """雛形 ID を knowledge/programs/ の MD と対応付ける"""
    mapping = {
        "beginner_full_body": "beginner_full_body",
        "intermediate_upper_lower": "intermediate_upper_lower",
        "advanced_ppl_hypertrophy": "advanced_ppl_hypertrophy",
        "strength_block_periodization": "strength_block_periodization",
    }
    return mapping.get(split_id)
