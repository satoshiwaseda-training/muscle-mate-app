"""
RAG サービス（計画書 v5 §6.5 §4.3 §5）

段階 A: 静的辞書検索（既定）
- knowledge/summaries/<カテゴリ>/*.md のフロントマターをロード
- review_status: human_reviewed のみインデックス対象
- target_goals / target_lifts でメタデータ事前フィルタ
- 依存ライブラリ追加なし（標準 re モジュールのみ）

段階 B: FAISS 昇格は将来対応（RAG_BACKEND=faiss）。

重要:
- 検索結果（要約本文）は外部 AI へ渡さない（§4.3）
- Flutter にも本文同梱しない（§5.4）
- レスポンスには evidence_id のリストのみ返す
"""
from __future__ import annotations

import os
import re
from pathlib import Path
from typing import Iterable, List, Optional

from src.schemas.workout import Goal, PriorityLift


# ── 設定 ────────────────────────────────────────────────────────────────────

_KNOWLEDGE_ROOT = Path(__file__).resolve().parents[3] / "knowledge" / "summaries"
_FRONT_MATTER = re.compile(r"^---\n(.*?)\n---", re.DOTALL)


def _knowledge_root() -> Path:
    """環境変数 KNOWLEDGE_ROOT で上書き可能"""
    override = os.getenv("KNOWLEDGE_ROOT")
    if override:
        return Path(override)
    return _KNOWLEDGE_ROOT


# ── フロントマターのロード ──────────────────────────────────────────────────

def _parse_front_matter(text: str) -> Optional[dict]:
    """マークダウン先頭の YAML 風フロントマターをパースする。

    依存追加を避けるため、単純な key: value 形式と key: [a, b] 形式のみ対応。
    """
    m = _FRONT_MATTER.match(text)
    if not m:
        return None

    block = m.group(1)
    result: dict = {}
    for line in block.splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if ":" not in line:
            continue
        key, _, value = line.partition(":")
        key = key.strip()
        value = value.strip()
        if value.startswith("[") and value.endswith("]"):
            inner = value[1:-1].strip()
            if not inner:
                result[key] = []
            else:
                items = [
                    s.strip().strip('"').strip("'")
                    for s in inner.split(",")
                ]
                result[key] = [s for s in items if s]
        else:
            value = value.strip('"').strip("'")
            result[key] = value
    return result


def _load_all_summaries(root: Path) -> List[dict]:
    """human_reviewed のフロントマターのみを返す"""
    if not root.exists():
        return []
    summaries: List[dict] = []
    for md in root.rglob("*.md"):
        try:
            text = md.read_text(encoding="utf-8")
        except Exception:
            continue
        fm = _parse_front_matter(text)
        if not fm:
            continue
        if fm.get("review_status") != "human_reviewed":
            continue
        # 必須キー
        eid = fm.get("evidence_id") or md.stem
        fm["evidence_id"] = eid
        summaries.append(fm)
    return summaries


# キャッシュ（プロセスローカル）。Hot reload で更新したい場合は再起動。
_cache: Optional[List[dict]] = None


def _get_cache() -> List[dict]:
    global _cache
    if _cache is None:
        _cache = _load_all_summaries(_knowledge_root())
    return _cache


def reload_cache() -> int:
    """インデックスを再ロード。テストや CLI で利用。"""
    global _cache
    _cache = _load_all_summaries(_knowledge_root())
    return len(_cache)


# ── 検索 ────────────────────────────────────────────────────────────────────

def _matches(summary: dict, goal: Goal, priority_lift: Optional[PriorityLift]) -> bool:
    target_goals = summary.get("target_goals") or []
    target_lifts = summary.get("target_lifts") or []

    goal_ok = (not target_goals) or (goal.value in target_goals)
    if priority_lift and priority_lift != PriorityLift.NONE:
        lift_ok = (not target_lifts) or (priority_lift.value in target_lifts)
    else:
        lift_ok = True
    return goal_ok and lift_ok


def retrieve_evidence_ids(
    goal: Goal,
    priority_lift: Optional[PriorityLift] = None,
    top_k: int = 5,
) -> List[str]:
    """ルールエンジンの種目選定に紐づける根拠論文 ID を返す。

    - メタデータ事前フィルタのみ（静的辞書検索）
    - top_k は安全のため 5 を上限とする
    - サーバー内でのみ使用。外部 AI へ渡してはならない（§4.3）
    """
    top_k = max(1, min(top_k, 5))
    candidates = [
        s for s in _get_cache()
        if _matches(s, goal, priority_lift)
    ]
    # スコアリング: target_goals が直接一致する方を優先
    def _score(s: dict) -> int:
        score = 0
        if goal.value in (s.get("target_goals") or []):
            score += 2
        if priority_lift and priority_lift != PriorityLift.NONE:
            if priority_lift.value in (s.get("target_lifts") or []):
                score += 2
        evidence_level = s.get("evidence_level", "")
        if "meta-analysis" in evidence_level:
            score += 1
        return score

    candidates.sort(key=_score, reverse=True)
    return [c["evidence_id"] for c in candidates[:top_k]]


def retrieve_summaries(
    goal: Goal,
    priority_lift: Optional[PriorityLift] = None,
    top_k: int = 5,
) -> List[dict]:
    """関連エビデンスを { evidence_id, short_summary_ja, theme } の辞書リストで返す。

    rule_engine が `general_advice` 文字列を組み立てる際に使う。
    本文（§2 定量的知見等）はサーバー内のみで参照され、外部 AI には送らない（§4.3）。
    """
    top_k = max(1, min(top_k, 5))
    candidates = [
        s for s in _get_cache()
        if _matches(s, goal, priority_lift)
    ]

    def _score(s: dict) -> int:
        score = 0
        if goal.value in (s.get("target_goals") or []):
            score += 2
        if priority_lift and priority_lift != PriorityLift.NONE:
            if priority_lift.value in (s.get("target_lifts") or []):
                score += 2
        evidence_level = s.get("evidence_level", "")
        if "meta" in evidence_level or "position" in evidence_level:
            score += 1
        return score

    candidates.sort(key=_score, reverse=True)
    candidates.sort(key=_score, reverse=True)
    out: List[dict] = []
    for c in candidates[:top_k]:
        out.append({
            "evidence_id": c["evidence_id"],
            "short_summary_ja": c.get("short_summary_ja", ""),
            "theme": c.get("theme", ""),
        })
    return out
