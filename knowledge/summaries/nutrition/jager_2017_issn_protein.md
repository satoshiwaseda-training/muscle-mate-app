---
evidence_id: jager_2017_issn_protein
title: "International Society of Sports Nutrition Position Stand: protein and exercise"
authors: ["Jäger R.", "Kerksick C.M.", "Campbell B.I.", "Cribb P.J.", "Wells S.D.", "Skwiat T.M.", "Purpura M.", "Ziegenfuss T.N.", "Ferrando A.A.", "Arent S.M.", "Smith-Ryan A.E.", "Stout J.R.", "Arciero P.J.", "Ormsbee M.J.", "Taylor L.W.", "Wilborn C.D.", "Kalman D.S.", "Kreider R.B.", "Willoughby D.S.", "Hoffman J.R.", "Krzykowski J.L.", "Antonio J."]
year: 2017
journal: "Journal of the International Society of Sports Nutrition"
doi: "10.1186/s12970-017-0177-8"
license: "CC-BY-4.0"
source_url: "https://jissn.biomedcentral.com/articles/10.1186/s12970-017-0177-8"
short_summary_ja: "運動者の総タンパク質は1.4〜2.0g/kg/日、各食0.25〜0.4g/kgが目安。ISSN公式ポジション。"
tags: ["nutrition", "protein", "position_stand"]
target_goals: ["muscle_gain"]
target_lifts: []
evidence_level: "position_stand"
review_status: human_reviewed
reviewer: "tech-team"
review_date: "2026-04-29"
---

## 1. 一行サマリ（自作）

ISSN（国際スポーツ栄養学会）公式ポジション。運動者は **総タンパク質 1.4〜2.0 g/kg/日** が筋肥大・回復の最適範囲で、**1 食あたり 0.25〜0.40 g/kg（または 20〜40g）を 3〜4 時間ごと**に分配することが望ましい。

## 2. 主要な定量的知見（ライセンス CC-BY-4.0 のため出典明記の上で要点を記載）

- **総量**: 運動者は健常人推奨（0.8 g/kg/日）の倍以上が必要。1.4〜2.0 g/kg/日を推奨。
- **1 食あたり**: 0.25〜0.40 g/kg、または 20〜40 g。20 g 未満では完全に MPS（筋タンパク合成）が刺激されない可能性。
- **タイミング**: 運動前後 2 時間以内が窓として推奨されるが、24 時間の総摂取量がより重要。
- **分配**: 3〜4 時間ごとに分けて摂取することで、24 時間の MPS を最大化。
- **ソース**: 完全タンパク（必須アミノ酸を全て含む）。ホエイは leucine 含量が高く即時 MPS 刺激に優れる。
- **就寝前**: カゼイン 30〜40 g の摂取は夜間の MPS と回復を促進。

## 3. 適用条件・適用外

- **適用**: 健常成人、レジスタンストレーニング・耐久系・複合系の運動者。
- **適用外**: 腎機能障害、特殊医療食の対象者。妊娠・授乳期は別途医療助言。
- **個人差**: 高齢者（>50歳）では anabolic resistance により上限寄り（2.0 g/kg/日）が望ましい場合あり。

## 4. ルールエンジン利用時の指示

- 適用フラグ: `goal == muscle_gain` または `goal == general_fitness` 時に `general_advice` の食事項目に反映可能。
- 推奨アクション:
  - メニュー生成時、`general_advice` に「目安として 1 食あたり 20〜40g のタンパク質、3〜4 時間ごと」と添える。
  - サンプル計算は `body_weight_kg` 入力がある場合のみ（任意フィールドのため未入力なら一般値）。
- **重要**: 上記知見は **外部 AI には送信しない**（計画書 §4.3）。`evidence_refs` に `jager_2017_issn_protein` を入れるだけで、Flutter は `assets/evidence_index.json` から表示メタを引く。

## 5. 出典

Jäger R, Kerksick CM, Campbell BI, Cribb PJ, Wells SD, Skwiat TM, et al. (2017). International Society of Sports Nutrition Position Stand: protein and exercise. *J Int Soc Sports Nutr*. 14:20. DOI: [10.1186/s12970-017-0177-8](https://doi.org/10.1186/s12970-017-0177-8)

License: CC-BY-4.0（出典明記により本要約 MD を再配布可）
