// SharedPreferences によるワークアウト履歴と設定の永続化
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/workout_record.dart';

class LocalStorageService {
  static const _key         = 'workout_records';
  static const _settingsKey  = 'user_settings';
  static const _recoveryBoostKey = 'recovery_boost_state';
  static const _plannedSessionKey = 'planned_session_state';
  static const _onboardingCompleteKey = 'onboarding_complete';

  // ── 設定 ────────────────────────────────────────────────────────────────

  static Map<String, dynamic> defaultSettings() => {
        'level': 'beginner',
        'preferred_goal': 'general_fitness',
        'session_duration_minutes': 30,
        'comfort_flags': <String>[],
        'bench_press_max': null,
        'squat_max': null,
        'deadlift_max': null,
        'equipment': ['bodyweight', 'dumbbell', 'machine'],
      };

  static Future<Map<String, dynamic>> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_settingsKey);
    if (raw == null) return defaultSettings();
    final parsed = jsonDecode(raw) as Map<String, dynamic>;
    // デフォルト値で不足フィールドを補完
    final defaults = defaultSettings();
    for (final k in defaults.keys) {
      parsed.putIfAbsent(k, () => defaults[k]);
    }
    return parsed;
  }

  static Future<void> saveSettings(Map<String, dynamic> settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsKey, jsonEncode(settings));
  }

  static Future<bool> isOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onboardingCompleteKey) ?? false;
  }

  static Future<void> markOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingCompleteKey, true);
  }

  static Future<List<WorkoutRecord>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    return raw
        .map((s) => WorkoutRecord.fromJsonString(s))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date)); // 新しい順
  }

  static Future<void> save(WorkoutRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    raw.add(record.toJsonString());
    await prefs.setStringList(_key, raw);
  }

  static Future<void> delete(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    raw.removeWhere((s) {
      final m = jsonDecode(s) as Map<String, dynamic>;
      return m['id'] == id;
    });
    await prefs.setStringList(_key, raw);
  }

  /// その日にトレーニングしたか
  static Future<bool> hasRecordOn(DateTime day) async {
    final all = await loadAll();
    return all.any((r) =>
        r.date.year == day.year &&
        r.date.month == day.month &&
        r.date.day == day.day);
  }

  // ── オフラインキャッシュ（最後に生成したプラン）─────────────────────────────

  static const _cachedPlanKey = 'cached_workout_plan';

  static Future<void> cachePlan(Map<String, dynamic> planJson) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cachedPlanKey, jsonEncode(planJson));
  }

  static Future<Map<String, dynamic>?> loadCachedPlan() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cachedPlanKey);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  static Future<void> saveRecoveryBoost(Map<String, dynamic> boost) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_recoveryBoostKey, jsonEncode(boost));
  }

  static Future<Map<String, dynamic>?> loadRecoveryBoost() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_recoveryBoostKey);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  static Future<void> savePlannedSession(Map<String, dynamic> session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_plannedSessionKey, jsonEncode(session));
  }

  static Future<Map<String, dynamic>?> loadPlannedSession() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_plannedSessionKey);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  static Future<void> clearPlannedSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_plannedSessionKey);
  }
}
