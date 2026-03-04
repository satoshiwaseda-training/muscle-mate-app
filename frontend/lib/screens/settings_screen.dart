// 設定画面: レベル・BIG3 MAX・使用器具を保存
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart' show AppColors;
import '../models/workout_plan.dart';
import '../services/local_storage_service.dart';
import 'privacy_policy_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Level _level = Level.intermediate;
  final _benchCtrl    = TextEditingController();
  final _squatCtrl    = TextEditingController();
  final _deadliftCtrl = TextEditingController();
  Set<Equipment> _equipment = {
    Equipment.barbell,
    Equipment.dumbbell,
    Equipment.machine,
    Equipment.bodyweight,
    Equipment.cable,
  };
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _benchCtrl.dispose();
    _squatCtrl.dispose();
    _deadliftCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final s = await LocalStorageService.loadSettings();
    setState(() {
      _level = Level.fromValue(s['level'] as String? ?? 'intermediate');
      _benchCtrl.text    = (s['bench_press_max'] as num?)?.toString() ?? '';
      _squatCtrl.text    = (s['squat_max']       as num?)?.toString() ?? '';
      _deadliftCtrl.text = (s['deadlift_max']    as num?)?.toString() ?? '';
      final eqList = (s['equipment'] as List<dynamic>?) ?? ['barbell', 'dumbbell', 'machine', 'bodyweight', 'cable'];
      _equipment = eqList
          .map((e) => Equipment.fromValue(e as String))
          .toSet();
      _loading = false;
    });
  }

  Future<void> _confirmDeleteAll(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('データを削除しますか？',
            style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
          'トレーニング記録・設定・同意履歴など、本アプリが保存したすべてのデータを完全に削除します。\nこの操作は取り消せません。',
          style: TextStyle(color: AppColors.textSecond),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル',
                style: TextStyle(color: AppColors.textSecond)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
                backgroundColor: Colors.redAccent),
            child: const Text('削除する'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('すべてのデータを削除しました'),
        backgroundColor: Colors.redAccent,
      ),
    );
    Navigator.pop(context);
  }

  Future<void> _save() async {
    if (_equipment.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('器具を1つ以上選択してください')),
      );
      return;
    }
    final settings = {
      'level': _level.value,
      'bench_press_max': double.tryParse(_benchCtrl.text.trim()),
      'squat_max':       double.tryParse(_squatCtrl.text.trim()),
      'deadlift_max':    double.tryParse(_deadliftCtrl.text.trim()),
      'equipment': _equipment.map((e) => e.value).toList(),
    };
    await LocalStorageService.saveSettings(settings);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('設定を保存しました'),
        backgroundColor: AppColors.primary,
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('設定')),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── トレーニングレベル ─────────────────────────────────────
                _Section(
                  title: 'トレーニングレベル',
                  icon: Icons.bar_chart,
                  child: Wrap(
                    spacing: 8,
                    children: Level.values.map((l) => ChoiceChip(
                          label: Text(l.label),
                          selected: _level == l,
                          selectedColor: AppColors.primary.withValues(alpha: 0.3),
                          onSelected: (_) => setState(() => _level = l),
                        )).toList(),
                  ),
                ),
                const SizedBox(height: 16),

                // ── BIG3 MAX重量 ────────────────────────────────────────────
                _Section(
                  title: 'BIG3 MAX重量（任意）',
                  icon: Icons.fitness_center,
                  subtitle: '入力するとメニューの重量がパーソナライズされます',
                  child: Column(
                    children: [
                      _Big3Field(
                        controller: _benchCtrl,
                        label: 'ベンチプレス MAX',
                        icon: Icons.airline_seat_flat,
                      ),
                      const SizedBox(height: 10),
                      _Big3Field(
                        controller: _squatCtrl,
                        label: 'スクワット MAX',
                        icon: Icons.accessibility_new,
                      ),
                      const SizedBox(height: 10),
                      _Big3Field(
                        controller: _deadliftCtrl,
                        label: 'デッドリフト MAX',
                        icon: Icons.fitness_center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── 使用可能な器具 ──────────────────────────────────────────
                _Section(
                  title: '使用可能な器具',
                  icon: Icons.sports_gymnastics,
                  subtitle: '使えない場合はオフにしてください',
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: Equipment.values.map((e) {
                      final on = _equipment.contains(e);
                      return FilterChip(
                        label: Text(e.label),
                        selected: on,
                        selectedColor: AppColors.primary.withValues(alpha: 0.3),
                        checkmarkColor: AppColors.primaryDim,
                        onSelected: (v) => setState(() {
                          if (v) {
                            _equipment.add(e);
                          } else {
                            _equipment.remove(e);
                          }
                        }),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 32),

                // ── 保存ボタン ─────────────────────────────────────────────
                FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save),
                  label: const Text('設定を保存する'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 24),

                // ── プライバシー ────────────────────────────────────────────
                _Section(
                  title: 'プライバシーと法規遵守',
                  icon: Icons.privacy_tip_outlined,
                  child: Column(
                    children: [
                      _LinkRow(
                        icon: Icons.article_outlined,
                        label: 'プライバシーポリシー',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const PrivacyPolicyScreen()),
                        ),
                      ),
                      const Divider(height: 1, color: Color(0xFF2A2040)),
                      _LinkRow(
                        icon: Icons.delete_forever_outlined,
                        label: 'アカウントデータを削除',
                        color: Colors.redAccent,
                        onTap: () => _confirmDeleteAll(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
    );
  }
}

// ── 部品 ──────────────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final String? subtitle;
  final Widget child;

  const _Section({
    required this.title,
    required this.icon,
    required this.child,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2040)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primaryDim, size: 18),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!,
                style: const TextStyle(
                    color: AppColors.textSecond, fontSize: 11)),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  const _LinkRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = AppColors.primaryDim,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      color: color,
                      fontSize: 14,
                      fontWeight: FontWeight.w500)),
            ),
            Icon(Icons.chevron_right, color: color.withValues(alpha: 0.5), size: 16),
          ],
        ),
      ),
    );
  }
}

class _Big3Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;

  const _Big3Field({
    required this.controller,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textSecond),
        suffixText: 'kg',
        suffixStyle: const TextStyle(color: AppColors.textSecond),
        prefixIcon: Icon(icon, size: 20, color: AppColors.textSecond),
        enabledBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Color(0xFF3A3060)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        filled: true,
        fillColor: AppColors.surfaceHigh,
      ),
    );
  }
}
