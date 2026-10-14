import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pescar_delta/widgets/quick_expense_sheet.dart';

void main() {
  test('iconița automată după numele cardului', () {
    expect(expenseIcon('Transport', 'Taxă pod'), Icons.toll);
    expect(expenseIcon('Transport', 'Bac Tulcea'), Icons.directions_ferry);
    expect(expenseIcon('Altele', 'Tabac'), isNot(Icons.directions_ferry));
    expect(expenseIcon('Mâncare-Băutură', 'Restaurant'), Icons.restaurant_menu);
    expect(expenseIcon('Mâncare-Băutură', 'Pește'), Icons.set_meal);
    expect(expenseIcon('Mâncare-Băutură', 'Gheață'), Icons.ac_unit);
    expect(
      expenseIcon('Combustibil', 'Benzină barcă'),
      Icons.local_gas_station,
    );
    expect(expenseIcon('Altele', 'Farmacie'), Icons.local_pharmacy);
  });
}
