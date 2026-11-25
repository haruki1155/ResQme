import 'package:flutter/material.dart';

class ConditionalAction {
  const ConditionalAction({required this.condition, required this.action});

  factory ConditionalAction.fromJson(Map<String, dynamic> json) {
    final condition = (json['condition'] as String?)?.trim() ?? '';
    final action = (json['action'] as String?)?.trim() ?? '';
    if (condition.isEmpty || action.isEmpty) {
      throw const FormatException('Invalid ConditionalAction');
    }
    return ConditionalAction(condition: condition, action: action);
  }

  final String condition;
  final String action;
}

class QuickInstructions {
  const QuickInstructions({
    required this.immediateAction,
    required this.recognitionSigns,
    required this.steps,
    required this.conditionalActions,
    required this.warnings,
    required this.emergencyEscalation,
  });

  factory QuickInstructions.fromJson(Map<String, dynamic> json) {
    final immediateAction = (json['immediateAction'] as String?)?.trim() ?? '';
    final steps = _stringList(json['steps']);
    if (immediateAction.isEmpty || steps.isEmpty) {
      throw const FormatException('Invalid QuickInstructions');
    }
    final rawConditionals = json['conditionalActions'] as List<dynamic>? ?? [];
    return QuickInstructions(
      immediateAction: immediateAction,
      recognitionSigns: _stringList(json['recognitionSigns']),
      steps: steps,
      conditionalActions: rawConditionals
          .map(
            (item) =>
                ConditionalAction.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(growable: false),
      warnings: _stringList(json['warnings']),
      emergencyEscalation: _stringList(json['emergencyEscalation']),
    );
  }

  final String immediateAction;
  final List<String> recognitionSigns;
  final List<String> steps;
  final List<ConditionalAction> conditionalActions;
  final List<String> warnings;
  final List<String> emergencyEscalation;
}

class LearnMoreArticle {
  const LearnMoreArticle({
    required this.overview,
    required this.causes,
    required this.riskFactors,
    required this.detailedRecognition,
    required this.prevention,
    required this.preparation,
    required this.explanations,
    required this.additionalPrecautions,
    required this.followUpCare,
  });

  factory LearnMoreArticle.fromJson(Map<String, dynamic> json) {
    final overview = (json['overview'] as String?)?.trim() ?? '';
    if (overview.isEmpty) {
      throw const FormatException('Invalid LearnMoreArticle: missing overview');
    }
    return LearnMoreArticle(
      overview: overview,
      causes: _stringList(json['causes']),
      riskFactors: _stringList(json['riskFactors']),
      detailedRecognition: _stringList(json['detailedRecognition']),
      prevention: _stringList(json['prevention']),
      preparation: _stringList(json['preparation']),
      explanations: _stringList(json['explanations']),
      additionalPrecautions: _stringList(json['additionalPrecautions']),
      followUpCare: _stringList(json['followUpCare']),
    );
  }

  final String overview;
  final List<String> causes;
  final List<String> riskFactors;
  final List<String> detailedRecognition;
  final List<String> prevention;
  final List<String> preparation;
  final List<String> explanations;
  final List<String> additionalPrecautions;
  final List<String> followUpCare;
}

class SourceReference {
  const SourceReference({
    required this.organization,
    required this.edition,
    required this.chapter,
    required this.topicTitle,
    required this.printedPages,
    required this.pdfPages,
    required this.topicIndexPage,
    required this.url,
  });

  factory SourceReference.fromJson(Map<String, dynamic> json) {
    final printed = _intList(json['printedPages']);
    final pdf = _intList(json['pdfPages']);
    if (printed.length != 2 || pdf.length != 2) {
      throw const FormatException('Invalid SourceReference page range');
    }
    return SourceReference(
      organization: (json['organization'] as String?)?.trim() ?? 'IFRC',
      edition: (json['edition'] as String?)?.trim() ?? '2025',
      chapter: (json['chapter'] as String?)?.trim() ?? '',
      topicTitle: (json['topicTitle'] as String?)?.trim() ?? '',
      printedPages: printed,
      pdfPages: pdf,
      topicIndexPage: (json['topicIndexPage'] as num?)?.toInt() ?? printed.first,
      url: (json['url'] as String?)?.trim() ?? '',
    );
  }

  final String organization;
  final String edition;
  final String chapter;
  final String topicTitle;
  final List<int> printedPages;
  final List<int> pdfPages;
  final int topicIndexPage;
  final String url;

  String get pageCitation {
    final start = printedPages.first;
    final end = printedPages.last;
    return start == end ? 'p. $start' : 'pp. $start\u2013$end';
  }
}

class ReviewMetadata {
  const ReviewMetadata({
    required this.sourceVerification,
    required this.clinicalApproval,
    required this.reviewer,
    required this.reviewerQualification,
    required this.approvedAt,
  });

  factory ReviewMetadata.fromJson(Map<String, dynamic> json) {
    return ReviewMetadata(
      sourceVerification:
          (json['sourceVerification'] as String?)?.trim() ?? 'pending',
      clinicalApproval:
          (json['clinicalApproval'] as String?)?.trim() ?? 'pending',
      reviewer: (json['reviewer'] as String?)?.trim(),
      reviewerQualification: (json['reviewerQualification'] as String?)?.trim(),
      approvedAt: (json['approvedAt'] as String?)?.trim(),
    );
  }

  final String sourceVerification;
  final String clinicalApproval;
  final String? reviewer;
  final String? reviewerQualification;
  final String? approvedAt;

  /// True ONLY when human clinical approval and reviewer attribution exist.
  bool get isClinicallyApproved =>
      clinicalApproval == 'approved' &&
      reviewer != null &&
      reviewer!.isNotEmpty &&
      approvedAt != null &&
      approvedAt!.isNotEmpty;
}

class FirstAidTopic {
  const FirstAidTopic({
    required this.id,
    required this.displayOrder,
    required this.title,
    required this.shortTitle,
    required this.category,
    required this.classification,
    required this.urgency,
    required this.ageGroup,
    required this.audience,
    required this.isCommonEmergency,
    required this.requiresEmergencyCall,
    required this.iconName,
    required this.searchKeywords,
    required this.quickInstructions,
    required this.learnMore,
    required this.relatedTopics,
    required this.source,
    required this.contentVersion,
    required this.review,
  });

  factory FirstAidTopic.fromJson(Map<String, dynamic> json) {
    final id = (json['id'] as String?)?.trim() ?? '';
    final title = (json['title'] as String?)?.trim() ?? '';
    final category = (json['category'] as String?)?.trim() ?? '';
    if (id.isEmpty || title.isEmpty || category.isEmpty) {
      throw const FormatException('Invalid FirstAidTopic identity');
    }
    return FirstAidTopic(
      id: id,
      displayOrder: (json['displayOrder'] as num?)?.toInt() ?? 0,
      title: title,
      shortTitle: (json['shortTitle'] as String?)?.trim() ?? title,
      category: category,
      classification:
          (json['classification'] as String?)?.trim() ?? 'common_first_aid',
      urgency: (json['urgency'] as String?)?.trim() ?? 'moderate',
      ageGroup: (json['ageGroup'] as String?)?.trim() ?? 'all_ages',
      audience: (json['audience'] as String?)?.trim() ?? 'lay_responder',
      isCommonEmergency: json['isCommonEmergency'] == true,
      requiresEmergencyCall: json['requiresEmergencyCall'] == true,
      iconName: (json['iconName'] as String?)?.trim() ?? 'medical_services',
      searchKeywords: _stringList(json['searchKeywords']),
      quickInstructions: QuickInstructions.fromJson(
        Map<String, dynamic>.from(json['quickInstructions'] as Map),
      ),
      learnMore: LearnMoreArticle.fromJson(
        Map<String, dynamic>.from(json['learnMore'] as Map),
      ),
      relatedTopics: _stringList(json['relatedTopics']),
      source: SourceReference.fromJson(
        Map<String, dynamic>.from(json['source'] as Map),
      ),
      contentVersion: (json['contentVersion'] as String?)?.trim() ?? '2025.1.0',
      review: ReviewMetadata.fromJson(
        Map<String, dynamic>.from(json['review'] as Map),
      ),
    );
  }

  final String id;
  final int displayOrder;
  final String title;
  final String shortTitle;
  final String category;
  final String classification;
  final String urgency;
  final String ageGroup;
  final String audience;
  final bool isCommonEmergency;
  final bool requiresEmergencyCall;
  final String iconName;
  final List<String> searchKeywords;
  final QuickInstructions quickInstructions;
  final LearnMoreArticle learnMore;
  final List<String> relatedTopics;
  final SourceReference source;
  final String contentVersion;
  final ReviewMetadata review;

  bool get isTrainedResponderOnly =>
      audience == 'trained_responder' ||
      classification == 'trained_responder_only';

  bool get isCriticalEmergency =>
      classification == 'critical_emergency' || urgency == 'critical';

  String get ageGroupLabel => switch (ageGroup) {
    'adult_adolescent' => 'Adult & adolescent',
    'child' => 'Child (1 yr to puberty)',
    'infant' => 'Infant (<1 yr)',
    'infant_child' => 'Infant & young child',
    _ => 'All ages',
  };

  String get audienceLabel => isTrainedResponderOnly
      ? 'Trained responder qualification required'
      : 'Suitable for lay bystanders';

  IconData get iconData => switch (iconName) {
    'fact_check_outlined' => Icons.fact_check_outlined,
    'health_and_safety_outlined' => Icons.health_and_safety_outlined,
    'volunteer_activism_outlined' => Icons.volunteer_activism_outlined,
    'clean_hands_outlined' => Icons.clean_hands_outlined,
    'air' || 'air_outlined' => Icons.air,
    'hotel_outlined' || 'airline_seat_flat' => Icons.airline_seat_flat_outlined,
    'monitor_heart' || 'monitor_heart_outlined' => Icons.monitor_heart_outlined,
    'child_care' || 'child_care_outlined' => Icons.child_care_outlined,
    'crib_outlined' => Icons.crib_outlined,
    'bolt' || 'bolt_outlined' => Icons.bolt_outlined,
    'medication_liquid' || 'medication_outlined' => Icons.medication_outlined,
    'pool' || 'water' => Icons.pool_outlined,
    'lungs' || 'Masks_outlined' => Icons.air_outlined,
    'warning_amber_outlined' || 'warning_amber' => Icons.warning_amber_rounded,
    'water_drop' || 'water_drop_outlined' => Icons.water_drop_outlined,
    'personal_injury_outlined' => Icons.personal_injury_outlined,
    'content_cut' => Icons.content_cut_outlined,
    'healing' || 'healing_outlined' => Icons.healing_outlined,
    'mood_bad_outlined' => Icons.medical_information_outlined,
    'local_fire_department_outlined' ||
    'local_fire_department' => Icons.local_fire_department_outlined,
    'science_outlined' => Icons.science_outlined,
    'visibility_outlined' => Icons.visibility_outlined,
    'accessibility_new' => Icons.accessibility_new,
    'pets_outlined' || 'pets' => Icons.pets_outlined,
    'bug_report_outlined' => Icons.bug_report_outlined,
    'dangerous_outlined' => Icons.dangerous_outlined,
    'favorite' => Icons.favorite_outline,
    'favorite_border' => Icons.favorite_border,
    'psychology_alt' || 'psychology' || 'psychology_outlined' =>
      Icons.psychology_outlined,
    'vaccines' => Icons.vaccines_outlined,
    'bloodtype_outlined' => Icons.bloodtype_outlined,
    'waves' => Icons.waves_outlined,
    'thermostat' => Icons.thermostat_outlined,
    'sick_outlined' => Icons.sick_outlined,
    'pregnant_woman' => Icons.pregnant_woman_outlined,
    'record_voice_over' => Icons.record_voice_over_outlined,
    'hearing' => Icons.hearing_outlined,
    'wb_sunny' => Icons.wb_sunny_outlined,
    'wb_twilight' => Icons.wb_twilight_outlined,
    'local_drink_outlined' => Icons.local_drink_outlined,
    'ac_unit' || 'severe_cold' => Icons.ac_unit_outlined,
    'terrain' => Icons.terrain_outlined,
    'scuba_diving' => Icons.scuba_diving_outlined,
    'directions_boat_outlined' => Icons.directions_boat_outlined,
    'support' => Icons.support_outlined,
    'self_improvement' => Icons.self_improvement_outlined,
    _ => Icons.medical_services_outlined,
  };
}

class FirstAidPrimarySource {
  const FirstAidPrimarySource({
    required this.title,
    required this.organization,
    required this.edition,
    required this.publicationYear,
    required this.url,
    required this.sha256,
  });

  factory FirstAidPrimarySource.fromJson(Map<String, dynamic> json) {
    return FirstAidPrimarySource(
      title: (json['title'] as String?)?.trim() ??
          'International first aid, resuscitation and education guidelines 2025',
      organization: (json['organization'] as String?)?.trim() ?? 'IFRC',
      edition: (json['edition'] as String?)?.trim() ?? '2025',
      publicationYear: (json['publicationYear'] as num?)?.toInt() ?? 2025,
      url: (json['url'] as String?)?.trim() ?? '',
      sha256: (json['sha256'] as String?)?.trim() ?? '',
    );
  }

  final String title;
  final String organization;
  final String edition;
  final int publicationYear;
  final String url;
  final String sha256;
}

class FirstAidLibraryBundle {
  const FirstAidLibraryBundle({
    required this.schemaVersion,
    required this.contentVersion,
    required this.governingPrinciple,
    required this.nonEndorsementNotice,
    required this.medicalDisclaimer,
    required this.primarySource,
    required this.categories,
    required this.topics,
    this.excludedPendingApprovalCount = 0,
    this.loadError,
  });

  final String schemaVersion;
  final String contentVersion;
  final String governingPrinciple;
  final String nonEndorsementNotice;
  final String medicalDisclaimer;
  final FirstAidPrimarySource primarySource;
  final List<String> categories;
  final List<FirstAidTopic> topics;
  final int excludedPendingApprovalCount;
  final String? loadError;

  bool get hasLoadError => loadError != null;

  FirstAidTopic? topicById(String id) {
    for (final topic in topics) {
      if (topic.id == id) return topic;
    }
    return null;
  }
}

List<String> _stringList(Object? raw) {
  if (raw is! List) return const <String>[];
  return raw
      .map((item) => item.toString().trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

List<int> _intList(Object? raw) {
  if (raw is! List) return const <int>[];
  return raw.map((item) => (item as num).toInt()).toList(growable: false);
}
