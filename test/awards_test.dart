import 'package:flutter_test/flutter_test.dart';
import 'package:pescar_delta/models/awards.dart';
import 'package:pescar_delta/models/catch_entry.dart';

CatchEntry _c(String? who, double? kg, {String species = 'Crap'}) =>
    CatchEntry(id: '$who$kg', species: species, date: DateTime(2026, 10, 20))
      ..participantId = who
      ..weightKg = kg;

void main() {
  test('premiile: cea mai mare captură, cantitate, număr', () {
    final a = computeAwards([
      _c('pop', 5),
      _c('pop', 1),
      _c('pop', 1),
      _c('gal', 7.5, species: 'Somn'),
      _c(null, 2),
    ]);
    expect(a.biggest.single.species, 'Somn');
    expect(a.topKgIds, ['gal']);
    expect(a.topKg, 7.5);
    expect(a.topCountIds, ['pop']);
    expect(a.topCount, 3);
  });

  test('premiile: egalitate și capturi necântărite', () {
    final a = computeAwards([_c('pop', null), _c('gal', null)]);
    expect(a.biggest, isEmpty);
    expect(a.topKgIds, isEmpty);
    expect(a.topCountIds, unorderedEquals(['pop', 'gal']));
    expect(a.topCount, 1);
  });
}
