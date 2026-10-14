import 'doc_copy.dart';

/// Opțiunile exacte din select-ul de pe permise.ddbra.ro.
const boatTypes = [
  'Barca cu motor',
  'Lotca pescuit',
  'Ambarcatiune agrement',
  'Barca pneumatica',
  'Salupa',
  'Velier',
  'Barca gonflabila',
  'Ambarcatiune cabinata',
  'Alt tip',
];

class Boat {
  Boat({
    required this.id,
    required this.denumire,
    this.nrInmatriculare = '',
    this.capacitateMotor = '',
    this.tip = 'Barca cu motor',
    this.port = '',
    this.ownerId,
    this.gratuit = false,
    this.marcaMotor = '',
    this.serieMotor = '',
    this.lungime = '',
    this.notes = '',
    List<DocCopy>? documents,
  }) : documents = documents ?? [];

  final String id;
  String denumire;
  String nrInmatriculare;
  String capacitateMotor;
  String tip;
  String port;

  /// Participantul ale cărui date personale apar pe permisul bărcii.
  String? ownerId;

  /// Rezidenți în rezervație / localități limitrofe → permis gratuit.
  bool gratuit;
  String marcaMotor;
  String serieMotor;
  String lungime;
  String notes;

  /// Copii: certificat de înmatriculare, permis de conducere ambarcațiune etc.
  List<DocCopy> documents;

  Map<String, dynamic> toJson() => {
    'id': id,
    'denumire': denumire,
    'nrInmatriculare': nrInmatriculare,
    'capacitateMotor': capacitateMotor,
    'tip': tip,
    'port': port,
    'ownerId': ownerId,
    'gratuit': gratuit,
    'marcaMotor': marcaMotor,
    'serieMotor': serieMotor,
    'lungime': lungime,
    'notes': notes,
    'documents': documents.map((d) => d.toJson()).toList(),
  };

  factory Boat.fromJson(Map<String, dynamic> j) => Boat(
    id: j['id'],
    denumire: j['denumire'] ?? '',
    nrInmatriculare: j['nrInmatriculare'] ?? '',
    capacitateMotor: j['capacitateMotor'] ?? '',
    tip: boatTypes.contains(j['tip']) ? j['tip'] : 'Barca cu motor',
    port: j['port'] ?? '',
    ownerId: j['ownerId'],
    gratuit: j['gratuit'] ?? false,
    marcaMotor: j['marcaMotor'] ?? '',
    serieMotor: j['serieMotor'] ?? '',
    lungime: j['lungime'] ?? '',
    notes: j['notes'] ?? '',
    documents: DocCopy.listFrom(j['documents']),
  );
}
