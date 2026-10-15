import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import 'home_shell.dart';
import '../models/awards.dart';
import '../models/catch_entry.dart';
import '../models/participant.dart';
import '../models/season.dart';
import '../services/weather_service.dart';
import '../theme.dart';
import '../widgets/delta_scene.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  /// null = toți anii; altfel id-ul unui sezon sau `an:<an>`.
  String? _filter;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final years = store.catches.map((c) => c.date.year).toSet().toList()
      ..sort((a, b) => b.compareTo(a));
    final seasons = store.seasons.toList()
      ..sort((a, b) => b.start.compareTo(a.start));
    final options = <String?, String>{
      null: 'Toate',
      for (final y in years) 'an:$y': 'Anul $y',
      for (final s in seasons) s.id: s.title,
    };
    if (!options.containsKey(_filter)) _filter = null;

    final list = store.catches.where((c) {
      if (_filter == null) return true;
      if (_filter!.startsWith('an:')) {
        return c.date.year == int.parse(_filter!.substring(3));
      }
      return store.season(_filter)?.contains(c.date) ?? false;
    }).toList();

    // Participanții înscriși în sezoanele din filtru.
    final filterSeasons = store.seasons.where((s) {
      if (_filter == null) return true;
      if (_filter!.startsWith('an:')) {
        return s.year == int.parse(_filter!.substring(3));
      }
      return s.id == _filter;
    });
    final enrolledIds = {
      for (final s in filterSeasons) ...s.participantIds,
      for (final c in list)
        if (c.participantId != null) c.participantId!,
    };
    final enrolled = store.participants
        .where((p) => enrolledIds.contains(p.id))
        .toList();

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: SceneAppBar(
          title: 'Statistici',
          subtitle: options[_filter],
          height: 112,
          time: SceneTime.dusk,
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Rezumat'),
              Tab(text: '🏆 Premii'),
              Tab(text: 'Participanți'),
              Tab(text: 'Pe zile'),
              Tab(text: 'Sortiment'),
            ],
          ),
          actions: [
            PopupMenuButton<String?>(
              icon: const Icon(Icons.filter_list),
              onSelected: (v) => setState(() => _filter = v),
              itemBuilder: (_) => [
                for (final e in options.entries)
                  CheckedPopupMenuItem(
                    value: e.key,
                    checked: e.key == _filter,
                    child: Text(e.value),
                  ),
              ],
            ),
          ],
        ),
        body: TabBarView(
          children: [
            list.isEmpty
                ? const _Empty()
                : _StatsBody(catches: list, title: options[_filter]!),
            list.isEmpty
                ? const _Empty()
                : _AwardsTab(catches: list, seasons: filterSeasons.toList()),
            _ParticipantsStats(catches: list, enrolled: enrolled),
            list.isEmpty ? const _Empty() : _DailyStats(catches: list),
            list.isEmpty ? const _Empty() : _SpeciesTable(catches: list),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) =>
      const Center(child: Text('Nicio captură în perioada aleasă.'));
}

String _kg(double v) => '${v.toStringAsFixed(v < 10 ? 2 : 1)} kg';
String _cm(double v) => '${v.toStringAsFixed(0)} cm';

/// Rândul unei capturi: (cine ·) specie · greutate · lungime.
String _catchLine(CatchEntry c, {String? who}) => [
  ?who,
  c.species,
  if (c.weightKg != null) _kg(c.weightKg!),
  if (c.lengthCm != null) _cm(c.lengthCm!),
  if (c.released) 'eliberat',
].join(' · ');

class _ParticipantsStats extends StatelessWidget {
  const _ParticipantsStats({required this.catches, required this.enrolled});
  final List<CatchEntry> catches;
  final List<Participant> enrolled;

  @override
  Widget build(BuildContext context) {
    if (enrolled.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Niciun participant înscris în perioada aleasă.\n'
            'Bifează participanții în sezon.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final text = Theme.of(context).textTheme;
    final rows = [
      for (final p in enrolled)
        (p, catches.where((c) => c.participantId == p.id).toList()),
    ]..sort((a, b) => _sumKg(b.$2).compareTo(_sumKg(a.$2)));
    final unassigned = catches.where((c) => c.participantId == null).length;

    String summary(Participant p, List<CatchEntry> list) {
      if (list.isEmpty) return '${p.category.label} · nicio captură';
      final maxKg = _max(list, (c) => c.weightKg);
      final maxCm = _max(list, (c) => c.lengthCm);
      return [
        '${list.length} capturi',
        _kg(_sumKg(list)),
        if (maxKg != null) 'max ${_kg(maxKg)}',
        if (maxCm != null) 'max ${_cm(maxCm)}',
      ].join(' · ');
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12 + kBannerSpace),
      children: [
        Text(
          '${enrolled.length} participanți înscriși',
          style: text.titleMedium,
        ),
        if (unassigned > 0)
          Text('$unassigned capturi fără pescar ales', style: text.bodySmall),
        const SizedBox(height: 8),
        for (final (i, (p, list)) in rows.indexed)
          Card(
            child: ExpansionTile(
              leading: CircleAvatar(child: Text('${i + 1}')),
              title: Text(p.fullName),
              subtitle: Text(summary(p, list)),
              children: [
                if (list.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final e in _speciesCount(list).entries)
                          Chip(
                            visualDensity: VisualDensity.compact,
                            label: Text('${e.key} ${e.value}'),
                          ),
                      ],
                    ),
                  ),
                for (final c in list)
                  ListTile(
                    dense: true,
                    title: Text(_catchLine(c)),
                    subtitle: Text(
                      DateFormat('EEE d MMM, HH:mm').format(c.date),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _DailyStats extends StatelessWidget {
  const _DailyStats({required this.catches});
  final List<CatchEntry> catches;

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    final text = Theme.of(context).textTheme;
    final byDay = <DateTime, List<CatchEntry>>{};
    for (final c in catches) {
      byDay
          .putIfAbsent(
            DateTime(c.date.year, c.date.month, c.date.day),
            () => [],
          )
          .add(c);
    }
    for (final l in byDay.values) {
      l.sort((a, b) => a.date.compareTo(b.date));
    }
    final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12 + kBannerSpace),
      children: [
        for (final d in days)
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('EEEE, d MMMM yyyy').format(d),
                    style: text.titleSmall,
                  ),
                  if (store.weatherOn(d) case final w?)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        '🌡 ${w.tMin.toStringAsFixed(0)}°/${w.tMax.toStringAsFixed(0)}°'
                        '  ⏲ ${w.pAvg.toStringAsFixed(0)} hPa '
                        '(${w.pChange >= 0 ? '+' : ''}${w.pChange.toStringAsFixed(1)})'
                        '  💨 ${w.windMax.toStringAsFixed(0)} km/h ${windDirName(w.windDir)}'
                        '${w.precip > 0.1 ? '  💧 ${w.precip.toStringAsFixed(1)} mm' : ''}',
                        style: text.bodySmall,
                      ),
                    ),
                  Text(
                    '${byDay[d]!.length} capturi · ${_kg(_sumKg(byDay[d]!))}'
                    ' · ${_speciesCount(byDay[d]!).entries.map((e) => '${e.key} ${e.value}').join(', ')}',
                    style: text.bodySmall,
                  ),
                  const Divider(),
                  for (final c in byDay[d]!)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 48,
                            child: Text(
                              DateFormat('HH:mm').format(c.date),
                              style: text.bodySmall,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              _catchLine(
                                c,
                                who: store
                                    .participant(c.participantId)
                                    ?.fullName,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Sortimentul pe specii (crap, caras, somn, știucă…): număr, kg total,
/// greutate și lungime maximă/medie.
class _SpeciesTable extends StatelessWidget {
  const _SpeciesTable({required this.catches});
  final List<CatchEntry> catches;

  @override
  Widget build(BuildContext context) {
    final bySpecies = <String, List<CatchEntry>>{};
    for (final c in catches) {
      bySpecies.putIfAbsent(c.species, () => []).add(c);
    }
    final rows = bySpecies.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));

    String avg(
      List<CatchEntry> l,
      double? Function(CatchEntry) f,
      String Function(double) fmt,
    ) {
      final v = l.map(f).whereType<double>().toList();
      return v.isEmpty ? '—' : fmt(v.reduce((a, b) => a + b) / v.length);
    }

    String maxOf(
      List<CatchEntry> l,
      double? Function(CatchEntry) f,
      String Function(double) fmt,
    ) {
      final m = _max(l, f);
      return m == null ? '—' : fmt(m);
    }

    const bold = TextStyle(fontWeight: FontWeight.bold);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12 + kBannerSpace),
      child: Card(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 18,
            columns: const [
              DataColumn(label: Text('Specie')),
              DataColumn(label: Text('Nr.'), numeric: true),
              DataColumn(label: Text('Total'), numeric: true),
              DataColumn(label: Text('Max'), numeric: true),
              DataColumn(label: Text('Medie'), numeric: true),
              DataColumn(label: Text('Lung. max'), numeric: true),
              DataColumn(label: Text('Lung. medie'), numeric: true),
            ],
            rows: [
              for (final e in rows)
                DataRow(
                  cells: [
                    DataCell(Text(e.key)),
                    DataCell(Text('${e.value.length}')),
                    DataCell(Text(_kg(_sumKg(e.value)))),
                    DataCell(Text(maxOf(e.value, (c) => c.weightKg, _kg))),
                    DataCell(Text(avg(e.value, (c) => c.weightKg, _kg))),
                    DataCell(Text(maxOf(e.value, (c) => c.lengthCm, _cm))),
                    DataCell(Text(avg(e.value, (c) => c.lengthCm, _cm))),
                  ],
                ),
              DataRow(
                cells: [
                  const DataCell(Text('TOTAL', style: bold)),
                  DataCell(Text('${catches.length}', style: bold)),
                  DataCell(Text(_kg(_sumKg(catches)), style: bold)),
                  const DataCell(Text('')),
                  const DataCell(Text('')),
                  const DataCell(Text('')),
                  const DataCell(Text('')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

double _sumKg(List<CatchEntry> l) =>
    l.fold<double>(0, (s, c) => s + (c.weightKg ?? 0));

double? _max(List<CatchEntry> l, double? Function(CatchEntry) f) {
  final v = l.map(f).whereType<double>();
  return v.isEmpty ? null : v.reduce((a, b) => a > b ? a : b);
}

Map<String, int> _speciesCount(List<CatchEntry> l) {
  final m = <String, int>{};
  for (final c in l) {
    m[c.species] = (m[c.species] ?? 0) + 1;
  }
  return Map.fromEntries(
    m.entries.toList()..sort((a, b) => b.value.compareTo(a.value)),
  );
}

class _StatsBody extends StatelessWidget {
  const _StatsBody({required this.catches, required this.title});
  final List<CatchEntry> catches;
  final String title;

  Map<String, int> _count(Iterable<String> keys) {
    final m = <String, int>{};
    for (final k in keys.where((k) => k.isNotEmpty)) {
      m[k] = (m[k] ?? 0) + 1;
    }
    return Map.fromEntries(
      m.entries.toList()..sort((a, b) => b.value.compareTo(a.value)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    final text = Theme.of(context).textTheme;
    final totalKg = catches.fold<double>(0, (s, c) => s + (c.weightKg ?? 0));
    final released = catches.where((c) => c.released).length;

    final records = <String, CatchEntry>{};
    for (final c in catches.where((c) => c.weightKg != null)) {
      final r = records[c.species];
      if (r == null || c.weightKg! > r.weightKg!) records[c.species] = c;
    }
    final sortedRecords = records.values.toList()
      ..sort((a, b) => b.weightKg!.compareTo(a.weightKg!));

    final bySpecies = _count(catches.map((c) => c.species));
    final byBait = _count(catches.map((c) => c.bait));
    final bySpot = _count(catches.map((c) => store.spot(c.spotId)?.name ?? ''));
    final byPerson = _count(
      catches.map((c) => store.participant(c.participantId)?.fullName ?? ''),
    );
    final byHour = List<int>.filled(24, 0);
    for (final c in catches) {
      byHour[c.date.hour]++;
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12 + kBannerSpace),
      children: [
        Text(title, style: text.titleMedium),
        const SizedBox(height: 8),
        Row(
          children: [
            _Tile(
              label: 'Capturi',
              value: '${catches.length}',
              icon: Icons.set_meal,
              color: Sea.ocean,
            ),
            _Tile(
              label: 'Total kg',
              value: totalKg.toStringAsFixed(1),
              icon: Icons.scale,
              color: Sea.teal,
            ),
            _Tile(
              label: 'Specii',
              value: '${bySpecies.length}',
              icon: Icons.category_outlined,
              color: Sea.sunset,
            ),
            _Tile(
              label: 'Eliberate',
              value: '$released',
              icon: Icons.water,
              color: Sea.coral,
            ),
          ],
        ),
        if (sortedRecords.isNotEmpty)
          _Section(
            title: '🏆 Recorduri pe specie',
            children: [
              for (final r in sortedRecords)
                ListTile(
                  dense: true,
                  title: Text(r.species),
                  subtitle: Text(
                    '${DateFormat('d MMM yyyy').format(r.date)}'
                    '${r.bait.isNotEmpty ? ' · ${r.bait}' : ''}'
                    '${store.participant(r.participantId) != null ? ' · ${store.participant(r.participantId)!.fullName}' : ''}',
                  ),
                  trailing: Text(
                    '${r.weightKg!.toStringAsFixed(2)} kg',
                    style: text.titleMedium,
                  ),
                ),
            ],
          ),
        _Section(
          title: 'Capturi pe oră',
          children: [SizedBox(height: 160, child: _HourChart(byHour: byHour))],
        ),
        _Ranking(title: 'Specii', data: bySpecies),
        _Ranking(title: 'Cele mai bune momeli', data: byBait),
        _Ranking(title: 'Cele mai bune locuri', data: bySpot),
        _Ranking(title: 'Pescari', data: byPerson),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
        color: color.withValues(alpha: 0.12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: color.withValues(alpha: 0.35)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          child: Column(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700, color: color),
              ),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _Ranking extends StatelessWidget {
  const _Ranking({required this.title, required this.data});
  final String title;
  final Map<String, int> data;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();
    final max = data.values.first;
    final scheme = Theme.of(context).colorScheme;
    return _Section(
      title: title,
      children: [
        for (final e in data.entries.take(6))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 110,
                  child: Text(e.key, overflow: TextOverflow.ellipsis),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: e.value / max,
                      minHeight: 14,
                      color: speciesColor(e.key),
                      backgroundColor: scheme.surfaceContainerHighest,
                    ),
                  ),
                ),
                SizedBox(
                  width: 32,
                  child: Text('${e.value}', textAlign: TextAlign.end),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _HourChart extends StatelessWidget {
  const _HourChart({required this.byHour});
  final List<int> byHour;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return BarChart(
      BarChartData(
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: const AxisTitles(),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) => v % 3 == 0
                  ? Text('${v.toInt()}', style: const TextStyle(fontSize: 10))
                  : const SizedBox.shrink(),
            ),
          ),
        ),
        barGroups: [
          for (var h = 0; h < 24; h++)
            BarChartGroupData(
              x: h,
              barRods: [
                BarChartRodData(
                  toY: byHour[h].toDouble(),
                  color: scheme.primary,
                  width: 8,
                  borderRadius: BorderRadius.circular(2),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Premiile pe sezon și pe zi: cea mai mare captură, cea mai mare cantitate,
/// cei mai mulți pești.
class _AwardsTab extends StatelessWidget {
  const _AwardsTab({required this.catches, required this.seasons});
  final List<CatchEntry> catches;
  final List<Season> seasons;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final bySeason = [
      for (final s
          in seasons.toList()..sort((a, b) => b.start.compareTo(a.start)))
        (s, catches.where((c) => s.contains(c.date)).toList()),
    ].where((e) => e.$2.isNotEmpty).toList();

    final byDay = <DateTime, List<CatchEntry>>{};
    for (final c in catches) {
      byDay
          .putIfAbsent(
            DateTime(c.date.year, c.date.month, c.date.day),
            () => [],
          )
          .add(c);
    }
    final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12 + kBannerSpace),
      children: [
        if (bySeason.isNotEmpty) ...[
          Text('Premiile sezonului', style: text.titleMedium),
          for (final (s, list) in bySeason)
            _AwardsCard(
              title: s.title,
              awards: computeAwards(list),
              gold: true,
            ),
          const SizedBox(height: 12),
        ],
        Text('Premiile zilei', style: text.titleMedium),
        for (final d in days)
          _AwardsCard(
            title: DateFormat('EEEE, d MMMM yyyy').format(d),
            awards: computeAwards(byDay[d]!),
          ),
      ],
    );
  }
}

class _AwardsCard extends StatelessWidget {
  const _AwardsCard({
    required this.title,
    required this.awards,
    this.gold = false,
  });
  final String title;
  final Awards awards;
  final bool gold;

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    final text = Theme.of(context).textTheme;
    String name(String? id) => store.participant(id)?.fullName ?? 'fără pescar';
    String names(List<String> ids) => ids.map(name).join(', ');
    String biggest(CatchEntry c) => [
      name(c.participantId),
      c.species,
      _kg(c.weightKg!),
      if (c.lengthCm != null) _cm(c.lengthCm!),
      if (gold) DateFormat('d MMM').format(c.date),
    ].join(' · ');

    Widget row(String emoji, String label, String who, String? value) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 32,
                child: Text(emoji, style: const TextStyle(fontSize: 20)),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: text.bodySmall),
                    Text(
                      who,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              if (value != null)
                Text(
                  value,
                  style: text.titleMedium?.copyWith(
                    color: Sea.sunset,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        );

    return Card(
      shape: gold
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Sea.sunset, width: 1.2),
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${gold ? '🏆 ' : ''}$title',
              style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const Divider(),
            row(
              '🥇',
              'Cea mai mare captură',
              awards.biggest.isEmpty
                  ? 'nicio captură cântărită'
                  : awards.biggest.map(biggest).join('\n'),
              null,
            ),
            row(
              '⚖️',
              'Cea mai mare cantitate',
              awards.topKgIds.isEmpty ? '—' : names(awards.topKgIds),
              awards.topKgIds.isEmpty ? null : _kg(awards.topKg),
            ),
            row(
              '🐟',
              'Cei mai mulți pești',
              awards.topCountIds.isEmpty ? '—' : names(awards.topCountIds),
              awards.topCountIds.isEmpty
                  ? null
                  : awards.topCount == 1
                  ? '1 pește'
                  : '${awards.topCount} pești',
            ),
          ],
        ),
      ),
    );
  }
}
