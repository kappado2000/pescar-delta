import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../services/location_service.dart';
import '../services/weather_service.dart';

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key, this.spotId});

  /// Când e deschis de pe hartă, pentru un loc anume.
  final String? spotId;

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  /// `tulcea`, `gps` sau id-ul unui loc salvat.
  late String _source = widget.spotId ?? 'tulcea';
  Future<Forecast>? _future;
  String _placeName = 'Tulcea';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final store = context.read<AppStore>();
    double lat = defaultLat, lng = defaultLng;
    String name = 'Tulcea';
    if (_source == 'gps') {
      final pos = await LocationService.current();
      if (pos != null) {
        lat = pos.latitude;
        lng = pos.longitude;
        name = 'Poziția mea';
      } else {
        name = 'Tulcea (GPS indisponibil)';
      }
    } else if (store.spot(_source) case final s?) {
      lat = s.lat;
      lng = s.lng;
      name = s.name;
    }
    if (!mounted) return;
    setState(() {
      _placeName = name;
      _future = WeatherService.fetch(lat, lng);
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final sources = {
      'tulcea': 'Tulcea',
      'gps': 'Poziția mea',
      for (final s in store.spots) s.id: s.name,
    };
    if (!sources.containsKey(_source)) _source = 'tulcea';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vreme și presiune'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.place_outlined),
            initialValue: _source,
            onSelected: (v) {
              _source = v;
              _load();
            },
            itemBuilder: (_) => [
              for (final e in sources.entries)
                PopupMenuItem(value: e.key, child: Text(e.value)),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: FutureBuilder<Forecast>(
          future: _future,
          builder: (context, snap) {
            if (snap.hasError) {
              return ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Nu am putut încărca prognoza.\n${snap.error}\n\n'
                      'Trage în jos pentru a reîncerca.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              );
            }
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            return _ForecastView(forecast: snap.data!, place: _placeName);
          },
        ),
      ),
    );
  }
}

class _ForecastView extends StatelessWidget {
  const _ForecastView({required this.forecast, required this.place});
  final Forecast forecast;
  final String place;

  @override
  Widget build(BuildContext context) {
    final f = forecast;
    final c = f.current;
    final text = Theme.of(context).textTheme;
    final trend = f.pressureTrend3h;
    final moon = moonFor(DateTime.now());
    final trendText = trend.abs() < 1
        ? 'stabilă'
        : trend < 0
        ? 'în scădere (${trend.toStringAsFixed(1)} hPa/3h)'
        : 'în creștere (+${trend.toStringAsFixed(1)} hPa/3h)';
    final today = f.days.isNotEmpty ? f.days.first : null;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(place, style: text.titleMedium),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '${c.temp.toStringAsFixed(0)}°',
                      style: text.displayMedium,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Presiune ${c.pressure.toStringAsFixed(0)} hPa'),
                          Text(trendText, style: text.bodySmall),
                          Text(
                            'Vânt ${c.wind.toStringAsFixed(0)} km/h ${windDirName(c.windDir)}',
                          ),
                          Text(
                            '${moon.emoji} ${moon.name} (${(moon.illumination * 100).round()}%)',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (today != null) ...[
                  const Divider(height: 24),
                  _ScoreRow(day: today, label: 'Azi'),
                ],
              ],
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 8, bottom: 8),
                  child: Text(
                    'Presiunea atmosferică (hPa)',
                    style: text.titleSmall,
                  ),
                ),
                SizedBox(height: 180, child: _PressureChart(hours: f.hours)),
              ],
            ),
          ),
        ),
        for (final d in f.days.skip(1))
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: _ScoreRow(
                day: d,
                label: DateFormat('EEEE, d MMM').format(d.date),
              ),
            ),
          ),
        const Padding(
          padding: EdgeInsets.all(8),
          child: Text(
            'Scorul combină tendința presiunii, vântul, faza lunii și ploaia. '
            'Cele mai bune ore sunt de obicei în jurul răsăritului și apusului.',
            style: TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class _ScoreRow extends StatelessWidget {
  const _ScoreRow({required this.day, required this.label});
  final DayForecast day;
  final String label;

  @override
  Widget build(BuildContext context) {
    final hm = DateFormat('HH:mm');
    final color = switch (day.score) {
      >= 8 => Colors.green,
      >= 6 => Colors.lightGreen,
      >= 4 => Colors.orange,
      _ => Colors.red,
    };
    final dawn = day.sunrise.subtract(const Duration(hours: 1));
    final dusk = day.sunset.subtract(const Duration(hours: 1));
    return Row(
      children: [
        CircleAvatar(
          backgroundColor: color,
          child: Text(
            '${day.score}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$label · ${day.scoreLabel}',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Text(
                '${day.tMin.toStringAsFixed(0)}°/${day.tMax.toStringAsFixed(0)}° · '
                'vânt max ${day.windMax.toStringAsFixed(0)} km/h · '
                'ploaie ${day.precip.toStringAsFixed(1)} mm · ${day.moon.emoji}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                'Ore bune: ${hm.format(dawn)}–${hm.format(day.sunrise.add(const Duration(hours: 2)))}'
                ' și ${hm.format(dusk)}–${hm.format(day.sunset.add(const Duration(hours: 1)))}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PressureChart extends StatelessWidget {
  const _PressureChart({required this.hours});
  final List<HourPoint> hours;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t0 = hours.first.time;
    final spots = [
      for (final h in hours)
        FlSpot(h.time.difference(t0).inMinutes / 60, h.pressure),
    ];
    final now = DateTime.now().difference(t0).inMinutes / 60;
    final minY =
        spots.map((s) => s.y).reduce((a, b) => a < b ? a : b).floorToDouble() -
        2;
    final maxY =
        spots.map((s) => s.y).reduce((a, b) => a > b ? a : b).ceilToDouble() +
        2;
    return LineChart(
      LineChartData(
        minY: minY,
        maxY: maxY,
        gridData: const FlGridData(drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        extraLinesData: ExtraLinesData(
          verticalLines: [
            VerticalLine(
              x: now,
              color: scheme.tertiary,
              strokeWidth: 1,
              dashArray: [4, 4],
              label: VerticalLineLabel(
                show: true,
                labelResolver: (_) => 'acum',
              ),
            ),
          ],
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 40),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 24,
              getTitlesWidget: (v, meta) => Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  DateFormat('EEE').format(t0.add(Duration(hours: v.round()))),
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (items) => [
              for (final i in items)
                LineTooltipItem(
                  '${DateFormat('EEE HH:mm').format(t0.add(Duration(minutes: (i.x * 60).round())))}\n'
                  '${i.y.toStringAsFixed(1)} hPa',
                  const TextStyle(color: Colors.white, fontSize: 12),
                ),
            ],
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: scheme.primary,
            barWidth: 2.5,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: scheme.primary.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }
}
