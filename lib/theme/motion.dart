import 'package:flutter/widgets.dart';

const Duration sheetIn = Duration(milliseconds: 250);
const Duration sheetOut = Duration(milliseconds: 200);
const Duration commitDuration = Duration(milliseconds: 220);
const Duration backCardMove = Duration(milliseconds: 200);
const Duration slotPulse = Duration(milliseconds: 300);
const Duration flipStagger = Duration(milliseconds: 80);
const Duration flipEach = Duration(milliseconds: 400);
const Duration switcher = Duration(milliseconds: 250);

/// Damping ratio about 0.7, which gives one small visible overshoot when a
/// card springs back to centre.
const SpringDescription cardSpring = SpringDescription(
  mass: 1,
  stiffness: 400,
  damping: 28,
);

/// True when the platform asks for animations to be removed. Read this in
/// build or didChangeDependencies, never in initState, because it depends on
/// an inherited MediaQuery.
bool reduceMotion(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context);

/// The given duration, or zero when the platform asks for reduced motion.
Duration motionOr(BuildContext context, Duration d) =>
    reduceMotion(context) ? Duration.zero : d;
