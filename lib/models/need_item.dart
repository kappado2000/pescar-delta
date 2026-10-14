/// Categoriile paginii „Necesar” a sezonului, în ordinea tab-urilor.
enum NeedCategory {
  echipament('Echipament pescuit', 'pregătit'),
  tinuta('Ținută', 'pregătit'),
  barca('Barcă', 'pregătit'),
  momeli('Momeli', 'cumpărat'),
  mancare('Mâncare-Băutură', 'cumpărat'),
  alte('Alte nevoi', 'rezolvat'),
  probleme('Probleme de remediat', 'remediat');

  const NeedCategory(this.label, this.doneLabel);
  final String label;

  /// Ce înseamnă bifa în categoria asta.
  final String doneLabel;
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
