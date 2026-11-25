import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resqme/features/public_support/data/first_aid_repository.dart';
import 'package:resqme/features/public_support/domain/first_aid_release_policy.dart';

class _StringAssetBundle extends CachingAssetBundle {
  _StringAssetBundle(this.payload, {this.shouldThrow = false});

  final String payload;
  final bool shouldThrow;

  @override
  Future<ByteData> load(String key) async {
    if (shouldThrow) throw StateError('Missing asset: $key');
    final bytes = Uint8List.fromList(utf8.encode(payload));
    return ByteData.view(bytes.buffer);
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    if (shouldThrow) throw StateError('Missing asset: $key');
    return payload;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(FirstAidRepository.clearCache);

  test(
    'canonical first_aid_library.json loads offline with complete IFRC 2025 coverage and valid links',
    () async {
      final bundle = await FirstAidRepository().loadLibrary(
        policy: FirstAidReleasePolicy.clinicalReviewDraft,
      );

      expect(bundle.hasLoadError, isFalse);
      expect(bundle.topics.length, 66);
      expect(bundle.categories.length, 7);
      expect(
        bundle.primarySource.sha256,
        'EED67BDFF38CA8A7628C7B01BE5BCD23796601E0D85BB021DC301EC3F9FF8F1F',
      );
      expect(
        bundle.nonEndorsementNotice.toLowerCase(),
        contains('not affiliated with, endorsed by, or certified by the ifrc'),
      );

      final ids = <String>{};
      final sourceChapters = <String>{};
      for (final topic in bundle.topics) {
        expect(ids.add(topic.id), isTrue, reason: 'Duplicate ID ${topic.id}');
        expect(topic.title, isNotEmpty);
        expect(topic.quickInstructions.immediateAction, isNotEmpty);
        expect(topic.quickInstructions.recognitionSigns.length, greaterThanOrEqualTo(2));
        expect(topic.quickInstructions.steps.length, inInclusiveRange(3, 7));
        expect(topic.quickInstructions.warnings, isNotEmpty);
        expect(topic.quickInstructions.emergencyEscalation, isNotEmpty);
        expect(topic.learnMore.overview, isNotEmpty);
        expect(topic.source.printedPages.first, greaterThanOrEqualTo(113));
        expect(topic.source.printedPages.last, lessThanOrEqualTo(522));
        sourceChapters.add(topic.source.topicTitle);

        // No fabricated reviewer credentials
        expect(topic.review.sourceVerification, 'verified');
        expect(topic.review.clinicalApproval, 'pending');
        expect(topic.review.reviewer, isNull);
        expect(topic.review.approvedAt, isNull);
        expect(topic.review.isClinicallyApproved, isFalse);
      }

      // All 57 IFRC 2025 clinical chapters accounted for
      expect(sourceChapters.length, 57);

      // Every relatedTopic ID resolves cleanly
      for (final topic in bundle.topics) {
        expect(topic.relatedTopics, isNotEmpty);
        for (final relId in topic.relatedTopics) {
          expect(ids.contains(relId), isTrue, reason: '${topic.id} -> $relId');
        }
      }

      // Distinct age separations for CPR and Choking
      expect(bundle.topicById('cpr-adult')?.ageGroup, 'adult_adolescent');
      expect(bundle.topicById('cpr-child')?.ageGroup, 'child');
      expect(bundle.topicById('cpr-infant')?.ageGroup, 'infant');
      expect(bundle.topicById('choking-adult')?.ageGroup, 'adult_adolescent');
      expect(bundle.topicById('choking-child')?.ageGroup, 'child');
      expect(bundle.topicById('choking-infant')?.ageGroup, 'infant');

      // Trained-responder restrictions enforced on specialized oxygen procedures
      expect(bundle.topicById('oxygen-administration')?.isTrainedResponderOnly, isTrue);
      expect(bundle.topicById('decompression-illness')?.isTrainedResponderOnly, isTrue);
    },
  );

  test(
    'publicRelease policy strictly excludes unapproved topics and blocks release builds',
    () async {
      final releasePolicy = FirstAidReleasePolicy.fromEnvironment(
        isReleaseBuild: true,
      );
      expect(releasePolicy.isPublicRelease, isTrue);

      final bundle = await FirstAidRepository().loadLibrary(
        policy: releasePolicy,
      );

      expect(bundle.hasLoadError, isFalse);
      expect(bundle.topics, isEmpty);
      expect(bundle.excludedPendingApprovalCount, 66);
    },
  );

  test(
    'publicRelease allows ONLY topics with human clinicalApproval, reviewer, and approvedAt',
    () async {
      final raw = await rootBundle.loadString(
        FirstAidRepository.defaultAssetPath,
      );
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final topics = List<Map<String, dynamic>>.from(decoded['topics'] as List);

      // Topic 0: properly signed off by a qualified human reviewer
      topics[0] = {
        ...topics[0],
        'review': {
          'sourceVerification': 'verified',
          'clinicalApproval': 'approved',
          'reviewer': 'Dr. Example Reviewer, MD',
          'reviewerQualification': 'Emergency Medicine Physician',
          'approvedAt': '2026-12-01',
        },
      };
      // Topic 1: marked 'approved' WITHOUT reviewer name -> must still be rejected!
      topics[1] = {
        ...topics[1],
        'review': {
          'sourceVerification': 'verified',
          'clinicalApproval': 'approved',
          'reviewer': null,
          'reviewerQualification': null,
          'approvedAt': null,
        },
      };
      decoded['topics'] = topics;

      final bundle = await FirstAidRepository(
        assetBundle: _StringAssetBundle(jsonEncode(decoded)),
      ).loadLibrary(policy: FirstAidReleasePolicy.publicRelease);

      expect(bundle.topics.length, 1);
      expect(bundle.topics.first.id, 'initial-assessment');
      expect(bundle.excludedPendingApprovalCount, 65);
      // Related topics pointing to excluded items are pruned safely
      expect(bundle.topics.first.relatedTopics, isEmpty);
    },
  );

  test('repository handles malformed or missing JSON safely without throwing', () async {
    final malformedBundle = await FirstAidRepository(
      assetBundle: _StringAssetBundle('{not-valid-json'),
    ).loadLibrary(policy: FirstAidReleasePolicy.clinicalReviewDraft);

    expect(malformedBundle.hasLoadError, isTrue);
    expect(malformedBundle.topics, isEmpty);

    final missingBundle = await FirstAidRepository(
      assetBundle: _StringAssetBundle('', shouldThrow: true),
    ).loadLibrary(policy: FirstAidReleasePolicy.clinicalReviewDraft);

    expect(missingBundle.hasLoadError, isTrue);
    expect(missingBundle.topics, isEmpty);
  });
}
