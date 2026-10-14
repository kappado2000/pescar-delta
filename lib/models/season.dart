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
  }) : participantIds = participantIds ?? [],
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
  );
}
