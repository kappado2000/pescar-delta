import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/catch_entry.dart';

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistici'),
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
      body: list.isEmpty
          ? const Center(child: Text('Nicio captură în perioada aleasă.'))
          : _StatsBody(catches: list, title: options[_filter]!),
    );
  }
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
      padding: const EdgeInsets.all(12),
      children: [
        Text(title, style: text.titleMedium),
        const SizedBox(height: 8),
        Row(
          children: [
            _Tile(label: 'Capturi', value: '${catches.length}'),
            _Tile(label: 'Total kg', value: totalKg.toStringAsFixed(1)),
            _Tile(label: 'Specii', value: '${bySpecies.length}'),
            _Tile(label: 'Eliberate', value: '$released'),
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
  const _Tile({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          child: Column(
            children: [
              Text(value, style: Theme.of(context).textTheme.titleLarge),
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
                      color: scheme.primary,
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
