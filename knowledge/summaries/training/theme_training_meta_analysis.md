---
evidence_id: theme_training_meta_analysis
title: "訓練変数（負荷・セット数・頻度）の最適化（テーマ要約）"
theme: "training_variables"
source_paper_ids:
  - currier_2023_bjsm_meta_analysis
license: "self_authored_secondary_summary"
license_note: "本要約は CC-BY-NC 4.0 公開論文の抄録に基づく自作の二次著作物。"
short_summary_ja: "高負荷は筋力で優位、肥大は負荷非依存。セット数追加で肥大用量反応、頻度は週2-3で十分。"
tags: ["training", "load", "sets", "frequency", "meta_analysis"]
target_goals: ["muscle_gain"]
target_lifts: []
evidence_level: "bayesian_network_meta_analysis"
review_status: human_reviewed
reviewer: "tech-team"
review_date: "2026-04-29"
---

## 1. 一行サマリ

178 研究 5,097 名のベイジアン NMA。**筋力ゲインは高負荷（>80% 1RM）が優位、肥大は負荷非依存（30〜85%）**。セット数追加で肥大に用量反応的効果、**週 2〜3 回頻度で十分**（それ以上は効率低下）。

## 2. 主要な定量的知見（Currier 2023 BJSM）

### 負荷（Load）
- **筋力**: 高負荷 >> 中負荷 ≈ 低負荷
- **肥大**: 高・中・低負荷で**有意差なし**
- 結論: 1RM を伸ばしたいなら高負荷、肥大狙いなら好きな負荷で OK

### セット数（Sets per session）
- **肥大**: 1 セット < 3 セット < 5 セット（用量反応）
- **筋力**: 同様に多セット優位だが効果サイズは肥大より小
- 推奨: 1 種目あたり **3〜5 セット**

### 頻度（Frequency）
- 同等のボリュームなら週 1〜2 回 ≈ 週 3〜4 回
- 週ボリュームを満たすことが重要、頻度自体は二次的
- 週 2〜3 回 / 筋群が現実的に最適

## 3. 既存ルールエンジンとの整合確認

| 既存実装 | 本知見との整合 |
| --- | --- |
| Beginner Full Body × 週 3 日 | ✅ 各筋群週 3 回 = 適正 |
| Intermediate Upper/Lower × 週 4 | ✅ 各筋群週 2 回 = 適正 |
| Advanced PPL × 週 5-6 | ✅ 各筋群週 2 回 + 高ボリューム |
| メインセット 3〜5 セット | ✅ 推奨範囲内 |
| 70-85% 1RM メイン | ✅ 筋力・肥大両立 |

## 4. ルールエンジン利用時の指示

- 既存実装は本メタ解析と**ほぼ整合済み**、特別な変更不要
- `priority_lift != none` 時は高負荷比率を上げる（既存 strength_block_periodization で対応済）
- セット数をユーザー入力で調整する機能を将来追加する場合、3〜5 を推奨範囲として提示

## 5. 適用条件・適用外

- **適用**: 健常成人（メタ解析対象）
- **適用外**: 高齢者特有のサルコペニア、青年期、医療管理下

## 6. 出典

- Currier BS, McLeod JC, Banfield L, et al. (2023). Resistance training prescription for muscle strength and hypertrophy in healthy adults: a systematic review and Bayesian network meta-analysis. *Br J Sports Med*. 57(18):1211-1220. DOI: 10.1136/bjsports-2023-106807 [CC-BY-NC 4.0]
