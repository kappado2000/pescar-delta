import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/expense.dart';
import '../models/season.dart';
import '../screens/expense_presets_screen.dart';
import '../screens/expenses_screen.dart';
import '../theme.dart';

/// Iconițele din care se poate alege pentru un card.
const expenseIconChoices = <String, IconData>{
  'benzina': Icons.local_gas_station,
  'masina': Icons.directions_car,
  'barca': Icons.directions_boat,
  'mancare': Icons.restaurant,
  'paine': Icons.bakery_dining,
  'gratar': Icons.outdoor_grill,
  'cumparaturi': Icons.shopping_cart,
  'bautura': Icons.local_drink,
  'bere': Icons.sports_bar,
  'vin': Icons.wine_bar,
  'cafea': Icons.local_cafe,
  'gheata': Icons.ac_unit,
  'momeli': Icons.phishing,
  'echipament': Icons.construction,
  'undite': Icons.phishing,
  'mulinete': Icons.album,
  'umbrela': Icons.beach_access,
  'scaun': Icons.chair_alt,
  'cazare': Icons.hotel,
  'cort': Icons.holiday_village,
  'permis': Icons.badge,
  'medicamente': Icons.medical_services,
  'baterii': Icons.battery_charging_full,
  'ulei': Icons.oil_barrel,
  'taxe': Icons.receipt_long,
  'bani': Icons.payments,
  'cadou': Icons.card_giftcard,
  'peste': Icons.set_meal,
  'restaurant': Icons.restaurant_menu,
  'pizza': Icons.local_pizza,
  'carne': Icons.kebab_dining,
  'dulciuri': Icons.icecream,
  'taxa_pod': Icons.toll,
  'bac': Icons.directions_ferry,
  'parcare': Icons.local_parking,
  'autostrada': Icons.add_road,
  'taxi': Icons.local_taxi,
  'autobuz': Icons.directions_bus,
  'tren': Icons.train,
  'inchiriere_barca': Icons.sailing,
  'camping': Icons.cabin,
  'foc': Icons.local_fire_department,
  'butelie': Icons.propane_tank,
  'generator': Icons.power,
  'farmacie': Icons.local_pharmacy,
  'apa': Icons.water_drop,
  'igiena': Icons.soap,
  'telefon': Icons.phone_android,
  'ghid': Icons.explore,
  'magazin': Icons.store,
  'altele': Icons.more_horiz,
};

/// Iconița unui card: cea aleasă, altfel automată după nume / categorie.
IconData presetIcon(ExpensePreset p) =>
    expenseIconChoices[p.icon] ?? expenseIcon(p.category, p.name);

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
  final tokens = n.split(RegExp(r'[^a-z0-9]+')).toSet();
  bool word(List<String> words) => words.any(tokens.contains);
  if (has(['gheata', 'ghiata'])) return Icons.ac_unit;
  if (word(['pod', 'poduri'])) return Icons.toll;
  if (word(['bac', 'bacul']) || has(['feribot'])) return Icons.directions_ferry;
  if (has(['parcare'])) return Icons.local_parking;
  if (has(['autostrada', 'rovinieta', 'vigneta'])) return Icons.add_road;
  if (has(['taxi'])) return Icons.local_taxi;
  if (has(['autobuz', 'microbuz', 'transfer'])) return Icons.directions_bus;
  if (has(['tren'])) return Icons.train;
  if (has(['inchiriere', 'inchiriat'])) return Icons.sailing;
  if (has(['restaurant', 'bistro', 'terasa'])) {
    return Icons.restaurant_menu;
  }
  if (has(['peste', 'saramura', 'ciorba'])) return Icons.set_meal;
  if (has(['pizza'])) return Icons.local_pizza;
  if (has(['farmac', 'medicament'])) return Icons.local_pharmacy;
  if (has(['lemne', 'carbuni', 'mangal']) || word(['foc'])) {
    return Icons.local_fire_department;
  }
  if (has(['butelie']) || word(['gaz'])) return Icons.propane_tank;
  if (has(['generator', 'curent'])) return Icons.power;
  if (has(['camping'])) return Icons.cabin;
  if (has(['ghid'])) return Icons.explore;
  if (has(['sapun', 'igiena', 'hartie', 'servetele'])) return Icons.soap;
  if (has(['telefon', 'internet', 'cartela'])) return Icons.phone_android;
  if (has(['magazin', 'market'])) return Icons.store;
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
  if (has(['undit', 'lanset', 'varga', 'vergi'])) return Icons.phishing;
  if (has(['mulinet'])) return Icons.album;
  if (has(['umbrel', 'parasolar', 'brolly'])) return Icons.beach_access;
  if (has(['scaun', 'fotoliu', 'sezut'])) return Icons.chair_alt;
  if (has(['carlig', 'fir', 'plumb', 'naluc'])) {
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
    useRootNavigator: true,
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

  @override
  void initState() {
    super.initState();
    final store = context.read<AppStore>();
    _payer = store.payerFor(widget.season);
    if (widget.initialPreset != null) _choose(widget.initialPreset!);
  }

  void _choose(ExpensePreset p) {
    setState(() {
      _preset = p;
      _common = p.common;
      _amount = '';
    });
  }

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

  Future<void> _save() async {
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
        content: Text('✓ ${p.name} · ${lei(e.amount)}'),
        duration: const Duration(seconds: 2),
      ),
    );
    if (!mounted) return;
    // înapoi la carduri: soldul cardului arată deja și cheltuiala asta
    setState(() {
      _preset = null;
      _amount = '';
    });
  }

  bool _belongs(Expense e, ExpensePreset p) {
    final presets = context.read<AppStore>().expensePresets;
    // card temporar (fără id, ex. „Încă una” din filtru): după nume
    if (p.id.isEmpty) {
      return e.description.trim().toLowerCase() == p.name.trim().toLowerCase();
    }
    return cardOf(e, presets)?.id == p.id;
  }

  /// Totalul cheltuit în sezon pe un bun (după presetare sau după nume).
  (double, int) _totalFor(ExpensePreset p) {
    final list = widget.season.expenses.where((e) => _belongs(e, p));
    return (list.fold(0.0, (s, e) => s + e.amount), list.length);
  }

  /// Ce nu ține de niciun card („Altele”).
  (double, int) _totalOthers(List<ExpensePreset> presets) {
    final list = widget.season.expenses.where(
      (e) => !presets.any((p) => _belongs(e, p)),
    );
    return (list.fold(0.0, (s, e) => s + e.amount), list.length);
  }

  /// Suma de sub titlul cardului; nimic cât timp nu s-a cheltuit pe el.
  String? _sub((double, int) t) => switch (t) {
    (_, 0) => null,
    (final sum, final n) => '${lei(sum)} · $n×',
  };

  bool _editing = false;

  Future<void> _deletePreset(ExpensePreset p) async {
    final store = context.read<AppStore>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Ștergi cardul „${p.name}”?'),
        content: const Text(
          'Cheltuielile deja făcute rămân și trec la soldul cardului „Altele”.',
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
    if (ok == true) await store.deletePreset(p.id);
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
          Row(
            children: [
              Expanded(
                child: Text(
                  _editing ? 'Editează cardurile' : 'Ce s-a cumpărat?',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              _editing
                  ? FilledButton(
                      onPressed: () => setState(() => _editing = false),
                      child: const Text('Gata'),
                    )
                  : TextButton.icon(
                      onPressed: () => setState(() => _editing = true),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Editează'),
                    ),
            ],
          ),
          if (_editing)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '✎ modifică · ✕ șterge · ține apăsat pe un card și trage-l '
                'peste altul ca să schimbi ordinea',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          const SizedBox(height: 12),
          Expanded(
            child: GridView.count(
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.95,
              children: [
                for (final (i, p) in presets.indexed)
                  _editing
                      ? _EditableTile(
                          key: ValueKey(p.id),
                          index: i,
                          onMove: (from) => store.movePreset(from, i),
                          onEdit: () => editPreset(context, p),
                          onDelete: () => _deletePreset(p),
                          child: _BigTile(
                            icon: presetIcon(p),
                            label: p.name,
                            sub: _sub(_totalFor(p)),
                            color: p.common ? Sea.ocean : Sea.sunset,
                            onTap: () => editPreset(context, p),
                          ),
                        )
                      : _BigTile(
                          icon: presetIcon(p),
                          label: p.name,
                          sub: _sub(_totalFor(p)),
                          color: p.common ? Sea.ocean : Sea.sunset,
                          onTap: () => _choose(p),
                        ),
                _BigTile(
                  icon: Icons.more_horiz,
                  label: 'Altele',
                  sub: _sub(_totalOthers(presets)),
                  color: Colors.blueGrey,
                  onTap: () {
                    Navigator.pop(context);
                    openExpenseEditor(context, widget.season);
                  },
                ),
                _BigTile(
                  icon: Icons.add,
                  label: 'Card nou',
                  color: Sea.teal,
                  onTap: () => editPreset(context, null),
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
              Icon(presetIcon(p), color: color, size: 28),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  p.name,
                  style: Theme.of(context).textTheme.titleLarge,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
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
                color: _amount.isEmpty ? Colors.grey : readable(context, color),
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
          FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              textStyle: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            onPressed: canSave ? _save : null,
            icon: const Icon(Icons.check),
            label: const Text('Salvează'),
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
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: [
            Expanded(
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
                  ],
                ),
              ),
            ),
            // suma cheltuită: banner jos, în culoarea iconiței, cu text alb
            if (sub != null)
              Container(
                width: double.infinity,
                color: color,
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  sub!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    // pe portocaliu albul nu se vede: maro
                    color: color == Sea.sunset ? kNumberBrown : Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Card în mod editare: butoane ✎ / ✕ și mutare prin ținere apăsat + tragere.
class _EditableTile extends StatelessWidget {
  const _EditableTile({
    super.key,
    required this.index,
    required this.onMove,
    required this.onEdit,
    required this.onDelete,
    required this.child,
  });
  final int index;
  final void Function(int from) onMove;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Widget child;

  Widget _badge(IconData icon, Color color, VoidCallback onTap) => Material(
    color: color,
    shape: const CircleBorder(),
    elevation: 2,
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: Icon(icon, size: 16, color: Colors.white),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final tile = Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(child: child),
        Positioned(
          top: -6,
          left: -6,
          child: _badge(Icons.edit, Sea.ocean, onEdit),
        ),
        Positioned(
          top: -6,
          right: -6,
          child: _badge(Icons.close, Sea.coral, onDelete),
        ),
      ],
    );
    return DragTarget<int>(
      onWillAcceptWithDetails: (d) => d.data != index,
      onAcceptWithDetails: (d) => onMove(d.data),
      builder: (context, candidate, _) => LongPressDraggable<int>(
        data: index,
        feedback: SizedBox(
          width: 110,
          height: 115,
          child: Opacity(
            opacity: 0.85,
            child: Material(color: Colors.transparent, child: child),
          ),
        ),
        childWhenDragging: Opacity(opacity: 0.3, child: child),
        child: AnimatedScale(
          scale: candidate.isNotEmpty ? 1.08 : 1.0,
          duration: const Duration(milliseconds: 120),
          child: tile,
        ),
      ),
    );
  }
}
