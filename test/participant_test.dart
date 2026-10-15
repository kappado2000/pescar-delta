import 'package:flutter_test/flutter_test.dart';
import 'package:pescar_delta/models/participant.dart';

void main() {
  test('numele de alint: porecla sau primul prenume', () {
    final pop = Participant(id: '1', nume: 'Pop', prenume: 'Simion Adrian');
    expect(pop.callName, 'Simion');
    pop.porecla = 'Adi';
    expect(pop.callName, 'Adi');
    expect(Participant.fromJson(pop.toJson()).callName, 'Adi');
    expect(
      Participant(id: '2', nume: 'Gal', prenume: 'Vasile').callName,
      'Vasile',
    );
  });
}
