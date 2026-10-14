/// O categorie a paginii „Necesar” (ex. Momeli). Categoriile sunt comune
/// tuturor sezoanelor și se pot adăuga, redenumi, șterge și reordona.
class NeedCategory {
  NeedCategory({
    required this.id,
    required this.label,
    this.doneLabel = 'bifat',
  });

  final String id;
  String label;

  /// Ce înseamnă bifa în categoria asta („pregătit”, „cumpărat”…).
  String doneLabel;

  /// Categoria problemelor: cele remediate nu se mai propun în alt sezon.
  bool get isProblems => id == 'probleme';

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'doneLabel': doneLabel,
  };

  factory NeedCategory.fromJson(Map<String, dynamic> j) => NeedCategory(
    id: j['id'],
    label: j['label'] ?? '',
    doneLabel: j['doneLabel'] ?? 'bifat',
  );

  /// Categoriile de pornire (id-urile păstrează datele deja introduse).
  static List<NeedCategory> defaults() => [
    NeedCategory(
      id: 'echipament',
      label: 'Echipament pescuit',
      doneLabel: 'pregătit',
    ),
    NeedCategory(id: 'tinuta', label: 'Ținută', doneLabel: 'pregătit'),
    NeedCategory(id: 'barca', label: 'Barcă', doneLabel: 'pregătit'),
    NeedCategory(id: 'momeli', label: 'Momeli', doneLabel: 'cumpărat'),
    NeedCategory(
      id: 'mancare',
      label: 'Mâncare-Băutură',
      doneLabel: 'cumpărat',
    ),
    NeedCategory(id: 'alte', label: 'Alte nevoi', doneLabel: 'rezolvat'),
    NeedCategory(
      id: 'probleme',
      label: 'Probleme de remediat',
      doneLabel: 'remediat',
    ),
  ];
}

/// Un rând din lista de necesar.
class NeedItem {
  NeedItem({required this.id, this.text = '', this.done = false});

  final String id;
  String text;
  bool done;

  Map<String, dynamic> toJson() => {'id': id, 'text': text, 'done': done};

  factory NeedItem.fromJson(Map<String, dynamic> j) =>
      NeedItem(id: j['id'], text: j['text'] ?? '', done: j['done'] ?? false);
}
