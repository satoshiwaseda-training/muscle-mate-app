/// ホーム画面：ユーザー情報入力 → ワークアウトプラン生成
/// BIG3 MAXを入力すると個人のMAX重量に基づいた重量がメニューに反映される
import 'package:flutter/material.dart';
import '../models/workout_plan.dart';
import '../services/api_service.dart';
import 'workout_plan_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // ── 基本設定 ─────────────────────────────────────────────────────────────
  Goal _selectedGoal = Goal.muscleGain;
  Level _selectedLevel = Level.beginner;
  int _daysPerWeek = 3;
  final Set<Equipment> _selectedEquipment = {Equipment.bodyweight};
  bool _isLoading = false;

  // ── BIG3 MAX 入力コントローラー ──────────────────────────────────────────
  // State内で保持（将来: SharedPreferences に移行予定）
  final _benchCtrl = TextEditingController();
  final _squatCtrl = TextEditingController();
  final _deadliftCtrl = TextEditingController();

  @override
  void dispose() {
    _benchCtrl.dispose();
    _squatCtrl.dispose();
    _deadliftCtrl.dispose();
    super.dispose();
  }

  // 文字列 → double? に安全変換
  double? _parseKg(TextEditingController ctrl) {
    final txt = ctrl.text.trim();
    if (txt.isEmpty) return null;
    return double.tryParse(txt);
  }

  Future<void> _generatePlan() async {
    if (_selectedEquipment.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('器具を1つ以上選択してください')),
      );
      return;
    }

    // BIG3 MAXを読み取り（未入力はnull → APIでnullとして送信）
    final bench = _parseKg(_benchCtrl);
    final squat = _parseKg(_squatCtrl);
    final deadlift = _parseKg(_deadliftCtrl);

    final big3 = (bench != null || squat != null || deadlift != null)
        ? Big3Max(
            benchPressMax: bench,
            squatMax: squat,
            deadliftMax: deadlift,
          )
        : null;

    setState(() => _isLoading = true);

    final request = WorkoutRequest(
      goal: _selectedGoal,
      level: _selectedLevel,
      daysPerWeek: _daysPerWeek,
      equipment: _selectedEquipment.toList(),
      big3Max: big3,
    );

    final response = await ApiService.generateWorkoutPlan(request);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (response.success && response.plan != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => WorkoutPlanScreen(plan: response.plan!),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response.errorMessage ?? 'エラーが発生しました')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Muscle Mate'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── 目標 ──────────────────────────────────────────────────────
            _SectionTitle('トレーニング目標'),
            Wrap(
              spacing: 8,
              children: Goal.values.map((g) {
                return ChoiceChip(
                  label: Text(g.label),
                  selected: _selectedGoal == g,
                  onSelected: (_) => setState(() => _selectedGoal = g),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // ── レベル ────────────────────────────────────────────────────
            _SectionTitle('現在のレベル'),
            Wrap(
              spacing: 8,
              children: Level.values.map((l) {
                return ChoiceChip(
                  label: Text(l.label),
                  selected: _selectedLevel == l,
                  onSelected: (_) => setState(() => _selectedLevel = l),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // ── 週の日数 ──────────────────────────────────────────────────
            _SectionTitle('週のトレーニング日数: $_daysPerWeek 日'),
            Slider(
              value: _daysPerWeek.toDouble(),
              min: 1,
              max: 7,
              divisions: 6,
              label: '$_daysPerWeek日',
              onChanged: (v) => setState(() => _daysPerWeek = v.round()),
            ),
            const SizedBox(height: 16),

            // ── 器具 ──────────────────────────────────────────────────────
            _SectionTitle('使用可能な器具（複数選択）'),
            Wrap(
              spacing: 8,
              children: Equipment.values.map((e) {
                final selected = _selectedEquipment.contains(e);
                return FilterChip(
                  label: Text(e.label),
                  selected: selected,
                  onSelected: (v) {
                    setState(() {
                      if (v) {
                        _selectedEquipment.add(e);
                      } else {
                        _selectedEquipment.remove(e);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // ── BIG3 MAX 入力 ──────────────────────────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.bar_chart, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'BIG3 MAX重量（任意）',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '入力すると最適なトレーニング重量がメニューに反映されます',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 16),
                    _Big3TextField(
                      controller: _benchCtrl,
                      label: 'ベンチプレス MAX',
                      icon: Icons.airline_seat_flat,
                    ),
                    const SizedBox(height: 12),
                    _Big3TextField(
                      controller: _squatCtrl,
                      label: 'スクワット MAX',
                      icon: Icons.accessibility_new,
                    ),
                    const SizedBox(height: 12),
                    _Big3TextField(
                      controller: _deadliftCtrl,
                      label: 'デッドリフト MAX',
                      icon: Icons.fitness_center,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── 生成ボタン ────────────────────────────────────────────────
            FilledButton.icon(
              onPressed: _isLoading ? null : _generatePlan,
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.fitness_center),
              label: Text(_isLoading ? 'AIが生成中...' : 'メニューを生成する'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── ウィジェット部品 ──────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _Big3TextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;

  const _Big3TextField({
    required this.controller,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        suffixText: 'kg',
        prefixIcon: Icon(icon, size: 20),
        border: const OutlineInputBorder(),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }
}
