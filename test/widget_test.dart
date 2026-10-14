import 'package:flutter_test/flutter_test.dart';
import 'package:pescar_delta/models/boat.dart';
import 'package:pescar_delta/models/expense.dart';
import 'package:pescar_delta/models/need_item.dart';
import 'package:pescar_delta/models/participant.dart';
import 'package:pescar_delta/models/season.dart';
import 'package:pescar_delta/services/permit_catalog.dart';
import 'package:pescar_delta/services/weather_service.dart';

void main() {
  final pensionar = Participant(
    id: 'p1',
    nume: 'Pop',
    prenume: 'Simion Adrian',
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
    expect(access.first.fields['fname'], 'Pop');
    expect(access.first.fields['lname'], 'Simion Adrian');
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
    final cats = {for (final c in NeedCategory.defaults()) c.id: c};
    s.needsOf(cats['momeli']!).add(NeedItem(id: 'n1', text: 'Porumb'));
    s
        .needsOf(cats['probleme']!)
        .add(NeedItem(id: 'n2', text: 'Motor', done: true));
    final back = Season.fromJson(s.toJson());
    expect(back.needsOf(cats['momeli']!).single.text, 'Porumb');
    expect(back.needsOf(cats['probleme']!).single.done, isTrue);
    expect(back.needsOf(cats['tinuta']!), isEmpty);
    // o categorie nouă, creată de user
    final noua = NeedCategory(id: 'x1', label: 'Medicamente');
    s.needsOf(noua).add(NeedItem(id: 'n3', text: 'Plasturi'));
    expect(Season.fromJson(s.toJson()).needsOf(noua).single.text, 'Plasturi');
  });

  test('cheltuieli: comune împărțite egal, personale, decontare', () {
    final now = DateTime(2026, 5, 1);
    final expenses = [
      // A plătește 300 lei mâncare comună pentru A, B, C → 100 fiecare
      Expense(
        id: '1',
        description: 'Mâncare',
        amount: 300,
        paidBy: 'A',
        common: true,
        sharedWith: ['A', 'B', 'C'],
        date: now,
      ),
      // B plătește 60 lei momeli comune pentru toți → 20 fiecare
      Expense(
        id: '2',
        description: 'Momeli',
        amount: 60,
        paidBy: 'B',
        common: true,
        sharedWith: ['A', 'B', 'C'],
        date: now,
      ),
      // A plătește 50 lei o lanseta personală a lui C
      Expense(
        id: '3',
        description: 'Lansetă',
        amount: 50,
        paidBy: 'A',
        common: false,
        sharedWith: ['C'],
        date: now,
      ),
    ];
    final b = balancesOf(expenses, ['A', 'B', 'C']);
    expect(b['A']!.balance, closeTo(350 - 120, 0.001)); // primește 230
    expect(b['B']!.balance, closeTo(60 - 120, 0.001)); // dă 60
    expect(b['C']!.balance, closeTo(0 - 170, 0.001)); // dă 170
    final t = settle(b);
    expect(t.fold<double>(0, (s, x) => s + x.amount), closeTo(230, 0.001));
    expect(t.every((x) => x.to == 'A'), isTrue);
  });

  test('2 participanți: cheltuiala comună se împarte la 2', () {
    final now = DateTime(2026, 5, 1);
    final expenses = [
      Expense(
        id: '1',
        description: 'Benzină barcă',
        amount: 300,
        paidBy: 'Pop',
        common: true,
        sharedWith: ['Pop', 'Ion'],
        date: now,
      ),
      Expense(
        id: '2',
        description: 'Benzină barcă',
        amount: 100,
        paidBy: 'Pop',
        common: true,
        sharedWith: ['Pop', 'Ion'],
        date: now,
      ),
      // cheltuiala proprie nu creează datorii
      Expense(
        id: '3',
        description: 'Cârlige',
        amount: 40,
        paidBy: 'Ion',
        common: false,
        sharedWith: ['Ion'],
        date: now,
      ),
    ];
    final common = expenses.where((e) => e.common).toList();
    final b = balancesOf(common, ['Pop', 'Ion']);
    expect(b['Ion']!.commonShare, 200);
    final t = settle(b).single;
    expect((t.from, t.to, t.amount), ('Ion', 'Pop', 200.0));
    expect(settle(balancesOf(expenses, ['Pop', 'Ion'])).single.amount, 200);
    expect(numberExpenses(expenses), 4);
    expect(expenses.map((e) => e.number), [1, 2, 3]);
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
