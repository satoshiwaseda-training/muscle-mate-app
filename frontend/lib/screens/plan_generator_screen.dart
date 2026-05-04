// メニュー提案画面（v1.0: ルールベース・AI 表記なし）
// 設定（Level・BIG3・器具）を自動ロードし、今日のターゲット筋群を選択してプランを生成
import 'package:flutter/material.dart';
import '../main.dart' show AppColors;
import '../models/workout_plan.dart';
import '../services/api_service.dart';
import '../services/local_storage_service.dart';
import '../widgets/advisory_modal.dart';
import 'workout_plan_screen.dart';

// シマー風ローディングプレースホルダー
class _ShimmerBox extends StatefulWidget {
  final double width;
  final double height;
  const _ShimmerBox({required this.width, required this.height});
  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Color.lerp(
            AppColors.surface,
            AppColors.surfaceHigh,
            _anim.value,
          ),
        ),
      ),
    );
  }
}

// ── 筋群マスター ──────────────────────────────────────────────────────────────
const _muscles = [
  ('chest', '胸', Icons.crop_square),
  ('back', '背中', Icons.airline_seat_recline_normal),
  ('shoulders', '肩', Icons.sports_gymnastics),
  ('biceps', '二頭筋', Icons.fitness_center),
  ('triceps', '三頭筋', Icons.fitness_center),
  ('quads', '大腿四頭', Icons.directions_run),
  ('hamstrings', 'ハムスト', Icons.directions_run),
  ('glutes', '臀部', Icons.accessibility_new),
  ('core', '体幹', Icons.radio_button_checked),
  ('calves', 'ふくらはぎ', Icons.directions_walk),
];

class PlanGeneratorScreen extends StatefulWidget {
  final bool startNow;
  const PlanGeneratorScreen({super.key, this.startNow = false});

  @override
  State<PlanGeneratorScreen> createState() => _PlanGeneratorScreenState();
}

class _PlanGeneratorScreenState extends State<PlanGeneratorScreen> {
  Goal _selectedGoal = Goal.general;
  final Set<String> _selectedMuscles = {};
  final int _daysPerWeek = 3; // デフォルト週3日
  int _sessionDurationMinutes = 30;
  final Set<String> _comfortFlags = {'light'};

  // 設定から読み込まれる値
  Level _level = Level.intermediate;
  List<Equipment> _equipment = [
    Equipment.barbell,
    Equipment.dumbbell,
    Equipment.machine,
    Equipment.bodyweight,
    Equipment.cable,
  ];
  Big3Max? _big3Max;

  bool _loading = true;
  bool _generating = false;
  bool _checkingHealth = false;
  bool _serverReachable = false;
  String? _serverStatusMessage;

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    await _loadSettings();
    await _refreshHealth(showFeedback: false);
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _loadSettings() async {
    final s = await LocalStorageService.loadSettings();
    final bench = (s['bench_press_max'] as num?)?.toDouble();
    final squat = (s['squat_max'] as num?)?.toDouble();
    final deadlift = (s['deadlift_max'] as num?)?.toDouble();
    final eqList = (s['equipment'] as List<dynamic>?) ??
        ['barbell', 'dumbbell', 'machine', 'bodyweight', 'cable'];

    if (!mounted) return;
    setState(() {
      _level = Level.fromValue(s['level'] as String? ?? 'intermediate');
      _selectedGoal = Goal.general;
      _sessionDurationMinutes = 30;
      _comfortFlags
        ..clear()
        ..add('light');
      _equipment = eqList.map((e) => Equipment.fromValue(e as String)).toList();
      _big3Max = (bench != null || squat != null || deadlift != null)
          ? Big3Max(
              benchPressMax: bench,
              squatMax: squat,
              deadliftMax: deadlift,
            )
          : null;
    });
  }

  Future<bool> _refreshHealth({bool showFeedback = true}) async {
    if (mounted) {
      setState(() => _checkingHealth = true);
    }

    final reachable = await ApiService.checkHealth();
    final statusMessage = reachable
        ? null
        : 'バックエンドに接続できません。'
            ' API_BASE_URL=${ApiService.baseUrl} を確認して再接続してください。';

    if (!mounted) return reachable;

    setState(() {
      _checkingHealth = false;
      _serverReachable = reachable;
      _serverStatusMessage = statusMessage;
    });

    if (showFeedback) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            reachable ? 'バックエンドに接続しました。' : 'バックエンドに接続できませんでした。',
          ),
        ),
      );
    }

    return reachable;
  }

  Future<void> _generatePlan() async {
    if (_equipment.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('設定で器具を1つ以上選択してください')),
      );
      return;
    }

    final healthy = await _refreshHealth(showFeedback: false);
    if (!mounted) return;
    if (!healthy) {
      _showBackendUnavailableDialog(context);
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
      notes: _comfortNotes(),
      big3Max: _big3Max,
    );

    final response = await ApiService.generateWorkoutPlan(request);

    if (!mounted) return;
    setState(() => _generating = false);

    if (response.success) {
      // v5 §6.4: rest_or_consult ならメニュー表示せず医療モーダルへ
      if (response.advisory.isRestOrConsult || response.plan == null) {
        if (!mounted) return;
        await AdvisoryModal.showIfNeeded(context, response.advisory);
        return;
      }
      // partial_skip / deload / none はメニュー表示前に Advisory を案内
      if (!response.advisory.isNone) {
        if (!mounted) return;
        await AdvisoryModal.showIfNeeded(context, response.advisory);
      }
      // キャッシュに保存（オフライン時の再利用のため）
      await LocalStorageService.cachePlan(response.plan!.toJson());
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => WorkoutPlanScreen(plan: response.plan!),
        ),
      );
    } else {
      // オフラインフォールバック: キャッシュされたプランを表示
      final cached = await LocalStorageService.loadCachedPlan();
      if (!mounted) return;
      if (cached != null) {
        _showOfflineDialog(context, cached);
      } else {
        _showErrorDialog(context, response.errorMessage ?? 'エラーが発生しました');
      }
    }
  }

  String _comfortNotes() {
    if (_comfortFlags.isEmpty) {
      return '幅広い年齢・経験のユーザーが無理なく続けられるよう、フォーム説明と負荷調整の余地を含めてください。';
    }
    final notes = <String>[
      '幅広い年齢・経験のユーザーが無理なく続けられるよう、フォーム説明と負荷調整の余地を含めてください。',
    ];
    if (_comfortFlags.contains('light')) {
      notes.add('今日は軽めに始めたい。強度は控えめにし、余力を残す構成にしてください。');
    }
    if (_comfortFlags.contains('tired')) {
      notes.add('疲れがあるため、セット数・休憩・種目難度を安全寄りにしてください。');
    }
    if (_comfortFlags.contains('pain')) {
      notes.add('痛みや不安がある場合は中止を促し、痛む部位を避ける代替と医療専門家への相談を案内してください。');
    }
    return notes.join('\n');
  }

  void _showOfflineDialog(BuildContext context, Map<String, dynamic> cached) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Row(
          children: [
            Icon(Icons.wifi_off, color: AppColors.secondary, size: 20),
            SizedBox(width: 8),
            Text('オフラインモード',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 16)),
          ],
        ),
        content: const Text(
          'サーバーへの接続に失敗しました。\n前回作成したトレーニング案を表示します。',
          style: TextStyle(color: AppColors.textSecond),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル',
                style: TextStyle(color: AppColors.textSecond)),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => WorkoutPlanScreen(
                    plan: WorkoutPlan.fromJson(cached),
                    isOffline: true,
                  ),
                ),
              );
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('キャッシュを表示'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
            SizedBox(width: 8),
            Text('エラー',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 16)),
          ],
        ),
        content:
            Text(message, style: const TextStyle(color: AppColors.textSecond)),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  void _showBackendUnavailableDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Row(
          children: [
            Icon(Icons.cloud_off, color: Colors.orangeAccent, size: 20),
            SizedBox(width: 8),
            Text(
              'サーバー未接続',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 16),
            ),
          ],
        ),
        content: Text(
          _serverStatusMessage ??
              'バックエンドに接続できません。start_dev.ps1 または backend の起動状態を確認してください。',
          style: const TextStyle(color: AppColors.textSecond),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              '閉じる',
              style: TextStyle(color: AppColors.textSecond),
            ),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await _refreshHealth();
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('再接続'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text(
          '今日のメニュー作成',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
        backgroundColor: AppColors.background,
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.help_outline),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
              children: [
                if (!_serverReachable) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.orangeAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.orangeAccent.withValues(alpha: 0.45),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.cloud_off,
                              color: Colors.orangeAccent,
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'サーバー未接続',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _serverStatusMessage ??
                              'バックエンドに接続できません。メニュー生成は無効化されています。',
                          style: const TextStyle(
                            color: AppColors.textSecond,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed:
                              _checkingHealth ? null : () => _refreshHealth(),
                          icon: _checkingHealth
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primary,
                                  ),
                                )
                              : const Icon(Icons.refresh),
                          label: Text(
                            _checkingHealth ? '接続確認中...' : '再接続',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const _SectionLabel('目標'),
                Row(
                  children: [
                    Expanded(
                      child: _LargeSelectTile(
                        label: Goal.general.label,
                        icon: Icons.monitor_heart,
                        selected: _selectedGoal == Goal.general,
                        onTap: () => setState(() => _selectedGoal = Goal.general),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _LargeSelectTile(
                        label: Goal.muscleGain.label,
                        icon: Icons.fitness_center,
                        selected: _selectedGoal == Goal.muscleGain,
                        onTap: () =>
                            setState(() => _selectedGoal = Goal.muscleGain),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _LargeSelectTile(
                        label: Goal.weightLoss.label,
                        icon: Icons.self_improvement,
                        selected: _selectedGoal == Goal.weightLoss,
                        onTap: () =>
                            setState(() => _selectedGoal = Goal.weightLoss),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const _SectionLabel('体調・コンディション'),
                Row(
                  children: [
                    Expanded(
                      child: _LargeSelectTile(
                        label: '軽め',
                        icon: Icons.sentiment_satisfied_alt,
                        selected: _comfortFlags.contains('light'),
                        mint: true,
                        onTap: () => _toggleComfortFlag(
                          'light',
                          !_comfortFlags.contains('light'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _LargeSelectTile(
                        label: '疲れあり',
                        icon: Icons.sentiment_neutral,
                        selected: _comfortFlags.contains('tired'),
                        onTap: () => _toggleComfortFlag(
                          'tired',
                          !_comfortFlags.contains('tired'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _LargeSelectTile(
                        label: '痛み・不安',
                        icon: Icons.sentiment_dissatisfied,
                        selected: _comfortFlags.contains('pain'),
                        onTap: () => _toggleComfortFlag(
                          'pain',
                          !_comfortFlags.contains('pain'),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.verified_user_outlined,
                          color: AppColors.secondary),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'あなたの過去の記録や体調をもとに、無理のないメニューを提案します',
                          style: TextStyle(
                            color: AppColors.secondary,
                            fontSize: 14,
                            height: 1.45,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                const _SectionLabel('時間（目安）'),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [15, 30, 45, 60].map((min) {
                    final selected = _sessionDurationMinutes == min;
                    return ChoiceChip(
                      label: Text('$min分'),
                      selected: selected,
                      onSelected: (_) =>
                          setState(() => _sessionDurationMinutes = min),
                      selectedColor: AppColors.primary,
                      backgroundColor: AppColors.surfaceHigh,
                      labelStyle: TextStyle(
                        color: selected
                            ? AppColors.background
                            : AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Row(
                    children: [
                      Expanded(
                        child: Text(
                          'その他の希望（任意）\n特定の部位を重点的に / 器具の制限 など',
                          style: TextStyle(
                            color: AppColors.textSecond,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                      ),
                      Icon(Icons.edit, color: AppColors.textSecond),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed:
                      (_generating || _checkingHealth || !_serverReachable)
                          ? null
                          : _generatePlan,
                  icon: _generating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.auto_fix_high),
                  label: Text(
                    _generating
                        ? '作成中...'
                        : _checkingHealth
                            ? '接続確認中...'
                            : !_serverReachable
                                ? 'サーバー接続待ち'
                                : 'メニューを提案してもらう',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.background,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    textStyle: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w900),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
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
                  style: TextStyle(color: AppColors.textSecond, fontSize: 14),
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
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.settings,
                              size: 14, color: AppColors.textSecond),
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
                        '詳しい重量設定',
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
                const SizedBox(height: 16),

                // ── 通信・プライバシーノート ──────────────────────────────────
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    '入力した条件はトレーニング案の作成にのみ使用されます。個人を特定する情報は送信しません。',
                    style: TextStyle(color: AppColors.textSecond, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 12),

                // ── 生成ボタン ───────────────────────────────────────────────
                FilledButton.icon(
                  onPressed:
                      (_generating || _checkingHealth || !_serverReachable)
                          ? null
                          : _generatePlan,
                  icon: _generating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.fitness_center),
                  label: Text(
                    _generating
                        ? '作成中...'
                        : _checkingHealth
                            ? '接続確認中...'
                            : !_serverReachable
                                ? 'サーバー接続待ち'
                                : 'メニューを提案してもらう',
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

  void _toggleComfortFlag(String value, bool selected) {
    setState(() {
      if (selected) {
        _comfortFlags.add(value);
        if (value == 'pain' || value == 'tired') {
          _sessionDurationMinutes = _sessionDurationMinutes > 45
              ? 45
              : _sessionDurationMinutes;
        }
      } else {
        _comfortFlags.remove(value);
      }
    });
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

class _LargeSelectTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final bool mint;
  final VoidCallback onTap;

  const _LargeSelectTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.mint = false,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = mint ? AppColors.secondary : AppColors.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 110,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? activeColor : AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? activeColor : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: selected ? AppColors.background : AppColors.textPrimary,
              size: 30,
            ),
            const SizedBox(height: 10),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: TextStyle(
                color: selected ? AppColors.background : AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w900,
                height: 1.2,
              ),
            ),
          ],
        ),
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
                style:
                    const TextStyle(color: AppColors.textSecond, fontSize: 12)),
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
