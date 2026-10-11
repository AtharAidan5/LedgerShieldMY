import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgershield_my/theme/ls_theme.dart';
import 'package:ledgershield_my/widgets/action_bar.dart';

/// Pumps the bar at [width] under the app theme and the given text scale.
Future<void> pumpBar(
  WidgetTester tester, {
  required double width,
  double textScale = 1.0,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: buildTheme(Brightness.dark),
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              child: ActionBar(
                onRelease: () {},
                onEvidence: () {},
                onHold: () {},
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  // The test font draws every glyph one em wide, so "Hold for review" needs
  // 15 em and the widths below are chosen against that, not against Inter.
  testWidgets('action bar keeps one row when the labels fit', (tester) async {
    await pumpBar(tester, width: 1200);
    expect(find.byKey(ActionBar.singleRowKey), findsOneWidget);
    expect(find.byKey(ActionBar.twoRowKey), findsNothing);
    expect(find.text('Hold for review'), findsOneWidget);
  });

  testWidgets('action bar moves to two rows at large text', (tester) async {
    await pumpBar(tester, width: 600, textScale: 1.3);
    expect(find.byKey(ActionBar.singleRowKey), findsNothing);
    expect(find.byKey(ActionBar.twoRowKey), findsOneWidget);
    // Every label is still present in full, never truncated.
    expect(find.text('Release'), findsOneWidget);
    expect(find.text('Evidence'), findsOneWidget);
    expect(find.text('Hold for review'), findsOneWidget);
  });

  testWidgets('action bar falls back to three rows when even a pair is too '
      'wide', (tester) async {
    await pumpBar(tester, width: 343, textScale: 2.0);
    expect(find.byKey(ActionBar.threeRowKey), findsOneWidget);
    expect(find.text('Hold for review'), findsOneWidget);
  });
}
