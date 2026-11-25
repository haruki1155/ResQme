import 'package:flutter/foundation.dart';
import 'package:resqme/features/public_support/domain/first_aid_models.dart';

/// Controls whether unapproved clinical drafts may be rendered.
///
/// Public release builds strictly exclude any topic whose human clinical
/// approval is not `'approved'` with verified reviewer metadata.
enum FirstAidReleaseMode {
  /// Production/public release gate: ONLY human-approved topics are shown.
  publicRelease,

  /// Development, automated test, and isolated clinical-review staging mode:
  /// allows inspecting source-verified drafts with a prominent
  /// `Pending clinical review` banner.
  clinicalReviewDraft,
}

class FirstAidReleasePolicy {
  const FirstAidReleasePolicy._(this.mode);

  final FirstAidReleaseMode mode;

  static const FirstAidReleasePolicy publicRelease = FirstAidReleasePolicy._(
    FirstAidReleaseMode.publicRelease,
  );

  static const FirstAidReleasePolicy clinicalReviewDraft =
      FirstAidReleasePolicy._(FirstAidReleaseMode.clinicalReviewDraft);

  /// Resolves the active policy from build mode.
  ///
  /// Release builds (`isReleaseBuild == true`) unconditionally enforce
  /// [publicRelease] so unapproved drafts can never ship to public users.
  factory FirstAidReleasePolicy.fromEnvironment({
    bool isReleaseBuild = kReleaseMode,
  }) {
    if (isReleaseBuild) {
      return publicRelease;
    }
    return clinicalReviewDraft;
  }

  bool get isPublicRelease => mode == FirstAidReleaseMode.publicRelease;

  bool allowsTopic(FirstAidTopic topic) {
    if (isPublicRelease) {
      return topic.review.isClinicallyApproved;
    }
    return topic.review.isClinicallyApproved ||
        topic.review.sourceVerification == 'verified';
  }
}
