import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/app_store.dart';
import '../models/need_item.dart';
import '../models/season.dart';
import '../theme.dart';

/// Pagina „Necesar”: ce trebuie pregătit pentru sezon, pe 7 categorii,
/// fiecare cu rânduri numerotate.
class NeedsScreen extends StatelessWidget {
  const NeedsScreen({super.key, required this.seasonId});
  final String seasonId;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final season = store.season(seasonId);
    if (season == null) return const Scaffold();
    return DefaultTabController(
      length: NeedCategory.values.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Necesar · ${season.title}'),
          actions: [
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'copy') _copyFromPrevious(context, store, season);
                if (v == 'share') _share(season);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'copy',
                  child: ListTile(
                    leading: Icon(Icons.content_copy),
                    title: Text('Preia din sezonul anterior'),
                  ),
                ),
                PopupMenuItem(
                  value: 'share',
                  child: ListTile(
                    leading: Icon(Icons.share),
                    title: Text('Trimite lista'),
                  ),
                ),
              ],
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              for (final (i, c) in NeedCategory.values.indexed)
                Tab(
                  child: _TabLabel(index: i + 1, category: c, season: season),
                ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            for (final c in NeedCategory.values)
              _NeedList(key: ValueKey(c), season: season, category: c),
          ],
        ),
      ),
    );
  }

  Future<void> _copyFromPrevious(
    BuildContext context,
    AppStore store,
    Season season,
  ) async {
    final previous =
        store.seasons
            .where(
              (s) =>
                  s.id != season.id &&
                  s.start.isBefore(season.start) &&
                  s.needs.values.any((l) => l.isNotEmpty),
            )
            .toList()
          ..sort((a, b) => b.start.compareTo(a.start));
    final messenger = ScaffoldMessenger.of(context);
    if (previous.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Niciun sezon anterior cu listă de necesar.'),
        ),
      );
      return;
    }
    final from = previous.first;
    var added = 0;
    for (final c in NeedCategory.values) {
      // problemele remediate nu se mai preiau
      final source = from
          .needsOf(c)
          .where(
            (i) =>
                i.text.trim().isNotEmpty &&
                !(c == NeedCategory.probleme && i.done),
          );
      final target = season.needsOf(c);
      final existing = target.map((i) => i.text.trim().toLowerCase()).toSet();
      for (final i in source) {
        if (existing.contains(i.text.trim().toLowerCase())) continue;
        target.add(NeedItem(id: newId(), text: i.text));
        added++;
      }
    }
    await store.upsertSeason(season);
    messenger.showSnackBar(
      SnackBar(content: Text('Am preluat $added rânduri din ${from.title}.')),
    );
  }

  Future<void> _share(Season season) async {
    final b = StringBuffer(
      'NECESAR — ${season.title} (${season.place.name})\n',
    );
    for (final (ci, c) in NeedCategory.values.indexed) {
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
    final index = _items.indexOf(item);
    setState(() => _items.remove(item));
    _save();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Șters: ${item.text}'),
          action: SnackBarAction(
            label: 'Anulează',
            onPressed: () {
              setState(
                () => _items.insert(index.clamp(0, _items.length), item),
              );
              _save();
            },
          ),
        ),
      );
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
              return Dismissible(
                key: ValueKey(item.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  color: Sea.coral,
                  child: const Icon(Icons.delete_outline, color: Colors.white),
                ),
                onDismissed: (_) => _remove(item),
                child: Card(
                  margin: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      ReorderableDragStartListener(
                        index: i,
                        child: Container(
                          width: 44,
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Text(
                            '${i + 1}.',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: item.done
                                  ? scheme.outline
                                  : scheme.primary,
                            ),
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
                  child: TextField(
                    controller: _newItem,
                    focusNode: _newFocus,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) => _add(),
                    decoration: InputDecoration(
                      hintText:
                          'Scrie aici (${widget.category.label.toLowerCase()})…',
                    ),
                  ),
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
