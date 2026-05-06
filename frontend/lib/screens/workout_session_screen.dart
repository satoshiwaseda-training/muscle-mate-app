// ワークアウトセッション画面
// セットごとに重量・回数を記録 → 完了時に成果画面へ遷移
import 'package:flutter/material.dart';
import '../main.dart' show AppColors, AppGradientButton;
import '../models/workout_plan.dart';
import '../models/workout_record.dart';
import '../services/api_service.dart';
import '../services/local_storage_service.dart';
import 'workout_result_screen.dart';

class WorkoutSessionScreen extends StatefulWidget {
  final DaySession session;
  final String planName;

  const WorkoutSessionScreen({
    super.key,
    required this.session,
    required this.planName,
  });

  @override
  State<WorkoutSessionScreen> createState() => _WorkoutSessionScreenState();
}

class _WorkoutSessionScreenState extends State<WorkoutSessionScreen> {
  // exercise index → set index → (weight, reps) の入力値
  late List<List<_SetInput>> _inputs;
  bool _loading = false;
  bool _gentleMode = false;

  @override
  void initState() {
    super.initState();
    _inputs = widget.session.exercises.map((ex) {
      final setCount = ex.sets <= 0 ? 3 : ex.sets;
      return List.generate(
        setCount,
        (i) => _SetInput(
          weight: ex.weightKg ?? 0,
          reps: _parseRepsDefault(ex.reps),
          completed: false,
        ),
      );
    }).toList();
  }

  int _parseRepsDefault(String reps) {
    final match = RegExp(r'\d+').firstMatch(reps);
    return match != null ? int.parse(match.group(0)!) : 10;
  }

  Future<void> _finish() async {
    setState(() => _loading = true);

    // 全セットを記録
    final sets = <SetRecord>[];
    final trainedMuscles = <String>{};
    for (var i = 0; i < widget.session.exercises.length; i++) {
      final ex = widget.session.exercises[i];
      var completedExercise = false;
      for (var j = 0; j < _inputs[i].length; j++) {
        final inp = _inputs[i][j];
        if (inp.completed && inp.weight > 0 && inp.reps > 0) {
          completedExercise = true;
          sets.add(SetRecord(
            exerciseName: ex.nameJa,
            weightKg: inp.weight,
            reps: inp.reps,
          ));
        }
      }
      if (completedExercise) {
        trainedMuscles.addAll(ex.targetMuscles);
      }
    }

    final totalKg = sets.fold(0.0, (s, r) => s + r.volume);
    final ent = await ApiService.getEntertainment(totalKg);

    final now = DateTime.now();
    final record = WorkoutRecord(
      id: now.toIso8601String(),
      date: now,
      planName: widget.session.sessionName.trim().isEmpty
          ? widget.planName
          : widget.session.sessionName,
      trainedMuscles: trainedMuscles.isEmpty
          ? widget.session.targetMuscles.map((m) => m).toList()
          : trainedMuscles.toList(),
      sets: sets,
      entertainment: ent,
    );
    await LocalStorageService.save(record);

    // 全履歴を取得して成果画面へ
    final history = await LocalStorageService.loadAll();

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => WorkoutResultScreen(
          record: record,
          history: history,
        ),
      ),
    );
  }

  void _applyGentleMode() {
    setState(() {
      _gentleMode = true;
      for (final exerciseInputs in _inputs) {
        for (final input in exerciseInputs) {
          input.weight = (input.weight * 0.85).clamp(0, 999).toDouble();
          input.reps = input.reps > 8 ? input.reps - 2 : input.reps;
        }
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('今日は軽めに調整しました')),
    );
  }

  void _skipExercise(int exerciseIndex) {
    setState(() {
      for (final input in _inputs[exerciseIndex]) {
        input.completed = false;
        input.weight = 0;
        input.reps = 0;
      }
    });
  }

  void _copyFirstSetToAll(int exerciseIndex) {
    final first = _inputs[exerciseIndex].first;
    setState(() {
      for (final input in _inputs[exerciseIndex].skip(1)) {
        input.weight = first.weight;
        input.reps = first.reps;
      }
    });
  }

  void _addSet(int exerciseIndex) {
    final last = _inputs[exerciseIndex].isNotEmpty
        ? _inputs[exerciseIndex].last
        : _SetInput(weight: 0, reps: 10, completed: false);
    setState(() {
      _inputs[exerciseIndex].add(
        _SetInput(
          weight: last.weight,
          reps: last.reps,
          completed: false,
        ),
      );
    });
  }

  void _removeSet(int exerciseIndex, int setIndex) {
    if (_inputs[exerciseIndex].length <= 1) return;
    setState(() {
      _inputs[exerciseIndex].removeAt(setIndex);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  IconButton(
                    tooltip: '戻る',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.surfaceHigh,
                      foregroundColor: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      '終了',
                      style: TextStyle(color: AppColors.textSecond),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _gentleMode ? null : _applyGentleMode,
                    icon: const Icon(Icons.spa_outlined),
                    label: Text(_gentleMode ? '軽めに調整済み' : '軽めにする'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.pause_circle_outline),
                    label: const Text('今日はここまで'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 6, 2, 14),
              child: Row(
                children: [
                  Text(
                    '全${widget.session.exercises.length}種目',
                    style: const TextStyle(
                      color: AppColors.textSecond,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        minHeight: 6,
                        value: widget.session.exercises.isEmpty
                            ? 0
                            : 1 / widget.session.exercises.length,
                        backgroundColor: AppColors.surfaceHigh,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.primary),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ...widget.session.exercises
                .asMap()
                .entries
                .map((e) => _ExerciseCard(
                      exercise: e.value,
                      exerciseIndex: e.key,
                      totalExercises: widget.session.exercises.length,
                      inputs: _inputs[e.key],
                      onChanged: () => setState(() {}),
                      onSkip: () => _skipExercise(e.key),
                      onCopyFirstSet: () => _copyFirstSetToAll(e.key),
                      onAddSet: () => _addSet(e.key),
                      onRemoveSet: (setIndex) => _removeSet(e.key, setIndex),
                    )),
            const SizedBox(height: 24),
            AppGradientButton(
              onPressed: _loading ? null : _finish,
              padding: const EdgeInsets.symmetric(vertical: 18),
              borderRadius: BorderRadius.circular(28),
              child: Center(
                child: Text(
                  _loading ? '保存中...' : '今日の記録を保存する',
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── セット入力カード ──────────────────────────────────────────────────────

class _SetInput {
  double weight;
  int reps;
  bool completed;
  _SetInput({
    required this.weight,
    required this.reps,
    required this.completed,
  });
}

class _ExerciseCard extends StatelessWidget {
  final Exercise exercise;
  final int exerciseIndex;
  final int totalExercises;
  final List<_SetInput> inputs;
  final VoidCallback onChanged;
  final VoidCallback onSkip;
  final VoidCallback onCopyFirstSet;
  final VoidCallback onAddSet;
  final ValueChanged<int> onRemoveSet;

  const _ExerciseCard({
    required this.exercise,
    required this.exerciseIndex,
    required this.totalExercises,
    required this.inputs,
    required this.onChanged,
    required this.onSkip,
    required this.onCopyFirstSet,
    required this.onAddSet,
    required this.onRemoveSet,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _CuteExerciseAvatar(
                  label: exercise.nameJa,
                  muscles: exercise.targetMuscles,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exercise.nameJa,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          _MiniBadge(
                              _primaryMuscleLabel(exercise.targetMuscles)),
                          _MiniBadge(exercise.equipment.label, muted: true),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.keyboard_arrow_down),
              ],
            ),
          ),
          ...inputs.asMap().entries.map(
                (entry) => _SetEditor(
                  setIndex: entry.key,
                  input: entry.value,
                  canRemove: inputs.length > 1,
                  onChanged: onChanged,
                  onRemove: () => onRemoveSet(entry.key),
                ),
              ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onAddSet,
                    icon: const Icon(Icons.add),
                    label: const Text('セットを追加'),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onCopyFirstSet,
                        icon: const Icon(Icons.refresh),
                        label: const Text('1セット目と同じにする'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onSkip,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('この種目をスキップ'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SetEditor extends StatelessWidget {
  final int setIndex;
  final _SetInput input;
  final bool canRemove;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  const _SetEditor({
    required this.setIndex,
    required this.input,
    required this.canRemove,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 2),
            child: Row(
              children: [
                Checkbox(
                  value: input.completed,
                  activeColor: AppColors.secondary,
                  onChanged: (value) {
                    input.completed = value ?? false;
                    onChanged();
                  },
                ),
                Expanded(
                  child: Text(
                    '${setIndex + 1}セット目',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (canRemove)
                  IconButton(
                    tooltip: 'セットを削除',
                    onPressed: onRemove,
                    icon: const Icon(Icons.close),
                    color: AppColors.textSecond,
                  ),
              ],
            ),
          ),
          _StepperBlock(
            label: '重量',
            value: input.weight.toStringAsFixed(1),
            unit: 'kg',
            decimal: true,
            onValueChanged: (value) {
              input.weight = double.tryParse(value) ?? input.weight;
              onChanged();
            },
            onMinus: () {
              input.weight = (input.weight - 2.5).clamp(0, 999).toDouble();
              onChanged();
            },
            onPlus: () {
              input.weight = (input.weight + 2.5).clamp(0, 999).toDouble();
              onChanged();
            },
          ),
          _StepperBlock(
            label: '回数',
            value: input.reps.toString(),
            unit: '回',
            onValueChanged: (value) {
              input.reps = int.tryParse(value) ?? input.reps;
              onChanged();
            },
            onMinus: () {
              input.reps = (input.reps - 1).clamp(0, 999).toInt();
              onChanged();
            },
            onPlus: () {
              input.reps = (input.reps + 1).clamp(0, 999).toInt();
              onChanged();
            },
          ),
        ],
      ),
    );
  }
}

class _CuteExerciseAvatar extends StatelessWidget {
  final String label;
  final List<String> muscles;

  const _CuteExerciseAvatar({
    required this.label,
    required this.muscles,
  });

  @override
  Widget build(BuildContext context) {
    final icon = _exerciseIcon(label, muscles);
    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.secondary.withValues(alpha: 0.95),
            AppColors.primary.withValues(alpha: 0.95),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // ホーム画面と同じマスコット画像で統一
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.asset(
              'assets/ui/home/home_mascot_character.png',
              width: 70,
              height: 70,
              fit: BoxFit.cover,
              alignment: Alignment.bottomCenter,
            ),
          ),
          // 右下に種目カテゴリの小バッジを残す（一目で胸/背/脚等を識別）
          Positioned(
            right: 6,
            bottom: 6,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: AppColors.background,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: Icon(icon, color: AppColors.primary, size: 14),
            ),
          ),
        ],
      ),
    );
  }

  IconData _exerciseIcon(String label, List<String> muscles) {
    final muscleSet = muscles.toSet();
    if (label.contains('ランジ') || label.contains('スクワット')) {
      return Icons.directions_walk;
    }
    if (muscleSet.contains('chest')) return Icons.favorite;
    if (muscleSet.contains('back')) return Icons.open_in_full;
    if (muscleSet.contains('core')) return Icons.self_improvement;
    return Icons.fitness_center;
  }
}

class _StepperBlock extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final bool decimal;
  final ValueChanged<String> onValueChanged;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  const _StepperBlock({
    required this.label,
    required this.value,
    required this.unit,
    this.decimal = false,
    required this.onValueChanged,
    required this.onMinus,
    required this.onPlus,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _RoundIconButton(icon: Icons.remove, onPressed: onMinus),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: TextFormField(
                    key: ValueKey('$label-$value'),
                    initialValue: value,
                    textAlign: TextAlign.center,
                    keyboardType:
                        TextInputType.numberWithOptions(decimal: decimal),
                    textInputAction: TextInputAction.next,
                    onChanged: onValueChanged,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 38,
                      fontWeight: FontWeight.w900,
                    ),
                    decoration: InputDecoration(
                      suffixText: unit,
                      suffixStyle: const TextStyle(
                        color: AppColors.textSecond,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                      filled: true,
                      fillColor: AppColors.background.withValues(alpha: 0.35),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: AppColors.primary,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              _RoundIconButton(icon: Icons.add, onPressed: onPlus),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  final String label;
  final bool muted;

  const _MiniBadge(this.label, {this.muted = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: muted
            ? Colors.white.withValues(alpha: 0.08)
            : AppColors.secondary.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: muted
              ? Colors.white.withValues(alpha: 0.08)
              : AppColors.secondary.withValues(alpha: 0.45),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: muted ? AppColors.textSecond : AppColors.secondary,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _RoundIconButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 54,
      height: 54,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: 28),
        style: IconButton.styleFrom(
          backgroundColor: AppColors.surfaceHigh,
          foregroundColor: AppColors.textPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: AppColors.border),
          ),
        ),
      ),
    );
  }
}

String _primaryMuscleLabel(List<String> muscles) {
  final set = muscles.toSet();
  if (set.contains('quads') ||
      set.contains('hamstrings') ||
      set.contains('glutes')) {
    return '下半身';
  }
  if (set.contains('chest')) return '胸';
  if (set.contains('back')) return '背中';
  if (set.contains('shoulders')) return '肩';
  if (set.contains('core')) return '体幹';
  return '全身';
}
