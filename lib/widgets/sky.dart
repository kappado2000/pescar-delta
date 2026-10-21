import 'package:flutter/material.dart';

/// Denumirea stării cerului pentru un cod WMO (noaptea „Senin”, nu „Soare”).
String skyLabel(int code, {bool night = false}) => switch (code) {
  0 => night ? 'Senin' : 'Soare',
  1 => night ? 'Mai mult senin' : 'Soare cu nori',
  2 => 'Parțial noros',
  3 => 'Înnorat',
  45 || 48 => 'Ceață',
  51 => 'Burniță slabă',
  53 || 55 || 56 || 57 => 'Burniță',
  61 => 'Ploaie slabă',
  63 => 'Ploaie',
  65 || 66 || 67 => 'Ploaie puternică',
  71 => 'Ninsoare slabă',
  73 || 77 || 85 => 'Ninsoare',
  75 || 86 => 'Ninsoare puternică',
  80 => 'Averse slabe',
  81 => 'Averse',
  82 => 'Averse puternice',
  >= 95 => 'Furtună',
  _ => 'Înnorat',
};

IconData skyIcon(int code, {bool night = false}) => switch (code) {
  0 => night ? Icons.nightlight_round : Icons.wb_sunny,
  1 => night ? Icons.nights_stay : Icons.wb_twilight,
  2 => night ? Icons.nights_stay_outlined : Icons.cloud_queue,
  3 => Icons.cloud,
  45 || 48 => Icons.foggy,
  >= 51 && <= 57 => Icons.grain,
  >= 61 && <= 67 => Icons.water_drop,
  >= 71 && <= 77 || 85 || 86 => Icons.ac_unit,
  >= 80 && <= 82 => Icons.umbrella,
  >= 95 => Icons.thunderstorm,
  _ => Icons.cloud,
};

/// Culoarea iconiței: soare portocaliu, nori gri-albăstrui, ploaie albastră,
/// furtună violet.
Color skyColor(int code, {bool night = false}) => switch (code) {
  0 || 1 => night ? const Color(0xFF5C6BC0) : const Color(0xFFE8890C),
  2 || 3 || 45 || 48 => const Color(0xFF607D8B),
  >= 95 => const Color(0xFF7E57C2),
  >= 71 && <= 77 || 85 || 86 => const Color(0xFF4FC3F7),
  _ => const Color(0xFF1E88E5),
};

/// Iconiță + denumire, pe un rând.
class SkyLabel extends StatelessWidget {
  const SkyLabel({
    super.key,
    required this.code,
    this.night = false,
    this.size = 18,
    this.style,
  });
  final int code;
  final bool night;
  final double size;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(
        skyIcon(code, night: night),
        size: size,
        color: skyColor(code, night: night),
      ),
      const SizedBox(width: 4),
      Text(
        skyLabel(code, night: night),
        style: (style ?? const TextStyle()).copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}
