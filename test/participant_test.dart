import 'package:flutter_test/flutter_test.dart';
import 'package:pescar_delta/models/participant.dart';

void main() {
  test('numele de alint: porecla sau primul prenume', () {
    final pop = Participant(id: '1', nume: 'Ionescu', prenume: 'Mihai Andrei');
    expect(pop.callName, 'Mihai');
    pop.porecla = 'Miki';
    expect(pop.callName, 'Miki');
    expect(Participant.fromJson(pop.toJson()).callName, 'Miki');
    expect(
      Participant(id: '2', nume: 'Marin', prenume: 'Vasile').callName,
      'Vasile',
    );
  });
}
