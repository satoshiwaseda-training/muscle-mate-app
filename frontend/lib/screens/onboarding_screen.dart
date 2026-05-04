import 'package:flutter/material.dart';
import '../main.dart' show AppColors, AppGradientButton;
import '../models/workout_plan.dart';
import '../services/local_storage_service.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onFinished;
  const OnboardingScreen({super.key, required this.onFinished});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  Goal _goal = Goal.general;
  Level _level = Level.beginner;
  int _minutes = 30;
  final Set<String> _comfortFlags = {'light'};
  final Set<Equipment> _equipment = {
    Equipment.bodyweight,
    Equipment.dumbbell,
  };

  Future<void> _finish() async {
    final settings = {
      ...LocalStorageService.defaultSettings(),
      'preferred_goal': _goal.value,
      'level': _level.value,
      'session_duration_minutes': _minutes,
      'comfort_flags': _comfortFlags.toList(),
      'equipment': _equipment.map((e) => e.value).toList(),
    };
    await LocalStorageService.saveSettings(settings);
    await LocalStorageService.markOnboardingComplete();
    if (mounted) widget.onFinished();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
          children: [
            const Text(
              'まずは、今日から続けやすい形に整えましょう',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 26,
                fontWeight: FontWeight.w900,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              '重い設定はあとからで大丈夫です。体力・目的・使える時間に合わせて、無理のないメニューを自動で作成します。',
              style: TextStyle(
                color: AppColors.textSecond,
                fontSize: 15,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 24),
            _Section(
              title: '目的',
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: Goal.values
                    .map(
                      (goal) => ChoiceChip(
                        label: Text(goal.label),
                        selected: _goal == goal,
                        onSelected: (_) => setState(() => _goal = goal),
                      ),
                    )
                    .toList(),
              ),
            ),
            _Section(
              title: '今の運動経験',
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: Level.values
                    .map(
                      (level) => ChoiceChip(
                        label: Text(level.label),
                        selected: _level == level,
                        onSelected: (_) => setState(() => _level = level),
                      ),
                    )
                    .toList(),
              ),
            ),
            _Section(
              title: '1回に使える時間',
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [15, 30, 45, 60]
                    .map(
                      (minutes) => ChoiceChip(
                        label: Text('$minutes分'),
                        selected: _minutes == minutes,
                        onSelected: (_) => setState(() => _minutes = minutes),
                      ),
                    )
                    .toList(),
              ),
            ),
            _Section(
              title: '今日の配慮',
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _FlagChip(
                    label: '軽めに始めたい',
                    value: 'light',
                    selected: _comfortFlags.contains('light'),
                    onChanged: _toggleFlag,
                  ),
                  _FlagChip(
                    label: '疲れがある',
                    value: 'tired',
                    selected: _comfortFlags.contains('tired'),
                    onChanged: _toggleFlag,
                  ),
                  _FlagChip(
                    label: '痛み・不安がある',
                    value: 'pain',
                    selected: _comfortFlags.contains('pain'),
                    onChanged: _toggleFlag,
                  ),
                ],
              ),
            ),
            _Section(
              title: '使える器具',
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: Equipment.values
                    .map(
                      (equipment) => FilterChip(
                        label: Text(equipment.label),
                        selected: _equipment.contains(equipment),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _equipment.add(equipment);
                            } else {
                              _equipment.remove(equipment);
                            }
                            if (_equipment.isEmpty) {
                              _equipment.add(Equipment.bodyweight);
                            }
                          });
                        },
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 12),
            AppGradientButton(
              onPressed: _finish,
              padding: const EdgeInsets.symmetric(vertical: 17),
              child: const Center(
                child: Text(
                  'この内容ではじめる',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleFlag(String value, bool selected) {
    setState(() {
      if (selected) {
        _comfortFlags.add(value);
      } else {
        _comfortFlags.remove(value);
      }
    });
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _FlagChip extends StatelessWidget {
  final String label;
  final String value;
  final bool selected;
  final void Function(String value, bool selected) onChanged;

  const _FlagChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (next) => onChanged(value, next),
    );
  }
}
