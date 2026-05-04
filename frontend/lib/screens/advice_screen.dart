// アドバイス画面（純ルールベース・コスト 0）
//
// 設定画面で保存された情報（goal/level/equipment/big3_max/body_weight_kg/age 等）を
// /workout/advice に送り、個別化されたカード群を表示する。
//
// - severity 別の配色（info/tip/warning）
// - evidence_refs を assets/evidence_index.json から論文タイトルとして表示
// - 出典 URL タップで端末ブラウザで開く（外部リンクは url_launcher で実装、最低限はテキスト表示のみ）

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart' show AppColors;
import '../models/advice.dart';
import '../models/workout_plan.dart';
import '../services/api_service.dart';
import '../services/evidence_index_service.dart';
import '../services/local_storage_service.dart';

class AdviceScreen extends StatefulWidget {
  const AdviceScreen({super.key});

  @override
  State<AdviceScreen> createState() => _AdviceScreenState();
}

class _AdviceScreenState extends State<AdviceScreen> {
  bool _loading = true;
  AdviceResponse? _response;
  Map<String, EvidenceMeta> _evidenceMeta = const {};
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorMsg = null;
    });

    final settings = await LocalStorageService.loadSettings();
    final equipmentList =
        (settings['equipment'] as List<dynamic>?) ?? const ['barbell'];
    final big3Map = <String, dynamic>{};
    if (settings['bench_press_max'] != null) {
      big3Map['bench_press_max'] = settings['bench_press_max'];
    }
    if (settings['squat_max'] != null) {
      big3Map['squat_max'] = settings['squat_max'];
    }
    if (settings['deadlift_max'] != null) {
      big3Map['deadlift_max'] = settings['deadlift_max'];
    }

    final request = WorkoutRequest(
      goal: Goal.fromValue(
          settings['preferred_goal'] as String? ?? Goal.general.value),
      level:
          Level.fromValue(settings['level'] as String? ?? Level.beginner.value),
      daysPerWeek: 3,
      sessionDurationMinutes:
          (settings['session_duration_minutes'] as num?)?.toInt() ?? 45,
      equipment:
          equipmentList.map((e) => Equipment.fromValue(e as String)).toList(),
      big3Max: big3Map.isEmpty
          ? null
          : Big3Max(
              benchPressMax:
                  (big3Map['bench_press_max'] as num?)?.toDouble(),
              squatMax: (big3Map['squat_max'] as num?)?.toDouble(),
              deadliftMax: (big3Map['deadlift_max'] as num?)?.toDouble(),
            ),
      bodyWeightKg: (settings['body_weight_kg'] as num?)?.toDouble(),
      age: (settings['age'] as num?)?.toInt(),
    );

    final results = await Future.wait([
      ApiService.getAdvice(request),
      EvidenceIndexService.load(),
    ]);
    final adviceRes = results[0] as AdviceResponse;
    final meta = results[1] as Map<String, EvidenceMeta>;

    if (!mounted) return;
    setState(() {
      _loading = false;
      _response = adviceRes;
      _evidenceMeta = meta;
      _errorMsg = adviceRes.success ? null : adviceRes.errorMessage;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('今日のアドバイス'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '更新',
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (_errorMsg != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  color: Colors.redAccent, size: 48),
              const SizedBox(height: 12),
              Text(
                _errorMsg!,
                style: const TextStyle(color: AppColors.textPrimary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _load,
                child: const Text('再試行'),
              ),
            ],
          ),
        ),
      );
    }
    final cards = _response?.cards ?? const [];
    if (cards.isEmpty) {
      return const Center(
        child: Text('表示できるアドバイスがありません',
            style: TextStyle(color: AppColors.textSecond)),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: cards.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) =>
            _AdviceCardWidget(card: cards[i], evidenceMeta: _evidenceMeta),
      ),
    );
  }
}

class _AdviceCardWidget extends StatelessWidget {
  final AdviceCard card;
  final Map<String, EvidenceMeta> evidenceMeta;

  const _AdviceCardWidget({required this.card, required this.evidenceMeta});

  Color get _accentColor {
    switch (card.severity) {
      case AdviceSeverity.warning:
        return Colors.orange;
      case AdviceSeverity.tip:
        return AppColors.primary;
      case AdviceSeverity.info:
        return AppColors.primaryDim;
    }
  }

  IconData get _icon {
    switch (card.category) {
      case AdviceCategory.proteinIntake:
        return Icons.egg_outlined;
      case AdviceCategory.fatBalance:
        return Icons.opacity;
      case AdviceCategory.caffeineTiming:
        return Icons.local_cafe_outlined;
      case AdviceCategory.restInterval:
        return Icons.timer_outlined;
      case AdviceCategory.equipmentGuidance:
        return Icons.fitness_center;
      case AdviceCategory.big3Progression:
        return Icons.trending_up;
      case AdviceCategory.volumeTarget:
        return Icons.bar_chart;
      case AdviceCategory.safetyNote:
        return Icons.medical_services_outlined;
      case AdviceCategory.injuryCare:
        return Icons.healing;
      case AdviceCategory.weightLossDiet:
        return Icons.restaurant_outlined;
      case AdviceCategory.muscleGroupFocus:
        return Icons.center_focus_strong;
      case AdviceCategory.sessionTrend:
        return Icons.timeline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accentColor;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(_icon, color: accent, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  card.title,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  card.category.label,
                  style: TextStyle(
                      color: accent,
                      fontSize: 10,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            card.body,
            style: const TextStyle(
                color: AppColors.textPrimary, fontSize: 13, height: 1.5),
          ),
          if (card.evidenceRefs.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 10),
            Text(
              '根拠',
              style: TextStyle(
                  color: AppColors.textSecond.withValues(alpha: 0.8),
                  fontSize: 10,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            ...card.evidenceRefs.map(
              (ref) => _EvidenceRow(
                evidenceId: ref,
                meta: evidenceMeta[ref],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EvidenceRow extends StatelessWidget {
  final String evidenceId;
  final EvidenceMeta? meta;

  const _EvidenceRow({required this.evidenceId, this.meta});

  @override
  Widget build(BuildContext context) {
    final m = meta;
    final label = m?.displayCitation ?? evidenceId;
    final url = m?.sourceUrl ?? '';
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('•',
              style: TextStyle(color: AppColors.textSecond, fontSize: 12)),
          const SizedBox(width: 6),
          Expanded(
            child: GestureDetector(
              onLongPress: url.isNotEmpty
                  ? () async {
                      await Clipboard.setData(ClipboardData(text: url));
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('リンクをコピー: $url'),
                          backgroundColor: AppColors.primary,
                        ),
                      );
                    }
                  : null,
              child: Text(
                label,
                style: TextStyle(
                  color: AppColors.textSecond.withValues(alpha: 0.9),
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
