// AIメニュー生成画面
// 設定（Level・BIG3・器具）を自動ロードし、今日のターゲット筋群を選択してプランを生成
import 'package:flutter/material.dart';
import '../main.dart' show AppColors;
import '../models/workout_plan.dart';
import '../services/api_service.dart';
import '../services/local_storage_service.dart';
import 'workout_plan_screen.dart';

// ── 筋群マスター ──────────────────────────────────────────────────────────────
const _muscles = [
  ('chest',       '胸',      Icons.crop_square),
  ('back',        '背中',    Icons.airline_seat_recline_normal),
  ('shoulders',   '肩',      Icons.sports_gymnastics),
  ('biceps',      '二頭筋',  Icons.fitness_center),
  ('triceps',     '三頭筋',  Icons.fitness_center),
  ('quads',       '大腿四頭', Icons.directions_run),
  ('hamstrings',  'ハムスト', Icons.directions_run),
  ('glutes',      '臀部',    Icons.accessibility_new),
  ('core',        '体幹',    Icons.radio_button_checked),
  ('calves',      'ふくらはぎ', Icons.directions_walk),
];

class PlanGeneratorScreen extends StatefulWidget {
  final bool startNow;
  const PlanGeneratorScreen({super.key, this.startNow = false});

  @override
  State<PlanGeneratorScreen> createState() => _PlanGeneratorScreenState();
}

class _PlanGeneratorScreenState extends State<PlanGeneratorScreen> {
  Goal _selectedGoal = Goal.muscleGain;
  final Set<String> _selectedMuscles = {};
  int _daysPerWeek = 3;             // デフォルト週3日
  int _sessionDurationMinutes = 60; // デフォルト60分

  // 設定から読み込まれる値
  Level _level = Level.intermediate;
  List<Equipment> _equipment = [
    Equipment.barbell, Equipment.dumbbell,
    Equipment.machine, Equipment.bodyweight, Equipment.cable,
  ];
  Big3Max? _big3Max;

  bool _loading = true;
  bool _generating = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final s = await LocalStorageService.loadSettings();
    final bench    = (s['bench_press_max'] as num?)?.toDouble();
    final squat    = (s['squat_max']       as num?)?.toDouble();
    final deadlift = (s['deadlift_max']    as num?)?.toDouble();
    final eqList = (s['equipment'] as List<dynamic>?) ??
        ['barbell', 'dumbbell', 'machine', 'bodyweight', 'cable'];

    setState(() {
      _level = Level.fromValue(s['level'] as String? ?? 'intermediate');
      _equipment = eqList
          .map((e) => Equipment.fromValue(e as String))
          .toList();
      _big3Max = (bench != null || squat != null || deadlift != null)
          ? Big3Max(
              benchPressMax: bench,
              squatMax: squat,
              deadliftMax: deadlift,
            )
          : null;
      _loading = false;
    });
  }

  Future<void> _generatePlan() async {
    if (_equipment.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('設定で器具を1つ以上選択してください')),
      );
      return;
    }

    setState(() => _generating = true);

    final request = WorkoutRequest(
      goal: _selectedGoal,
      level: _level,
      daysPerWeek: _daysPerWeek,
      sessionDurationMinutes: _sessionDurationMinutes,
      equipment: _equipment,
      targetMuscles: _selectedMuscles.toList(),
      big3Max: _big3Max,
    );

    final response = await ApiService.generateWorkoutPlan(request);

    if (!mounted) return;
    setState(() => _generating = false);

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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.startNow ? '今日のメニューを生成' : 'AIメニュー生成'),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // startNow バナー
                if (widget.startNow) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary.withValues(alpha: 0.2),
                          AppColors.secondary.withValues(alpha: 0.08),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.5)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.bolt, color: AppColors.primary),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '今日のトレーニングを開始！\n部位を選んでメニューを生成してください。',
                            style: TextStyle(
                                color: AppColors.textPrimary, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // ── 目標 ────────────────────────────────────────────────────
                const _SectionLabel('トレーニング目標'),
                Wrap(
                  spacing: 8,
                  children: Goal.values.map((g) => ChoiceChip(
                        label: Text(g.label),
                        selected: _selectedGoal == g,
                        selectedColor:
                            AppColors.primary.withValues(alpha: 0.3),
                        onSelected: (_) =>
                            setState(() => _selectedGoal = g),
                      )).toList(),
                ),
                const SizedBox(height: 20),

                // ── 週間トレーニング日数 ────────────────────────────────────
                const _SectionLabel('週間トレーニング日数'),
                const Text(
                  '週に何日トレーニングするか選択してください',
                  style: TextStyle(color: AppColors.textSecond, fontSize: 11),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [1, 2, 3, 4, 5, 6, 7].map((d) {
                    final selected = _daysPerWeek == d;
                    return GestureDetector(
                      onTap: () => setState(() => _daysPerWeek = d),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.primary.withValues(alpha: 0.25)
                              : AppColors.surfaceHigh,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected
                                ? AppColors.primary
                                : const Color(0xFF3A3060),
                            width: selected ? 1.5 : 1.0,
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              '$d',
                              style: TextStyle(
                                color: selected
                                    ? AppColors.textPrimary
                                    : AppColors.textSecond,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              '日',
                              style: TextStyle(
                                color: selected
                                    ? AppColors.primaryDim
                                    : AppColors.textSecond,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                // ── トレーニング時間 ────────────────────────────────────────
                const _SectionLabel('今日のトレーニング時間'),
                const Text(
                  '休憩時間を含む合計時間（文献ベースの最適インターバルを自動適用）',
                  style: TextStyle(color: AppColors.textSecond, fontSize: 11),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [30, 45, 60, 75, 90, 120].map((min) {
                    final selected = _sessionDurationMinutes == min;
                    return GestureDetector(
                      onTap: () =>
                          setState(() => _sessionDurationMinutes = min),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.primary.withValues(alpha: 0.25)
                              : AppColors.surfaceHigh,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected
                                ? AppColors.primary
                                : const Color(0xFF3A3060),
                            width: selected ? 1.5 : 1.0,
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              '$min',
                              style: TextStyle(
                                color: selected
                                    ? AppColors.textPrimary
                                    : AppColors.textSecond,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              '分',
                              style: TextStyle(
                                color: selected
                                    ? AppColors.primaryDim
                                    : AppColors.textSecond,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                // ── 今日のターゲット筋群 ────────────────────────────────────
                Row(
                  children: [
                    const _SectionLabel('今日のターゲット筋群'),
                    const Spacer(),
                    if (_selectedMuscles.isNotEmpty)
                      TextButton(
                        onPressed: () =>
                            setState(() => _selectedMuscles.clear()),
                        child: const Text('クリア',
                            style: TextStyle(
                                color: AppColors.textSecond, fontSize: 12)),
                      ),
                  ],
                ),
                const Text(
                  '※ 未選択の場合は全身メニューを生成します',
                  style: TextStyle(color: AppColors.textSecond, fontSize: 11),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: _muscles.map((m) {
                    final (key, label, icon) = m;
                    final selected = _selectedMuscles.contains(key);
                    return GestureDetector(
                      onTap: () => setState(() {
                        if (selected) {
                          _selectedMuscles.remove(key);
                        } else {
                          _selectedMuscles.add(key);
                        }
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.primary.withValues(alpha: 0.25)
                              : AppColors.surfaceHigh,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected
                                ? AppColors.primary
                                : const Color(0xFF3A3060),
                            width: selected ? 1.5 : 1.0,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(icon,
                                size: 14,
                                color: selected
                                    ? AppColors.primaryDim
                                    : AppColors.textSecond),
                            const SizedBox(width: 6),
                            Text(
                              label,
                              style: TextStyle(
                                color: selected
                                    ? AppColors.textPrimary
                                    : AppColors.textSecond,
                                fontSize: 13,
                                fontWeight: selected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                // ── 設定サマリー（読取専用） ─────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF2A2040)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.settings, size: 14,
                              color: AppColors.textSecond),
                          SizedBox(width: 6),
                          Text('現在の設定',
                              style: TextStyle(
                                  color: AppColors.textSecond,
                                  fontSize: 12,
                                  letterSpacing: 0.5)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _SettingRow('レベル', _level.label),
                      _SettingRow(
                        'BIG3 MAX',
                        _big3Max != null && _big3Max!.hasAny
                            ? [
                                if (_big3Max!.benchPressMax != null)
                                  'ベンチ ${_big3Max!.benchPressMax!.toStringAsFixed(0)}kg',
                                if (_big3Max!.squatMax != null)
                                  'スクワット ${_big3Max!.squatMax!.toStringAsFixed(0)}kg',
                                if (_big3Max!.deadliftMax != null)
                                  'デッド ${_big3Max!.deadliftMax!.toStringAsFixed(0)}kg',
                              ].join(' / ')
                            : '未設定',
                      ),
                      _SettingRow(
                        '器具',
                        _equipment.map((e) => e.label).join('・'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // ── 生成ボタン ───────────────────────────────────────────────
                FilledButton.icon(
                  onPressed: _generating ? null : _generatePlan,
                  icon: _generating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.auto_awesome),
                  label: Text(
                    _generating ? 'AIが生成中...' : 'メニューを生成する',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }
}

// ── 部品 ──────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 14),
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  final String label;
  final String value;
  const _SettingRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(label,
                style: const TextStyle(
                    color: AppColors.textSecond, fontSize: 12)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    color: AppColors.textPrimary, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
