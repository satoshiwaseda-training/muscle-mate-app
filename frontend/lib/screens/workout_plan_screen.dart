// 生成されたワークアウトプランの表示画面
// セッションを選んで「ワークアウト開始」ボタンでセッション画面へ
import 'package:flutter/material.dart';
import '../main.dart' show AppColors;
import '../models/workout_plan.dart';
import 'workout_session_screen.dart';

const _replacementCatalog = <String, List<_ReplacementOption>>{
  'chest': [
    _ReplacementOption('ベンチプレス', ['胸', '三頭'], popularity: 'No.1', benefit: '高重量で基準を作りやすい', recommended: true),
    _ReplacementOption('インクラインダンベルプレス', ['胸上部', '肩前'], popularity: '人気', benefit: '胸上部を効率良く追い込める'),
    _ReplacementOption('インクラインベンチプレス', ['胸上部', '三頭'], popularity: '定番', benefit: '上部狙いでも重量を乗せやすい'),
    _ReplacementOption('チェストプレス', ['胸', '三頭'], popularity: '安定', benefit: 'フォームを崩さず追い込みやすい'),
    _ReplacementOption('ダンベルフライ', ['胸', 'ストレッチ'], popularity: '補助', benefit: '可動域を取りながら刺激を足せる'),
    _ReplacementOption('ケーブルフライ', ['胸', '収縮'], popularity: '人気', benefit: '収縮を感じやすく仕上げに向く'),
    _ReplacementOption('ディップス', ['胸下部', '三頭'], popularity: '強度高', benefit: '自重で強い刺激を入れやすい'),
  ],
  'back': [
    _ReplacementOption('ラットプルダウン', ['広背筋', '背中'], popularity: 'No.1', benefit: '広背筋を狙いやすく戻しやすい', recommended: true),
    _ReplacementOption('ベントオーバーロウ', ['背中', '広背筋'], popularity: '定番', benefit: '厚み作りに直結しやすい'),
    _ReplacementOption('ワンハンドロウ', ['広背筋', '左右差'], popularity: '人気', benefit: '左右差を整えやすい'),
    _ReplacementOption('ペンドレイロウ', ['背中', '爆発力'], popularity: '強度高', benefit: '立ち上がりの強さを作りやすい'),
    _ReplacementOption('Tバーロウ', ['背中', '厚み'], popularity: '人気', benefit: '背中中央の厚みを出しやすい'),
    _ReplacementOption('シーテッドロウ', ['背中', '菱形筋'], popularity: '安定', benefit: '収縮を感じながら追い込める'),
    _ReplacementOption('デッドリフト', ['背面全体', '下半身'], popularity: '高重量', benefit: '全身の出力をまとめて使える'),
  ],
  'shoulders': [
    _ReplacementOption('ショルダープレス', ['肩前', '三角筋'], popularity: 'No.1', benefit: '肩全体の基準種目にしやすい', recommended: true),
    _ReplacementOption('ミリタリープレス', ['肩前', '体幹'], popularity: '定番', benefit: '体幹も含めて強さを出しやすい'),
    _ReplacementOption('アーノルドプレス', ['肩前', '肩中部'], popularity: '人気', benefit: '可動域を広く使って追い込める'),
    _ReplacementOption('サイドレイズ', ['肩中部', '三角筋'], popularity: '仕上げ', benefit: '肩幅の見え方を作りやすい'),
    _ReplacementOption('フロントレイズ', ['肩前', '三角筋'], popularity: '補助', benefit: '前部を集中的に入れやすい'),
    _ReplacementOption('リアデルト', ['肩後部', '姿勢'], popularity: '人気', benefit: '後部と姿勢維持を整えやすい'),
    _ReplacementOption('アップライトロウ', ['肩', '僧帽筋'], popularity: '強度高', benefit: '肩上部にまとめて刺激を入れやすい'),
  ],
  'legs': [
    _ReplacementOption('スクワット', ['脚', '臀部'], popularity: 'No.1', benefit: '脚全体の軸として使いやすい', recommended: true),
    _ReplacementOption('ブルガリアンスクワット', ['脚', '臀部'], popularity: '人気', benefit: '片脚で深く追い込みやすい'),
    _ReplacementOption('レッグプレス', ['脚', '大腿四頭'], popularity: '定番', benefit: '高重量でも安定して押しやすい'),
    _ReplacementOption('ルーマニアンデッドリフト', ['ハム', '臀部'], popularity: '人気', benefit: 'ハムと臀部を効率良く狙える'),
    _ReplacementOption('レッグエクステンション', ['大腿四頭', '膝周り'], popularity: '補助', benefit: '四頭をピンポイントで仕上げやすい'),
    _ReplacementOption('レッグカール', ['ハム', '膝裏'], popularity: '補助', benefit: 'ハムを単独で入れやすい'),
    _ReplacementOption('カーフレイズ', ['ふくらはぎ', '下腿'], popularity: '仕上げ', benefit: '下腿のボリュームを足しやすい'),
    _ReplacementOption('ヒップスラスト', ['臀部', '脚'], popularity: '人気', benefit: '臀部主導で力を出しやすい'),
  ],
  'biceps': [
    _ReplacementOption('バーベルカール', ['二頭', '基本'], popularity: 'No.1', benefit: '基準重量を作りやすい', recommended: true),
    _ReplacementOption('EZバーカール', ['二頭', '前腕'], popularity: '人気', benefit: '手首負担を抑えて続けやすい'),
    _ReplacementOption('ケーブルカール', ['二頭', '収縮'], popularity: '定番', benefit: '張りを保ったまま追い込める'),
    _ReplacementOption('インクラインアームカール', ['二頭', '伸長'], popularity: '人気', benefit: '伸長刺激を入れやすい'),
    _ReplacementOption('インクラインハンマーカール', ['二頭', '腕橈骨筋'], popularity: '補助', benefit: '前腕も含めて厚みを出しやすい'),
    _ReplacementOption('ハンマーカール', ['二頭', '前腕'], popularity: '安定', benefit: '握りやすく継続しやすい'),
    _ReplacementOption('コンセントレーションカール', ['二頭', '収縮'], popularity: '仕上げ', benefit: '最後の収縮を作りやすい'),
  ],
  'triceps': [
    _ReplacementOption('ディップス', ['三頭', '胸'], popularity: 'No.1', benefit: '強い負荷で押し切りやすい', recommended: true),
    _ReplacementOption('ケーブルプレスダウン', ['三頭', '収縮'], popularity: '人気', benefit: '肘を安定させて入れやすい'),
    _ReplacementOption('プレスダウン', ['三頭', '基本'], popularity: '定番', benefit: '三頭を素直に狙いやすい'),
    _ReplacementOption('ライイングトライセプスエクステンション', ['三頭', '伸長'], popularity: '強度高', benefit: '長頭まで深く入れやすい'),
    _ReplacementOption('オーバーヘッドエクステンション', ['三頭', '長頭'], popularity: '人気', benefit: '長頭に集中しやすい'),
    _ReplacementOption('ナローベンチプレス', ['三頭', '胸'], popularity: '高重量', benefit: '押す力を残したまま追い込める'),
    _ReplacementOption('キックバック', ['三頭', '収縮'], popularity: '仕上げ', benefit: '最後の収縮感を作りやすい'),
  ],
  'core': [
    _ReplacementOption('プランク', ['体幹', '安定'], popularity: 'No.1', benefit: '基礎安定を作りやすい', recommended: true),
    _ReplacementOption('アブローラー', ['体幹', '腹直筋'], popularity: '人気', benefit: '高い負荷で体幹を使いやすい'),
    _ReplacementOption('アブドミナル', ['腹直筋', '収縮'], popularity: '定番', benefit: '腹直筋を収縮中心で入れやすい'),
    _ReplacementOption('ハンギングレッグレイズ', ['下腹部', '体幹'], popularity: '強度高', benefit: '下腹部まで狙いやすい'),
    _ReplacementOption('ロシアンツイスト', ['腹斜筋', '回旋'], popularity: '補助', benefit: '回旋動作を足しやすい'),
    _ReplacementOption('デッドバグ', ['体幹', '安定'], popularity: '安定', benefit: '安定して続けやすい'),
    _ReplacementOption('ケーブルクランチ', ['腹直筋', '収縮'], popularity: '人気', benefit: '負荷調整しながら追い込める'),
  ],
};

const _replacementTargetMuscles = {
  'chest': ['chest'],
  'back': ['back'],
  'shoulders': ['shoulders'],
  'legs': ['quads', 'hamstrings', 'glutes'],
  'biceps': ['biceps'],
  'triceps': ['triceps'],
  'core': ['core'],
};

const _replacementGroupOrder = [
  'chest',
  'back',
  'shoulders',
  'legs',
  'biceps',
  'triceps',
  'core',
];

class WorkoutPlanScreen extends StatefulWidget {
  final WorkoutPlan plan;
  final bool isOffline;
  const WorkoutPlanScreen({super.key, required this.plan, this.isOffline = false});

  @override
  State<WorkoutPlanScreen> createState() => _WorkoutPlanScreenState();
}

class _WorkoutPlanScreenState extends State<WorkoutPlanScreen> {
  late WorkoutPlan _editablePlan;

  @override
  void initState() {
    super.initState();
    _editablePlan = _copyPlan(widget.plan);
  }

  WorkoutPlan _copyPlan(WorkoutPlan plan) {
    return WorkoutPlan(
      planName: plan.planName,
      durationWeeks: plan.durationWeeks,
      generalAdvice: plan.generalAdvice,
      weeklySchedule: plan.weeklySchedule
          .map(
            (session) => DaySession(
              dayOfWeek: session.dayOfWeek,
              sessionName: session.sessionName,
              targetMuscles: List<String>.from(session.targetMuscles),
              estimatedDurationMinutes: session.estimatedDurationMinutes,
              exercises: session.exercises
                  .map(
                    (exercise) => Exercise(
                      nameJa: exercise.nameJa,
                      nameEn: exercise.nameEn,
                      sets: exercise.sets,
                      reps: exercise.reps,
                      restSeconds: exercise.restSeconds,
                      equipment: exercise.equipment,
                      targetMuscles: List<String>.from(exercise.targetMuscles),
                      coachingPoint: exercise.coachingPoint,
                      weightKg: exercise.weightKg,
                    ),
                  )
                  .toList(),
            ),
          )
          .toList(),
    );
  }

  void _deleteExercise(int sessionIndex, int exerciseIndex) {
    final sessions = [..._editablePlan.weeklySchedule];
    final session = sessions[sessionIndex];
    final exercises = [...session.exercises]..removeAt(exerciseIndex);
    sessions[sessionIndex] = DaySession(
      dayOfWeek: session.dayOfWeek,
      sessionName: session.sessionName,
      targetMuscles: session.targetMuscles,
      estimatedDurationMinutes: session.estimatedDurationMinutes,
      exercises: exercises,
    );
    setState(() {
      _editablePlan = WorkoutPlan(
        planName: _editablePlan.planName,
        durationWeeks: _editablePlan.durationWeeks,
        weeklySchedule: sessions,
        generalAdvice: _editablePlan.generalAdvice,
      );
    });
  }

  Future<void> _showReplaceSheet(
    BuildContext context,
    int sessionIndex,
    int exerciseIndex,
    Exercise exercise,
  ) async {
    final initialGroup = _primaryGroup(exercise.targetMuscles);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        var selectedGroup = initialGroup;
        return StatefulBuilder(
          builder: (context, setModalState) {
            final candidates =
                _replacementCatalog[selectedGroup] ?? const <_ReplacementOption>[];
            return SafeArea(
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '差し替え候補',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      '部位を切り替えながら候補を選べます',
                      style: TextStyle(
                        color: AppColors.textSecond,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _replacementGroupOrder.map((group) {
                          final selected = group == selectedGroup;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(_groupLabel(group)),
                              selected: selected,
                              onSelected: (_) {
                                setModalState(() => selectedGroup = group);
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: candidates.length,
                        separatorBuilder: (_, __) => const Divider(
                          color: AppColors.border,
                          height: 1,
                        ),
                        itemBuilder: (context, index) {
                          final candidate = candidates[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    candidate.nameJa,
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                if (candidate.popularity != null)
                                  Text(
                                    candidate.popularity!,
                                    style: const TextStyle(
                                      color: AppColors.textSecond,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                              ],
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    candidate.targetLabels.join(' / '),
                                    style: const TextStyle(
                                      color: AppColors.textSecond,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (candidate.benefit != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      candidate.benefit!,
                                      style: const TextStyle(
                                        color: AppColors.textSecond,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                  if (candidate.recommended) ...[
                                    const SizedBox(height: 4),
                                    const Text(
                                      '今回おすすめ',
                                      style: TextStyle(
                                        color: AppColors.primary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            onTap: () {
                              final replacement = Exercise(
                                nameJa: candidate.nameJa,
                                nameEn: candidate.nameJa,
                                sets: exercise.sets,
                                reps: exercise.reps,
                                restSeconds: exercise.restSeconds,
                                equipment: exercise.equipment,
                                targetMuscles: List<String>.from(
                                  _replacementTargetMuscles[selectedGroup] ??
                                      exercise.targetMuscles,
                                ),
                                coachingPoint: exercise.coachingPoint,
                                weightKg: exercise.weightKg,
                              );
                              _replaceExercise(
                                sessionIndex,
                                exerciseIndex,
                                replacement,
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '${exercise.nameJa} → ${candidate.nameJa} に差し替えました',
                                  ),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _replaceExercise(int sessionIndex, int exerciseIndex, Exercise replacement) {
    final sessions = [..._editablePlan.weeklySchedule];
    final session = sessions[sessionIndex];
    final exercises = [...session.exercises];
    exercises[exerciseIndex] = replacement;
    sessions[sessionIndex] = DaySession(
      dayOfWeek: session.dayOfWeek,
      sessionName: session.sessionName,
      targetMuscles: session.targetMuscles,
      estimatedDurationMinutes: session.estimatedDurationMinutes,
      exercises: exercises,
    );
    setState(() {
      _editablePlan = WorkoutPlan(
        planName: _editablePlan.planName,
        durationWeeks: _editablePlan.durationWeeks,
        weeklySchedule: sessions,
        generalAdvice: _editablePlan.generalAdvice,
      );
    });
  }

  String _primaryGroup(List<String> muscles) {
    final set = muscles.toSet();
    if (set.contains('biceps')) return 'biceps';
    if (set.contains('triceps')) return 'triceps';
    if (set.contains('shoulders')) return 'shoulders';
    if (set.contains('chest')) return 'chest';
    if (set.contains('back')) return 'back';
    if (set.contains('core')) return 'core';
    return 'legs';
  }

  String _groupLabel(String group) {
    const labels = {
      'chest': '胸',
      'back': '背中',
      'shoulders': '肩',
      'legs': '脚',
      'biceps': '二頭',
      'triceps': '三頭',
      'core': '体幹',
    };
    return labels[group] ?? '全身';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_editablePlan.planName, overflow: TextOverflow.ellipsis),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── オフラインバナー ──────────────────────────────
          if (widget.isOffline)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppColors.secondary.withValues(alpha: 0.4)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.wifi_off, color: AppColors.secondary, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'オフラインモード: 前回作成したトレーニング案を表示しています',
                      style: TextStyle(
                          color: AppColors.secondary, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),

          // ── プラン概要 ─────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_editablePlan.planName,
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 4),
                Text('推奨期間: ${_editablePlan.durationWeeks}週間',
                    style: const TextStyle(color: AppColors.textSecond)),
                const Divider(height: 24, color: AppColors.border),
                const Text('総合アドバイス',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(_editablePlan.generalAdvice,
                    style: const TextStyle(color: AppColors.textSecond)),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── 週間スケジュール ───────────────────────────────
          ..._editablePlan.weeklySchedule.asMap().entries.map(
                (entry) => _SessionCard(
                  sessionIndex: entry.key,
                  session: entry.value,
                  plan: _editablePlan,
                  onReplace: (exerciseIndex, exercise) =>
                      _showReplaceSheet(context, entry.key, exerciseIndex, exercise),
                  onDelete: (exerciseIndex) =>
                      _deleteExercise(entry.key, exerciseIndex),
                  groupLabel: _groupLabel,
                ),
              ),
        ],
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final int sessionIndex;
  final DaySession session;
  final WorkoutPlan plan;
  final void Function(int exerciseIndex, Exercise exercise) onReplace;
  final void Function(int exerciseIndex) onDelete;
  final String Function(String group) groupLabel;

  const _SessionCard({
    required this.sessionIndex,
    required this.session,
    required this.plan,
    required this.onReplace,
    required this.onDelete,
    required this.groupLabel,
  });

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
        border: Border.all(color: AppColors.border),
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
              children: session.exercises.asMap().entries.map((entry) {
                return _EditableExerciseTile(
                  exercise: entry.value,
                  groupLabel: groupLabel,
                  onReplace: () => onReplace(entry.key, entry.value),
                  onDelete: () => onDelete(entry.key),
                );
              }).toList(),
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

class _EditableExerciseTile extends StatelessWidget {
  final Exercise exercise;
  final String Function(String group) groupLabel;
  final VoidCallback onReplace;
  final VoidCallback onDelete;

  const _EditableExerciseTile({
    required this.exercise,
    required this.groupLabel,
    required this.onReplace,
    required this.onDelete,
  });

  String _primaryGroup(List<String> muscles) {
    final set = muscles.toSet();
    if (set.contains('biceps')) return 'biceps';
    if (set.contains('triceps')) return 'triceps';
    if (set.contains('shoulders')) return 'shoulders';
    if (set.contains('chest')) return 'chest';
    if (set.contains('back')) return 'back';
    if (set.contains('core')) return 'core';
    return 'legs';
  }

  @override
  Widget build(BuildContext context) {
    final group = groupLabel(_primaryGroup(exercise.targetMuscles));
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
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
          Text(
            '部位: $group',
            style: const TextStyle(
              color: AppColors.textSecond,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),

          // ── セット・レップ・重量 ────────────────────────────
          Row(
            children: [
              _InfoChip('${exercise.sets}セット', Icons.repeat),
              const SizedBox(width: 8),
              _InfoChip('回数 ${exercise.reps}', Icons.repeat),
              const SizedBox(width: 8),
              _InfoChip(
                exercise.weightKg != null
                    ? '重量 ${exercise.weightKg!.toStringAsFixed(1)}kg'
                    : '重量 未設定',
                Icons.fitness_center,
                highlight: exercise.weightKg != null,
              ),
            ],
          ),
          const SizedBox(height: 6),

          // ── コーチングポイント ─────────────────────────────
          Text(
            exercise.coachingPoint,
            style: const TextStyle(
                color: AppColors.textSecond, fontSize: 12),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              GestureDetector(
                onTap: onReplace,
                child: const Text(
                  '差し替え',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: onDelete,
                child: const Text(
                  '削除',
                  style: TextStyle(
                    color: AppColors.textSecond,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
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

class _ReplacementOption {
  final String nameJa;
  final List<String> targetLabels;
  final String? popularity;
  final String? benefit;
  final bool recommended;

  const _ReplacementOption(
    this.nameJa,
    this.targetLabels, {
    this.popularity,
    this.benefit,
    this.recommended = false,
  });
}
