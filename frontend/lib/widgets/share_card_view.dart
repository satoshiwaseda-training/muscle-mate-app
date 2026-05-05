// シェア用カードの再利用可能な widget
//
// share_summary_screen.dart と workout_result_screen.dart の両方から使われる。
// プライバシー配慮で「あなた N 人分」は含まない（自分の体重が逆算されるため）。

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../main.dart' show AppColors;

// ─────────────────────────────────────────────────────────────────────────────
// 物理オブジェクト比較データ
// ─────────────────────────────────────────────────────────────────────────────
class ComparisonItem {
  final String emoji;
  final String name;
  final double weightKg;
  final String counterUnit;
  const ComparisonItem({
    required this.emoji,
    required this.name,
    required this.weightKg,
    required this.counterUnit,
  });
}

const List<ComparisonItem> kComparisonItems = [
  ComparisonItem(emoji: '🐶', name: '柴犬', weightKg: 10, counterUnit: '匹'),
  ComparisonItem(emoji: '🦍', name: 'ゴリラ', weightKg: 160, counterUnit: '頭'),
  ComparisonItem(emoji: '🐎', name: 'ウマ', weightKg: 500, counterUnit: '頭'),
  ComparisonItem(emoji: '🚗', name: 'クルマ', weightKg: 1500, counterUnit: '台'),
  ComparisonItem(emoji: '🐘', name: 'ゾウ', weightKg: 5000, counterUnit: '頭'),
  ComparisonItem(emoji: '🚌', name: 'バス', weightKg: 12000, counterUnit: '台'),
  ComparisonItem(emoji: '🐋', name: 'クジラ', weightKg: 30000, counterUnit: '頭'),
  ComparisonItem(emoji: '✈️', name: '飛行機', weightKg: 80000, counterUnit: '機'),
  ComparisonItem(emoji: '🚀', name: 'ロケット', weightKg: 500000, counterUnit: '基'),
];

class SelectedComparison {
  final ComparisonItem item;
  final int count;
  const SelectedComparison(this.item, this.count);
}

({SelectedComparison? primary, SelectedComparison? secondary, SelectedComparison? aspiration})
    selectComparisons(double totalKg) {
  const items = kComparisonItems;
  var bigIdx = -1;
  for (var i = 0; i < items.length; i++) {
    if (items[i].weightKg <= totalKg) bigIdx = i;
  }
  if (bigIdx < 0) {
    return (primary: null, secondary: null, aspiration: SelectedComparison(items.first, 1));
  }
  final primary = SelectedComparison(items[bigIdx], (totalKg / items[bigIdx].weightKg).floor());
  SelectedComparison? secondary;
  if (bigIdx > 0) {
    secondary = SelectedComparison(items[bigIdx - 1], (totalKg / items[bigIdx - 1].weightKg).floor());
  }
  return (primary: primary, secondary: secondary, aspiration: null);
}

String formatVolumeKg(double v) {
  if (v >= 10000) return '${(v / 1000).toStringAsFixed(1)}k';
  if (v >= 1000) {
    final s = v.toStringAsFixed(0);
    final reversed = s.split('').reversed.join();
    final buf = StringBuffer();
    for (var i = 0; i < reversed.length; i++) {
      if (i > 0 && i % 3 == 0) buf.write(',');
      buf.write(reversed[i]);
    }
    return buf.toString().split('').reversed.join();
  }
  return v.toStringAsFixed(0);
}

// ─────────────────────────────────────────────────────────────────────────────
// ShareCardView
//   キャプチャ対象のカード本体。RepaintBoundary で囲んで画像化する想定。
// ─────────────────────────────────────────────────────────────────────────────
class ShareCardView extends StatelessWidget {
  /// 「TODAY」「7 DAYS」「30 DAYS」など右上のバッジ
  final String rangeShortLabel;

  /// 期間内の合計重量 (kg)
  final double totalVolumeKg;

  /// 期間内のセッション日数
  final int sessionCount;

  /// 期間内の総セット数
  final int totalSets;

  /// 連続日数
  final int streak;

  const ShareCardView({
    super.key,
    required this.rangeShortLabel,
    required this.totalVolumeKg,
    required this.sessionCount,
    required this.totalSets,
    required this.streak,
  });

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final df = DateFormat('yyyy.MM.dd', 'ja');
    final selection = selectComparisons(totalVolumeKg);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF101719), Color(0xFF1B2225), Color(0xFF101719)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.55),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 上部: ロゴ + 期間バッジ ───────────────────────
          Row(
            children: [
              ClipOval(
                child: Image.asset(
                  'assets/ui/home/home_mascot_character.png',
                  width: 44,
                  height: 44,
                  fit: BoxFit.cover,
                  alignment: Alignment.bottomCenter,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Muscle Mate',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.4,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  rangeShortLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // ── 合計重量（メインビジュアル）─────────────────
          Center(
            child: Column(
              children: [
                Text(
                  '持ち上げた合計重量',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                ShaderMask(
                  shaderCallback: (rect) => const LinearGradient(
                    colors: [AppColors.primaryDim, AppColors.primary],
                  ).createShader(rect),
                  child: Text(
                    formatVolumeKg(totalVolumeKg),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 56,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.5,
                      height: 0.95,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'kg',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),

          // ── 物理オブジェクト比較 ─────────────────────────
          if (selection.primary != null || selection.secondary != null)
            _ComparisonRow(primary: selection.primary, secondary: selection.secondary)
          else if (selection.aspiration != null)
            _AspirationRow(target: selection.aspiration!, currentKg: totalVolumeKg),

          const SizedBox(height: 18),

          // ── 補足情報 ──────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _CompactStat(
                  icon: Icons.local_fire_department_outlined,
                  label: 'セッション',
                  value: '$sessionCount日',
                ),
                Container(width: 1, height: 28, color: Colors.white.withValues(alpha: 0.12)),
                _CompactStat(
                  icon: Icons.repeat,
                  label: '総セット',
                  value: '${totalSets}set',
                ),
                Container(width: 1, height: 28, color: Colors.white.withValues(alpha: 0.12)),
                _CompactStat(
                  icon: Icons.trending_up,
                  label: '連続',
                  value: '$streak日',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── フッター ──────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                df.format(today),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '#MuscleMate',
                style: TextStyle(
                  color: AppColors.primary.withValues(alpha: 0.85),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ComparisonRow extends StatelessWidget {
  final SelectedComparison? primary;
  final SelectedComparison? secondary;
  const _ComparisonRow({this.primary, this.secondary});

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    if (primary != null) items.add(_ComparisonTile(selected: primary!, isPrimary: true));
    if (secondary != null) {
      if (items.isNotEmpty) items.add(const SizedBox(height: 10));
      items.add(_ComparisonTile(selected: secondary!, isPrimary: false));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: items);
  }
}

class _ComparisonTile extends StatelessWidget {
  final SelectedComparison selected;
  final bool isPrimary;
  const _ComparisonTile({required this.selected, required this.isPrimary});

  @override
  Widget build(BuildContext context) {
    final accent = isPrimary ? AppColors.primary : AppColors.primaryDim;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accent.withValues(alpha: 0.18), accent.withValues(alpha: 0.04)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.55), width: 1.5),
      ),
      child: Row(
        children: [
          Text(selected.item.emoji, style: TextStyle(fontSize: isPrimary ? 38 : 30)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  selected.item.name,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 2),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '${selected.count}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isPrimary ? 32 : 24,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                        ),
                      ),
                      TextSpan(
                        text: ' ${selected.item.counterUnit}分',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isPrimary ? 16 : 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AspirationRow extends StatelessWidget {
  final SelectedComparison target;
  final double currentKg;
  const _AspirationRow({required this.target, required this.currentKg});

  @override
  Widget build(BuildContext context) {
    final remaining = (target.item.weightKg - currentKg).clamp(0, double.infinity);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.32)),
      ),
      child: Row(
        children: [
          Text(target.item.emoji, style: const TextStyle(fontSize: 30)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${target.item.name} 1 ${target.item.counterUnit}分まで',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'あと ${remaining.toStringAsFixed(0)} kg',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _CompactStat({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: AppColors.primary),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}
