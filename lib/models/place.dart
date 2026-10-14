/// O localitate / zonă de pescuit cu coordonate (pentru vreme).
class Place {
  const Place(this.name, this.lat, this.lng);

  final String name;
  final double lat;
  final double lng;

  /// Cheie stabilă pentru jurnalul meteo (≈100 m precizie).
  String get key => '${lat.toStringAsFixed(3)},${lng.toStringAsFixed(3)}';
}

const sfantuGheorghe = Place('Sfântu Gheorghe', 44.896, 29.59294);

/// Localitățile din Deltă propuse rapid la alegerea locației sezonului
/// (coordonate din geocoding Open-Meteo).
const deltaPlaces = [
  sfantuGheorghe,
  Place('Crișan', 45.17462, 29.38598),
  Place('Sulina', 45.15564, 29.65403),
  Place('Mila 23', 45.22738, 29.24533),
  Place('Caraorman', 45.07891, 29.39321),
  Place('Uzlina', 45.07345, 29.22681),
  Place('Murighiol', 45.03333, 29.16667),
  Place('Mahmudia', 45.08333, 29.08333),
  Place('Chilia Veche', 45.41667, 29.28333),
  Place('Periprava', 45.40178, 29.54718),
  Place('Jurilovca', 44.76667, 28.86667),
  Place('Tulcea', 45.1787, 28.8050),
];
