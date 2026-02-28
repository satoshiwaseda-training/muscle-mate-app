/// 生成されたワークアウトプランの表示画面
import 'package:flutter/material.dart';
import '../models/workout_plan.dart';

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
          // ── プラン概要 ───────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plan.planName,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 4),
                  Text('推奨期間: ${plan.durationWeeks}週間'),
                  const Divider(height: 24),
                  Text(
                    '総合アドバイス',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(plan.generalAdvice),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── 週間スケジュール ──────────────────────────────────
          ...plan.weeklySchedule.map((session) => _SessionCard(session)),
        ],
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final DaySession session;
  const _SessionCard(this.session);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        title: Text(
          '${_dayLabel(session.dayOfWeek)}：${session.sessionName}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('${session.estimatedDurationMinutes}分 / ${session.exercises.length}種目'),
        children: session.exercises
            .map((ex) => _ExerciseTile(ex))
            .toList(),
      ),
    );
  }

  String _dayLabel(String day) {
    const map = {
      'monday': '月', 'tuesday': '火', 'wednesday': '水',
      'thursday': '木', 'friday': '金', 'saturday': '土', 'sunday': '日',
    };
    return map[day] ?? day;
  }
}

class _ExerciseTile extends StatelessWidget {
  final Exercise exercise;
  const _ExerciseTile(this.exercise);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      title: Text('${exercise.nameJa}  (${exercise.nameEn})'),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${exercise.sets}セット × ${exercise.reps}  |  インターバル ${exercise.restSeconds}秒',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Text(
            exercise.coachingPoint,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      isThreeLine: true,
    );
  }
}
