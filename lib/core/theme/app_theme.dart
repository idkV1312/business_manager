import 'package:flutter/material.dart';

class AppTheme {
  static const _brand = Color(0xFF2F5D9D);
  static const _accent = Color(0xFF1F9D84);
  static const _surface = Color(0xFFFFFFFF);
  static const _page = Color(0xFFF4F7FB);
  static const _ink = Color(0xFF172033);

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _brand,
      brightness: Brightness.light,
      primary: _brand,
      secondary: _accent,
      surface: _surface,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: _page,
      fontFamilyFallback: const ['Inter', 'SF Pro Text', 'Segoe UI', 'Roboto', 'Arial'],
    );

    final textTheme = base.textTheme.copyWith(
      headlineMedium: base.textTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.45,
        color: _ink,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        color: _ink,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
        color: _ink,
      ),
      bodyLarge: base.textTheme.bodyLarge?.copyWith(
        height: 1.35,
        color: const Color(0xFF3E4658),
      ),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(
        height: 1.35,
        color: const Color(0xFF4C556A),
      ),
      labelLarge: base.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.15,
      ),
    );

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: _ink,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge,
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: const Color(0xFFEAF2FF),
        selectedColor: const Color(0xFFDCEBFF),
        side: const BorderSide(color: Color(0xFFD5E2F5)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        labelStyle: textTheme.labelLarge?.copyWith(color: const Color(0xFF2E4C7A)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF9FBFF),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        hintStyle: textTheme.bodyMedium?.copyWith(color: const Color(0xFF8A93A8)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD5DDED)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD5DDED)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _brand, width: 1.3),
        ),
      ),
      cardTheme: CardThemeData(
        color: _surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE7ECF4)),
        ),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFFE6ECF4)),
        ),
        tileColor: _surface,
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE2E8F2),
        thickness: 1,
        space: 1,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 0,
        backgroundColor: colorScheme.primary,
        foregroundColor: Colors.white,
        extendedPadding: const EdgeInsets.symmetric(horizontal: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        height: 72,
        backgroundColor: _surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: const Color(0xFFDCEBFF),
        labelTextStyle: MaterialStateProperty.resolveWith((states) {
          final selected = states.contains(MaterialState.selected);
          return textTheme.labelSmall?.copyWith(
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? _brand : const Color(0xFF657089),
          );
        }),
      ),
      iconTheme: const IconThemeData(
        color: Color(0xFF4A546A),
      ),
    );
  }
}
