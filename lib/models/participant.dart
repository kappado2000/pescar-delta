import 'doc_copy.dart';

/// Categoria determină dacă permisul de acces turist este gratuit (ARBDD).
enum ParticipantCategory {
  standard('Standard', false),
  pensionar('Pensionar', true),
  elevStudent('Elev / student', true),
  veteran('Veteran', true),
  dizabilitati('Persoană cu dizabilități', true);

  const ParticipantCategory(this.label, this.freeAccess);
  final String label;
  final bool freeAccess;

  static ParticipantCategory fromName(String? name) => ParticipantCategory
      .values
      .firstWhere((c) => c.name == name, orElse: () => standard);
}

class Participant {
  Participant({
    required this.id,
    required this.nume,
    required this.prenume,
    this.cnp = '',
    this.email = '',
    this.telefon = '',
    this.judet = '',
    this.tara = 'Romania',
    this.category = ParticipantCategory.standard,
    this.notes = '',
    this.ciSerie = '',
    this.ciNumar = '',
    this.ciExpira,
    this.pensieDoc = '',
    List<DocCopy>? documents,
  }) : documents = documents ?? [];

  final String id;
  String nume;
  String prenume;
  String cnp;
  String email;
  String telefon;
  String judet;
  String tara;
  ParticipantCategory category;
  String notes;
  String ciSerie;
  String ciNumar;
  DateTime? ciExpira;

  /// Nr. decizie / cupon de pensie — dovada gratuității.
  String pensieDoc;
  List<DocCopy> documents;

  bool get ciExpired => ciExpira != null && ciExpira!.isBefore(DateTime.now());

  String get fullName => '$nume $prenume'.trim();

  /// Numele scurt pentru decontare: numele de familie + inițiala, ex. „Pop S.”.
  String get shortName {
    final p = prenume.trim();
    return p.isEmpty ? nume.trim() : '${nume.trim()} ${p[0].toUpperCase()}.';
  }

  /// Câmpurile obligatorii pe permise.ddbra.ro care lipsesc.
  List<String> missingFields({bool needsCnp = false, bool needsPhone = false}) {
    return [
      if (nume.trim().isEmpty) 'nume',
      if (prenume.trim().isEmpty) 'prenume',
      if (email.trim().isEmpty) 'email',
      if (judet.trim().isEmpty) 'județ',
      if (needsCnp && cnp.trim().isEmpty) 'CNP',
      if (needsPhone && telefon.trim().isEmpty) 'telefon',
    ];
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'nume': nume,
    'prenume': prenume,
    'cnp': cnp,
    'email': email,
    'telefon': telefon,
    'judet': judet,
    'tara': tara,
    'category': category.name,
    'notes': notes,
    'ciSerie': ciSerie,
    'ciNumar': ciNumar,
    'ciExpira': ciExpira?.toIso8601String(),
    'pensieDoc': pensieDoc,
    'documents': documents.map((d) => d.toJson()).toList(),
  };

  factory Participant.fromJson(Map<String, dynamic> j) => Participant(
    id: j['id'],
    nume: j['nume'] ?? '',
    prenume: j['prenume'] ?? '',
    cnp: j['cnp'] ?? '',
    email: j['email'] ?? '',
    telefon: j['telefon'] ?? '',
    judet: j['judet'] ?? '',
    tara: j['tara'] ?? 'Romania',
    category: ParticipantCategory.fromName(j['category']),
    notes: j['notes'] ?? '',
    ciSerie: j['ciSerie'] ?? '',
    ciNumar: j['ciNumar'] ?? '',
    ciExpira: j['ciExpira'] == null ? null : DateTime.parse(j['ciExpira']),
    pensieDoc: j['pensieDoc'] ?? '',
    documents: DocCopy.listFrom(j['documents']),
  );
}
