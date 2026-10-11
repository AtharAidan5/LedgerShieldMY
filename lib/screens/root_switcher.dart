import 'package:flutter/material.dart';

import '../game/game_controller.dart';
import '../game/game_scope.dart';
import '../theme/motion.dart';
import 'error_view.dart';
import 'proof_screen.dart';
import 'reveal_screen.dart';
import 'stack_screen.dart';

/// Keys for the AnimatedSwitcher. Stack and locking share one key so the
/// lock overlay does not cross-fade the StackScreen with itself.
enum _Screen { loading, error, stack, reveal, proof }

_Screen _screenFor(GamePhase phase) => switch (phase) {
  GamePhase.loading => _Screen.loading,
  GamePhase.error => _Screen.error,
  GamePhase.stack || GamePhase.locking => _Screen.stack,
  GamePhase.reveal => _Screen.reveal,
  GamePhase.proof => _Screen.proof,
};

/// The one root widget. It switches on the controller phase instead of
/// pushing routes, so Play again is a hard reset and no stale route can sit
/// under the Reveal.
class RootSwitcher extends StatelessWidget {
  const RootSwitcher({super.key, this.onToggleTheme});

  final VoidCallback? onToggleTheme;

  @override
  Widget build(BuildContext context) {
    final controller = GameScope.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final phase = controller.phase;
        final Widget screen = switch (phase) {
          GamePhase.loading => const Center(child: CircularProgressIndicator()),
          GamePhase.error => ErrorView(
            message: controller.errorMessage ?? '',
            onRetry: controller.loadBatch,
          ),
          GamePhase.stack ||
          GamePhase.locking => StackScreen(onToggleTheme: onToggleTheme),
          GamePhase.reveal => const RevealScreen(),
          GamePhase.proof => const ProofScreen(),
        };
        return PopScope(
          // Stack, locking and reveal swallow system back so a judge cannot
          // leave mid-turn; proof steps back to the reveal.
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && controller.phase == GamePhase.proof) {
              controller.showReveal();
            }
          },
          child: Center(
            child: ConstrainedBox(
              // Keeps the phone layout when the app runs on Chrome.
              constraints: const BoxConstraints(maxWidth: 430),
              child: AnimatedSwitcher(
                duration: motionOr(context, switcher),
                child: KeyedSubtree(
                  key: ValueKey<_Screen>(_screenFor(phase)),
                  child: screen,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
