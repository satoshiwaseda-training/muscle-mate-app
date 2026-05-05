// SNS シェア用の実績サマリ画面（v1.0 で追加・物理オブジェクト比較版）
//
// ユーザーが今日 / 過去 7 日 / 過去 30 日に持ち上げた合計重量を、
// 身近な物体（自分自身・ゴリラ・車・バス・飛行機・ロケット）の
// 「何個分」に相当するかでビジュアルに表示する。SNS 投稿に映える
// インパクト重視のレイアウト。
//
// AI 表記なし。

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
// Web では blob+anchor で直接ダウンロード。モバイルではスタブ（呼ばれない）
import '../services/web_download_stub.dart'
    if (dart.library.html) '../services/web_download_web.dart';

enum _SummaryRange { today, week, month }

// ─────────────────────────────────────────────────────────────────────────────
// 物理オブジェクト比較データ
//   小 → 大の順で並ぶ。重量は標準的な目安値。
// ─────────────────────────────────────────────────────────────────────────────
class _ComparisonItem {
  final String emoji;
  final String name;
  final double weightKg;
  final String counterUnit; // 「人」「頭」「台」「機」「基」
  const _ComparisonItem({
    required this.emoji,
    required this.name,
    required this.weightKg,
    required this.counterUnit,
  });
}

/// 比較対象リスト（プライバシー配慮で「あなた」は除外）
///
/// 「あなた N 人分」表示は、SNS 投稿時にユーザー本人の体重が
/// 逆算されてしまう（合計 kg ÷ 人数 = 体重）ため意図的に削除。
const List<_ComparisonItem> _comparisonItems = [
  _ComparisonItem(
    emoji: '🐶',
    name: '柴犬',
    weightKg: 10,
    counterUnit: '匹',
  ),
  _ComparisonItem(
    emoji: '🦍',
    name: 'ゴリラ',
    weightKg: 160,
    counterUnit: '頭',
  ),
  _ComparisonItem(
    emoji: '🐎',
    name: 'ウマ',
    weightKg: 500,
    counterUnit: '頭',
  ),
  _ComparisonItem(
    emoji: '🚗',
    name: 'クルマ',
    weightKg: 1500,
    counterUnit: '台',
  ),
  _ComparisonItem(
    emoji: '🐘',
    name: 'ゾウ',
    weightKg: 5000,
    counterUnit: '頭',
  ),
  _ComparisonItem(
    emoji: '🚌',
    name: 'バス',
    weightKg: 12000,
    counterUnit: '台',
  ),
  _ComparisonItem(
    emoji: '🐋',
    name: 'クジラ',
    weightKg: 30000,
    counterUnit: '頭',
  ),
  _ComparisonItem(
    emoji: '✈️',
    name: '飛行機',
    weightKg: 80000,
    counterUnit: '機',
  ),
  _ComparisonItem(
    emoji: '🚀',
    name: 'ロケット',
    weightKg: 500000,
    counterUnit: '基',
  ),
];

/// 持ち上げた合計重量から、表示する 1〜2 件の比較を選ぶ。
///   ・「一番 1 に近いもの」= weight ≤ totalKg を満たす最大の物体
///   ・「その一つ下」= 1 つ軽い物体（複数個に相当する）
/// 両方とも該当しない場合（total が小さすぎる）は最小物体だけ目標として返す。
class _Selected {
  final _ComparisonItem item;
  final int count;
  const _Selected(this.item, this.count);
}

({_Selected? primary, _Selected? secondary, _Selected? aspiration})
    _selectComparisons(double totalKg) {
  const items = _comparisonItems;

  // weight ≤ totalKg を満たす最大インデックス
  var bigIdx = -1;
  for (var i = 0; i < items.length; i++) {
    if (items[i].weightKg <= totalKg) bigIdx = i;
  }

  if (bigIdx < 0) {
    // 最小物体にも満たない → 目標として最小物体を提示
    final lightest = items.first;
    return (primary: null, secondary: null, aspiration: _Selected(lightest, 1));
  }

  final primary = _Selected(
    items[bigIdx],
    (totalKg / items[bigIdx].weightKg).floor(),
  );
  _Selected? secondary;
  if (bigIdx > 0) {
    secondary = _Selected(
      items[bigIdx - 1],
      (totalKg / items[bigIdx - 1].weightKg).floor(),
    );
  }
  return (primary: primary, secondary: secondary, aspiration: null);
}

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
    setState(() {
      _stats = stats;
    });
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
        // Web: blob URL + 隠しアンカーで直接ダウンロード
        // (share_plus の Web 実装は Web Share API に依存しており HTTPS 必須・
        // ブラウザ依存のため、http://localhost:8080 でも確実に動く実装に切替)
        await downloadBytesAsFile(bytes, fileName);
        _toast('画像をダウンロードしました');
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
                  // 期間タブ
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

                  // シェア用カード
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: RepaintBoundary(
                        key: _cardKey,
                        child: _SummaryCard(
                          rangeShortLabel: _rangeShortLabel(),
                          stats: _currentSub(),
                          streak: _stats!.streak,
                        ),
                      ),
                    ),
                  ),

                  // 共有ボタン
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
//   キャプチャ対象。テキストは最小限。合計重量と物理比較に焦点。
// ─────────────────────────────────────────────────────────────────────────────
class _SummaryCard extends StatelessWidget {
  final String rangeShortLabel;
  final ShareSubStats stats;
  final int streak;

  const _SummaryCard({
    required this.rangeShortLabel,
    required this.stats,
    required this.streak,
  });

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final df = DateFormat('yyyy.MM.dd', 'ja');
    final selection = _selectComparisons(stats.totalVolumeKg);

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
                    colors: [
                      AppColors.primaryDim,
                      AppColors.primary,
                    ],
                  ).createShader(rect),
                  child: Text(
                    _formatVolume(stats.totalVolumeKg),
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
            _ComparisonRow(
              primary: selection.primary,
              secondary: selection.secondary,
            )
          else if (selection.aspiration != null)
            _AspirationRow(
              target: selection.aspiration!,
              currentKg: stats.totalVolumeKg,
            ),

          const SizedBox(height: 18),

          // ── 補足情報（コンパクト・期間補足）─────────────
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
                  value: '${stats.sessionCount}日',
                ),
                Container(
                  width: 1,
                  height: 28,
                  color: Colors.white.withValues(alpha: 0.12),
                ),
                _CompactStat(
                  icon: Icons.repeat,
                  label: '総セット',
                  value: '${stats.totalSets}set',
                ),
                Container(
                  width: 1,
                  height: 28,
                  color: Colors.white.withValues(alpha: 0.12),
                ),
                _CompactStat(
                  icon: Icons.trending_up,
                  label: '連続',
                  value: '$streak日',
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── フッター: 日付 + ハッシュタグ ──────────────────
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
    if (v >= 10000) {
      return (v / 1000).toStringAsFixed(1) + 'k';
    }
    if (v >= 1000) {
      // 1,234 形式
      final s = v.toStringAsFixed(0);
      final reversed = s.split('').reversed.join();
      final withCommas = StringBuffer();
      for (var i = 0; i < reversed.length; i++) {
        if (i > 0 && i % 3 == 0) withCommas.write(',');
        withCommas.write(reversed[i]);
      }
      return withCommas.toString().split('').reversed.join();
    }
    return v.toStringAsFixed(0);
  }
}

// 物理オブジェクト 1〜2 件を並べる
class _ComparisonRow extends StatelessWidget {
  final _Selected? primary;
  final _Selected? secondary;
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
  final _Selected selected;
  final bool isPrimary;
  const _ComparisonTile({required this.selected, required this.isPrimary});

  @override
  Widget build(BuildContext context) {
    final accent = isPrimary ? AppColors.primary : AppColors.primaryDim;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: 0.18),
            accent.withValues(alpha: 0.04),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.55), width: 1.5),
      ),
      child: Row(
        children: [
          // 絵文字
          Text(
            selected.item.emoji,
            style: TextStyle(fontSize: isPrimary ? 38 : 30),
          ),
          const SizedBox(width: 14),
          // 名前
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
  final _Selected target;
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
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.32),
        ),
      ),
      child: Row(
        children: [
          Text(
            target.item.emoji,
            style: const TextStyle(fontSize: 30),
          ),
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
  const _CompactStat({
    required this.icon,
    required this.label,
    required this.value,
  });

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
