import 'package:flutter/material.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF2F6F6D),
      brightness: Brightness.light,
    );
    return _theme(colorScheme);
  }

  static ThemeData night() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF7BC7B2),
      brightness: Brightness.dark,
    ).copyWith(
      surface: const Color(0xFF101816),
      surfaceContainerLowest: const Color(0xFF0B1110),
      surfaceContainerLow: const Color(0xFF17211F),
      surfaceContainer: const Color(0xFF1B2825),
      surfaceContainerHigh: const Color(0xFF243330),
      surfaceContainerHighest: const Color(0xFF2D3D39),
    );
    return _theme(colorScheme);
  }

  static ThemeData _theme(ColorScheme colorScheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        clipBehavior: Clip.antiAlias,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: true,
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        labelType: NavigationRailLabelType.all,
      ),
    );
  }
}
