import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/app_store.dart';
import '../models/expense.dart';
import '../models/season.dart';
import '../theme.dart';
import '../widgets/quick_expense_sheet.dart';
import 'expense_presets_screen.dart';

final _lei = NumberFormat.currency(
  locale: 'ro',
  symbol: 'lei',
  decimalDigits: 2,
);
String lei(double v) => _lei.format(v);

final _when = DateFormat('d MMM yyyy, HH:mm');

String _title(Expense e) => e.description.isEmpty ? e.category : e.description;

/// Cheltuielile sezonului: lista numerotată, situația pe participant și
/// decontarea.
class ExpensesScreen extends StatelessWidget {
  const ExpensesScreen({super.key, required this.seasonId});
  final String seasonId;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final season = store.season(seasonId);
    if (season == null) return const Scaffold();
    numberExpenses(season.expenses); // cheltuielile vechi primesc număr
    final total = season.expenses.fold<double>(0, (s, e) => s + e.amount);
    return DefaultTabController(
      length: 4,
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
              tooltip: 'Trimite',
              icon: const Icon(Icons.share),
              onPressed: season.expenses.isEmpty
                  ? null
                  : () => _share(store, season),
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Toate'),
              Tab(text: 'Comune'),
              Tab(text: 'Pe participant'),
              Tab(text: 'Decontare'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => showQuickExpense(context, season),
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
                  _ExpenseList(season: season),
                  _CommonList(season: season),
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

  Future<void> _share(AppStore store, Season season) async {
    String name(String id) => store.participant(id)?.fullName ?? '?';
    final balances = balancesOf(season.expenses, season.participantIds);
    final total = season.expenses.fold<double>(0, (s, e) => s + e.amount);
    final b = StringBuffer(
      'CHELTUIELI — ${season.title} (${season.place.name})\n',
    )..writeln('Total: ${lei(total)}');
    final list = season.expenses.toList()
      ..sort((a, b) => a.number.compareTo(b.number));
    b.writeln();
    for (final e in list) {
      b.writeln(
        '#${e.number} ${_when.format(e.date)} · ${_title(e)} · ${lei(e.amount)}'
        ' · ${name(e.paidBy)} · ${e.common ? 'comună' : 'proprie'}',
      );
    }
    b.writeln('\nPE PARTICIPANT:');
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

void openExpenseEditor(
  BuildContext context,
  Season season, {
  Expense? expense,
  ExpensePreset? preset,
}) {
  if (season.participantIds.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bifează întâi participanții sezonului.')),
    );
    return;
  }
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) =>
          ExpenseEditScreen(season: season, expense: expense, preset: preset),
    ),
  );
}

// =====================================================================
// Lista numerotată, cu filtru pe presetare / bun
// =====================================================================

class _ExpenseList extends StatefulWidget {
  const _ExpenseList({required this.season});
  final Season season;

  @override
  State<_ExpenseList> createState() => _ExpenseListState();
}

class _ExpenseListState extends State<_ExpenseList> {
  /// Filtru: titlul cheltuielii (ex. „Benzină barcă”), null = toate.
  String? _filter;

  /// null = toate, true = comune, false = proprii.
  bool? _common;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final season = widget.season;
    if (season.expenses.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Nicio cheltuială încă.\n'
            'Adaugă ce s-a plătit: cine a plătit și dacă intră la comun '
            '(se împarte egal) sau e proprie.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    // grupuri pe bun (ex. 3 × Benzină barcă)
    final groups = <String, List<Expense>>{};
    for (final e in season.expenses) {
      groups.putIfAbsent(_title(e), () => []).add(e);
    }
    final groupNames = groups.keys.toList()
      ..sort((a, b) => groups[b]!.length.compareTo(groups[a]!.length));
    if (_filter != null && !groups.containsKey(_filter)) _filter = null;
    final list =
        (_filter == null ? season.expenses : groups[_filter]!)
            .where((e) => _common == null || e.common == _common)
            .toList()
          ..sort((a, b) => b.number.compareTo(a.number));
    double sum(bool common) => season.expenses
        .where((e) => e.common == common)
        .fold(0, (s, e) => s + e.amount);
    final preset = _filter == null
        ? null
        : store.expensePresets
              .where((p) => p.name.toLowerCase() == _filter!.toLowerCase())
              .firstOrNull;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: SegmentedButton<bool?>(
            showSelectedIcon: false,
            segments: [
              const ButtonSegment(value: null, label: Text('Toate')),
              ButtonSegment(
                value: true,
                icon: const Icon(Icons.groups),
                label: Text('Comune ${lei(sum(true))}'),
              ),
              ButtonSegment(
                value: false,
                icon: const Icon(Icons.person),
                label: Text('Proprii ${lei(sum(false))}'),
              ),
            ],
            selected: {_common},
            onSelectionChanged: (v) => setState(() => _common = v.first),
          ),
        ),
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: [
              ChoiceChip(
                label: Text('Toate (${season.expenses.length})'),
                selected: _filter == null,
                onSelected: (_) => setState(() => _filter = null),
              ),
              for (final g in groupNames)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: ChoiceChip(
                    label: Text('$g (${groups[g]!.length})'),
                    selected: _filter == g,
                    onSelected: (_) => setState(() => _filter = g),
                  ),
                ),
            ],
          ),
        ),
        if (_filter != null)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
            decoration: BoxDecoration(
              color: Sea.ocean.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '$_filter: ${list.length} × · total '
                    '${lei(list.fold<double>(0, (s, e) => s + e.amount))}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Încă una'),
                  onPressed: () => showQuickExpense(
                    context,
                    season,
                    preset:
                        preset ??
                        ExpensePreset(
                          id: '',
                          name: _filter!,
                          category: list.first.category,
                          common: list.first.common,
                        ),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
            children: [
              for (final e in list) _ExpenseTile(season: season, expense: e),
            ],
          ),
        ),
      ],
    );
  }
}

class _ExpenseTile extends StatelessWidget {
  const _ExpenseTile({
    required this.season,
    required this.expense,
    this.ownNumber,
  });
  final Season season;
  final Expense expense;

  /// Numărul curent în lista participantului (în tab-ul „Pe participant”).
  final int? ownNumber;

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    final e = expense;
    final color = e.common ? Sea.ocean : Sea.sunset;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => openExpenseEditor(context, season, expense: e),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
          child: Row(
            children: [
              Container(
                width: 46,
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Text(
                      ownNumber != null ? '$ownNumber.' : '#${e.number}',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: color,
                        fontSize: 15,
                      ),
                    ),
                    if (ownNumber != null)
                      Text(
                        '#${e.number}',
                        style: TextStyle(fontSize: 10, color: color),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _title(e),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      _when.format(e.date),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      '${ownNumber == null ? 'Achitată de ${store.participant(e.paidBy)?.fullName ?? '?'} · ' : ''}'
                      '${e.common ? 'comună, împărțită egal la ${e.sharedWith.length}' : 'cheltuială proprie'}',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: color),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    lei(e.amount),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  CommonToggle(season: season, expense: e),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// Comune: separat, cu participantul care le-a făcut
// =====================================================================

class _CommonList extends StatelessWidget {
  const _CommonList({required this.season});
  final Season season;

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    final text = Theme.of(context).textTheme;
    final list = season.expenses.where((e) => e.common).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    if (list.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Nicio cheltuială comună.\n'
            'Bifează „Intră la comun” la o cheltuială ca să apară aici.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final total = list.fold<double>(0, (s, e) => s + e.amount);
    final people = season.participantIds.length;
    final byPayer = <String, List<Expense>>{};
    for (final e in list) {
      byPayer.putIfAbsent(e.paidBy, () => []).add(e);
    }
    double sum(List<Expense> l) => l.fold<double>(0, (s, e) => s + e.amount);
    final ids = {...season.participantIds, ...byPayer.keys}.toList();
    final balances = balancesOf(list, ids);
    final transfers = settle(balances);

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
      children: [
        Card(
          color: Sea.ocean.withValues(alpha: 0.08),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.groups, color: Sea.ocean),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Cheltuieli comune: ${list.length}',
                        style: text.titleMedium,
                      ),
                    ),
                    Text(
                      lei(total),
                      style: text.titleMedium?.copyWith(
                        color: Sea.ocean,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                if (people > 0)
                  Text(
                    'Revin aprox. ${lei(total / people)} de persoană '
                    '(la $people participanți)',
                    style: text.bodySmall,
                  ),
                const Divider(height: 20),
                Text(
                  'Cota fiecăruia (împărțire egală):',
                  style: text.labelLarge,
                ),
                const SizedBox(height: 4),
                for (final id in ids)
                  _ShareRow(
                    name: store.participant(id)?.fullName ?? '?',
                    paid: sum(byPayer[id] ?? const []),
                    percent: total == 0
                        ? 0
                        : sum(byPayer[id] ?? const []) / total * 100,
                    share: balances[id]?.commonShare ?? 0,
                    owes: [
                      for (final t in transfers.where((t) => t.from == id))
                        (store.participant(t.to)?.fullName ?? '?', t.amount),
                    ],
                    receives: [
                      for (final t in transfers.where((t) => t.to == id))
                        (store.participant(t.from)?.fullName ?? '?', t.amount),
                    ],
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        for (final (i, e) in list.indexed)
          Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => openExpenseEditor(context, season, expense: e),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
                child: Row(
                  children: [
                    SizedBox(
                      width: 40,
                      child: Column(
                        children: [
                          Text(
                            '${i + 1}.',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: Sea.ocean,
                            ),
                          ),
                          Text(
                            '#${e.number}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Sea.ocean,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _title(e),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(_when.format(e.date), style: text.bodySmall),
                          const SizedBox(height: 4),
                          _PayerChip(
                            name: store.participant(e.paidBy)?.fullName ?? '?',
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          lei(e.amount),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          '${lei(e.amount / (e.sharedWith.isEmpty ? 1 : e.sharedWith.length))}'
                          ' / pers.',
                          style: text.bodySmall,
                        ),
                        CommonToggle(season: season, expense: e),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Un participant în tabelul cotelor: cât a achitat la comun, cota lui
/// egală și cui are de dat / de la cine primește.
class _ShareRow extends StatelessWidget {
  const _ShareRow({
    required this.name,
    required this.paid,
    required this.percent,
    required this.share,
    required this.owes,
    required this.receives,
  });
  final String name;
  final double paid;
  final double percent;
  final double share;
  final List<(String, double)> owes;
  final List<(String, double)> receives;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _PayerChip(name: name),
              const Spacer(),
              Text(
                'a achitat ${lei(paid)} (${percent.toStringAsFixed(0)}%)',
                style: text.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('Cota lui: ${lei(share)}', style: text.bodyMedium),
          for (final (to, amount) in owes)
            Text(
              'Are de achitat lui $to: ${lei(amount)}',
              style: const TextStyle(
                color: Sea.coral,
                fontWeight: FontWeight.w700,
              ),
            ),
          for (final (from, amount) in receives)
            Text(
              'Primește de la $from: ${lei(amount)}',
              style: const TextStyle(
                color: Sea.good,
                fontWeight: FontWeight.w700,
              ),
            ),
          if (owes.isEmpty && receives.isEmpty)
            Text('Achitat', style: text.bodySmall?.copyWith(color: Sea.good)),
        ],
      ),
    );
  }
}

/// Numele participantului care a făcut cheltuiala, evidențiat.
class _PayerChip extends StatelessWidget {
  const _PayerChip({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Sea.deep,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.person, size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
// Pe participant: cheltuielile achitate de fiecare, numerotate
// =====================================================================

class _PerParticipant extends StatelessWidget {
  const _PerParticipant({required this.season});
  final Season season;

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    final balances = balancesOf(season.expenses, season.participantIds);
    final text = Theme.of(context).textTheme;
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
              childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              children: [
                _row('A achitat (total)', b.paid),
                _row('Partea lui din cheltuielile comune', b.commonShare),
                _row('Cheltuieli proprii', b.personal),
                const Divider(),
                _row('Total de suportat', b.owes, bold: true),
                ..._paidBy(context, b.participantId, text),
                ..._sharesFromOthers(context, store, b.participantId, text),
              ],
            ),
          ),
      ],
    );
  }

  List<Widget> _paidBy(BuildContext context, String id, TextTheme text) {
    final own = season.expenses.where((e) => e.paidBy == id).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    List<Widget> section(String title, Color color, List<Expense> list) {
      if (list.isEmpty) return const [];
      return [
        const SizedBox(height: 12),
        Row(
          children: [
            Container(width: 4, height: 18, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text('$title (${list.length})', style: text.titleSmall),
            ),
            Text(
              lei(list.fold(0, (s, e) => s + e.amount)),
              style: text.titleSmall?.copyWith(color: color),
            ),
          ],
        ),
        const SizedBox(height: 4),
        for (final (i, e) in list.indexed)
          _ExpenseTile(season: season, expense: e, ownNumber: i + 1),
      ];
    }

    return [
      ...section(
        'Cheltuieli comune achitate de el',
        Sea.ocean,
        own.where((e) => e.common).toList(),
      ),
      ...section(
        'Cheltuieli proprii',
        Sea.sunset,
        own.where((e) => !e.common).toList(),
      ),
    ];
  }

  List<Widget> _sharesFromOthers(
    BuildContext context,
    AppStore store,
    String id,
    TextTheme text,
  ) {
    final others =
        season.expenses
            .where(
              (e) => e.common && e.paidBy != id && e.sharedWith.contains(id),
            )
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));
    if (others.isEmpty) return const [];
    return [
      const SizedBox(height: 12),
      Text(
        'Partea lui din ce au achitat alții la comun',
        style: text.titleSmall,
      ),
      for (final e in others)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              SizedBox(
                width: 40,
                child: Text('#${e.number}', style: text.bodySmall),
              ),
              Expanded(
                child: Text(
                  '${_title(e)} · ${_when.format(e.date)} · '
                  '${store.participant(e.paidBy)?.fullName ?? '?'}',
                  style: text.bodySmall,
                ),
              ),
              Text(lei(e.shares()[id] ?? 0), style: text.bodySmall),
            ],
          ),
        ),
    ];
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

// =====================================================================
// Decontare
// =====================================================================

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
// Adăugare / modificare cheltuială
// =====================================================================

class ExpenseEditScreen extends StatefulWidget {
  const ExpenseEditScreen({
    super.key,
    required this.season,
    this.expense,
    this.preset,
  });
  final Season season;
  final Expense? expense;

  /// Presetarea aplicată de la început (ex. „Încă una” pe Benzină barcă).
  final ExpensePreset? preset;

  @override
  State<ExpenseEditScreen> createState() => _ExpenseEditScreenState();
}

class _ExpenseEditScreenState extends State<ExpenseEditScreen> {
  late Expense _e;
  late final TextEditingController _desc;
  late final TextEditingController _amount;
  late String _paidBy;
  late bool _common;
  late final Set<String> _shared;
  late String _category;
  late DateTime _date;
  String? _presetId;
  bool _saveAsPreset = false;

  bool get _isNew => widget.expense == null;

  @override
  void initState() {
    super.initState();
    _e =
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
    _desc = TextEditingController(text: _e.description);
    _amount = TextEditingController(
      text: _e.amount == 0 ? '' : _e.amount.toStringAsFixed(2),
    );
    _paidBy = _e.paidBy;
    _common = _e.common;
    _shared = {..._e.sharedWith};
    _category = _e.category;
    _date = _e.date;
    _presetId = _e.presetId;
    if (widget.preset != null) _applyPreset(widget.preset!, rebuild: false);
  }

  void _applyPreset(ExpensePreset p, {bool rebuild = true}) {
    void apply() {
      _presetId = p.id.isEmpty ? null : p.id;
      _desc.text = p.name;
      _category = p.category;
      _common = p.common;
      if (_common && _shared.isEmpty) {
        _shared.addAll(widget.season.participantIds);
      }
      if (p.amount != null) _amount.text = p.amount!.toStringAsFixed(2);
    }

    rebuild ? setState(apply) : apply();
  }

  Future<void> _pickDateTime() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(widget.season.year - 1),
      lastDate: DateTime(widget.season.year + 1, 12, 31),
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_date),
    );
    setState(() {
      _date = DateTime(
        d.year,
        d.month,
        d.day,
        t?.hour ?? _date.hour,
        t?.minute ?? _date.minute,
      );
    });
  }

  /// Salvează; cu [another] rămâne în formular pentru încă o cheltuială pe
  /// același bun (aceeași presetare, același plătitor, aceeași bifă).
  Future<void> _save(
    List<String> people,
    double amount, {
    bool another = false,
  }) async {
    final store = context.read<AppStore>();
    final messenger = ScaffoldMessenger.of(context);
    final season = widget.season;
    _e
      ..description = _desc.text.trim()
      ..amount = amount
      ..paidBy = _paidBy
      ..common = _common
      ..sharedWith = _common
          ? [
              for (final p in people)
                if (_shared.contains(p)) p,
            ]
          : [_paidBy]
      ..category = _category
      ..presetId = _presetId
      ..date = _date;
    if (!season.expenses.any((x) => x.id == _e.id)) {
      _e.number = numberExpenses(season.expenses);
      season.expenses.add(_e);
    }
    await store.upsertSeason(season);
    if (_saveAsPreset) {
      final preset = ExpensePreset(
        id: newId(),
        name: _e.description,
        category: _e.category,
        common: _e.common,
      );
      await store.upsertPreset(preset);
      _presetId = preset.id;
      _saveAsPreset = false;
    }
    if (!mounted) return;
    if (!another) {
      Navigator.pop(context);
      return;
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Salvată #${_e.number} · ${_title(_e)} · ${lei(_e.amount)}',
        ),
      ),
    );
    setState(() {
      _e = Expense(
        id: newId(),
        description: _e.description,
        amount: 0,
        paidBy: _paidBy,
        common: _common,
        sharedWith: List.of(_e.sharedWith),
        date: DateTime.now(),
        category: _category,
        presetId: _presetId,
      );
      _amount.clear();
      _date = DateTime.now();
    });
  }

  Future<void> _delete() async {
    final store = context.read<AppStore>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Ștergi cheltuiala #${_e.number}?'),
        content: Text(
          '${_title(_e)} · ${lei(_e.amount)} · ${_when.format(_e.date)}',
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
    if (ok != true) return;
    widget.season.expenses.removeWhere((x) => x.id == _e.id);
    await store.upsertSeason(widget.season);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final people = [
      for (final id in widget.season.participantIds) ?store.participant(id),
    ];
    final ids = people.map((p) => p.id).toList();
    final amount = double.tryParse(_amount.text.replaceAll(',', '.')) ?? 0;
    final canSave = amount > 0 && (!_common || _shared.isNotEmpty);
    final payerName =
        people.where((p) => p.id == _paidBy).firstOrNull?.fullName ?? '?';
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'Cheltuială nouă' : 'Cheltuiala #${_e.number}'),
        actions: [
          if (!_isNew)
            IconButton(
              tooltip: 'Șterge',
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_isNew) ...[
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
                  ChoiceChip(
                    avatar: Icon(
                      p.common ? Icons.groups : Icons.person,
                      size: 18,
                    ),
                    label: Text(
                      p.amount == null
                          ? p.name
                          : '${p.name} · ${lei(p.amount!)}',
                    ),
                    selected: _presetId == p.id,
                    onSelected: (_) => _applyPreset(p),
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
                  autofocus: widget.preset != null,
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
                  key: ValueKey(_category),
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
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.schedule),
            title: const Text('Data și ora efectuării'),
            subtitle: Text(
              toBeginningOfSentenceCase(
                DateFormat('EEEE, d MMMM yyyy, HH:mm').format(_date),
              ),
            ),
            trailing: const Icon(Icons.edit_calendar_outlined),
            onTap: _pickDateTime,
          ),
          DropdownButtonFormField<String>(
            initialValue: ids.contains(_paidBy) ? _paidBy : ids.first,
            decoration: const InputDecoration(
              labelText: 'Achitată de (în sarcina lui)',
            ),
            items: [
              for (final p in people)
                DropdownMenuItem(value: p.id, child: Text(p.fullName)),
            ],
            onChanged: (v) => setState(() => _paidBy = v!),
          ),
          const SizedBox(height: 12),
          Card(
            color: (_common ? Sea.ocean : Sea.sunset).withValues(alpha: 0.10),
            child: CheckboxListTile(
              value: _common,
              onChanged: (v) => setState(() {
                _common = v ?? false;
                if (_common && _shared.isEmpty) _shared.addAll(ids);
              }),
              title: const Text('Intră la comun'),
              subtitle: Text(
                _common
                    ? 'Se împarte în mod egal între participanții bifați mai jos'
                    : 'Cheltuială proprie a lui $payerName',
              ),
            ),
          ),
          if (_common) ...[
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Împărțită egal la ${_shared.length}'
                '${amount > 0 && _shared.isNotEmpty ? ' × ${lei(amount / _shared.length)}' : ''}:',
                style: Theme.of(context).textTheme.titleSmall,
              ),
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
          ],
          if (_isNew &&
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
            onPressed: canSave ? () => _save(ids, amount) : null,
            icon: const Icon(Icons.save),
            label: Text(_isNew ? 'Salvează' : 'Salvează modificările'),
          ),
          if (_isNew) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: canSave
                  ? () => _save(ids, amount, another: true)
                  : null,
              icon: const Icon(Icons.playlist_add),
              label: Text(
                _desc.text.trim().isEmpty
                    ? 'Salvează și adaugă încă una'
                    : 'Salvează și încă una „${_desc.text.trim()}”',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Bifa „comun” de pe o cheltuială: bifată = se împarte egal între toți
/// participanții sezonului; debifată = cheltuială proprie a celui care a plătit.
class CommonToggle extends StatelessWidget {
  const CommonToggle({super.key, required this.season, required this.expense});
  final Season season;
  final Expense expense;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _toggle(context),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: Checkbox(
              value: expense.common,
              visualDensity: VisualDensity.compact,
              onChanged: (_) => _toggle(context),
            ),
          ),
          Text(
            'comun',
            style: TextStyle(
              fontSize: 12,
              color: expense.common
                  ? Sea.ocean
                  : Theme.of(context).colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  void _toggle(BuildContext context) {
    final store = context.read<AppStore>();
    expense.common = !expense.common;
    expense.sharedWith = expense.common
        ? List.of(season.participantIds)
        : [expense.paidBy];
    store.upsertSeason(season);
  }
}
