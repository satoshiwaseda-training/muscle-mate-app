// ワークアウトセッション画面
/// セットごとに重量・回数を記録 → 完了時に合計とエンタメを表示
import 'package:flutter/material.dart';
import '../models/workout_plan.dart';
import '../models/workout_record.dart';
import '../services/api_service.dart';
import '../services/local_storage_service.dart';
import '../widgets/entertainment_banner.dart';
import '../widgets/muscle_visualizer.dart';

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
  final List<SetRecord> _completedSets = [];
  bool _finished = false;
  bool _loading = false;
  Map<String, dynamic>? _entertainment;

  @override
  void initState() {
    super.initState();
    _inputs = widget.session.exercises.map((ex) {
      return List.generate(
        ex.sets,
        (i) => _SetInput(
          weight: ex.weightKg ?? 0,
          reps: _parseRepsDefault(ex.reps),
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
    for (var i = 0; i < widget.session.exercises.length; i++) {
      final ex = widget.session.exercises[i];
      for (var j = 0; j < ex.sets; j++) {
        final inp = _inputs[i][j];
        if (inp.weight > 0 && inp.reps > 0) {
          sets.add(SetRecord(
            exerciseName: ex.nameJa,
            weightKg: inp.weight,
            reps: inp.reps,
          ));
        }
      }
    }

    final totalKg = sets.fold(0.0, (s, r) => s + r.volume);

    // エンタメAPI呼び出し
    final ent = await ApiService.getEntertainment(totalKg);

    // ローカル保存
    final now = DateTime.now();
    final record = WorkoutRecord(
      id: now.toIso8601String(),
      date: now,
      planName: widget.planName,
      trainedMuscles:
          widget.session.targetMuscles.map((m) => m).toList(),
      sets: sets,
      entertainment: ent,
    );
    await LocalStorageService.save(record);

    setState(() {
      _completedSets.addAll(sets);
      _entertainment = ent;
      _finished = true;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_finished) return _buildResult();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.session.sessionName),
        centerTitle: true,
        backgroundColor: const Color(0xFFE53935),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ...widget.session.exercises.asMap().entries.map((e) =>
              _ExerciseCard(
                exercise: e.value,
                inputs: _inputs[e.key],
                onChanged: () => setState(() {}),
              )),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _loading ? null : _finish,
            icon: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.check_circle),
            label: Text(_loading ? '記録中...' : 'トレーニング完了！'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              padding: const EdgeInsets.symmetric(vertical: 16),
              textStyle: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResult() {
    final totalKg =
        _completedSets.fold(0.0, (s, r) => s + r.volume);

    return Scaffold(
      appBar: AppBar(
        title: const Text('セッション完了！'),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // エンタメバナー
          if (_entertainment != null)
            EntertainmentBanner(data: _entertainment!),
          if (_entertainment == null)
            _SimpleTotalCard(totalKg: totalKg),
          const SizedBox(height: 24),

          // 筋肉ビジュアライザー
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text('今日のターゲット筋群',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 16),
                  MuscleVisualizer(
                      trainedMuscles: widget.session.targetMuscles),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // セット実績リスト
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('実績サマリー',
                      style: Theme.of(context).textTheme.titleMedium),
                  const Divider(height: 16),
                  ..._completedSets.map((s) => Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(child: Text(s.exerciseName)),
                            Text(
                              '${s.weightKg.toStringAsFixed(1)}kg × ${s.reps}rep'
                              '  = ${s.volume.toStringAsFixed(0)}kg',
                              style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12),
                            ),
                          ],
                        ),
                      )),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () =>
                Navigator.popUntil(context, (r) => r.isFirst),
            icon: const Icon(Icons.home),
            label: const Text('ホームに戻る'),
          ),
        ],
      ),
    );
  }
}

// ── セット入力カード ──────────────────────────────────────────────────────

class _SetInput {
  double weight;
  int reps;
  _SetInput({required this.weight, required this.reps});
}

class _ExerciseCard extends StatelessWidget {
  final Exercise exercise;
  final List<_SetInput> inputs;
  final VoidCallback onChanged;

  const _ExerciseCard({
    required this.exercise,
    required this.inputs,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(exercise.nameJa,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                if (exercise.weightKg != null)
                  Chip(
                    label: Text('推奨: ${exercise.weightKg}kg',
                        style: const TextStyle(fontSize: 11)),
                    backgroundColor:
                        const Color(0xFFE53935).withValues(alpha: 0.15),
                  ),
              ],
            ),
            Text(exercise.coachingPoint,
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            ...List.generate(exercise.sets, (i) => _SetRow(
                  setNum: i + 1,
                  input: inputs[i],
                  onChanged: onChanged,
                )),
          ],
        ),
      ),
    );
  }
}

class _SetRow extends StatelessWidget {
  final int setNum;
  final _SetInput input;
  final VoidCallback onChanged;

  const _SetRow(
      {required this.setNum,
      required this.input,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
              width: 36,
              child: Text('Set $setNum',
                  style: const TextStyle(fontSize: 12))),
          const SizedBox(width: 8),
          // 重量
          _NumField(
            value: input.weight,
            suffix: 'kg',
            onChanged: (v) {
              input.weight = v;
              onChanged();
            },
          ),
          const SizedBox(width: 8),
          const Text('×'),
          const SizedBox(width: 8),
          // 回数
          _NumField(
            value: input.reps.toDouble(),
            suffix: 'rep',
            isInt: true,
            onChanged: (v) {
              input.reps = v.round();
              onChanged();
            },
          ),
          const SizedBox(width: 8),
          Text(
            '= ${(input.weight * input.reps).toStringAsFixed(0)}kg',
            style: const TextStyle(fontSize: 11, color: Colors.white54),
          ),
        ],
      ),
    );
  }
}

class _NumField extends StatefulWidget {
  final double value;
  final String suffix;
  final bool isInt;
  final ValueChanged<double> onChanged;

  const _NumField({
    required this.value,
    required this.suffix,
    required this.onChanged,
    this.isInt = false,
  });

  @override
  State<_NumField> createState() => _NumFieldState();
}

class _NumFieldState extends State<_NumField> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
        text: widget.isInt
            ? widget.value.round().toString()
            : widget.value.toStringAsFixed(1));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      child: TextFormField(
        controller: _ctrl,
        keyboardType:
            const TextInputType.numberWithOptions(decimal: true),
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          suffixText: widget.suffix,
          suffixStyle:
              const TextStyle(fontSize: 10, color: Colors.white54),
          isDense: true,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        ),
        onChanged: (s) {
          final v = double.tryParse(s);
          if (v != null) widget.onChanged(v);
        },
      ),
    );
  }
}

class _SimpleTotalCard extends StatelessWidget {
  final double totalKg;
  const _SimpleTotalCard({required this.totalKg});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text('総挙上重量',
                style: TextStyle(fontSize: 14, color: Colors.white54)),
            Text('${totalKg.toStringAsFixed(0)} kg',
                style: const TextStyle(
                    fontSize: 48, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}
