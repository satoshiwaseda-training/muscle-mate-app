// SharedPreferences によるワークアウト履歴と設定の永続化
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/workout_record.dart';

/// シェア画面用の達成サマリ統計（今日 / 1 週間 / 1 ヶ月の集計）
class ShareSummaryStats {
  final ShareSubStats today;
  final ShareSubStats week;
  final ShareSubStats month;
  final int streak;

  const ShareSummaryStats({
    required this.today,
    required this.week,
    required this.month,
    required this.streak,
  });
}

class ShareSubStats {
  final int sessionCount;          // 期間内のセッション数 (= 日数)
  final int exerciseCount;         // 期間内に実施した種目の総数 (重複あり)
  final double totalVolumeKg;      // 期間内の総ボリューム (重量 × レップ 合計)
  final int totalSets;             // 期間内の総セット数
  final List<String> topExercises; // 期間内に多く実施した種目 TOP3

  const ShareSubStats({
    required this.sessionCount,
    required this.exerciseCount,
    required this.totalVolumeKg,
    required this.totalSets,
    required this.topExercises,
  });

  factory ShareSubStats.fromRecords(List<WorkoutRecord> records) {
    final exCounts = <String, int>{};
    var volumeSum = 0.0;
    var setCount = 0;
    for (final r in records) {
      for (final s in r.sets) {
        exCounts[s.exerciseName] = (exCounts[s.exerciseName] ?? 0) + 1;
        volumeSum += s.volume;
        setCount += 1;
      }
    }
    final sorted = exCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top3 = sorted.take(3).map((e) => e.key).toList();

    final uniqueDays = records
        .map((r) => '${r.date.year}-${r.date.month}-${r.date.day}')
        .toSet();

    return ShareSubStats(
      sessionCount: uniqueDays.length,
      exerciseCount: exCounts.values.fold<int>(0, (a, b) => a + b),
      totalVolumeKg: volumeSum,
      totalSets: setCount,
      topExercises: top3,
    );
  }
}

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

  // ── 履歴サマリ集計（v1.0: 論文ベース最適化用）─────────────────────────
  //
  // 端末内の WorkoutRecord 全件から過去 30 日のサマリを作る。
  // 個別レコードの内容（重量・レップ等）は送信せず、集計値のみをリクエスト
  // ボディに含める（プライバシーポリシー §5 と整合）。

  /// 過去 30 日のトレーニング記録サマリを返す。
  /// バックエンドの RecentHistorySummary スキーマと完全対応する。
  static Future<Map<String, dynamic>> buildRecentHistorySummary({
    DateTime? now,
  }) async {
    final reference = now ?? DateTime.now();
    final all = await loadAll();
    if (all.isEmpty) {
      return {
        'last_session_days_ago': null,
        'sessions_last_7_days': 0,
        'sessions_last_30_days': 0,
        'avg_weekly_volume_kg_30d': 0.0,
        'recent_muscle_focus_7d': <String, int>{},
        'muscles_unworked_14d': <String>[],
        'streak_days': 0,
        'pain_reports_last_7d': <String, int>{},
        'top_exercises_30d': <String>[],
      };
    }

    // 期間内のレコードを抽出
    final last7 = all
        .where((r) => reference.difference(r.date).inDays < 7)
        .toList();
    final last14 = all
        .where((r) => reference.difference(r.date).inDays < 14)
        .toList();
    final last30 = all
        .where((r) => reference.difference(r.date).inDays < 30)
        .toList();

    // 直近セッションからの経過日数
    final mostRecent = all.first; // loadAll は新しい順ソート済み
    final daysAgo = reference.difference(mostRecent.date).inDays;

    // 過去 7 日の筋群フォーカス
    final focus7d = <String, int>{};
    for (final r in last7) {
      for (final m in r.trainedMuscles) {
        focus7d[m] = (focus7d[m] ?? 0) + 1;
      }
    }

    // 14 日間鍛えていない代表 6 筋群を導出
    const _trackedMuscles = [
      'chest', 'back', 'shoulders', 'legs', 'core', 'arms',
    ];
    final muscles14d = last14
        .expand((r) => r.trainedMuscles)
        .toSet();
    final unworked14d = _trackedMuscles
        .where((m) => !muscles14d.contains(m))
        .toList();

    // 週ボリューム平均（過去 30 日 / 4.286 週）
    final totalVolume30d =
        last30.fold<double>(0, (sum, r) => sum + r.totalVolume);
    final avgWeeklyVolume = last30.isEmpty
        ? 0.0
        : (totalVolume30d / 30 * 7);

    // 連続日数
    final streak = _computeStreak(all, reference);

    // 痛み報告（entertainment 内に pain_regions が入る場合に対応）
    final painCounts = <String, int>{};
    for (final r in last7) {
      final ent = r.entertainment;
      if (ent == null) continue;
      final regions = ent['pain_regions'];
      if (regions is List) {
        for (final region in regions) {
          if (region is String) {
            painCounts[region] = (painCounts[region] ?? 0) + 1;
          }
        }
      }
    }

    // 種目頻度上位 10
    final exCounts = <String, int>{};
    for (final r in last30) {
      for (final s in r.sets) {
        exCounts[s.exerciseName] = (exCounts[s.exerciseName] ?? 0) + 1;
      }
    }
    final topExercises = exCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top10 = topExercises.take(10).map((e) => e.key).toList();

    return {
      'last_session_days_ago': daysAgo,
      'sessions_last_7_days': _uniqueDays(last7).length,
      'sessions_last_30_days': _uniqueDays(last30).length,
      'avg_weekly_volume_kg_30d': avgWeeklyVolume,
      'recent_muscle_focus_7d': focus7d,
      'muscles_unworked_14d': unworked14d,
      'streak_days': streak,
      'pain_reports_last_7d': painCounts,
      'top_exercises_30d': top10,
    };
  }

  // ── シェア用サマリ集計（v1.0: SNS 投稿画面で使用）─────────────────────────
  //
  // 今日 / 過去 7 日 / 過去 30 日の達成サマリを 1 構造体にまとめて返す。
  // share_summary_screen.dart の表示ロジックに直接ぶら下げる。

  static Future<ShareSummaryStats> buildShareSummary({DateTime? now}) async {
    final reference = now ?? DateTime.now();
    final all = await loadAll();

    // 今日
    final today = DateTime(reference.year, reference.month, reference.day);
    final todayRecords = all.where((r) {
      final d = DateTime(r.date.year, r.date.month, r.date.day);
      return d == today;
    }).toList();

    // 過去 7 日
    final last7 = all
        .where((r) => reference.difference(r.date).inDays < 7)
        .toList();

    // 過去 30 日
    final last30 = all
        .where((r) => reference.difference(r.date).inDays < 30)
        .toList();

    return ShareSummaryStats(
      today: ShareSubStats.fromRecords(todayRecords),
      week: ShareSubStats.fromRecords(last7),
      month: ShareSubStats.fromRecords(last30),
      streak: _computeStreak(all, reference),
    );
  }

  static Set<String> _uniqueDays(List<WorkoutRecord> records) {
    return records
        .map((r) => '${r.date.year}-${r.date.month}-${r.date.day}')
        .toSet();
  }

  static int _computeStreak(List<WorkoutRecord> all, DateTime reference) {
    if (all.isEmpty) return 0;
    final days = _uniqueDays(all)
        .map((s) {
          final parts = s.split('-').map(int.parse).toList();
          return DateTime(parts[0], parts[1], parts[2]);
        })
        .toList()
      ..sort((a, b) => b.compareTo(a));
    if (days.isEmpty) return 0;

    var streak = 0;
    var cursor = DateTime(reference.year, reference.month, reference.day);
    final daySet = days.toSet();
    while (daySet.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    // 「今日記録がなくても昨日まで連続なら継続」を許容するため、
    // 今日記録がない場合は1日だけ前に巻き戻して再判定
    if (streak == 0) {
      cursor = DateTime(reference.year, reference.month, reference.day)
          .subtract(const Duration(days: 1));
      while (daySet.contains(cursor)) {
        streak++;
        cursor = cursor.subtract(const Duration(days: 1));
      }
    }
    return streak;
  }
}
