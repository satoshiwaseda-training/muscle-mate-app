// カレンダー起点型ホーム画面 — 筋トレMEMO風
// Gemini推奨: TableCalendar + BottomSheet でカレンダー主役UXを実現
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../main.dart' show AppColors;
import '../models/workout_record.dart';
import '../services/local_storage_service.dart';
import '../widgets/entertainment_banner.dart';
import '../widgets/muscle_visualizer.dart';
import 'plan_generator_screen.dart';
import 'settings_screen.dart';

class CalendarHomeScreen extends StatefulWidget {
  const CalendarHomeScreen({super.key});
  @override
  State<CalendarHomeScreen> createState() => _CalendarHomeScreenState();
}

class _CalendarHomeScreenState extends State<CalendarHomeScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  List<WorkoutRecord> _allRecords = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final records = await LocalStorageService.loadAll();
    if (mounted) setState(() { _allRecords = records; _loading = false; });
  }

  List<WorkoutRecord> _recordsFor(DateTime day) => _allRecords
      .where((r) =>
          r.date.year == day.year &&
          r.date.month == day.month &&
          r.date.day == day.day)
      .toList();

  bool _isToday(DateTime d) => isSameDay(d, DateTime.now());

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
    setState(() { _selectedDay = selected; _focusedDay = focused; });
    _showDayBottomSheet(selected);
  }

  void _showDayBottomSheet(DateTime day) {
    final records = _recordsFor(day);
    final isToday = _isToday(day);
    final fmt = DateFormat('M月d日(E)', 'ja');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DayBottomSheet(
        day: day,
        title: fmt.format(day),
        records: records,
        isToday: isToday,
        onStartWorkout: () {
          Navigator.pop(context);
          Navigator.push(context,
            MaterialPageRoute(builder: (_) => const PlanGeneratorScreen(startNow: true)));
        },
        onRefresh: _load,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayRecords = _recordsFor(today);
    final streak = _streak;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : CustomScrollView(
              slivers: [
                // ── ヘッダー ───────────────────────────────────────────
                SliverToBoxAdapter(
                  child: _Header(streak: streak, todayDone: todayRecords.isNotEmpty),
                ),

                // ── カレンダー ─────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: _FireCalendar(
                      focusedDay: _focusedDay,
                      selectedDay: _selectedDay,
                      eventLoader: _recordsFor,
                      onDaySelected: _onDayTapped,
                      onPageChanged: (d) => _focusedDay = d,
                    ),
                  ),
                ),

                // ── 今日のサマリー ─────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: _TodaySummary(
                      records: todayRecords,
                      onStart: () => _showDayBottomSheet(today),
                    ),
                  ),
                ),

                // ── 最近の実績 ─────────────────────────────────────────
                if (_allRecords.isNotEmpty) ...[
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: Text('最近の実績',
                          style: TextStyle(
                              color: AppColors.textSecond,
                              fontSize: 12,
                              letterSpacing: 1)),
                    ),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        child: _RecordTile(
                          record: _allRecords[i],
                          onTap: () => _showDayBottomSheet(_allRecords[i].date),
                        ),
                      ),
                      childCount: _allRecords.length.clamp(0, 5),
                    ),
                  ),
                ],
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            ),

      // ── FAB: AIメニュー生成 ─────────────────────────────────────────────
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showDayBottomSheet(DateTime.now()),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('トレーニング開始',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

// ── ヘッダー ──────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final int streak;
  final bool todayDone;
  const _Header({required this.streak, required this.todayDone});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 56, 20, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.15),
            AppColors.background,
          ],
        ),
      ),
      child: Row(
        children: [
          const Text('Muscle Mate',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5)),
          const Spacer(),
          // 設定アイコン
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const SettingsScreen()),
            ),
            icon: const Icon(Icons.settings_outlined,
                color: AppColors.textSecond),
            tooltip: '設定',
          ),
          const SizedBox(width: 4),
          // ストリーク表示
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: streak > 0
                  ? AppColors.primary.withValues(alpha: 0.15)
                  : AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: streak > 0 ? AppColors.primary : Colors.white12),
            ),
            child: Row(
              children: [
                Icon(
                  streak > 0 ? Icons.local_fire_department : Icons.local_fire_department_outlined,
                  color: streak > 0 ? AppColors.primary : Colors.white24,
                  size: 20,
                ),
                const SizedBox(width: 4),
                Text(
                  '$streak日',
                  style: TextStyle(
                    color: streak > 0 ? AppColors.primary : Colors.white24,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
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
        headerStyle: const HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextStyle: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 16),
          leftChevronIcon:
              Icon(Icons.chevron_left, color: AppColors.textSecond),
          rightChevronIcon:
              Icon(Icons.chevron_right, color: AppColors.textSecond),
          headerPadding: EdgeInsets.symmetric(vertical: 12),
        ),
        daysOfWeekStyle: const DaysOfWeekStyle(
          weekdayStyle:
              TextStyle(color: AppColors.textSecond, fontSize: 12),
          weekendStyle:
              TextStyle(color: AppColors.primary, fontSize: 12),
        ),
        calendarStyle: CalendarStyle(
          outsideDaysVisible: false,
          defaultTextStyle:
              const TextStyle(color: AppColors.textPrimary),
          weekendTextStyle:
              const TextStyle(color: AppColors.primary),
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
          selectedTextStyle: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold),
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
            gradient: LinearGradient(
              colors: [
                AppColors.primary.withValues(alpha: 0.2),
                AppColors.secondary.withValues(alpha: 0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.4)),
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
                  Text('タップして今日のトレーニングを開始！',
                      style: TextStyle(
                          color: AppColors.primary, fontSize: 12)),
                ],
              ),
            ],
          ),
        ),
      );
    }

    final totalVol =
        records.fold(0.0, (s, r) => s + r.totalVolume);
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
                  color: AppColors.textSecond,
                  fontSize: 11,
                  letterSpacing: 1)),
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
    final fmt = DateFormat('M/d(E)', 'ja');
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
                  Text(fmt.format(record.date),
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
              FilledButton.icon(
                onPressed: onStartWorkout,
                icon: const Icon(Icons.play_arrow),
                label: const Text('トレーニングを開始する'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // 実績
            if (records.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  isToday
                      ? 'まだ記録がありません。\nトレーニングを開始しましょう！'
                      : 'この日の記録はありません',
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
                  color: AppColors.textSecond,
                  fontSize: 11,
                  letterSpacing: 1)),
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
                      '${s.weightKg}kg × ${s.reps}rep = ${s.volume.toStringAsFixed(0)}kg',
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
          TextButton.icon(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline,
                color: Colors.redAccent, size: 18),
            label: const Text('削除',
                style: TextStyle(color: Colors.redAccent, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
