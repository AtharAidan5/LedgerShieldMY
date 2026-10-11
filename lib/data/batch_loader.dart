import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'models.dart';

const String batchAssetPath = 'assets/data/batch.json';

/// Parses a batch and validates it eagerly, so a bad row fails at startup
/// (and lands on the error view) instead of mid-swipe.
Batch parseBatch(String json) {
  final decoded = jsonDecode(json);
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('Batch root must be a JSON object.');
  }
  final batch = Batch.fromJson(decoded);
  _validateRanks(batch.items);
  return batch;
}

Future<Batch> loadBatchAsset() async {
  final raw = await rootBundle.loadString(batchAssetPath);
  return parseBatch(raw);
}

/// The model ranks must be exactly the unique set 1..n; the Reveal and the
/// disagreement ladder both assume this.
void _validateRanks(List<PoItem> items) {
  final seen = <int>{};
  for (final item in items) {
    if (item.modelRank < 1 || item.modelRank > items.length) {
      throw FormatException(
        'model_rank ${item.modelRank} on ${item.id} is outside 1..${items.length}.',
      );
    }
    if (!seen.add(item.modelRank)) {
      throw FormatException('Duplicate model_rank ${item.modelRank} on ${item.id}.');
    }
  }
}
