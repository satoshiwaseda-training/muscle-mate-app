// 生成されたワークアウトプランの表示画面
/// セッションを選んで「ワークアウト開始」ボタンでセッション画面へ
import 'package:flutter/material.dart';
import '../models/workout_plan.dart';
import 'workout_session_screen.dart';

class WorkoutPlanScreen extends StatelessWidget {
  final WorkoutPlan plan;
  const WorkoutPlanScreen({super.key, required this.plan});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(plan.planName, overflow: TextOverflow.ellipsis),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── プラン概要 ─────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(plan.planName,
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 4),
                  Text('推奨期間: ${plan.durationWeeks}週間'),
                  const Divider(height: 24),
                  Text('総合アドバイス',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(plan.generalAdvice),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── 週間スケジュール ───────────────────────────────
          ...plan.weeklySchedule
              .map((session) => _SessionCard(session: session, plan: plan)),
        ],
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final DaySession session;
  final WorkoutPlan plan;
  const _SessionCard({required this.session, required this.plan});

  String _dayLabel(String day) {
    const map = {
      'monday': '月', 'tuesday': '火', 'wednesday': '水',
      'thursday': '木', 'friday': '金', 'saturday': '土', 'sunday': '日',
    };
    return map[day] ?? day;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          ExpansionTile(
            title: Text(
              '${_dayLabel(session.dayOfWeek)}：${session.sessionName}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
                '${session.estimatedDurationMinutes}分 / ${session.exercises.length}種目'),
            children: session.exercises
                .map((ex) => _ExerciseTile(ex))
                .toList(),
          ),
          // ── ワークアウト開始ボタン ──────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => WorkoutSessionScreen(
                      session: session,
                      planName: plan.planName,
                    ),
                  ),
                ),
                icon: const Icon(Icons.play_arrow),
                label: const Text('このセッションを開始'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE53935),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseTile extends StatelessWidget {
  final Exercise exercise;
  const _ExerciseTile(this.exercise);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      title: Text('${exercise.nameJa}  (${exercise.nameEn})'),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${exercise.sets}セット × ${exercise.reps}'
            '  |  インターバル ${exercise.restSeconds}秒',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          if (exercise.weightKg != null)
            Text(
              '推奨重量: ${exercise.weightKg!.toStringAsFixed(1)} kg',
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFE53935)),
            ),
          const SizedBox(height: 4),
          Text(exercise.coachingPoint,
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
      isThreeLine: true,
    );
  }
}
