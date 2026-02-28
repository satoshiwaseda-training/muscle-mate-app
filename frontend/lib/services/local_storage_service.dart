// SharedPreferences によるワークアウト履歴の永続化
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/workout_record.dart';

class LocalStorageService {
  static const _key = 'workout_records';

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
}
