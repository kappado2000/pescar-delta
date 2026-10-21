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
    this.gust = 0,
    this.cloud = 0,
    this.code = 0,
    this.precipProb,
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

  /// Rafale de vânt (km/h) și nebulozitate (%).
  final double gust;
  final double cloud;

  /// Starea cerului (cod WMO, consensul modelelor): 0 senin … 95 furtună.
  final int code;

  /// Probabilitatea de ploaie (%), unde modelele o dau.
  final double? precipProb;

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
    this.code = 0,
    this.precipProbMax,
    this.reasons = const [],
  });

  /// Starea cerului peste zi (cod WMO) — ce o să vezi afară între răsărit
  /// și apus.
  final int code;

  /// Cea mai mare probabilitate de ploaie din zi (%).
  final double? precipProbMax;

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

  /// De ce are scorul acesta (ex. „presiune stabilă +2”).
  final List<String> reasons;
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
bool _newOrFullMoon(MoonInfo moon) =>
    min(
      min(moon.age, _synodicMonth - moon.age),
      (moon.age - _synodicMonth / 2).abs(),
    ) <
    2;

String _signed(int v) => v > 0 ? '+$v' : '$v';

/// Scorul zilei (0–10) și motivele lui.
(int, List<String>) fishingScoreWhy({
  required double pressureChange,
  required double windMax,
  required double precip,
  required MoonInfo moon,
}) {
  var s = 5;
  final why = <String>[];
  void add(int v, String text) {
    s += v;
    why.add('$text ${_signed(v)}');
  }

  final dp = pressureChange;
  if (dp.abs() < 3) {
    add(2, 'presiune stabilă');
  } else if (dp <= -3 && dp > -7) {
    add(1, 'presiunea scade lent');
  } else if (dp <= -7) {
    add(-2, 'presiunea scade brusc');
  } else if (dp >= 6) {
    add(-1, 'presiunea crește brusc');
  }
  if (windMax < 15) {
    add(1, 'vânt slab');
  } else if (windMax > 35) {
    add(-2, 'vânt puternic');
  } else if (windMax > 25) {
    add(-1, 'vânt moderat');
  }
  if (_newOrFullMoon(moon)) add(1, moon.name.toLowerCase());
  if (precip > 10) add(-1, 'ploaie multă');
  return (s.clamp(0, 10), why);
}

int fishingScore({
  required double pressureChange,
  required double windMax,
  required double precip,
  required MoonInfo moon,
}) => fishingScoreWhy(
  pressureChange: pressureChange,
  windMax: windMax,
  precip: precip,
  moon: moon,
).$1;

/// Scorul unei ore (0–10) și motivele lui. [before3h] = ora de acum 3 ore.
(int, List<String>) hourScore(
  HourPoint h,
  HourPoint? before3h,
  DayForecast day,
) {
  var s = 5;
  final why = <String>[];
  void add(int v, String text) {
    s += v;
    why.add('$text ${_signed(v)}');
  }

  // presiunea în ultimele 3 ore
  if (before3h != null) {
    final dp = h.pressure - before3h.pressure;
    if (dp.abs() < 1) {
      add(1, 'presiune stabilă');
    } else if (dp <= -1 && dp > -2.5) {
      add(1, 'presiunea scade lent');
    } else if (dp <= -2.5) {
      add(-2, 'presiunea scade brusc');
    } else if (dp >= 2) {
      add(-1, 'presiunea crește brusc');
    }
  }
  // vânt și rafale
  if (h.wind < 10) {
    add(1, 'vânt slab');
  } else if (h.wind >= 30) {
    add(-2, 'vânt puternic');
  } else if (h.wind >= 20) {
    add(-1, 'vânt moderat');
  }
  if (h.gust >= 45) add(-1, 'rafale puternice');
  // ploaie
  if (h.precip >= 2) add(-1, 'ploaie puternică');
  // momentul zilei
  final t = h.time;
  final end = t.add(const Duration(minutes: 59));
  final dawn =
      end.isAfter(day.sunrise.subtract(const Duration(hours: 1))) &&
      t.isBefore(day.sunrise.add(const Duration(hours: 2)));
  final dusk =
      end.isAfter(day.sunset.subtract(const Duration(hours: 1))) &&
      t.isBefore(day.sunset.add(const Duration(hours: 1)));
  final night =
      t.isBefore(day.sunrise.subtract(const Duration(hours: 1))) ||
      t.isAfter(day.sunset.add(const Duration(hours: 1)));
  if (dawn) add(2, 'zori');
  if (dusk) add(2, 'apus');
  if (night && !dawn && !dusk) add(-1, 'noapte');
  if (h.temp >= 28 && t.hour >= 12 && t.hour <= 16) add(-1, 'căldură mare');
  if (_newOrFullMoon(day.moon)) add(1, day.moon.name.toLowerCase());
  return (s.clamp(0, 10), why);
}

String rainLabel(double mm) => mm >= 4
    ? 'puternică'
    : mm >= 1
    ? 'moderată'
    : mm >= 0.1
    ? 'slabă'
    : '';

double _median(List<double> v) {
  final s = v.toList()..sort();
  final m = s.length ~/ 2;
  return s.length.isOdd ? s[m] : (s[m - 1] + s[m]) / 2;
}

/// Starea cerului dintr-o oră, din codurile WMO ale modelelor plus mediana
/// ploii și a norilor (un singur model nu poate „câștiga” singur).
int skyCode({
  required List<int> codes,
  required double precip,
  required double cloud,
  required double temp,
}) {
  int votes(bool Function(int) f) => codes.where(f).length;
  final half = (codes.length / 2).ceil().clamp(1, 99);
  if (codes.isNotEmpty && votes((c) => c >= 95) >= max(2, half - 1)) {
    return 95;
  }
  if (precip >= 0.1) {
    final snow = votes((c) => (c >= 71 && c <= 77) || c == 85 || c == 86);
    if (snow >= half && temp < 2) {
      return precip >= 4 ? 75 : (precip >= 1 ? 73 : 71);
    }
    final showers = votes((c) => c >= 80 && c <= 82);
    final rain = votes((c) => c >= 61 && c <= 67);
    final drizzle = votes((c) => c >= 51 && c <= 57);
    if (drizzle > rain && drizzle >= showers && precip < 0.5) {
      return precip >= 0.3 ? 53 : 51;
    }
    if (showers > rain) return precip >= 4 ? 82 : (precip >= 1 ? 81 : 80);
    return precip >= 4 ? 65 : (precip >= 1 ? 63 : 61);
  }
  if (codes.isNotEmpty && votes((c) => c == 45 || c == 48) >= half) return 45;
  if (cloud < 20) return 0;
  if (cloud < 50) return 1;
  if (cloud < 85) return 2;
  return 3;
}

/// Starea zilei din orele dintre răsărit și apus: furtuna și ploaia au
/// prioritate, altfel norii în medie.
int daySkyCode(List<HourPoint> daylight) {
  if (daylight.isEmpty) return 0;
  if (daylight.any((h) => h.code >= 95)) return 95;
  final wet = daylight.where((h) => h.code >= 51).toList();
  final rainSum = wet.fold<double>(0, (s, h) => s + h.precip);
  if (wet.length >= 2 || rainSum >= 1) {
    // ora cu cea mai multă ploaie dă tipul (ploaie / averse / ninsoare)
    final code = wet.reduce((a, b) => b.precip > a.precip ? b : a).code;
    // burnița care ține toată ziua și adună ≥ 2 mm e de fapt ploaie
    if (code >= 51 && code <= 57 && rainSum >= 2) return 61;
    return code;
  }
  if (daylight.where((h) => h.code == 45).length >= 3) return 45;
  final cloud =
      daylight.fold<double>(0, (s, h) => s + h.cloud) / daylight.length;
  if (cloud < 20) return 0;
  if (cloud < 50) return 1;
  if (cloud < 85) return 2;
  return 3;
}

double _spread(List<double> v) =>
    v.length < 2 ? 0 : v.reduce(max) - v.reduce(min);

class WeatherService {
  /// Prognoza pe 7 zile ca mediană a 5 modele (ECMWF, ICON, ARPEGE, GFS,
  /// UKMO); diferențele dintre ele dau gradul de siguranță.
  static Future<Forecast> fetch(double lat, double lng) async =>
      parse(await fetchJson(lat, lng));

  /// Răspunsul brut al serviciului (se păstrează pentru zonele fără semnal).
  static Future<Map<String, dynamic>> fetchJson(double lat, double lng) =>
      getJsonWithRetry(
        Uri.https('api.open-meteo.com', '/v1/forecast', {
          'latitude': '$lat',
          'longitude': '$lng',
          'hourly':
              'temperature_2m,pressure_msl,wind_speed_10m,wind_direction_10m,'
              'precipitation,wind_gusts_10m,cloud_cover,weather_code,'
              'precipitation_probability',
          'daily': 'sunrise,sunset',
          'models': forecastModels.keys.join(','),
          'timezone': 'Europe/Bucharest',
          'past_days': '1',
          'forecast_days': '7',
        }),
      );

  /// Prognoza din răspunsul brut (proaspăt sau păstrat).
  static Forecast parse(Map<String, dynamic> j) {
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
      final gu = values('wind_gusts_10m', i);
      final cl = values('cloud_cover', i);
      final pp = values('precipitation_probability', i);
      final codes = values('weather_code', i).map((v) => v.round()).toList();
      final precipM = pr.isEmpty ? 0.0 : _median(pr);
      final cloudM = cl.isEmpty ? 0.0 : _median(cl);
      hours.add(
        HourPoint(
          time: DateTime.parse(times[i]),
          temp: _median(t),
          pressure: _median(p),
          wind: _median(w),
          // direcția: ECMWF (primul model) — mediana unghiurilor nu are sens
          windDir: dirs.isEmpty ? 0 : dirs.first,
          precip: precipM,
          gust: gu.isEmpty ? 0 : _median(gu),
          cloud: cloudM,
          code: skyCode(
            codes: codes,
            precip: precipM,
            cloud: cloudM,
            temp: _median(t),
          ),
          precipProb: pp.isEmpty ? null : _median(pp),
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
      final sunrise =
          DateTime.tryParse(sunrises[i]) ?? date.add(const Duration(hours: 7));
      final sunset =
          DateTime.tryParse(sunsets[i]) ?? date.add(const Duration(hours: 19));
      final daylight = dh
          .where(
            (x) =>
                !x.time.isBefore(
                  sunrise.subtract(const Duration(minutes: 59)),
                ) &&
                x.time.isBefore(sunset),
          )
          .toList();
      final probs = dh.map((x) => x.precipProb).whereType<double>();
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
          sunrise: sunrise,
          sunset: sunset,
          code: daySkyCode(daylight),
          precipProbMax: probs.isEmpty ? null : probs.reduce(max),
          pressureChange: dp,
          moon: moon,
          certainty: (1 - disagreement).clamp(0.0, 1.0),
          models: dh.map((x) => x.models).reduce(min),
          score: fishingScoreWhy(
            pressureChange: dp,
            windMax: windMax,
            precip: precip,
            moon: moon,
          ).$1,
          reasons: fishingScoreWhy(
            pressureChange: dp,
            windMax: windMax,
            precip: precip,
            moon: moon,
          ).$2,
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
