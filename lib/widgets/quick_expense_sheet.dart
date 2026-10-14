import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/expense.dart';
import '../models/season.dart';
import '../screens/expenses_screen.dart';
import '../theme.dart';

String _fold(String s) => s
    .toLowerCase()
    .replaceAll('ă', 'a')
    .replaceAll('â', 'a')
    .replaceAll('î', 'i')
    .replaceAll('ș', 's')
    .replaceAll('ş', 's')
    .replaceAll('ț', 't')
    .replaceAll('ţ', 't');

/// Iconița unui bun: întâi după cuvintele din nume (gheață, băutură…),
/// apoi după categorie.
IconData expenseIcon(String category, [String name = '']) {
  final n = _fold(name);
  bool has(List<String> words) => words.any(n.contains);
  if (has(['gheata', 'ghiata'])) return Icons.ac_unit;
  if (has(['bere'])) return Icons.sports_bar;
  if (has(['vin'])) return Icons.wine_bar;
  if (has(['cafea'])) return Icons.local_cafe;
  if (has(['apa', 'bautur', 'suc', 'racoritoare'])) return Icons.local_drink;
  if (has(['paine', 'mancare', 'alimente', 'carne', 'gratar'])) {
    return Icons.restaurant;
  }
  if (has(['benzina', 'combustibil', 'carburant'])) {
    return Icons.local_gas_station;
  }
  if (has(['motorina', 'masina', 'autostrada', 'rovinieta', 'parcare'])) {
    return Icons.directions_car;
  }
  if (has(['ulei'])) return Icons.oil_barrel;
  if (has(['momeal', 'nada', 'rame', 'viermi', 'porumb', 'boilies'])) {
    return Icons.phishing;
  }
  if (has(['carlig', 'fir', 'plumb', 'naluc', 'lanset', 'mulineta'])) {
    return Icons.construction;
  }
  if (has(['cazare', 'pensiune', 'cort', 'camera'])) return Icons.hotel;
  if (has(['permis'])) return Icons.badge;
  if (has(['barca', 'ambarcat', 'motor'])) return Icons.directions_boat;
  return switch (category) {
    'Combustibil' => Icons.local_gas_station,
    'Mâncare-Băutură' => Icons.restaurant,
    'Momeli' => Icons.phishing,
    'Cazare' => Icons.hotel,
    'Transport' => Icons.directions_car,
    'Permise' => Icons.badge,
    'Echipament' => Icons.construction,
    _ => Icons.receipt_long,
  };
}

/// Cheltuială rapidă, pentru barcă: presetare → sumă → salvează.
/// Data și ora se pun automat; plătitorul implicit e ultimul folosit.
Future<void> showQuickExpense(
  BuildContext context,
  Season season, {
  ExpensePreset? preset,
}) async {
  if (season.participantIds.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bifează întâi participanții sezonului.')),
    );
    return;
  }
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.92,
      child: _QuickExpense(season: season, initialPreset: preset),
    ),
  );
}

class _QuickExpense extends StatefulWidget {
  const _QuickExpense({required this.season, this.initialPreset});
  final Season season;
  final ExpensePreset? initialPreset;

  @override
  State<_QuickExpense> createState() => _QuickExpenseState();
}

class _QuickExpenseState extends State<_QuickExpense> {
  ExpensePreset? _preset;
  String _amount = '';
  late String _payer;
  bool _common = true;
  int _savedCount = 0;

  @override
  void initState() {
    super.initState();
    final store = context.read<AppStore>();
    final last = store.lastPayerId;
    _payer = widget.season.participantIds.contains(last)
        ? last!
        : widget.season.participantIds.first;
    if (widget.initialPreset != null) _choose(widget.initialPreset!);
  }

  void _choose(ExpensePreset p) {
    setState(() {
      _preset = p;
      _common = p.common;
      _amount = p.amount == null ? '' : _fmt(p.amount!);
    });
  }

  String _fmt(double v) => v == v.roundToDouble()
      ? v.toStringAsFixed(0)
      : v.toStringAsFixed(2).replaceAll('.', ',');

  double get _value => double.tryParse(_amount.replaceAll(',', '.')) ?? 0;

  void _key(String k) {
    setState(() {
      if (k == '⌫') {
        if (_amount.isNotEmpty) {
          _amount = _amount.substring(0, _amount.length - 1);
        }
      } else if (k == ',') {
        if (!_amount.contains(',')) {
          _amount = _amount.isEmpty ? '0,' : '$_amount,';
        }
      } else {
        final dec = _amount.indexOf(',');
        if (dec >= 0 && _amount.length - dec > 2) return; // max 2 zecimale
        if (_amount == '0') _amount = '';
        if (_amount.length < 7) _amount += k;
      }
    });
  }

  Future<void> _save({required bool another}) async {
    final store = context.read<AppStore>();
    final messenger = ScaffoldMessenger.of(context);
    final season = widget.season;
    final p = _preset!;
    final e = Expense(
      id: newId(),
      description: p.name,
      amount: _value,
      paidBy: _payer,
      common: _common,
      sharedWith: _common ? List.of(season.participantIds) : [_payer],
      date: DateTime.now(),
      category: p.category,
      presetId: p.id.isEmpty ? null : p.id,
    );
    e.number = numberExpenses(season.expenses);
    season.expenses.add(e);
    store.lastPayerId = _payer;
    await store.upsertSeason(season);
    messenger.showSnackBar(
      SnackBar(
        content: Text('✓ #${e.number} ${p.name} · ${lei(e.amount)}'),
        duration: const Duration(seconds: 2),
      ),
    );
    if (!mounted) return;
    if (another) {
      setState(() {
        _savedCount++;
        _amount = p.amount == null ? '' : _fmt(p.amount!);
      });
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _preset == null ? _presetGrid(context) : _amountPad(context);
  }

  // ---------- pasul 1: ce s-a cumpărat ----------
  Widget _presetGrid(BuildContext context) {
    final store = context.watch<AppStore>();
    final presets = store.expensePresets;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Ce s-a cumpărat?',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: GridView.count(
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.95,
              children: [
                for (final p in presets)
                  _BigTile(
                    icon: expenseIcon(p.category, p.name),
                    label: p.name,
                    sub: p.amount == null ? null : lei(p.amount!),
                    color: p.common ? Sea.ocean : Sea.sunset,
                    onTap: () => _choose(p),
                  ),
                _BigTile(
                  icon: Icons.edit_note,
                  label: 'Altceva\n(formular)',
                  color: Colors.blueGrey,
                  onTap: () {
                    Navigator.pop(context);
                    openExpenseEditor(context, widget.season);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------- pasul 2: suma, cine a plătit, salvează ----------
  Widget _amountPad(BuildContext context) {
    final store = context.read<AppStore>();
    final p = _preset!;
    final people = [
      for (final id in widget.season.participantIds) ?store.participant(id),
    ];
    final canSave = _value > 0;
    final color = _common ? Sea.ocean : Sea.sunset;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _preset = null),
              ),
              Icon(expenseIcon(p.category, p.name), color: color, size: 28),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  p.name,
                  style: Theme.of(context).textTheme.titleLarge,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_savedCount > 0) Chip(label: Text('$_savedCount salvate')),
            ],
          ),
          // suma, mare
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '${_amount.isEmpty ? '0' : _amount} lei',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w800,
                color: _amount.isEmpty ? Colors.grey : color,
              ),
            ),
          ),
          // cine a plătit — butoane mari
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (final person in people)
                ChoiceChip(
                  label: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 6,
                    ),
                    child: Text(
                      person.fullName,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                  avatar: const Icon(Icons.person),
                  selected: _payer == person.id,
                  onSelected: (_) => setState(() => _payer = person.id),
                ),
            ],
          ),
          const SizedBox(height: 8),
          // comun / proprie — un singur buton mare
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: true,
                icon: Icon(Icons.groups),
                label: Text('La comun'),
              ),
              ButtonSegment(
                value: false,
                icon: Icon(Icons.person),
                label: Text('Proprie'),
              ),
            ],
            selected: {_common},
            onSelectionChanged: (v) => setState(() => _common = v.first),
          ),
          const SizedBox(height: 8),
          // tastatura
          Expanded(
            child: GridView.count(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.1,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (final k in [
                  '1',
                  '2',
                  '3',
                  '4',
                  '5',
                  '6',
                  '7',
                  '8',
                  '9',
                  ',',
                  '0',
                  '⌫',
                ])
                  FilledButton.tonal(
                    style: FilledButton.styleFrom(
                      padding: EdgeInsets.zero,
                      textStyle: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onPressed: () => _key(k),
                    child: k == '⌫'
                        ? const Icon(Icons.backspace_outlined, size: 26)
                        : Text(k),
                  ),
              ],
            ),
          ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                  ),
                  onPressed: canSave ? () => _save(another: true) : null,
                  child: const Text('Salvează + încă una'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    textStyle: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onPressed: canSave ? () => _save(another: false) : null,
                  icon: const Icon(Icons.check),
                  label: const Text('Salvează'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BigTile extends StatelessWidget {
  const _BigTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.sub,
  });
  final IconData icon;
  final String label;
  final String? sub;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 38, color: color),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              if (sub != null)
                Text(sub!, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}
