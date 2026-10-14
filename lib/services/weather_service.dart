import 'dart:math';

import '../models/catch_entry.dart';
import 'http_retry.dart';

/// Tulcea — poarta Deltei; locația implicită.
const defaultLat = 45.1787;
const defaultLng = 28.8050;

/// Modelele comparate pentru prognoză (consens = mediana lor).
const forecastModels = {
  'ecmwf_ifs025': 'ECMWF',
  'icon_seamless': 'ICON (DWD)',
  'meteofrance_seamless': 'ARPEGE (Météo-France)',
  'gfs_seamless': 'GFS (NOAA)',
  'ukmo_seamless': 'UKMO',
};

class HourPoint {
  HourPoint({
    required this.time,
    required this.temp,
    required this.pressure,
    required this.wind,
    required this.windDir,
    required this.precip,
    this.tempSpread = 0,
    this.windSpread = 0,
    this.pressureSpread = 0,
    this.models = 1,
  });
  final DateTime time;
  final double temp;
  final double pressure;
  final double wind;
  final double windDir;

  /// Precipitații în ora respectivă (mm).
  final double precip;

  /// Diferența dintre cel mai mare și cel mai mic model.
  final double tempSpread;
  final double windSpread;
  final double pressureSpread;

  /// Câte modele au avut date pentru ora asta.
  final int models;
}

class DayForecast {
  DayForecast({
    required this.date,
    required this.tMin,
    required this.tMax,
    required this.windMax,
    required this.precip,
    required this.sunrise,
    required this.sunset,
    required this.pressureChange,
    required this.score,
    required this.moon,
    required this.certainty,
    required this.models,
  });

  final DateTime date;
  final double tMin;
  final double tMax;
  final double windMax;
  final double precip;
  final DateTime sunrise;
  final DateTime sunset;

  /// Variația presiunii pe parcursul zilei (hPa).
  final double pressureChange;
  final int score;
  final MoonInfo moon;

  /// 0–1: cât de mult se potrivesc modelele între ele.
  final double certainty;
  final int models;

  String get scoreLabel => switch (score) {
    >= 8 => 'Excelentă',
    >= 6 => 'Bună',
    >= 4 => 'Medie',
    _ => 'Slabă',
  };

  String get certaintyLabel => certainty >= 0.7
      ? 'Sigură'
      : certainty >= 0.45
      ? 'Probabilă'
      : 'Incertă';
}

class Forecast {
  Forecast(this.current, this.hours, this.days, this.modelNames);
  final HourPoint current;
  final List<HourPoint> hours;
  final List<DayForecast> days;

  /// Modelele care au contribuit la consens.
  final List<String> modelNames;

  /// Tendința presiunii în ultimele 3 ore (hPa).
  double get pressureTrend3h {
    final now = DateTime.now();
    final past = hours
        .where((h) => h.time.isBefore(now.subtract(const Duration(hours: 3))))
        .lastOrNull;
    return past == null ? 0 : current.pressure - past.pressure;
  }
}

class MoonInfo {
  MoonInfo(this.age, this.illumination);

  /// Zile de la luna nouă (0 – 29.53).
  final double age;
  final double illumination;

  String get name => switch (age) {
    < 1.85 => 'Lună nouă',
    < 5.54 => 'Semilună crescătoare',
    < 9.23 => 'Primul pătrar',
    < 12.92 => 'Gibboasă crescătoare',
    < 16.61 => 'Lună plină',
    < 20.30 => 'Gibboasă descrescătoare',
    < 23.99 => 'Ultimul pătrar',
    < 27.68 => 'Semilună descrescătoare',
    _ => 'Lună nouă',
  };

  String get emoji => switch (age) {
    < 1.85 => '🌑',
    < 5.54 => '🌒',
    < 9.23 => '🌓',
    < 12.92 => '🌔',
    < 16.61 => '🌕',
    < 20.30 => '🌖',
    < 23.99 => '🌗',
    < 27.68 => '🌘',
    _ => '🌑',
  };
}

const _synodicMonth = 29.530588853;

MoonInfo moonFor(DateTime date) {
  final knownNewMoon = DateTime.utc(2000, 1, 6, 18, 14);
  final days = date.toUtc().difference(knownNewMoon).inMinutes / 1440.0;
  final age = (days % _synodicMonth + _synodicMonth) % _synodicMonth;
  final illumination = (1 - cos(2 * pi * age / _synodicMonth)) / 2;
  return MoonInfo(age, illumination);
}

/// Scor 0–10 pe baza presiunii, vântului, lunii și precipitațiilor.
int fishingScore({
  required double pressureChange,
  required double windMax,
  required double precip,
  required MoonInfo moon,
}) {
  var s = 5.0;
  final dp = pressureChange;
  if (dp.abs() < 3) {
    s += 2; // presiune stabilă
  } else if (dp <= -3 && dp > -7) {
    s += 1; // scădere lentă — peștele se hrănește înaintea frontului
  } else if (dp <= -7) {
    s -= 2;
  } else if (dp >= 6) {
    s -= 1; // creștere bruscă după front
  }
  if (windMax < 15) {
    s += 1;
  } else if (windMax > 35) {
    s -= 2;
  } else if (windMax > 25) {
    s -= 1;
  }
  final distToNewOrFull = min(
    min(moon.age, _synodicMonth - moon.age),
    (moon.age - _synodicMonth / 2).abs(),
  );
  if (distToNewOrFull < 2) s += 1;
  if (precip > 10) s -= 1;
  return s.round().clamp(0, 10);
}

double _median(List<double> v) {
  final s = v.toList()..sort();
  final m = s.length ~/ 2;
  return s.length.isOdd ? s[m] : (s[m - 1] + s[m]) / 2;
}

double _spread(List<double> v) =>
    v.length < 2 ? 0 : v.reduce(max) - v.reduce(min);

class WeatherService {
  /// Prognoza pe 7 zile ca mediană a 5 modele (ECMWF, ICON, ARPEGE, GFS,
  /// UKMO); diferențele dintre ele dau gradul de siguranță.
  static Future<Forecast> fetch(double lat, double lng) async {
    final j = await getJsonWithRetry(
      Uri.https('api.open-meteo.com', '/v1/forecast', {
        'latitude': '$lat',
        'longitude': '$lng',
        'hourly': 'temperature_2m,pressure_msl,wind_speed_10m,wind_direction_10m,precipitation',
        'daily': 'sunrise,sunset',
        'models': forecastModels.keys.join(','),
        'timezone': 'Europe/Bucharest',
        'past_days': '1',
        'forecast_days': '7',
      }),
    );

    final h = j['hourly'] as Map<String, dynamic>;
    final times = (h['time'] as List).cast<String>();
    List<double> values(String variable, int i) => [
      for (final m in forecastModels.keys)
        if ((h['${variable}_$m'] as List?)?[i] case final num v) v.toDouble(),
    ];

    final usedModels = <String>{};
    final hours = <HourPoint>[];
    for (var i = 0; i < times.length; i++) {
      final t = values('temperature_2m', i);
      final p = values('pressure_msl', i);
      final w = values('wind_speed_10m', i);
      if (t.isEmpty || p.isEmpty || w.isEmpty) continue;
      for (final m in forecastModels.keys) {
        if ((h['temperature_2m_$m'] as List?)?[i] != null) usedModels.add(m);
      }
      final dirs = values('wind_direction_10m', i);
      final pr = values('precipitation', i);
      hours.add(
        HourPoint(
          time: DateTime.parse(times[i]),
          temp: _median(t),
          pressure: _median(p),
          wind: _median(w),
          // direcția: ECMWF (primul model) — mediana unghiurilor nu are sens
          windDir: dirs.isEmpty ? 0 : dirs.first,
          precip: pr.isEmpty ? 0 : _median(pr),
          tempSpread: _spread(t),
          windSpread: _spread(w),
          pressureSpread: _spread(p),
          models: t.length,
        ),
      );
    }
    if (hours.isEmpty) throw Exception('Prognoză indisponibilă');

    final now = DateTime.now();
    final current = hours.lastWhere(
      (x) => !x.time.isAfter(now),
      orElse: () => hours.first,
    );

    // răsărit/apus: același pentru toate modelele, luăm prima coloană
    final d = j['daily'] as Map<String, dynamic>;
    List<String> col(String prefix) =>
        (d.entries.firstWhere((e) => e.key.startsWith(prefix)).value as List)
            .map((e) => e?.toString() ?? '')
            .toList();
    final dayTimes = (d['time'] as List).cast<String>();
    final sunrises = col('sunrise');
    final sunsets = col('sunset');

    final todayDate = DateTime(now.year, now.month, now.day);
    final days = <DayForecast>[];
    for (var i = 0; i < dayTimes.length; i++) {
      final date = DateTime.parse(dayTimes[i]);
      // ziua trecută e doar pentru tendința presiunii
      if (date.isBefore(todayDate)) continue;
      final dh = hours
          .where(
            (p) =>
                p.time.year == date.year &&
                p.time.month == date.month &&
                p.time.day == date.day,
          )
          .toList();
      if (dh.isEmpty) continue;
      double avg(double Function(HourPoint) f) =>
          dh.map(f).reduce((a, b) => a + b) / dh.length;
      final dp = dh.last.pressure - dh.first.pressure;
      final windMax = dh.map((x) => x.wind).reduce(max);
      final precip = dh.fold<double>(0, (s, x) => s + x.precip);
      final moon = moonFor(date.add(const Duration(hours: 12)));
      // siguranța scade cu împrăștierea modelelor (°C, km/h, hPa)
      final disagreement =
          (avg((x) => x.tempSpread) / 6 +
              avg((x) => x.windSpread) / 25 +
              avg((x) => x.pressureSpread) / 8) /
          3;
      days.add(
        DayForecast(
          date: date,
          tMin: dh.map((x) => x.temp).reduce(min),
          tMax: dh.map((x) => x.temp).reduce(max),
          windMax: windMax,
          precip: precip,
          sunrise:
              DateTime.tryParse(sunrises[i]) ??
              date.add(const Duration(hours: 7)),
          sunset:
              DateTime.tryParse(sunsets[i]) ??
              date.add(const Duration(hours: 19)),
          pressureChange: dp,
          moon: moon,
          certainty: (1 - disagreement).clamp(0.0, 1.0),
          models: dh.map((x) => x.models).reduce(min),
          score: fishingScore(
            pressureChange: dp,
            windMax: windMax,
            precip: precip,
            moon: moon,
          ),
        ),
      );
    }
    return Forecast(current, hours, days, [
      for (final m in forecastModels.keys)
        if (usedModels.contains(m)) forecastModels[m]!,
    ]);
  }

  /// Vremea curentă pentru salvarea odată cu o captură (null dacă e offline).
  static Future<WeatherSnapshot?> snapshot(double lat, double lng) async {
    try {
      final f = await fetch(lat, lng);
      return WeatherSnapshot(
        tempC: f.current.temp,
        pressureHpa: f.current.pressure,
        windKmh: f.current.wind,
        windDir: f.current.windDir,
      );
    } catch (_) {
      return null;
    }
  }
}

String windDirName(double deg) {
  const names = ['N', 'NE', 'E', 'SE', 'S', 'SV', 'V', 'NV'];
  return names[((deg % 360) / 45).round() % 8];
}
