---
program_id: advanced_ppl_hypertrophy
title: 上級者向け Push / Pull / Legs（筋肥大）
target_levels: ["advanced"]
target_goals: ["muscle_gain"]
days_per_week_min: 5
days_per_week_max: 6
session_duration_minutes: 75
evidence_refs: []
review_status: draft
---

## 概要

週 5〜6 日で Push（胸・肩・三頭）／Pull（背中・二頭）／Legs を回す上級者向け筋肥大プログラム。

## ルール

- 週 6 日例: 月 Push / 火 Pull / 水 Legs / 木 Push / 金 Pull / 土 Legs / 日 休
- 各筋群を週 2 回叩き、週間ボリューム 12〜18 セット／筋群。
- メインセット強度は 70〜85% 1RM の範囲で日替わり（ヘビー／ライト）。
- 4 週ごとにデロード週（重量 -10%、ボリューム -30%）を必ず挿入。

## サンプル: Push 日（ヘビー）

| 種目 | セット | レップ | 強度 |
| --- | --- | --- | --- |
| ベンチプレス | 4 | 5-7 | 82.5% 1RM |
| インクラインダンベルプレス | 4 | 8-10 | 72% 1RM |
| オーバーヘッドプレス | 3 | 6-8 | 75% 1RM |
| サイドレイズ | 3 | 12-15 | — |
| トライセプスエクステンション | 3 | 10-12 | — |
| プッシュダウン | 3 | 12-15 | — |

## ルールエンジン利用時の指示

- `level == "advanced"` かつ `goal == "muscle_gain"` かつ `days_per_week >= 5` で本雛形を選択。
- 4 週ごとのデロード判定を `progression_service` 側で実施。
- 怪我履歴が指定された場合は該当部位の主動筋種目を除外し、`safety_flags` を立てる。

## 出典

本雛形は特定の商業プログラムを参照しておらず、PPL 分割の一般的知見と週ボリューム 10+ セット／筋群の文献的合意に基づく自作。
