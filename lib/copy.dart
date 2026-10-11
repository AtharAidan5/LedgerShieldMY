import 'data/models.dart';

/// Every user-facing string in the app lives here, so the spec's copy rules
/// (exposure units rather than a currency, "unresolved exception" and
/// "protected exposure (simulated)" wording, "goods receipt" spelled out)
/// can be enforced by one scan in test/copy_rules_test.dart.
class Copy {
  const Copy._();

  // Brand and framing.
  static const String wordmark = 'LedgerShield MY';
  static const String tagline =
      'MyInvois proves the invoice is real. LedgerShield tells you whether to pay it yet.';

  static String opening(int pending, int k) =>
      '$pending payments pending. You have $k review slots.';
  static const String openingHint =
      'Each hold uses one slot. Released cards are paid as-is.';
  static const String wordmarkHint =
      'Long press to switch between dark and light.';

  // Stack screen.
  static String slots(int used, int k) => 'Review slots $used/$k';
  static String cardCounter(int n, int total) => 'Card $n of $total';
  static const String lockSlotsFull = 'Slots full. Remaining cards released.';
  static const String lockAllReviewed = 'All cards reviewed.';
  static const String buttonRelease = 'Release';
  static const String buttonEvidence = 'Evidence';
  static const String buttonHold = 'Hold for review';
  static const String hintRelease = 'Release';
  static const String hintHold = 'Hold';
  static const String hintEvidence = 'Evidence';
  static const String howItWorksTooltip = 'How this works';
  static const String loading = 'Loading batch';

  // Gesture hints in the payment card footer.
  static const String footerSwipeLeft = 'Release';
  static const String footerSwipeUp = 'Evidence';
  static const String footerSwipeRight = 'Hold';

  // Screen-reader labels. These are spoken, never drawn.
  static String cardSemantics({
    required String vendor,
    required String exposure,
    required String band,
    required String prob,
    required String category,
    required String reason,
    required int n,
    required int total,
  }) =>
      'Vendor $vendor, $exposure exposure units, $band, $prob, $category. '
      '$reason ${cardCounter(n, total)}.';
  static const String cardSemanticsHint =
      'Swipe left to release, swipe right to hold, swipe up or double tap '
      'for evidence. The buttons below do the same.';
  static String tileSemantics({
    required String vendor,
    required String exposure,
    required String outcome,
    required bool yourPick,
    required bool modelPick,
  }) {
    final who = yourPick && modelPick
        ? ', picked by you and LedgerShield'
        : yourPick
        ? ', picked by you'
        : modelPick
        ? ', picked by LedgerShield'
        : '';
    return 'Vendor $vendor, $exposure units, $outcome$who';
  }

  static String labelledValue(String label, String value) => '$label, $value';

  // Payment card.
  static String vendorLabel(String vendor) => 'Vendor $vendor';
  static const String exposureCaption = 'exposure units, at risk if paid as-is';
  static String clearsIn(int days) =>
      days == 1 ? 'Clears in 1 day' : 'Clears in $days days';
  static String bandLabel(String band, String prob) => '$band, $prob';
  static String probRange(String low, String high) => '$low to $high';

  // Decision reasons written to the audit log.
  static const String holdReason = 'Held for review.';
  static const String releaseReason = 'Released without review.';
  static const String escalateReason =
      'Insufficient evidence. Escalated for review.';
  static const String autoReleaseReason =
      'Released automatically when the review slots filled.';
  static const String holdReceivingReason =
      'Held pending receiving confirmation.';

  // Evidence sheet.
  static String evidenceTitle(String vendor) => 'Evidence trail, $vendor';
  static String notRecorded(String label) => '$label: not recorded';
  static String vendorBaseRate(String pct) =>
      'This vendor: $pct of past items cleared with an exception';
  static const String whatWouldChangeLabel = 'What would change this';
  static const String recommendedActionLabel = 'Recommended action';
  static const String sheetHold = 'Hold and request receiving confirmation';
  static const String sheetRelease = 'Release';
  static const String sheetEscalate = 'Insufficient evidence, escalate';
  static const String sheetFooter =
      'Human approval required. Decision is logged.';

  static String recommendedAction(ExceptionCategory c) => switch (c) {
    ExceptionCategory.missingGoodsReceipt =>
      'Hold until the goods receipt is posted.',
    ExceptionCategory.amountMismatch =>
      'Hold and confirm the invoice value against the goods receipt.',
    ExceptionCategory.processPath =>
      'Hold and confirm the receipt-first flow was followed.',
    ExceptionCategory.insufficientEvidence =>
      'Release, or escalate if the invoice is still missing.',
  };

  // Reveal screen.
  static String headlineSameReviews(int yours, int model, int k) =>
      'You caught $yours. LedgerShield caught $model. Same $k reviews.';
  static String headlineFewerHolds(int yours, int holds, int model, int k) =>
      'You caught $yours with $holds holds. LedgerShield caught $model with $k.';
  static String yourPicksTitle(int n) => 'Your $n';
  static String modelPicksTitle(int k) => "LedgerShield's $k";
  static const String whatActuallyHappened = 'What actually happened';
  static const String exception = 'Exception';
  static const String fine = 'Fine';
  static const String markerYou = 'You';
  static const String markerModel = 'LS';
  static String exceptionsCaught(int caught, int of) =>
      'Exceptions caught: $caught of $of';
  static String protectedExposure(String units) =>
      'Protected exposure (simulated): $units units';
  static const String disagreementTitle =
      'Where you and LedgerShield disagreed most';
  static const String samePicks = 'You and LedgerShield chose the same five.';
  static String rankedThis(int rank, int total) =>
      'LedgerShield ranked this #$rank of $total.';
  static const String rankWeighsHistory =
      'The rank weighs vendor history as well as exposure and probability.';
  static const String outcomeException =
      'Outcome: an unresolved exception reached clearance.';
  static const String outcomeFine = 'Outcome: cleared without an exception.';
  static const String sideModelOnly = 'LedgerShield held it. You released it.';
  static const String sidePlayerOnly = 'You held it. LedgerShield released it.';
  static const String seeProof = 'See the proof';
  static const String playAgain = 'Play again';
  static const String auditLog = 'Audit log';

  // Proof receipt.
  static const String proofTitle = 'Held-out test, same review capacity.';
  static String kPerDay(int k) => 'K = $k reviews per day';
  static const String placeholder = 'PLACEHOLDER';
  static const String placeholderBanner =
      'PLACEHOLDER DATA, replace the proof block in batch.json';
  static const String proofSectionShare = 'Share of future exceptions surfaced';
  static const String proofSectionHeldout =
      'Vendor held-out (unfamiliar vendors)';
  static const String statPrecision = 'precision@K';
  static const String statExposureRecall = 'exposure-recall@K';
  static const String statMedianDays = 'median days of warning before payment';
  static const String notAvailableForVariant = 'n/a for this variant';
  static const String chipVendorHeldout = 'Vendor held-out';
  static const String smallPrint =
      'Held-out later period. Forward-time split. Grouped by purchase order. '
      'Values are transformed exposure units, not currency. '
      'Rule-derived exceptions are proxy outcomes, not confirmed losses. '
      'Held-out replay validates the forecasts; it does not prove real-world results. '
      'A human approves every action and the decision is logged.';
  static const String backToReveal = 'Back to reveal';

  // Audit log.
  static const String auditTitle = 'Audit log';
  static const String auditHeader = sheetFooter;
  static const String auditEmpty = 'No decisions logged yet.';
  static const String decisionHeld = 'Held';
  static const String decisionReleased = 'Released';
  static const String decisionAutoReleased = 'Auto-released';
  static const String decisionEscalated = 'Escalated';
  static const String sourceSwipe = 'swipe';
  static const String sourceButton = 'button';
  static const String sourceSheet = 'evidence sheet';
  static const String sourceAuto = 'auto';

  // How this works dialog.
  static const String howTitle = 'How this works';
  static const String howSentence1 =
      'LedgerShield scores each pending purchase-order item 14 days after it is created.';
  static const String howSentence2 =
      'It ranks the items most likely to reach payment with an unresolved exception, '
      'for a fixed number of reviews, weighing vendor history as well as exposure.';
  static const String howSentence3 =
      'A human approves every hold or release, and each decision is logged.';
  static const String gotIt = 'Got it';

  // Error view.
  static const String errorTitle = 'Could not load the batch.';
  static const String retry = 'Retry';
}
