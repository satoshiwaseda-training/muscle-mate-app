// 筋トレメニューの Dart モデル
// backend/src/schemas/workout.py と完全対応（計画書 v5）
// fromJson / toJson で安全なシリアライズを保証

// ── Enums ────────────────────────────────────────────────────────────────────

enum Goal {
  muscleGain('muscle_gain', '筋力アップ'),
  weightLoss('weight_loss', '引き締め'),
  endurance('endurance', '疲れにくい体'),
  general('general_fitness', '健康維持');

  const Goal(this.value, this.label);
  final String value;
  final String label;

  static Goal fromValue(String v) =>
      Goal.values.firstWhere((e) => e.value == v, orElse: () => Goal.general);
}

enum Level {
  beginner('beginner', 'これから始める'),
  intermediate('intermediate', '慣れてきた'),
  advanced('advanced', 'しっかり鍛える');

  const Level(this.value, this.label);
  final String value;
  final String label;

  static Level fromValue(String v) =>
      Level.values.firstWhere((e) => e.value == v, orElse: () => Level.beginner);
}

enum Equipment {
  barbell('barbell', 'バーベル'),
  dumbbell('dumbbell', 'ダンベル'),
  machine('machine', 'マシン'),
  bodyweight('bodyweight', '自重'),
  cable('cable', 'ケーブル');

  const Equipment(this.value, this.label);
  final String value;
  final String label;

  static Equipment fromValue(String v) =>
      Equipment.values.firstWhere((e) => e.value == v,
          orElse: () => Equipment.bodyweight);
}

// v5 で追加: 任意の優先リフト
enum PriorityLift {
  none('none', '指定なし'),
  bench('bench', 'ベンチプレス'),
  squat('squat', 'スクワット'),
  deadlift('deadlift', 'デッドリフト');

  const PriorityLift(this.value, this.label);
  final String value;
  final String label;

  static PriorityLift fromValue(String v) =>
      PriorityLift.values.firstWhere((e) => e.value == v,
          orElse: () => PriorityLift.none);
}

// v5 で追加: Advisory のレベル
enum AdvisoryLevel {
  none('none'),
  partialSkip('partial_skip'),
  restOrConsult('rest_or_consult'),
  deload('deload');

  const AdvisoryLevel(this.value);
  final String value;

  static AdvisoryLevel fromValue(String v) =>
      AdvisoryLevel.values.firstWhere((e) => e.value == v,
          orElse: () => AdvisoryLevel.none);
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
  final int sessionDurationMinutes;
  final List<Equipment> equipment;
  final List<String> targetMuscles;
  final int? age;
  final String? notes;
  final Big3Max? big3Max;

  // v5 で追加された任意フィールド
  final PriorityLift? priorityLift;
  final double? bodyWeightKg;
  final double? yearsOfTraining;

  // v1.0 (履歴ベースの最適化): LocalStorageService.buildRecentHistorySummary
  // で生成した集計値を Map で渡す。サーバーは永続化しない。
  final Map<String, dynamic>? recentHistory;

  const WorkoutRequest({
    required this.goal,
    required this.level,
    this.daysPerWeek = 3,
    this.sessionDurationMinutes = 60,
    required this.equipment,
    this.targetMuscles = const [],
    this.age,
    this.notes,
    this.big3Max,
    this.priorityLift,
    this.bodyWeightKg,
    this.yearsOfTraining,
    this.recentHistory,
  });

  Map<String, dynamic> toJson() => {
        'goal': goal.value,
        'level': level.value,
        'days_per_week': daysPerWeek,
        'session_duration_minutes': sessionDurationMinutes,
        'equipment': equipment.map((e) => e.value).toList(),
        if (targetMuscles.isNotEmpty) 'target_muscles': targetMuscles,
        if (age != null) 'age': age,
        if (notes != null && notes!.isNotEmpty) 'notes': notes,
        if (big3Max != null && big3Max!.hasAny) 'big3_max': big3Max!.toJson(),
        if (priorityLift != null && priorityLift != PriorityLift.none)
          'priority_lift': priorityLift!.value,
        if (bodyWeightKg != null) 'body_weight_kg': bodyWeightKg,
        if (yearsOfTraining != null) 'years_of_training': yearsOfTraining,
        if (recentHistory != null) 'recent_history': recentHistory,
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
  final double? weightKg;

  // v5 で追加
  final List<String> evidenceRefs;
  final List<String> safetyFlags;
  final String? progressionRule;

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
    this.evidenceRefs = const [],
    this.safetyFlags = const [],
    this.progressionRule,
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
        evidenceRefs: json['evidence_refs'] != null
            ? List<String>.from(json['evidence_refs'] as List)
            : const [],
        safetyFlags: json['safety_flags'] != null
            ? List<String>.from(json['safety_flags'] as List)
            : const [],
        progressionRule: json['progression_rule'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'name_ja': nameJa,
        'name_en': nameEn,
        'sets': sets,
        'reps': reps,
        'rest_seconds': restSeconds,
        'equipment': equipment.value,
        'target_muscles': targetMuscles,
        'coaching_point': coachingPoint,
        if (weightKg != null) 'weight_kg': weightKg,
        'evidence_refs': evidenceRefs,
        'safety_flags': safetyFlags,
        if (progressionRule != null) 'progression_rule': progressionRule,
      };
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

  Map<String, dynamic> toJson() => {
        'day_of_week': dayOfWeek,
        'session_name': sessionName,
        'target_muscles': targetMuscles,
        'estimated_duration_minutes': estimatedDurationMinutes,
        'exercises': exercises.map((e) => e.toJson()).toList(),
      };
}

/// 提案根拠（v1.0 で追加）。論文ベースのルールが何を見て何を選んだかを格納。
class ProposalRationale {
  final String summary;
  final List<String> bullets;
  final List<String> evidenceRefs;

  const ProposalRationale({
    required this.summary,
    this.bullets = const [],
    this.evidenceRefs = const [],
  });

  factory ProposalRationale.fromJson(Map<String, dynamic> json) =>
      ProposalRationale(
        summary: json['summary'] as String,
        bullets: json['bullets'] != null
            ? List<String>.from(json['bullets'] as List)
            : const [],
        evidenceRefs: json['evidence_refs'] != null
            ? List<String>.from(json['evidence_refs'] as List)
            : const [],
      );

  Map<String, dynamic> toJson() => {
        'summary': summary,
        'bullets': bullets,
        'evidence_refs': evidenceRefs,
      };
}

class WorkoutPlan {
  final String planName;
  final int durationWeeks;
  final List<DaySession> weeklySchedule;
  final String generalAdvice;

  // v5 で追加
  final List<String> safetyFlags;

  // v1.0 で追加: 履歴ベース最適化が走った時の提案根拠
  final ProposalRationale? proposalRationale;

  const WorkoutPlan({
    required this.planName,
    required this.durationWeeks,
    required this.weeklySchedule,
    required this.generalAdvice,
    this.safetyFlags = const [],
    this.proposalRationale,
  });

  factory WorkoutPlan.fromJson(Map<String, dynamic> json) => WorkoutPlan(
        planName: json['plan_name'] as String,
        durationWeeks: json['duration_weeks'] as int,
        weeklySchedule: (json['weekly_schedule'] as List)
            .map((e) => DaySession.fromJson(e as Map<String, dynamic>))
            .toList(),
        generalAdvice: json['general_advice'] as String,
        safetyFlags: json['safety_flags'] != null
            ? List<String>.from(json['safety_flags'] as List)
            : const [],
        proposalRationale: json['proposal_rationale'] != null
            ? ProposalRationale.fromJson(
                json['proposal_rationale'] as Map<String, dynamic>)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'plan_name': planName,
        'duration_weeks': durationWeeks,
        'weekly_schedule': weeklySchedule.map((s) => s.toJson()).toList(),
        'general_advice': generalAdvice,
        'safety_flags': safetyFlags,
        if (proposalRationale != null)
          'proposal_rationale': proposalRationale!.toJson(),
      };
}

// v5 §6.4 で追加: ユーザーへの推奨アクション
class Advisory {
  final AdvisoryLevel level;
  final String? title;
  final String? body;
  final List<String> actions;

  const Advisory({
    this.level = AdvisoryLevel.none,
    this.title,
    this.body,
    this.actions = const [],
  });

  factory Advisory.fromJson(Map<String, dynamic> json) => Advisory(
        level: AdvisoryLevel.fromValue(json['level'] as String? ?? 'none'),
        title: json['title'] as String?,
        body: json['body'] as String?,
        actions: json['actions'] != null
            ? List<String>.from(json['actions'] as List)
            : const [],
      );

  bool get isNone => level == AdvisoryLevel.none;
  bool get isRestOrConsult => level == AdvisoryLevel.restOrConsult;
  bool get isPartialSkip => level == AdvisoryLevel.partialSkip;
  bool get isDeload => level == AdvisoryLevel.deload;
}

// v5 §6.4 で拡張: トップレベルに safety_flags / advisory / external_ai_used を追加
class WorkoutResponse {
  final bool success;
  final WorkoutPlan? plan;
  final List<String> safetyFlags;
  final Advisory advisory;
  final bool externalAiUsed;
  final String? errorMessage;

  const WorkoutResponse({
    required this.success,
    this.plan,
    this.safetyFlags = const [],
    this.advisory = const Advisory(),
    this.externalAiUsed = false,
    this.errorMessage,
  });

  factory WorkoutResponse.fromJson(Map<String, dynamic> json) =>
      WorkoutResponse(
        success: json['success'] as bool,
        plan: json['plan'] != null
            ? WorkoutPlan.fromJson(json['plan'] as Map<String, dynamic>)
            : null,
        safetyFlags: json['safety_flags'] != null
            ? List<String>.from(json['safety_flags'] as List)
            : const [],
        advisory: json['advisory'] != null
            ? Advisory.fromJson(json['advisory'] as Map<String, dynamic>)
            : const Advisory(),
        externalAiUsed: json['external_ai_used'] as bool? ?? false,
        errorMessage: json['error_message'] as String?,
      );
}
