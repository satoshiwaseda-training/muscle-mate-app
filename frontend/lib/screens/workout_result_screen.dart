// ワークアウト成果表示画面
// ゲームのリザルト画面ライクな高級感ある達成感UI
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../main.dart' show AppColors, AppGradientButton;
import '../models/advice.dart';
import '../models/workout_plan.dart';
import '../models/workout_record.dart';
import '../services/api_service.dart';
import '../services/evidence_index_service.dart';
import '../services/local_storage_service.dart';
import 'package:flutter/foundation.dart';

import 'recovery_hub_screen.dart';
import '../widgets/action_unlock_cards.dart';
import '../widgets/share_card_view.dart';
import '../services/share_action.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Grade
// ─────────────────────────────────────────────────────────────────────────────

enum WorkoutGrade { S, A, B, C }

enum _EffortTone { light, steady, hard, breakthrough }

// ─────────────────────────────────────────────────────────────────────────────
// Main Screen
// ─────────────────────────────────────────────────────────────────────────────

class WorkoutResultScreen extends StatefulWidget {
  final WorkoutRecord record;
  final List<WorkoutRecord> history;

  const WorkoutResultScreen({
    super.key,
    required this.record,
    required this.history,
  });

  @override
  State<WorkoutResultScreen> createState() => _WorkoutResultScreenState();
}

class _WorkoutResultScreenState extends State<WorkoutResultScreen>
    with TickerProviderStateMixin {
  // Animations
  late AnimationController _entranceCtrl;
  late AnimationController _counterCtrl;

  late Animation<double> _fadeIn;
  late Animation<Offset> _slideUp;
  late Animation<double> _volumeCounter;

  // Stats
  late WorkoutGrade _grade;
  late double _prevVolume;
  late int _streak;
  late bool _isPersonalBest;
  late double _avgRecentVolume;
  late double _maxHistoricalVolume;
  late int _lastSessionMomentumGain;
  bool _locallyUnlockedNextBestAction = false;


  // Post-workout advice cards
  List<AdviceCard> _adviceCards = const [];
  Map<String, EvidenceMeta> _evidenceMeta = const {};
  bool _adviceLoading = true;

  @override
  void initState() {
    super.initState();
    _computeStats();
    _initAnimations();
    _startAnimations();
    _loadAdvice();
  }

  /// 完了直後のアドバイスを取得（栄養・休息・カフェイン等）
  /// メニュー生成時ではなくここで表示する UX 設計（v6）。
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

  // ── Stats computation ───────────────────────────────────────────────────────

  void _computeStats() {
    final history = widget.history
        .where((r) => r.id != widget.record.id)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    _prevVolume = history.isNotEmpty ? history.first.totalVolume : 0;
    _streak = _calcStreak(history, widget.record.date);

    final maxVol = history.isNotEmpty
        ? history.map((r) => r.totalVolume).reduce(math.max)
        : 0.0;
    _maxHistoricalVolume = maxVol;
    _isPersonalBest = history.isNotEmpty && widget.record.totalVolume > maxVol;

    final cutoff = widget.record.date.subtract(const Duration(days: 7));
    final recent = history.where((r) => r.date.isAfter(cutoff)).take(6).toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final avgVol = recent.isNotEmpty
        ? recent.map((r) => r.totalVolume).reduce((a, b) => a + b) /
            recent.length
        : 0.0;
    _avgRecentVolume = avgVol;
    _lastSessionMomentumGain = _momentumGainFor(widget.record.totalVolume);
    final curr = widget.record.totalVolume;

    if (_isPersonalBest || (avgVol > 0 && curr >= avgVol * 1.5)) {
      _grade = WorkoutGrade.S;
    } else if (avgVol > 0 && curr >= avgVol * 1.2) {
      _grade = WorkoutGrade.A;
    } else if (avgVol == 0 || curr >= avgVol * 0.9) {
      _grade = WorkoutGrade.B;
    } else {
      _grade = WorkoutGrade.C;
    }
  }

  int _calcStreak(List<WorkoutRecord> sorted, DateTime today) {
    int streak = 1;
    DateTime check = DateTime(today.year, today.month, today.day)
        .subtract(const Duration(days: 1));
    for (final r in sorted) {
      final d = DateTime(r.date.year, r.date.month, r.date.day);
      if (d == check) {
        streak++;
        check = check.subtract(const Duration(days: 1));
      } else if (d.isBefore(check)) {
        break;
      }
    }
    return streak;
  }

  int _momentumGainFor(double volume) {
    final gain = (volume / 120).round();
    return math.max(1, gain);
  }

  // ── Animations ──────────────────────────────────────────────────────────────

  void _initAnimations() {
    _entranceCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _counterCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800));

    _fadeIn = CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOut);
    _slideUp = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOut));
    _volumeCounter = Tween<double>(
      begin: 0,
      end: widget.record.totalVolume,
    ).animate(
        CurvedAnimation(parent: _counterCtrl, curve: Curves.easeOutCubic));
  }

  void _startAnimations() {
    _entranceCtrl.forward();
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) _counterCtrl.forward();
    });
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    _counterCtrl.dispose();
    super.dispose();
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: FadeTransition(
              opacity: _fadeIn,
              child: SlideTransition(
                position: _slideUp,
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 52),
                  children: [
                    _buildTopBar(),
                    const SizedBox(height: 12),
                    _buildHeroCard(),
                    const SizedBox(height: 18),
                    // v1.0: ユーザーフィードバック反映で完了画面を 2 ブロックのみに整理。
                    // 一時非表示にしているのは：
                    //   _buildAcceptanceMessage()  受容メッセージ (ハート + 短文)
                    //   _buildMascotCallout()      マスコット + 一言コメント
                    // v1.1 以降で再表示する場合は次の 4 行を有効化：
                    //   _buildAcceptanceMessage(),
                    //   const SizedBox(height: 14),
                    //   _buildMascotCallout(),
                    //   const SizedBox(height: 18),
                    _buildFeedbackCard(),
                    const SizedBox(height: 28),
                    // v1.0: 回復メニュー (RecoveryHubScreen) への遷移は UI/UX 未確定のため
                    // 一旦非表示にしている。v1.1 以降で再表示する場合は次の行を有効化：
                    //   _buildNextBestActionSection(),
                    //   const SizedBox(height: 28),
                    _buildHomeButton(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Row(
      children: [
        IconButton(
          tooltip: '閉じる',
          onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          style: IconButton.styleFrom(
            backgroundColor: AppColors.surfaceHigh,
            foregroundColor: AppColors.textPrimary,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.surfaceHigh,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.border),
          ),
          child: Text(
            DateFormat('M月d日', 'ja').format(widget.record.date),
            style: const TextStyle(
              color: AppColors.textSecond,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  String _warmHeroTitle() {
    if (!_hasVolume) return '今日はリラックスデー';
    switch (_effortTone) {
      case _EffortTone.light:
        return '無理なくできました。';
      case _EffortTone.steady:
        return '今日も、やり切った。';
      case _EffortTone.hard:
        return 'いい追い込みです。';
      case _EffortTone.breakthrough:
        return '正直、ここまでやる人は少ないです。';
    }
  }

  String _warmHeroLead() {
    if (!_hasVolume) {
      return '軽い負荷で身体をリラックスできました。次回もこの調子で続けましょう。';
    }
    switch (_effortTone) {
      case _EffortTone.light:
        return '無理をせず、身体に合わせて動けました。こういう日も大事な積み上げです。';
      case _EffortTone.steady:
        return 'その一歩、確実に積み上がっています。あなたは続けられる人です。';
      case _EffortTone.hard:
        return 'その1セット、未来を変えています。確実に強くなっています。';
      case _EffortTone.breakthrough:
        return 'これは本気の積み上げです。その苦しさは、全部成長に変わっています。';
    }
  }

  String _coachTitle() {
    if (!_hasVolume) return '軽い負荷で整えました';
    if (_effortTone == _EffortTone.breakthrough) return '本気の積み上げです';
    if (_effortTone == _EffortTone.hard) return '今日の追い込み';
    return '今日できたこと';
  }

  String _mascotSpeech() {
    if (!_hasVolume) return '今日は控えめでOKです。次回も少しずつ頑張りましょう。';
    switch (_effortTone) {
      case _EffortTone.light:
        return '控えめでも大丈夫。身体を整えられたので、次回につながります。';
      case _EffortTone.steady:
        return 'ちゃんと積み上げています。昨日の自分を超えています。';
      case _EffortTone.hard:
        return 'いい追い込みです。ここでやれる人は、最後までやる人です。';
      case _EffortTone.breakthrough:
        return 'これは本気です。ここまでやれた自分を、今日は誇ってください。';
    }
  }

  bool get _hasVolume => widget.record.totalVolume > 0;

  _EffortTone get _effortTone {
    final current = widget.record.totalVolume;
    if (current <= 0) return _EffortTone.light;
    if (_isPersonalBest ||
        (_avgRecentVolume > 0 && current >= _avgRecentVolume * 1.5)) {
      return _EffortTone.breakthrough;
    }
    if (_grade == WorkoutGrade.A ||
        (_prevVolume > 0 && current >= _prevVolume * 1.15)) {
      return _EffortTone.hard;
    }
    if (_grade == WorkoutGrade.C) return _EffortTone.light;
    return _EffortTone.steady;
  }

  Widget _buildMascotCallout() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.34)),
      ),
      child: Row(
        children: [
          const _ResultMascot(size: 58),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _mascotSpeech(),
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.55,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.background.withValues(alpha: 0.24),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.primary, size: 18),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecond,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Hero Volume Card ────────────────────────────────────────────────────────

  Widget _buildHeroCard() {
    final diff = widget.record.totalVolume - _prevVolume;
    final resultTag = _heroResultTag(diff);
    return _GlowCard(
      glowColor: AppColors.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HeroHookBadge(text: resultTag, color: AppColors.primary),
                    const SizedBox(height: 12),
                    Text(
                      _warmHeroTitle(),
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        height: 1.24,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _warmHeroLead(),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.68),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.55,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              const _ResultMascot(),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            _hasVolume ? '今日の合計' : '今日の記録',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          if (_hasVolume)
            AnimatedBuilder(
              animation: _volumeCounter,
              builder: (_, __) => Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Flexible(
                    child: Text(
                      _volumeCounter.value.toStringAsFixed(0),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 78,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -3,
                        height: 0.92,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10, left: 6),
                    child: Text(
                      'kg',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.42),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            const Text(
              '軽めに完了',
              style: TextStyle(
                color: Colors.white,
                fontSize: 34,
                fontWeight: FontWeight.w900,
                height: 1.15,
              ),
            ),
          const SizedBox(height: 18),
          Row(
            children: [
              _buildMiniStat(
                _streak <= 1 ? '今日から始まった' : '習慣の入口',
                _streak <= 1 ? '1日目' : '$_streak日連続',
                Icons.local_fire_department,
              ),
              const SizedBox(width: 10),
              _buildMiniStat(
                '次の目安',
                _nextStepLabel(),
                Icons.flag_outlined,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNextBestActionSection() {
    if (_accessState.isPremium || _accessState.nextBestActionUnlocked) {
      return NextBestActionCard(
        title: '次はここから',
        reason: _nextActionReason(),
        expectedBenefit: _nextActionBenefit(),
      );
    }

    return UnlockCard(
      title: '次は何をやるか、1つだけ決めましょう',
      subtitle: '次回の自分を、今ここで楽にします',
      cta: '決める',
      onTap: _unlockNextBestAction,
    );
  }

  // ── Warm Feedback ───────────────────────────────────────────────────────────

  Widget _buildFeedbackCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.28),
                  ),
                ),
                child: const Icon(
                  Icons.favorite_rounded,
                  color: AppColors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _coachTitle(),
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _friendlySummary(),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.68),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.background.withValues(alpha: 0.28),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Text(
              _friendlyNextLine(),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.82),
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.6,
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _WarmChip(icon: Icons.water_drop_outlined, label: '水分をとる'),
              _WarmChip(icon: Icons.self_improvement, label: '軽く伸ばす'),
              _WarmChip(icon: Icons.nightlight_round, label: 'よく休む'),
            ],
          ),
        ],
      ),
    );
  }

  String _friendlySummary() {
    if (!_hasVolume) {
      return '軽い負荷で身体をリラックスできました。疲れをためすぎずに終えられたのは良い判断です。';
    }
    switch (_effortTone) {
      case _EffortTone.light:
        return '今日は控えめに整えた日です。疲れを残しすぎずに終えられたのは良い判断です。';
      case _EffortTone.steady:
        return 'ちゃんと積み上げています。このペースを作れる人は、続けられる人です。';
      case _EffortTone.hard:
        return 'いい追い込みです。今日の1セットは、次の強さにつながっています。';
      case _EffortTone.breakthrough:
        return 'ここまでやれる日は多くありません。これは本気の積み上げです。';
    }
  }

  String _friendlyNextLine() {
    if (!_hasVolume) {
      return '次回はゆるい1セットから始めましょう。身体が温まったら、少しだけ増やせば十分です。';
    }
    if (_effortTone == _EffortTone.light) {
      return '次回も控えめからでOKです。余裕があれば、最後に1回だけ増やしてみましょう。';
    }
    if (_effortTone == _EffortTone.breakthrough) {
      return '次回は同じ強度を狙わなくて大丈夫です。今日の本気を、次につなげましょう。';
    }
    return '次は“ほんの少しだけ上へ”。前回より1回だけ増やせたら、それは成長です。';
  }

  String _heroResultTag(double diff) {
    if (_isPersonalBest) return '新記録';
    if (_prevVolume <= 0) return 'スタート記録';
    if (diff > 0) return '前回超え';
    return '安定継続';
  }

  String _nextActionReason() {
    if (_streak < 3) {
      return '次にやることが1つ決まっているだけで、始めるハードルはぐっと下がります。';
    }
    final target = _nextGradeTarget();
    if (target != null && target.label != '次の自己ベスト') {
      return '前回より1回だけ増やす。それだけでも、あなたの積み上げは進みます。';
    }
    if (_isPersonalBest) {
      return '今日は強くやり切れています。次回は同じ流れを守るだけでも価値があります。';
    }
    if (_prevVolume <= 0) {
      return '記録した時点で、もう始まっています。次回の一歩を今決めておきましょう。';
    }
    final diff = widget.record.totalVolume - _prevVolume;
    if (diff > 0) {
      return '前回より進めています。この流れを次に持っていきましょう。';
    }
    return '今日は軽い負荷で整えた日です。次回も同じくらいから始めれば十分です。';
  }

  String _nextActionBenefit() {
    if (_streak < 3) {
      return '続けやすいペースを保ちながら、次回のモメンタムも守りやすくなります。';
    }
    final target = _nextGradeTarget();
    if (target == null) return '比較データが増えて、自分に合う続け方が見えやすくなります。';
    if (_grade == WorkoutGrade.S) {
      return '次に何を少し足すかが見えやすくなります。焦らず準備していきましょう。';
    }
    return '${target.label}に向けて、次にできそうな一歩を見つけやすくなります。';
  }

  Widget _buildAcceptanceMessage() {
    return _AcceptanceMessageCard(
      message: _acceptanceMessage(),
    );
  }

  String _acceptanceMessage() {
    if (!_hasVolume) {
      return 'やった日は、必ず前に進んでいる。';
    }
    if (_effortTone == _EffortTone.breakthrough) {
      return 'その苦しさ、全部成長に変わっています。今日は胸を張って終わりましょう。';
    }
    if (_effortTone == _EffortTone.hard) {
      return 'その1セット、未来を変えています。今日の積み上げは強いです。';
    }
    if (_effortTone == _EffortTone.light) {
      return '今日は無理なく整えられました。次回もこの調子でいきましょう。';
    }
    return 'その一歩、確実に積み上がっています。';
  }

  String _nextStepLabel() {
    if (!_hasVolume) return '1種目だけ';
    final target = _nextGradeTarget();
    if (target == null || target.remainingKg <= 0) return '1回だけ上へ';
    if (_effortTone == _EffortTone.breakthrough) return 'まず回復';
    return '+${target.remainingKg.toStringAsFixed(0)}kg';
  }

  _GradeTarget? _nextGradeTarget() {
    if (_avgRecentVolume <= 0) return null;

    switch (_grade) {
      case WorkoutGrade.S:
        final target = _maxHistoricalVolume > 0
            ? _maxHistoricalVolume + 1
            : widget.record.totalVolume + 1;
        return _GradeTarget(
          label: '次の自己ベスト',
          remainingKg: math.max(0.0, target - widget.record.totalVolume),
        );
      case WorkoutGrade.A:
        final target = _avgRecentVolume * 1.5;
        return _GradeTarget(
          label: 'S',
          remainingKg: math.max(0.0, target - widget.record.totalVolume),
        );
      case WorkoutGrade.B:
        final target = _avgRecentVolume * 1.2;
        return _GradeTarget(
          label: 'A',
          remainingKg: math.max(0.0, target - widget.record.totalVolume),
        );
      case WorkoutGrade.C:
        final target = _avgRecentVolume * 0.9;
        return _GradeTarget(
          label: 'B',
          remainingKg: math.max(0.0, target - widget.record.totalVolume),
        );
    }
  }

  Future<void> _unlockNextBestAction() async {
    final recommendation = _weeklyRecoveryRecommendation();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RecoveryHubScreen(
          onApplyNextBestAction: () {
            setState(() => _locallyUnlockedNextBestAction = true);
          },
          expectedMomentum: math.max(1, (_lastSessionMomentumGain / 2).round()),
          recommendedType: recommendation.type,
          recommendationText: recommendation.message,
        ),
      ),
    );
  }

  _RecoveryHubRecommendation _weeklyRecoveryRecommendation() {
    final weekStart = widget.record.date.subtract(const Duration(days: 6));
    final weeklyRecords = [
      ...widget.history.where((r) => r.id != widget.record.id),
      widget.record,
    ].where((r) => !r.date.isBefore(weekStart)).toList();
    final weeklyCount = weeklyRecords
        .map((r) => '${r.date.year}-${r.date.month}-${r.date.day}')
        .toSet()
        .length;
    if (weeklyCount >= 3) {
      return const _RecoveryHubRecommendation(
        type: RecoveryOptionType.unlockNextAction,
        message: '今週の目標まであと1回。次にやることを先に決めておくと続けやすくなります',
      );
    }

    final focusCounts = <String, int>{
      'legs': 0,
      'chest': 0,
      'back': 0,
      'shoulders': 0,
      'core': 0,
    };
    for (final record in weeklyRecords) {
      final set = record.trainedMuscles.toSet();
      if (set.contains('quads') ||
          set.contains('hamstrings') ||
          set.contains('glutes') ||
          set.contains('calves') ||
          set.contains('legs')) {
        focusCounts['legs'] = (focusCounts['legs'] ?? 0) + 1;
      }
      for (final group in ['chest', 'back', 'shoulders', 'core']) {
        if (set.contains(group)) {
          focusCounts[group] = (focusCounts[group] ?? 0) + 1;
        }
      }
    }
    final weakest =
        focusCounts.entries.reduce((a, b) => a.value <= b.value ? a : b).key;
    if (weakest == 'legs') {
      return const _RecoveryHubRecommendation(
        type: RecoveryOptionType.stretch,
        message: '今週は下半身を少し多めに使っています。今日は軽く伸ばして整えましょう',
      );
    }

    final hoursSinceLatest = widget.history.isEmpty
        ? 0
        : widget.record.date.difference(widget.history.first.date).inHours;
    if (hoursSinceLatest < 24) {
      return const _RecoveryHubRecommendation(
        type: RecoveryOptionType.sleep,
        message: '少し疲れが残りやすい流れです。今日は睡眠を優先して体を戻しましょう',
      );
    }

    return const _RecoveryHubRecommendation(
      type: RecoveryOptionType.nutrition,
      message: '次も気持ちよく動けるように、食事と水分を整えておきましょう',
    );
  }

  _ResultAccessState get _accessState {
    final data = widget.record.entertainment ?? const <String, dynamic>{};
    return _ResultAccessState(
      isPremium: data['is_premium'] == true,
      nextBestActionUnlocked: data['next_best_action_unlocked'] == true ||
          _locallyUnlockedNextBestAction,
    );
  }

  // ── Post-workout Advice (v6: 完了後にのみ表示) ──────────────────────────────

  Widget _buildPostWorkoutAdviceSection() {
    if (_adviceLoading) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
                color: AppColors.primary, strokeWidth: 2),
          ),
        ),
      );
    }
    if (_adviceCards.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.tips_and_updates_outlined,
                  color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              const Text(
                '今日のおつかれセット',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_adviceCards.length}件',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
        ...List.generate(_adviceCards.length, (i) {
          final c = _adviceCards[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ResultAdviceCard(card: c, evidenceMeta: _evidenceMeta),
          );
        }),
      ],
    );
  }

  // ── Home Button ─────────────────────────────────────────────────────────────

  // 今日のセッション分のセット数
  int get _todaySetCount => widget.record.sets.length;

  // タップでシェアプレビューモーダルを開く。モーダル内のカードを RepaintBoundary
  // でキャプチャ → Web ダウンロード or Native Share Sheet に渡す。
  void _openShareModal() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _TodayShareSheet(
        cardData: _ShareCardData(
          totalVolumeKg: widget.record.totalVolume,
          sessionCount: 1,
          totalSets: _todaySetCount,
          streak: _streak,
        ),
      ),
    );
  }

  Widget _buildHomeButton() {
    return Column(
      children: [
        // ── 実績シェアボタン（モーダルプレビューを開く）──────────────────
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            onPressed: _openShareModal,
            icon: const Icon(Icons.ios_share, size: 18),
            label: const Text(
              '今日の実績をシェアする',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: AppGradientButton(
            onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
            child: const Center(
              child: Text(
                'ホームに戻る',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}


// ── _ResultAdviceCard: result 画面用のコンパクトなアドバイスカード ───────────

class _ResultAdviceCard extends StatelessWidget {
  final AdviceCard card;
  final Map<String, EvidenceMeta> evidenceMeta;

  const _ResultAdviceCard({required this.card, required this.evidenceMeta});

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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_icon, color: accent, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  card.title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  card.category.label,
                  style: TextStyle(
                    color: accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
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
// v1.0 提出計画書 (v1.3) 対応のための最小スタブ widgets / data classes
// 元実装で参照されていたが定義が欠落していたため、UI を成立させる最低限の
// 互換実装を追加。本実装は v1.1 で本来のデザインに差し替える想定。
// ─────────────────────────────────────────────────────────────────────────────

class _ResultMascot extends StatelessWidget {
  final double size;
  const _ResultMascot({this.size = 72});

  @override
  Widget build(BuildContext context) {
    // ホーム画面・ワークアウトセッション画面と同じマスコット画像で統一
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDim],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: ClipOval(
        child: Padding(
          padding: EdgeInsets.all(size * 0.04),
          child: Image.asset(
            'assets/ui/home/home_mascot_character.png',
            fit: BoxFit.cover,
            alignment: Alignment.bottomCenter,
          ),
        ),
      ),
    );
  }
}

class _GlowCard extends StatelessWidget {
  final Widget child;
  final Color glowColor;
  const _GlowCard({required this.child, required this.glowColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: glowColor.withValues(alpha: 0.32)),
        boxShadow: [
          BoxShadow(
            color: glowColor.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _HeroHookBadge extends StatelessWidget {
  final String text;
  final Color color;
  const _HeroHookBadge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _WarmChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _WarmChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.primary, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _AcceptanceMessageCard extends StatelessWidget {
  final String message;
  const _AcceptanceMessageCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.favorite, color: AppColors.primary, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.55,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GradeTarget {
  final String label;
  final double remainingKg;
  const _GradeTarget({required this.label, required this.remainingKg});
}

class _RecoveryHubRecommendation {
  final RecoveryOptionType type;
  final String message;
  const _RecoveryHubRecommendation({required this.type, required this.message});
}

class _ResultAccessState {
  final bool isPremium;
  final bool nextBestActionUnlocked;
  const _ResultAccessState({
    required this.isPremium,
    required this.nextBestActionUnlocked,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// _ShareCardData
//   モーダルへ渡す ShareCardView の構築データ
// ─────────────────────────────────────────────────────────────────────────────
class _ShareCardData {
  final double totalVolumeKg;
  final int sessionCount;
  final int totalSets;
  final int streak;
  const _ShareCardData({
    required this.totalVolumeKg,
    required this.sessionCount,
    required this.totalSets,
    required this.streak,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// _TodayShareSheet
//   ワークアウト終了画面から開かれるシェアプレビュー兼アクションシート。
//   - カードを表示してユーザーが内容を確認できる
//   - 「ダウンロード／シェア」ボタンで RepaintBoundary を画像化 → 共有
// ─────────────────────────────────────────────────────────────────────────────
class _TodayShareSheet extends StatefulWidget {
  final _ShareCardData cardData;
  const _TodayShareSheet({required this.cardData});

  @override
  State<_TodayShareSheet> createState() => _TodayShareSheetState();
}

class _TodayShareSheetState extends State<_TodayShareSheet> {
  final GlobalKey _cardKey = GlobalKey();
  bool _processing = false;

  Future<void> _share() async {
    if (_processing) return;
    setState(() => _processing = true);
    await captureAndShareCard(
      context: context,
      boundaryKey: _cardKey,
      fileNamePrefix: 'muscle_mate_today_result',
    );
    if (mounted) setState(() => _processing = false);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.6,
      maxChildSize: 0.95,
      builder: (context, controller) => Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(
          children: [
            // ドラッグハンドル
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // ヘッダー
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
              child: Row(
                children: [
                  const Icon(Icons.ios_share,
                      color: AppColors.primary, size: 18),
                  const SizedBox(width: 8),
                  const Text(
                    '今日の実績をシェア',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close,
                        color: AppColors.textSecond),
                    tooltip: '閉じる',
                  ),
                ],
              ),
            ),
            // スクロール可能なカード本体
            Expanded(
              child: SingleChildScrollView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: RepaintBoundary(
                  key: _cardKey,
                  child: ShareCardView(
                    rangeShortLabel: 'TODAY',
                    totalVolumeKg: widget.cardData.totalVolumeKg,
                    sessionCount: widget.cardData.sessionCount,
                    totalSets: widget.cardData.totalSets,
                    streak: widget.cardData.streak,
                  ),
                ),
              ),
            ),
            // 共有ボタン
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
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
                      padding: const EdgeInsets.symmetric(vertical: 14),
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
