---
evidence_id: theme_equipment
title: "フリーウェイト vs マシン（テーマ要約）"
theme: "training_equipment"
source_paper_ids:
  - spennewyn_2008_free_vs_machine
license: "self_authored_secondary_summary"
license_note: "本要約は PubMed 公開の抄録に基づく自作の二次著作物。"
short_summary_ja: "未経験者ではフリーウェイトが筋力・バランス向上で優位。経験者では同等。初心者にはまずフォーム習熟、無理せずマシン併用も可。"
tags: ["training", "equipment", "free_weights", "machines"]
target_goals: ["muscle_gain", "general_fitness"]
target_lifts: []
evidence_level: "RCT"
review_status: human_reviewed
reviewer: "tech-team"
review_date: "2026-04-29"
---

## 1. 一行サマリ

**未経験者では 16 週でフリーウェイトが筋力（+116% vs +58%）とバランス（+245% vs +49%）で優位**。経験者・短期では同等。初心者には**まずフォーム習熟を優先**し、不安があればマシンを併用してもよい。

## 2. 主要な定量的知見（Spennewyn 2008）

- 16 週間 RCT、未経験成人男女
- フリーウェイト群（free-form）vs マシン群（fixed-form）
- **筋力**: フリーウェイト +116% / マシン +58% → **フリーウェイト約 2 倍**
- **バランス**: フリーウェイト +245% / マシン +49% → **大差**
- 機序仮説: 多関節・自由軌道による神経筋協調と体幹安定筋の同時動員

## 3. 実用ガイドライン

| ユーザー特性 | 推奨 |
| --- | --- |
| `level == beginner` | コンパウンドは**フリーウェイト**を優先。フォーム習得まで軽量で。心配ならマシン併用 |
| `level == intermediate` 以上 | フリーウェイトとマシンを目的別に使い分け |
| 高齢・バランスに不安 | スクワットラック内のセーフティバー、またはレッグプレスから開始 |
| 怪我履歴あり | 該当部位はマシンで軌道を制限、痛みなく動かせる範囲で |

## 4. ルールエンジン利用時の指示

- 既存実装の `_choose_split` でレベル別にスプリット選択している
- 初心者向け Full Body はバーベル・ダンベル中心で構成 → **本知見と整合**
- ユーザーの `equipment` に `barbell` が含まれない場合のみマシンに代替（既存実装の対応で OK）
- `safety_flags == ['needs_spotter']` の付与基準: フリーウェイト × ベンチプレス重量 ≥ 80kg または スクワット重量 ≥ 100kg

## 5. 適用条件・適用外

- **適用**: 健常成人、ジムまたはホームジム環境
- **配慮**: スポッター不在環境ではセーフティバー必須
- **適用外**: 急性傷害、術後リハビリ期

## 6. 出典

- Spennewyn KC. (2008). Strength outcomes in fixed versus free-form resistance equipment. *J Strength Cond Res*. 22(1):75-81. DOI: 10.1519/JSC.0b013e31815ef5e7
