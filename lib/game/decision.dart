/// The decision a reviewer (or the lock rule) takes on one card, and the
/// audit row that records it.
library;

enum Decision { hold, release, autoRelease, escalate }

enum DecisionSource { swipe, button, sheet, auto }

class AuditEntry {
  const AuditEntry({
    required this.at,
    required this.itemId,
    required this.vendor,
    required this.decision,
    required this.source,
    required this.reason,
    required this.cardIndex,
  });

  final DateTime at;
  final String itemId;
  final String vendor;
  final Decision decision;
  final DecisionSource source;
  final String reason;

  /// Zero-based position of the item in the session order.
  final int cardIndex;

  @override
  String toString() =>
      'AuditEntry($itemId, ${decision.name}, ${source.name}, card $cardIndex)';
}
