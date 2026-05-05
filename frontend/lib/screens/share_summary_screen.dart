// SNS シェア用の実績サマリ画面（v1.0 で追加・物理オブジェクト比較版）
//
// ユーザーが今日 / 過去 7 日 / 過去 30 日に持ち上げた合計重量を、
// 身近な物体の「何個分」に相当するかでビジュアルに表示する。
// 共通の ShareCardView と captureAndShareCard を使う。

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../main.dart' show AppColors;
import '../services/local_storage_service.dart';
import '../services/share_action.dart';
import '../widgets/share_card_view.dart';

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

  Future<void> _share() async {
    if (_processing) return;
    setState(() => _processing = true);
    await captureAndShareCard(
      context: context,
      boundaryKey: _cardKey,
      fileNamePrefix:
          'muscle_mate_${_rangeShortLabel().replaceAll(' ', '_').toLowerCase()}',
    );
    if (mounted) setState(() => _processing = false);
  }

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

                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: RepaintBoundary(
                        key: _cardKey,
                        child: ShareCardView(
                          rangeShortLabel: _rangeShortLabel(),
                          totalVolumeKg: _currentSub().totalVolumeKg,
                          sessionCount: _currentSub().sessionCount,
                          totalSets: _currentSub().totalSets,
                          streak: _stats!.streak,
                        ),
                      ),
                    ),
                  ),

                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _processing ? null : _share,
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
