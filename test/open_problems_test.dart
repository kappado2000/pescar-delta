import 'package:flutter_test/flutter_test.dart';
import 'package:pescar_delta/models/need_item.dart';
import 'package:pescar_delta/models/season.dart';

Season _s(String id, int month) => Season(
  id: id,
  year: 2026,
  kind: month < 6 ? SeasonKind.primavara : SeasonKind.toamna,
  start: DateTime(2026, month, 1),
  end: DateTime(2026, month, 7),
);

void main() {
  test('problemele nerezolvate trec în sezoanele următoare', () {
    final cats = NeedCategory.defaults();
    final pb = cats.firstWhere((c) => c.isProblems);
    final primavara = _s('p', 4);
    final toamna = _s('t', 10);
    primavara.needsOf(pb).addAll([
      NeedItem(id: '1', text: 'Motor nu pornește'),
      NeedItem(id: '2', text: 'Lanseta ruptă', done: true),
      NeedItem(id: '3', text: 'Ancoră pierdută'),
    ]);
    // în toamnă: nerezolvatele din primăvară, mai puțin cele bifate
    var open = openProblems([primavara, toamna], cats, toamna);
    expect(open.map((e) => e.$2.text), [
      'Motor nu pornește',
      'Ancoră pierdută',
    ]);
    // scrisă din nou în sezonul nou → nu mai apare dublat
    toamna.needsOf(pb).add(NeedItem(id: '4', text: 'ancoră pierdută'));
    open = openProblems([primavara, toamna], cats, toamna);
    expect(open.single.$2.text, 'Motor nu pornește');
    // în sezonul de primăvară nu apar probleme „din viitor”
    expect(openProblems([primavara, toamna], cats, primavara), isEmpty);
    // remediată → dispare
    primavara.needsOf(pb).first.done = true;
    expect(openProblems([primavara, toamna], cats, toamna), isEmpty);
  });
}
