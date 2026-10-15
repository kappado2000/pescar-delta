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
      _c('ionescu', 5),
      _c('ionescu', 1),
      _c('ionescu', 1),
      _c('marin', 7.5, species: 'Somn'),
      _c(null, 2),
    ]);
    expect(a.biggest.single.species, 'Somn');
    expect(a.topKgIds, ['marin']);
    expect(a.topKg, 7.5);
    expect(a.topCountIds, ['ionescu']);
    expect(a.topCount, 3);
  });

  test('premiile: egalitate și capturi necântărite', () {
    final a = computeAwards([_c('ionescu', null), _c('marin', null)]);
    expect(a.biggest, isEmpty);
    expect(a.topKgIds, isEmpty);
    expect(a.topCountIds, unorderedEquals(['ionescu', 'marin']));
    expect(a.topCount, 1);
  });
}
