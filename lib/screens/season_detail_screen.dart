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
import 'permit_buy_screen.dart';
import 'seasons_screen.dart';

class SeasonDetailScreen extends StatelessWidget {
  const SeasonDetailScreen({super.key, required this.seasonId});
  final String seasonId;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final season = store.season(seasonId);
    if (season == null) return const Scaffold();
    final tasks = buildPermitTasks(
      season: season,
      participants: store.participants,
      boats: store.boats,
    );
    final pending = tasks
        .where((t) => season.purchased[t.key] != true)
        .toList();
    final fmt = DateFormat('d MMMM yyyy');
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(season.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_calendar_outlined),
            onPressed: () => showSeasonEditor(context, season: season),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _delete(context, season),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
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
          Text('${fmt.format(season.start)} – ${fmt.format(season.end)}'),
          const SizedBox(height: 16),

          // ---------- Participanți ----------
          Text('Participanți', style: text.titleMedium),
          const SizedBox(height: 4),
          if (store.participants.isEmpty)
            const Text(
              'Adaugă participanți din ecranul principal (iconița 👥).',
            ),
          Wrap(
            spacing: 8,
            children: [
              for (final p in store.participants)
                FilterChip(
                  label: Text(p.fullName),
                  avatar: p.category.freeAccess
                      ? const Icon(Icons.elderly, size: 18)
                      : null,
                  selected: season.participantIds.contains(p.id),
                  onSelected: (v) {
                    v
                        ? season.participantIds.add(p.id)
                        : season.participantIds.remove(p.id);
                    store.upsertSeason(season);
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text('Bărci', style: text.titleMedium),
          const SizedBox(height: 4),
          if (store.boats.isEmpty)
            const Text(
              'Nicio barcă — adaug-o din ecranul principal (iconița 🚤).',
            ),
          Wrap(
            spacing: 8,
            children: [
              for (final b in store.boats)
                FilterChip(
                  label: Text(b.denumire),
                  selected: season.boatIds.contains(b.id),
                  onSelected: (v) {
                    v ? season.boatIds.add(b.id) : season.boatIds.remove(b.id);
                    store.upsertSeason(season);
                  },
                ),
            ],
          ),
          const SizedBox(height: 16),

          // ---------- Perioada permiselor ----------
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
                await store.upsertSeason(season);
              },
            ),
          ),
          const SizedBox(height: 12),
          // ---------- Durate ----------
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

          // ---------- Permise ----------
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
          const SizedBox(height: 20),

          // ---------- Folderul permise ----------
          _PermitFolder(season: season, tasks: tasks),
        ],
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

    // Asociază fișierul unui permis → nume standard (ex. Pop_Simion_Adrian_pescuit.pdf).
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
