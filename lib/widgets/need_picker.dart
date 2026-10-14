import 'package:flutter/material.dart';

import '../data/app_store.dart';
import '../models/need_item.dart';
import '../models/season.dart';
import '../theme.dart';

/// O variantă scrisă în alte sezoane, cu sezoanele în care a apărut.
class NeedSuggestion {
  NeedSuggestion(this.text, this.seasons);
  final String text;
  final List<String> seasons;
}

String _norm(String s) => s.trim().toLowerCase();

/// Toate variantele scrise în alte sezoane pentru categoria [c], fără cele
/// deja prezente în [season]. Problemele deja remediate nu se mai propun.
List<NeedSuggestion> needSuggestions(
  AppStore store,
  Season season,
  NeedCategory c,
) {
  final present = season.needsOf(c).map((i) => _norm(i.text)).toSet();
  final byText = <String, NeedSuggestion>{};
  final others = store.seasons.where((s) => s.id != season.id).toList()
    ..sort((a, b) => b.start.compareTo(a.start)); // cele mai recente primele
  for (final s in others) {
    for (final i in s.needsOf(c)) {
      final key = _norm(i.text);
      if (key.isEmpty || present.contains(key)) continue;
      if (c.isProblems && i.done) continue;
      byText
          .putIfAbsent(key, () => NeedSuggestion(i.text.trim(), []))
          .seasons
          .add(s.title);
    }
  }
  return byText.values.toList();
}

/// Ecranul de alegere: bifezi variantele din alte sezoane și le adaugi în
/// [season]. Cu [only] arată doar o categorie. Întoarce câte rânduri a adăugat.
Future<int> pickNeedsFromOtherSeasons(
  BuildContext context,
  AppStore store,
  Season season, {
  NeedCategory? only,
}) async {
  final categories = only == null ? store.needCategories : [only];
  final options = {
    for (final c in categories) c: needSuggestions(store, season, c),
  }..removeWhere((_, v) => v.isEmpty);
  if (options.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Nu există variante noi în alte sezoane.')),
    );
    return 0;
  }
  final picked = await Navigator.push<Map<NeedCategory, List<String>>>(
    context,
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _NeedPickerScreen(
        options: options,
        order: store.needCategories.map((c) => c.id).toList(),
      ),
    ),
  );
  if (picked == null) return 0;
  var added = 0;
  for (final e in picked.entries) {
    for (final text in e.value) {
      season.needsOf(e.key).add(NeedItem(id: newId(), text: text));
      added++;
    }
  }
  if (added > 0) await store.upsertSeason(season);
  return added;
}

class _NeedPickerScreen extends StatefulWidget {
  const _NeedPickerScreen({required this.options, required this.order});
  final Map<NeedCategory, List<NeedSuggestion>> options;

  /// id-urile categoriilor, în ordinea lor (pentru numerotare).
  final List<String> order;

  @override
  State<_NeedPickerScreen> createState() => _NeedPickerScreenState();
}

class _NeedPickerScreenState extends State<_NeedPickerScreen> {
  final Map<NeedCategory, Set<String>> _selected = {};
  String _filter = '';

  int get _count => _selected.values.fold(0, (s, v) => s + v.length);

  bool _visible(NeedSuggestion s) =>
      _filter.isEmpty || _norm(s.text).contains(_filter);

  void _toggleAll(bool select) {
    setState(() {
      for (final e in widget.options.entries) {
        final set = _selected.putIfAbsent(e.key, () => {});
        for (final s in e.value.where(_visible)) {
          select ? set.add(s.text) : set.remove(s.text);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final allSelected = widget.options.entries.every(
      (e) => e.value
          .where(_visible)
          .every((s) => _selected[e.key]?.contains(s.text) ?? false),
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alege din alte sezoane'),
        actions: [
          TextButton(
            onPressed: () => _toggleAll(!allSelected),
            child: Text(
              allSelected ? 'Deselectează' : 'Selectează tot',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Caută…',
              ),
              onChanged: (v) => setState(() => _filter = _norm(v)),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 16),
              children: [
                for (final e in widget.options.entries)
                  if (e.value.any(_visible)) ...[
                    _SectionHeader(
                      index: widget.order.indexOf(e.key.id),
                      category: e.key,
                      selected: _selected[e.key]?.length ?? 0,
                      total: e.value.length,
                      onToggle: (select) => setState(() {
                        final set = _selected.putIfAbsent(e.key, () => {});
                        for (final s in e.value.where(_visible)) {
                          select ? set.add(s.text) : set.remove(s.text);
                        }
                      }),
                    ),
                    for (final s in e.value.where(_visible))
                      CheckboxListTile(
                        dense: true,
                        value: _selected[e.key]?.contains(s.text) ?? false,
                        title: Text(s.text),
                        subtitle: Text(
                          s.seasons.length == 1
                              ? s.seasons.first
                              : '${s.seasons.first} și încă ${s.seasons.length - 1}',
                        ),
                        onChanged: (v) => setState(() {
                          final set = _selected.putIfAbsent(e.key, () => {});
                          v == true ? set.add(s.text) : set.remove(s.text);
                        }),
                      ),
                  ],
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton.icon(
            onPressed: _count == 0
                ? null
                : () => Navigator.pop(context, {
                    for (final e in _selected.entries)
                      if (e.value.isNotEmpty)
                        e.key: [
                          // păstrăm ordinea din listă
                          for (final s in widget.options[e.key]!)
                            if (e.value.contains(s.text)) s.text,
                        ],
                  }),
            icon: const Icon(Icons.playlist_add),
            label: Text('Adaugă $_count'),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.index,
    required this.category,
    required this.selected,
    required this.total,
    required this.onToggle,
  });
  final int index;
  final NeedCategory category;
  final int selected;
  final int total;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Sea.foam.withValues(alpha: 0.6),
      padding: const EdgeInsets.fromLTRB(16, 6, 4, 6),
      child: Row(
        children: [
          CircleAvatar(
            radius: 11,
            backgroundColor: needsColor(context),
            child: Text(
              '${index + 1}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: needsOnColor(context),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${category.label} ($selected/$total)',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Sea.navy,
              ),
            ),
          ),
          TextButton(
            onPressed: () => onToggle(selected < total),
            child: Text(selected < total ? 'Toate' : 'Niciunul'),
          ),
        ],
      ),
    );
  }
}
