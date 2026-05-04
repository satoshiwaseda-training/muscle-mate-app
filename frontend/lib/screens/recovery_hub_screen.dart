import 'package:flutter/material.dart';

import '../main.dart' show AppColors, AppGradientButton;
import '../models/advice.dart';
import '../models/workout_plan.dart';
import '../services/api_service.dart';
import '../services/evidence_index_service.dart';
import '../services/local_storage_service.dart';

enum RecoveryOptionType {
  unlockNextAction,
  nutrition,
  sleep,
  stretch,
}

class _RecoveryChoice {
  final RecoveryOptionType type;
  final String title;
  final String subtitle;
  final String effectLabel;
  final String rewardLabel;
  final String strategyLabel;
  final int projectedEfficiency;
  final String outcomeTitle;
  final String outcomeBody;
  final String resultTitle;
  final String resultBody;
  final String iconPath;

  const _RecoveryChoice({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.effectLabel,
    required this.rewardLabel,
    required this.strategyLabel,
    required this.projectedEfficiency,
    required this.outcomeTitle,
    required this.outcomeBody,
    required this.resultTitle,
    required this.resultBody,
    required this.iconPath,
  });
}

class RecoveryHubScreen extends StatefulWidget {
  final VoidCallback? onApplyNextBestAction;
  final int expectedMomentum;
  final RecoveryOptionType? recommendedType;
  final String? recommendationText;

  const RecoveryHubScreen({
    super.key,
    this.onApplyNextBestAction,
    required this.expectedMomentum,
    this.recommendedType,
    this.recommendationText,
  });

  @override
  State<RecoveryHubScreen> createState() => _RecoveryHubScreenState();
}

class _RecoveryHubScreenState extends State<RecoveryHubScreen> {
  static const int _momentumBoostThreshold = 50;
  static const int _currentRecoveryEfficiency = 80;
  bool _usedToday = false;
  String? _usedTitle;

  // ── Advice cards（v6: 各トピックに紐付けて表示）─────────────────────────
  List<AdviceCard> _adviceCards = const [];
  Map<String, EvidenceMeta> _evidenceMeta = const {};
  bool _adviceLoading = true;

  // initState はファイル下部の方の定義に統合済み（v1.0 提出計画書 stub 修復）
  Future<void> _loadAdvice() async {
    try {
      final settings = await LocalStorageService.loadSettings();
      final equipmentList =
          (settings['equipment'] as List<dynamic>?) ?? const ['barbell'];
      final big3Map = <String, dynamic>{};
      for (final k in const ['bench_press_max', 'squat_max', 'deadlift_max']) {
        if (settings[k] != null) big3Map[k] = settings[k];
      }
      final request = WorkoutRequest(
        goal: Goal.fromValue(
            settings['preferred_goal'] as String? ?? Goal.general.value),
        level: Level.fromValue(
            settings['level'] as String? ?? Level.beginner.value),
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
        _adviceCards = adviceRes.success ? adviceRes.cards : const [];
        _evidenceMeta = meta;
        _adviceLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _adviceLoading = false;
        _adviceCards = const [];
      });
    }
  }

  /// Recovery オプション → 関連する AdviceCategory のマッピング
  List<AdviceCategory> _categoriesFor(RecoveryOptionType type) {
    switch (type) {
      case RecoveryOptionType.nutrition:
        return const [
          AdviceCategory.proteinIntake,
          AdviceCategory.weightLossDiet,
          AdviceCategory.fatBalance,
          AdviceCategory.caffeineTiming,
        ];
      case RecoveryOptionType.sleep:
        return const [
          AdviceCategory.caffeineTiming,
          AdviceCategory.sessionTrend,
          AdviceCategory.safetyNote,
        ];
      case RecoveryOptionType.stretch:
        return const [
          AdviceCategory.injuryCare,
          AdviceCategory.muscleGroupFocus,
          AdviceCategory.restInterval,
        ];
      case RecoveryOptionType.unlockNextAction:
        return const [
          AdviceCategory.big3Progression,
          AdviceCategory.volumeTarget,
          AdviceCategory.equipmentGuidance,
        ];
    }
  }

  List<AdviceCard> _adviceFor(RecoveryOptionType type) {
    final cats = _categoriesFor(type).toSet();
    return _adviceCards.where((c) => cats.contains(c.category)).toList();
  }

  List<_RecoveryChoice> get _options => const [
        _RecoveryChoice(
          type: RecoveryOptionType.unlockNextAction,
          title: '次回提案を整える',
          subtitle: '次のおすすめを、今の回復状態に合わせて始めやすく整えます。',
          effectLabel: 'モメンタム +2',
          rewardLabel: '次回提案ブースト維持',
          strategyLabel: '次回提案ブースト',
          projectedEfficiency: 96,
          outcomeTitle: '次回のおすすめが始めやすくなる',
          outcomeBody: '回復状態と週目標を含めて、次の1手を強化します。',
          resultTitle: '強化版の次回提案を適用',
          resultBody: '回復状態と今週目標を反映した提案に切り替わりました。',
          iconPath: 'assets/icons/recovery_next_step.png',
        ),
        _RecoveryChoice(
          type: RecoveryOptionType.nutrition,
          title: '栄養を整える',
          subtitle: 'トレ後の補給を整えて、次回の重さを減らします。',
          effectLabel: '回復効率 +12%',
          rewardLabel: 'モメンタム減衰を軽減',
          strategyLabel: '栄養で回復維持',
          projectedEfficiency: 92,
          outcomeTitle: '疲労が残りにくくなる',
          outcomeBody: 'トレ後2時間以内の補給ポイントを確認して、回復の抜けを防ぎます。',
          resultTitle: '栄養リカバリーを適用',
          resultBody: 'トレ後2時間以内にタンパク質を確保すると回復効率が安定します。',
          iconPath: 'assets/icons/recovery_nutrition.png',
        ),
        _RecoveryChoice(
          type: RecoveryOptionType.sleep,
          title: '睡眠を整える',
          subtitle: '今夜の休み方を整えて、明日の再開を軽くします。',
          effectLabel: '回復効率 +14%',
          rewardLabel: '疲労回復ブースト',
          strategyLabel: '睡眠優先',
          projectedEfficiency: 94,
          outcomeTitle: '明日の再開が軽くなる',
          outcomeBody: '睡眠の優先度を上げて、次回の戻りやすさを高めます。',
          resultTitle: '睡眠リカバリーを適用',
          resultBody: '今夜はいつもより30分早く休むと、次回の戻りが軽くなります。',
          iconPath: 'assets/icons/recovery_sleep.png',
        ),
        _RecoveryChoice(
          type: RecoveryOptionType.stretch,
          title: '可動域を整える',
          subtitle: '重点部位をほぐして、次回の最初の1セットに入りやすくします。',
          effectLabel: '回復効率 +10%',
          rewardLabel: '始動しやすさアップ',
          strategyLabel: '可動域を整える',
          projectedEfficiency: 90,
          outcomeTitle: '動き出しがスムーズになる',
          outcomeBody: '重点部位を短く整えて、次回の最初の1セットに入りやすくします。',
          resultTitle: 'ストレッチメモを適用',
          resultBody: '重点部位を3分だけ伸ばして終えると、次回の始動がしやすくなります。',
          iconPath: 'assets/icons/recovery_mobility.png',
        ),
      ];

  @override
  void initState() {
    super.initState();
    _loadAdvice();
    _loadUsageState();
  }

  Future<void> _loadUsageState() async {
    final boost = await LocalStorageService.loadRecoveryBoost();
    if (!mounted) return;
    final todayKey = _dayKey(DateTime.now());
    setState(() {
      _usedToday = boost != null && boost['date'] == todayKey;
      _usedTitle =
          _usedToday && boost != null ? boost['title'] as String? : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final nextBoostTarget =
        ((widget.expectedMomentum ~/ _momentumBoostThreshold) + 1) *
            _momentumBoostThreshold;
    final remainingMomentum = nextBoostTarget - widget.expectedMomentum;
    final options = _options;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('回復ラウンジ'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: '戻る',
          onPressed: () {
            // 直前画面が無い場合に備えてホームまでフォールバック
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              Navigator.of(context).popUntil((route) => route.isFirst);
            }
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.home_outlined),
            tooltip: 'ホームへ戻る',
            onPressed: () {
              // 起点画面（ホーム）まで一気に戻る
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(
          AppColors.gapL,
          AppColors.gapS,
          AppColors.gapL,
          AppColors.gapL,
        ),
        child: AppGradientButton(
          onPressed: _usedToday ? null : () => _openChoiceSheet(context),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.auto_awesome),
              const SizedBox(width: 8),
              Text(
                _usedToday ? '本日の回復は利用済み' : '回復方法を選ぶ',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppColors.gapL),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ListView(
                  children: [
                    _IntroPanel(
                      usedToday: _usedToday,
                      usedTitle: _usedTitle,
                    ),
                    const SizedBox(height: AppColors.gapL),
                    Text(
                      '現在状態',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.88),
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _StatusCard(
                      label: '健康モメンタム',
                      value:
                          '${widget.expectedMomentum} / 次回提案ブーストまであと $remainingMomentum',
                      description: '続けるほど貯まる継続ポイントです。一定量で次回提案が強化されます。',
                      accent: AppColors.primary,
                    ),
                    const SizedBox(height: AppColors.gapS),
                    const _StatusCard(
                      label: '回復効率',
                      value: '$_currentRecoveryEfficiency%',
                      description: '今日の疲労を整えておくほど、次回のおすすめに入りやすくなります。',
                      accent: AppColors.warrior,
                    ),
                    if (widget.recommendationText != null) ...[
                      const SizedBox(height: AppColors.gapS),
                      _StatusCard(
                        label: '今週おすすめ',
                        value: widget.recommendationText!,
                        description: '今の流れに最も合う回復セッションです。',
                        accent: AppColors.primaryDim,
                      ),
                    ],
                    const SizedBox(height: AppColors.gapL),
                    Text(
                      '選べる回復メニュー',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.88),
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...options.expand((option) => [
                          RecoveryOptionCard(
                            title: option.title,
                            subtitle: option.subtitle,
                            effectLabel: option.effectLabel,
                            rewardLabel: option.rewardLabel,
                            strategyLabel: option.strategyLabel,
                            iconPath: option.iconPath,
                            availabilityLabel: _usedToday
                                ? '本日は利用済み'
                                : widget.recommendedType == option.type
                                    ? '今のあなたにおすすめ'
                                    : '今日あと1回利用できます',
                            projectedRecoveryEfficiency:
                                option.projectedEfficiency,
                            outcomeTitle: option.outcomeTitle,
                            outcomeBody: option.outcomeBody,
                            isHighlighted:
                                widget.recommendedType == option.type,
                            isDisabled: _usedToday,
                          ),
                          // v6: 各オプションに関連したアドバイスカードを表示
                          _AdviceForOption(
                            loading: _adviceLoading,
                            cards: _adviceFor(option.type),
                            evidenceMeta: _evidenceMeta,
                          ),
                          const SizedBox(height: AppColors.gapS),
                        ]),
                    const SizedBox(height: AppColors.gapM),
                    Text(
                      '補足説明',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.88),
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _usedToday
                          ? '今日はすでに回復セッションを利用しました。反映内容はホームで確認できます。'
                          : '先に回復方法を選び、報酬内容を確認してから視聴します。どの選択肢も視聴後すぐに反映されます。',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.62),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleOptionTap(
    BuildContext context,
    _RecoveryChoice option,
  ) async {
    if (_usedToday) return;
    await _showRewardAdPlaceholder(context);
    if (option.type == RecoveryOptionType.unlockNextAction) {
      widget.onApplyNextBestAction?.call();
    }
    final momentumDelta = option.type == RecoveryOptionType.unlockNextAction
        ? widget.expectedMomentum + 2
        : widget.expectedMomentum;
    await LocalStorageService.saveRecoveryBoost({
      'date': _dayKey(DateTime.now()),
      'type': option.type.name,
      'title': option.title,
      'strategy_label': optionsStrategyLabel(option.type),
      'reward_label': option.rewardLabel,
      'projected_efficiency': option.projectedEfficiency,
      'momentum_delta': momentumDelta,
      'next_action_boosted': option.type == RecoveryOptionType.unlockNextAction,
    });
    if (mounted) {
      setState(() {
        _usedToday = true;
        _usedTitle = option.title;
      });
    }
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _RecoveryResultSheet(
        title: option.resultTitle,
        body: option.resultBody,
        expectedMomentum: momentumDelta,
      ),
    );
  }

  Future<void> _openChoiceSheet(BuildContext context) async {
    if (_usedToday) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RecoveryChoiceSheet(
        options: _options,
        recommendedType: widget.recommendedType,
        onSelected: (option) async {
          Navigator.of(context).pop();
          await _handleOptionTap(context, option);
        },
      ),
    );
  }

  Future<void> _showRewardAdPlaceholder(BuildContext context) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (context.mounted) Navigator.of(context).pop();
  }

  String _dayKey(DateTime day) =>
      '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

  String optionsStrategyLabel(RecoveryOptionType type) {
    switch (type) {
      case RecoveryOptionType.unlockNextAction:
        return '次回提案を強化';
      case RecoveryOptionType.nutrition:
        return '栄養で回復維持';
      case RecoveryOptionType.sleep:
        return '睡眠優先';
      case RecoveryOptionType.stretch:
        return '可動域を整える';
    }
  }
}

class RecoveryOptionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String effectLabel;
  final String rewardLabel;
  final String strategyLabel;
  final String availabilityLabel;
  final int projectedRecoveryEfficiency;
  final String outcomeTitle;
  final String outcomeBody;
  final bool isHighlighted;
  final bool isDisabled;
  final String iconPath;

  const RecoveryOptionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.effectLabel,
    required this.rewardLabel,
    required this.strategyLabel,
    required this.availabilityLabel,
    required this.projectedRecoveryEfficiency,
    required this.outcomeTitle,
    required this.outcomeBody,
    this.isHighlighted = false,
    required this.isDisabled,
    required this.iconPath,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppColors.gapL),
      decoration: BoxDecoration(
        color: isHighlighted ? null : AppColors.surface,
        gradient: isHighlighted
            ? LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.16),
                  AppColors.primaryDim.withValues(alpha: 0.08),
                  AppColors.surface,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        borderRadius: BorderRadius.circular(AppColors.radiusL),
        border: Border.all(
          color: isDisabled
              ? AppColors.border.withValues(alpha: 0.70)
              : isHighlighted
                  ? AppColors.primary.withValues(alpha: 0.45)
                  : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // TODO(assets): replace Icon with Image.asset when PNGs are ready
          // Image.asset(iconPath, width: 32, height: 32, fit: BoxFit.contain)
          Opacity(
            opacity: isDisabled ? 0.45 : 0.80,
            child: Icon(
              _iconDataForPath(iconPath),
              size: 32,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            strategyLabel,
            style: TextStyle(
              color: isHighlighted
                  ? AppColors.primary
                  : Colors.white.withValues(alpha: 0.40),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              color: isDisabled
                  ? Colors.white.withValues(alpha: 0.56)
                  : AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: isDisabled ? 0.42 : 0.62),
              fontSize: 12,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(
                      alpha: isDisabled ? 0.03 : 0.04,
                    ),
                    borderRadius: BorderRadius.circular(AppColors.radiusM),
                    border: Border.all(
                      color: Colors.white.withValues(
                        alpha: isDisabled ? 0.06 : 0.10,
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '利用前',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.42),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '回復効率 ${_RecoveryHubScreenState._currentRecoveryEfficiency}%',
                        style: TextStyle(
                          color: Colors.white.withValues(
                            alpha: isDisabled ? 0.52 : 0.82,
                          ),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withValues(
                          alpha: isDisabled ? 0.10 : 0.18,
                        ),
                        AppColors.primaryDim.withValues(
                          alpha: isDisabled ? 0.06 : 0.12,
                        ),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(AppColors.radiusM),
                    border: Border.all(
                      color: AppColors.primary.withValues(
                        alpha: isDisabled ? 0.10 : 0.22,
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '利用後見込み',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.52),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$projectedRecoveryEfficiency%',
                        style: TextStyle(
                          color: isDisabled
                              ? Colors.white.withValues(alpha: 0.58)
                              : AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            outcomeTitle,
            style: TextStyle(
              color: isDisabled
                  ? Colors.white.withValues(alpha: 0.56)
                  : AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            outcomeBody,
            style: TextStyle(
              color: Colors.white.withValues(alpha: isDisabled ? 0.40 : 0.62),
              fontSize: 12,
              fontWeight: FontWeight.w500,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(
                    alpha: isDisabled ? 0.04 : 0.06,
                  ),
                  borderRadius: BorderRadius.circular(AppColors.radiusS),
                  border: Border.all(
                    color: Colors.white.withValues(
                      alpha: isDisabled ? 0.08 : 0.14,
                    ),
                  ),
                ),
                child: Text(
                  effectLabel,
                  style: TextStyle(
                    color: Colors.white.withValues(
                      alpha: isDisabled ? 0.52 : 0.72,
                    ),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(
                    alpha: isDisabled ? 0.04 : 0.08,
                  ),
                  borderRadius: BorderRadius.circular(AppColors.radiusS),
                  border: Border.all(
                    color: AppColors.primary.withValues(
                      alpha: isDisabled ? 0.08 : 0.18,
                    ),
                  ),
                ),
                child: Text(
                  rewardLabel,
                  style: TextStyle(
                    color: isDisabled
                        ? Colors.white.withValues(alpha: 0.50)
                        : AppColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                availabilityLabel,
                style: TextStyle(
                  color: isHighlighted
                      ? AppColors.primary
                      : Colors.white.withValues(alpha: 0.46),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // TODO(assets): remove once Image.asset is restored
  static IconData _iconDataForPath(String path) {
    if (path.contains('nutrition')) return Icons.restaurant_rounded;
    if (path.contains('sleep')) return Icons.bedtime_rounded;
    if (path.contains('mobility')) return Icons.accessibility_new_rounded;
    return Icons.auto_awesome; // next_step fallback
  }
}

class _RecoveryChoiceSheet extends StatelessWidget {
  final List<_RecoveryChoice> options;
  final RecoveryOptionType? recommendedType;
  final Future<void> Function(_RecoveryChoice option) onSelected;

  const _RecoveryChoiceSheet({
    required this.options,
    required this.recommendedType,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppColors.gapL,
        AppColors.gapM,
        AppColors.gapL,
        AppColors.gapL,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF141A24),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppColors.radiusXL),
        ),
        border: Border.all(color: AppColors.border),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: AppColors.gapM),
            const Text(
              '回復方法を選ぶ',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '見たい回復メニューを選んでから視聴します。報酬は視聴後すぐに反映されます。',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.64),
                fontSize: 12,
                height: 1.5,
              ),
            ),
            const SizedBox(height: AppColors.gapM),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.6,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: options.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final option = options[index];
                  return _RecoveryChoiceSheetCard(
                    title: option.title,
                    subtitle: option.subtitle,
                    effectLabel: option.effectLabel,
                    rewardLabel: option.rewardLabel,
                    isRecommended: recommendedType == option.type,
                    onTap: () => onSelected(option),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecoveryChoiceSheetCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String effectLabel;
  final String rewardLabel;
  final bool isRecommended;
  final VoidCallback onTap;

  const _RecoveryChoiceSheetCard({
    required this.title,
    required this.subtitle,
    required this.effectLabel,
    required this.rewardLabel,
    required this.isRecommended,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppColors.radiusL),
      child: Ink(
        padding: const EdgeInsets.all(AppColors.gapL),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppColors.radiusL),
          border: Border.all(
            color: isRecommended
                ? AppColors.primary.withValues(alpha: 0.45)
                : AppColors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isRecommended) ...[
              const Text(
                'RECOMMENDED',
                style: TextStyle(
                  color: AppColors.primaryDim,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
            ],
            Text(
              title,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.64),
                fontSize: 12,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _RewardChip(
                  label: effectLabel,
                  foreground: AppColors.textPrimary,
                  background: Colors.transparent,
                  border: AppColors.primary.withValues(alpha: 0.18),
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.18),
                      AppColors.primaryDim.withValues(alpha: 0.12),
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
                _RewardChip(
                  label: rewardLabel,
                  foreground: Colors.white.withValues(alpha: 0.82),
                  background: Colors.white.withValues(alpha: 0.05),
                  border: Colors.white.withValues(alpha: 0.10),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RewardChip extends StatelessWidget {
  final String label;
  final Color foreground;
  final Color background;
  final Color border;
  final Gradient? gradient;

  const _RewardChip({
    required this.label,
    required this.foreground,
    required this.background,
    required this.border,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        gradient: gradient,
        borderRadius: BorderRadius.circular(AppColors.radiusS),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _IntroPanel extends StatelessWidget {
  final bool usedToday;
  final String? usedTitle;

  const _IntroPanel({
    required this.usedToday,
    required this.usedTitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppColors.gapL),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppColors.radiusL),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            usedToday
                ? '本日の回復は利用済みです。'
                : '気になるトピックの科学的根拠を下に表示します。',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          if (usedTitle != null) ...[
            const SizedBox(height: 6),
            Text(
              usedTitle!,
              style: const TextStyle(
                color: AppColors.textSecond,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── _AdviceForOption: 各回復オプションに紐付くアドバイスカード群を表示 ───

class _AdviceForOption extends StatelessWidget {
  final bool loading;
  final List<AdviceCard> cards;
  final Map<String, EvidenceMeta> evidenceMeta;

  const _AdviceForOption({
    required this.loading,
    required this.cards,
    required this.evidenceMeta,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        child: SizedBox(
          height: 16,
          width: 16,
          child: CircularProgressIndicator(
              color: AppColors.primary, strokeWidth: 2),
        ),
      );
    }
    if (cards.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final c in cards)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _RecoveryAdviceCard(
                  card: c, evidenceMeta: evidenceMeta),
            ),
        ],
      ),
    );
  }
}

class _RecoveryAdviceCard extends StatelessWidget {
  final AdviceCard card;
  final Map<String, EvidenceMeta> evidenceMeta;

  const _RecoveryAdviceCard(
      {required this.card, required this.evidenceMeta});

  Color get _accent {
    switch (card.severity) {
      case AdviceSeverity.warning:
        return Colors.orange;
      case AdviceSeverity.tip:
        return AppColors.primary;
      case AdviceSeverity.info:
        return AppColors.primary;
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
    final accent = _accent;
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_icon, color: accent, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  card.title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            card.body,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// v1.0 提出計画書 (v1.3) 対応のための最小スタブ widgets
// 元実装で参照されていたが定義が欠落していたため、UI を成立させる最低限の
// 互換実装を追加。本実装は v1.1 で本来のデザインに差し替える想定。
// ─────────────────────────────────────────────────────────────────────────────

class _StatusCard extends StatelessWidget {
  final String label;
  final String value;
  final String description;
  final Color accent;
  const _StatusCard({
    required this.label,
    required this.value,
    required this.description,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: accent, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  color: AppColors.textSecond,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  color: accent,
                  fontSize: 16,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(description,
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12,
                  height: 1.5)),
        ],
      ),
    );
  }
}

class _RecoveryResultSheet extends StatelessWidget {
  final String title;
  final String body;
  final int expectedMomentum;
  const _RecoveryResultSheet({
    required this.title,
    required this.body,
    required this.expectedMomentum,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(body,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    height: 1.6)),
            const SizedBox(height: 12),
            Text('健康モメンタム: $expectedMomentum',
                style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size(double.infinity, 48)),
              child: const Text('閉じる'),
            ),
          ],
        ),
      ),
    );
  }
}
