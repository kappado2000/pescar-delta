import 'package:flutter/material.dart';

/// Paleta marină a aplicației.
class Sea {
  static const navy = Color(0xFF0B2545);
  static const deep = Color(0xFF0E4C6D);
  static const ocean = Color(0xFF13698F);
  static const teal = Color(0xFF1B998B);
  static const aqua = Color(0xFF8DD3E0);
  static const foam = Color(0xFFEAF5F8);
  static const sand = Color(0xFFF2E6CF);
  static const sunset = Color(0xFFF4A259);
  static const coral = Color(0xFFE76F51);

  /// Culori pentru valori „bune / medii / slabe”.
  static const good = Color(0xFF2A9D8F);
  static const ok = Color(0xFFE9C46A);
  static const bad = Color(0xFFE76F51);

  static const headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [navy, deep, ocean],
  );
}

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: Sea.ocean,
        brightness: brightness,
      ).copyWith(
        primary: dark ? Sea.aqua : Sea.deep,
        onPrimary: dark ? Sea.navy : Colors.white,
        secondary: Sea.teal,
        tertiary: Sea.sunset,
        onTertiary: Sea.navy,
        surface: dark ? const Color(0xFF0A1C2E) : const Color(0xFFDDEEF8),
        surfaceContainerLow: dark ? const Color(0xFF0F2438) : Colors.white,
        surfaceContainer: dark
            ? const Color(0xFF122A41)
            : const Color(0xFFE8F4FB),
        surfaceContainerHighest: dark
            ? const Color(0xFF1A3550)
            : const Color(0xFFDCEBF1),
      );
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: dark ? Sea.navy : Sea.deep,
      foregroundColor: Colors.white,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        // contur subțire: închis pe luminos, deschis pe dark
        side: BorderSide(
          color: dark
              ? Sea.aqua.withValues(alpha: 0.35)
              : Sea.navy.withValues(alpha: 0.55),
          width: 0.8,
        ),
      ),
      margin: const EdgeInsets.symmetric(vertical: 5),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: dark ? Sea.navy : Colors.white,
      indicatorColor: dark ? Sea.deep : Sea.foam,
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          color: s.contains(WidgetState.selected)
              ? (dark ? Sea.aqua : Sea.deep)
              : scheme.onSurfaceVariant,
        ),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Sea.sunset,
      foregroundColor: Sea.navy,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      isDense: true,
      filled: true,
      fillColor: scheme.surfaceContainerLow,
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: Colors.white,
      unselectedLabelColor: Colors.white70,
      indicatorColor: Sea.sunset,
      dividerColor: Colors.transparent,
    ),
  );
}

/// Culoarea „Necesar”: maro pe tema luminoasă, portocaliu pe cea dark.
Color needsColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? Sea.sunset
    : const Color(0xFF8B5A2B);

/// Textul de pe insignele „Necesar” (numerele categoriilor).
Color needsOnColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? Sea.navy : Colors.white;

/// Culoare stabilă pentru fiecare specie (aceeași în toate ecranele).
Color speciesColor(String species) {
  const palette = [
    Color(0xFF13698F),
    Color(0xFF1B998B),
    Color(0xFFF4A259),
    Color(0xFFE76F51),
    Color(0xFF6A4C93),
    Color(0xFF2A9D8F),
    Color(0xFF8AB17D),
    Color(0xFFB5838D),
    Color(0xFF264653),
    Color(0xFFE9C46A),
  ];
  const fixed = {
    'Crap': 0,
    'Caras': 9,
    'Somn': 8,
    'Știucă': 6,
    'Șalău': 4,
    'Biban': 3,
    'Plătică': 2,
    'Roșioară': 3,
    'Avat': 7,
    'Fitofag': 1,
  };
  final i =
      fixed[species] ??
      species.codeUnits.fold<int>(0, (a, b) => a + b) % palette.length;
  return palette[i];
}
