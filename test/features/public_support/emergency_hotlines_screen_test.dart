import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:resqme/features/public_support/presentation/emergency_hotlines_screen.dart';

void main() {
  testWidgets('agency cards use compact titles and relevant descriptions', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: EmergencyHotlinesScreen()));
    await tester.scrollUntilVisible(find.text('CDRRMO / EMS'), 250);
    expect(find.text('City disaster and medical rescue'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('PNP'), 250);
    expect(find.text('Urdaneta City police assistance'), findsOneWidget);
  });

  testWidgets('hotline cards fit a narrow screen with enlarged text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
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
        home: const EmergencyHotlinesScreen(),
      ),
    );
    await tester.scrollUntilVisible(find.text('02 8911 5061'), 250);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mockup emergency action retains confirmation', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: EmergencyHotlinesScreen(
          openDialer: (_) async {
            calls++;
            return true;
          },
        ),
      ),
    );
    expect(find.text('IF LIFE IS IN DANGER'), findsOneWidget);
    expect(find.text('Call 911 now'), findsOneWidget);
    expect(find.text('PHILIPPINES DIRECTORY'), findsOneWidget);
    await tester.tap(find.text('Call 911'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(calls, 0);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(calls, 0);
  });

  testWidgets('directory contains every supplied hotline number', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: EmergencyHotlinesScreen()));
    for (final number in const [
      '911',
      '0917 818 5374',
      '0917 159 1545',
      '0920 369 9876',
      '0916 226 3641',
      '0998 598 5133',
      '0917 184 4611',
      '075 568 6114',
      '0975 632 6248',
      '143',
      '02 8527 8385',
      '02 8911 5061',
    ]) {
      await tester.scrollUntilVisible(find.text(number), 250);
      expect(find.text(number), findsOneWidget);
    }
  });

  testWidgets('confirmation and cancel never open the dialer', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: EmergencyHotlinesScreen(
          openDialer: (_) async {
            calls++;
            return true;
          },
        ),
      ),
    );
    await tester.tap(find.text('911'));
    await tester.tap(find.text('911'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(
      find.textContaining('No call is placed automatically'),
      findsOneWidget,
    );
    expect(calls, 0);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('confirmation opens only the selected normalized telephone URI', (
    tester,
  ) async {
    final launched = <Uri>[];
    await tester.pumpWidget(
      MaterialApp(
        home: EmergencyHotlinesScreen(
          openDialer: (uri) async {
            launched.add(uri);
            return true;
          },
        ),
      ),
    );
    await tester.scrollUntilVisible(find.text('0917 818 5374'), 250);
    await tester.tap(find.text('0917 818 5374'));
    await tester.pumpAndSettle();
    expect(launched, isEmpty);
    await tester.tap(find.text('Open Phone'));
    await tester.pumpAndSettle();
    expect(launched, [Uri(scheme: 'tel', path: '09178185374')]);
  });

  for (final throws in [false, true]) {
    testWidgets('dialer ${throws ? 'exception' : 'failure'} shows recovery', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: EmergencyHotlinesScreen(
            openDialer: (_) async {
              if (throws) throw StateError('No phone activity');
              return false;
            },
          ),
        ),
      );
      await tester.tap(find.text('911'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open Phone'));
      await tester.pumpAndSettle();
      expect(
        find.text('Unable to open the Phone app. You can dial 911 manually.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('extension is explained but never automatically dialed', (
    tester,
  ) async {
    Uri? launched;
    await tester.pumpWidget(
      MaterialApp(
        home: EmergencyHotlinesScreen(
          openDialer: (uri) async {
            launched = uri;
            return true;
          },
        ),
      ),
    );
    await tester.scrollUntilVisible(find.text('02 8911 5061'), 350);
    await tester.drag(find.byType(ListView).first, const Offset(0, -140));
    await tester.pumpAndSettle();
    expect(find.textContaining('extension 100'), findsOneWidget);
    await tester.tap(find.text('02 8911 5061'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.textContaining('extension 100'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Open Phone'));
    await tester.pumpAndSettle();
    expect(launched, Uri(scheme: 'tel', path: '0289115061'));
  });
}
