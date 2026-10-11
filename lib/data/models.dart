/// Data model for one batch of precomputed purchase-order items.
///
/// Every class is immutable, has a const constructor and a `fromJson` factory.
/// Numbers are always read through `num` because the JSON decoder yields
/// `int` for values such as `184` even when the schema calls for a double.
library;

enum RiskBand {
  low('Low'),
  elevated('Elevated'),
  high('High');

  const RiskBand(this.label);

  final String label;

  static RiskBand parse(String value) {
    for (final band in RiskBand.values) {
      if (band.label == value) return band;
    }
    throw FormatException('Unknown risk_band: $value');
  }
}

enum ExceptionCategory {
  missingGoodsReceipt('Missing goods receipt'),
  amountMismatch('Amount mismatch'),
  processPath('Process-path exception'),
  insufficientEvidence('Insufficient evidence');

  const ExceptionCategory(this.label);

  final String label;

  static ExceptionCategory parse(String value) {
    for (final category in ExceptionCategory.values) {
      if (category.label == value) return category;
    }
    throw FormatException('Unknown category: $value');
  }
}

class PoEvent {
  const PoEvent({required this.label, required this.date, required this.present});

  factory PoEvent.fromJson(Map<String, dynamic> json) => PoEvent(
        label: json['label'] as String,
        date: json['date'] as String?,
        present: json['present'] as bool,
      );

  final String label;

  /// Raw `yyyy-MM-dd` string, or null when the event has not happened.
  final String? date;
  final bool present;
}

class Outcome {
  const Outcome({
    required this.exceptionReachedClearance,
    required this.actualExposureUnits,
  });

  factory Outcome.fromJson(Map<String, dynamic> json) => Outcome(
        exceptionReachedClearance: json['exception_reached_clearance'] as bool,
        actualExposureUnits: (json['actual_exposure_units'] as num).toDouble(),
      );

  final bool exceptionReachedClearance;
  final double actualExposureUnits;
}

class PoItem {
  const PoItem({
    required this.id,
    required this.vendor,
    required this.matchType,
    required this.exposureUnits,
    required this.daysToClearance,
    required this.riskProb,
    required this.riskLow,
    required this.riskHigh,
    required this.riskBand,
    required this.category,
    required this.reason,
    required this.vendorBaseRate,
    required this.whatWouldChange,
    required this.events,
    required this.modelRank,
    required this.outcome,
  });

  factory PoItem.fromJson(Map<String, dynamic> json) => PoItem(
        id: json['id'] as String,
        vendor: json['vendor'] as String,
        matchType: json['match_type'] as String,
        exposureUnits: (json['exposure_units'] as num).toDouble(),
        daysToClearance: (json['days_to_clearance'] as num).toInt(),
        riskProb: (json['risk_prob'] as num).toDouble(),
        riskLow: (json['risk_low'] as num).toDouble(),
        riskHigh: (json['risk_high'] as num).toDouble(),
        riskBand: RiskBand.parse(json['risk_band'] as String),
        category: ExceptionCategory.parse(json['category'] as String),
        reason: json['reason'] as String,
        vendorBaseRate: (json['vendor_base_rate'] as num).toDouble(),
        whatWouldChange: json['what_would_change'] as String,
        events: List.unmodifiable(
          (json['events'] as List<dynamic>)
              .map((e) => PoEvent.fromJson(e as Map<String, dynamic>)),
        ),
        modelRank: (json['model_rank'] as num).toInt(),
        outcome: Outcome.fromJson(json['outcome'] as Map<String, dynamic>),
      );

  final String id;
  final String vendor;
  final String matchType;
  final double exposureUnits;
  final int daysToClearance;
  final double riskProb;
  final double riskLow;
  final double riskHigh;
  final RiskBand riskBand;
  final ExceptionCategory category;
  final String reason;
  final double vendorBaseRate;
  final String whatWouldChange;
  final List<PoEvent> events;
  final int modelRank;
  final Outcome outcome;

  @override
  bool operator ==(Object other) => other is PoItem && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'PoItem($id)';
}

class BatchMeta {
  const BatchMeta({
    required this.checkpoint,
    required this.reviewCapacityK,
    required this.units,
    required this.split,
    required this.modelVersion,
  });

  factory BatchMeta.fromJson(Map<String, dynamic> json) => BatchMeta(
        checkpoint: json['checkpoint'] as String,
        reviewCapacityK: (json['review_capacity_K'] as num?)?.toInt() ?? 5,
        units: json['units'] as String,
        split: json['split'] as String,
        modelVersion: json['model_version'] as String,
      );

  final String checkpoint;
  final int reviewCapacityK;
  final String units;
  final String split;
  final String modelVersion;
}

class Policy {
  const Policy({required this.name, required this.recallAtK});

  factory Policy.fromJson(Map<String, dynamic> json) => Policy(
        name: json['name'] as String,
        recallAtK: (json['recall_at_K'] as num).toDouble(),
      );

  final String name;
  final double recallAtK;
}

class HeldoutVariant {
  const HeldoutVariant({
    required this.precisionAtK,
    required this.exposureRecallAtK,
  });

  factory HeldoutVariant.fromJson(Map<String, dynamic> json) => HeldoutVariant(
        precisionAtK: (json['precision_at_K'] as num).toDouble(),
        exposureRecallAtK: (json['exposure_recall_at_K'] as num).toDouble(),
      );

  final double precisionAtK;
  final double exposureRecallAtK;
}

class ProofData {
  const ProofData({
    required this.kPerDay,
    required this.policies,
    required this.precisionAtK,
    required this.exposureRecallAtK,
    required this.medianDaysWarning,
    required this.vendorHeldout,
  });

  factory ProofData.fromJson(Map<String, dynamic> json) => ProofData(
        kPerDay: (json['K_per_day'] as num).toInt(),
        policies: List.unmodifiable(
          (json['policies'] as List<dynamic>)
              .map((p) => Policy.fromJson(p as Map<String, dynamic>)),
        ),
        precisionAtK: (json['precision_at_K'] as num).toDouble(),
        exposureRecallAtK: (json['exposure_recall_at_K'] as num).toDouble(),
        medianDaysWarning: (json['median_days_warning'] as num).toDouble(),
        vendorHeldout: HeldoutVariant.fromJson(
          json['vendor_heldout'] as Map<String, dynamic>,
        ),
      );

  final int kPerDay;
  final List<Policy> policies;
  final double precisionAtK;
  final double exposureRecallAtK;
  final double medianDaysWarning;
  final HeldoutVariant vendorHeldout;

  /// True while every proof number is still the `0.0` placeholder from the
  /// spec, which is how the Proof screen decides to show the PLACEHOLDER badge.
  bool get isPlaceholder =>
      precisionAtK == 0.0 &&
      exposureRecallAtK == 0.0 &&
      medianDaysWarning == 0.0 &&
      vendorHeldout.precisionAtK == 0.0 &&
      vendorHeldout.exposureRecallAtK == 0.0 &&
      policies.every((p) => p.recallAtK == 0.0);
}

class Batch {
  const Batch({required this.meta, required this.items, required this.proof});

  factory Batch.fromJson(Map<String, dynamic> json) => Batch(
        meta: BatchMeta.fromJson(json['meta'] as Map<String, dynamic>),
        items: List.unmodifiable(
          (json['items'] as List<dynamic>)
              .map((i) => PoItem.fromJson(i as Map<String, dynamic>)),
        ),
        proof: ProofData.fromJson(json['proof'] as Map<String, dynamic>),
      );

  final BatchMeta meta;
  final List<PoItem> items;
  final ProofData proof;
}
