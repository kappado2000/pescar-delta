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
    this.photoBase64,
    this.released = false,
    this.notes = '',
    this.participantId,
    this.weather,
  });

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
  String? photoBase64;
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
    'photoBase64': photoBase64,
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
    photoBase64: j['photoBase64'],
    released: j['released'] ?? false,
    notes: j['notes'] ?? '',
    participantId: j['participantId'],
    weather: j['weather'] == null
        ? null
        : WeatherSnapshot.fromJson(Map<String, dynamic>.from(j['weather'])),
  );
}
