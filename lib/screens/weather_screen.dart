import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import 'home_shell.dart';
import '../models/place.dart';
import '../models/season.dart';
import '../models/weather_day.dart';
import '../services/location_service.dart';
import '../services/weather_service.dart';
import '../theme.dart';
import '../widgets/delta_scene.dart';

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key, this.spotId});

  /// Când e deschis de pe hartă, pentru un loc anume.
  final String? spotId;

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  /// `season` (locația sezonului curent), `gps`, `place:<key>` sau id de loc.
  late String _source = widget.spotId ?? 'season';
  Future<Forecast>? _future;
  String _placeName = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Place _seasonPlace(AppStore store) =>
      store.currentSeason?.place ?? sfantuGheorghe;

  Future<void> _load() async {
    final store = context.read<AppStore>();
    var place = _seasonPlace(store);
    var name = place.name;
    if (_source == 'gps') {
      final pos = await LocationService.current();
      if (pos != null) {
        place = Place('Poziția mea', pos.latitude, pos.longitude);
        name = 'Poziția mea';
      } else {
        name = '${place.name} (GPS indisponibil)';
      }
    } else if (_source.startsWith('place:')) {
      place = deltaPlaces.firstWhere(
        (p) => p.key == _source.substring(6),
        orElse: () => place,
      );
      name = place.name;
    } else if (store.spot(_source) case final s?) {
      place = Place(s.name, s.lat, s.lng);
      name = s.name;
    }
    if (!mounted) return;
    setState(() {
      _placeName = name;
      _future = WeatherService.fetch(place.lat, place.lng);
    });
    store.collectWeather();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final seasonPlace = _seasonPlace(store);
    final sources = {
      'season': '${seasonPlace.name} (sezonul curent)',
      'gps': 'Poziția mea',
      for (final p in deltaPlaces)
        if (p.key != seasonPlace.key) 'place:${p.key}': p.name,
      for (final s in store.spots) s.id: '📍 ${s.name}',
    };
    if (!sources.containsKey(_source)) _source = 'season';
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: SceneAppBar(
          title: 'Vremea',
          subtitle: _placeName,
          height: 112,
          actions: [
            PopupMenuButton<String>(
              tooltip: 'Alege locația',
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
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Prognoză 7 zile'),
              Tab(text: 'Istoric sezon'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            RefreshIndicator(
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
            const _HistoryView(),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// Prognoză
// =====================================================================

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
        ? 'în scădere (${trend.toStringAsFixed(1)} hPa în 3 ore)'
        : 'în creștere (+${trend.toStringAsFixed(1)} hPa în 3 ore)';

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12 + kBannerSpace),
      children: [
        // ---------- acum ----------
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(
                  '${c.temp.toStringAsFixed(0)}°',
                  style: text.displayMedium?.copyWith(
                    fontWeight: FontWeight.w300,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Acum la $place', style: text.titleSmall),
                      Text(
                        'Presiune ${c.pressure.toStringAsFixed(0)} hPa, $trendText',
                      ),
                      Text(
                        'Vânt ${c.wind.toStringAsFixed(0)} km/h din ${windDirName(c.windDir)}',
                      ),
                      Text(
                        '${moon.emoji} ${moon.name} (${(moon.illumination * 100).round()}%)',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // ---------- banda celor 7 zile ----------
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            child: Row(
              children: [
                for (final d in f.days)
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _openHours(context, f, d, place),
                      child: _DayColumn(day: d),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // ---------- presiunea ----------
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

        // ---------- detaliu pe fiecare zi ----------
        for (final (i, d) in f.days.indexed)
          Card(
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => _openHours(context, f, d, place),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: _DayDetail(day: d, label: _dayLabel(i, d.date)),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            'Prognoză de consens: mediana modelelor ${f.modelNames.join(', ')}. '
            '„Sigură” = modelele se potrivesc; „Incertă” = diferă mult între ele. '
            'Scorul de pescuit combină tendința presiunii, vântul, luna și ploaia.',
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }
}

Color _scoreColor(int score) => switch (score) {
  >= 8 => Sea.good,
  >= 6 => Sea.teal,
  >= 4 => Sea.ok,
  _ => Sea.bad,
};

Color _certaintyColor(double c) =>
    c >= 0.7 ? Sea.good : (c >= 0.45 ? Sea.ok : Sea.bad);

IconData _skyIcon(DayForecast d) => d.precip >= 5
    ? Icons.thunderstorm_outlined
    : d.precip >= 1
    ? Icons.water_drop_outlined
    : d.windMax >= 35
    ? Icons.air
    : Icons.wb_sunny_outlined;

/// Coloana unei zile în banda de 7 zile.
class _DayColumn extends StatelessWidget {
  const _DayColumn({required this.day});
  final DayForecast day;

  @override
  Widget build(BuildContext context) {
    final small = Theme.of(context).textTheme.bodySmall;
    final now = DateTime.now();
    final isToday = day.date.day == now.day && day.date.month == now.month;
    return Column(
      children: [
        Text(
          isToday ? 'Azi' : DateFormat('EEE').format(day.date),
          style: small?.copyWith(fontWeight: FontWeight.w700),
        ),
        Text(DateFormat('d.MM').format(day.date), style: small),
        const SizedBox(height: 6),
        Icon(
          _skyIcon(day),
          size: 22,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 4),
        Text(
          '${day.tMax.toStringAsFixed(0)}°',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        Text('${day.tMin.toStringAsFixed(0)}°', style: small),
        const SizedBox(height: 6),
        CircleAvatar(
          radius: 12,
          backgroundColor: _scoreColor(day.score),
          child: Text(
            '${day.score}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 22,
          height: 4,
          decoration: BoxDecoration(
            color: _certaintyColor(day.certainty),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }
}

class _DayDetail extends StatelessWidget {
  const _DayDetail({required this.day, required this.label});
  final DayForecast day;
  final String label;

  @override
  Widget build(BuildContext context) {
    final hm = DateFormat('HH:mm');
    final small = Theme.of(context).textTheme.bodySmall;
    final dawn = day.sunrise.subtract(const Duration(hours: 1));
    final dusk = day.sunset.subtract(const Duration(hours: 1));
    final dp = day.pressureChange;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: _scoreColor(day.score),
          child: Text(
            '${day.score}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '$label · ${day.scoreLabel} de pescuit',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _certaintyColor(day.certainty)
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      day.certaintyLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _certaintyColor(day.certainty),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '🌡 ${day.tMin.toStringAsFixed(0)}° / ${day.tMax.toStringAsFixed(0)}°   '
                '💨 max ${day.windMax.toStringAsFixed(0)} km/h   '
                '💧 ${day.precip.toStringAsFixed(1)} mm',
              ),
              Text(
                'Presiune ${dp.abs() < 3
                    ? 'stabilă'
                    : dp < 0
                    ? 'în scădere'
                    : 'în creștere'} '
                '(${dp >= 0 ? '+' : ''}${dp.toStringAsFixed(1)} hPa) · '
                '${day.moon.emoji} ${day.moon.name}',
                style: small,
              ),
              Text(
                'Ore bune: ${hm.format(dawn)}–${hm.format(day.sunrise.add(const Duration(hours: 2)))}'
                ' și ${hm.format(dusk)}–${hm.format(day.sunset.add(const Duration(hours: 1)))}',
                style: small,
              ),
              if (day.reasons.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    'Scor: 5 ${day.reasons.map((r) => '· $r').join(' ')} = ${day.score}',
                    style: small?.copyWith(fontStyle: FontStyle.italic),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

String _dayLabel(int i, DateTime date) => i == 0
    ? 'Azi'
    : i == 1
    ? 'Mâine'
    : toBeginningOfSentenceCase(DateFormat('EEEE, d MMM').format(date));

void _openHours(BuildContext context, Forecast f, DayForecast d, String place) {
  final i = f.days.indexOf(d);
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => _DayHoursScreen(
        day: d,
        allHours: f.hours,
        hours: f.hours
            .where(
              (h) =>
                  h.time.year == d.date.year &&
                  h.time.month == d.date.month &&
                  h.time.day == d.date.day,
            )
            .toList(),
        title: _dayLabel(i, d.date),
        place: place,
      ),
    ),
  );
}

/// O zi de prognoză defalcată pe ore.
class _DayHoursScreen extends StatelessWidget {
  const _DayHoursScreen({
    required this.day,
    required this.allHours,
    required this.hours,
    required this.title,
    required this.place,
  });
  final DayForecast day;
  final List<HourPoint> allHours;
  final List<HourPoint> hours;
  final String title;

  HourPoint? _before3h(HourPoint h) {
    final t = h.time.subtract(const Duration(hours: 3));
    return allHours.where((x) => x.time == t).firstOrNull;
  }

  final String place;

  bool _good(DateTime t) {
    final dawn0 = day.sunrise.subtract(const Duration(hours: 1));
    final dawn1 = day.sunrise.add(const Duration(hours: 2));
    final dusk0 = day.sunset.subtract(const Duration(hours: 1));
    final dusk1 = day.sunset.add(const Duration(hours: 1));
    final end = t.add(const Duration(minutes: 59));
    return (end.isAfter(dawn0) && t.isBefore(dawn1)) ||
        (end.isAfter(dusk0) && t.isBefore(dusk1));
  }

  IconData _sky(HourPoint h) {
    final night = h.time.isBefore(day.sunrise) || h.time.isAfter(day.sunset);
    if (h.precip >= 1) return Icons.water_drop;
    if (h.precip >= 0.2) return Icons.grain;
    if (h.wind >= 35) return Icons.air;
    return night ? Icons.nightlight_round : Icons.wb_sunny_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final hm = DateFormat('HH:mm');
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    return Scaffold(
      appBar: AppBar(title: Text('$title · $place')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: _DayDetail(day: day, label: title),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 6),
                    child: Text(
                      'Presiunea în cursul zilei (hPa)',
                      style: text.titleSmall,
                    ),
                  ),
                  if (hours.length > 1)
                    SizedBox(height: 150, child: _PressureChart(hours: hours)),
                  Padding(
                    padding: const EdgeInsets.only(left: 8, top: 6),
                    child: Text(
                      '☀ răsărit ${hm.format(day.sunrise)} · apus ${hm.format(day.sunset)}',
                      style: text.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
            child: Row(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Sea.sunset.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '= oră bună de pescuit (zori / apus)',
                  style: text.bodySmall,
                ),
              ],
            ),
          ),
          for (final (i, h) in hours.indexed)
            Container(
              margin: const EdgeInsets.symmetric(vertical: 2),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: _good(h.time)
                    ? Sea.sunset.withValues(alpha: 0.18)
                    : scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color:
                      h.time.hour == now.hour &&
                          h.time.day == now.day &&
                          h.time.month == now.month
                      ? Sea.ocean
                      : scheme.outlineVariant.withValues(alpha: 0.5),
                  width: h.time.hour == now.hour && h.time.day == now.day
                      ? 2
                      : 0.6,
                ),
              ),
              child: Builder(
                builder: (context) {
                  final (score, why) = hourScore(h, _before3h(h), day);
                  final prev = i == 0 ? null : hours[i - 1];
                  final trend = prev == null
                      ? ''
                      : h.pressure - prev.pressure > 0.3
                      ? ' ↑'
                      : h.pressure - prev.pressure < -0.3
                      ? ' ↓'
                      : ' →';
                  final rain = rainLabel(h.precip);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          SizedBox(
                            width: 48,
                            child: Text(
                              hm.format(h.time),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Icon(_sky(h), size: 20, color: scheme.primary),
                          const SizedBox(width: 6),
                          SizedBox(
                            width: 40,
                            child: Text(
                              '${h.temp.toStringAsFixed(0)}°',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              '${h.pressure.toStringAsFixed(0)} hPa$trend · ☁ ${h.cloud.toStringAsFixed(0)}%',
                              style: text.bodySmall,
                            ),
                          ),
                          Tooltip(
                            message: 'Scorul de pescuit al orei',
                            child: CircleAvatar(
                              radius: 14,
                              backgroundColor: _scoreColor(score),
                              child: Text(
                                '$score',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Tooltip(
                            message: 'Cât de mult se potrivesc modelele',
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _certaintyColor(
                                  (1 -
                                          (h.tempSpread / 6 +
                                                  h.windSpread / 25 +
                                                  h.pressureSpread / 8) /
                                              3)
                                      .clamp(0.0, 1.0),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 48, top: 3),
                        child: Text(
                          '💨 ${h.wind.toStringAsFixed(0)} km/h ${windDirName(h.windDir)}'
                          '${h.gust >= h.wind + 5 ? ', rafale ${h.gust.toStringAsFixed(0)}' : ''}'
                          '${rain.isNotEmpty ? ' · 💧 ploaie $rain ${h.precip.toStringAsFixed(1)} mm' : ' · fără ploaie'}',
                          style: text.bodySmall,
                        ),
                      ),
                      if (why.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 48, top: 2),
                          child: Text(
                            why.join(' · '),
                            style: text.bodySmall?.copyWith(
                              fontStyle: FontStyle.italic,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              'Cercul cu cifră = scorul de pescuit al orei (0–10), cu motivele dedesubt. '
              'Bulina mică: verde = modelele se potrivesc, galben = probabil, '
              'roșu = incert. Ora curentă e încadrată cu albastru.',
              style: text.bodySmall,
            ),
          ),
        ],
      ),
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
    final ys = spots.map((s) => s.y);
    final minY = ys.reduce((a, b) => a < b ? a : b).floorToDouble() - 2;
    final maxY = ys.reduce((a, b) => a > b ? a : b).ceilToDouble() + 2;
    return LineChart(
      LineChartData(
        minY: minY,
        maxY: maxY,
        gridData: const FlGridData(drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        extraLinesData: ExtraLinesData(
          verticalLines: [
            // linia „acum” doar dacă ora curentă e în intervalul graficului
            if (now >= 0 && now <= spots.last.x)
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

// =====================================================================
// Istoric pe sezon (date colectate în locația sezonului)
// =====================================================================

class _HistoryView extends StatefulWidget {
  const _HistoryView();

  @override
  State<_HistoryView> createState() => _HistoryViewState();
}

class _HistoryViewState extends State<_HistoryView> {
  String? _seasonId;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final seasons = store.seasons.toList()
      ..sort((a, b) => b.start.compareTo(a.start));
    if (seasons.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Adaugă un sezon (cu locația lui) — vremea se colectează '
            'automat pe perioada sezonului.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final Season season =
        store.season(_seasonId) ?? store.currentSeason ?? seasons.first;
    final days = store.weatherForSeason(season);
    final text = Theme.of(context).textTheme;
    final sources = days
        .map((d) => d.source)
        .where((s) => s.isNotEmpty)
        .toSet();

    return RefreshIndicator(
      onRefresh: () async {
        final added = await store.collectWeather();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                added == 0 ? 'Datele sunt la zi.' : 'Am adăugat $added zile.',
              ),
            ),
          );
        }
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12 + kBannerSpace),
        children: [
          DropdownButtonFormField<String>(
            initialValue: season.id,
            decoration: const InputDecoration(labelText: 'Sezon'),
            items: [
              for (final s in seasons)
                DropdownMenuItem(
                  value: s.id,
                  child: Text('${s.title} · ${s.place.name}'),
                ),
            ],
            onChanged: (v) => setState(() => _seasonId = v),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: store.collectingWeather
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_download_outlined),
              title: Text(
                '${season.place.name} · ${days.length} zile colectate',
              ),
              subtitle: Text(
                days.isEmpty
                    ? (season.start.isAfter(DateTime.now())
                          ? 'Sezonul nu a început — colectarea pornește din '
                                '${DateFormat('d MMMM').format(season.start)}.'
                          : 'Se colectează automat când ai internet. '
                                'Trage în jos pentru a încerca acum.')
                    : 'Sursa: ${sources.join(' + ')} (date de analiză, '
                          'zi de zi). Trage în jos pentru actualizare.',
              ),
            ),
          ),
          if (days.length > 1)
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 8, bottom: 8),
                      child: Text(
                        'Presiunea medie zilnică (hPa) · '
                        'punctele portocalii = zile cu capturi',
                        style: text.titleSmall,
                      ),
                    ),
                    SizedBox(
                      height: 180,
                      child: _HistoryChart(
                        days: days.reversed.toList(),
                        catchDays: {
                          for (final c in store.catches)
                            WeatherDay.keyFor(c.date),
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          for (final d in days)
            _WeatherDayTile(
              day: d,
              catches: store.catches
                  .where((c) => WeatherDay.keyFor(c.date) == d.key)
                  .length,
            ),
        ],
      ),
    );
  }
}

class _WeatherDayTile extends StatelessWidget {
  const _WeatherDayTile({required this.day, required this.catches});
  final WeatherDay day;
  final int catches;

  @override
  Widget build(BuildContext context) {
    final d = day;
    final trendIcon = d.pChange.abs() < 3
        ? Icons.trending_flat
        : d.pChange < 0
        ? Icons.trending_down
        : Icons.trending_up;
    final trendColor = d.pChange.abs() < 3
        ? Sea.good
        : d.pChange < 0
        ? Sea.ok
        : Sea.bad;
    return Card(
      child: ListTile(
        leading: Icon(trendIcon, color: trendColor, size: 30),
        title: Text(
          toBeginningOfSentenceCase(
            DateFormat('EEEE, d MMM yyyy').format(d.date),
          ),
        ),
        subtitle: Text(
          '${d.tMin.toStringAsFixed(0)}°/${d.tMax.toStringAsFixed(0)}° · '
          '${d.pAvg.toStringAsFixed(0)} hPa '
          '(${d.pChange >= 0 ? '+' : ''}${d.pChange.toStringAsFixed(1)}) · '
          'vânt ${d.windMax.toStringAsFixed(0)} km/h ${windDirName(d.windDir)}'
          '${d.precip > 0.1 ? ' · ploaie ${d.precip.toStringAsFixed(1)} mm' : ''}',
        ),
        trailing: catches > 0
            ? Chip(
                visualDensity: VisualDensity.compact,
                avatar: const Icon(Icons.set_meal, size: 16),
                label: Text('$catches'),
              )
            : null,
      ),
    );
  }
}

class _HistoryChart extends StatelessWidget {
  const _HistoryChart({required this.days, required this.catchDays});

  /// Zilele în ordine cronologică.
  final List<WeatherDay> days;
  final Set<String> catchDays;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final spots = [
      for (var i = 0; i < days.length; i++) FlSpot(i.toDouble(), days[i].pAvg),
    ];
    final ys = spots.map((s) => s.y);
    final minY = ys.reduce((a, b) => a < b ? a : b).floorToDouble() - 2;
    final maxY = ys.reduce((a, b) => a > b ? a : b).ceilToDouble() + 2;
    final step = (days.length / 5).ceilToDouble().clamp(1, 1000).toDouble();
    return LineChart(
      LineChartData(
        minY: minY,
        maxY: maxY,
        gridData: const FlGridData(drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 40),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: step,
              getTitlesWidget: (v, _) {
                final i = v.round();
                if (i < 0 || i >= days.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    DateFormat('d MMM').format(days[i].date),
                    style: const TextStyle(fontSize: 10),
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (items) => [
              for (final it in items)
                LineTooltipItem(
                  '${DateFormat('d MMM').format(days[it.x.round()].date)}\n'
                  '${it.y.toStringAsFixed(1)} hPa',
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
            dotData: FlDotData(
              checkToShowDot: (s, _) =>
                  catchDays.contains(days[s.x.round()].key),
              getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                radius: 5,
                color: Sea.sunset,
                strokeColor: Colors.white,
                strokeWidth: 1.5,
              ),
            ),
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
