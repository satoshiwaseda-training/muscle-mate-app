---
evidence_id: theme_protein_nutrition
title: "タンパク質摂取量・分配・ソース（テーマ要約）"
theme: "nutrition_protein"
source_paper_ids:
  - jager_2017_issn_protein
  - moore_2009_protein_dose_response
  - macnaughton_2016_40g_vs_20g_whey
  - schoenfeld_2018_protein_per_meal
  - van_vliet_2017_whole_egg
  - elliot_2006_milk_mps
  - bagheri_2021_egg_vs_white
license: "self_authored_secondary_summary"
license_note: "本要約は PubMed 公開の抄録および ISSN 公式ポジション（CC-BY-4.0）に基づく自作の二次著作物。"
short_summary_ja: "総量1.4-2.0g/kg/日、各食0.4g/kg、3-4時間ごと分配。全身トレでは40gで20gより優位。卵黄あり・乳製品も有効。"
tags: ["nutrition", "protein", "MPS", "distribution"]
target_goals: ["muscle_gain", "general_fitness"]
target_lifts: []
evidence_level: "position_stand_plus_meta"
review_status: human_reviewed
reviewer: "tech-team"
review_date: "2026-04-29"
---

## 1. 一行サマリ

運動者の**総タンパク質は 1.4〜2.0 g/kg/日**、**1 食あたり 0.4 g/kg（または 20〜40 g）を 3〜4 時間ごと**に分配。**全身レジスタンス運動後は 40 g が 20 g より MPS で優位**。卵黄ありの全卵、牛乳もホエイ同等に有効。

## 2. 主要な定量的知見

### 総量と分配（Jäger 2017 ISSN, Schoenfeld 2018）
- **総量**: 1.4〜2.0 g/kg/日（運動者）、健常人推奨（0.8 g/kg/日）の倍以上
- **1 食あたり**: 0.25〜0.40 g/kg、または 20〜40 g
- **頻度**: 3〜4 時間ごと、1 日 4 食以上推奨
- **就寝前**: カゼイン 30〜40 g で夜間 MPS と回復を促進
- **タイミング**: 運動前後 2 時間以内が望ましいが、24 時間総量がより重要

### MPS 飽和点（Moore 2009）
- 単一筋群運動後: **20 g で MPS が最大化**、それ以上は酸化に回る
- ロイシン豊富な完全タンパクが効率的

### 全身運動の例外（Macnaughton 2016）
- **全身 RT 後は 40 g が 20 g より MPS 優位**（差 +20%）
- ホエイ 40 g、特に 80kg 級以上の被験者で顕著
- 全身運動は筋活性面積が広く、20g 上限ルールは個別種目時のもの

### 食品ソース比較
- **全卵 vs 卵白**（Van Vliet 2017）: 等窒素量で全卵が **MPS +40%** 優位。卵黄の脂質・栄養素が anabolic に寄与
- **全卵 vs 卵白 12 週 RCT**（Bagheri 2021）: 筋量に有意差なし。**握力・脚筋力は全卵群が優位**
- **牛乳**（Elliot 2006）: RT 後の摂取で正味 MPS 刺激（フェニルアラニン取込み増）。全脂乳・無脂乳ともに有効

## 3. 体重別の実用換算（ルールエンジン用）

| 体重 | 総量目安/日 | 1 食目安 | 4 食/日の場合 |
| --- | --- | --- | --- |
| 50kg | 70-100g | 20g | 4×20g |
| 60kg | 84-120g | 24g | 4×24g |
| 70kg | 98-140g | 28g | 4×28g |
| 80kg | 112-160g | 32g | 4×32g |
| 90kg | 126-180g | 36g | 4×36g |

## 4. ルールエンジン利用時の指示

| 条件 | アクション |
| --- | --- |
| `goal == muscle_gain` | `general_advice` に「1 食 20-40g、3-4 時間ごと」を含める |
| `body_weight_kg` 入力あり | 上表から個別値を計算して提示 |
| 全身トレ日 | 運動後タンパク質目安を **0.5 g/kg（〜40g）** に引き上げ |
| 就寝前 | カゼインまたは緩消化タンパク 30-40g を案内（任意） |

## 5. 適用条件・適用外

- **適用**: 健常成人、レジスタンス・耐久・複合トレ
- **配慮**: 高齢者（>50 歳）は上限寄り（2.0 g/kg/日）
- **適用外**: 腎機能障害、特殊医療食対象者、妊娠・授乳期

## 6. 出典

- Jäger R, Kerksick CM, Campbell BI, et al. (2017). ISSN Position Stand: protein and exercise. *J Int Soc Sports Nutr*. 14:20. DOI: 10.1186/s12970-017-0177-8 [CC-BY-4.0]
- Moore DR, Robinson MJ, Fry JL, et al. (2009). Ingested protein dose response of muscle and albumin protein synthesis after resistance exercise in young men. *Am J Clin Nutr*. 89(1):161-168. DOI: 10.3945/ajcn.2008.26401
- Macnaughton LS, Wardle SL, Witard OC, et al. (2016). The response of muscle protein synthesis following whole-body resistance exercise is greater following 40 g than 20 g of ingested whey protein. *Physiol Rep*. 4(15):e12893. DOI: 10.14814/phy2.12893
- Schoenfeld BJ, Aragon AA. (2018). How much protein can the body use in a single meal for muscle-building? *J Int Soc Sports Nutr*. 15:10. DOI: 10.1186/s12970-018-0215-1
- Van Vliet S, Shy EL, Sawan SA, et al. (2017). Consumption of whole eggs promotes greater stimulation of postexercise muscle protein synthesis. *Am J Clin Nutr*. 106(6):1401-1412. DOI: 10.3945/ajcn.117.159855
- Elliot TA, Cree MG, Sanford AP, et al. (2006). Milk ingestion stimulates net muscle protein synthesis following resistance exercise. *Med Sci Sports Exerc*. 38(4):667-674. DOI: 10.1249/01.mss.0000210190.64458.25
- Bagheri R, Moghadam BH, Ashtary-Larky D, et al. (2021). Whole egg vs egg white ingestion during 12 weeks of resistance training. *J Strength Cond Res*. 35(2):411-419. DOI: 10.1519/JSC.0000000000003922
