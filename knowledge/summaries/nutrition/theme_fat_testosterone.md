---
evidence_id: theme_fat_testosterone
title: "脂質摂取とテストステロン（テーマ要約）"
theme: "nutrition_fat"
source_paper_ids:
  - whittaker_2021_low_fat_testosterone
license: "self_authored_secondary_summary"
license_note: "本要約は PubMed 公開の抄録に基づく自作の二次著作物。"
short_summary_ja: "低脂肪食は男性のテストステロンを10-15%低下させる。極端な低脂肪は推奨せず、総脂質エネルギー比20-35%が安全。"
tags: ["nutrition", "fat", "testosterone", "hormone"]
target_goals: ["muscle_gain"]
target_lifts: []
evidence_level: "meta_analysis"
review_status: human_reviewed
reviewer: "tech-team"
review_date: "2026-04-29"
---

## 1. 一行サマリ

**低脂肪食は男性の総テストステロンを 10〜15% 低下させる**（メタ解析）。極端な低脂肪は推奨せず、**総脂質エネルギー比 20〜35%** を保つことで内分泌的に安全。

## 2. 主要な定量的知見（Whittaker 2021 メタ解析）

- **対象**: 6 介入研究、男性 206 名
- **介入**: 低脂肪食群 vs 高脂肪食群
- **結果**: 低脂肪食群の総テストステロンが **10〜15% 低い**（正常範囲内ではあるが）
- **遊離テストステロン・SHBG**: 同様の傾向
- **欧州系男性**でより顕著な低下傾向
- **限界**: RCT 数が少なく、追加研究が必要

## 3. 実用ガイドライン

| 総エネルギー比の脂質 | 評価 |
| --- | --- |
| < 20% | テストステロン低下リスク。減量中でも避ける |
| 20-35% | **推奨範囲**。内分泌・MPS とも安定 |
| > 40% | 個別評価。摂取量が多い場合はタンパク質・炭水化物との配分を検討 |

## 4. ルールエンジン利用時の指示

- `goal == muscle_gain` のメニュー生成時、`general_advice` に「総エネルギーの 20% 以上を脂質から確保」のヒントを含めることを検討
- BIG3 強化（`priority_lift != none`）を狙うユーザーは特に重要（神経筋・内分泌系への影響）
- 体組成計算機能を将来追加する際の基準値として使用

## 5. 適用条件・適用外

- **適用**: 健常成人男性、トレーニング目的
- **配慮**: 飽和脂肪・トランス脂肪は別評価。心血管系既往者は医療助言優先
- **適用外**: 女性・特殊代謝疾患のユーザー（本研究は男性対象）

## 6. 出典

- Whittaker J, Wu K. (2021). Low-fat diets and testosterone in men: Systematic review and meta-analysis of intervention studies. *J Steroid Biochem Mol Biol*. 210:105878. DOI: 10.1016/j.jsbmb.2021.105878
