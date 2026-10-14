import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import 'backup_screen.dart';
import 'boats_screen.dart';
import 'expense_presets_screen.dart';
import 'need_categories_screen.dart';
import 'participants_screen.dart';
import 'seasons_screen.dart';

/// Setările, grupate: oameni și bărci, liste, date, aspect.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    void open(Widget page) =>
        Navigator.push(context, MaterialPageRoute(builder: (_) => page));

    Widget header(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          letterSpacing: 1.2,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Setări')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          header('Oameni și bărci'),
          ListTile(
            leading: const Icon(Icons.people_outline),
            title: const Text('Participanți'),
            subtitle: Text('${store.participants.length} · date, CNP, acte'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => open(const ParticipantsScreen()),
          ),
          ListTile(
            leading: const Icon(Icons.directions_boat_outlined),
            title: const Text('Bărci'),
            subtitle: Text('${store.boats.length} · motorizare, acte'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => open(const BoatsScreen()),
          ),
          header('Sezoane'),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('Toate sezoanele și istoricul'),
            subtitle: Text('${store.seasons.length} sezoane'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => open(const SeasonsScreen()),
          ),
          header('Liste'),
          ListTile(
            leading: const Icon(Icons.category_outlined),
            title: const Text('Categorii necesar'),
            subtitle: Text('${store.needCategories.length} categorii'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => open(const NeedCategoriesScreen()),
          ),
          ListTile(
            leading: const Icon(Icons.bookmarks_outlined),
            title: const Text('Presetări cheltuieli'),
            subtitle: Text('${store.expensePresets.length} bunuri'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => open(const ExpensePresetsScreen()),
          ),
          header('Date'),
          ListTile(
            leading: const Icon(Icons.cloud_sync_outlined),
            title: const Text('Copie de siguranță'),
            subtitle: const Text('Exportă / importă toate datele'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => open(const BackupScreen()),
          ),
          header('Aspect'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<ThemeMode>(
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
        ],
      ),
    );
  }
}
