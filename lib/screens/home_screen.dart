import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/season.dart';
import '../models/spot.dart';
import '../services/location_service.dart';
import '../services/permit_catalog.dart';
import '../services/weather_service.dart';
import '../theme.dart';
import '../widgets/thermo.dart';
import '../widgets/delta_scene.dart';
import '../widgets/open_problems.dart';
import '../widgets/quick_expense_sheet.dart';
import 'catches_screen.dart';
import 'expenses_screen.dart';
import 'home_shell.dart';
import 'season_detail_screen.dart';
import 'seasons_screen.dart';
import 'settings_screen.dart';

/// Acasă: sezonul curent, cu acțiunile rapide și starea lui.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<Forecast>? _weather;
  String? _weatherFor;

  void _loadWeather(Season s) {
    if (_weatherFor == s.place.key) return;
    _weatherFor = s.place.key;
    _weather = WeatherService.fetch(s.place.lat, s.place.lng);
  }

  void _open(Season s, int tab) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => SeasonDetailScreen(seasonId: s.id, initialTab: tab),
    ),
  );

  Future<void> _markSpot() async {
    final store = context.read<AppStore>();
    final messenger = ScaffoldMessenger.of(context);
    final pos = await LocationService.current();
    if (!mounted) return;
    if (pos == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Nu am acces la GPS — pornește locația.')),
      );
      return;
    }
    final name = TextEditingController(
      text: 'Loc ${DateFormat('d MMM, HH:mm').format(DateTime.now())}',
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Marchează locul'),
        content: TextField(
          controller: name,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nume'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Anulează'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Salvează'),
          ),
        ],
      ),
    );
    if (ok != true || name.text.trim().isEmpty) return;
    await store.upsertSpot(
      Spot(
        id: newId(),
        name: name.text.trim(),
        lat: pos.latitude,
        lng: pos.longitude,
      ),
    );
    messenger.showSnackBar(
      SnackBar(content: Text('Loc salvat: ${name.text.trim()}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final season = store.currentSeason;
    if (season != null) _loadWeather(season);
    return Scaffold(
      appBar: SceneAppBar(
        title: 'Pescar Deltă',
        titleSuffix: '  - ${DateFormat('EEEE, d MMMM').format(DateTime.now())}',
        height: 150,
        actions: [
          IconButton(
            tooltip: 'Setări',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24 + kBannerSpace),
        children: season == null
            ? [_NoSeason(onCreate: () => showSeasonEditor(context))]
            : [
                _SeasonHeader(
                  season: season,
                  weather: _weather,
                  onTap: () => _open(season, 0),
                ),
                OpenProblemsRow(season: season, onTap: () => _open(season, 3)),
                const SizedBox(height: 4),
                // acțiuni rapide, butoane mari
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  // fără spațiul automat de jos (al bannerului) — altfel apare un gol mare
                  padding: EdgeInsets.zero,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 2.4,
                  children: [
                    _Action(
                      icon: Icons.account_balance_wallet,
                      label: 'Cheltuială',
                      color: Sea.teal,
                      onTap: () => showQuickExpense(context, season),
                    ),
                    _Action(
                      icon: Icons.add_a_photo_outlined,
                      label: 'Captură',
                      color: Sea.coral,
                      onTap: () => openCatchEditor(context),
                    ),
                    _Action(
                      icon: Icons.add_location_alt,
                      label: 'Marchează locul',
                      color: Sea.ocean,
                      onTap: _markSpot,
                    ),
                    _Action(
                      icon: Icons.checklist,
                      label: 'Necesar',
                      color: needsColor(context),
                      onTap: () => _open(season, 3),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ..._sections(store, season),
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(Icons.history),
                  title: const Text('Toate sezoanele și istoricul'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SeasonsScreen()),
                  ),
                ),
              ],
      ),
    );
  }

  List<Widget> _sections(AppStore store, Season season) {
    final tasks = buildPermitTasks(
      season: season,
      participants: store.participants,
      boats: store.boats,
    );
    final bought = tasks.where((t) => season.purchased[t.key] == true).length;
    final needs = [
      for (final c in store.needCategories)
        ...season.needsOf(c).where((i) => i.text.trim().isNotEmpty),
    ];
    final spent = season.expenses.fold<double>(0, (s, e) => s + e.amount);
    Widget row(
      IconData icon,
      Color color,
      String title,
      String value,
      int tab,
    ) => Card(
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: color,
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: () => _open(season, tab),
      ),
    );
    return [
      row(
        Icons.badge_outlined,
        bought == tasks.length && tasks.isNotEmpty ? Sea.good : Sea.ocean,
        'Permise',
        '$bought/${tasks.length}',
        2,
      ),
      row(
        Icons.checklist,
        needsColor(context),
        'Necesar',
        '${needs.where((i) => i.done).length}/${needs.length}',
        3,
      ),
      row(
        Icons.account_balance_wallet_outlined,
        Sea.teal,
        'Cheltuieli',
        lei(spent),
        4,
      ),
      row(
        Icons.groups_outlined,
        Sea.ocean,
        'Echipa',
        '${season.participantIds.length} pers. · ${season.boatIds.length} bărci',
        1,
      ),
    ];
  }
}

class _SeasonHeader extends StatelessWidget {
  const _SeasonHeader({
    required this.season,
    required this.weather,
    required this.onTap,
  });
  final Season season;
  final Future<Forecast>? weather;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final status = season.contains(now)
        ? 'În desfășurare'
        : now.isBefore(season.start)
        ? 'Începe în ${season.start.difference(now).inDays + 1} zile'
        : 'Încheiat';
    final text = Theme.of(context).textTheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(season.title, style: text.titleLarge)),
                  Chip(label: Text(status)),
                ],
              ),
              Text(
                '📍 ${season.place.name} · '
                '${season.periodLabel}',
              ),
              const SizedBox(height: 2),
              FutureBuilder<Forecast>(
                future: weather,
                builder: (context, snap) {
                  final f = snap.data;
                  if (f == null) {
                    return Text(
                      snap.hasError
                          ? 'Vremea: fără semnal'
                          : 'Vremea se încarcă…',
                      style: text.bodySmall,
                    );
                  }
                  final today = f.days.isNotEmpty ? f.days.first : null;
                  final style = text.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  );
                  return Text.rich(
                    TextSpan(
                      style: style,
                      children: [
                        thermoSpan(),
                        TextSpan(
                          text:
                              ' ${f.current.temp.toStringAsFixed(0)}° · '
                              '${f.current.pressure.toStringAsFixed(0)} hPa · '
                              'vânt ${f.current.wind.toStringAsFixed(0)} km/h',
                        ),
                        if (today != null) ...[
                          const TextSpan(text: ' · pescuit: '),
                          WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: CircleAvatar(
                              radius: 13,
                              backgroundColor: fishingScoreColor(today.score),
                              child: Text(
                                '${today.score}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.14),
      // bordură subțire, în nuanța mai închisă a culorii butonului
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Color.lerp(color, Colors.black, 0.25)!.withValues(alpha: 0.75),
          width: 0.9,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoSeason extends StatelessWidget {
  const _NoSeason({required this.onCreate});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.event_note, size: 48, color: Sea.ocean),
            const SizedBox(height: 8),
            const Text(
              'Niciun sezon încă.\nCreează sezonul (primăvară sau toamnă) '
              'cu locația lui.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text('Creează sezonul'),
            ),
          ],
        ),
      ),
    );
  }
}
