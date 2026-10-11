import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgershield_my/copy.dart';
import 'package:ledgershield_my/data/models.dart';
import 'package:ledgershield_my/theme/ls_theme.dart';
import 'package:ledgershield_my/widgets/payment_card.dart';

const PoItem _item = PoItem(
  id: 'PO-4500012402-00010',
  vendor: 'V-0188',
  matchType: '3-way',
  exposureUnits: 73.5,
  daysToClearance: 7,
  riskProb: 0.49,
  riskLow: 0.38,
  riskHigh: 0.60,
  riskBand: RiskBand.elevated,
  category: ExceptionCategory.missingGoodsReceipt,
  reason:
      'This flow requires a goods receipt before payment. '
      'No receipt is recorded yet.',
  vendorBaseRate: 0.14,
  whatWouldChange: 'A goods receipt posted before clearance.',
  events: [],
  modelRank: 1,
  outcome: Outcome(exceptionReachedClearance: true, actualExposureUnits: 73.5),
);

/// Pumps one card in a slot of the given size under the app theme.
Future<void> pumpCard(
  WidgetTester tester, {
  required Size slot,
  double textScale = 1.0,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: buildTheme(Brightness.dark),
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(
          body: Center(
            child: SizedBox.fromSize(
              size: slot,
              child: const PaymentCard(item: _item),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('payment card shows the gesture footer when it has room', (
    tester,
  ) async {
    await pumpCard(tester, slot: const Size(600, 900));
    expect(tester.takeException(), isNull);
    expect(find.text(Copy.footerSwipeLeft), findsOneWidget);
    expect(find.text(Copy.footerSwipeUp), findsOneWidget);
    expect(find.text(Copy.footerSwipeRight), findsOneWidget);
    expect(find.text(_item.matchType), findsOneWidget);
  });

  testWidgets('payment card degrades instead of overflowing at large text', (
    tester,
  ) async {
    await pumpCard(tester, slot: const Size(343, 420), textScale: 2.0);
    // No RenderFlex overflow: the card dropped rows and clipped cleanly.
    expect(tester.takeException(), isNull);
    // The lowest-value rows go first; the band word and reason stay.
    expect(find.text(_item.matchType), findsNothing);
    expect(find.text(Copy.footerSwipeLeft), findsNothing);
    expect(find.text(Copy.bandLabel('Elevated', '0.49')), findsOneWidget);
    expect(find.text(_item.reason), findsOneWidget);
  });

  testWidgets('payment card counts wrapped caption rows at mid text scale', (
    tester,
  ) async {
    // At 1.6x the exposure caption and the chip label wrap inside a phone
    // width while a non-scrolling step is still chosen, so the layout model
    // must book those rows at their wrapped height or the column overflows.
    await pumpCard(tester, slot: const Size(343, 560), textScale: 1.6);
    expect(tester.takeException(), isNull);
    expect(find.text(Copy.exposureCaption), findsOneWidget);
    expect(find.text(Copy.bandLabel('Elevated', '0.49')), findsOneWidget);
  });
}
