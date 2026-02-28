/// 筋トレメニューの Dart モデル
/// backend/src/schemas/workout.py の WorkoutPlan と完全対応
/// fromJson / toJson で安全なシリアライズを保証

// ── Enums ────────────────────────────────────────────────────────────────────

enum Goal {
  muscleGain('muscle_gain', '筋肥大'),
  weightLoss('weight_loss', '減量'),
  endurance('endurance', '持久力'),
  general('general_fitness', '総合体力');

  const Goal(this.value, this.label);
  final String value;
  final String label;

  static Goal fromValue(String v) =>
      Goal.values.firstWhere((e) => e.value == v);
}

enum Level {
  beginner('beginner', '初心者'),
  intermediate('intermediate', '中級者'),
  advanced('advanced', '上級者');

  const Level(this.value, this.label);
  final String value;
  final String label;

  static Level fromValue(String v) =>
      Level.values.firstWhere((e) => e.value == v);
}

enum Equipment {
  barbell('barbell', 'バーベル'),
  dumbbell('dumbbell', 'ダンベル'),
  machine('machine', 'マシン'),
  bodyweight('bodyweight', '自重'),
  cable('cable', 'ケーブル'),
  kettlebell('kettlebell', 'ケトルベル');

  const Equipment(this.value, this.label);
  final String value;
  final String label;

  static Equipment fromValue(String v) =>
      Equipment.values.firstWhere((e) => e.value == v);
}

// ── リクエストモデル: Flutter → FastAPI ──────────────────────────────────────

class Big3Max {
  final double? benchPressMax;
  final double? squatMax;
  final double? deadliftMax;

  const Big3Max({
    this.benchPressMax,
    this.squatMax,
    this.deadliftMax,
  });

  bool get hasAny =>
      benchPressMax != null || squatMax != null || deadliftMax != null;

  Map<String, dynamic> toJson() => {
        if (benchPressMax != null) 'bench_press_max': benchPressMax,
        if (squatMax != null) 'squat_max': squatMax,
        if (deadliftMax != null) 'deadlift_max': deadliftMax,
      };
}

class WorkoutRequest {
  final Goal goal;
  final Level level;
  final int daysPerWeek;
  final List<Equipment> equipment;
  final int? age;
  final String? notes;
  final Big3Max? big3Max;

  const WorkoutRequest({
    required this.goal,
    required this.level,
    required this.daysPerWeek,
    required this.equipment,
    this.age,
    this.notes,
    this.big3Max,
  });

  Map<String, dynamic> toJson() => {
        'goal': goal.value,
        'level': level.value,
        'days_per_week': daysPerWeek,
        'equipment': equipment.map((e) => e.value).toList(),
        if (age != null) 'age': age,
        if (notes != null && notes!.isNotEmpty) 'notes': notes,
        if (big3Max != null && big3Max!.hasAny) 'big3_max': big3Max!.toJson(),
      };
}

// ── レスポンスモデル: FastAPI → Flutter ──────────────────────────────────────

class Exercise {
  final String nameJa;
  final String nameEn;
  final int sets;
  final String reps;
  final int restSeconds;
  final Equipment equipment;
  final List<String> targetMuscles;
  final String coachingPoint;
  final double? weightKg; // BIG3 MAXから算出されたトレーニング重量

  const Exercise({
    required this.nameJa,
    required this.nameEn,
    required this.sets,
    required this.reps,
    required this.restSeconds,
    required this.equipment,
    required this.targetMuscles,
    required this.coachingPoint,
    this.weightKg,
  });

  factory Exercise.fromJson(Map<String, dynamic> json) => Exercise(
        nameJa: json['name_ja'] as String,
        nameEn: json['name_en'] as String,
        sets: json['sets'] as int,
        reps: json['reps'] as String,
        restSeconds: json['rest_seconds'] as int,
        equipment: Equipment.fromValue(json['equipment'] as String),
        targetMuscles: List<String>.from(json['target_muscles'] as List),
        coachingPoint: json['coaching_point'] as String,
        weightKg: (json['weight_kg'] as num?)?.toDouble(),
      );
}

class DaySession {
  final String dayOfWeek;
  final String sessionName;
  final List<String> targetMuscles;
  final int estimatedDurationMinutes;
  final List<Exercise> exercises;

  const DaySession({
    required this.dayOfWeek,
    required this.sessionName,
    required this.targetMuscles,
    required this.estimatedDurationMinutes,
    required this.exercises,
  });

  factory DaySession.fromJson(Map<String, dynamic> json) => DaySession(
        dayOfWeek: json['day_of_week'] as String,
        sessionName: json['session_name'] as String,
        targetMuscles: List<String>.from(json['target_muscles'] as List),
        estimatedDurationMinutes:
            json['estimated_duration_minutes'] as int,
        exercises: (json['exercises'] as List)
            .map((e) => Exercise.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class WorkoutPlan {
  final String planName;
  final int durationWeeks;
  final List<DaySession> weeklySchedule;
  final String generalAdvice;

  const WorkoutPlan({
    required this.planName,
    required this.durationWeeks,
    required this.weeklySchedule,
    required this.generalAdvice,
  });

  factory WorkoutPlan.fromJson(Map<String, dynamic> json) => WorkoutPlan(
        planName: json['plan_name'] as String,
        durationWeeks: json['duration_weeks'] as int,
        weeklySchedule: (json['weekly_schedule'] as List)
            .map((e) => DaySession.fromJson(e as Map<String, dynamic>))
            .toList(),
        generalAdvice: json['general_advice'] as String,
      );
}

class WorkoutResponse {
  final bool success;
  final WorkoutPlan? plan;
  final String? errorMessage;

  const WorkoutResponse({
    required this.success,
    this.plan,
    this.errorMessage,
  });

  factory WorkoutResponse.fromJson(Map<String, dynamic> json) =>
      WorkoutResponse(
        success: json['success'] as bool,
        plan: json['plan'] != null
            ? WorkoutPlan.fromJson(json['plan'] as Map<String, dynamic>)
            : null,
        errorMessage: json['error_message'] as String?,
      );
}
