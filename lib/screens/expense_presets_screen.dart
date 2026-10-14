import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/expense.dart';
import '../theme.dart';
import '../widgets/quick_expense_sheet.dart';
import 'expenses_screen.dart';

/// Bunurile pentru care se fac des cheltuieli (comune sau personale).
class ExpensePresetsScreen extends StatelessWidget {
  const ExpensePresetsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    return Scaffold(
      appBar: AppBar(title: const Text('Presetări cheltuieli')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => editPreset(context, null),
        icon: const Icon(Icons.add),
        label: const Text('Presetare'),
      ),
      body: store.expensePresets.isEmpty
          ? const Center(child: Text('Nicio presetare.'))
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(4, 0, 4, 8),
                  child: Text(
                    'Bunuri pentru care se fac des cheltuieli. La o cheltuială '
                    'nouă le alegi cu o atingere.',
                  ),
                ),
                for (final p in store.expensePresets)
                  Card(
                    child: ListTile(
                      leading: Icon(
                        expenseIcon(p.category, p.name),
                        color: p.common ? Sea.ocean : Sea.sunset,
                      ),
                      title: Text(p.name),
                      subtitle: Text(
                        '${p.category} · ${p.common ? 'comună' : 'personală'}'
                        '${p.amount != null ? ' · ${lei(p.amount!)}' : ''}',
                      ),
                      trailing: const Icon(Icons.edit_outlined),
                      onTap: () => editPreset(context, p),
                    ),
                  ),
              ],
            ),
    );
  }
}

Future<void> editPreset(BuildContext context, ExpensePreset? preset) async {
  final store = context.read<AppStore>();
  final name = TextEditingController(text: preset?.name ?? '');
  final amount = TextEditingController(
    text: preset?.amount?.toStringAsFixed(2) ?? '',
  );
  var category = preset?.category ?? 'Altele';
  var common = preset?.common ?? true;
  await showDialog(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, setState) => AlertDialog(
        title: Text(preset == null ? 'Presetare nouă' : 'Editare presetare'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              autofocus: preset == null,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Bun (ex. Benzină barcă)',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: expenseCategories.contains(category)
                  ? category
                  : 'Altele',
              decoration: const InputDecoration(labelText: 'Categorie'),
              items: [
                for (final cat in expenseCategories)
                  DropdownMenuItem(value: cat, child: Text(cat)),
              ],
              onChanged: (v) => setState(() => category = v!),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Suma obișnuită (opțional)',
                suffixText: 'lei',
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: common,
              onChanged: (v) => setState(() => common = v),
              title: Text(common ? 'Comună (se împarte egal)' : 'Personală'),
            ),
          ],
        ),
        actions: [
          if (preset != null)
            TextButton(
              onPressed: () async {
                await store.deletePreset(preset.id);
                if (c.mounted) Navigator.pop(c);
              },
              child: const Text('Șterge'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Anulează'),
          ),
          FilledButton(
            onPressed: () async {
              if (name.text.trim().isEmpty) return;
              final p = preset ?? ExpensePreset(id: newId(), name: '');
              p
                ..name = name.text.trim()
                ..category = category
                ..common = common
                ..amount = double.tryParse(amount.text.replaceAll(',', '.'));
              await store.upsertPreset(p);
              if (c.mounted) Navigator.pop(c);
            },
            child: const Text('Salvează'),
          ),
        ],
      ),
    ),
  );
}
