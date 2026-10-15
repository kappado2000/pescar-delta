import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/season.dart';
import '../theme.dart';

/// Cardul de avertisment cu problemele nerezolvate din sezoanele anterioare.
/// Fiecare se poate bifa ca remediată (se bifează în sezonul ei).
class OpenProblemsCard extends StatelessWidget {
  const OpenProblemsCard({super.key, required this.season});
  final Season season;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final open = store.openProblemsBefore(season);
    if (open.isEmpty) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;
    return Card(
      color: Sea.bad.withValues(alpha: 0.10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Sea.bad, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Sea.bad),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Probleme nerezolvate din sezoanele anterioare (${open.length})',
                    style: text.titleSmall?.copyWith(color: Sea.bad),
                  ),
                ),
              ],
            ),
            for (final (from, item) in open)
              CheckboxListTile(
                dense: true,
                contentPadding: const EdgeInsets.only(left: 4, right: 4),
                value: false,
                controlAffinity: ListTileControlAffinity.trailing,
                title: Text(item.text),
                subtitle: Text('din ${from.title} · bifează când e remediată'),
                onChanged: (v) {
                  if (v != true) return;
                  item.done = true;
                  store.upsertSeason(from);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Remediată: ${item.text}')),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

/// Rândul scurt de avertisment (Acasă / Rezumat), cu salt la Necesar.
class OpenProblemsRow extends StatelessWidget {
  const OpenProblemsRow({super.key, required this.season, required this.onTap});
  final Season season;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final n = context.watch<AppStore>().openProblemsBefore(season).length;
    if (n == 0) return const SizedBox.shrink();
    return Card(
      color: Sea.bad.withValues(alpha: 0.10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Sea.bad, width: 1),
      ),
      child: ListTile(
        leading: const Icon(Icons.warning_amber_rounded, color: Sea.bad),
        title: Text(
          n == 1 ? '1 problemă nerezolvată' : '$n probleme nerezolvate',
          style: const TextStyle(fontWeight: FontWeight.w700, color: Sea.bad),
        ),
        subtitle: const Text('din sezoanele anterioare'),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
