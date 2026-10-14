import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/app_store.dart';
import '../models/need_item.dart';
import '../models/season.dart';
import '../theme.dart';
import '../widgets/need_picker.dart';
import '../widgets/swipe_delete.dart';
import 'need_categories_screen.dart';

/// Pagina „Necesar”: ce trebuie pregătit pentru sezon, pe 7 categorii,
/// fiecare cu rânduri numerotate.
class NeedsScreen extends StatelessWidget {
  const NeedsScreen({super.key, required this.seasonId, this.initialTab = 0});
  final String seasonId;

  /// Categoria deschisă la intrare (0 = Echipament pescuit).
  final int initialTab;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final season = store.season(seasonId);
    if (season == null) return const Scaffold();
    final cats = store.needCategories;
    if (cats.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text('Necesar · ${season.title}')),
        body: Center(
          child: FilledButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Creează o categorie'),
            onPressed: () => editNeedCategory(context, null),
          ),
        ),
      );
    }
    return DefaultTabController(
      // se reconstruiește când se schimbă categoriile
      key: ValueKey(cats.map((c) => c.id).join('|')),
      length: cats.length,
      initialIndex: initialTab.clamp(0, cats.length - 1),
      child: Scaffold(
        appBar: AppBar(
          title: Text('Necesar · ${season.title}'),
          actions: [
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'copy') _pick(context, store, season);
                if (v == 'share') _share(store, season);
                if (v == 'cats') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const NeedCategoriesScreen(),
                    ),
                  );
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'copy',
                  child: ListTile(
                    leading: Icon(Icons.history),
                    title: Text('Alege din alte sezoane'),
                  ),
                ),
                PopupMenuItem(
                  value: 'share',
                  child: ListTile(
                    leading: Icon(Icons.share),
                    title: Text('Trimite lista'),
                  ),
                ),
                PopupMenuItem(
                  value: 'cats',
                  child: ListTile(
                    leading: Icon(Icons.category_outlined),
                    title: Text('Categorii (adaugă / modifică)'),
                  ),
                ),
              ],
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              for (final (i, c) in cats.indexed)
                Tab(
                  child: _TabLabel(index: i + 1, category: c, season: season),
                ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            for (final c in cats)
              _NeedList(key: ValueKey(c.id), season: season, category: c),
          ],
        ),
      ),
    );
  }

  Future<void> _pick(
    BuildContext context,
    AppStore store,
    Season season,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final added = await pickNeedsFromOtherSeasons(context, store, season);
    if (added > 0) {
      messenger.showSnackBar(
        SnackBar(content: Text('Am adăugat $added rânduri.')),
      );
    }
  }

  Future<void> _share(AppStore store, Season season) async {
    final b = StringBuffer(
      'NECESAR — ${season.title} (${season.place.name})\n',
    );
    for (final (ci, c) in store.needCategories.indexed) {
      final items = season
          .needsOf(c)
          .where((i) => i.text.trim().isNotEmpty)
          .toList();
      if (items.isEmpty) continue;
      b.writeln('\n${ci + 1}. ${c.label.toUpperCase()}');
      for (final (i, item) in items.indexed) {
        b.writeln('  ${i + 1}. ${item.done ? '✅' : '⬜'} ${item.text.trim()}');
      }
    }
    await SharePlus.instance.share(ShareParams(text: b.toString()));
  }
}

class _TabLabel extends StatelessWidget {
  const _TabLabel({
    required this.index,
    required this.category,
    required this.season,
  });
  final int index;
  final NeedCategory category;
  final Season season;

  @override
  Widget build(BuildContext context) {
    final items = season
        .needsOf(category)
        .where((i) => i.text.trim().isNotEmpty);
    final total = items.length;
    final done = items.where((i) => i.done).length;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 10,
          backgroundColor: Sea.sunset,
          child: Text(
            '$index',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Sea.navy,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(category.label),
        if (total > 0) ...[
          const SizedBox(width: 6),
          Text(
            '$done/$total',
            style: TextStyle(
              fontSize: 11,
              color: done == total ? Sea.aqua : Colors.white70,
            ),
          ),
        ],
      ],
    );
  }
}

/// Lista numerotată a unei categorii, cu rând gol de adăugare la final.
class _NeedList extends StatefulWidget {
  const _NeedList({super.key, required this.season, required this.category});
  final Season season;
  final NeedCategory category;

  @override
  State<_NeedList> createState() => _NeedListState();
}

class _NeedListState extends State<_NeedList>
    with AutomaticKeepAliveClientMixin {
  final _controllers = <String, TextEditingController>{};
  final _newItem = TextEditingController();
  final _newFocus = FocusNode();

  List<NeedItem> get _items => widget.season.needsOf(widget.category);

  @override
  bool get wantKeepAlive => true;

  TextEditingController _controllerFor(NeedItem item) => _controllers
      .putIfAbsent(item.id, () => TextEditingController(text: item.text));

  void _save() => context.read<AppStore>().upsertSeason(widget.season);

  void _add() {
    final text = _newItem.text.trim();
    if (text.isEmpty) return;
    setState(() => _items.add(NeedItem(id: newId(), text: text)));
    _newItem.clear();
    _newFocus.requestFocus(); // scrii rândul următor imediat
    _save();
  }

  void _remove(NeedItem item) {
    setState(() => _items.remove(item));
    _controllers.remove(item.id)?.dispose();
    _save();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _newItem.dispose();
    _newFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final scheme = Theme.of(context).colorScheme;
    final items = _items;
    final done = items.where((i) => i.done).length;
    return Column(
      children: [
        if (items.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: done / items.length,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                    color: done == items.length ? Sea.good : Sea.ocean,
                  ),
                ),
                const SizedBox(width: 12),
                Text('$done/${items.length} ${widget.category.doneLabel}'),
              ],
            ),
          ),
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            buildDefaultDragHandles: false,
            itemCount: items.length,
            onReorderItem: (from, to) {
              setState(() => items.insert(to, items.removeAt(from)));
              _save();
            },
            itemBuilder: (context, i) {
              final item = items[i];
              return SwipeToDelete(
                key: ValueKey(item.id),
                id: item.id,
                number: i + 1,
                text: _controllerFor(item).text,
                onDelete: () => _remove(item),
                child: Card(
                  margin: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      ReorderableDragStartListener(
                        index: i,
                        child: Container(
                          width: 64,
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.drag_indicator,
                                size: 20,
                                color: scheme.outline,
                              ),
                              Text(
                                '${i + 1}.',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                  color: item.done
                                      ? scheme.outline
                                      : scheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _controllerFor(item),
                          maxLines: null,
                          style: TextStyle(
                            decoration: item.done
                                ? TextDecoration.lineThrough
                                : null,
                            color: item.done ? scheme.outline : null,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            filled: false,
                            isDense: true,
                          ),
                          onChanged: (v) {
                            item.text = v;
                            _save();
                          },
                        ),
                      ),
                      Checkbox(
                        value: item.done,
                        onChanged: (v) {
                          setState(() => item.done = v ?? false);
                          _save();
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        // rândul de adăugare, numerotat cu numărul următor
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            decoration: BoxDecoration(
              color: scheme.surfaceContainer,
              border: Border(top: BorderSide(color: scheme.outlineVariant)),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 44,
                  child: Text(
                    '${items.length + 1}.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: scheme.primary,
                    ),
                  ),
                ),
                Expanded(
                  child: RawAutocomplete<String>(
                    textEditingController: _newItem,
                    focusNode: _newFocus,
                    optionsBuilder: (v) {
                      final q = v.text.trim().toLowerCase();
                      if (q.isEmpty) return const [];
                      return needSuggestions(
                            context.read<AppStore>(),
                            widget.season,
                            widget.category,
                          )
                          .map((s) => s.text)
                          .where((t) => t.toLowerCase().contains(q));
                    },
                    onSelected: (_) => _add(),
                    optionsViewOpenDirection: OptionsViewOpenDirection.up,
                    optionsViewBuilder: (context, onSelected, options) => Align(
                      alignment: Alignment.bottomLeft,
                      child: Material(
                        elevation: 4,
                        borderRadius: BorderRadius.circular(12),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxHeight: 220,
                            maxWidth: 320,
                          ),
                          child: ListView(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            children: [
                              for (final o in options)
                                ListTile(
                                  dense: true,
                                  leading: const Icon(Icons.history, size: 18),
                                  title: Text(o),
                                  onTap: () => onSelected(o),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    fieldViewBuilder: (context, controller, focus, onSubmit) =>
                        TextField(
                          controller: controller,
                          focusNode: focus,
                          textCapitalization: TextCapitalization.sentences,
                          textInputAction: TextInputAction.next,
                          onSubmitted: (_) => _add(),
                          decoration: InputDecoration(
                            hintText:
                                'Scrie aici (${widget.category.label.toLowerCase()})…',
                          ),
                        ),
                  ),
                ),
                IconButton(
                  tooltip: 'Alege din alte sezoane',
                  icon: const Icon(Icons.history),
                  onPressed: () async {
                    final added = await pickNeedsFromOtherSeasons(
                      context,
                      context.read<AppStore>(),
                      widget.season,
                      only: widget.category,
                    );
                    if (added > 0) setState(() {});
                  },
                ),
                IconButton.filled(onPressed: _add, icon: const Icon(Icons.add)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
