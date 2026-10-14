import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/need_item.dart';
import '../theme.dart';

/// Categoriile paginii „Necesar”: adaugi, redenumești, ștergi, reordonezi.
class NeedCategoriesScreen extends StatelessWidget {
  const NeedCategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final cats = store.needCategories;
    return Scaffold(
      appBar: AppBar(title: const Text('Categorii necesar')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => editNeedCategory(context, null),
        icon: const Icon(Icons.add),
        label: const Text('Categorie nouă'),
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              'Categoriile sunt aceleași în toate sezoanele. '
              'Ține apăsat pe număr ca să schimbi ordinea.',
            ),
          ),
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 96),
              buildDefaultDragHandles: false,
              itemCount: cats.length,
              onReorderItem: store.reorderNeedCategory,
              itemBuilder: (context, i) {
                final c = cats[i];
                final count = store.needItemsIn(c);
                return Card(
                  key: ValueKey(c.id),
                  child: ListTile(
                    leading: ReorderableDragStartListener(
                      index: i,
                      child: CircleAvatar(
                        radius: 15,
                        backgroundColor: Sea.sunset,
                        child: Text(
                          '${i + 1}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Sea.navy,
                          ),
                        ),
                      ),
                    ),
                    title: Text(c.label),
                    subtitle: Text(
                      'bifa = „${c.doneLabel}” · $count rânduri în sezoane',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Modifică',
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => editNeedCategory(context, c),
                        ),
                        IconButton(
                          tooltip: 'Șterge',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _delete(context, store, c, count),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _delete(
    BuildContext context,
    AppStore store,
    NeedCategory c,
    int count,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('Ștergi categoria „${c.label}”?'),
        content: Text(
          count == 0
              ? 'Categoria nu are rânduri.'
              : 'Se șterg și cele $count rânduri ale ei din toate sezoanele.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const Text('Anulează'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(d, true),
            child: const Text('Șterge'),
          ),
        ],
      ),
    );
    if (ok == true) await store.deleteNeedCategory(c);
  }
}

/// Dialog de creare (c == null) sau modificare a unei categorii.
Future<void> editNeedCategory(BuildContext context, NeedCategory? c) async {
  final store = context.read<AppStore>();
  final label = TextEditingController(text: c?.label ?? '');
  var doneLabel = c?.doneLabel ?? 'pregătit';
  const options = ['pregătit', 'cumpărat', 'rezolvat', 'remediat', 'bifat'];
  await showDialog(
    context: context,
    builder: (d) => StatefulBuilder(
      builder: (d, setState) => AlertDialog(
        title: Text(c == null ? 'Categorie nouă' : 'Modifică categoria'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: label,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Nume (ex. Medicamente)',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: options.contains(doneLabel) ? doneLabel : 'bifat',
              decoration: const InputDecoration(labelText: 'Bifa înseamnă'),
              items: [
                for (final o in options)
                  DropdownMenuItem(value: o, child: Text(o)),
              ],
              onChanged: (v) => setState(() => doneLabel = v!),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d),
            child: const Text('Anulează'),
          ),
          FilledButton(
            onPressed: () async {
              final name = label.text.trim();
              if (name.isEmpty) return;
              if (c == null) {
                await store.addNeedCategory(name, doneLabel: doneLabel);
              } else {
                c
                  ..label = name
                  ..doneLabel = doneLabel;
                await store.updateNeedCategory(c);
              }
              if (d.mounted) Navigator.pop(d);
            },
            child: const Text('Salvează'),
          ),
        ],
      ),
    ),
  );
}
