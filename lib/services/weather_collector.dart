import '../models/place.dart';
import '../models/weather_day.dart';
import 'http_retry.dart';

/// Descarcă vremea zilnică observată într-o locație (a sezonului).
///
/// Sursa principală: analiza ECMWF IFS (9 km) — cel mai precis model global,
/// la zi până ieri. Pentru zilele care lipsesc: reanaliza ERA5.
class WeatherCollector {
  static Future<List<WeatherDay>> fetchRange(
    Place place,
    DateTime from,
    DateTime to,
  ) async {
    final today = DateTime.now();
    final yesterday = DateTime(today.year, today.month, today.day - 1);
    if (to.isAfter(yesterday)) to = yesterday;
    if (from.isAfter(to)) return [];

    final days = {
      for (final d in await _fetch(
        place,
        from,
        to,
        'ecmwf_ifs',
        'ECMWF IFS 9 km',
      ))
        d.key: d,
    };
    var missing = false;
    for (
      var d = from;
      !d.isAfter(to);
      d = DateTime(d.year, d.month, d.day + 1)
    ) {
      if (!days.containsKey(WeatherDay.keyFor(d))) missing = true;
    }
    if (missing) {
      for (final d in await _fetch(place, from, to, 'era5_seamless', 'ERA5')) {
        days.putIfAbsent(d.key, () => d);
      }
    }
    return days.values.toList();
  }

  static Future<List<WeatherDay>> _fetch(
    Place place,
    DateTime from,
    DateTime to,
    String model,
    String sourceLabel,
  ) async {
    final j = await getJsonWithRetry(
      Uri.https('archive-api.open-meteo.com', '/v1/archive', {
        'latitude': '${place.lat}',
        'longitude': '${place.lng}',
        'start_date': WeatherDay.keyFor(from),
        'end_date': WeatherDay.keyFor(to),
        'daily':
            'temperature_2m_min,temperature_2m_max,precipitation_sum,'
            'wind_speed_10m_max,wind_direction_10m_dominant',
        'hourly': 'pressure_msl',
        'models': model,
        'timezone': 'Europe/Bucharest',
      }),
    );
    double? n(dynamic v) => (v as num?)?.toDouble();

    // presiunea orară grupată pe zile
    final h = j['hourly'] as Map<String, dynamic>;
    final hTimes = (h['time'] as List).cast<String>();
    final pressureByDay = <String, List<double>>{};
    for (var i = 0; i < hTimes.length; i++) {
      final p = n(h['pressure_msl'][i]);
      if (p == null) continue;
      pressureByDay.putIfAbsent(hTimes[i].substring(0, 10), () => []).add(p);
    }

    final d = j['daily'] as Map<String, dynamic>;
    final days = <WeatherDay>[];
    final times = (d['time'] as List).cast<String>();
    for (var i = 0; i < times.length; i++) {
      final ps = pressureByDay[times[i]] ?? const [];
      final tMin = n(d['temperature_2m_min'][i]);
      if (tMin == null || ps.length < 12) continue; // zi incompletă
      days.add(
        WeatherDay(
          date: DateTime.parse(times[i]),
          tMin: tMin,
          tMax: n(d['temperature_2m_max'][i]) ?? tMin,
          pMin: ps.reduce((a, b) => a < b ? a : b),
          pMax: ps.reduce((a, b) => a > b ? a : b),
          pAvg: ps.reduce((a, b) => a + b) / ps.length,
          pChange: ps.last - ps.first,
          windMax: n(d['wind_speed_10m_max'][i]) ?? 0,
          windDir: n(d['wind_direction_10m_dominant'][i]) ?? 0,
          precip: n(d['precipitation_sum'][i]) ?? 0,
          source: sourceLabel,
        ),
      );
    }
    return days;
  }
}
