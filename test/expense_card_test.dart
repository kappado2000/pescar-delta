import 'package:flutter_test/flutter_test.dart';
import 'package:pescar_delta/models/expense.dart';

Expense _e(String desc, String cat, {String? preset}) => Expense(
  id: desc,
  description: desc,
  amount: 10,
  paidBy: 'pop',
  common: true,
  sharedWith: const ['pop'],
  date: DateTime(2026, 10, 20),
  category: cat,
  presetId: preset,
);

void main() {
  final benzina = ExpensePreset(
    id: 'b',
    name: 'Benzină barcă',
    category: 'Combustibil',
  );
  final momeli = ExpensePreset(id: 'm', name: 'Momeli', category: 'Momeli');
  final presets = [benzina, momeli];

  test('cheltuiala ajunge pe cardul potrivit', () {
    expect(cardOf(_e('x', 'Combustibil', preset: 'b'), presets), benzina);
    expect(cardOf(_e('momeli', 'Altele'), presets), momeli);
    // scrisă de mână, cu categoria aleasă → cardul categoriei
    expect(cardOf(_e('Viermi', 'Momeli'), presets), momeli);
    // presetare aleasă, apoi categoria schimbată → cardul noii categorii
    expect(
      cardOf(_e('Benzină barcă 2', 'Momeli', preset: 'b'), presets),
      momeli,
    );
    // fără card în categorie sau categoria „Altele” → Altele
    expect(cardOf(_e('Pâine', 'Mâncare-Băutură'), presets), isNull);
    expect(cardOf(_e('Diverse', 'Altele'), presets), isNull);
  });
}
