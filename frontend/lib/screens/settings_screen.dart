// 設定画面: レベル・BIG3 MAX・使用器具を保存
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart' show AppColors;
import '../models/workout_plan.dart';
import '../services/local_storage_service.dart';
import 'advice_screen.dart';
import 'privacy_policy_screen.dart';

// 提出計画書 v1.3 §5.1: v1.0 では外部 AI トグル UI を非表示にする。
// SharedPreferences のキー (external_ai_optin) や api_service.dart の
// X-External-AI-Optin ヘッダ送信ロジックは残し、v1.1 で UI を再露出するだけで戻せるようにする。
// ビルド時に --dart-define=ENABLE_EXTERNAL_AI=true を渡したときだけトグル UI が出る。
const bool kEnableExternalAi =
    bool.fromEnvironment('ENABLE_EXTERNAL_AI', defaultValue: false);

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Level _level = Level.intermediate;
  Goal _preferredGoal = Goal.general;
  int _sessionDurationMinutes = 30;
  final Set<String> _comfortFlags = {};
  final _benchCtrl    = TextEditingController();
  final _squatCtrl    = TextEditingController();
  final _deadliftCtrl = TextEditingController();
  final _weightCtrl   = TextEditingController();
  final _ageCtrl      = TextEditingController();
  Set<Equipment> _equipment = {
    Equipment.barbell,
    Equipment.dumbbell,
    Equipment.machine,
    Equipment.bodyweight,
    Equipment.cable,
  };
  bool _externalAiOptin = false;  // v5: 外部 AI 補強の同意状態（既定オフ）
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
    _weightCtrl.dispose();
    _ageCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final s = await LocalStorageService.loadSettings();
    setState(() {
      _level = Level.fromValue(s['level'] as String? ?? 'intermediate');
      _preferredGoal =
          Goal.fromValue(s['preferred_goal'] as String? ?? Goal.general.value);
      _sessionDurationMinutes =
          (s['session_duration_minutes'] as num?)?.toInt() ?? 30;
      _comfortFlags
        ..clear()
        ..addAll((s['comfort_flags'] as List<dynamic>? ?? const [])
            .map((e) => e.toString()));
      _benchCtrl.text    = (s['bench_press_max'] as num?)?.toString() ?? '';
      _squatCtrl.text    = (s['squat_max']       as num?)?.toString() ?? '';
      _deadliftCtrl.text = (s['deadlift_max']    as num?)?.toString() ?? '';
      _weightCtrl.text   = (s['body_weight_kg']  as num?)?.toString() ?? '';
      _ageCtrl.text      = (s['age']             as num?)?.toString() ?? '';
      final eqList = (s['equipment'] as List<dynamic>?) ?? ['barbell', 'dumbbell', 'machine', 'bodyweight', 'cable'];
      _equipment = eqList
          .map((e) => Equipment.fromValue(e as String))
          .toSet();
      _loading = false;
    });
    // 外部 AI 同意状態（SharedPreferences から読み込み）
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _externalAiOptin = prefs.getBool('external_ai_optin') ?? false;
      });
    }
  }

  /// 外部 AI 補強を有効にする際は、内容を再確認するダイアログを出してから有効化する。
  Future<void> _toggleExternalAi(bool enable) async {
    if (enable) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          icon: const Icon(Icons.psychology_outlined,
              color: AppColors.primary, size: 36),
          title: const Text(
            '外部 AI 補強を有効にしますか？',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 18),
          ),
          content: const SingleChildScrollView(
            child: Text(
              '本機能を有効にすると、メニュー生成時に以下の 6 項目のみが Groq, Inc.（米国）の '
              'AI 推論サービスに送信されます：\n\n'
              '• 目標 / レベル / 使用器具\n'
              '• 週頻度 / セッション時間\n'
              '• 生成された種目名一覧\n\n'
              '【送信されない情報】\n'
              '年齢・性別・体重・BIG3 数値・ターゲット筋群・優先種目・トレーニング歴・'
              '怪我履歴・自由記述・実施記録・痛み有無・RPE\n\n'
              '【自動スキップ】\n'
              '怪我・自由記述・部位指定などが入力されたメニュー生成では、'
              '本機能を有効化していても外部 AI への送信は自動的に行われません。\n\n'
              '【撤回】\n'
              '設定画面でいつでもオフにできます。撤回前に既に送信された分の'
              '遡及削除は保証されません。',
              style: TextStyle(
                color: AppColors.textPrimary, fontSize: 13, height: 1.5),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('同意して有効化'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('external_ai_optin', enable);
    if (enable) {
      await prefs.setString(
          'external_ai_optin_date', DateTime.now().toIso8601String());
    }
    if (mounted) {
      setState(() => _externalAiOptin = enable);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(enable
              ? '外部 AI 補強を有効にしました'
              : '外部 AI 補強を無効にしました（以後の送信は停止）'),
          backgroundColor: AppColors.primary,
        ),
      );
    }
  }

  void _showContactDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('お問い合わせ',
            style: TextStyle(color: AppColors.textPrimary)),
        content: const SelectableText(
          'support@musclemate.app\n\nご質問・ご意見はメールにてお送りください。',
          style: TextStyle(color: AppColors.textSecond, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる',
                style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
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
    if (context.mounted && Navigator.canPop(context)) Navigator.pop(context);
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
      'preferred_goal': _preferredGoal.value,
      'session_duration_minutes': _sessionDurationMinutes,
      'comfort_flags': _comfortFlags.toList(),
      'bench_press_max': double.tryParse(_benchCtrl.text.trim()),
      'squat_max':       double.tryParse(_squatCtrl.text.trim()),
      'deadlift_max':    double.tryParse(_deadliftCtrl.text.trim()),
      'body_weight_kg':  double.tryParse(_weightCtrl.text.trim()),
      'age':             int.tryParse(_ageCtrl.text.trim()),
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
    if (context.mounted && Navigator.canPop(context)) Navigator.pop(context);
  }

  void _toggleComfortFlag(String value, bool selected) {
    setState(() {
      if (selected) {
        _comfortFlags.add(value);
      } else {
        _comfortFlags.remove(value);
      }
    });
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
                _Section(
                  title: '目的と続け方',
                  icon: Icons.favorite_outline,
                  subtitle: 'まずは無理なく続けるための基本設定です',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('目的',
                          style: TextStyle(
                              color: AppColors.textSecond, fontSize: 14)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: Goal.values.map((g) => ChoiceChip(
                              label: Text(g.label),
                              selected: _preferredGoal == g,
                              selectedColor:
                                  AppColors.primary.withValues(alpha: 0.3),
                              onSelected: (_) =>
                                  setState(() => _preferredGoal = g),
                            )).toList(),
                      ),
                      const SizedBox(height: 16),
                      const Text('1回に使える時間',
                          style: TextStyle(
                              color: AppColors.textSecond, fontSize: 14)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [15, 30, 45, 60, 75, 90].map((min) {
                          return ChoiceChip(
                            label: Text('$min分'),
                            selected: _sessionDurationMinutes == min,
                            selectedColor:
                                AppColors.primary.withValues(alpha: 0.3),
                            onSelected: (_) => setState(
                                () => _sessionDurationMinutes = min),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      const Text('いつもの配慮',
                          style: TextStyle(
                              color: AppColors.textSecond, fontSize: 14)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _ComfortFilterChip(
                            label: '軽めに始めたい',
                            value: 'light',
                            selected: _comfortFlags.contains('light'),
                            onChanged: _toggleComfortFlag,
                          ),
                          _ComfortFilterChip(
                            label: '疲れやすい',
                            value: 'tired',
                            selected: _comfortFlags.contains('tired'),
                            onChanged: _toggleComfortFlag,
                          ),
                          _ComfortFilterChip(
                            label: '痛み・不安に配慮',
                            value: 'pain',
                            selected: _comfortFlags.contains('pain'),
                            onChanged: _toggleComfortFlag,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── トレーニングレベル ─────────────────────────────────────
                _Section(
                  title: '運動経験',
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
                  title: '詳しい重量設定（任意）',
                  icon: Icons.fitness_center,
                  subtitle: '慣れている方だけ入力してください。未入力でもメニューは作れます',
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

                // ── 体格情報（任意・アドバイスの個別化に使用）─────────────
                _Section(
                  title: '体格情報（任意）',
                  icon: Icons.straighten,
                  subtitle: '入力するとタンパク質量・カフェイン量が個別計算されます',
                  child: Column(
                    children: [
                      _Big3Field(
                        controller: _weightCtrl,
                        label: '体重',
                        icon: Icons.monitor_weight_outlined,
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _ageCtrl,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: AppColors.textPrimary),
                        decoration: const InputDecoration(
                          labelText: '年齢',
                          labelStyle:
                              TextStyle(color: AppColors.textSecond),
                          suffixText: '歳',
                          suffixStyle:
                              TextStyle(color: AppColors.textSecond),
                          prefixIcon: Icon(Icons.cake_outlined,
                              size: 20, color: AppColors.textSecond),
                          enabledBorder: OutlineInputBorder(
                            borderSide:
                                BorderSide(color: Color(0xFF3A3060)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                                color: AppColors.primary, width: 1.5),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                          filled: true,
                          fillColor: AppColors.surfaceHigh,
                        ),
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
                const SizedBox(height: 16),

                // ── 外部 AI 補強トグル（v5・既定オフ）──────────────────────
                // v1.0 提出ビルドでは kEnableExternalAi=false のため UI は表示されない。
                // SharedPreferences のキーと api_service.dart の送信ヘッダは温存。
                if (kEnableExternalAi) ...[
                  _Section(
                    title: '外部 AI 補強（任意・既定オフ）',
                    icon: Icons.psychology_outlined,
                    subtitle: 'コーチングコメントの文章のみ補強します。'
                        '年齢・体重・怪我・記録は送信しません',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            _externalAiOptin
                                ? '有効になっています'
                                : '有効化する',
                            style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 14),
                          ),
                          subtitle: Text(
                            _externalAiOptin
                                ? '送信されるのは目標・レベル・器具・頻度・時間・種目名のみ'
                                : '有効化すると確認ダイアログが表示されます',
                            style: const TextStyle(
                                color: AppColors.textSecond, fontSize: 11),
                          ),
                          value: _externalAiOptin,
                          activeThumbColor: AppColors.primary,
                          onChanged: _toggleExternalAi,
                        ),
                        const SizedBox(height: 4),
                        GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const PrivacyPolicyScreen()),
                          ),
                          child: Text(
                            'プライバシーポリシー §4 を読む →',
                            style: TextStyle(
                              color: AppColors.primaryDim,
                              fontSize: 11,
                              decoration: TextDecoration.underline,
                              decorationColor:
                                  AppColors.primaryDim.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],

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

                // ── アドバイス機能 ─────────────────────────────────────────
                _Section(
                  title: '今日のアドバイス',
                  icon: Icons.lightbulb_outline,
                  subtitle: '体重・目標・レベルから論文ベースの個別アドバイスを表示',
                  child: _LinkRow(
                    icon: Icons.tips_and_updates_outlined,
                    label: 'アドバイスを見る',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AdviceScreen()),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ── プライバシー・法規遵守 ───────────────────────────────────
                _Section(
                  title: 'プライバシーと法規遵守',
                  icon: Icons.privacy_tip_outlined,
                  child: Column(
                    children: [
                      _LinkRow(
                        icon: Icons.description_outlined,
                        label: '利用規約',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const _TermsOfServiceScreen()),
                        ),
                      ),
                      const Divider(height: 1, color: AppColors.border),
                      _LinkRow(
                        icon: Icons.article_outlined,
                        label: 'プライバシーポリシー',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const PrivacyPolicyScreen()),
                        ),
                      ),
                      const Divider(height: 1, color: AppColors.border),
                      _LinkRow(
                        icon: Icons.mail_outline,
                        label: 'お問い合わせ',
                        onTap: () => _showContactDialog(context),
                      ),
                      const Divider(height: 1, color: AppColors.border),
                      _LinkRow(
                        icon: Icons.delete_forever_outlined,
                        label: 'アカウントデータを削除',
                        color: Colors.redAccent,
                        onTap: () => _confirmDeleteAll(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: Text(
                    'バージョン 1.0.0',
                    style: TextStyle(
                      color: AppColors.textSecond.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
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
        border: Border.all(color: AppColors.border),
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

class _ComfortFilterChip extends StatelessWidget {
  final String label;
  final String value;
  final bool selected;
  final void Function(String value, bool selected) onChanged;

  const _ComfortFilterChip({
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
      selectedColor: AppColors.primary.withValues(alpha: 0.3),
      checkmarkColor: AppColors.primaryDim,
      onSelected: (next) => onChanged(value, next),
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

// ── 利用規約画面 ───────────────────────────────────────────────────────────────

class _TermsOfServiceScreen extends StatelessWidget {
  const _TermsOfServiceScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('利用規約')),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: _TermsContent(),
      ),
    );
  }
}

class _TermsContent extends StatelessWidget {
  const _TermsContent();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      color: AppColors.textPrimary,
      fontSize: 13,
      height: 1.7,
    );
    const headStyle = TextStyle(
      color: AppColors.primary,
      fontSize: 14,
      fontWeight: FontWeight.bold,
    );
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('制定日：2026年4月5日', style: TextStyle(color: AppColors.textSecond, fontSize: 12)),
        SizedBox(height: 20),
        Text('第1条（適用）', style: headStyle),
        SizedBox(height: 6),
        Text('本利用規約は、本アプリ「Muscle Mate」の利用に関する条件を定めます。アプリを使用することで、本規約に同意したものとみなします。', style: style),
        SizedBox(height: 16),
        Text('第2条（利用条件）', style: headStyle),
        SizedBox(height: 6),
        Text('本アプリは個人的・非商業的な目的のみに使用できます。', style: style),
        SizedBox(height: 16),
        Text('第3条（禁止事項）', style: headStyle),
        SizedBox(height: 6),
        Text('・本アプリのリバースエンジニアリング・逆コンパイル\n・本アプリを利用した第三者への損害行為\n・本アプリの無断複製・再配布', style: style),
        SizedBox(height: 16),
        Text('第4条（免責事項）', style: headStyle),
        SizedBox(height: 6),
        Text('本アプリはトレーニング記録を支援するツールです。医療・健康に関するアドバイスを提供するものではありません。トレーニング中の怪我・体調不良等について、開発者は責任を負いません。', style: style),
        SizedBox(height: 16),
        Text('第5条（データ・プライバシー）', style: headStyle),
        SizedBox(height: 6),
        Text('トレーニングデータはお使いのデバイス内にのみ保存されます。詳細はプライバシーポリシーをご確認ください。', style: style),
        SizedBox(height: 16),
        Text('第6条（規約の変更）', style: headStyle),
        SizedBox(height: 6),
        Text('本規約は予告なく変更される場合があります。重要な変更はアプリ内でお知らせします。', style: style),
        SizedBox(height: 16),
        Text('第7条（お問い合わせ）', style: headStyle),
        SizedBox(height: 6),
        SelectableText('support@musclemate.app', style: TextStyle(color: AppColors.primaryDim, fontSize: 13)),
        SizedBox(height: 32),
      ],
    );
  }
}
