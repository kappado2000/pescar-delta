import 'package:flutter_test/flutter_test.dart';
import 'package:pescar_delta/models/species_data.dart';

void main() {
  test('greutatea estimată din lungime e realistă', () {
    expect(estimateWeightKg('Crap', 60), closeTo(3.1, 0.3));
    expect(estimateWeightKg('Știucă', 70), closeTo(2.2, 0.3));
    expect(estimateWeightKg('Somn', 100), closeTo(8.6, 1.0));
    expect(estimateWeightKg('Caras', 30), closeTo(0.6, 0.1));
    expect(estimateWeightKg('Altă specie', 50), isNull);
    expect(estimateWeightKg('Crap', null), isNull);
  });

  test('momeala și metoda implicite pe specie', () {
    expect(speciesBaits['Crap']!.$1, 'Boilies');
    expect(speciesBaits['Caras']!.$1, 'Porumb - 2');
    expect(speciesBaits['Somn']!.$1, 'Buchet râme cu coropișniță');
    expect(speciesBaits['Știucă']!.$1, 'Linguriță aurie cu roșu');
    expect(speciesBaits['Crap']!.$2, contains('Porumb cu aromă de scoică - 3'));
    expect(speciesMethod['Știucă'], 'Spinning');
    expect(speciesMethod['Somn'], 'Fund');
  });
}
