/// Copia (poză/scan) a unui act: CI, cupon de pensie, certificat barcă etc.
/// Se ține criptat, în baza de date locală.
class DocCopy {
  DocCopy({required this.id, required this.label, required this.base64});

  final String id;
  String label;
  final String base64;

  Map<String, dynamic> toJson() => {'id': id, 'label': label, 'base64': base64};

  factory DocCopy.fromJson(Map<String, dynamic> j) =>
      DocCopy(id: j['id'], label: j['label'] ?? '', base64: j['base64']);

  static List<DocCopy> listFrom(dynamic raw) => [
    for (final e in (raw as List? ?? []))
      DocCopy.fromJson(Map<String, dynamic>.from(e)),
  ];
}
