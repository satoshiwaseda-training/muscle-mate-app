---
evidence_id: theme_rest_intervals
title: "セット間休息時間（テーマ要約）"
theme: "training_rest"
source_paper_ids:
  - buresh_2009_rest_interval
  - schoenfeld_2016_longer_rest
  - henselmans_schoenfeld_2014_rest_intervals_review
license: "self_authored_secondary_summary"
license_note: "本要約は PubMed 公開の抄録に基づく自作の二次著作物。"
short_summary_ja: "短休息ホルモン狙い説は否定された。コンパウンドは2-3分以上、アイソレーションは1-2分が肥大・筋力ともに最適。"
tags: ["training", "rest_interval", "hypertrophy", "strength"]
target_goals: ["muscle_gain", "general_fitness"]
target_lifts: []
evidence_level: "review_plus_RCT"
review_status: human_reviewed
reviewer: "tech-team"
review_date: "2026-04-29"
---

## 1. 一行サマリ

「**短休息でホルモン上昇 → 肥大**」という仮説は**実証されず**。**コンパウンド種目は 2〜3 分以上、アイソレーションは 1〜2 分**が肥大・筋力の双方に最適。短休息は同等以下、かつボリューム達成の妨げ。

## 2. 主要な定量的知見

### 短休息のホルモン優位は持続しない（Buresh 2009）
- 1 分休息群 vs 2.5 分休息群、10 週間 RT
- 1 週目は**短休息群でホルモン応答が大きい**
- ただし**5 週目までに差が消失、10 週目には完全消失**
- **筋力・筋断面積のゲインに群間差なし**

### 長休息は肥大・筋力で優位（Schoenfeld 2016）
- 1 分 vs 3 分休息、8 週間、経験者男性
- **3 分群が筋力（ベンチ・スクワット 1RM）と前太腿厚で優位**
- 上腕屈筋・三頭筋にも長休息傾向あり
- 1 分群はメインセットでのレップ数減少が原因と推察

### システマティックレビュー（Henselmans & Schoenfeld 2014）
- 異なる休息時間で長期肥大を比較した研究のうち、**短休息が優位だった研究はゼロ**
- 1 件は逆に長休息優位を報告
- 1 分未満の短休息は GH 急性上昇 + テストステロン/コルチゾール比低下を伴うが、長期的肥大には寄与しない

## 3. 推奨休息時間表（ルールエンジン用・既存実装と整合）

| 種目分類 | 推奨休息（秒） | 根拠 |
| --- | --- | --- |
| コンパウンド（BIG3、ロウ、プレス系） | **180** | 高ボリュームを達成するため |
| 大筋群アイソレーション（ラットプル、レッグプレス等） | 120 | 中間値 |
| 中筋群アイソレーション（カール、エクステンション） | 90 | 部分回復で十分 |
| 小筋群アイソレーション（フェイスプル、サイドレイズ） | 60 | 短休息でも質が落ちにくい |
| 体幹・補助 | 30〜60 | 軽負荷 |

## 4. ルールエンジン利用時の指示

- 既存実装の `rest_seconds` 設定（180/120/90/60）を**継続維持**
- 「ホルモン狙いの短休息」を採用しない（誤指導の防止）
- ユーザーが「時間がない」を選択した場合のみ短休息を提案するが、**ボリューム達成可能性が下がる旨を `general_advice` に明示**

## 5. 適用条件・適用外

- **適用**: 健常成人、肥大・筋力目的
- **適用外**: 持久力・代謝コンディショニング目的（こちらは短休息サーキットが有効）

## 6. 出典

- Buresh R, Berg K, French J. (2009). The effect of resistive exercise rest interval on hormonal response, strength, and hypertrophy with training. *J Strength Cond Res*. 23(1):62-71. DOI: 10.1519/JSC.0b013e318185f14a
- Schoenfeld BJ, Pope ZK, Benik FM, et al. (2016). Longer Interset Rest Periods Enhance Muscle Strength and Hypertrophy in Resistance-Trained Men. *J Strength Cond Res*. 30(7):1805-1812. DOI: 10.1519/JSC.0000000000001272
- Henselmans M, Schoenfeld BJ. (2014). The Effect of Inter-Set Rest Intervals on Resistance Exercise-Induced Muscle Hypertrophy. *Sports Med*. 44(12):1635-1643. DOI: 10.1007/s40279-014-0228-0
