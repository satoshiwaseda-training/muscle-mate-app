// ワークアウト実績の記録モデル
/// SharedPreferences に JSON として保存する
import 'dart:convert';

class SetRecord {
  final String exerciseName;
  final double weightKg;
  final int reps;

  const SetRecord({
    required this.exerciseName,
    required this.weightKg,
    required this.reps,
  });

  double get volume => weightKg * reps;

  Map<String, dynamic> toJson() => {
        'exercise_name': exerciseName,
        'weight_kg': weightKg,
        'reps': reps,
      };

  factory SetRecord.fromJson(Map<String, dynamic> j) => SetRecord(
        exerciseName: j['exercise_name'] as String,
        weightKg: (j['weight_kg'] as num).toDouble(),
        reps: j['reps'] as int,
      );
}

class WorkoutRecord {
  final String id;             // ISO8601 日時文字列をIDにする
  final DateTime date;
  final String planName;
  final List<String> trainedMuscles;  // MuscleGroup の value 文字列
  final List<SetRecord> sets;
  final Map<String, dynamic>? entertainment; // APIレスポンス

  const WorkoutRecord({
    required this.id,
    required this.date,
    required this.planName,
    required this.trainedMuscles,
    required this.sets,
    this.entertainment,
  });

  double get totalVolume =>
      sets.fold(0.0, (sum, s) => sum + s.volume);

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'plan_name': planName,
        'trained_muscles': trainedMuscles,
        'sets': sets.map((s) => s.toJson()).toList(),
        'entertainment': entertainment,
      };

  factory WorkoutRecord.fromJson(Map<String, dynamic> j) => WorkoutRecord(
        id: j['id'] as String,
        date: DateTime.parse(j['date'] as String),
        planName: j['plan_name'] as String,
        trainedMuscles: List<String>.from(j['trained_muscles'] as List),
        sets: (j['sets'] as List)
            .map((s) => SetRecord.fromJson(s as Map<String, dynamic>))
            .toList(),
        entertainment: j['entertainment'] as Map<String, dynamic>?,
      );

  String toJsonString() => jsonEncode(toJson());
  static WorkoutRecord fromJsonString(String s) =>
      WorkoutRecord.fromJson(jsonDecode(s) as Map<String, dynamic>);
}
