import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resqme/features/medical/screens/tier2_access_screen.dart';
import 'package:resqme/features/medical/services/tier2_authorization_repository.dart';
import 'tier2_test_fakes.dart';

const record = <String, dynamic>{
  'conditions': {'state': 'listed', 'details': 'Fictional condition'},
  'allergies': {'state': 'none_known', 'details': null},
  'primaryContact': {
    'fullName': 'Fictional contact',
    'relationship': 'Parent',
    'phoneNumber': '00000000000',
  },
};

class ScreenRepository extends Tier2AuthorizationRepository {
  ScreenRepository(Tier2Fixture f)
    : super(
        auth: f.auth,
        functions: f.functions,
        keyProvider: f.key,
        expectedProjectId: 'demo-resqme',
      );
  Completer<Map<String, dynamic>> pending = Completer();
  int calls = 0;
  @override
  Future<Map<String, dynamic>> readWithBiometrics() {
    calls++;
    return pending.future;
  }
}

void main() {
  for (final transition in ['background', 'logout', 'switch']) {
    testWidgets('displayed record clears on $transition', (tester) async {
      final f = Tier2Fixture();
      addTearDown(f.auth.changes.close);
      final repo = ScreenRepository(f);
      await tester.pumpWidget(
        MaterialApp(home: Tier2AccessScreen(repository: repo)),
      );
      await tester.tap(find.text('Unlock with biometrics'));
      repo.pending.complete(record);
      await tester.pumpAndSettle();
      expect(find.text('Fictional contact (Parent)'), findsOneWidget);
      await tester.tap(find.text('Medical'));
      await tester.pumpAndSettle();
      expect(find.text('Fictional condition'), findsOneWidget);
      if (transition == 'background') {
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        await tester.pump();
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
      } else {
        f.auth.switchUser(transition == 'logout' ? null : TestUser('adult-b'));
      }
      await tester.pumpAndSettle();
      expect(find.text('Fictional condition'), findsNothing);
      expect(find.text('Fictional contact (Parent)'), findsNothing);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
    });
  }
  testWidgets(
    'inactive prompt transition alone does not invalidate authorization',
    (tester) async {
      final f = Tier2Fixture();
      addTearDown(f.auth.changes.close);
      final repo = ScreenRepository(f);
      await tester.pumpWidget(
        MaterialApp(home: Tier2AccessScreen(repository: repo)),
      );
      await tester.tap(find.text('Unlock with biometrics'));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      repo.pending.complete(record);
      await tester.pumpAndSettle();
      expect(find.text('Fictional contact (Parent)'), findsOneWidget);
      await tester.tap(find.text('Allergies'));
      await tester.pumpAndSettle();
      expect(find.text('KNOWN ALLERGIES'), findsOneWidget);
      await tester.tap(find.text('Medical'));
      await tester.pumpAndSettle();
      expect(find.text('Fictional condition'), findsOneWidget);
      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();
      expect(find.text('HEALTH RECORDS'), findsOneWidget);
    },
  );
  for (final transition in [
    'pause',
    'hidden',
    'logout',
    'switch-back',
    'dispose',
  ]) {
    for (final fail in [false, true]) {
      testWidgets(
        'late ${fail ? 'error' : 'record'} after $transition stays cleared',
        (tester) async {
          final f = Tier2Fixture();
          addTearDown(f.auth.changes.close);
          final repo = ScreenRepository(f);
          await tester.pumpWidget(
            MaterialApp(home: Tier2AccessScreen(repository: repo)),
          );
          await tester.tap(find.text('Unlock with biometrics'));
          await tester.pump();
          if (transition == 'pause' || transition == 'hidden') {
            tester.binding.handleAppLifecycleStateChanged(
              AppLifecycleState.inactive,
            );
            tester.binding.handleAppLifecycleStateChanged(
              AppLifecycleState.hidden,
            );
            if (transition == 'pause') {
              tester.binding.handleAppLifecycleStateChanged(
                AppLifecycleState.paused,
              );
            }
            await tester.pump();
            if (transition == 'pause') {
              tester.binding.handleAppLifecycleStateChanged(
                AppLifecycleState.hidden,
              );
            }
            tester.binding.handleAppLifecycleStateChanged(
              AppLifecycleState.inactive,
            );
            tester.binding.handleAppLifecycleStateChanged(
              AppLifecycleState.resumed,
            );
          } else if (transition == 'logout') {
            f.auth.switchUser(null);
          } else if (transition == 'switch-back') {
            final owner = f.auth.currentUser;
            f.auth.switchUser(TestUser('adult-b'));
            f.auth.switchUser(owner);
          } else {
            await tester.pumpWidget(const MaterialApp(home: SizedBox()));
          }
          await tester.pump();
          if (fail) {
            repo.pending.completeError(
              const Tier2AuthorizationFailure('Fictional late failure'),
            );
          } else {
            repo.pending.complete(record);
          }
          await tester.pumpAndSettle();
          expect(find.text('Fictional condition'), findsNothing);
          expect(find.text('Fictional late failure'), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  testWidgets('lock clears a displayed record and password', (tester) async {
    final f = Tier2Fixture();
    addTearDown(f.auth.changes.close);
    final repo = ScreenRepository(f);
    await tester.pumpWidget(
      MaterialApp(home: Tier2AccessScreen(repository: repo)),
    );
    await tester.enterText(find.byType(TextField), 'fictional-password');
    await tester.tap(find.text('Unlock with biometrics'));
    repo.pending.complete(record);
    await tester.pumpAndSettle();
    expect(find.text('Fictional contact (Parent)'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Lock Tier 2 information'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.text('Lock Tier 2 information'));
    await tester.pump();
    expect(find.text('Fictional contact (Parent)'), findsNothing);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
  });
}
