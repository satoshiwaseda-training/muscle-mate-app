// アドバイスカードの Dart モデル
// backend/src/schemas/advice.py と完全対応

enum AdviceCategory {
  proteinIntake('protein_intake', 'タンパク質'),
  fatBalance('fat_balance', '脂質'),
  caffeineTiming('caffeine_timing', 'カフェイン'),
  restInterval('rest_interval', '休息'),
  equipmentGuidance('equipment_guidance', '器具'),
  big3Progression('big3_progression', 'BIG3'),
  volumeTarget('volume_target', 'ボリューム'),
  safetyNote('safety_note', '安全'),
  injuryCare('injury_care', 'ケア'),
  weightLossDiet('weight_loss_diet', '減量'),
  muscleGroupFocus('muscle_group_focus', '部位'),
  sessionTrend('session_trend', '進捗');

  const AdviceCategory(this.value, this.label);
  final String value;
  final String label;

  static AdviceCategory fromValue(String v) =>
      AdviceCategory.values.firstWhere(
        (e) => e.value == v,
        orElse: () => AdviceCategory.safetyNote,
      );
}

enum AdviceSeverity {
  info('info'),
  tip('tip'),
  warning('warning');

  const AdviceSeverity(this.value);
  final String value;

  static AdviceSeverity fromValue(String v) => AdviceSeverity.values.firstWhere(
        (e) => e.value == v,
        orElse: () => AdviceSeverity.info,
      );
}

class AdviceCard {
  final String cardId;
  final AdviceCategory category;
  final String title;
  final String body;
  final Map<String, double> numericTargets;
  final List<String> evidenceRefs;
  final AdviceSeverity severity;

  const AdviceCard({
    required this.cardId,
    required this.category,
    required this.title,
    required this.body,
    this.numericTargets = const {},
    this.evidenceRefs = const [],
    this.severity = AdviceSeverity.info,
  });

  factory AdviceCard.fromJson(Map<String, dynamic> json) => AdviceCard(
        cardId: json['card_id'] as String,
        category: AdviceCategory.fromValue(json['category'] as String),
        title: json['title'] as String,
        body: json['body'] as String,
        numericTargets: json['numeric_targets'] != null
            ? Map<String, double>.from((json['numeric_targets'] as Map)
                .map((k, v) => MapEntry(k.toString(), (v as num).toDouble())))
            : const {},
        evidenceRefs: json['evidence_refs'] != null
            ? List<String>.from(json['evidence_refs'] as List)
            : const [],
        severity:
            AdviceSeverity.fromValue(json['severity'] as String? ?? 'info'),
      );
}

class AdviceResponse {
  final bool success;
  final List<AdviceCard> cards;
  final bool externalAiUsed;
  final String? errorMessage;

  const AdviceResponse({
    required this.success,
    this.cards = const [],
    this.externalAiUsed = false,
    this.errorMessage,
  });

  factory AdviceResponse.fromJson(Map<String, dynamic> json) => AdviceResponse(
        success: json['success'] as bool,
        cards: json['cards'] != null
            ? (json['cards'] as List)
                .map((e) => AdviceCard.fromJson(e as Map<String, dynamic>))
                .toList()
            : const [],
        externalAiUsed: json['external_ai_used'] as bool? ?? false,
        errorMessage: json['error_message'] as String?,
      );
}

// assets/evidence_index.json のエントリ
class EvidenceMeta {
  final String evidenceId;
  final String title;
  final List<String> authors;
  final int? year;
  final String doi;
  final String license;
  final String sourceUrl;
  final String shortSummaryJa;

  const EvidenceMeta({
    required this.evidenceId,
    required this.title,
    this.authors = const [],
    this.year,
    this.doi = '',
    this.license = '',
    this.sourceUrl = '',
    this.shortSummaryJa = '',
  });

  factory EvidenceMeta.fromJson(Map<String, dynamic> json) => EvidenceMeta(
        evidenceId: json['evidence_id'] as String,
        title: json['title'] as String? ?? '',
        authors: json['authors'] != null
            ? List<String>.from(json['authors'] as List)
            : const [],
        year: json['year'] is int ? json['year'] as int : null,
        doi: json['doi'] as String? ?? '',
        license: json['license'] as String? ?? '',
        sourceUrl: json['source_url'] as String? ?? '',
        shortSummaryJa: json['short_summary_ja'] as String? ?? '',
      );

  String get formattedAuthors {
    if (authors.isEmpty) return '';
    if (authors.length <= 3) return authors.join(', ');
    return '${authors.take(2).join(', ')} et al.';
  }

  String get displayCitation {
    final parts = <String>[];
    if (formattedAuthors.isNotEmpty) parts.add(formattedAuthors);
    if (year != null) parts.add('($year)');
    if (title.isNotEmpty) parts.add(title);
    return parts.join(' ');
  }
}
