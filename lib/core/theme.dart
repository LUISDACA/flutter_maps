import 'package:flutter/material.dart';

ThemeData buildTheme() {
  final base = ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
    useMaterial3: true,
  );
  return base.copyWith(
    appBarTheme: const AppBarTheme(centerTitle: true),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Colors.red,
      foregroundColor: Colors.white,
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
    ),
  );
}
