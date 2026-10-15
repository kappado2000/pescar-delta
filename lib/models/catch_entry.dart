const commonSpecies = [
  'Crap',
  'Caras',
  'Știucă',
  'Șalău',
  'Somn',
  'Biban',
  'Plătică',
  'Roșioară',
  'Babușcă',
  'Avat',
  'Fitofag',
  'Novac',
  'Cosaș',
  'Lin',
  'Scrumbie',
  'Morunaș',
  'Altă specie',
];

const fishingMethods = [
  'Fund',
  'Feeder',
  'Crap (fund)',
  'Spinning',
  'Plută',
  'Bolognese',
  'Muscă',
  'Somn (clonc)',
  'Altă metodă',
];

class WeatherSnapshot {
  WeatherSnapshot({this.tempC, this.pressureHpa, this.windKmh, this.windDir});

  final double? tempC;
  final double? pressureHpa;
  final double? windKmh;
  final double? windDir;

  Map<String, dynamic> toJson() => {
    'tempC': tempC,
    'pressureHpa': pressureHpa,
    'windKmh': windKmh,
    'windDir': windDir,
  };

  factory WeatherSnapshot.fromJson(Map<String, dynamic> j) => WeatherSnapshot(
    tempC: (j['tempC'] as num?)?.toDouble(),
    pressureHpa: (j['pressureHpa'] as num?)?.toDouble(),
    windKmh: (j['windKmh'] as num?)?.toDouble(),
    windDir: (j['windDir'] as num?)?.toDouble(),
  );
}

/// O poză sau un video al capturii.
///
/// Pozele se țin comprimate în baza de date ([base64]); video-urile sunt
/// fișiere în directorul aplicației ([path], relativ: `media/<captură>/x.mp4`).
class CatchMedia {
  CatchMedia({required this.id, required this.isVideo, this.base64, this.path});

  final String id;
  final bool isVideo;
  final String? base64;
  final String? path;

  Map<String, dynamic> toJson() => {
    'id': id,
    'isVideo': isVideo,
    'base64': base64,
    'path': path,
  };

  factory CatchMedia.fromJson(Map<String, dynamic> j) => CatchMedia(
    id: j['id'],
    isVideo: j['isVideo'] ?? false,
    base64: j['base64'],
    path: j['path'],
  );
}

class CatchEntry {
  CatchEntry({
    required this.id,
    required this.date,
    required this.species,
    this.weightKg,
    this.lengthCm,
    this.bait = '',
    this.method = '',
    this.spotId,
    this.lat,
    this.lng,
    List<CatchMedia>? media,
    this.released = false,
    this.notes = '',
    this.participantId,
    this.weather,
  }) : media = media ?? [];

  final String id;
  DateTime date;
  String species;
  double? weightKg;
  double? lengthCm;
  String bait;
  String method;
  String? spotId;
  double? lat;
  double? lng;

  /// Pozele și video-urile capturii, în ordinea adăugării.
  List<CatchMedia> media;

  /// Prima poză (pentru miniatură).
  String? get photoBase64 =>
      media.where((m) => !m.isVideo && m.base64 != null).firstOrNull?.base64;

  int get videoCount => media.where((m) => m.isVideo).length;
  bool released;
  String notes;
  String? participantId;
  WeatherSnapshot? weather;

  bool get hasLocation => lat != null && lng != null;

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'species': species,
    'weightKg': weightKg,
    'lengthCm': lengthCm,
    'bait': bait,
    'method': method,
    'spotId': spotId,
    'lat': lat,
    'lng': lng,
    'media': media.map((m) => m.toJson()).toList(),
    'released': released,
    'notes': notes,
    'participantId': participantId,
    'weather': weather?.toJson(),
  };

  factory CatchEntry.fromJson(Map<String, dynamic> j) => CatchEntry(
    id: j['id'],
    date: DateTime.parse(j['date']),
    species: j['species'] ?? '',
    weightKg: (j['weightKg'] as num?)?.toDouble(),
    lengthCm: (j['lengthCm'] as num?)?.toDouble(),
    bait: j['bait'] ?? '',
    method: j['method'] ?? '',
    spotId: j['spotId'],
    lat: (j['lat'] as num?)?.toDouble(),
    lng: (j['lng'] as num?)?.toDouble(),
    media: [
      for (final m in (j['media'] as List? ?? []))
        CatchMedia.fromJson(Map<String, dynamic>.from(m)),
      // compatibilitate: poza unică din versiunea anterioară
      if (j['media'] == null && j['photoBase64'] != null)
        CatchMedia(id: 'p0', isVideo: false, base64: j['photoBase64']),
    ],
    released: j['released'] ?? false,
    notes: j['notes'] ?? '',
    participantId: j['participantId'],
    weather: j['weather'] == null
        ? null
        : WeatherSnapshot.fromJson(Map<String, dynamic>.from(j['weather'])),
  );
}
