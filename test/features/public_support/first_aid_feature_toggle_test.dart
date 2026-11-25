import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resqme/core/config/first_aid_feature_flags.dart';
import 'package:resqme/features/public_support/data/first_aid_repository.dart';
import 'package:resqme/features/public_support/domain/first_aid_release_policy.dart';
import 'package:resqme/features/public_support/presentation/emergency_hotlines_screen.dart';
import 'package:resqme/features/public_support/presentation/first_aid_screens.dart';

class _StringAssetBundle extends CachingAssetBundle {
  _StringAssetBundle(this.payload);
  final String payload;

  @override
  Future<ByteData> load(String key) async {
    final bytes = Uint8List.fromList(utf8.encode(payload));
    return ByteData.view(bytes.buffer);
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) =>
      SynchronousFuture<String>(payload);
}

Future<void> _scrollDownTo(
  WidgetTester tester,
  Finder target, {
  double step = 200,
}) async {
  await tester.scrollUntilVisible(
    target,
    step,
    scrollable: find.byType(Scrollable).first,
    maxScrolls: 100,
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(FirstAidRepository.clearCache);

  group('Feature OFF (Default FirstAidFeatureFlags.enableExpandedFirstAid == false)', () {
    test('centralized feature flag defaults to false', () {
      expect(FirstAidFeatureFlags.enableExpandedFirstAid, isFalse);
      expect(eligibleOriginalFirstAidGuides.length, 8);
      expect(withheldOriginalFirstAidGuides.length, 2);
      expect(
        withheldOriginalFirstAidGuides.map((g) => g.title),
        containsAll(['Asthma', 'Moving an injured person']),
      );
    });

    testWidgets(
      'displays restored original First Aid home, loads eligible guides, hides expanded IFRC & Learning Library, and blocks search leaks',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: FirstAidLibraryScreen()),
        );
        await tester.pumpAndSettle();

        // Restored original header & layout
        expect(find.text('First-aid instructions'), findsOneWidget);
        expect(find.text('IMMEDIATE CARE GUIDE'), findsOneWidget);
        expect(find.text('What do you need\nhelp with?'), findsOneWidget);

        // Expanded IFRC UI and Learning Library entry points are completely absent
        expect(
          find.text('Act first.\nLearn more when needed.'),
          findsNothing,
        );
        expect(
          find.byKey(const Key('open_learning_library_button')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('common_emergency_cpr-adult')),
          findsNothing,
        );

        await _scrollDownTo(tester, find.text('8 GUIDES'));
        expect(find.text('8 GUIDES'), findsOneWidget);

        // Withheld original instructions do not appear
        expect(find.text('Asthma'), findsNothing);
        expect(find.text('Moving an injured person'), findsNothing);

        // Category filter menu works on original guides
        await tester.tap(find.byTooltip('Filter guides'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.widgetWithText(CheckedPopupMenuItem<String>, 'Bleeding & wounds'),
        );
        await tester.pumpAndSettle();
        expect(find.text('2 GUIDES'), findsOneWidget);
        expect(find.text('Nosebleed'), findsOneWidget);
        expect(find.text('Bleeding and wound care'), findsOneWidget);

        // Search cannot expose expanded IFRC procedures or withheld guides
        for (final blockedQuery in const [
          'Decompression illness',
          'Suicidal ideation',
          'Balinguyngoy',
          'Asthma',
          'Moving an injured person',
        ]) {
          await tester.enterText(
            find.byKey(const Key('original_first_aid_search_field')),
            blockedQuery,
          );
          await tester.tap(find.byTooltip('Search guides'));
          await tester.pumpAndSettle();
          expect(
            find.text('No guides found'),
            findsOneWidget,
            reason: 'Blocked query "$blockedQuery" must return no matches',
          );
        }

        // Clear search & open an eligible original full guide
        await tester.tap(find.text('Clear search & filters'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('original_first_aid_search_field')),
          'nosebleed',
        );
        await tester.pumpAndSettle();
        expect(find.text('Nosebleed'), findsOneWidget);
        await tester.tap(find.text('Nosebleed'));
        await tester.pumpAndSettle();
        await _scrollDownTo(tester, find.text('Open full guide'));
        await tester.tap(find.text('Open full guide'));
        await tester.pumpAndSettle();
        expect(find.text('Instruction image'), findsOneWidget);
        expect(find.textContaining('Pinch the soft part'), findsOneWidget);
      },
    );

    testWidgets(
      'direct navigation cannot bypass feature flag or withheld-guide gate, while Call 911 and Hotlines stay active',
      (tester) async {
        final bundle = FirstAidRepository().tryLoadLibrarySync(
          policy: FirstAidReleasePolicy.clinicalReviewDraft,
        )!;
        final cprTopic = bundle.topicById('cpr-adult')!;

        // 1. Direct push to FirstAidQuickInstructionScreen with default flag (false)
        await tester.pumpWidget(
          MaterialApp(
            home: FirstAidQuickInstructionScreen(
              topic: cprTopic,
              bundle: bundle,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('restricted_first_aid_guard_banner')),
          findsOneWidget,
        );
        expect(find.text('Adult and Adolescent CPR'), findsNothing);
        expect(find.byKey(const Key('guard_call_911_button')), findsOneWidget);

        // 2. Direct push to FirstAidLearningLibraryScreen with default flag (false)
        await tester.pumpWidget(
          MaterialApp(home: FirstAidLearningLibraryScreen(bundle: bundle)),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('restricted_first_aid_guard_banner')),
          findsOneWidget,
        );
        expect(find.text('66 ARTICLES'), findsNothing);

        // 3. Direct push to FirstAidArticleScreen with default flag (false)
        await tester.pumpWidget(
          MaterialApp(
            home: FirstAidArticleScreen(topic: cprTopic, bundle: bundle),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('restricted_first_aid_guard_banner')),
          findsOneWidget,
        );
        expect(find.text('CAUSES & RISK FACTORS'), findsNothing);

        // 4. Direct push to FirstAidDetailScreen with a withheld legacy guide
        final withheldAsthma = withheldOriginalFirstAidGuides.first;
        await tester.pumpWidget(
          MaterialApp(home: FirstAidDetailScreen(guide: withheldAsthma)),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('restricted_first_aid_guard_banner')),
          findsOneWidget,
        );
        expect(find.textContaining('blue/grey reliever'), findsNothing);

        // 5. Emergency Hotlines navigation remains operational from Original Home
        await tester.pumpWidget(
          const MaterialApp(home: FirstAidLibraryScreen()),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('first_aid_hotlines_button')));
        await tester.pumpAndSettle();
        expect(find.byType(EmergencyHotlinesScreen), findsOneWidget);
      },
    );

    testWidgets(
      'restored Original First Aid fits 320x720 narrow screens at 1.8x enlarged text scale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 720);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.8)),
              child: child!,
            ),
            home: const FirstAidLibraryScreen(),
          ),
        );
        await tester.pumpAndSettle();
        await _scrollDownTo(tester, find.text('Open full guide'), step: 220);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('Feature ON + FirstAidReleasePolicy enforcement', () {
    testWidgets(
      'shows ONLY clinically approved expanded procedures in publicRelease and withholds unapproved topics across Home, Search, Learning Library, and direct navigation',
      (tester) async {
        final raw = File(
          FirstAidRepository.defaultAssetPath,
        ).readAsStringSync();
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        final topics = List<Map<String, dynamic>>.from(
          decoded['topics'] as List,
        );

        // Approve ONLY 'cpr-adult' and 'nosebleeds'; leave the remaining 64 pending.
        for (var i = 0; i < topics.length; i++) {
          final id = topics[i]['id'] as String;
          if (id == 'cpr-adult' || id == 'nosebleeds') {
            topics[i] = {
              ...topics[i],
              'review': {
                'sourceVerification': 'verified',
                'clinicalApproval': 'approved',
                'reviewer': 'Dr. Test Clinician, MD',
                'reviewerQualification': 'Emergency Medicine',
                'approvedAt': '2026-12-01',
              },
            };
          }
        }
        decoded['topics'] = topics;

        final testRepo = FirstAidRepository(
          assetBundle: _StringAssetBundle(jsonEncode(decoded)),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: FirstAidLibraryScreen(
              repository: testRepo,
              releasePolicy: FirstAidReleasePolicy.publicRelease,
              debugEnableExpandedFirstAidOverride: true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('Act first.\nLearn more when needed.'),
          findsOneWidget,
        );
        await _scrollDownTo(tester, find.text('2 PROCEDURES'));
        expect(find.text('2 PROCEDURES'), findsOneWidget);

        // Filipino search works for approved 'Nosebleeds' ('Balinguyngoy')
        await tester.drag(
          find.byType(ListView).first,
          const Offset(0, 2000),
        );
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('first_aid_search_field')),
          'Balinguyngoy',
        );
        await tester.pumpAndSettle();
        await _scrollDownTo(tester, find.text('Nosebleeds'));
        expect(find.text('Nosebleeds'), findsOneWidget);

        // Search for unapproved 'Heatstroke' returns nothing
        await tester.drag(
          find.byType(ListView).first,
          const Offset(0, 2000),
        );
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('first_aid_search_field')),
          'Heatstroke',
        );
        await tester.pumpAndSettle();
        await _scrollDownTo(tester, find.text('No guides found'));
        expect(find.text('No guides found'), findsOneWidget);

        // Direct navigation to an unapproved topic under publicRelease is blocked
        final fullDraftBundle = FirstAidRepository().tryLoadLibrarySync(
          policy: FirstAidReleasePolicy.clinicalReviewDraft,
        )!;
        final unapprovedHeatstroke = fullDraftBundle.topicById('heatstroke')!;
        await tester.pumpWidget(
          MaterialApp(
            home: FirstAidQuickInstructionScreen(
              topic: unapprovedHeatstroke,
              bundle: fullDraftBundle,
              releasePolicy: FirstAidReleasePolicy.publicRelease,
              debugEnableExpandedFirstAidOverride: true,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('restricted_first_aid_guard_banner')),
          findsOneWidget,
        );
        expect(find.textContaining('Immerse neck-down'), findsNothing);
      },
    );
  });
}
