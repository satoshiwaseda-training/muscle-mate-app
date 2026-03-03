// 生成されたワークアウトプランの表示画面
// セッションを選んで「ワークアウト開始」ボタンでセッション画面へ
import 'package:flutter/material.dart';
import '../main.dart' show AppColors;
import '../models/workout_plan.dart';
import 'workout_session_screen.dart';

class WorkoutPlanScreen extends StatelessWidget {
  final WorkoutPlan plan;
  const WorkoutPlanScreen({super.key, required this.plan});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(plan.planName, overflow: TextOverflow.ellipsis),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── プラン概要 ─────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF2A2040)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(plan.planName,
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 4),
                Text('推奨期間: ${plan.durationWeeks}週間',
                    style: const TextStyle(color: AppColors.textSecond)),
                const Divider(height: 24, color: Color(0xFF2A2040)),
                const Text('総合アドバイス',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(plan.generalAdvice,
                    style: const TextStyle(color: AppColors.textSecond)),
              ],
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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2040)),
      ),
      child: Column(
        children: [
          Theme(
            data: Theme.of(context).copyWith(
              dividerColor: Colors.transparent,
            ),
            child: ExpansionTile(
              initiallyExpanded: true,
              title: Text(
                '${_dayLabel(session.dayOfWeek)}：${session.sessionName}',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary),
              ),
              subtitle: Text(
                '${session.estimatedDurationMinutes}分 / ${session.exercises.length}種目',
                style: const TextStyle(color: AppColors.textSecond),
              ),
              children: session.exercises
                  .map((ex) => _ExerciseTile(ex))
                  .toList(),
            ),
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
                  backgroundColor: AppColors.primary,
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
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFF2A2040))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 種目名 + 休憩時間バッジ ────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  exercise.nameJa,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppColors.textPrimary),
                ),
              ),
              const SizedBox(width: 8),
              _RestBadge(exercise.restSeconds),
            ],
          ),
          const SizedBox(height: 2),
          Text(exercise.nameEn,
              style: const TextStyle(
                  color: AppColors.textSecond, fontSize: 11)),
          const SizedBox(height: 6),

          // ── セット・レップ・重量 ────────────────────────────
          Row(
            children: [
              _InfoChip(
                  '${exercise.sets}セット × ${exercise.reps}',
                  Icons.repeat),
              if (exercise.weightKg != null) ...[
                const SizedBox(width: 8),
                _InfoChip(
                    '推奨 ${exercise.weightKg!.toStringAsFixed(1)}kg',
                    Icons.fitness_center,
                    highlight: true),
              ],
            ],
          ),
          const SizedBox(height: 6),

          // ── コーチングポイント ─────────────────────────────
          Text(
            exercise.coachingPoint,
            style: const TextStyle(
                color: AppColors.textSecond, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _RestBadge extends StatelessWidget {
  final int seconds;
  const _RestBadge(this.seconds);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer_outlined,
              size: 12, color: AppColors.primaryDim),
          const SizedBox(width: 3),
          Text(
            '休憩 $seconds秒',
            style: const TextStyle(
                fontSize: 11,
                color: AppColors.primaryDim,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool highlight;
  const _InfoChip(this.label, this.icon, {this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: highlight
            ? AppColors.secondary.withValues(alpha: 0.15)
            : AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 11,
              color: highlight ? AppColors.secondary : AppColors.textSecond),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
                fontSize: 11,
                color: highlight ? AppColors.secondary : AppColors.textSecond,
                fontWeight: highlight ? FontWeight.bold : FontWeight.normal),
          ),
        ],
      ),
    );
  }
}
