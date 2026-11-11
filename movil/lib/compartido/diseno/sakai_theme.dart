import 'package:flutter/material.dart';

/// Adaptación Flutter de Sakai/PrimeVue; procedencia en DISENO_SAKAI.md.
abstract final class Sakai {
  static const emerald = Color(0xFF10B981);
  // Emerald 700 mantiene contraste de texto blanco en botones y texto pequeño.
  static const green = Color(0xFF047857);
  static const mint = Color(0xFFD1FAE5);
  static const background = Color(0xFFF1F5F9);
  static const ink = Color(0xFF0F172A);
  static const muted = Color(0xFF64748B);
  static const border = Color(0xFFE2E8F0);
  static const blue = Color(0xFF1D4ED8);
  static const blueLight = Color(0xFFDBEAFE);
  static const violet = Color(0xFF7E22CE);
  static const violetLight = Color(0xFFF3E8FF);
  static const amber = Color(0xFFB45309);
  static const amberLight = Color(0xFFFEF3C7);
  static const cyan = Color(0xFF0E7490);
  static const cyanLight = Color(0xFFCFFAFE);

  static ThemeData get theme {
    final base = ThemeData(useMaterial3: true, fontFamily: 'Roboto');
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
    );
    return base.copyWith(
      scaffoldBackgroundColor: background,
      colorScheme: ColorScheme.fromSeed(seedColor: emerald).copyWith(
        primary: green,
        onPrimary: Colors.white,
        primaryContainer: mint,
        onPrimaryContainer: green,
        secondary: blue,
        secondaryContainer: blueLight,
        tertiary: violet,
        tertiaryContainer: violetLight,
        surface: Colors.white,
        onSurface: ink,
        onSurfaceVariant: muted,
        outline: muted,
        outlineVariant: border,
      ),
      textTheme: base.textTheme
          .apply(bodyColor: ink, displayColor: ink)
          .copyWith(
            headlineMedium: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: ink,
              letterSpacing: -.7,
            ),
            headlineSmall: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: ink,
              letterSpacing: -.5,
            ),
            titleLarge: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: ink,
            ),
            titleMedium: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: ink,
            ),
            bodyMedium: const TextStyle(fontSize: 14, height: 1.5, color: ink),
            bodySmall: const TextStyle(
              fontSize: 12,
              height: 1.45,
              color: muted,
            ),
          )
          .apply(fontFamily: 'Roboto'),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: ink,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: shape,
      ),
      dividerTheme: const DividerThemeData(
        color: border,
        thickness: 1,
        space: 24,
      ),
      iconTheme: const IconThemeData(color: muted, size: 22),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        labelStyle: const TextStyle(color: muted),
        hintStyle: const TextStyle(color: muted),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: green, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 16,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: green,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 50),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: green,
          minimumSize: const Size(0, 48),
          side: const BorderSide(color: green),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        indicatorColor: mint,
        height: 72,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w400,
            color: states.contains(WidgetState.selected) ? green : muted,
          ),
        ),
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      listTileTheme: const ListTileThemeData(
        selectedColor: green,
        selectedTileColor: mint,
        iconColor: muted,
        contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: green),
    );
  }
}

/// Glifos de PrimeIcons originales, incluidos localmente bajo licencia MIT.
abstract final class PrimeIcons {
  static const home = IconData(0xe925, fontFamily: 'PrimeIcons');
  static const inbox = IconData(0xe961, fontFamily: 'PrimeIcons');
  static const search = IconData(0xe908, fontFamily: 'PrimeIcons');
  static const file = IconData(0xe958, fontFamily: 'PrimeIcons');
  static const folder = IconData(0xe963, fontFamily: 'PrimeIcons');
  static const user = IconData(0xe939, fontFamily: 'PrimeIcons');
  static const plus = IconData(0xe90d, fontFamily: 'PrimeIcons');
  static const chevronRight = IconData(0xe901, fontFamily: 'PrimeIcons');
  static const clock = IconData(0xe940, fontFamily: 'PrimeIcons');
  static const check = IconData(0xe90a, fontFamily: 'PrimeIcons');
}
