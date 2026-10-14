/// Vremea observată într-o zi la stația de referință (Sfântu Gheorghe).
class WeatherDay {
  WeatherDay({
    required this.date,
    required this.tMin,
    required this.tMax,
    required this.pMin,
    required this.pMax,
    required this.pAvg,
    required this.pChange,
    required this.windMax,
    required this.windDir,
    required this.precip,
    this.source = '',
  });

  /// Ziua (fără oră).
  final DateTime date;
  final double tMin;
  final double tMax;
  final double pMin;
  final double pMax;
  final double pAvg;

  /// Variația presiunii de la 00:00 la 23:00 (hPa).
  final double pChange;
  final double windMax;

  /// Direcția dominantă a vântului (grade).
  final double windDir;
  final double precip;

  /// Modelul din care provin datele (ex. „ECMWF IFS 9 km”).
  final String source;

  String get key => keyFor(date);

  static String keyFor(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> toJson() => {
    'date': key,
    'tMin': tMin,
    'tMax': tMax,
    'pMin': pMin,
    'pMax': pMax,
    'pAvg': pAvg,
    'pChange': pChange,
    'windMax': windMax,
    'windDir': windDir,
    'precip': precip,
    'source': source,
  };

  factory WeatherDay.fromJson(Map<String, dynamic> j) {
    double n(String k) => (j[k] as num?)?.toDouble() ?? 0;
    return WeatherDay(
      date: DateTime.parse(j['date']),
      tMin: n('tMin'),
      tMax: n('tMax'),
      pMin: n('pMin'),
      pMax: n('pMax'),
      pAvg: n('pAvg'),
      pChange: n('pChange'),
      windMax: n('windMax'),
      windDir: n('windDir'),
      precip: n('precip'),
      source: j['source'] ?? '',
    );
  }
}
