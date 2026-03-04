import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/calendar_home_screen.dart';
import 'screens/consent_screen.dart';
import 'screens/plan_generator_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ja');
  final prefs = await SharedPreferences.getInstance();
  final consented = prefs.getBool('consent_given') ?? false;
  runApp(MuscleMateApp(showConsent: !consented));
}

// ── Anytime Fitness インスパイアカラーパレット ────────────────────────────────
class AppColors {
  static const background  = Color(0xFF110E1E); // ディープパープルブラック
  static const surface     = Color(0xFF1D1831); // ダークパープル
  static const surfaceHigh = Color(0xFF272040); // パープル
  static const primary     = Color(0xFF6D28D9); // Anytimeバイオレット
  static const primaryDim  = Color(0xFF8B5CF6); // ライトパープル
  static const secondary   = Color(0xFFEC4899); // ピンク/マゼンタ
  static const fire        = Color(0xFFFF1744); // ヒートマップ最大値
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecond  = Color(0xFF9C8EC4); // ミューテッドパープル
  static const marker      = Color(0xFF6D28D9); // カレンダーマーカー
  static const beast       = Color(0xFFFF1744);
  static const hero        = Color(0xFFFFD600);
  static const warrior     = Color(0xFF69F0AE);
}

class MuscleMateApp extends StatelessWidget {
  final bool showConsent;
  const MuscleMateApp({super.key, this.showConsent = false});

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
        ),
        cardTheme: CardThemeData(
          color: AppColors.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF2A2A2A)),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.background,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: AppColors.surfaceHigh,
          selectedColor: AppColors.primary.withValues(alpha: 0.3),
          side: const BorderSide(color: Color(0xFF3A3A3A)),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        textTheme: const TextTheme(
          titleLarge:
              TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
          titleMedium:
              TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
          bodyMedium: TextStyle(color: AppColors.textSecond),
          bodySmall: TextStyle(color: AppColors.textSecond, fontSize: 12),
        ),
        useMaterial3: true,
      ),
      home: showConsent ? const _ConsentGate() : const _RootNav(),
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
    if (_consented) return const _RootNav();
    return ConsentScreen(
      onConsented: () => setState(() => _consented = true),
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
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.primary.withValues(alpha: 0.2),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month, color: AppColors.primary),
            label: 'ホーム',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_outlined),
            selectedIcon:
                Icon(Icons.auto_awesome, color: AppColors.primary),
            label: 'AIメニュー生成',
          ),
        ],
      ),
    );
  }
}
