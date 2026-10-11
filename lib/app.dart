import 'package:flutter/material.dart';

import 'game/game_controller.dart';
import 'game/game_scope.dart';
import 'screens/root_switcher.dart';
import 'theme/ls_theme.dart';

class LedgerShieldApp extends StatefulWidget {
  const LedgerShieldApp({super.key});

  @override
  State<LedgerShieldApp> createState() => _LedgerShieldAppState();
}

class _LedgerShieldAppState extends State<LedgerShieldApp> {
  // The controller and the batch load live in State, not in main or build,
  // so a hot reload keeps the game where it was.
  late final GameController _controller;
  ThemeMode _themeMode = ThemeMode.dark;

  @override
  void initState() {
    super.initState();
    _controller = GameController();
    _controller.loadBatch();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.dark
          ? ThemeMode.light
          : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    // GameScope wraps MaterialApp rather than home so sheet and dialog
    // builders under the root Navigator's overlay can reach GameScope.of.
    return GameScope(
      controller: _controller,
      child: MaterialApp(
        title: 'LedgerShield MY',
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        themeMode: _themeMode,
        debugShowCheckedModeBanner: false,
        home: RootSwitcher(onToggleTheme: _toggleTheme),
      ),
    );
  }
}
