import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import 'backup_screen.dart';
import 'boats_screen.dart';
import 'expense_presets_screen.dart';
import 'need_categories_screen.dart';
import 'participants_screen.dart';
import 'seasons_screen.dart';

/// Numărul build-ului (pus la compilare; gol în previzualizare).
const _buildNumber = String.fromEnvironment('BUILD_NUMBER');

/// Setările, grupate: oameni și bărci, liste, date, aspect.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    void open(Widget page) =>
        Navigator.push(context, MaterialPageRoute(builder: (_) => page));

    final scheme = Theme.of(context).colorScheme;
    Widget header(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium
            ?.copyWith(letterSpacing: 1.2, color: scheme.primary),
      ),
    );

    /// Un card cu titlul secțiunii și rândurile ei, strânse între ele.
    Widget section(String title, List<Widget> tiles) => Card(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: scheme.onSurface.withValues(alpha: 0.35),
          width: 0.8,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                title.toUpperCase(),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                  color: scheme.primary,
                ),
              ),
            ),
            ...tiles,
          ],
        ),
      ),
    );

    Widget tile(IconData icon, String title, String subtitle, Widget page) =>
        ListTile(
          dense: true,
          visualDensity: const VisualDensity(vertical: -3),
          leading: Icon(icon),
          title: Text(title, style: const TextStyle(fontSize: 15)),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => open(page),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Setări')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          section('Oameni și bărci', [
            tile(
              Icons.people_outline,
              'Participanți',
              '${store.participants.length} · date, CNP, acte',
              const ParticipantsScreen(),
            ),
            tile(
              Icons.directions_boat_outlined,
              'Bărci',
              '${store.boats.length} · motorizare, acte',
              const BoatsScreen(),
            ),
          ]),
          section('Sezoane', [
            tile(
              Icons.history,
              'Toate sezoanele și istoricul',
              '${store.seasons.length} sezoane',
              const SeasonsScreen(),
            ),
          ]),
          section('Liste', [
            tile(
              Icons.category_outlined,
              'Categorii necesar',
              '${store.needCategories.length} categorii',
              const NeedCategoriesScreen(),
            ),
            tile(
              Icons.bookmarks_outlined,
              'Presetări cheltuieli',
              '${store.expensePresets.length} bunuri',
              const ExpensePresetsScreen(),
            ),
          ]),
          section('Capturi', [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
              child: DropdownButtonFormField<String?>(
                initialValue:
                    store.participants.any(
                      (p) => p.id == store.defaultCatcherId,
                    )
                    ? store.defaultCatcherId
                    : null,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Pescar implicit',
                  helperText:
                      'Primul la „Cine a prins” și ales din start '
                      'la o captură nouă',
                  prefixIcon: Icon(Icons.phishing),
                ),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Ultimul care a prins'),
                  ),
                  for (final p in store.participants)
                    DropdownMenuItem(value: p.id, child: Text(p.fullName)),
                ],
                onChanged: store.setDefaultCatcher,
              ),
            ),
          ]),
          section('Cheltuieli', [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
              child: DropdownButtonFormField<String?>(
                initialValue:
                    store.participants.any((p) => p.id == store.defaultPayerId)
                    ? store.defaultPayerId
                    : null,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Plătitor implicit',
                  helperText:
                      'Apare deja ales la orice cheltuială nouă '
                      '(dacă e în echipa sezonului)',
                  prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                ),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Ultimul care a plătit'),
                  ),
                  for (final p in store.participants)
                    DropdownMenuItem(value: p.id, child: Text(p.fullName)),
                ],
                onChanged: store.setDefaultPayer,
              ),
            ),
          ]),
          section('Date', [
            tile(
              Icons.cloud_sync_outlined,
              'Copie de siguranță',
              'Exportă / importă toate datele',
              const BackupScreen(),
            ),
          ]),
          header('Aspect'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<ThemeMode>(
              // varianta aleasă cu o tentă mai închisă
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: Color.alphaBlend(
                  scheme.primary.withValues(alpha: 0.35),
                  scheme.secondaryContainer,
                ),
                selectedForegroundColor: scheme.onSurface,
              ),
              segments: const [
                ButtonSegment(
                  value: ThemeMode.light,
                  icon: Icon(Icons.light_mode_outlined),
                  label: Text('Luminos'),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  icon: Icon(Icons.dark_mode_outlined),
                  label: Text('Dark'),
                ),
                ButtonSegment(
                  value: ThemeMode.system,
                  icon: Icon(Icons.brightness_auto_outlined),
                  label: Text('Automat'),
                ),
              ],
              selected: {store.themeMode},
              onSelectionChanged: (v) => store.setThemeMode(v.first),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: Text(
              _buildNumber.isEmpty
                  ? 'Deltă · previzualizare'
                  : 'Deltă · build $_buildNumber',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
