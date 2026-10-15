import 'catch_entry.dart';

/// Premiile unei perioade (o zi sau un sezon). La egalitate premiul se
/// împarte; capturile fără pescar ales contează doar la cea mai mare captură.
class Awards {
  const Awards({
    required this.biggest,
    required this.topKgIds,
    required this.topKg,
    required this.topCountIds,
    required this.topCount,
  });

  /// Cea mai grea captură (mai multe la egalitate); goală dacă nu e cântărită
  /// nicio captură.
  final List<CatchEntry> biggest;

  /// Pescarii cu cea mai mare cantitate (kg) și cantitatea lor.
  final List<String> topKgIds;
  final double topKg;

  /// Pescarii cu cei mai mulți pești și numărul lor.
  final List<String> topCountIds;
  final int topCount;

  bool get isEmpty =>
      biggest.isEmpty && topKgIds.isEmpty && topCountIds.isEmpty;
}

Awards computeAwards(Iterable<CatchEntry> catches) {
  final biggest = <CatchEntry>[];
  final kg = <String, double>{};
  final count = <String, int>{};
  for (final c in catches) {
    final w = c.weightKg;
    if (w != null && w > 0) {
      if (biggest.isEmpty || w > biggest.first.weightKg!) {
        biggest
          ..clear()
          ..add(c);
      } else if (w == biggest.first.weightKg) {
        biggest.add(c);
      }
    }
    final id = c.participantId;
    if (id == null) continue;
    kg[id] = (kg[id] ?? 0) + (w ?? 0);
    count[id] = (count[id] ?? 0) + 1;
  }

  List<String> leaders<T extends num>(Map<String, T> m, T best) => [
    for (final e in m.entries)
      if (e.value == best) e.key,
  ];

  final topKg = kg.values.fold<double>(0, (a, b) => b > a ? b : a);
  final topCount = count.values.fold<int>(0, (a, b) => b > a ? b : a);
  return Awards(
    biggest: biggest,
    topKgIds: topKg > 0 ? leaders(kg, topKg) : const [],
    topKg: topKg,
    topCountIds: topCount > 0 ? leaders(count, topCount) : const [],
    topCount: topCount,
  );
}
