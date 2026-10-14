import 'package:flutter_test/flutter_test.dart';
import 'package:pescar_delta/models/boat.dart';
import 'package:pescar_delta/models/need_item.dart';
import 'package:pescar_delta/models/participant.dart';
import 'package:pescar_delta/models/season.dart';
import 'package:pescar_delta/services/permit_catalog.dart';
import 'package:pescar_delta/services/weather_service.dart';

void main() {
  final pensionar = Participant(
    id: 'p1',
    nume: 'Ionescu',
    prenume: 'Mihai Andrei',
    cnp: '1500101400001',
    email: 'a@b.ro',
    judet: 'Tulcea',
    telefon: '0700000000',
    category: ParticipantCategory.pensionar,
  );
  final platitor = Participant(id: 'p2', nume: 'Ion', prenume: 'Vasile');
  final boat = Boat(id: 'b1', denumire: 'Lotca', ownerId: 'p1');

  Season season() => Season(
    id: 's1',
    year: DateTime.now().year + 1,
    kind: SeasonKind.primavara,
    start: DateTime(DateTime.now().year + 1, 3, 1),
    end: DateTime(DateTime.now().year + 1, 4, 5),
    participantIds: ['p1', 'p2'],
    boatIds: ['b1'],
    accessDuration: AccessDuration.zile7,
    permitStart: DateTime(DateTime.now().year + 1, 3, 1),
  );

  test('pensionarul primește permisul de acces gratuit', () {
    final tasks = buildPermitTasks(
      season: season(),
      participants: [pensionar, platitor],
      boats: [boat],
    );
    final access = tasks.where((t) => t.kind == PermitKind.acces).toList();
    expect(access.first.product.id, 4);
    expect(access.last.product.id, 6);
    expect(access.first.fields['fname'], 'Ionescu');
    expect(access.first.fields['lname'], 'Mihai Andrei');
    expect(
      access.first.fields['valabilitate_this_year_365_zile'],
      '01-03-${DateTime.now().year + 1}',
    );
  });

  test('permisul de pescuit cere CNP, barca cere datele bărcii', () {
    final tasks = buildPermitTasks(
      season: season(),
      participants: [pensionar, platitor],
      boats: [boat],
    );
    final fishing = tasks.where((t) => t.kind == PermitKind.pescuit).toList();
    expect(fishing.first.ready, isTrue);
    expect(fishing.last.missing, contains('CNP'));
    final b = tasks.singleWhere((t) => t.kind == PermitKind.barca);
    expect(b.product.id, 9);
    expect(b.missing, containsAll(['nr. înmatriculare', 'port']));
  });

  test('fără ziua de început, permisele nu sunt gata', () {
    final s = season()..permitStart = null;
    final tasks = buildPermitTasks(
      season: s,
      participants: [pensionar],
      boats: [],
    );
    expect(tasks.every((t) => t.missing.contains('ziua de început')), isTrue);
  });

  test('lista de necesar se salvează și se reîncarcă', () {
    final s = season();
    s.needsOf(NeedCategory.momeli).add(NeedItem(id: 'n1', text: 'Porumb'));
    s
        .needsOf(NeedCategory.probleme)
        .add(NeedItem(id: 'n2', text: 'Motor', done: true));
    final back = Season.fromJson(s.toJson());
    expect(back.needsOf(NeedCategory.momeli).single.text, 'Porumb');
    expect(back.needsOf(NeedCategory.probleme).single.done, isTrue);
    expect(back.needsOf(NeedCategory.tinuta), isEmpty);
  });

  test('sezoanele din anii trecuți sunt arhivate', () {
    final s = season()..year = DateTime.now().year - 1;
    expect(s.archived, isTrue);
    expect(season().archived, isFalse);
  });

  test('faza lunii: 2024-01-11 a fost lună nouă', () {
    expect(moonFor(DateTime.utc(2024, 1, 11, 12)).name, 'Lună nouă');
    expect(moonFor(DateTime.utc(2024, 1, 25, 18)).name, 'Lună plină');
  });
}
