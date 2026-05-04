import 'package:flutter/material.dart';
import '../main.dart' show AppColors, AppGradientButton;
import '../models/workout_plan.dart';
import 'workout_session_screen.dart';

class ManualWorkoutBuilderScreen extends StatefulWidget {
  const ManualWorkoutBuilderScreen({super.key});

  @override
  State<ManualWorkoutBuilderScreen> createState() =>
      _ManualWorkoutBuilderScreenState();
}

class _ManualWorkoutBuilderScreenState
    extends State<ManualWorkoutBuilderScreen> {
  String _selectedGroup = 'chest';
  final List<_ManualDraft> _drafts = [];

  void _toggleExercise(_CatalogExercise exercise) {
    final index =
        _drafts.indexWhere((d) => d.exercise.nameJa == exercise.nameJa);
    setState(() {
      if (index >= 0) {
        _drafts.removeAt(index);
      } else {
        _drafts.add(_ManualDraft(exercise: exercise));
      }
    });
  }

  void _showExercisePicker() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        var selectedGroup = _selectedGroup;
        return StatefulBuilder(
          builder: (context, setModalState) {
            final exercises =
                _catalog[selectedGroup] ?? const <_CatalogExercise>[];
            return DraggableScrollableSheet(
              initialChildSize: 0.82,
              minChildSize: 0.5,
              maxChildSize: 0.92,
              builder: (context, controller) {
                return Container(
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(22)),
                  ),
                  child: ListView(
                    controller: controller,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    children: [
                      const Text(
                        '種目を選ぶ',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _groupOrder.map((group) {
                            final selected = group == selectedGroup;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(_groupLabels[group] ?? group),
                                selected: selected,
                                onSelected: (_) {
                                  setModalState(() => selectedGroup = group);
                                  setState(() => _selectedGroup = group);
                                },
                                selectedColor: AppColors.primary,
                                backgroundColor: AppColors.surfaceHigh,
                                labelStyle: TextStyle(
                                  color: selected
                                      ? AppColors.background
                                      : AppColors.textPrimary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...exercises.map((exercise) {
                        final selected = _drafts.any((draft) =>
                            draft.exercise.nameJa == exercise.nameJa);
                        return _ExercisePickCard(
                          exercise: exercise,
                          selected: selected,
                          onTap: () {
                            _toggleExercise(exercise);
                            setModalState(() {});
                          },
                        );
                      }),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _startWorkout() {
    if (_drafts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('種目を1つ以上選んでください')),
      );
      return;
    }

    final exercises = _drafts.map((draft) {
      return Exercise(
        nameJa: draft.exercise.nameJa,
        nameEn: draft.exercise.nameEn,
        sets: draft.sets,
        reps: draft.repsController.text.trim().isEmpty
            ? '10'
            : draft.repsController.text.trim(),
        restSeconds: 90,
        equipment: draft.exercise.equipment,
        targetMuscles: draft.exercise.targetMuscles,
        coachingPoint: '無理のない範囲で、痛みがあれば中止してください。',
        weightKg: double.tryParse(draft.weightController.text.trim()) ?? 0,
      );
    }).toList();

    final session = DaySession(
      dayOfWeek: 'today',
      sessionName: '自分で選んだメニュー',
      targetMuscles: exercises.expand((e) => e.targetMuscles).toSet().toList(),
      estimatedDurationMinutes: (_drafts.length * 6).clamp(10, 90),
      exercises: exercises,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WorkoutSessionScreen(
          session: session,
          planName: '自分で選んだメニュー',
        ),
      ),
    );
  }

  @override
  void dispose() {
    for (final draft in _drafts) {
      draft.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final exercises = _catalog[_selectedGroup] ?? const <_CatalogExercise>[];
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'メニューを自分で作る',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
        backgroundColor: AppColors.background,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        children: [
          const Text(
            '部位を選んで、やりたい種目を追加してください。あとから重量・回数・セット数を変えられます。',
            style: TextStyle(
              color: AppColors.textSecond,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _groupOrder.map((group) {
                final selected = group == _selectedGroup;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(_groupLabels[group] ?? group),
                    selected: selected,
                    onSelected: (_) => setState(() => _selectedGroup = group),
                    selectedColor: AppColors.primary,
                    backgroundColor: AppColors.surfaceHigh,
                    labelStyle: TextStyle(
                      color: selected
                          ? AppColors.background
                          : AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '種目を選ぶ',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          ...exercises.map((exercise) {
            final selected = _drafts
                .any((draft) => draft.exercise.nameJa == exercise.nameJa);
            return _ExercisePickCard(
              exercise: exercise,
              selected: selected,
              onTap: () => _toggleExercise(exercise),
            );
          }),
          if (_drafts.isNotEmpty) ...[
            const SizedBox(height: 22),
            const Text(
              '今日やる種目',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            ..._drafts.map((draft) => _SelectedDraftCard(
                  draft: draft,
                  onRemove: () => _toggleExercise(draft.exercise),
                  onChanged: () => setState(() {}),
                )),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: _drafts.isEmpty
              ? AppGradientButton(
                  onPressed: _showExercisePicker,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: const Center(
                    child: Text(
                      '種目を選ぶ',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                )
              : AppGradientButton(
                  onPressed: _startWorkout,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: const Center(
                    child: Text(
                      'この内容で記録を始める',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _ExercisePickCard extends StatelessWidget {
  final _CatalogExercise exercise;
  final bool selected;
  final VoidCallback onTap;

  const _ExercisePickCard({
    required this.exercise,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: selected
          ? AppColors.primary.withValues(alpha: 0.18)
          : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: selected ? AppColors.primary : AppColors.border,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(
                selected ? Icons.check_circle : Icons.add_circle_outline,
                color: selected ? AppColors.primary : AppColors.secondary,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exercise.nameJa,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${exercise.equipment.label} / ${exercise.note}',
                      style: const TextStyle(color: AppColors.textSecond),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary : AppColors.secondary,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  selected ? '選択中' : '追加',
                  style: const TextStyle(
                    color: AppColors.background,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectedDraftCard extends StatelessWidget {
  final _ManualDraft draft;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const _SelectedDraftCard({
    required this.draft,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  draft.exercise.nameJa,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text(
                'セット数',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              _SmallStepButton(
                icon: Icons.remove,
                onTap: draft.sets <= 1
                    ? null
                    : () {
                        draft.sets--;
                        onChanged();
                      },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text(
                  '${draft.sets}',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _SmallStepButton(
                icon: Icons.add,
                onTap: () {
                  draft.sets++;
                  onChanged();
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _NumberField(
                  controller: draft.weightController,
                  label: '重量',
                  suffix: 'kg',
                  decimal: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _NumberField(
                  controller: draft.repsController,
                  label: '回数',
                  suffix: '回',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String suffix;
  final bool decimal;

  const _NumberField({
    required this.controller,
    required this.label,
    required this.suffix,
    this.decimal = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      textInputAction: TextInputAction.next,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 22,
        fontWeight: FontWeight.w900,
      ),
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        filled: true,
        fillColor: AppColors.surfaceHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }
}

class _ManualDraft {
  final _CatalogExercise exercise;
  final TextEditingController weightController;
  final TextEditingController repsController;
  int sets = 3;

  _ManualDraft({required this.exercise})
      : weightController = TextEditingController(text: '20'),
        repsController = TextEditingController(text: '10');

  void dispose() {
    weightController.dispose();
    repsController.dispose();
  }
}

class _SmallStepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _SmallStepButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 42,
      height: 42,
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, size: 20),
        style: IconButton.styleFrom(
          backgroundColor: AppColors.surfaceHigh,
          foregroundColor: AppColors.textPrimary,
          disabledForegroundColor: AppColors.textSecond.withValues(alpha: 0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.border),
          ),
        ),
      ),
    );
  }
}

class _CatalogExercise {
  final String nameJa;
  final String nameEn;
  final Equipment equipment;
  final List<String> targetMuscles;
  final String note;

  const _CatalogExercise(
    this.nameJa,
    this.nameEn,
    this.equipment,
    this.targetMuscles,
    this.note,
  );
}

const _groupLabels = {
  'chest': '胸',
  'back': '背中',
  'shoulders': '肩',
  'legs': '脚',
  'biceps': '二頭',
  'triceps': '三頭',
  'core': '体幹',
};

const _groupOrder = [
  'chest',
  'back',
  'shoulders',
  'legs',
  'biceps',
  'triceps',
  'core',
];

const _catalog = <String, List<_CatalogExercise>>{
  'chest': [
    _CatalogExercise(
        'ベンチプレス', 'Bench Press', Equipment.barbell, ['chest'], '胸の定番'),
    _CatalogExercise('インクラインダンベルプレス', 'Incline DB Press', Equipment.dumbbell,
        ['chest'], '胸上部'),
    _CatalogExercise(
        'チェストプレス', 'Chest Press', Equipment.machine, ['chest'], '安定して押せる'),
    _CatalogExercise(
        'ダンベルフライ', 'DB Fly', Equipment.dumbbell, ['chest'], '胸を大きく動かす'),
    _CatalogExercise(
        'ケーブルフライ', 'Cable Fly', Equipment.cable, ['chest'], '胸に効かせやすい'),
    _CatalogExercise(
        'ディップス', 'Dips', Equipment.bodyweight, ['chest', 'triceps'], '自重でしっかり'),
  ],
  'back': [
    _CatalogExercise(
        'ラットプルダウン', 'Lat Pulldown', Equipment.machine, ['back'], '広背筋'),
    _CatalogExercise(
        'ベントオーバーロウ', 'Bent Over Row', Equipment.barbell, ['back'], '背中の厚み'),
    _CatalogExercise(
        'ワンハンドロウ', 'One Arm Row', Equipment.dumbbell, ['back'], '左右差調整'),
    _CatalogExercise(
        'シーテッドロウ', 'Seated Row', Equipment.machine, ['back'], '背中に効かせやすい'),
    _CatalogExercise('デッドリフト', 'Deadlift', Equipment.barbell,
        ['back', 'hamstrings'], '全身をしっかり使う'),
  ],
  'shoulders': [
    _CatalogExercise('ショルダープレス', 'Shoulder Press', Equipment.dumbbell,
        ['shoulders'], '肩の基本'),
    _CatalogExercise('ミリタリープレス', 'Military Press', Equipment.barbell,
        ['shoulders'], '体幹も使う'),
    _CatalogExercise(
        'サイドレイズ', 'Side Raise', Equipment.dumbbell, ['shoulders'], '肩幅づくり'),
    _CatalogExercise(
        'リアデルト', 'Rear Delt', Equipment.machine, ['shoulders'], '肩後部'),
    _CatalogExercise(
        'アップライトロウ', 'Upright Row', Equipment.barbell, ['shoulders'], '肩上部'),
  ],
  'legs': [
    _CatalogExercise('スクワット', 'Squat', Equipment.barbell,
        ['quads', 'hamstrings', 'glutes'], '脚の定番'),
    _CatalogExercise('ブルガリアンスクワット', 'Bulgarian Split Squat', Equipment.dumbbell,
        ['quads', 'glutes'], '片脚'),
    _CatalogExercise(
        'レッグプレス', 'Leg Press', Equipment.machine, ['quads'], '安定して押せる'),
    _CatalogExercise('ルーマニアンデッドリフト', 'RDL', Equipment.barbell,
        ['hamstrings', 'glutes'], 'ハム・臀部'),
    _CatalogExercise(
        'レッグエクステンション', 'Leg Extension', Equipment.machine, ['quads'], '四頭筋'),
    _CatalogExercise(
        'レッグカール', 'Leg Curl', Equipment.machine, ['hamstrings'], 'ハム'),
    _CatalogExercise(
        'カーフレイズ', 'Calf Raise', Equipment.machine, ['calves'], 'ふくらはぎ'),
  ],
  'biceps': [
    _CatalogExercise(
        'バーベルカール', 'Barbell Curl', Equipment.barbell, ['biceps'], '二頭の基本'),
    _CatalogExercise(
        'EZバーカール', 'EZ Curl', Equipment.barbell, ['biceps'], '手首に優しい'),
    _CatalogExercise(
        'ケーブルカール', 'Cable Curl', Equipment.cable, ['biceps'], '腕に効かせやすい'),
    _CatalogExercise(
        'ハンマーカール', 'Hammer Curl', Equipment.dumbbell, ['biceps'], '前腕も使う'),
  ],
  'triceps': [
    _CatalogExercise(
        'ケーブルプレスダウン', 'Cable Pushdown', Equipment.cable, ['triceps'], '三頭の基本'),
    _CatalogExercise('ライイングエクステンション', 'Lying Extension', Equipment.barbell,
        ['triceps'], '腕を大きく動かす'),
    _CatalogExercise('オーバーヘッドエクステンション', 'Overhead Extension',
        Equipment.dumbbell, ['triceps'], '長頭'),
    _CatalogExercise('ナローベンチプレス', 'Close Grip Bench', Equipment.barbell,
        ['triceps'], 'しっかり押す'),
  ],
  'core': [
    _CatalogExercise('プランク', 'Plank', Equipment.bodyweight, ['core'], '体幹の基本'),
    _CatalogExercise(
        'アブローラー', 'Ab Wheel', Equipment.bodyweight, ['core'], '体幹をしっかり使う'),
    _CatalogExercise(
        'アブドミナル', 'Abdominal Crunch', Equipment.machine, ['core'], '腹直筋'),
    _CatalogExercise(
        'ロシアンツイスト', 'Russian Twist', Equipment.bodyweight, ['core'], '腹斜筋'),
    _CatalogExercise(
        'デッドバグ', 'Dead Bug', Equipment.bodyweight, ['core'], '安全に体幹'),
  ],
};
