import 'package:flutter/material.dart';

/// App color palette borrowed from the web app's dark-on-light aesthetic.
/// Tweak in concert with the web design tokens when they change.
class AppTheme {
  AppTheme._();

  static const _seed = Color(0xFF1F2937);

  static ThemeData light() {
    final base = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: _seed),
      useMaterial3: true,
      brightness: Brightness.light,
    );
    return base.copyWith(
      visualDensity: VisualDensity.adaptivePlatformDensity,
      textTheme: base.textTheme.apply(fontFamilyFallback: const ['system-ui']),
    );
  }

  static ThemeData dark() {
    final base = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: _seed,
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
      brightness: Brightness.dark,
    );
    return base.copyWith(visualDensity: VisualDensity.adaptivePlatformDensity);
  }
}
