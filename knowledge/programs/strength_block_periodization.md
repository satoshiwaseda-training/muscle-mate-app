---
program_id: strength_block_periodization
title: BIG3 強化向けブロック周期化（自作）
target_levels: ["intermediate", "advanced"]
target_goals: ["muscle_gain"]
target_lifts: ["bench", "squat", "deadlift"]
days_per_week_min: 3
days_per_week_max: 4
session_duration_minutes: 75
block_weeks: 4
evidence_refs: []
review_status: draft
---

## 概要

BIG3（ベンチ・スクワット・デッドリフト）の重量更新を狙う中〜上級者向けの 4 週ブロック周期化プログラム。商業プログラム（5/3/1 等）を参照せず、ボリューム→強度→ピーク→デロードの一般的な周期化原則のみで構成。

## ブロック構成（4 週）

| 週 | フォーカス | メインセット | 強度 | 補助 |
| --- | --- | --- | --- | --- |
| 1 | ボリューム | 5×5 | 75% 1RM | 通常 |
| 2 | 強度 | 5×3 | 82.5% 1RM | 通常 |
| 3 | ピーク | 3×2〜3 | 87.5% 1RM | 軽め |
| 4 | デロード | 3×3 | 65% 1RM | 軽め |

## ルールエンジン利用時の指示

- `priority_lift in {"bench", "squat", "deadlift"}` かつ `level >= intermediate` で本雛形を選択候補にする。
- ブロックの何週目かは `progression_service` が `SessionLog` から判定（端末側保存）。
- 痛み報告（`safety_flags == ["pain_reported"]`）が出た場合は当該リフトを除外し、§9.2 の advisory に従う。

## 安全配慮

- 87.5% 1RM 以上の重量はバーベル種目で必ずスポッターまたはセーフティバーを使用する旨をコーチングコメントに含める（ルールエンジン側で自動付与）。
- 1 セッションの最大増量は +5kg（コンパウンド）にハードキャップ。

## 出典

本雛形は特定の商業プログラムを参照しておらず、線形周期化・ブロック周期化の一般的合意（ボリューム→強度→ピーク→デロード）に基づく自作。
