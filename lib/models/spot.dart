class Spot {
  Spot({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    this.notes = '',
    this.depthM,
  });

  final String id;
  String name;
  double lat;
  double lng;
  String notes;
  double? depthM;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'lat': lat,
    'lng': lng,
    'notes': notes,
    'depthM': depthM,
  };

  factory Spot.fromJson(Map<String, dynamic> j) => Spot(
    id: j['id'],
    name: j['name'] ?? '',
    lat: (j['lat'] as num).toDouble(),
    lng: (j['lng'] as num).toDouble(),
    notes: j['notes'] ?? '',
    depthM: (j['depthM'] as num?)?.toDouble(),
  );
}
