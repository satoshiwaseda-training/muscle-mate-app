// 端末内のセッションログ（計画書 v5 §6.5 §6.6 §11.4）
//
// - user_id を持たない
// - サーバーへ送信する場合も /workout/next 経路でステートレス
// - 端末内 SharedPreferences / SQLite にのみ永続化
// - 設定画面の「アカウントデータを削除」で完全消去できる契約

import 'workout_plan.dart' show Advisory;

class SetLog {
  final double weightKg;
  final int reps;
  final double? rpe;
  final bool pain;
  final String? painRegion;

  const SetLog({
    required this.weightKg,
    required this.reps,
    this.rpe,
    this.pain = false,
    this.painRegion,
  });

  Map<String, dynamic> toJson() => {
        'weight_kg': weightKg,
        'reps': reps,
        if (rpe != null) 'rpe': rpe,
        'pain': pain,
        if (painRegion != null) 'pain_region': painRegion,
      };

  factory SetLog.fromJson(Map<String, dynamic> json) => SetLog(
        weightKg: (json['weight_kg'] as num).toDouble(),
        reps: json['reps'] as int,
        rpe: (json['rpe'] as num?)?.toDouble(),
        pain: json['pain'] as bool? ?? false,
        painRegion: json['pain_region'] as String?,
      );
}

class ExerciseLog {
  final String nameJa;
  final String nameEn;
  final List<SetLog> sets;

  const ExerciseLog({
    required this.nameJa,
    required this.nameEn,
    required this.sets,
  });

  Map<String, dynamic> toJson() => {
        'name_ja': nameJa,
        'name_en': nameEn,
        'sets': sets.map((s) => s.toJson()).toList(),
      };

  factory ExerciseLog.fromJson(Map<String, dynamic> json) => ExerciseLog(
        nameJa: json['name_ja'] as String,
        nameEn: json['name_en'] as String,
        sets: (json['sets'] as List)
            .map((e) => SetLog.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class SessionLog {
  final DateTime sessionDate;
  final String? sessionName;
  final List<ExerciseLog> exerciseLogs;

  const SessionLog({
    required this.sessionDate,
    this.sessionName,
    required this.exerciseLogs,
  });

  bool get hasAnyPain =>
      exerciseLogs.any((el) => el.sets.any((s) => s.pain));

  double? get maxRpe {
    final rpes = exerciseLogs
        .expand((el) => el.sets)
        .map((s) => s.rpe)
        .whereType<double>()
        .toList();
    if (rpes.isEmpty) return null;
    return rpes.reduce((a, b) => a > b ? a : b);
  }

  Map<String, dynamic> toJson() => {
        'session_date':
            '${sessionDate.year}-${sessionDate.month.toString().padLeft(2, '0')}-${sessionDate.day.toString().padLeft(2, '0')}',
        if (sessionName != null) 'session_name': sessionName,
        'exercise_logs': exerciseLogs.map((e) => e.toJson()).toList(),
      };

  factory SessionLog.fromJson(Map<String, dynamic> json) => SessionLog(
        sessionDate: DateTime.parse(json['session_date'] as String),
        sessionName: json['session_name'] as String?,
        exerciseLogs: (json['exercise_logs'] as List)
            .map((e) => ExerciseLog.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

// /workout/next のレスポンス
class NextWorkoutResponse {
  final bool success;
  final List<String> safetyFlags;
  final Advisory advisory;
  final Map<String, dynamic> recommendations;
  final bool externalAiUsed;
  final String? errorMessage;

  const NextWorkoutResponse({
    required this.success,
    this.safetyFlags = const [],
    this.advisory = const Advisory(),
    this.recommendations = const {},
    this.externalAiUsed = false,
    this.errorMessage,
  });

  factory NextWorkoutResponse.fromJson(Map<String, dynamic> json) =>
      NextWorkoutResponse(
        success: json['success'] as bool,
        safetyFlags: json['safety_flags'] != null
            ? List<String>.from(json['safety_flags'] as List)
            : const [],
        advisory: json['advisory'] != null
            ? Advisory.fromJson(json['advisory'] as Map<String, dynamic>)
            : const Advisory(),
        recommendations: json['recommendations'] != null
            ? Map<String, dynamic>.from(json['recommendations'] as Map)
            : const {},
        externalAiUsed: json['external_ai_used'] as bool? ?? false,
        errorMessage: json['error_message'] as String?,
      );

  /// 種目名から推奨アクションを取得
  /// 戻り値: {"action": "increase"|"stay", "delta_kg": double}
  Map<String, dynamic>? recommendationFor(String nameJa) {
    final raw = recommendations[nameJa];
    if (raw == null) return null;
    return Map<String, dynamic>.from(raw as Map);
  }
}
