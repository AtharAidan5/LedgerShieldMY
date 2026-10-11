import 'package:flutter/widgets.dart';

import 'game_controller.dart';

/// Exposes the single [GameController] to the whole tree. It wraps
/// [MaterialApp] (not `home`) so sheet and dialog builders under the root
/// Navigator's overlay can still reach it.
class GameScope extends InheritedNotifier<GameController> {
  const GameScope({
    super.key,
    required GameController controller,
    required super.child,
  }) : super(notifier: controller);

  static GameController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<GameScope>();
    assert(scope != null, 'GameScope.of called outside a GameScope.');
    return scope!.notifier!;
  }
}
