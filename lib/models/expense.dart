/// Categoriile de cheltuieli, pentru totaluri.
const expenseCategories = [
  'Mâncare-Băutură',
  'Combustibil',
  'Momeli',
  'Cazare',
  'Transport',
  'Permise',
  'Echipament',
  'Altele',
];

/// Un bun pentru care se fac des cheltuieli (ex. „Benzină barcă”):
/// completează rapid descrierea, categoria, tipul și suma obișnuită.
class ExpensePreset {
  ExpensePreset({
    required this.id,
    required this.name,
    this.category = 'Altele',
    this.common = true,
    this.amount,
    this.icon,
  });

  final String id;
  String name;
  String category;
  bool common;

  /// Suma obișnuită (opțional).
  double? amount;

  /// Iconița aleasă de user (cheie din lista de iconițe); null = automată.
  String? icon;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'category': category,
    'common': common,
    'amount': amount,
    'icon': icon,
  };

  factory ExpensePreset.fromJson(Map<String, dynamic> j) => ExpensePreset(
    id: j['id'],
    name: j['name'] ?? '',
    category: j['category'] ?? 'Altele',
    common: j['common'] ?? true,
    amount: (j['amount'] as num?)?.toDouble(),
    icon: j['icon'],
  );
}

/// O cheltuială de sezon, plătită de un participant.
///
/// - comună: se împarte egal între [sharedWith];
/// - personală: e doar a lui [sharedWith].first (poate fi altul decât plătitorul).
class Expense {
  Expense({
    required this.id,
    required this.description,
    required this.amount,
    required this.paidBy,
    required this.common,
    required this.sharedWith,
    required this.date,
    this.category = 'Altele',
    this.number = 0,
    this.presetId,
  });

  final String id;

  /// Numărul curent în sezon (#1, #2…), dat la înregistrare.
  int number;

  /// Presetarea din care a fost creată (ex. „Benzină barcă”), dacă e cazul.
  String? presetId;
  String description;

  /// Suma în lei.
  double amount;
  String paidBy;
  bool common;
  List<String> sharedWith;
  DateTime date;
  String category;

  /// Cât din cheltuială îi revine fiecărui participant.
  Map<String, double> shares() {
    final people = sharedWith.isEmpty ? [paidBy] : sharedWith;
    if (!common) return {people.first: amount};
    final each = amount / people.length;
    return {for (final p in people) p: each};
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'description': description,
    'amount': amount,
    'paidBy': paidBy,
    'common': common,
    'sharedWith': sharedWith,
    'date': date.toIso8601String(),
    'category': category,
    'number': number,
    'presetId': presetId,
  };

  factory Expense.fromJson(Map<String, dynamic> j) => Expense(
    id: j['id'],
    description: j['description'] ?? '',
    amount: (j['amount'] as num).toDouble(),
    paidBy: j['paidBy'],
    common: j['common'] ?? true,
    sharedWith: List<String>.from(j['sharedWith'] ?? []),
    date: DateTime.parse(j['date']),
    category: j['category'] ?? 'Altele',
    number: j['number'] ?? 0,
    presetId: j['presetId'],
  );
}

/// Dă numere curente cheltuielilor care nu au (în ordinea datei) și
/// întoarce următorul număr liber.
int numberExpenses(List<Expense> expenses) {
  var next = expenses.fold<int>(0, (m, e) => e.number > m ? e.number : m) + 1;
  final missing = expenses.where((e) => e.number == 0).toList()
    ..sort((a, b) => a.date.compareTo(b.date));
  for (final e in missing) {
    e.number = next++;
  }
  return next;
}

/// Situația unui participant în sezon.
class ExpenseBalance {
  ExpenseBalance(this.participantId);
  final String participantId;
  double paid = 0;
  double commonShare = 0;
  double personal = 0;

  double get owes => commonShare + personal;

  /// Pozitiv = primește bani; negativ = are de dat.
  double get balance => paid - owes;
}

/// Un transfer de decontare: [from] îi dă lui [to] suma [amount].
class Transfer {
  Transfer(this.from, this.to, this.amount);
  final String from;
  final String to;
  final double amount;
}

Map<String, ExpenseBalance> balancesOf(
  Iterable<Expense> expenses,
  Iterable<String> participantIds,
) {
  final map = {for (final id in participantIds) id: ExpenseBalance(id)};
  for (final e in expenses) {
    map.putIfAbsent(e.paidBy, () => ExpenseBalance(e.paidBy)).paid += e.amount;
    for (final s in e.shares().entries) {
      final b = map.putIfAbsent(s.key, () => ExpenseBalance(s.key));
      e.common ? b.commonShare += s.value : b.personal += s.value;
    }
  }
  return map;
}

/// Decontarea cu cât mai puține transferuri: cel care are cel mai mult de
/// dat plătește celui care are cel mai mult de primit, și tot așa.
List<Transfer> settle(Map<String, ExpenseBalance> balances) {
  final debtors = [
    for (final b in balances.values)
      if (b.balance < -0.005) [b.participantId, -b.balance],
  ];
  final creditors = [
    for (final b in balances.values)
      if (b.balance > 0.005) [b.participantId, b.balance],
  ];
  int byAmount(List a, List b) => (b[1] as double).compareTo(a[1] as double);
  debtors.sort(byAmount);
  creditors.sort(byAmount);
  final result = <Transfer>[];
  var i = 0, j = 0;
  while (i < debtors.length && j < creditors.length) {
    final d = debtors[i], c = creditors[j];
    final amount = (d[1] as double) < (c[1] as double)
        ? d[1] as double
        : c[1] as double;
    result.add(Transfer(d[0] as String, c[0] as String, amount));
    d[1] = (d[1] as double) - amount;
    c[1] = (c[1] as double) - amount;
    if ((d[1] as double) < 0.005) i++;
    if ((c[1] as double) < 0.005) j++;
  }
  return result;
}

/// Cardul de cheltuială rapidă de care ține [e] (null = „Altele”): întâi
/// presetarea aleasă (dacă n-a fost schimbată categoria), apoi numele
/// cardului, apoi primul card din aceeași categorie.
ExpensePreset? cardOf(Expense e, List<ExpensePreset> presets) {
  for (final p in presets) {
    if (p.id.isNotEmpty && e.presetId == p.id && e.category == p.category) {
      return p;
    }
  }
  final name = e.description.trim().toLowerCase();
  for (final p in presets) {
    if (name.isNotEmpty && name == p.name.trim().toLowerCase()) return p;
  }
  if (e.category == 'Altele') return null;
  for (final p in presets) {
    if (p.category == e.category) return p;
  }
  return null;
}
