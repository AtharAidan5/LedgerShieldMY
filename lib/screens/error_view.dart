import 'package:flutter/material.dart';

import '../copy.dart';

/// Shown when the batch asset fails to load or parse.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(Copy.errorTitle, style: text.headlineMedium),
                const SizedBox(height: 12),
                Text(message, style: text.bodySmall),
                const SizedBox(height: 24),
                SizedBox(
                  height: 48,
                  child: FilledButton(
                    onPressed: onRetry,
                    child: const Text(Copy.retry),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
