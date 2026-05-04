// 論文の出典画面（v1.0 で追加）
//
// メニュー提案ロジックの根拠となる論文・プログラム雛形の一覧を表示する。
// 「AI が生成した」のではなく「公開されている研究知見をルールに落とし込んで
// いる」ことを審査担当者・ユーザーに transparent に示すための画面。
//
// 出典本文は knowledge/summaries/ および knowledge/papers/*.metadata.md と
// 同期している（ハードコードだが、登録論文数が少ないため運用で同期可能）。

import 'package:flutter/material.dart';
import '../main.dart' show AppColors;

class CitationsScreen extends StatelessWidget {
  const CitationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('論文の出典'),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── イントロ ──────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.32),
                ),
              ),
              child: const Text(
                'メニュー提案・休息推奨・進行ルールは、以下の査読論文と '
                '一般公開されているプログラム雛形をルール化して運用しています。'
                '提案文には該当する evidence_id を表示します。',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  height: 1.6,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── プログラム雛形 ───────────────────────────────────
            _SectionHeader(
              title: 'プログラム雛形',
              subtitle: 'メニュー骨格の根拠（自作の二次著作物）',
            ),
            _CitationCard(
              evidenceId: 'beginner_full_body',
              title: '初心者向け Full Body プログラム',
              meta: '対象: 初心者 / 週 2〜3 日 / 45 分前後',
              detail: '全身を均等に扱う Full Body スプリット。'
                  'スクワット系・プッシュ系・プル系・補助 1〜2 種目で構成。',
            ),
            _CitationCard(
              evidenceId: 'intermediate_upper_lower',
              title: '中級者向け Upper / Lower プログラム',
              meta: '対象: 中級 / 週 4 日',
              detail: '上半身と下半身を交互に鍛える分割プログラム。'
                  '各部位を週 2 回刺激することで頻度・ボリュームを最適化。',
            ),
            _CitationCard(
              evidenceId: 'advanced_ppl_hypertrophy',
              title: '上級者向け Push / Pull / Legs（筋肥大）',
              meta: '対象: 上級 / 週 5〜6 日 / 筋肥大重視',
              detail: 'プッシュ・プル・脚の 3 分割で高頻度・高ボリュームを実現。'
                  '各筋群を週 2 回刺激。',
            ),
            _CitationCard(
              evidenceId: 'strength_block_periodization',
              title: 'BIG3 強化ブロック周期化',
              meta: '対象: 中級〜上級 / BIG3 強化',
              detail: 'ボリューム期 → 強度期 → ピーク期の 3 ブロック周期化。'
                  'スクワット・ベンチ・デッドリフトの 1RM を計画的に伸ばす。',
            ),

            const SizedBox(height: 24),

            // ── トレーニング変数 ─────────────────────────────────
            _SectionHeader(
              title: 'トレーニング変数（負荷・セット数・頻度）',
              subtitle: '提案最適化の判断材料',
            ),
            _CitationCard(
              evidenceId: 'theme_training_meta_analysis',
              title:
                  'Currier et al. (2023) — Resistance training prescription for muscle strength and hypertrophy',
              meta: 'Br J Sports Med 57(18):1211-1220 / CC-BY-NC 4.0',
              detail: '178 研究 5,097 名のベイジアンネットワーク・メタ解析。'
                  '筋力ゲインは高負荷（>80% 1RM）が優位、肥大は負荷非依存。'
                  'セット数は用量反応的に肥大効果増、頻度は週 2〜3 回が最適。',
              doi: '10.1136/bjsports-2023-106807',
            ),
            _CitationCard(
              evidenceId: 'theme_rest_intervals',
              title: 'Schoenfeld et al. (2016) — Longer interset rest periods',
              meta: 'JSCR / Schoenfeld & Henselmans 2014 review',
              detail: 'コンパウンド種目のセット間休息は 2〜3 分以上が望ましい。'
                  '短すぎる休息はボリューム低下と肥大効果低下を招く。',
            ),
            _CitationCard(
              evidenceId: 'theme_hypertrophy_mechanisms',
              title:
                  'Schoenfeld (2010, 2013) — Mechanisms of muscle hypertrophy',
              meta: 'JSCR 2010 / Sports Med 2013',
              detail: '機械的張力・代謝ストレス・筋損傷の 3 機序による筋肥大の整理。'
                  '安全性確保（重症度の高い怪我部位の除外）の根拠。',
            ),
            _CitationCard(
              evidenceId: 'buresh_2009_rest_interval',
              title:
                  'Buresh et al. (2009) — The effect of resistive exercise rest interval',
              meta: 'JSCR',
              detail: 'セッション間 48 時間の休養が筋タンパク合成と回復に重要。',
            ),
            _CitationCard(
              evidenceId: 'spennewyn_2008_free_vs_machine',
              title:
                  'Spennewyn (2008) — Free weights vs machines',
              meta: 'JSCR',
              detail: 'フリーウェイトとマシンの効果比較。'
                  '使用器具による種目選択ロジックの根拠。',
            ),

            const SizedBox(height: 24),

            // ── 栄養 ─────────────────────────────────────────
            _SectionHeader(
              title: 'タンパク質・栄養',
              subtitle: 'タンパク質計算の根拠',
            ),
            _CitationCard(
              evidenceId: 'jager_2017_issn_protein',
              title:
                  'Jäger et al. (2017) — ISSN Position Stand: Protein and exercise',
              meta: 'JISSN / CC-BY 4.0',
              detail: '体重 1kg あたり 1.4〜2.0g/日のタンパク質摂取が筋肥大・'
                  '回復に有効という ISSN 公式見解。',
              doi: '10.1186/s12970-017-0177-8',
            ),
            _CitationCard(
              evidenceId: 'theme_protein_nutrition',
              title: 'タンパク質摂取量・タイミング（テーマ要約）',
              meta: '複数論文の二次著作物',
              detail: '1 食 20〜40g、就寝前カゼイン、トレ後 30 分以内の'
                  '20g 摂取の効果を統合的に整理。',
            ),
            _CitationCard(
              evidenceId: 'theme_fat_testosterone',
              title: '低脂肪食とテストステロン（テーマ要約）',
              meta: '複数論文の二次著作物',
              detail: '極端な低脂肪食は内因性テストステロンを下げ得る。'
                  '20〜35% の脂質摂取が安全圏。',
            ),

            const SizedBox(height: 24),

            // ── カフェイン ────────────────────────────────────
            _SectionHeader(
              title: 'カフェイン・補助成分',
              subtitle: '時刻別アドバイスの根拠',
            ),
            _CitationCard(
              evidenceId: 'theme_caffeine',
              title:
                  'Hodgson et al. (2013) / Trexler et al. (2016) — Caffeine effects on performance',
              meta: 'PLoS ONE 2013 (CC-BY 4.0) / Eur J Sport Sci 2016',
              detail: 'カフェイン 3〜6 mg/kg のトレ前摂取は持久力・最大筋力に'
                  '有意な向上効果。半減期 5h を考慮した時刻別推奨。',
            ),

            const SizedBox(height: 32),

            // ── 注記・ライセンス ───────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '注記',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '・本アプリのメニュー・進行ルールは上記の査読論文を参考に作成した自作の二次著作物です。'
                    '原著論文の本文は配布しておらず、メタデータと要約のみを参照しています。\n\n'
                    '・本アプリは情報提供を目的としたフィットネス支援であり、'
                    '医療助言・診断・治療を提供するものではありません。\n\n'
                    '・引用条件・ライセンス詳細は GitHub リポジトリの '
                    'knowledge/LICENSES.md を参照してください。',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppColors.textSecond,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _CitationCard extends StatelessWidget {
  final String evidenceId;
  final String title;
  final String meta;
  final String detail;
  final String? doi;
  const _CitationCard({
    required this.evidenceId,
    required this.title,
    required this.meta,
    required this.detail,
    this.doi,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // evidence_id ラベル
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              evidenceId,
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            meta,
            style: const TextStyle(
              color: AppColors.textSecond,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            detail,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 12,
              height: 1.55,
            ),
          ),
          if (doi != null) ...[
            const SizedBox(height: 6),
            Text(
              'DOI: $doi',
              style: const TextStyle(
                color: AppColors.textSecond,
                fontSize: 10,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ],
      ),
    );
  }
}
