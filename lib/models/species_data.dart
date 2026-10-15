import 'dart:math';

/// Relația greutate–lungime W(g) = a · L(cm)^b, pe specii (valori tipice din
/// FishBase pentru apele din Europa). Dă o estimare, nu o cântărire.
const _lengthWeight = <String, (double, double)>{
  'Crap': (0.0145, 3.0),
  'Caras': (0.022, 3.0),
  'Somn': (0.0054, 3.1),
  'Știucă': (0.0049, 3.06),
  'Șalău': (0.0075, 3.05),
  'Biban': (0.0118, 3.08),
  'Plătică': (0.0105, 3.1),
  'Roșioară': (0.0125, 3.0),
  'Babușcă': (0.0125, 3.0),
  'Avat': (0.0087, 3.05),
  'Fitofag': (0.0110, 3.05),
  'Novac': (0.0125, 3.05),
  'Cosaș': (0.0125, 3.0),
  'Lin': (0.0145, 3.05),
};

/// Greutatea estimată (kg) pentru lungimea dată, sau null dacă specia nu e
/// în tabel ori lungimea lipsește.
double? estimateWeightKg(String species, double? lengthCm) {
  final ab = _lengthWeight[species];
  if (ab == null || lengthCm == null || lengthCm <= 0) return null;
  final grams = ab.$1 * pow(lengthCm, ab.$2);
  return (grams / 1000 * 100).round() / 100; // 2 zecimale
}

bool hasWeightEstimate(String species) => _lengthWeight.containsKey(species);

List<String> _porumb({required bool cu2}) => [
  if (cu2) 'Porumb - 2',
  'Porumb - 3',
  'Porumb uscat - 2',
  'Porumb uscat - 3',
  'Porumb cu aromă de vanilie - 2',
  'Porumb cu aromă de vanilie - 3',
  'Porumb cu aromă de scoică - 2',
  'Porumb cu aromă de scoică - 3',
  'Porumb cu alte arome - 2',
  'Porumb cu alte arome - 3',
  'Mămăligă',
  'Viermuși',
];

/// Momeala implicită și lista de variante pe specie.
final speciesBaits = <String, (String, List<String>)>{
  'Crap': ('Boilies', ['Boilies', ..._porumb(cu2: true)]),
  'Caras': ('Porumb - 2', _porumb(cu2: true)),
  'Somn': (
    'Buchet râme cu coropișniță',
    [
      'Buchet râme cu coropișniță',
      'Buchet râme',
      'Coropișniță',
      'Viermi de salcie',
    ],
  ),
  'Știucă': (
    'Linguriță aurie cu roșu',
    [
      'Linguriță aurie cu roșu',
      'Linguriță argintie cu roșu',
      'Spinnerbait verde',
      'Spinnerbait alb',
      'Năluca verzuie',
      'Năluca albă',
      'Vobler',
    ],
  ),
};

/// Metoda implicită pe specie.
const speciesMethod = <String, String>{
  'Crap': 'Fund',
  'Caras': 'Fund',
  'Somn': 'Fund',
  'Știucă': 'Spinning',
};
