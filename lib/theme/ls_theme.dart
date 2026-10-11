import 'package:flutter/material.dart';

import 'ls_colors.dart';

/// Style for every number on screen: exposure, ids, probabilities, timestamps.
const TextStyle monoStyle = TextStyle(
  fontFamily: 'JetBrainsMono',
  fontWeight: FontWeight.w500,
  fontFeatures: [FontFeature.tabularFigures()],
);

const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

/// The one card surface used by the payment card, the Reveal cards, the
/// receipt and the lock panel: surface fill, a 1 px line border and a shadow
/// that is heavier in dark mode (where the line border alone barely reads)
/// and a faint ink tint in light mode (where a black shadow would be a grey
/// halo on the near-white background). [borderColor] and [borderWidth]
/// override the border for cards that carry a risk colour on their edge.
BoxDecoration lsCard(
  BuildContext context, {
  double radius = 20,
  Color? borderColor,
  double borderWidth = 1,
}) {
  final c = context.ls;
  final dark = Theme.of(context).brightness == Brightness.dark;
  return BoxDecoration(
    color: c.surface,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: borderColor ?? c.line, width: borderWidth),
    boxShadow: [
      if (dark)
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.35),
          blurRadius: 16,
          offset: const Offset(0, 8),
        )
      else
        BoxShadow(
          color: c.ink.withValues(alpha: 0.06),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
    ],
  );
}

ThemeData buildTheme(Brightness b) {
  final c = b == Brightness.dark ? LsColors.dark : LsColors.light;
  final light = b == Brightness.light;

  // Only three sizes may ever render: 28 for the hero number and headline,
  // 17 for body and controls, 13 for captions and small print. Material would
  // otherwise leak 14, 22 and 24 px through buttons, app bars and dialogs, so
  // those roles are pinned to the same three sizes below.
  final headline = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w600,
    color: c.ink,
    height: 1.2,
  );
  final body = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w400,
    color: c.ink,
    height: 1.35,
    fontFeatures: _tabular,
  );
  final bodyStrong = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: c.ink,
    height: 1.35,
  );
  final caption = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: c.inkMuted,
    height: 1.3,
    fontFeatures: _tabular,
  );

  final textTheme = TextTheme(
    headlineMedium: headline,
    headlineSmall: headline,
    titleLarge: bodyStrong,
    labelLarge: bodyStrong,
    bodyLarge: body,
    bodyMedium: body,
    bodySmall: caption,
  );

  final colorScheme = ColorScheme.fromSeed(seedColor: c.accent, brightness: b)
      .copyWith(
        surface: c.surface,
        primary: c.accent,
        onPrimary: b == Brightness.light ? c.ink : c.bg,
        error: c.riskHigh,
        onSurface: c.ink,
      );

  return ThemeData(
    useMaterial3: true,
    brightness: b,
    scaffoldBackgroundColor: c.bg,
    colorScheme: colorScheme,
    fontFamily: 'Inter',
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: c.bg,
      foregroundColor: c.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: bodyStrong,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.surface,
      titleTextStyle: headline,
      contentTextStyle: body,
      // Material 3 would give the dialog a 28 px radius; every other
      // surface in the app is 20 px.
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    // Light accent on the light background is about 3.3:1, below AA for
    // text, so outlined, text and chip labels are drawn in ink in light
    // mode. The accent stays on the border so the controls still read as
    // actions. In dark mode the accent is about 9.4:1 and stays as the label.
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: light ? c.ink : c.accent,
        side: BorderSide(color: c.accent),
      ),
    ),
    // A text button has no border to carry the accent, so in light mode its
    // ink label is underlined instead; otherwise it would be indistinguishable
    // from body text. The style is built from bodyStrong so the label keeps
    // its 17 px size, and the underline takes the ink foreground colour.
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: light ? c.ink : c.accent,
        textStyle: light
            ? bodyStrong.copyWith(
                decoration: TextDecoration.underline,
                decorationThickness: 1.5,
              )
            : null,
      ),
    ),
    chipTheme: ChipThemeData(
      labelStyle: bodyStrong.copyWith(color: c.ink),
      side: BorderSide(color: c.accent),
      selectedColor: c.accent.withValues(alpha: 0.18),
      checkmarkColor: c.ink,
      backgroundColor: c.surface,
    ),
    dividerColor: c.line,
    extensions: [c],
  );
}
