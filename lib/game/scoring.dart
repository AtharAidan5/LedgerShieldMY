/// Pure scoring functions for the Reveal. No Flutter imports, so the
/// controller tests and any future CLI check can run them on plain Dart.
library;

import '../copy.dart';
import '../data/models.dart';
import '../util/format.dart';

enum DisagreementSide { modelOnly, playerOnly }

class Disagreement {
  const Disagreement({
    required this.item,
    required this.side,
    required this.why,
  });

  final PoItem item;
  final DisagreementSide side;
  final String why;
}

/// Picks whose outcome turned out to be an unresolved exception.
int caughtCount(Iterable<PoItem> picks) =>
    picks.where((p) => p.outcome.exceptionReachedClearance).length;

/// Sum of the actual exposure over caught picks, shown as
/// "Protected exposure (simulated)".
double exposureProtected(Iterable<PoItem> picks) => picks
    .where((p) => p.outcome.exceptionReachedClearance)
    .fold(0.0, (sum, p) => sum + p.outcome.actualExposureUnits);

/// One-based position of [item] when [session] is sorted by exposure
/// descending; a proxy for how obvious the item looked. Returns 0 when the
/// item is not in the session.
int exposureRank(List<PoItem> session, PoItem item) {
  final sorted = [...session]
    ..sort((a, b) => b.exposureUnits.compareTo(a.exposureUnits));
  final index = sorted.indexWhere((p) => p.id == item.id);
  return index < 0 ? 0 : index + 1;
}

/// The model's picks: the [k] lowest model ranks in [session].
List<PoItem> modelPicksOf(List<PoItem> session, int k) {
  final sorted = [...session]
    ..sort((a, b) => a.modelRank.compareTo(b.modelRank));
  return List.unmodifiable(sorted.take(k));
}

/// The one card the Reveal calls out. The ladder prefers the model-only pick
/// that looked least alarming yet turned out to be an exception, then the
/// player-only hold the model thought least worth a slot, then any
/// model-only pick, then any player-only pick. Null when the picks match.
Disagreement? pickDisagreement(
  List<PoItem> session,
  List<PoItem> yourPicks,
  List<PoItem> modelPicks,
) {
  final yourIds = yourPicks.map((p) => p.id).toSet();
  final modelIds = modelPicks.map((p) => p.id).toSet();
  final modelOnly = modelPicks.where((p) => !yourIds.contains(p.id)).toList();
  final playerOnly = yourPicks.where((p) => !modelIds.contains(p.id)).toList();

  PoItem? best(List<PoItem> candidates, Comparator<PoItem> prefer) {
    if (candidates.isEmpty) return null;
    final sorted = [...candidates]..sort(prefer);
    return sorted.first;
  }

  final total = session.length;

  final surprise = best(
    modelOnly.where((p) => p.outcome.exceptionReachedClearance).toList(),
    (a, b) {
      final byProb = a.riskProb.compareTo(b.riskProb);
      if (byProb != 0) return byProb;
      return exposureRank(session, b).compareTo(exposureRank(session, a));
    },
  );
  if (surprise != null) {
    return _disagreement(surprise, DisagreementSide.modelOnly, total);
  }

  final falseAlarm = best(
    playerOnly.where((p) => !p.outcome.exceptionReachedClearance).toList(),
    (a, b) {
      final byRank = b.modelRank.compareTo(a.modelRank);
      if (byRank != 0) return byRank;
      return b.exposureUnits.compareTo(a.exposureUnits);
    },
  );
  if (falseAlarm != null) {
    return _disagreement(falseAlarm, DisagreementSide.playerOnly, total);
  }

  final anyModel = best(
    modelOnly,
    (a, b) => a.modelRank.compareTo(b.modelRank),
  );
  if (anyModel != null) {
    return _disagreement(anyModel, DisagreementSide.modelOnly, total);
  }

  final anyPlayer = best(
    playerOnly,
    (a, b) => b.modelRank.compareTo(a.modelRank),
  );
  if (anyPlayer != null) {
    return _disagreement(anyPlayer, DisagreementSide.playerOnly, total);
  }

  return null;
}

Disagreement _disagreement(PoItem item, DisagreementSide side, int total) {
  final outcome = item.outcome.exceptionReachedClearance
      ? Copy.outcomeException
      : Copy.outcomeFine;
  final why = '${Copy.rankedThis(item.modelRank, total)} '
      '${Copy.rankWeighsHistory} '
      '${item.reason} '
      '${Copy.vendorBaseRate(formatPercent(item.vendorBaseRate))}. '
      '$outcome';
  return Disagreement(item: item, side: side, why: why);
}
