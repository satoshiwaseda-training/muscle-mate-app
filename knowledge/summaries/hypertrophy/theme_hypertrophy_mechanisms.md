---
evidence_id: theme_hypertrophy_mechanisms
title: "筋肥大のメカニズムと負荷・ボリューム設計（テーマ要約）"
theme: "hypertrophy"
source_paper_ids:
  - schoenfeld_2010_mechanisms
  - schoenfeld_2013_metabolic_stress
  - mitchell_2012_load_hypertrophy
  - west_phillips_2012_hormones
license: "self_authored_secondary_summary"
license_note: "本要約は PubMed 公開の抄録および当社チームの解釈に基づく自作の二次著作物。原文の転載は含まない。"
short_summary_ja: "筋肥大は機械的張力が主要因。週ボリュームが用量反応的に効く。低負荷でも追い込めば肥大は同等。系統ホルモンは予測因子にならない。"
tags: ["hypertrophy", "volume", "load", "mechanism"]
target_goals: ["muscle_gain"]
target_lifts: []
evidence_level: "narrative_review_synthesis"
review_status: human_reviewed
reviewer: "tech-team"
review_date: "2026-04-29"
---

## 1. 一行サマリ

**筋肥大は機械的張力（mechanical tension）が主因**。週ボリューム（セット数）が用量反応的に効き、各筋群あたり週 10 セット以上を目安とする。**負荷は 30%〜85% 1RM の幅で、追い込めば肥大効果は同等**。系統ホルモン（テストステロン・GH・IGF-1）の急性上昇は肥大予測因子にならない。

## 2. 主要な定量的知見（抄録および公開情報ベース）

### 機械的張力・代謝ストレス・筋ダメージ（Schoenfeld 2010, 2013）
- 筋肥大の三大刺激: 機械的張力 / 代謝ストレス / 筋ダメージ
- 機械的張力が最も重要。代謝ストレスは補助的役割（細胞膨張、線維動員、myokine 放出）
- 筋ダメージは結果であり目的ではない

### 負荷と肥大（Mitchell 2012）
- 30% 1RM × 失敗まで vs 80% 1RM × 失敗まで → **筋肥大に有意差なし**
- 30% 群: +6.8%、80%×3 セット群: +7.2%（MRI 計測）
- ただし**最大筋力**は高負荷群で優位

### 系統ホルモンの限界（West & Phillips 2012）
- 12 週間 RT 中の急性 GH/T/IGF-1 上昇 ≠ 筋肥大・筋力ゲインと**相関なし**（n=56）
- 「ホルモン狙いで短休息」は理論的に弱い

## 3. ルールエンジン利用時の指示

| 条件 | アクション |
| --- | --- |
| `goal == muscle_gain` | 各筋群の**週ボリューム ≥ 10 セット**を満たすようスプリットを構成 |
| 上限 | 週 18〜20 セット/筋群を超えない（過剰ボリュームでの停滞回避） |
| 負荷 | 70〜85% 1RM をメインセットに据え、補助種目は 8〜15 レップ |
| 失敗回数 | 全セット failure 必須ではない。`RIR 1〜3` で停止可 |
| 短休息戦略 | ホルモン狙いの 30〜60 秒休息は**推奨しない**（§rest_intervals 参照） |

## 4. 適用条件・適用外

- **適用**: 健常成人、初〜上級者
- **配慮**: 高齢者は anabolic resistance のため上限ボリューム寄り
- **適用外**: 急性傷害期、医療管理下のケース

## 5. 出典

- Schoenfeld BJ. (2010). The Mechanisms of Muscle Hypertrophy and Their Application to Resistance Training. *J Strength Cond Res*. 24(10):2857-2872. DOI: 10.1519/JSC.0b013e3181e840f3
- Schoenfeld BJ. (2013). Potential Mechanisms for a Role of Metabolic Stress in Hypertrophic Adaptations. *Sports Med*. 43(3):179-194. DOI: 10.1007/s40279-013-0017-1
- Mitchell CJ et al. (2012). Resistance exercise load does not determine training-mediated hypertrophic gains in young men. *J Appl Physiol*. 113(1):71-77. DOI: 10.1152/japplphysiol.00307.2012
- West DWD, Phillips SM. (2012). Associations of exercise-induced hormone profiles and gains in strength and hypertrophy. *Eur J Appl Physiol*. 112(7):2693-2702. DOI: 10.1007/s00421-011-2246-z
