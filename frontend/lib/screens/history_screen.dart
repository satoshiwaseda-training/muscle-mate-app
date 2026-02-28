// 履歴 + カレンダー画面
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../models/workout_record.dart';
import '../services/local_storage_service.dart';
import '../widgets/muscle_visualizer.dart';
import '../widgets/entertainment_banner.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<WorkoutRecord> _records = [];
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final records = await LocalStorageService.loadAll();
    setState(() {
      _records = records;
      _loading = false;
    });
  }

  List<WorkoutRecord> _recordsForDay(DateTime day) => _records
      .where((r) =>
          r.date.year == day.year &&
          r.date.month == day.month &&
          r.date.day == day.day)
      .toList();

  @override
  Widget build(BuildContext context) {
    final selected = _selectedDay != null
        ? _recordsForDay(_selectedDay!)
        : <WorkoutRecord>[];

    return Scaffold(
      appBar: AppBar(title: const Text('トレーニング履歴'), centerTitle: true),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _records.isEmpty
              ? const Center(
                  child: Text(
                    'まだ記録がありません。\nワークアウトを完了すると記録されます！',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54),
                  ),
                )
              : ListView(
                  children: [
                    // ── カレンダー ─────────────────────────────────────
                    TableCalendar(
                      firstDay: DateTime(2025, 1, 1),
                      lastDay: DateTime(2030, 12, 31),
                      focusedDay: _focusedDay,
                      selectedDayPredicate: (d) =>
                          isSameDay(d, _selectedDay),
                      calendarStyle: CalendarStyle(
                        todayDecoration: BoxDecoration(
                          color: const Color(0xFFE53935).withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        selectedDecoration: const BoxDecoration(
                          color: Color(0xFFE53935),
                          shape: BoxShape.circle,
                        ),
                        markerDecoration: const BoxDecoration(
                          color: Color(0xFFFF6D00),
                          shape: BoxShape.circle,
                        ),
                        outsideDaysVisible: false,
                      ),
                      headerStyle: const HeaderStyle(
                          formatButtonVisible: false,
                          titleCentered: true),
                      eventLoader: (day) => _recordsForDay(day),
                      onDaySelected: (sel, foc) => setState(() {
                        _selectedDay = sel;
                        _focusedDay = foc;
                      }),
                      onPageChanged: (f) => _focusedDay = f,
                    ),
                    const Divider(),

                    // ── 選択日の記録 ──────────────────────────────────
                    if (selected.isNotEmpty)
                      ...selected.map((r) => _RecordCard(record: r,
                          onDelete: () async {
                            await LocalStorageService.delete(r.id);
                            _load();
                          }))
                    else if (_selectedDay != null)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('この日の記録はありません',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white54)),
                      ),

                    const Divider(),
                    const Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text('全記録',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    // ── 全記録リスト ──────────────────────────────────
                    ..._records.map((r) => _RecordCard(record: r,
                        onDelete: () async {
                          await LocalStorageService.delete(r.id);
                          _load();
                        })),
                  ],
                ),
    );
  }
}

class _RecordCard extends StatelessWidget {
  final WorkoutRecord record;
  final VoidCallback onDelete;
  const _RecordCard({required this.record, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('M/d (E) HH:mm', 'ja');
    return ExpansionTile(
      title: Text(record.planName,
          style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(fmt.format(record.date)),
      trailing: Text(
        '${record.totalVolume.toStringAsFixed(0)} kg',
        style: const TextStyle(
            color: Color(0xFFFF6D00), fontWeight: FontWeight.bold),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              // エンタメバナー
              if (record.entertainment != null)
                EntertainmentBanner(data: record.entertainment!),

              const SizedBox(height: 16),

              // 筋肉ビジュアライザー
              if (record.trainedMuscles.isNotEmpty)
                MuscleVisualizer(trainedMuscles: record.trainedMuscles),

              const SizedBox(height: 16),

              // 削除ボタン
              TextButton.icon(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                label: const Text('この記録を削除',
                    style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
