/// Un fișier de permis (PDF/imagine) salvat în folderul `permise/<an>-<sezon>/`.
class PermitFile {
  PermitFile({
    required this.id,
    required this.seasonId,
    required this.fileName,
    required this.relativePath,
    required this.addedAt,
    this.taskKey,
  });

  final String id;
  final String seasonId;
  final String fileName;

  /// Calea relativă la directorul aplicației, ex. `permise/2026-primavara/x.pdf`.
  /// Pe web conținutul se ține în baza de date sub cheia [id].
  final String relativePath;
  final DateTime addedAt;

  /// Permisul (din sezon) căruia îi aparține fișierul, ex. `pescuit:<id>`.
  final String? taskKey;

  Map<String, dynamic> toJson() => {
    'id': id,
    'seasonId': seasonId,
    'fileName': fileName,
    'relativePath': relativePath,
    'addedAt': addedAt.toIso8601String(),
    'taskKey': taskKey,
  };

  factory PermitFile.fromJson(Map<String, dynamic> j) => PermitFile(
    id: j['id'],
    seasonId: j['seasonId'],
    fileName: j['fileName'],
    relativePath: j['relativePath'],
    addedAt: DateTime.parse(j['addedAt']),
    taskKey: j['taskKey'],
  );
}
