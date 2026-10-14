import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../models/catch_entry.dart';

/// Tulcea — poarta Deltei; locația implicită.
const defaultLat = 45.1787;
const defaultLng = 28.8050;

class HourPoint {
  HourPoint(
    this.time,
    this.temp,
    this.pressure,
    this.wind,
    this.windDir,
    this.precipProb,
  );
  final DateTime time;
  final double temp;
  final double pressure;
  final double wind;
  final double windDir;
  final double precipProb;
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

  String get scoreLabel => switch (score) {
    >= 8 => 'Excelentă',
    >= 6 => 'Bună',
    >= 4 => 'Medie',
    _ => 'Slabă',
  };
}

class Forecast {
  Forecast(this.current, this.hours, this.days);
  final HourPoint current;
  final List<HourPoint> hours;
  final List<DayForecast> days;

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

class WeatherService {
  static Future<Forecast> fetch(double lat, double lng) async {
    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': '$lat',
      'longitude': '$lng',
      'current': 'temperature_2m,pressure_msl,wind_speed_10m,wind_direction_10m,precipitation_probability',
      'hourly': 'temperature_2m,pressure_msl,wind_speed_10m,wind_direction_10m,precipitation_probability',
      'daily': 'temperature_2m_min,temperature_2m_max,wind_speed_10m_max,precipitation_sum,sunrise,sunset',
      'timezone': 'Europe/Bucharest',
      'past_days': '1',
      'forecast_days': '7',
    });
    final res = await http.get(uri).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw Exception('Open-Meteo a răspuns ${res.statusCode}');
    }
    final j = jsonDecode(res.body) as Map<String, dynamic>;

    double n(dynamic v) => (v as num?)?.toDouble() ?? 0;

    final h = j['hourly'] as Map<String, dynamic>;
    final times = (h['time'] as List).cast<String>();
    final hours = [
      for (var i = 0; i < times.length; i++)
        HourPoint(
          DateTime.parse(times[i]),
          n(h['temperature_2m'][i]),
          n(h['pressure_msl'][i]),
          n(h['wind_speed_10m'][i]),
          n(h['wind_direction_10m'][i]),
          n(h['precipitation_probability'][i]),
        ),
    ];

    final c = j['current'] as Map<String, dynamic>;
    final current = HourPoint(
      DateTime.parse(c['time']),
      n(c['temperature_2m']),
      n(c['pressure_msl']),
      n(c['wind_speed_10m']),
      n(c['wind_direction_10m']),
      n(c['precipitation_probability']),
    );

    final d = j['daily'] as Map<String, dynamic>;
    final dayTimes = (d['time'] as List).cast<String>();
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final days = <DayForecast>[];
    for (var i = 0; i < dayTimes.length; i++) {
      final date = DateTime.parse(dayTimes[i]);
      // ziua trecută e doar pentru tendința presiunii
      if (date.isBefore(todayDate)) continue;
      final dayHours = hours
          .where(
            (p) =>
                p.time.year == date.year &&
                p.time.month == date.month &&
                p.time.day == date.day,
          )
          .toList();
      final dp = dayHours.length > 1
          ? dayHours.last.pressure - dayHours.first.pressure
          : 0.0;
      final moon = moonFor(date.add(const Duration(hours: 12)));
      final windMax = n(d['wind_speed_10m_max'][i]);
      final precip = n(d['precipitation_sum'][i]);
      days.add(
        DayForecast(
          date: date,
          tMin: n(d['temperature_2m_min'][i]),
          tMax: n(d['temperature_2m_max'][i]),
          windMax: windMax,
          precip: precip,
          sunrise: DateTime.parse(d['sunrise'][i]),
          sunset: DateTime.parse(d['sunset'][i]),
          pressureChange: dp,
          moon: moon,
          score: fishingScore(
            pressureChange: dp,
            windMax: windMax,
            precip: precip,
            moon: moon,
          ),
        ),
      );
    }
    return Forecast(current, hours, days);
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
