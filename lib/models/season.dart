import 'expense.dart';
import 'need_item.dart';
import 'place.dart';

enum SeasonKind {
  primavara('Primăvară'),
  toamna('Toamnă');

  const SeasonKind(this.label);
  final String label;

  static SeasonKind fromName(String? n) =>
      SeasonKind.values.firstWhere((k) => k.name == n, orElse: () => primavara);
}

enum AccessDuration {
  zi1('1 zi'),
  zile7('7 zile'),
  an('Până la finele anului');

  const AccessDuration(this.label);
  final String label;

  static AccessDuration fromName(String? n) =>
      AccessDuration.values.firstWhere((d) => d.name == n, orElse: () => an);
}

enum BoatDuration {
  zile7('7 zile'),
  an('Până la finele anului');

  const BoatDuration(this.label);
  final String label;

  static BoatDuration fromName(String? n) =>
      BoatDuration.values.firstWhere((d) => d.name == n, orElse: () => an);
}

class Season {
  Season({
    required this.id,
    required this.year,
    required this.kind,
    required this.start,
    required this.end,
    List<String>? participantIds,
    List<String>? boatIds,
    this.accessDuration = AccessDuration.an,
    this.boatDuration = BoatDuration.an,
    Map<String, bool>? purchased,
    this.notes = '',
    this.permitStart,
    this.place = sfantuGheorghe,
    Map<String, List<NeedItem>>? needs,
    List<Expense>? expenses,
  }) : needs = needs ?? {},
       expenses = expenses ?? [],
       participantIds = participantIds ?? [],
       boatIds = boatIds ?? [],
       purchased = purchased ?? {};

  final String id;
  int year;
  SeasonKind kind;
  DateTime start;
  DateTime end;
  List<String> participantIds;
  List<String> boatIds;
  AccessDuration accessDuration;
  BoatDuration boatDuration;

  /// Cheie: `<tip permis>:<id participant sau barcă>` → cumpărat.
  Map<String, bool> purchased;
  String notes;

  /// Ziua de la care încep permisele (ex. ziua plecării) — o scrie userul;
  /// fără ea permisele nu se completează.
  DateTime? permitStart;

  /// Locația sezonului (ex. Sfântu Gheorghe, Crișan) — pentru vreme.
  Place place;

  /// Pagina „Necesar”: liste numerotate pe categorii.
  /// id categorie → rânduri.
  Map<String, List<NeedItem>> needs;

  List<NeedItem> needsOf(NeedCategory c) => needs.putIfAbsent(c.id, () => []);

  /// Cheltuielile sezonului (comune sau personale).
  List<Expense> expenses;

  /// Ultima zi acoperită de un permis de [d] care începe în [from].
  static DateTime endFor(DateTime from, AccessDuration d) => switch (d) {
    AccessDuration.zi1 => DateTime(from.year, from.month, from.day),
    AccessDuration.zile7 => DateTime(from.year, from.month, from.day + 6),
    AccessDuration.an => DateTime(from.year, 12, 31),
  };

  /// Aliniază perioada sezonului cu permisele (începutul și durata lor).
  /// Întoarce true dacă s-a schimbat ceva.
  bool syncPeriodWithPermits() {
    final from = permitStart;
    if (from == null) return false;
    final newStart = DateTime(from.year, from.month, from.day);
    final newEnd = endFor(newStart, accessDuration);
    if (newStart == start && newEnd == end) return false;
    start = newStart;
    end = newEnd;
    year = newStart.year;
    return true;
  }

  String get title => '${kind.label} $year';
  String get folderName => '$year-${kind.name}';

  /// Sezoanele se arhivează automat după ce trece anul.
  bool get archived => year < DateTime.now().year;

  bool contains(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    return !day.isBefore(DateTime(start.year, start.month, start.day)) &&
        !day.isAfter(DateTime(end.year, end.month, end.day));
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'year': year,
    'kind': kind.name,
    'start': start.toIso8601String(),
    'end': end.toIso8601String(),
    'participantIds': participantIds,
    'boatIds': boatIds,
    'accessDuration': accessDuration.name,
    'boatDuration': boatDuration.name,
    'purchased': purchased,
    'notes': notes,
    'permitStart': permitStart?.toIso8601String(),
    'place': {'name': place.name, 'lat': place.lat, 'lng': place.lng},
    'needs': {
      for (final e in needs.entries)
        e.key: e.value.map((i) => i.toJson()).toList(),
    },
    'expenses': expenses.map((e) => e.toJson()).toList(),
  };

  factory Season.fromJson(Map<String, dynamic> j) => Season(
    id: j['id'],
    year: j['year'],
    kind: SeasonKind.fromName(j['kind']),
    start: DateTime.parse(j['start']),
    end: DateTime.parse(j['end']),
    participantIds: List<String>.from(j['participantIds'] ?? []),
    boatIds: List<String>.from(j['boatIds'] ?? []),
    accessDuration: AccessDuration.fromName(j['accessDuration']),
    boatDuration: BoatDuration.fromName(j['boatDuration']),
    purchased: Map<String, bool>.from(j['purchased'] ?? {}),
    notes: j['notes'] ?? '',
    permitStart: j['permitStart'] == null
        ? null
        : DateTime.parse(j['permitStart']),
    place: j['place'] == null
        ? sfantuGheorghe
        : Place(
            j['place']['name'],
            (j['place']['lat'] as num).toDouble(),
            (j['place']['lng'] as num).toDouble(),
          ),
    needs: {
      for (final e in ((j['needs'] as Map?) ?? {}).entries)
        e.key as String: [
          for (final i in e.value as List)
            NeedItem.fromJson(Map<String, dynamic>.from(i)),
        ],
    },
    expenses: [
      for (final e in (j['expenses'] as List? ?? []))
        Expense.fromJson(Map<String, dynamic>.from(e)),
    ],
  );
}

/// Problemele de remediat nebifate din sezoanele care au început înaintea
/// lui [season] (fără cele scrise din nou în [season]); cele mai noi primele.
List<(Season, NeedItem)> openProblems(
  List<Season> seasons,
  List<NeedCategory> categories,
  Season season,
) {
  final cats = categories.where((c) => c.isProblems).toList();
  if (cats.isEmpty) return const [];
  final here = {
    for (final c in cats)
      for (final i in season.needsOf(c)) i.text.trim().toLowerCase(),
  };
  final earlier =
      seasons
          .where((s) => s.id != season.id && s.start.isBefore(season.start))
          .toList()
        ..sort((a, b) => b.start.compareTo(a.start));
  final seen = <String>{};
  return [
    for (final s in earlier)
      for (final c in cats)
        for (final i in s.needsOf(c))
          if (!i.done &&
              i.text.trim().isNotEmpty &&
              !here.contains(i.text.trim().toLowerCase()) &&
              seen.add(i.text.trim().toLowerCase()))
            (s, i),
  ];
}
