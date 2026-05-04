"""
knowledge/summaries/*.md（review_status: human_reviewed）から
frontend/assets/evidence_index.json を生成する（計画書 v5 §5.4）。

許可スキーマのみ出力する:
  evidence_id, title, authors, year, doi, license, source_url, short_summary_ja

要約マークダウン本文や定量的知見は **同梱しない**（外部 AI へも渡さない契約）。

実行方法:
  cd backend
  python scripts/papers/build_evidence_index.py
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from typing import List


REPO_ROOT = Path(__file__).resolve().parents[3]
SUMMARIES = REPO_ROOT / "knowledge" / "summaries"
OUTPUT = REPO_ROOT / "frontend" / "assets" / "evidence_index.json"

ALLOWED_KEYS = {
    "evidence_id",
    "title",
    "authors",
    "year",
    "doi",
    "license",
    "source_url",
    "short_summary_ja",
}

_FRONT_MATTER = re.compile(r"^---\n(.*?)\n---", re.DOTALL)


def _parse_front_matter(text: str) -> dict | None:
    m = _FRONT_MATTER.match(text)
    if not m:
        return None
    block = m.group(1)
    out: dict = {}
    for line in block.splitlines():
        line = line.strip()
        if not line or line.startswith("#") or ":" not in line:
            continue
        k, _, v = line.partition(":")
        k = k.strip()
        v = v.strip()
        if v.startswith("[") and v.endswith("]"):
            inner = v[1:-1].strip()
            out[k] = (
                [s.strip().strip('"').strip("'") for s in inner.split(",") if s.strip()]
                if inner
                else []
            )
        else:
            out[k] = v.strip('"').strip("'")
    return out


def _coerce(fm: dict) -> dict:
    """許可スキーマに整形。許可外のキーは絶対に含めない。"""
    obj = {
        "evidence_id": fm.get("evidence_id", ""),
        "title": fm.get("title", ""),
        "authors": fm.get("authors") or [],
        "year": int(fm["year"]) if fm.get("year", "").isdigit() else fm.get("year"),
        "doi": fm.get("doi", ""),
        "license": fm.get("license", ""),
        "source_url": fm.get("source_url", ""),
        "short_summary_ja": fm.get("short_summary_ja", ""),
    }
    # 不正なキーが万が一混入しても弾く
    return {k: v for k, v in obj.items() if k in ALLOWED_KEYS}


def build() -> int:
    if not SUMMARIES.exists():
        print(f"[INFO] {SUMMARIES} が存在しません。空の index を生成します。")
    entries: List[dict] = []
    if SUMMARIES.exists():
        for md in SUMMARIES.rglob("*.md"):
            try:
                fm = _parse_front_matter(md.read_text(encoding="utf-8"))
            except Exception as e:
                print(f"[WARN] {md} のパースに失敗: {e}")
                continue
            if not fm:
                continue
            if fm.get("review_status") != "human_reviewed":
                continue
            if not fm.get("evidence_id"):
                fm["evidence_id"] = md.stem
            entries.append(_coerce(fm))

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(
        json.dumps(entries, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )

    # 安全側スキーマ検査
    for e in entries:
        bad = set(e.keys()) - ALLOWED_KEYS
        if bad:
            print(f"[ERROR] 許可外キーを検出: {bad}", file=sys.stderr)
            return 1

    print(f"[OK] {len(entries)} 件の evidence を {OUTPUT} に出力しました")
    return 0


if __name__ == "__main__":
    raise SystemExit(build())
