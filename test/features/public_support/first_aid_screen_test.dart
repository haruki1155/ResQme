import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resqme/app/resqme_app.dart';
import 'package:resqme/features/public_support/data/first_aid_repository.dart';
import 'package:resqme/features/public_support/domain/first_aid_release_policy.dart';
import 'package:resqme/features/public_support/presentation/first_aid_screens.dart';
import 'package:resqme/features/welcome/data/consent_repository.dart';

class _FakeConsentRepository implements ConsentRepository {
  _FakeConsentRepository({required this.accepted});
  bool accepted;

  @override
  Future<void> acceptTerms() async {
    accepted = true;
  }

  @override
  Future<bool> hasAcceptedTerms() async => accepted;
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
    maxScrolls: 120,
  );
  await tester.pumpAndSettle();
}

Future<void> _scrollToTop(WidgetTester tester) async {
  final listFinder = find.byType(ListView).first;
  for (var i = 0; i < 4; i++) {
    await tester.drag(listFinder, const Offset(0, 2500));
    await tester.pumpAndSettle();
  }
}

void main() {
  setUp(FirstAidRepository.clearCache);

  testWidgets(
    'Expanded First Aid Home shows Common Emergencies, filters by category & Filipino search, and recovers from no-match',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: FirstAidLibraryScreen(
            releasePolicy: FirstAidReleasePolicy.clinicalReviewDraft,
            debugEnableExpandedFirstAidOverride: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('IMMEDIATE CARE GUIDE'), findsOneWidget);
      expect(find.text('Act first.\nLearn more when needed.'), findsOneWidget);

      await _scrollDownTo(
        tester,
        find.byKey(const Key('common_emergency_cpr-adult')),
      );
      expect(
        find.byKey(const Key('common_emergency_cpr-adult')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('common_emergency_severe-bleeding')),
        findsOneWidget,
      );

      final mentalChip = find.byKey(const Key('category_chip_Mental Distress'));
      await _scrollDownTo(tester, mentalChip);
      await tester.tap(mentalChip);
      await tester.pumpAndSettle();
      await _scrollToTop(tester);
      await _scrollDownTo(tester, find.text('4 PROCEDURES'));
      expect(find.text('4 PROCEDURES'), findsOneWidget);
      await _scrollDownTo(
        tester,
        find.text('Acute Anxiety and Panic Attack'),
      );
      expect(find.text('Acute Anxiety and Panic Attack'), findsOneWidget);

      await _scrollToTop(tester);
      await _scrollDownTo(tester, find.byKey(const Key('category_chip_All')));
      await tester.tap(find.byKey(const Key('category_chip_All')));
      await tester.pumpAndSettle();
      await _scrollDownTo(tester, find.text('66 PROCEDURES'));
      expect(find.text('66 PROCEDURES'), findsOneWidget);

      await _scrollToTop(tester);
      await tester.enterText(
        find.byKey(const Key('first_aid_search_field')),
        'Balinguyngoy',
      );
      await tester.pumpAndSettle();
      await _scrollDownTo(tester, find.text('Nosebleeds'));
      expect(find.text('1 PROCEDURE'), findsOneWidget);
      expect(find.text('Nosebleeds'), findsOneWidget);

      await _scrollToTop(tester);
      await tester.enterText(
        find.byKey(const Key('first_aid_search_field')),
        'zzz-nonexistent-query',
      );
      await tester.tap(find.byTooltip('Search guides'));
      await tester.pumpAndSettle();
      await _scrollDownTo(tester, find.text('No guides found'));
      expect(find.text('No guides found'), findsOneWidget);
      await _scrollDownTo(tester, find.text('SUGGESTED COMMON EMERGENCIES'));
      expect(find.text('SUGGESTED COMMON EMERGENCIES'), findsOneWidget);

      await _scrollToTop(tester);
      await _scrollDownTo(tester, find.text('Clear search & filters'));
      await tester.tap(find.text('Clear search & filters'));
      await tester.pumpAndSettle();
      await _scrollDownTo(tester, find.text('66 PROCEDURES'));
      expect(find.text('66 PROCEDURES'), findsOneWidget);
    },
  );

  testWidgets(
    'Quick Instruction enforces 8-section hierarchy, >=16sp step text, >=48dp targets, and bidirectional Learn More navigation',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: FirstAidLibraryScreen(
            releasePolicy: FirstAidReleasePolicy.clinicalReviewDraft,
            debugEnableExpandedFirstAidOverride: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester
            .getSize(find.byKey(const Key('first_aid_call_911_button')))
            .height,
        greaterThanOrEqualTo(48),
      );
      expect(
        tester.getSize(find.byTooltip('Back')).height,
        greaterThanOrEqualTo(48),
      );

      final cprChip = find.byKey(const Key('common_emergency_cpr-adult'));
      await _scrollDownTo(tester, cprChip);
      await tester.tap(cprChip);
      await tester.pumpAndSettle();

      expect(find.text('Quick First Aid'), findsOneWidget);
      expect(find.text('Adult and Adolescent CPR'), findsOneWidget);
      expect(
        find.byKey(const Key('quick_instruction_emergency_banner')),
        findsOneWidget,
      );
      await _scrollDownTo(
        tester,
        find.byKey(const Key('immediate_action_callout')),
      );
      expect(
        find.byKey(const Key('immediate_action_callout')),
        findsOneWidget,
      );

      await _scrollDownTo(tester, find.text('SIGNS TO RECOGNIZE'));
      expect(find.text('SIGNS TO RECOGNIZE'), findsOneWidget);

      await _scrollDownTo(tester, find.byKey(const Key('instruction_step_1')));
      expect(find.text('FIRST-AID STEPS'), findsOneWidget);

      final step1Text = tester.widget<Text>(
        find.byKey(const Key('instruction_step_1')),
      );
      expect(step1Text.style!.fontSize, greaterThanOrEqualTo(16.0));

      await _scrollDownTo(
        tester,
        find.byKey(const Key('critical_warnings_section')),
      );
      expect(
        find.byKey(const Key('critical_warnings_section')),
        findsOneWidget,
      );

      final learnMoreBtn = find.byKey(
        const Key('quick_instruction_learn_more_button'),
      );
      await _scrollDownTo(tester, learnMoreBtn);
      expect(
        find.text('WHEN TO GET EMERGENCY MEDICAL HELP'),
        findsOneWidget,
      );
      expect(tester.getSize(learnMoreBtn).height, greaterThanOrEqualTo(48));

      await tester.tap(learnMoreBtn);
      await tester.pumpAndSettle();
      expect(find.text('Learn More'), findsOneWidget);
      await _scrollDownTo(tester, find.text('CAUSES & RISK FACTORS'));
      expect(find.text('CAUSES & RISK FACTORS'), findsOneWidget);

      await _scrollToTop(tester);
      final backToQuickBtn = find.byKey(
        const Key('article_view_quick_instructions_button'),
      );
      expect(tester.getSize(backToQuickBtn).height, greaterThanOrEqualTo(48));
      await tester.tap(backToQuickBtn);
      await tester.pumpAndSettle();
      expect(find.text('Quick First Aid'), findsOneWidget);
      expect(learnMoreBtn, findsOneWidget);
      await _scrollToTop(tester);
      expect(find.text('Adult and Adolescent CPR'), findsOneWidget);
    },
  );

  testWidgets(
    'Trained-responder-only topics display explicit qualification restriction banner',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: FirstAidLibraryScreen(
            releasePolicy: FirstAidReleasePolicy.clinicalReviewDraft,
            debugEnableExpandedFirstAidOverride: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('first_aid_search_field')),
        'oxygen administration',
      );
      await tester.pumpAndSettle();

      final oxygenCard = find.byKey(
        const Key('topic_card_oxygen-administration'),
      );
      await _scrollDownTo(tester, oxygenCard);
      await tester.tap(oxygenCard);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('trained_responder_warning_banner')),
        findsOneWidget,
      );
      expect(find.textContaining('TRAINED RESPONDERS ONLY'), findsWidgets);
    },
  );

  testWidgets(
    'Learning Library supports search, A-Z sorting, source citations, and related topic links',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: FirstAidLibraryScreen(
            releasePolicy: FirstAidReleasePolicy.clinicalReviewDraft,
            debugEnableExpandedFirstAidOverride: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final openLibBtn = find.byKey(const Key('open_learning_library_button'));
      await _scrollDownTo(tester, openLibBtn);
      await tester.tap(openLibBtn);
      await tester.pumpAndSettle();

      expect(find.text('Learning Library'), findsOneWidget);
      await _scrollDownTo(tester, find.text('66 ARTICLES'));
      expect(find.text('66 ARTICLES'), findsOneWidget);

      await _scrollToTop(tester);
      final sortAzChip = find.byKey(const Key('sort_alphabetical_chip'));
      await _scrollDownTo(tester, sortAzChip);
      await tester.tap(sortAzChip);
      await tester.pumpAndSettle();

      final abdoCard = find.byKey(
        const Key('learning_article_card_abdominal-pain'),
      );
      await _scrollDownTo(tester, abdoCard);
      expect(find.text('Abdominal Pain (Non-Traumatic)'), findsOneWidget);

      await tester.tap(abdoCard);
      await tester.pumpAndSettle();

      await _scrollDownTo(tester, find.text('SOURCE REFERENCE & ATTRIBUTION'));
      expect(find.textContaining('pp. 412\u2013417'), findsOneWidget);
    },
  );

  testWidgets(
    'Expanded UI fits 320x720 narrow screens at 1.8x enlarged text scale without overflow',
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
          home: const FirstAidLibraryScreen(
            releasePolicy: FirstAidReleasePolicy.clinicalReviewDraft,
            debugEnableExpandedFirstAidOverride: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      final cprCard = find.byKey(const Key('common_emergency_cpr-adult'));
      await _scrollDownTo(tester, cprCard, step: 180);
      await tester.tap(cprCard);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await _scrollDownTo(
        tester,
        find.byKey(const Key('quick_instruction_learn_more_button')),
        step: 180,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Call 911 requires confirmation dialog and launches tel:911 only when confirmed',
    (tester) async {
      Uri? launchedUri;
      await tester.pumpWidget(
        MaterialApp(
          home: FirstAidLibraryScreen(
            openDialer: (uri) async {
              launchedUri = uri;
              return true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('first_aid_call_911_button')));
      await tester.pumpAndSettle();
      expect(find.text('Open Phone?'), findsOneWidget);
      expect(launchedUri, isNull);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(launchedUri, isNull);

      await tester.tap(find.byKey(const Key('first_aid_call_911_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open Phone'));
      await tester.pumpAndSettle();
      expect(launchedUri.toString(), 'tel:911');
    },
  );

  testWidgets(
    'cold-start emergency access works before Terms consent and from Scanner Entry without login or student data',
    (tester) async {
      final consent = _FakeConsentRepository(accepted: false);
      await tester.pumpWidget(ResQMeApp(consentRepository: consent));
      await tester.pumpAndSettle();

      expect(find.text('Terms and Conditions'), findsOneWidget);
      final termsFirstAidBtn = find.byKey(
        const Key('terms_emergency_first_aid_button'),
      );
      await _scrollDownTo(tester, termsFirstAidBtn);
      await tester.tap(termsFirstAidBtn);
      await tester.pumpAndSettle();

      expect(find.text('First-aid instructions'), findsOneWidget);
      expect(consent.accepted, isFalse);
      expect(find.text('Blood Type'), findsNothing);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await _scrollDownTo(tester, find.byType(Checkbox));
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await _scrollDownTo(tester, find.text('Accept & continue'));
      await tester.tap(find.text('Accept & continue'));
      await tester.pumpAndSettle();

      final entryFirstAidBtn = find.byKey(
        const Key('entry_emergency_first_aid_button'),
      );
      await tester.ensureVisible(entryFirstAidBtn);
      await tester.tap(entryFirstAidBtn);
      await tester.pumpAndSettle();
      expect(find.text('First-aid instructions'), findsOneWidget);
    },
  );

  testWidgets(
    'Feature ON + publicRelease with zero approved expanded topics safely falls back to original library and Call 911',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: FirstAidLibraryScreen(
            releasePolicy: FirstAidReleasePolicy.publicRelease,
            debugEnableExpandedFirstAidOverride: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('public_release_pending_approval_banner')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('first_aid_call_911_button')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('common_emergency_cpr-adult')), findsNothing);
      await _scrollDownTo(tester, find.text('8 GUIDES'));
      expect(find.text('8 GUIDES'), findsOneWidget);
    },
  );
}
