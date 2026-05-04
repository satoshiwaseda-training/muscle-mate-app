// ignore_for_file: unused_element
// カレンダー起点型ホーム画面 — 筋トレMEMO風
// Gemini推奨: TableCalendar + BottomSheet でカレンダー主役UXを実現
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../main.dart' show AppColors, AppGradientButton;
import '../models/workout_record.dart';
import '../services/local_storage_service.dart';
import '../widgets/entertainment_banner.dart';
import '../widgets/muscle_visualizer.dart';
import 'plan_generator_screen.dart';
import 'manual_workout_builder_screen.dart';
import 'recovery_hub_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';
import 'privacy_policy_screen.dart';
import 'citations_screen.dart';

class CalendarHomeScreen extends StatefulWidget {
  const CalendarHomeScreen({super.key});
  @override
  State<CalendarHomeScreen> createState() => _CalendarHomeScreenState();
}

class _CalendarHomeScreenState extends State<CalendarHomeScreen> {
  static const _focusGroups = ['chest', 'back', 'legs', 'shoulders', 'core'];
  static const _focusLabels = {
    'chest': '胸',
    'back': '背中',
    'legs': '下半身',
    'shoulders': '肩',
    'core': '体幹',
  };

  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  List<WorkoutRecord> _allRecords = [];
  bool _loading = true;
  _PlannedSession? _plannedSession;
  _HomeRecoveryState? _recoveryState;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final records = await LocalStorageService.loadAll();
    final recoveryBoost = await LocalStorageService.loadRecoveryBoost();
    final rawPlannedSession = await LocalStorageService.loadPlannedSession();
    final plannedSession = _normalizePlannedSession(rawPlannedSession, records);
    if (!mounted) return;
    setState(() {
      _allRecords = records;
      _recoveryState = _parseRecoveryState(recoveryBoost);
      _plannedSession = plannedSession;
      _loading = false;
    });
  }

  List<WorkoutRecord> _recordsFor(DateTime day) => _allRecords
      .where((r) =>
          r.date.year == day.year &&
          r.date.month == day.month &&
          r.date.day == day.day)
      .toList();

  bool _isToday(DateTime d) => isSameDay(d, DateTime.now());

  int _momentumGainFor(double volume) {
    final gain = (volume / 120).round();
    return gain < 1 ? 1 : gain;
  }

  Future<void> _openRecoveryLounge(int expectedMomentum) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RecoveryHubScreen(
          expectedMomentum: expectedMomentum,
        ),
      ),
    );
    _load();
  }

  int _weeklyMomentumGain(DateTime today) {
    final cutoff = today.subtract(const Duration(days: 7));
    return _allRecords
        .where((r) => !r.date.isBefore(cutoff))
        .fold<int>(0, (sum, r) => sum + _momentumGainFor(r.totalVolume));
  }

  int _consecutiveCountFrom(DateTime startDay) {
    var count = 0;
    var day = DateTime(startDay.year, startDay.month, startDay.day);
    while (_recordsFor(day).isNotEmpty) {
      count++;
      day = day.subtract(const Duration(days: 1));
    }
    return count;
  }

  int _weeklySessionCount(DateTime today) {
    final cutoff = today.subtract(const Duration(days: 6));
    return _allRecords
        .where((r) {
          final d = DateTime(r.date.year, r.date.month, r.date.day);
          return !d.isBefore(cutoff);
        })
        .map((r) => '${r.date.year}-${r.date.month}-${r.date.day}')
        .toSet()
        .length;
  }

  String _weeklyGoalProgressText(DateTime today) {
    const goal = 4;
    final count = _weeklySessionCount(today);
    final focus = _weeklyFocusLabel(today);
    if (count == 0) return '今週0/$goal 回 — あと1回でスタート達成';
    if (count == 1) return '今週1/$goal 回 — あと2回で習慣化レベル';
    if (count == 2) return '今週2/$goal 回 — あと1回で習慣化レベル';
    if (count == 3) return '今週3/$goal 回 — あと1回で達人レベル';
    return '今週 $count/$goal 回達成 — 重点: $focus';
  }

  String _weeklyFocusLabel(DateTime today) {
    final cutoff = today.subtract(const Duration(days: 6));
    final counts = <String, int>{
      for (final group in _focusGroups) group: 0,
    };

    for (final record in _allRecords) {
      final d = DateTime(record.date.year, record.date.month, record.date.day);
      if (d.isBefore(cutoff)) continue;
      final muscles = record.trainedMuscles.toSet();
      if (muscles.contains('quads') ||
          muscles.contains('hamstrings') ||
          muscles.contains('glutes') ||
          muscles.contains('calves')) {
        counts['legs'] = (counts['legs'] ?? 0) + 1;
      }
      for (final group in ['chest', 'back', 'shoulders', 'core']) {
        if (muscles.contains(group)) {
          counts[group] = (counts[group] ?? 0) + 1;
        }
      }
    }

    final target = counts.entries.reduce((a, b) {
      if (a.value != b.value) return a.value <= b.value ? a : b;
      return _focusGroups.indexOf(a.key) <= _focusGroups.indexOf(b.key) ? a : b;
    });
    return _focusLabels[target.key] ?? '全身';
  }

  String _homeNextGoalText(bool todayDone, int streak) {
    if (_recoveryState?.nextActionBoosted == true) {
      final weeklyCount = _weeklySessionCount(DateTime.now());
      final remaining = math.max(1, 4 - weeklyCount);
      return remaining == 1 ? 'あと1回で今週目標達成' : 'あと$remaining回で今週目標達成ライン';
    }
    if (!todayDone) {
      final weeklyCount = _weeklySessionCount(DateTime.now());
      final remaining = math.max(0, 4 - weeklyCount);
      if (weeklyCount == 0) return 'あと1回でスタート達成';
      if (remaining <= 1) return 'あと1回で今週の達人レベル';
      if (weeklyCount < 3) return '今週あと$remaining回で習慣化レベル';
      return 'あと$remaining回で今週目標達成';
    }

    final latest = _allRecords.isNotEmpty ? _allRecords.first : null;
    if (latest == null) return 'あと1回でこの流れが安定';

    final recent = _allRecords
        .where((r) {
          final cutoff = latest.date.subtract(const Duration(days: 7));
          return r.id != latest.id && r.date.isAfter(cutoff);
        })
        .take(6)
        .toList();

    final avgVol = recent.isNotEmpty
        ? recent.map((r) => r.totalVolume).reduce((a, b) => a + b) /
            recent.length
        : 0.0;

    if (avgVol > 0) {
      final target = avgVol * 1.2;
      final remaining = math.max(0.0, target - latest.totalVolume);
      return 'あと${remaining.toStringAsFixed(1)}kgでAランク';
    }

    return 'あと1回でこの流れが安定';
  }

  String _homeNextGoalReason(bool todayDone) {
    final today = DateTime.now();
    final weeklyCount = _weeklySessionCount(today);
    final recovery = _recoveryModel(today);
    final focus = _weeklyFocusLabel(today);
    final remaining = math.max(0, 4 - weeklyCount);
    if (_recoveryState?.nextActionBoosted == true) {
      if (remaining > 0) {
        return remaining == 1
            ? '今週の実施数が目標まで残り1回のため、$focusを優先した構成にしています。'
            : '今週の実施数から$focusを優先と判断しています。${recovery.focusLabel}の回復経過も考慮しています。';
      }
      return '今週の実施数から$focusを優先と判断しています。${recovery.focusLabel}の回復経過も考慮しています。';
    }
    if (weeklyCount == 0) {
      return '今週の記録がまだないため、初回向けのベース構成で提案しています。';
    }
    if (weeklyCount < 4) {
      return remaining == 1
          ? '今日実施すると今週目標（4回）に届くため、通常構成で提案しています。${recovery.reason}'
          : '今週あと$remaining回の達成が見えているため、継続しやすい構成にしています。${recovery.reason}';
    }
    return recovery.reason;
  }

  String _homeNextGoalBenefit(bool todayDone) {
    if (_recoveryState != null) {
      return '実施履歴が積まれるほど、次回の負荷・種目の精度が上がります。';
    }
    return _weekdayAnchorText(DateTime.now());
  }

  _SuggestedSession _suggestNextSession(DateTime today) {
    final recovery = _recoveryModel(today);
    final targetDay = _preferredSessionDay(today);
    final slot = targetDay.hour < 12 ? '朝' : '20:00';
    final title = _formatPlannedTitle(targetDay, slot);
    return _SuggestedSession(
      scheduledAt: targetDay,
      title: '次回予定: $title',
      subtitle:
          '推奨: ${recovery.focusLabel}の回復に合わせて${_relativeDayLabel(targetDay, today)}',
      actionLabel: _plannedSession == null ? 'この予定で固定' : '明日の予定にする',
    );
  }

  DateTime _preferredSessionDay(DateTime today) {
    if (_allRecords.isEmpty) {
      return DateTime(today.year, today.month, today.day + 1, 7);
    }
    final latest = _allRecords.first;
    final elapsed = today.difference(latest.date).inHours;
    if (elapsed < 24) {
      return DateTime(today.year, today.month, today.day + 1, 20);
    }
    if (elapsed < 48) {
      return DateTime(today.year, today.month, today.day + 1, 7);
    }
    return DateTime(today.year, today.month, today.day, 20);
  }

  String _formatPlannedTitle(DateTime day, String slot) {
    final now = DateTime.now();
    final diffDays = DateTime(day.year, day.month, day.day)
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;
    if (diffDays == 0) return '今日 $slot';
    if (diffDays == 1) return '明日 $slot';
    return '${_weekdayShort(day)}曜 $slot';
  }

  String _relativeDayLabel(DateTime day, DateTime today) {
    final diffDays = DateTime(day.year, day.month, day.day)
        .difference(DateTime(today.year, today.month, today.day))
        .inDays;
    if (diffDays == 0) return '今日';
    if (diffDays == 1) return '明日';
    return '${_weekdayShort(day)}曜';
  }

  String _weekdayShort(DateTime day) {
    const weekdays = ['月', '火', '水', '木', '金', '土', '日'];
    return weekdays[day.weekday - 1];
  }

  void _commitPlannedSession(_SuggestedSession suggested) {
    final next = _plannedSession == null
        ? _PlannedSession(
            scheduledAt: suggested.scheduledAt,
            label: suggested.title.replaceFirst('次回予定: ', ''),
            status: 'scheduled',
            createdAt: DateTime.now(),
          )
        : _PlannedSession(
            scheduledAt: DateTime(
              DateTime.now().year,
              DateTime.now().month,
              DateTime.now().day + 1,
              20,
            ),
            label: '明日 20:00',
            status: 'scheduled',
            createdAt: DateTime.now(),
          );
    LocalStorageService.savePlannedSession(next.toJson());
    setState(() => _plannedSession = next);
  }

  void _changePlannedSession({
    required int dayOffset,
    int? hour,
    required String label,
  }) {
    final now = DateTime.now();
    final next = _PlannedSession(
      scheduledAt: DateTime(
        now.year,
        now.month,
        now.day + dayOffset,
        hour ?? (_plannedSession?.scheduledAt.hour ?? 20),
      ),
      label: label,
      status: 'scheduled',
      createdAt: DateTime.now(),
    );
    LocalStorageService.savePlannedSession(next.toJson());
    setState(() => _plannedSession = next);
  }

  void _openPlanGenerator() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const PlanGeneratorScreen(startNow: true),
      ),
    ).then((_) => _load());
  }

  void _openManualBuilder() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ManualWorkoutBuilderScreen(),
      ),
    ).then((_) => _load());
  }

  void _showCreateMenuChoices() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '今日のメニューを作る',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.auto_fix_high, color: AppColors.primary),
                title: const Text('メニューを提案してもらう'),
                subtitle: const Text('目的・体調に合わせて自動作成'),
                onTap: () {
                  Navigator.pop(context);
                  _openPlanGenerator();
                },
              ),
              ListTile(
                leading: const Icon(Icons.touch_app, color: AppColors.secondary),
                title: const Text('自分で部位・種目を選ぶ'),
                subtitle: const Text('登録済み種目から選んで重量・回数を入力'),
                onTap: () {
                  Navigator.pop(context);
                  _openManualBuilder();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _restToday() {
    _changePlannedSession(dayOffset: 1, hour: 20, label: '明日 20:00');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('今日は休む日にしました。明日また無理なく再開しましょう')),
    );
  }

  String _plannedSessionStatus(DateTime today) {
    if (_plannedSession == null) return '';
    if (_plannedSession!.status == 'completed') {
      return '予定達成  約束した1回を回収しました';
    }
    if (_plannedSession!.status == 'expired') {
      return '失効  今日の流れに合わせて予定を組み直せます';
    }
    final diffDays = DateTime(
      _plannedSession!.scheduledAt.year,
      _plannedSession!.scheduledAt.month,
      _plannedSession!.scheduledAt.day,
    ).difference(DateTime(today.year, today.month, today.day)).inDays;
    final when = diffDays <= 0
        ? '次回は今日'
        : diffDays == 1
            ? '次回は明日'
            : '次回は$diffDays日後';
    if (diffDays == 1) {
      return '明日は無理のない範囲で大丈夫です。\nこのペースでいけば、今週の目標はちゃんと見えていますよ。';
    }
    return '予約済み  $when  この予定で今週目標達成に近づく';
  }

  String _plannedSessionSubtitle(String fallback) {
    if (_plannedSession == null) return fallback;
    switch (_plannedSession!.status) {
      case 'completed':
        return 'この1回で流れを維持できました。ここから次の約束を自然につなげられます';
      case 'expired':
        return '前回の予定は期限を過ぎました。今日の流れに合わせて再設定できます';
      default:
        return _plannedSessionMeaning(_plannedSession!, DateTime.now());
    }
  }

  String _plannedSessionReason(
    _PlannedSession? session,
    DateTime today,
    String focusLabel,
  ) {
    if (session == null) {
      return '回復に合いやすい時間帯です';
    }
    final weeklyCount = _weeklySessionCount(today);
    final remaining = math.max(0, 4 - weeklyCount);
    final diffDays = DateTime(
      session.scheduledAt.year,
      session.scheduledAt.month,
      session.scheduledAt.day,
    ).difference(DateTime(today.year, today.month, today.day)).inDays;
    final isMorning = session.scheduledAt.hour < 12;

    if (remaining == 1) {
      return '今週目標に届きやすい設定です';
    }
    if (diffDays <= 0 && !isMorning) {
      return '今の生活リズムに合う時間です';
    }
    if (isMorning) {
      return '$focusLabel の回復に合いやすい時間帯です';
    }
    return '流れを切らずに続けやすい設定です';
  }

  String? _plannedSessionRewardText(DateTime today) {
    if (_plannedSession?.status != 'completed') return null;
    final weeklyCount = _weeklySessionCount(today);
    if (weeklyCount < 4) return '今週目標に1歩前進';
    if (_streak > 0) return 'いい流れを維持できました';
    return '健康モメンタムを守りました';
  }

  String _plannedSessionMeaning(_PlannedSession session, DateTime today) {
    final weeklyCount = _weeklySessionCount(today);
    final remaining = math.max(0, 4 - weeklyCount);
    final diffDays = DateTime(
      session.scheduledAt.year,
      session.scheduledAt.month,
      session.scheduledAt.day,
    ).difference(DateTime(today.year, today.month, today.day)).inDays;

    if (remaining == 1) {
      return 'この1回で今週目標達成に届く予定です';
    }
    if (diffDays <= 0) {
      return '今日の流れを維持する重要な1回です';
    }
    if (diffDays == 1) {
      return 'この調子で、明日も無理なく続けましょう';
    }
    return '次の流れを切らさないための約束として置いています';
  }

  _PlannedSession? _normalizePlannedSession(
    Map<String, dynamic>? raw,
    List<WorkoutRecord> records,
  ) {
    if (raw == null) return null;
    final session = _PlannedSession.fromJson(raw);
    final scheduledDay = DateTime(
      session.scheduledAt.year,
      session.scheduledAt.month,
      session.scheduledAt.day,
    );
    final today = DateTime.now();
    final todayDay = DateTime(today.year, today.month, today.day);
    final hasRecordOnScheduledDay = records.any((r) {
      final recordDay = DateTime(r.date.year, r.date.month, r.date.day);
      return recordDay == scheduledDay;
    });

    if (session.status == 'scheduled' && hasRecordOnScheduledDay) {
      final completed = session.copyWith(status: 'completed');
      LocalStorageService.savePlannedSession(completed.toJson());
      return completed;
    }

    if (session.status == 'scheduled' && scheduledDay.isBefore(todayDay)) {
      final expired = session.copyWith(status: 'expired');
      LocalStorageService.savePlannedSession(expired.toJson());
      return expired;
    }

    return session;
  }

  _HomeRecoveryState? _parseRecoveryState(Map<String, dynamic>? raw) {
    if (raw == null) return null;
    final todayKey = _dayKey(DateTime.now());
    if (raw['date'] != todayKey) return null;
    return _HomeRecoveryState(
      title: raw['title'] as String? ?? '回復済み',
      momentumDelta: raw['momentum_delta'] as int? ?? 0,
      strategyLabel: raw['strategy_label'] as String? ?? '回復を整える',
      nextActionBoosted: raw['next_action_boosted'] == true,
    );
  }

  String _dayKey(DateTime day) =>
      '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

  _RecoveryModel _recoveryModel(DateTime today) {
    if (_allRecords.isEmpty) {
      return const _RecoveryModel(
        reason: '記録がまだないため、全身バランスのベース構成を基準にしています。',
        focusLabel: '全身',
      );
    }

    final latest = _allRecords.first;
    final elapsed = today.difference(latest.date).inHours;
    final focus =
        _focusLabels[_primaryMuscleGroup(latest.trainedMuscles)] ?? '全身';

    if (elapsed < 24) {
      return _RecoveryModel(
        reason: '$focus の前回から$elapsed時間未満のため、今回は回復系メニューを優先しています。',
        focusLabel: focus,
      );
    }
    if (elapsed < 48) {
      return _RecoveryModel(
        reason: '$focus の前回から$elapsed時間経過。疲労が抜け始めたタイミングのため、通常負荷で組んでいます。',
        focusLabel: focus,
      );
    }
    return _RecoveryModel(
      reason: '$focus の前回から$elapsed時間経過。回復が進んでいるため、体力に合わせて少しずつ進めやすい設定にしています。',
      focusLabel: focus,
    );
  }

  String _primaryMuscleGroup(List<String> muscles) {
    final set = muscles.toSet();
    if (set.contains('quads') ||
        set.contains('hamstrings') ||
        set.contains('glutes') ||
        set.contains('calves') ||
        set.contains('legs')) {
      return 'legs';
    }
    for (final group in ['chest', 'back', 'shoulders', 'core']) {
      if (set.contains(group)) return group;
    }
    return 'core';
  }

  String _weekdayAnchorText(DateTime day) {
    switch (day.weekday) {
      case DateTime.monday:
        return '週の最初のため、負荷をやや抑えた再始動構成にしています。';
      case DateTime.tuesday:
        return '前日の休養から回復が見込めるため、上半身を進める構成にしています。';
      case DateTime.wednesday:
        return '週の中間のため、現在の実施ペースを維持できる構成にしています。';
      case DateTime.thursday:
        return '累積疲労がたまりにくい曜日のため、上半身を固める強度にしています。';
      case DateTime.friday:
        return '週末前で達成数を稼ぎやすいため、消化しやすい構成にしています。';
      case DateTime.saturday:
        return '平日より時間が確保しやすいため、強度を上げた構成にしています。';
      case DateTime.sunday:
        return '翌週に疲労を持ち越さないため、回復寄りの構成にしています。';
      default:
        return '今日の実施データを元に構成しています。';
    }
  }

  // 連続トレーニング日数（streaks）
  int get _streak {
    int count = 0;
    DateTime day = DateTime.now();
    while (true) {
      if (_recordsFor(day).isEmpty) break;
      count++;
      day = day.subtract(const Duration(days: 1));
    }
    return count;
  }

  void _onDayTapped(DateTime selected, DateTime focused) {
    setState(() {
      _selectedDay = selected;
      _focusedDay = focused;
    });
    _showDayBottomSheet(selected);
  }

  void _showDayBottomSheet(DateTime day) {
    final records = _recordsFor(day);
    final isToday = _isToday(day);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DayBottomSheet(
        day: day,
        title: _safeSheetTitle(day),
        records: records,
        isToday: isToday,
        onStartWorkout: () {
          Navigator.pop(context);
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const PlanGeneratorScreen(startNow: true)));
        },
        onRefresh: _load,
      ),
    );
  }

  String _safeSheetTitle(DateTime day) {
    const weekdays = ['月', '火', '水', '木', '金', '土', '日'];
    final weekday = weekdays[day.weekday - 1];
    return '${day.month}月${day.day}日($weekday)';
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayRecords = _recordsFor(today);
    final todayDone = todayRecords.isNotEmpty;
    final streak = _streak;
    final displayedFocus = _recoveryModel(today).focusLabel;

    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: const _AppDrawer(),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : CustomScrollView(
              slivers: [
                // ── ヘッダー ───────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Builder(
                    builder: (context) => _Header(
                      streak: streak,
                      todayDone: todayRecords.isNotEmpty,
                      onMenuTap: () => Scaffold.of(context).openDrawer(),
                    ),
                  ),
                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: _TodayActionCard(
                      todayDone: todayDone,
                      hasPlan: _plannedSession != null,
                      focusLabel: displayedFocus,
                      onCreatePlan: _showCreateMenuChoices,
                      onOpenToday: () => _showDayBottomSheet(today),
                      onRest: _restToday,
                    ),
                  ),
                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    child: _WeeklyProgressCard(
                      today: today,
                      eventLoader: _recordsFor,
                    ),
                  ),
                ),

                // ── カレンダー ─────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                    child: _FireCalendar(
                      focusedDay: _focusedDay,
                      selectedDay: _selectedDay,
                      eventLoader: _recordsFor,
                      onDaySelected: _onDayTapped,
                      onPageChanged: (d) => _focusedDay = d,
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            ),
    );
  }
}

// ── ヘッダー ──────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final int streak;
  final bool todayDone;
  final VoidCallback onMenuTap;
  const _Header({
    required this.streak,
    required this.todayDone,
    required this.onMenuTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 40, 22, 20),
      decoration: const BoxDecoration(
        color: AppColors.background,
      ),
      child: Row(
        children: [
          // ハンバーガーメニュー: タップで Drawer (サイドメニュー) を開く
          IconButton(
            onPressed: onMenuTap,
            icon: const Icon(Icons.menu,
                color: AppColors.textSecond, size: 28),
            tooltip: 'メニューを開く',
            padding: const EdgeInsets.all(12),
          ),
          const SizedBox(width: 6),
          const Expanded(
            child: Text(
              '💪 Muscle Mate',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          // v1.0 では通知機能を提供しないためベルアイコンは削除済み。
          // 通知 (UNUserNotificationCenter) を実装する v1.1 以降で再追加する。
        ],
      ),
    );
  }
}

class _TodayActionCard extends StatelessWidget {
  final bool todayDone;
  final bool hasPlan;
  final String focusLabel;
  final VoidCallback onCreatePlan;
  final VoidCallback onOpenToday;
  final VoidCallback onRest;

  const _TodayActionCard({
    required this.todayDone,
    required this.hasPlan,
    required this.focusLabel,
    required this.onCreatePlan,
    required this.onOpenToday,
    required this.onRest,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.surfaceHigh,
            AppColors.surface,
            AppColors.primary.withValues(alpha: 0.10),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '今日やること',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        height: 1.08,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      '体調に合わせて無理なく\n進めましょう',
                      style: TextStyle(
                        color: AppColors.textSecond,
                        fontSize: 16,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: SizedBox(
                  width: 112,
                  height: 112,
                  child: Image.asset(
                    'assets/ui/home/home_mascot_character.png',
                    fit: BoxFit.cover,
                    alignment: Alignment.bottomCenter,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          AppGradientButton(
            onPressed: onCreatePlan,
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: const Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_fix_high),
                  SizedBox(width: 10),
                  Text(
                    '今日のメニューを作る',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                  ),
                  SizedBox(width: 10),
                  Icon(Icons.chevron_right),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onOpenToday,
                  icon: const Icon(Icons.edit_note),
                  label: Text(hasPlan ? '予定を見る' : '記録する'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onRest,
                  icon: const Icon(Icons.self_improvement),
                  label: const Text('休む日にする'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            todayDone ? '今日は記録済みです' : 'おすすめ: $focusLabel',
            style: const TextStyle(
              color: AppColors.primaryDim,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyProgressCard extends StatelessWidget {
  final DateTime today;
  final List<WorkoutRecord> Function(DateTime) eventLoader;

  const _WeeklyProgressCard({
    required this.today,
    required this.eventLoader,
  });

  @override
  Widget build(BuildContext context) {
    final start = today.subtract(Duration(days: today.weekday - 1));
    const weekdays = ['月', '火', '水', '木', '金', '土', '日'];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Expanded(
                child: Text(
                  '今週の進み具合',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '詳細を見る 〉',
                style: TextStyle(color: AppColors.textSecond, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (index) {
              final day = start.add(Duration(days: index));
              final done = eventLoader(day).isNotEmpty;
              final isToday = isSameDay(day, today);
              return Column(
                children: [
                  Text(
                    weekdays[index],
                    style: const TextStyle(
                      color: AppColors.textSecond,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: done
                          ? AppColors.secondary.withValues(alpha: 0.95)
                          : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isToday
                            ? AppColors.primary
                            : AppColors.secondary.withValues(alpha: 0.4),
                        width: isToday ? 2 : 1,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      done ? '✓' : '${day.day}',
                      style: TextStyle(
                        color: done ? AppColors.background : AppColors.textSecond,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${day.month}/${day.day}',
                    style: TextStyle(
                      color: isToday ? AppColors.primary : AppColors.textSecond,
                      fontSize: 11,
                      fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ── カレンダー ─────────────────────────────────────────────────────────────────

class _FireCalendar extends StatelessWidget {
  final DateTime focusedDay;
  final DateTime selectedDay;
  final List<WorkoutRecord> Function(DateTime) eventLoader;
  final void Function(DateTime, DateTime) onDaySelected;
  final void Function(DateTime) onPageChanged;

  const _FireCalendar({
    required this.focusedDay,
    required this.selectedDay,
    required this.eventLoader,
    required this.onDaySelected,
    required this.onPageChanged,
  });

  static const _weekdayLabels = ['月', '火', '水', '木', '金', '土', '日'];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: TableCalendar(
        firstDay: DateTime(2025, 1, 1),
        lastDay: DateTime(2030, 12, 31),
        focusedDay: focusedDay,
        selectedDayPredicate: (d) => isSameDay(d, selectedDay),
        eventLoader: eventLoader,
        onDaySelected: onDaySelected,
        onPageChanged: onPageChanged,
        locale: 'ja_JP',
        headerStyle: HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextFormatter: (date, _) => '${date.year}年${date.month}月',
          titleTextStyle: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 16),
          leftChevronIcon:
              const Icon(Icons.chevron_left, color: AppColors.textSecond),
          rightChevronIcon:
              const Icon(Icons.chevron_right, color: AppColors.textSecond),
          headerPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
        daysOfWeekStyle: DaysOfWeekStyle(
          dowTextFormatter: (date, _) => _weekdayLabels[date.weekday - 1],
          weekdayStyle:
              const TextStyle(color: AppColors.textSecond, fontSize: 12),
          weekendStyle:
              const TextStyle(color: AppColors.primary, fontSize: 12),
        ),
        calendarStyle: CalendarStyle(
          outsideDaysVisible: false,
          defaultTextStyle: const TextStyle(color: AppColors.textPrimary),
          weekendTextStyle: const TextStyle(color: AppColors.primary),
          todayDecoration: BoxDecoration(
            border: Border.all(color: AppColors.primary, width: 2),
            shape: BoxShape.circle,
          ),
          todayTextStyle: const TextStyle(
              color: AppColors.primary, fontWeight: FontWeight.bold),
          selectedDecoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          selectedTextStyle:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          markerDecoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          markerSize: 5,
          markerMargin: const EdgeInsets.only(top: 2),
          cellMargin: const EdgeInsets.all(4),
        ),
      ),
    );
  }
}

// ── 今日のサマリーカード ───────────────────────────────────────────────────────

class _TodaySummary extends StatelessWidget {
  final List<WorkoutRecord> records;
  final VoidCallback onStart;
  const _TodaySummary({required this.records, required this.onStart});

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return GestureDetector(
        onTap: onStart,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: const Row(
            children: [
              Icon(Icons.add_circle, color: AppColors.primary, size: 32),
              SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('今日はまだ記録がありません',
                      style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold)),
                  Text('まずは1回やってみる',
                      style: TextStyle(color: AppColors.primary, fontSize: 12)),
                ],
              ),
            ],
          ),
        ),
      );
    }

    final totalVol = records.fold(0.0, (s, r) => s + r.totalVolume);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('今日の実績',
              style: TextStyle(
                  color: AppColors.textSecond, fontSize: 11, letterSpacing: 1)),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('${totalVol.toStringAsFixed(0)} kg',
                  style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 36,
                      fontWeight: FontWeight.w900)),
              const SizedBox(width: 8),
              const Text('総挙上重量',
                  style: TextStyle(color: AppColors.textSecond)),
            ],
          ),
          Text('${records.length}セッション完了',
              style: const TextStyle(color: AppColors.textSecond)),
        ],
      ),
    );
  }
}

// ── 実績タイル ────────────────────────────────────────────────────────────────

class _RecordTile extends StatelessWidget {
  final WorkoutRecord record;
  final VoidCallback onTap;
  const _RecordTile({required this.record, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const weekdays = ['月', '火', '水', '木', '金', '土', '日'];
    final dateLabel =
        '${record.date.month}/${record.date.day}(${weekdays[record.date.weekday - 1]})';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF2A2A2A)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.fitness_center,
                  color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(record.planName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Text(dateLabel,
                      style: const TextStyle(
                          color: AppColors.textSecond, fontSize: 12)),
                ],
              ),
            ),
            Text(
              '${record.totalVolume.toStringAsFixed(0)}kg',
              style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 日付別 BottomSheet ────────────────────────────────────────────────────────

class _DayBottomSheet extends StatelessWidget {
  final DateTime day;
  final String title;
  final List<WorkoutRecord> records;
  final bool isToday;
  final VoidCallback onStartWorkout;
  final VoidCallback onRefresh;

  const _DayBottomSheet({
    required this.day,
    required this.title,
    required this.records,
    required this.isToday,
    required this.onStartWorkout,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: records.isEmpty ? 0.42 : 0.85,
      minChildSize: 0.3,
      maxChildSize: 0.95,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: ListView(
          controller: ctrl,
          padding: const EdgeInsets.all(20),
          children: [
            // ドラッグハンドル
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // 日付タイトル
            Text(title,
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 16),

            // 今日 → 開始ボタン
            if (isToday) ...[
              AppGradientButton(
                onPressed: onStartWorkout,
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.play_arrow),
                    SizedBox(width: 8),
                    Text(
                      '今日のメニューを作る',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // 実績
            if (records.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  isToday ? 'まだ記録がありません。\n体調に合わせて今日のメニューを作りましょう。' : 'この日の記録はありません',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecond),
                ),
              )
            else
              ...records.map((r) => _RecordDetailCard(
                    record: r,
                    onDelete: () async {
                      await LocalStorageService.delete(r.id);
                      onRefresh();
                      if (context.mounted) Navigator.pop(context);
                    },
                  )),
          ],
        ),
      ),
    );
  }
}

class _RecoveryLoungeEntryCard extends StatelessWidget {
  final VoidCallback onTap;

  const _RecoveryLoungeEntryCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '回復ラウンジ',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '疲労を整えて、次回の1回を始めやすくする',
                    style: TextStyle(
                      color: AppColors.textSecond,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            IgnorePointer(
              child: AppGradientButton(
                onPressed: () {},
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                borderRadius: BorderRadius.circular(AppColors.radiusS),
                child: const Text(
                  '開く',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
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

class _RecoveryModel {
  final String reason;
  final String focusLabel;

  const _RecoveryModel({required this.reason, required this.focusLabel});
}

class _SuggestedSession {
  final DateTime scheduledAt;
  final String title;
  final String subtitle;
  final String actionLabel;

  const _SuggestedSession({
    required this.scheduledAt,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
  });
}

class _PlannedSession {
  final DateTime scheduledAt;
  final String label;
  final String status;
  final DateTime createdAt;

  const _PlannedSession({
    required this.scheduledAt,
    required this.label,
    required this.status,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'date': scheduledAt.toIso8601String(),
        'label': label,
        'status': status,
        'createdAt': createdAt.toIso8601String(),
      };

  factory _PlannedSession.fromJson(Map<String, dynamic> json) {
    return _PlannedSession(
      scheduledAt: DateTime.parse(json['date'] as String),
      label: json['label'] as String? ?? '',
      status: json['status'] as String? ?? 'scheduled',
      createdAt: DateTime.parse(
        json['createdAt'] as String? ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  _PlannedSession copyWith({
    DateTime? scheduledAt,
    String? label,
    String? status,
    DateTime? createdAt,
  }) {
    return _PlannedSession(
      scheduledAt: scheduledAt ?? this.scheduledAt,
      label: label ?? this.label,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class _HomeRecoveryState {
  final String title;
  final int momentumDelta;
  final String strategyLabel;
  final bool nextActionBoosted;

  const _HomeRecoveryState({
    required this.title,
    required this.momentumDelta,
    required this.strategyLabel,
    required this.nextActionBoosted,
  });
}

// ── 実績詳細カード（BottomSheet内） ──────────────────────────────────────────

class _RecordDetailCard extends StatelessWidget {
  final WorkoutRecord record;
  final VoidCallback onDelete;
  const _RecordDetailCard({required this.record, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF3A3A3A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── エンタメバナー ────────────────────────────────────
          if (record.entertainment != null) ...[
            EntertainmentBanner(data: record.entertainment!),
            const SizedBox(height: 16),
          ],

          // ── 筋肉ビジュアライザー ──────────────────────────────
          if (record.trainedMuscles.isNotEmpty) ...[
            const Text('ターゲット筋群',
                style: TextStyle(
                    color: AppColors.textSecond,
                    fontSize: 11,
                    letterSpacing: 1)),
            const SizedBox(height: 8),
            MuscleVisualizer(trainedMuscles: record.trainedMuscles),
            const SizedBox(height: 16),
          ],

          // ── セットサマリー ────────────────────────────────────
          const Text('セット実績',
              style: TextStyle(
                  color: AppColors.textSecond, fontSize: 11, letterSpacing: 1)),
          const SizedBox(height: 8),
          ...record.sets.map((s) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                        child: Text(s.exerciseName,
                            style: const TextStyle(fontSize: 13))),
                    Text(
                      '${s.weightKg}kg × ${s.reps}回 = ${s.volume.toStringAsFixed(0)}kg',
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecond,
                          fontFamily: 'monospace'),
                    ),
                  ],
                ),
              )),

          const SizedBox(height: 12),
          const Divider(color: Colors.white12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('総挙上重量',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecond)),
              Text(
                '${record.totalVolume.toStringAsFixed(0)} kg',
                style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 16),
              ),
            ],
          ),

          const SizedBox(height: 12),
          AppGradientButton(
            onPressed: onDelete,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            borderRadius: BorderRadius.circular(AppColors.radiusS),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.delete_outline, size: 18),
                SizedBox(width: 6),
                Text('削除', style: TextStyle(fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _AppDrawer
//   ハンバーガーメニューから開くサイドメニュー。v1.0 で必要な遷移をすべて
//   1 箇所に集約する。各項目をタップすると Drawer を閉じてから対象画面に
//   遷移する (showDialog 系は閉じずに重ね表示)。
// ─────────────────────────────────────────────────────────────────────────────
class _AppDrawer extends StatelessWidget {
  const _AppDrawer();

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.surface,
      child: SafeArea(
        child: Column(
          children: [
            // ── ヘッダー（ロゴ + タグライン）─────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryDim],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '💪 Muscle Mate',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '筋トレをもっと気軽に楽しく',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            // ── メニュー項目 ─────────────────────────────────────────
            _DrawerTile(
              icon: Icons.history,
              label: '履歴',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const HistoryScreen()),
                );
              },
            ),
            _DrawerTile(
              icon: Icons.settings_outlined,
              label: '設定',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
            ),
            const Divider(color: AppColors.border, height: 1),
            _DrawerTile(
              icon: Icons.menu_book_outlined,
              label: '論文の出典',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const CitationsScreen()),
                );
              },
            ),
            _DrawerTile(
              icon: Icons.privacy_tip_outlined,
              label: 'プライバシーポリシー',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const PrivacyPolicyScreen()),
                );
              },
            ),
            _DrawerTile(
              icon: Icons.info_outline,
              label: 'アプリについて',
              onTap: () {
                Navigator.pop(context);
                showAboutDialog(
                  context: context,
                  applicationName: 'Muscle Mate',
                  applicationVersion: 'v1.0.0',
                  applicationLegalese:
                      '© Muscle Musician\n\n筋トレをもっと気軽に楽しく\n'
                      'GitHub: github.com/satoshiwaseda-training/muscle-mate-app',
                );
              },
            ),

            const Spacer(),

            // ── フッター（バージョン表示）─────────────────────────────
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Muscle Mate v1.0.0',
                style: TextStyle(
                  color: AppColors.textSecond.withValues(alpha: 0.6),
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _DrawerTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary, size: 22),
      title: Text(
        label,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      onTap: onTap,
      dense: true,
    );
  }
}
