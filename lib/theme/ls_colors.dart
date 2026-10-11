import 'package:flutter/material.dart';

import '../data/models.dart';

/// Colour tokens for both themes, exposed as a ThemeExtension so every widget
/// reads them through `context.ls` instead of hard-coding hex values.
class LsColors extends ThemeExtension<LsColors> {
  const LsColors({
    required this.bg,
    required this.surface,
    required this.ink,
    required this.inkMuted,
    required this.accent,
    required this.riskHigh,
    required this.riskMid,
    required this.riskLow,
    required this.line,
  });

  final Color bg;
  final Color surface;
  final Color ink;
  final Color inkMuted;
  final Color accent;
  final Color riskHigh;
  final Color riskMid;
  final Color riskLow;
  final Color line;

  static const LsColors dark = LsColors(
    bg: Color(0xFF0E1116),
    surface: Color(0xFF171B22),
    ink: Color(0xFFEDEFF3),
    inkMuted: Color(0xFF9AA3B2),
    accent: Color(0xFF3DD6B0),
    riskHigh: Color(0xFFFF5C5C),
    riskMid: Color(0xFFFFB84D),
    riskLow: Color(0xFF3DD6B0),
    line: Color(0xFF262C36),
  );

  static const LsColors light = LsColors(
    bg: Color(0xFFF6F7F9),
    surface: Color(0xFFFFFFFF),
    ink: Color(0xFF12151A),
    inkMuted: Color(0xFF5B6472),
    accent: Color(0xFF0E9F7E),
    riskHigh: Color(0xFFD93636),
    riskMid: Color(0xFFC77700),
    riskLow: Color(0xFF0E9F7E),
    line: Color(0xFFE3E6EB),
  );

  @override
  LsColors copyWith({
    Color? bg,
    Color? surface,
    Color? ink,
    Color? inkMuted,
    Color? accent,
    Color? riskHigh,
    Color? riskMid,
    Color? riskLow,
    Color? line,
  }) {
    return LsColors(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      ink: ink ?? this.ink,
      inkMuted: inkMuted ?? this.inkMuted,
      accent: accent ?? this.accent,
      riskHigh: riskHigh ?? this.riskHigh,
      riskMid: riskMid ?? this.riskMid,
      riskLow: riskLow ?? this.riskLow,
      line: line ?? this.line,
    );
  }

  @override
  LsColors lerp(ThemeExtension<LsColors>? other, double t) {
    if (other is! LsColors) {
      return this;
    }
    return LsColors(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkMuted: Color.lerp(inkMuted, other.inkMuted, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      riskHigh: Color.lerp(riskHigh, other.riskHigh, t)!,
      riskMid: Color.lerp(riskMid, other.riskMid, t)!,
      riskLow: Color.lerp(riskLow, other.riskLow, t)!,
      line: Color.lerp(line, other.line, t)!,
    );
  }
}

extension LsContext on BuildContext {
  LsColors get ls => Theme.of(this).extension<LsColors>()!;
}

extension RiskBandColor on RiskBand {
  Color color(LsColors c) => switch (this) {
    RiskBand.low => c.riskLow,
    RiskBand.elevated => c.riskMid,
    RiskBand.high => c.riskHigh,
  };
}
