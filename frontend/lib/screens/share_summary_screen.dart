// SNS シェア用の実績サマリ画面（v1.0 で追加）
//
// ユーザーが今日 / 過去 7 日 / 過去 30 日のトレーニング実績をまとめて
// 「自慢できる」形で確認・SNS 共有できる画面。
//
// 機能:
//   - 期間タブで切り替え（今日 / 1 週間 / 1 ヶ月）
//   - 中央のシェア用カード (RepaintBoundary 内) を綺麗にレイアウト
//   - 「画像を保存・シェア」ボタンで:
//     - iOS: Native Share Sheet で Photos / Twitter / LINE 等へ
//     - Web: PNG ファイルとしてダウンロード
//
// AI 表記なし。広告も投稿促進も控えめ。

import 'dart:io' show File;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../main.dart' show AppColors;
import '../services/local_storage_service.dart';

enum _SummaryRange { today, week, month }

class ShareSummaryScreen extends StatefulWidget {
  const ShareSummaryScreen({super.key});

  @override
  State<ShareSummaryScreen> createState() => _ShareSummaryScreenState();
}

class _ShareSummaryScreenState extends State<ShareSummaryScreen> {
  final GlobalKey _cardKey = GlobalKey();
  _SummaryRange _range = _SummaryRange.week;
  ShareSummaryStats? _stats;
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final stats = await LocalStorageService.buildShareSummary();
    if (!mounted) return;
    setState(() => _stats = stats);
  }

  ShareSubStats _currentSub() {
    final s = _stats!;
    switch (_range) {
      case _SummaryRange.today:
        return s.today;
      case _SummaryRange.week:
        return s.week;
      case _SummaryRange.month:
        return s.month;
    }
  }

  String _rangeLabel() {
    switch (_range) {
      case _SummaryRange.today:
        return '今日';
      case _SummaryRange.week:
        return '今週（過去 7 日）';
      case _SummaryRange.month:
        return '今月（過去 30 日）';
    }
  }

  String _rangeShortLabel() {
    switch (_range) {
      case _SummaryRange.today:
        return 'TODAY';
      case _SummaryRange.week:
        return '7 DAYS';
      case _SummaryRange.month:
        return '30 DAYS';
    }
  }

  // ── 画像生成 + 共有 ─────────────────────────────────────────────────
  Future<void> _shareCardAsImage() async {
    if (_processing) return;
    setState(() => _processing = true);
    try {
      final boundary = _cardKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        _toast('画像の生成に失敗しました');
        return;
      }
      final bytes = byteData.buffer.asUint8List();
      final fileName =
          'muscle_mate_${_rangeShortLabel().replaceAll(' ', '_').toLowerCase()}_'
          '${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.png';

      if (kIsWeb) {
        // Web: bytes を直接 XFile.fromData として渡す（内部で blob URL → download anchor）
        await Share.shareXFiles(
          [XFile.fromData(bytes, mimeType: 'image/png', name: fileName)],
          text: '#MuscleMate でトレーニング記録中 💪',
          fileNameOverrides: [fileName],
        );
      } else {
        // モバイル: 一時ファイル → Native Share Sheet
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/$fileName');
        await file.writeAsBytes(bytes);
        await Share.shareXFiles(
          [XFile(file.path, mimeType: 'image/png')],
          text: '#MuscleMate でトレーニング記録中 💪',
        );
      }
    } catch (e) {
      _toast('画像の保存に失敗しました: ${e.runtimeType}');
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  // ── ビルド ───────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('実績をシェア'),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: _stats == null
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : SafeArea(
              child: Column(
                children: [
                  // ── 期間タブ ──────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: SegmentedButton<_SummaryRange>(
                      segments: const [
                        ButtonSegment(
                          value: _SummaryRange.today,
                          label: Text('今日'),
                          icon: Icon(Icons.today, size: 16),
                        ),
                        ButtonSegment(
                          value: _SummaryRange.week,
                          label: Text('1 週間'),
                          icon: Icon(Icons.calendar_view_week, size: 16),
                        ),
                        ButtonSegment(
                          value: _SummaryRange.month,
                          label: Text('1 ヶ月'),
                          icon: Icon(Icons.calendar_view_month, size: 16),
                        ),
                      ],
                      selected: {_range},
                      onSelectionChanged: (v) =>
                          setState(() => _range = v.first),
                      style: ButtonStyle(
                        backgroundColor: WidgetStateProperty.resolveWith(
                          (states) => states.contains(WidgetState.selected)
                              ? AppColors.primary
                              : AppColors.surface,
                        ),
                        foregroundColor: WidgetStateProperty.resolveWith(
                          (states) => states.contains(WidgetState.selected)
                              ? Colors.white
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),

                  // ── シェア用カード本体 ────────────────────────────
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: RepaintBoundary(
                        key: _cardKey,
                        child: _SummaryCard(
                          rangeLabel: _rangeLabel(),
                          rangeShortLabel: _rangeShortLabel(),
                          stats: _currentSub(),
                          streak: _stats!.streak,
                        ),
                      ),
                    ),
                  ),

                  // ── 共有ボタン ────────────────────────────────────
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _processing ? null : _shareCardAsImage,
                          icon: _processing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.ios_share),
                          label: Text(
                            _processing
                                ? '画像を準備中...'
                                : (kIsWeb
                                    ? '画像をダウンロード'
                                    : '画像を保存・シェア'),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SummaryCard
//   キャプチャ対象。9:16 比率に近い縦長カードで Twitter/Instagram でも映える。
//   グラデーション背景 + 大きな数字 + マスコット + ロゴ + 期間ラベル。
// ─────────────────────────────────────────────────────────────────────────────
class _SummaryCard extends StatelessWidget {
  final String rangeLabel;
  final String rangeShortLabel;
  final ShareSubStats stats;
  final int streak;

  const _SummaryCard({
    required this.rangeLabel,
    required this.rangeShortLabel,
    required this.stats,
    required this.streak,
  });

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final df = DateFormat('yyyy.MM.dd', 'ja');
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
          // ── 上部: ロゴ + 期間バッジ ─────────────────────────
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
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
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

          // ── 大見出し ──────────────────────────────────────
          Text(
            rangeLabel,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            stats.sessionCount > 0
                ? '今日も積み上げた。'
                : 'これから積み上げる。',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 22),

          // ── メインの数字（4 マス） ────────────────────────
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  label: 'セッション',
                  value: '${stats.sessionCount}',
                  unit: '日',
                  accent: AppColors.primary,
                  icon: Icons.local_fire_department_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatTile(
                  label: '総ボリューム',
                  value: _formatVolume(stats.totalVolumeKg),
                  unit: 'kg',
                  accent: AppColors.primaryDim,
                  icon: Icons.scale_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  label: '総セット',
                  value: '${stats.totalSets}',
                  unit: 'set',
                  accent: AppColors.secondary,
                  icon: Icons.repeat,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatTile(
                  label: '連続記録',
                  value: '$streak',
                  unit: '日',
                  accent: AppColors.primary,
                  icon: Icons.trending_up,
                ),
              ),
            ],
          ),

          // ── よく頑張った種目 TOP3 ─────────────────────────
          if (stats.topExercises.isNotEmpty) ...[
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.32),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'よく頑張った種目',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.65),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...stats.topExercises.asMap().entries.map(
                        (e) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Center(
                                  child: Text(
                                    '${e.key + 1}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  e.value,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 18),

          // ── フッター: 日付 + ハッシュタグ ────────────────────
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

  String _formatVolume(double v) {
    if (v >= 1000) {
      return (v / 1000).toStringAsFixed(1) + 'k';
    }
    return v.toStringAsFixed(0);
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color accent;
  final IconData icon;
  const _StatTile({
    required this.label,
    required this.value,
    required this.unit,
    required this.accent,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accent, size: 16),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                  ),
                ),
                TextSpan(
                  text: ' $unit',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
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
