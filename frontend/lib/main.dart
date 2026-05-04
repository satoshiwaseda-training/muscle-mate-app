import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/calendar_home_screen.dart';
import 'screens/consent_screen.dart';
import 'screens/history_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/plan_generator_screen.dart';
import 'screens/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ja');
  final prefs = await SharedPreferences.getInstance();
  final consented = prefs.getBool('consent_given') ?? false;
  final onboarded = prefs.getBool('onboarding_complete') ?? false;
  runApp(MuscleMateApp(showConsent: !consented, showOnboarding: !onboarded));
}

// ── FORGE カラーパレット ─────────────────────────────────────────────────────
// コンセプト: 鍛造スチール × 炎の熱量 × 精密工学
// 紫を完全排除。背景はほぼ黒のニュートラル。
// Primary = Forge Orange（炎・強度・熱量）
// Accent  = Precision Cyan（テック・データ・精密さ）
class AppColors {
  // ── Backgrounds ──────────────────────────────────────────────────────────────
  static const background = Color(0xFF101719); // Mockup dark charcoal
  static const surface = Color(0xFF1B2225);
  static const surfaceHigh = Color(0xFF242B2E);

  // ── Borders ──────────────────────────────────────────────────────────────────
  static const border = Color(0xFF475155); // 区切り線（主張しない）

  // ── Primary Action ────────────────────────────────────────────────────────────
  static const primary = Color(0xFFFF8A3D); // Forge Orange
  static const primaryDim = Color(0xFFFFBE55); // Ember Gold
  static const primaryGradient = LinearGradient(
    colors: [primary, primaryDim],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  // ── Accent ───────────────────────────────────────────────────────────────────
  static const secondary = Color(0xFF8FE7D3); // Mockup mint

  // ── Text ─────────────────────────────────────────────────────────────────────
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecond = Color(0xFFB8C0C2); // white70相当の可読性重視

  // ── Functional ───────────────────────────────────────────────────────────────
  static const fire = primary;
  static const marker = primary;
  static const beast = primaryDim;

  // ── Achievement (成果ランク) ──────────────────────────────────────────────────
  static const hero = Color(0xFFFFD93D); // Gold
  static const warrior = Color(0xFF6BCB77); // Mint Green

  // ── Design Tokens ─────────────────────────────────────────────────────────
  // Corner radius
  static const double radiusS = 10.0; // chip, badge, input
  static const double radiusM = 14.0; // stat card, small card
  static const double radiusL = 16.0; // standard card  ← 統一基準
  static const double radiusXL = 20.0; // hero card, sheet

  // Spacing
  static const double gapS = 8.0;
  static const double gapM = 12.0;
  static const double gapL = 16.0;
  static const double gapXL = 24.0;
}

class AppGradientButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;

  const AppGradientButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    this.borderRadius = const BorderRadius.all(
      Radius.circular(AppColors.radiusL),
    ),
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: enabled ? null : Colors.white.withValues(alpha: 0.08),
        gradient: enabled ? AppColors.primaryGradient : null,
        borderRadius: borderRadius,
        border: Border.all(
          color: Colors.white.withValues(alpha: enabled ? 0.10 : 0.06),
        ),
        boxShadow: enabled
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.22),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: borderRadius,
          child: Padding(
            padding: padding,
            child: DefaultTextStyle.merge(
              style: TextStyle(
                color: enabled
                    ? const Color(0xFF1A1F2C)
                    : Colors.white.withValues(alpha: 0.54),
                fontWeight: FontWeight.w800,
              ),
              child: IconTheme(
                data: IconThemeData(
                  color: enabled
                      ? const Color(0xFF1A1F2C)
                      : Colors.white.withValues(alpha: 0.54),
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MuscleMateApp extends StatelessWidget {
  final bool showConsent;
  final bool showOnboarding;
  const MuscleMateApp({
    super.key,
    this.showConsent = false,
    this.showOnboarding = false,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Muscle Mate',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: const ColorScheme.dark(
          surface: AppColors.surface,
          primary: AppColors.primary,
          secondary: AppColors.secondary,
          onPrimary: Colors.white,
          onSurface: AppColors.textPrimary,
          outline: AppColors.border,
          surfaceContainerHighest: AppColors.surfaceHigh,
        ),
        // ── Card ─────────────────────────────────────────────────────────────
        cardTheme: const CardThemeData(
          color: AppColors.surface,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
            side: BorderSide(color: AppColors.border),
          ),
        ),
        // ── AppBar ───────────────────────────────────────────────────────────
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.background,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        // ── FilledButton ─────────────────────────────────────────────────────
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            textStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        // ── Chip ─────────────────────────────────────────────────────────────
        chipTheme: ChipThemeData(
          backgroundColor: AppColors.surface,
          selectedColor: AppColors.primary.withValues(alpha: 0.18),
          side: const BorderSide(color: AppColors.border),
          labelStyle: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        // ── NavigationBar ────────────────────────────────────────────────────
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: AppColors.surface,
          indicatorColor: AppColors.primary.withValues(alpha: 0.15),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(
                color: AppColors.primary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              );
            }
            return const TextStyle(
              color: AppColors.textSecond,
              fontSize: 12,
            );
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: AppColors.primary, size: 24);
            }
            return const IconThemeData(color: AppColors.textSecond, size: 22);
          }),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
        ),
        // ── Divider ──────────────────────────────────────────────────────────
        dividerTheme: const DividerThemeData(
          color: AppColors.border,
          thickness: 1,
          space: 1,
        ),
        // ── Input ────────────────────────────────────────────────────────────
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.surfaceHigh,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
          labelStyle: const TextStyle(color: AppColors.textSecond),
          hintStyle: const TextStyle(color: AppColors.textSecond),
        ),
        // ── Typography ───────────────────────────────────────────────────────
        textTheme: const TextTheme(
          titleLarge: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
          titleMedium: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
          bodyMedium: TextStyle(color: AppColors.textSecond),
          bodySmall: TextStyle(color: AppColors.textSecond, fontSize: 13),
        ),
        useMaterial3: true,
      ),
      home: showConsent
          ? const _ConsentGate()
          : showOnboarding
              ? const _OnboardingGate()
              : const _RootNav(),
    );
  }
}

// 同意画面 → ルートナビ への橋渡し
class _ConsentGate extends StatefulWidget {
  const _ConsentGate();
  @override
  State<_ConsentGate> createState() => _ConsentGateState();
}

class _ConsentGateState extends State<_ConsentGate> {
  bool _consented = false;

  @override
  Widget build(BuildContext context) {
    if (_consented) return const _OnboardingGate();
    return ConsentScreen(
      onConsented: () => setState(() => _consented = true),
    );
  }
}

class _OnboardingGate extends StatefulWidget {
  const _OnboardingGate();
  @override
  State<_OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends State<_OnboardingGate> {
  bool _finished = false;

  @override
  Widget build(BuildContext context) {
    if (_finished) return const _RootNav();
    return OnboardingScreen(
      onFinished: () => setState(() => _finished = true),
    );
  }
}

class _RootNav extends StatefulWidget {
  const _RootNav();
  @override
  State<_RootNav> createState() => _RootNavState();
}

class _RootNavState extends State<_RootNav> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          CalendarHomeScreen(),
          PlanGeneratorScreen(),
          HistoryScreen(),
          SettingsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.primary.withValues(alpha: 0.2),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: AppColors.primary),
            label: 'ホーム',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_circle_outline),
            selectedIcon: Icon(Icons.add_circle, color: AppColors.primary),
            label: '記録する',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history, color: AppColors.primary),
            label: '履歴',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings, color: AppColors.primary),
            label: '設定',
          ),
        ],
      ),
    );
  }
}
