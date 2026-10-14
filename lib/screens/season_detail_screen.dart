import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/app_store.dart';
import '../models/permit_file.dart';
import '../models/season.dart';
import '../services/permit_catalog.dart';
import '../models/need_item.dart';
import '../theme.dart';
import '../models/expense.dart';
import '../widgets/quick_expense_sheet.dart';
import '../widgets/swipe_delete.dart';
import 'expenses_screen.dart';
import 'need_categories_screen.dart';
import 'needs_screen.dart';
import 'permit_buy_screen.dart';
import 'boats_screen.dart';
import 'participants_screen.dart';
import 'seasons_screen.dart';

class SeasonDetailScreen extends StatelessWidget {
  const SeasonDetailScreen({
    super.key,
    required this.seasonId,
    this.initialTab = 0,
  });
  final String seasonId;

  /// 0 Rezumat · 1 Echipa · 2 Permise · 3 Necesar · 4 Cheltuieli
  final int initialTab;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final season = store.season(seasonId);
    if (season == null) return const Scaffold();
    return DefaultTabController(
      length: 5,
      initialIndex: initialTab.clamp(0, 4),
      child: Scaffold(
        appBar: AppBar(
          title: Text('${season.title} · ${season.place.name}'),
          actions: [
            IconButton(
              tooltip: 'Modifică sezonul',
              icon: const Icon(Icons.edit_calendar_outlined),
              onPressed: () => showSeasonEditor(context, season: season),
            ),
            IconButton(
              tooltip: 'Șterge sezonul',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _delete(context, season),
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(icon: Icon(Icons.dashboard_outlined), text: 'Rezumat'),
              Tab(icon: Icon(Icons.groups_outlined), text: 'Echipa'),
              Tab(icon: Icon(Icons.badge_outlined), text: 'Permise'),
              Tab(icon: Icon(Icons.checklist), text: 'Necesar'),
              Tab(
                icon: Icon(Icons.account_balance_wallet_outlined),
                text: 'Cheltuieli',
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _SummaryTab(season: season),
            _TeamTab(season: season),
            _PermitsTab(season: season),
            ListView(
              padding: const EdgeInsets.all(12),
              children: [_NeedsCard(season: season, expanded: true)],
            ),
            ListView(
              padding: const EdgeInsets.all(12),
              children: [_ExpensesCard(season: season)],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _delete(BuildContext context, Season s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Ștergi ${s.title}?'),
        content: const Text(
          'Se șterg și fișierele din folderul de permise al sezonului. '
          'Capturile rămân în jurnal.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Anulează'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Șterge'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    Navigator.pop(context);
    await context.read<AppStore>().deleteSeason(s.id);
  }
}

/// Rezumatul sezonului: ce e gata și ce mai e de făcut, cu salt la tab.
class _SummaryTab extends StatelessWidget {
  const _SummaryTab({required this.season});
  final Season season;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final fmt = DateFormat('d MMMM yyyy');
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
    final needsDone = needs.where((i) => i.done).length;
    final spent = season.expenses.fold<double>(0, (s, e) => s + e.amount);
    final catches = store.catches
        .where((c) => season.contains(c.date))
        .toList();
    final kg = catches.fold<double>(0, (s, c) => s + (c.weightKg ?? 0));
    void go(int tab) => DefaultTabController.of(context).animateTo(tab);

    Widget tile(
      IconData icon,
      Color color,
      String title,
      String value,
      String sub,
      VoidCallback onTap,
    ) {
      return Card(
        child: ListTile(
          onTap: onTap,
          leading: CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.15),
            child: Icon(icon, color: color),
          ),
          title: Text(title),
          subtitle: Text(sub),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: color,
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (season.archived)
          Card(
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: const ListTile(
              leading: Icon(Icons.inventory_2_outlined),
              title: Text('Sezon arhivat'),
              subtitle: Text(
                'Anul s-a încheiat — datele rămân pentru consultare.',
              ),
            ),
          ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.place, color: Sea.ocean),
            title: Text(season.place.name),
            subtitle: Text(
              '${fmt.format(season.start)} – ${fmt.format(season.end)}'
              '${season.permitStart != null ? '\nPermisele încep din ${fmt.format(season.permitStart!)}' : ''}',
            ),
            isThreeLine: season.permitStart != null,
          ),
        ),
        tile(
          Icons.groups_outlined,
          Sea.ocean,
          'Echipa',
          '${season.participantIds.length} + ${season.boatIds.length}',
          '${season.participantIds.length} participanți · ${season.boatIds.length} bărci',
          () => go(1),
        ),
        tile(
          Icons.badge_outlined,
          bought == tasks.length && tasks.isNotEmpty ? Sea.good : Sea.ocean,
          'Permise ARBDD',
          '$bought/${tasks.length}',
          tasks.isEmpty
              ? 'Bifează participanții în Echipa'
              : bought == tasks.length
              ? 'Toate cumpărate'
              : '${tasks.length - bought} de cumpărat',
          () => go(2),
        ),
        tile(
          Icons.checklist,
          needsColor(context),
          'Necesar',
          '$needsDone/${needs.length}',
          needs.isEmpty ? 'Nimic notat încă' : 'bifate',
          () => go(3),
        ),
        tile(
          Icons.account_balance_wallet_outlined,
          Sea.teal,
          'Cheltuieli',
          lei(spent),
          '${season.expenses.length} cheltuieli',
          () => go(4),
        ),
        tile(
          Icons.set_meal,
          Sea.coral,
          'Capturi',
          '${catches.length}',
          '${kg.toStringAsFixed(1)} kg în perioada sezonului',
          () {},
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          icon: const Icon(Icons.account_balance_wallet),
          label: const Text('Cheltuială rapidă'),
          onPressed: () => showQuickExpense(context, season),
        ),
      ],
    );
  }
}

/// Cine merge în sezon: participanții și bărcile bifate.
class _TeamTab extends StatelessWidget {
  const _TeamTab({required this.season});
  final Season season;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(child: Text('Participanți', style: text.titleMedium)),
            TextButton.icon(
              icon: const Icon(Icons.person_add_alt),
              label: const Text('Gestionează'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ParticipantsScreen()),
              ),
            ),
          ],
        ),
        if (store.participants.isEmpty)
          const Text('Niciun participant — apasă „Gestionează”.'),
        for (final p in store.participants)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: season.participantIds.contains(p.id),
            title: Text(p.fullName),
            subtitle: Text(p.category.label),
            secondary: const Icon(Icons.person_outline),
            onChanged: (v) {
              v == true
                  ? season.participantIds.add(p.id)
                  : season.participantIds.remove(p.id);
              store.upsertSeason(season);
            },
          ),
        const Divider(height: 32),
        Row(
          children: [
            Expanded(child: Text('Bărci', style: text.titleMedium)),
            TextButton.icon(
              icon: const Icon(Icons.directions_boat_outlined),
              label: const Text('Gestionează'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BoatsScreen()),
              ),
            ),
          ],
        ),
        if (store.boats.isEmpty)
          const Text('Nicio barcă — apasă „Gestionează”.'),
        for (final b in store.boats)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: season.boatIds.contains(b.id),
            title: Text(b.denumire),
            subtitle: Text(
              [
                b.tip,
                if (b.capacitateMotor.isNotEmpty) b.capacitateMotor,
              ].join(' · '),
            ),
            secondary: const Icon(Icons.directions_boat),
            onChanged: (v) {
              v == true
                  ? season.boatIds.add(b.id)
                  : season.boatIds.remove(b.id);
              store.upsertSeason(season);
            },
          ),
      ],
    );
  }
}

/// Permisele: ziua de început, durate, lista ARBDD, folderul „permise”.
class _PermitsTab extends StatelessWidget {
  const _PermitsTab({required this.season});
  final Season season;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final fmt = DateFormat('d MMMM yyyy');
    final text = Theme.of(context).textTheme;
    final tasks = buildPermitTasks(
      season: season,
      participants: store.participants,
      boats: store.boats,
    );
    final pending = tasks
        .where((t) => season.purchased[t.key] != true)
        .toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Card(
          color: season.permitStart == null
              ? Theme.of(context).colorScheme.errorContainer
              : null,
          child: ListTile(
            leading: const Icon(Icons.event_available),
            title: const Text('Ziua de început a permiselor'),
            subtitle: Text(
              season.permitStart == null
                  ? 'Apasă și scrie ziua (ex. 15.05.${season.year})'
                  : fmt.format(season.permitStart!),
            ),
            trailing: const Icon(Icons.keyboard_outlined),
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialEntryMode: DatePickerEntryMode.input,
                initialDate: season.permitStart ?? DateTime.now(),
                firstDate: DateTime(season.year, 1, 1),
                lastDate: DateTime(season.year, 12, 31),
                helpText: 'Ziua de început a permiselor',
                fieldHintText: 'zz.ll.aaaa',
              );
              if (d == null) return;
              season.permitStart = d;
              season.syncPeriodWithPermits();
              await store.upsertSeason(season);
            },
          ),
        ),
        const SizedBox(height: 12),
        Text('Permis acces turist (plătit)', style: text.titleSmall),
        const SizedBox(height: 6),
        SegmentedButton<AccessDuration>(
          segments: [
            for (final d in AccessDuration.values)
              ButtonSegment(
                value: d,
                label: Text(d.label, textAlign: TextAlign.center),
              ),
          ],
          selected: {season.accessDuration},
          onSelectionChanged: (v) {
            season.accessDuration = v.first;
            season.syncPeriodWithPermits();
            store.upsertSeason(season);
          },
        ),
        if (season.boatIds.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Permis ambarcațiune', style: text.titleSmall),
          const SizedBox(height: 6),
          SegmentedButton<BoatDuration>(
            segments: [
              for (final d in BoatDuration.values)
                ButtonSegment(value: d, label: Text(d.label)),
            ],
            selected: {season.boatDuration},
            onSelectionChanged: (v) {
              season.boatDuration = v.first;
              store.upsertSeason(season);
            },
          ),
        ],
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(child: Text('Permise ARBDD', style: text.titleMedium)),
            Text('${tasks.length - pending.length}/${tasks.length}'),
          ],
        ),
        const SizedBox(height: 8),
        if (pending.isNotEmpty && !season.archived)
          FilledButton.icon(
            icon: const Icon(Icons.auto_fix_high),
            label: Text('Completează automat (${pending.length} rămase)'),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PermitBuyScreen(seasonId: season.id),
              ),
            ),
          ),
        for (final t in tasks) _TaskTile(season: season, task: t),
        for (final b in store.boats.where(
          (b) => !season.boatIds.contains(b.id),
        ))
          Card(
            color: Theme.of(context).colorScheme.errorContainer,
            child: ListTile(
              leading: const Icon(Icons.directions_boat_outlined),
              title: Text('Barca „${b.denumire}” nu e bifată în sezon'),
              subtitle: const Text('Nu are permis de ambarcațiune.'),
              trailing: FilledButton(
                onPressed: () {
                  season.boatIds.add(b.id);
                  store.upsertSeason(season);
                },
                child: const Text('Bifează'),
              ),
            ),
          ),
        const SizedBox(height: 20),
        _PermitFolder(season: season, tasks: tasks),
      ],
    );
  }
}

/// „Necesar”: apeși și se deschide în jos cu toate categoriile; fiecare
/// categorie se deschide la rândul ei cu nevoile, care se bifează pe loc.
class _NeedsCard extends StatelessWidget {
  const _NeedsCard({required this.season, this.expanded = false});
  final Season season;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    List<NeedItem> filled(NeedCategory c) =>
        season.needsOf(c).where((i) => i.text.trim().isNotEmpty).toList();
    final cats = store.needCategories;
    final items = [for (final c in cats) ...filled(c)];
    final done = items.where((i) => i.done).length;
    final problems = cats
        .where((c) => c.isProblems)
        .expand(filled)
        .where((i) => !i.done)
        .length;

    void openTab(int index) => Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NeedsScreen(seasonId: season.id, initialTab: index),
      ),
    );

    return Card(
      color: needsColor(context).withValues(alpha: 0.12),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: expanded,
        leading: Icon(Icons.checklist, color: needsColor(context), size: 32),
        title: const Text('Necesar pentru sezon'),
        subtitle: Text(
          items.isEmpty
              ? 'Apasă ca să vezi categoriile'
              : '$done/${items.length} bifate'
                    '${problems > 0 ? ' · $problems probleme de remediat' : ''}',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        children: [
          for (final (i, c) in cats.indexed)
            Builder(
              builder: (context) {
                final list = filled(c);
                final catDone = list.where((x) => x.done).length;
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 3),
                  child: ExpansionTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 13,
                      backgroundColor: needsColor(context),
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: needsOnColor(context),
                        ),
                      ),
                    ),
                    title: Text(c.label),
                    subtitle: Text(
                      list.isEmpty
                          ? 'nimic notat'
                          : '$catDone/${list.length} ${c.doneLabel}',
                      style: TextStyle(
                        color: list.isNotEmpty && catDone == list.length
                            ? Sea.good
                            : null,
                      ),
                    ),
                    children: [
                      ReorderableListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        buildDefaultDragHandles: false,
                        itemCount: list.length,
                        onReorderItem: (from, to) {
                          // ordinea nouă a rândurilor completate; cele goale rămân la final
                          final ordered = List.of(list);
                          ordered.insert(to, ordered.removeAt(from));
                          final all = season.needsOf(c);
                          final empty = all
                              .where((x) => x.text.trim().isEmpty)
                              .toList();
                          all
                            ..clear()
                            ..addAll(ordered)
                            ..addAll(empty);
                          store.upsertSeason(season);
                        },
                        itemBuilder: (context, n) {
                          final item = list[n];
                          return SwipeToDelete(
                            key: ValueKey(item.id),
                            id: item.id,
                            number: n + 1,
                            text: item.text,
                            onDelete: () {
                              season.needsOf(c).remove(item);
                              store.upsertSeason(season);
                            },
                            child: CheckboxListTile(
                              dense: true,
                              visualDensity: VisualDensity.compact,
                              value: item.done,
                              controlAffinity: ListTileControlAffinity.trailing,
                              secondary: ReorderableDragStartListener(
                                index: n,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.drag_indicator,
                                      size: 20,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .outline,
                                    ),
                                    SizedBox(
                                      width: 28,
                                      child: Text(
                                        '${n + 1}.',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              title: Text(
                                item.text,
                                style: TextStyle(
                                  decoration: item.done
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                              onChanged: (v) {
                                item.done = v ?? false;
                                store.upsertSeason(season);
                              },
                            ),
                          );
                        },
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          icon: const Icon(Icons.edit_note),
                          label: Text(
                            list.isEmpty ? 'Adaugă' : 'Editează / adaugă',
                          ),
                          onPressed: () => openTab(i),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              icon: const Icon(Icons.category_outlined),
              label: const Text('Categorii: adaugă / modifică / șterge'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NeedCategoriesScreen()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpensesCard extends StatelessWidget {
  const _ExpensesCard({required this.season});
  final Season season;

  @override
  Widget build(BuildContext context) {
    final total = season.expenses.fold<double>(0, (s, e) => s + e.amount);
    final transfers = settle(balancesOf(season.expenses, season.participantIds))
        .length;
    return Card(
      color: Sea.teal.withValues(alpha: 0.12),
      child: ListTile(
        leading: const Icon(
          Icons.account_balance_wallet_outlined,
          color: Sea.teal,
          size: 32,
        ),
        title: const Text('Cheltuieli'),
        subtitle: Text(
          season.expenses.isEmpty
              ? 'Comune (împărțite egal) sau personale, pe participant'
              : 'Total ${lei(total)} · '
                    '${transfers == 0 ? 'toți achitați' : '$transfers transferuri de decontat'}',
        ),
        // „+” mare: cheltuială rapidă direct de aici
        trailing: IconButton.filled(
          tooltip: 'Cheltuială rapidă',
          iconSize: 30,
          style: IconButton.styleFrom(backgroundColor: Sea.teal),
          icon: const Icon(Icons.add),
          onPressed: () => showQuickExpense(context, season),
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ExpensesScreen(seasonId: season.id),
          ),
        ),
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({required this.season, required this.task});
  final Season season;
  final PermitTask task;

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    final done = season.purchased[task.key] == true;
    final icon = switch (task.kind) {
      PermitKind.acces => Icons.badge_outlined,
      PermitKind.pescuit => Icons.phishing,
      PermitKind.barca => Icons.directions_boat_outlined,
    };
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text('${task.kind.label} — ${task.ownerName}'),
        subtitle: Text(
          task.ready
              ? (task.subtitle ?? task.product.title)
              : 'Lipsește: ${task.missing.join(', ')}',
          style: task.ready ? null : const TextStyle(color: Colors.orange),
        ),
        trailing: Checkbox(
          value: done,
          onChanged: (v) => store.setPurchased(season, task.key, v ?? false),
        ),
        onTap: season.archived
            ? null
            : () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PermitBuyScreen(
                    seasonId: season.id,
                    onlyTaskKey: task.key,
                  ),
                ),
              ),
      ),
    );
  }
}

class _PermitFolder extends StatelessWidget {
  const _PermitFolder({required this.season, required this.tasks});
  final Season season;
  final List<PermitTask> tasks;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final files = store.filesForSeason(season.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.folder_outlined),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'permise/${season.folderName}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            TextButton.icon(
              icon: const Icon(Icons.upload_file),
              label: const Text('Adaugă'),
              onPressed: () => _add(context),
            ),
          ],
        ),
        if (files.isEmpty)
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text(
              'Permisele primite pe email (PDF) se importă aici, '
              'ca să le ai la control chiar fără semnal.',
            ),
          ),
        for (final f in files)
          ListTile(
            leading: Icon(
              f.fileName.toLowerCase().endsWith('.pdf')
                  ? Icons.picture_as_pdf_outlined
                  : Icons.image_outlined,
            ),
            title: Text(f.fileName),
            subtitle: Text(DateFormat('d MMM yyyy, HH:mm').format(f.addedAt)),
            onTap: () => _open(context, f),
            trailing: PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'share') await _share(store, f);
                if (v == 'delete') await store.deletePermitFile(f);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'share', child: Text('Trimite')),
                PopupMenuItem(value: 'delete', child: Text('Șterge')),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _add(BuildContext context) async {
    final store = context.read<AppStore>();
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );
    if (result.isEmpty || !context.mounted) return;
    final picked = result.single;
    final bytes = await picked.readAsBytes();
    if (!context.mounted) return;

    // Asociază fișierul unui permis → nume standard (ex. Ionescu_Mihai_Andrei_pescuit.pdf).
    final task = await showDialog<PermitTask?>(
      context: context,
      builder: (c) => SimpleDialog(
        title: const Text('Al cui e permisul?'),
        children: [
          for (final t in tasks)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(c, t),
              child: Text('${t.kind.label} — ${t.ownerName}'),
            ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(c, null),
            child: const Text('Păstrează numele original'),
          ),
        ],
      ),
    );
    final ext = picked.name.contains('.')
        ? picked.name.substring(picked.name.lastIndexOf('.'))
        : '';
    await store.addPermitFile(
      season: season,
      fileName: task == null ? picked.name : '${task.fileLabel}$ext',
      bytes: bytes,
      taskKey: task?.key,
    );
    if (task != null) await store.setPurchased(season, task.key, true);
  }

  Future<void> _open(BuildContext context, PermitFile f) async {
    final store = context.read<AppStore>();
    if (kIsWeb) {
      await _share(store, f);
      return;
    }
    final path = await store.permitFilePath(f);
    if (path != null) await OpenFilex.open(path);
  }

  Future<void> _share(AppStore store, PermitFile f) async {
    final bytes = await store.permitFileBytes(f);
    if (bytes == null) return;
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(bytes, name: f.fileName)],
        fileNameOverrides: [f.fileName],
      ),
    );
  }
}
