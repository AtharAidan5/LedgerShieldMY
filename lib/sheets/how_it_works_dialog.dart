import 'package:flutter/material.dart';

import '../copy.dart';
import '../theme/motion.dart';

const Duration _dialogIn = Duration(milliseconds: 150);

/// The "i" modal: three sentences plus the tagline and one Got it button.
Future<void> showHowItWorksDialog(BuildContext context) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: Copy.howTitle,
    transitionDuration: motionOr(context, _dialogIn),
    transitionBuilder: (_, animation, _, child) =>
        FadeTransition(opacity: animation, child: child),
    pageBuilder: (dialogContext, _, _) {
      final text = Theme.of(dialogContext).textTheme;
      return AlertDialog(
        title: const Text(Copy.howTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(Copy.howSentence1, style: text.bodyLarge),
            const SizedBox(height: 12),
            Text(Copy.howSentence2, style: text.bodyLarge),
            const SizedBox(height: 12),
            Text(Copy.howSentence3, style: text.bodyLarge),
            const SizedBox(height: 16),
            Text(
              Copy.tagline,
              style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text(Copy.gotIt),
          ),
        ],
      );
    },
  );
}
