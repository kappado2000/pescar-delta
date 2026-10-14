import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/season.dart';
import '../services/permit_catalog.dart';
import 'backup_screen.dart';
import 'boats_screen.dart';
import 'participants_screen.dart';
import 'season_detail_screen.dart';
import '../theme.dart';
import '../models/place.dart';
import '../widgets/delta_scene.dart';
import '../widgets/place_picker.dart';

final _dayMonth = DateFormat('d MMM');

String _greeting() {
  final h = DateTime.now().hour;
  if (h >= 5 && h < 11) return 'Bună dimineața, fir întins!';
  if (h >= 11 && h < 18) return 'Bună ziua, fir întins!';
  if (h >= 18 && h < 22) return 'Bună seara, fir întins!';
  return 'Noapte bună, pescarule!';
}

class SeasonsScreen extends StatelessWidget {
  const SeasonsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final active = store.activeSeasons;
    final history = store.seasonsByYear;
    return Scaffold(
      appBar: SceneAppBar(
        title: 'Pescar Deltă',
        subtitle:
            '${_greeting()} · ${DateFormat('EEEE, d MMMM').format(DateTime.now())}',
        height: 170,
        actions: [
          IconButton(
            tooltip: 'Participanți',
            icon: const Icon(Icons.people_outline),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ParticipantsScreen()),
            ),
          ),
          IconButton(
            tooltip: 'Bărci',
            icon: const Icon(Icons.directions_boat_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BoatsScreen()),
            ),
          ),
          IconButton(
            tooltip: 'Copie de siguranță',
            icon: const Icon(Icons.cloud_sync_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BackupScreen()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showSeasonEditor(context),
        icon: const Icon(Icons.add),
        label: const Text('Sezon'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
        children: [
          Row(
            children: [
              Expanded(
                child: _QuickCard(
                  icon: Icons.people_outline,
                  title: 'Participanți',
                  subtitle: '${store.participants.length} · date și acte',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ParticipantsScreen(),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: _QuickCard(
                  icon: Icons.directions_boat_outlined,
                  title: 'Bărci',
                  subtitle: '${store.boats.length} · motor și acte',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const BoatsScreen()),
                  ),
                ),
              ),
            ],
          ),
          if (active.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Niciun sezon pentru anul acesta.\n'
                'Adaugă sezonul de primăvară și cel de toamnă.',
                textAlign: TextAlign.center,
              ),
            ),
          for (final s in active) _SeasonCard(season: s),
          if (history.isNotEmpty) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.history),
                  const SizedBox(width: 8),
                  Text(
                    'Istoric · toate sezoanele',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
            for (final entry in history.entries)
              Card(
                child: ExpansionTile(
                  initiallyExpanded: entry.key == DateTime.now().year,
                  leading: Icon(
                    entry.key < DateTime.now().year
                        ? Icons.inventory_2_outlined
                        : Icons.event_note,
                  ),
                  title: Text('${entry.key}'),
                  subtitle: Text(
                    '${entry.value.length} sezoane · '
                    '${entry.value.map((s) => s.place.name).toSet().join(', ')}'
                    '${entry.key < DateTime.now().year ? ' · arhivat' : ''}',
                  ),
                  children: [
                    for (final s in entry.value) _SeasonTile(season: s),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _QuickCard extends StatelessWidget {
  const _QuickCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(icon, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleSmall),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SeasonCard extends StatelessWidget {
  const _SeasonCard({required this.season});
  final Season season;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final tasks = buildPermitTasks(
      season: season,
      participants: store.participants,
      boats: store.boats,
    );
    final done = tasks.where((t) => season.purchased[t.key] == true).length;
    final catches = store.catches.where((c) => season.contains(c.date)).length;
    final now = DateTime.now();
    final status = season.contains(now)
        ? 'În desfășurare'
        : now.isBefore(season.start)
        ? 'Începe în ${season.start.difference(now).inDays + 1} zile'
        : 'Încheiat';
    final statusColor = season.contains(now)
        ? Sea.teal
        : now.isBefore(season.start)
        ? Sea.sunset
        : Colors.blueGrey;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _open(context, season),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    season.kind == SeasonKind.primavara
                        ? Icons.local_florist_outlined
                        : Icons.eco_outlined,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      season.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '📍 ${season.place.name} · '
                '${_dayMonth.format(season.start)} – ${_dayMonth.format(season.end)}'
                ' · ${season.participantIds.length} participanți'
                ' · $catches capturi',
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: tasks.isEmpty ? 0 : done / tasks.length,
                color: done == tasks.length && tasks.isNotEmpty
                    ? Sea.good
                    : Sea.ocean,
                minHeight: 8,
                borderRadius: BorderRadius.circular(3),
              ),
              const SizedBox(height: 4),
              Text(
                tasks.isEmpty
                    ? 'Alege participanții ca să vezi permisele'
                    : 'Permise cumpărate: $done / ${tasks.length}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SeasonTile extends StatelessWidget {
  const _SeasonTile({required this.season});
  final Season season;

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    final catches = store.catches.where((c) => season.contains(c.date));
    final kg = catches.fold<double>(0, (s, c) => s + (c.weightKg ?? 0));
    final spent = season.expenses.fold<double>(0, (s, e) => s + e.amount);
    return ListTile(
      leading: Icon(
        season.kind == SeasonKind.primavara
            ? Icons.local_florist_outlined
            : Icons.eco_outlined,
      ),
      title: Text('${season.kind.label} · ${season.place.name}'),
      subtitle: Text(
        '${_dayMonth.format(season.start)} – ${_dayMonth.format(season.end)}'
        ' · ${season.participantIds.length} participanți\n'
        '${catches.length} capturi · ${kg.toStringAsFixed(1)} kg'
        '${spent > 0 ? ' · cheltuieli ${spent.toStringAsFixed(0)} lei' : ''}',
      ),
      isThreeLine: true,
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _open(context, season),
    );
  }
}

void _open(BuildContext context, Season s) => Navigator.push(
  context,
  MaterialPageRoute(builder: (_) => SeasonDetailScreen(seasonId: s.id)),
);

/// Dialog de creare/editare sezon. Datele implicite (înainte / după
/// prohibiție) se pot modifica.
Future<void> showSeasonEditor(BuildContext context, {Season? season}) async {
  final store = context.read<AppStore>();
  final now = DateTime.now();
  final usedKinds = store.seasons
      .where((s) => s.year == now.year)
      .map((s) => s.kind)
      .toSet();
  var kind =
      season?.kind ??
      (usedKinds.contains(SeasonKind.primavara)
          ? SeasonKind.toamna
          : SeasonKind.primavara);
  var year = season?.year ?? now.year;
  (DateTime, DateTime) defaults(SeasonKind k, int y) =>
      k == SeasonKind.primavara
      ? (DateTime(y, 3, 1), DateTime(y, 4, 5))
      : (DateTime(y, 6, 10), DateTime(y, 11, 30));
  var start = season?.start ?? defaults(kind, year).$1;
  var end = season?.end ?? defaults(kind, year).$2;
  // locația: a sezonului editat, altfel a celui mai recent sezon
  var place =
      season?.place ??
      ((store.seasons.toList()..sort((a, b) => b.start.compareTo(a.start)))
              .firstOrNull
              ?.place ??
          sfantuGheorghe);

  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        Future<void> pick(bool isStart) async {
          final d = await showDatePicker(
            context: ctx,
            initialDate: isStart ? start : end,
            firstDate: DateTime(year, 1, 1),
            lastDate: DateTime(year, 12, 31),
          );
          if (d == null) return;
          setState(() {
            if (isStart) {
              start = d;
              if (end.isBefore(start)) end = start;
            } else {
              end = d.isBefore(start) ? start : d;
            }
          });
        }

        return AlertDialog(
          title: Text(season == null ? 'Sezon nou' : 'Editare sezon'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<SeasonKind>(
                segments: [
                  for (final k in SeasonKind.values)
                    ButtonSegment(value: k, label: Text(k.label)),
                ],
                selected: {kind},
                onSelectionChanged: (v) => setState(() {
                  kind = v.first;
                  if (season == null) {
                    (start, end) = defaults(kind, year);
                  }
                }),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: year,
                decoration: const InputDecoration(labelText: 'An'),
                items: [
                  for (var y = now.year - 3; y <= now.year + 1; y++)
                    DropdownMenuItem(value: y, child: Text('$y')),
                ],
                onChanged: (y) => setState(() {
                  year = y!;
                  (start, end) = defaults(kind, year);
                }),
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.play_arrow),
                title: const Text('Început'),
                subtitle: Text(DateFormat('d MMMM yyyy').format(start)),
                onTap: () => pick(true),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.stop),
                title: const Text('Sfârșit'),
                subtitle: Text(DateFormat('d MMMM yyyy').format(end)),
                onTap: () => pick(false),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.place),
                title: const Text('Locație'),
                subtitle: Text(place.name),
                trailing: const Icon(Icons.edit_location_alt_outlined),
                onTap: () async {
                  final p = await pickPlace(ctx, current: place);
                  if (p != null) setState(() => place = p);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Anulează'),
            ),
            FilledButton(
              onPressed: () async {
                final s =
                    season ??
                    Season(
                      id: newId(),
                      year: year,
                      kind: kind,
                      start: start,
                      end: end,
                      // participanții sezonului anterior, ca punct de plecare
                      participantIds: List.of(
                        store.seasons.isEmpty
                            ? store.participants.map((p) => p.id)
                            : (store.seasons.toList()..sort(
                                    (a, b) => b.start.compareTo(a.start),
                                  ))
                                  .first
                                  .participantIds,
                      ),
                      // bărcile sezonului anterior (la primul sezon: toate)
                      boatIds: List.of(
                        store.seasons.isEmpty
                            ? store.boats.map((b) => b.id)
                            : (store.seasons.toList()..sort(
                                    (a, b) => b.start.compareTo(a.start),
                                  ))
                                  .first
                                  .boatIds,
                      ),
                    );
                s
                  ..year = year
                  ..kind = kind
                  ..start = start
                  ..end = end
                  ..place = place;
                await store.upsertSeason(s);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Salvează'),
            ),
          ],
        );
      },
    ),
  );
}
