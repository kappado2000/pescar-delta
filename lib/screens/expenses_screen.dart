import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/app_store.dart';
import '../models/expense.dart';
import '../models/season.dart';
import '../theme.dart';
import 'expense_presets_screen.dart';

final _lei = NumberFormat.currency(
  locale: 'ro',
  symbol: 'lei',
  decimalDigits: 2,
);
String lei(double v) => _lei.format(v);

/// Cheltuielile sezonului: lista, situația pe participant și decontarea.
class ExpensesScreen extends StatelessWidget {
  const ExpensesScreen({super.key, required this.seasonId});
  final String seasonId;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final season = store.season(seasonId);
    if (season == null) return const Scaffold();
    final total = season.expenses.fold<double>(0, (s, e) => s + e.amount);
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Cheltuieli · ${season.title}'),
          actions: [
            IconButton(
              tooltip: 'Presetări',
              icon: const Icon(Icons.bookmarks_outlined),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ExpensePresetsScreen()),
              ),
            ),
            IconButton(
              tooltip: 'Trimite decontarea',
              icon: const Icon(Icons.share),
              onPressed: season.expenses.isEmpty
                  ? null
                  : () => _shareSettlement(store, season),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Cheltuieli'),
              Tab(text: 'Pe participant'),
              Tab(text: 'Decontare'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _edit(context, season, null),
          icon: const Icon(Icons.add),
          label: const Text('Cheltuială'),
        ),
        body: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: Sea.foam.withValues(alpha: 0.6),
              child: Text(
                'Total sezon: ${lei(total)} · ${season.expenses.length} cheltuieli',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Sea.navy,
                ),
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _ExpenseList(
                    season: season,
                    onEdit: (e) => _edit(context, season, e),
                  ),
                  _PerParticipant(season: season),
                  _Settlement(season: season),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _edit(BuildContext context, Season season, Expense? e) {
    if (season.participantIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bifează întâi participanții sezonului.')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExpenseEditScreen(season: season, expense: e),
      ),
    );
  }

  Future<void> _shareSettlement(AppStore store, Season season) async {
    String name(String id) => store.participant(id)?.fullName ?? '?';
    final balances = balancesOf(season.expenses, season.participantIds);
    final total = season.expenses.fold<double>(0, (s, e) => s + e.amount);
    final b = StringBuffer(
      'CHELTUIELI — ${season.title} (${season.place.name})\n',
    )..writeln('Total: ${lei(total)}\n');
    for (final x in balances.values) {
      b.writeln(
        '• ${name(x.participantId)}: a plătit ${lei(x.paid)}, '
        'partea lui ${lei(x.owes)} → '
        '${x.balance >= 0 ? 'primește' : 'dă'} ${lei(x.balance.abs())}',
      );
    }
    final transfers = settle(balances);
    b.writeln('\nDECONTARE:');
    if (transfers.isEmpty) b.writeln('Nimeni nu datorează nimic.');
    for (final (i, t) in transfers.indexed) {
      b.writeln(
        '${i + 1}. ${name(t.from)} îi dă lui ${name(t.to)} ${lei(t.amount)}',
      );
    }
    await SharePlus.instance.share(ShareParams(text: b.toString()));
  }
}

class _ExpenseList extends StatelessWidget {
  const _ExpenseList({required this.season, required this.onEdit});
  final Season season;
  final void Function(Expense) onEdit;

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    final list = season.expenses.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    if (list.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Nicio cheltuială încă.\n'
            'Adaugă ce s-a plătit: cine a plătit și dacă e comună '
            '(se împarte egal) sau personală.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
      children: [
        for (final e in list)
          Card(
            child: ListTile(
              onTap: () => onEdit(e),
              leading: CircleAvatar(
                backgroundColor: (e.common ? Sea.ocean : Sea.sunset).withValues(
                  alpha: 0.15,
                ),
                child: Icon(
                  e.common ? Icons.groups : Icons.person,
                  color: e.common ? Sea.ocean : Sea.sunset,
                ),
              ),
              title: Text(e.description.isEmpty ? e.category : e.description),
              subtitle: Text(
                '${DateFormat('d MMM').format(e.date)} · plătit de '
                '${store.participant(e.paidBy)?.fullName ?? '?'}\n'
                '${e.common ? 'Comună · împărțită egal la ${e.sharedWith.length}' : 'Personală · ${store.participant(e.sharedWith.firstOrNull ?? e.paidBy)?.fullName ?? '?'}'}',
              ),
              isThreeLine: true,
              trailing: Text(
                lei(e.amount),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
      ],
    );
  }
}

class _PerParticipant extends StatelessWidget {
  const _PerParticipant({required this.season});
  final Season season;

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    final balances = balancesOf(season.expenses, season.participantIds);
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
      children: [
        for (final b in balances.values)
          Card(
            child: ExpansionTile(
              leading: CircleAvatar(
                backgroundColor: (b.balance >= 0 ? Sea.good : Sea.coral)
                    .withValues(alpha: 0.15),
                child: Icon(
                  b.balance >= 0 ? Icons.call_received : Icons.call_made,
                  color: b.balance >= 0 ? Sea.good : Sea.coral,
                ),
              ),
              title: Text(store.participant(b.participantId)?.fullName ?? '?'),
              subtitle: Text(
                b.balance.abs() < 0.005
                    ? 'Achitat'
                    : b.balance > 0
                    ? 'Primește ${lei(b.balance)}'
                    : 'Are de dat ${lei(-b.balance)}',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: b.balance >= 0 ? Sea.good : Sea.coral,
                ),
              ),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              children: [
                _row('A plătit', b.paid),
                _row('Partea lui din cheltuielile comune', b.commonShare),
                _row('Cheltuieli personale', b.personal),
                const Divider(),
                _row('Total de suportat', b.owes, bold: true),
                const SizedBox(height: 8),
                for (final e in season.expenses.where(
                  (e) =>
                      e.paidBy == b.participantId ||
                      e.shares().containsKey(b.participantId),
                ))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Icon(
                          e.paidBy == b.participantId
                              ? Icons.payments_outlined
                              : Icons.receipt_long_outlined,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${e.description.isEmpty ? e.category : e.description}'
                            '${e.paidBy == b.participantId ? ' (a plătit ${lei(e.amount)})' : ''}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        if (e.shares()[b.participantId] case final share?)
                          Text(
                            lei(share),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _row(String label, double v, {bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text(
          lei(v),
          style: TextStyle(fontWeight: bold ? FontWeight.w700 : null),
        ),
      ],
    ),
  );
}

class _Settlement extends StatelessWidget {
  const _Settlement({required this.season});
  final Season season;

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    final transfers = settle(
      balancesOf(season.expenses, season.participantIds),
    );
    if (season.expenses.isEmpty) {
      return const Center(child: Text('Nicio cheltuială de decontat.'));
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
      children: [
        Text(
          transfers.isEmpty
              ? 'Toată lumea e achitată. 👍'
              : 'Ca să fie toată lumea achitată, în mod egal:',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        for (final (i, t) in transfers.indexed)
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Sea.sunset,
                child: Text(
                  '${i + 1}',
                  style: const TextStyle(
                    color: Sea.navy,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: store.participant(t.from)?.fullName ?? '?',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const TextSpan(text: '  îi dă lui  '),
                    TextSpan(
                      text: store.participant(t.to)?.fullName ?? '?',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              trailing: Text(
                lei(t.amount),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: Sea.deep,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// =====================================================================
// Adăugare / editare cheltuială
// =====================================================================

class ExpenseEditScreen extends StatefulWidget {
  const ExpenseEditScreen({super.key, required this.season, this.expense});
  final Season season;
  final Expense? expense;

  @override
  State<ExpenseEditScreen> createState() => _ExpenseEditScreenState();
}

class _ExpenseEditScreenState extends State<ExpenseEditScreen> {
  late final Expense _e =
      widget.expense ??
      Expense(
        id: newId(),
        description: '',
        amount: 0,
        paidBy: widget.season.participantIds.first,
        common: true,
        sharedWith: List.of(widget.season.participantIds),
        date: DateTime.now(),
      );
  late final _desc = TextEditingController(text: _e.description);
  late final _amount = TextEditingController(
    text: _e.amount == 0 ? '' : _e.amount.toStringAsFixed(2),
  );
  late String _paidBy = _e.paidBy;
  late bool _common = _e.common;
  late final Set<String> _shared = {..._e.sharedWith};
  late String _personalFor = _e.common
      ? _e.paidBy
      : (_e.sharedWith.firstOrNull ?? _e.paidBy);
  late String _category = _e.category;
  late DateTime _date = _e.date;
  bool _saveAsPreset = false;

  void _applyPreset(ExpensePreset p) {
    setState(() {
      _desc.text = p.name;
      _category = p.category;
      _common = p.common;
      if (p.amount != null) _amount.text = p.amount!.toStringAsFixed(2);
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final people = [
      for (final id in widget.season.participantIds) ?store.participant(id),
    ];
    final amount = double.tryParse(_amount.text.replaceAll(',', '.')) ?? 0;
    final isNew = widget.expense == null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isNew ? 'Cheltuială nouă' : 'Cheltuială'),
        actions: [
          if (!isNew)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                widget.season.expenses.removeWhere((x) => x.id == _e.id);
                await store.upsertSeason(widget.season);
                if (context.mounted) Navigator.pop(context);
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (isNew) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Presetări',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ExpensePresetsScreen(),
                    ),
                  ),
                  child: const Text('Gestionează'),
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final p in store.expensePresets)
                  ActionChip(
                    avatar: Icon(
                      p.common ? Icons.groups : Icons.person,
                      size: 18,
                    ),
                    label: Text(
                      p.amount == null
                          ? p.name
                          : '${p.name} · ${lei(p.amount!)}',
                    ),
                    onPressed: () => _applyPreset(p),
                  ),
              ],
            ),
            const Divider(height: 24),
          ],
          TextField(
            controller: _desc,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Ce s-a cumpărat'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _amount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Suma',
                    suffixText: 'lei',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: expenseCategories.contains(_category)
                      ? _category
                      : 'Altele',
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Categorie'),
                  items: [
                    for (final c in expenseCategories)
                      DropdownMenuItem(value: c, child: Text(c)),
                  ],
                  onChanged: (v) => setState(() => _category = v!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: people.any((p) => p.id == _paidBy)
                ? _paidBy
                : people.first.id,
            decoration: const InputDecoration(labelText: 'Cine a plătit'),
            items: [
              for (final p in people)
                DropdownMenuItem(value: p.id, child: Text(p.fullName)),
            ],
            onChanged: (v) => setState(() => _paidBy = v!),
          ),
          const SizedBox(height: 16),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: true,
                icon: Icon(Icons.groups),
                label: Text('Comună'),
              ),
              ButtonSegment(
                value: false,
                icon: Icon(Icons.person),
                label: Text('Personală'),
              ),
            ],
            selected: {_common},
            onSelectionChanged: (v) => setState(() => _common = v.first),
          ),
          const SizedBox(height: 12),
          if (_common) ...[
            Text(
              'Se împarte în mod egal la '
              '(${_shared.length}${amount > 0 && _shared.isNotEmpty ? ' × ${lei(amount / _shared.length)}' : ''}):',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            for (final p in people)
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: _shared.contains(p.id),
                title: Text(p.fullName),
                onChanged: (v) => setState(
                  () => v == true ? _shared.add(p.id) : _shared.remove(p.id),
                ),
              ),
          ] else
            DropdownButtonFormField<String>(
              initialValue: people.any((p) => p.id == _personalFor)
                  ? _personalFor
                  : people.first.id,
              decoration: const InputDecoration(
                labelText: 'A cui este cheltuiala',
              ),
              items: [
                for (final p in people)
                  DropdownMenuItem(value: p.id, child: Text(p.fullName)),
              ],
              onChanged: (v) => setState(() => _personalFor = v!),
            ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event),
            title: const Text('Data cheltuielii'),
            subtitle: Text(DateFormat('EEEE, d MMMM yyyy').format(_date)),
            trailing: const Icon(Icons.edit_calendar_outlined),
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(widget.season.year - 1),
                lastDate: DateTime(widget.season.year + 1, 12, 31),
              );
              if (d != null) setState(() => _date = d);
            },
          ),
          if (isNew &&
              _desc.text.trim().isNotEmpty &&
              !store.expensePresets.any(
                (p) => p.name.toLowerCase() == _desc.text.trim().toLowerCase(),
              ))
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _saveAsPreset,
              onChanged: (v) => setState(() => _saveAsPreset = v ?? false),
              title: const Text('Salvează și ca presetare'),
              subtitle: const Text('Data viitoare o alegi cu o atingere'),
            ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: amount <= 0 || (_common && _shared.isEmpty)
                ? null
                : () async {
                    _e
                      ..description = _desc.text.trim()
                      ..amount = amount
                      ..paidBy = _paidBy
                      ..common = _common
                      ..sharedWith = _common
                          ? [
                              for (final p in people)
                                if (_shared.contains(p.id)) p.id,
                            ]
                          : [_personalFor]
                      ..category = _category
                      ..date = _date;
                    if (!widget.season.expenses.any((x) => x.id == _e.id)) {
                      widget.season.expenses.add(_e);
                    }
                    await store.upsertSeason(widget.season);
                    if (_saveAsPreset) {
                      await store.upsertPreset(
                        ExpensePreset(
                          id: newId(),
                          name: _e.description,
                          category: _e.category,
                          common: _e.common,
                        ),
                      );
                    }
                    if (context.mounted) Navigator.pop(context);
                  },
            icon: const Icon(Icons.save),
            label: const Text('Salvează'),
          ),
        ],
      ),
    );
  }
}
