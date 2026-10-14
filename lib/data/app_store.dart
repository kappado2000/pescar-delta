import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/boat.dart';
import '../models/catch_entry.dart';
import '../models/participant.dart';
import '../models/permit_file.dart';
import '../models/season.dart';
import '../models/spot.dart';

const _uuid = Uuid();
String newId() => _uuid.v4();

/// Toate datele aplicației, ținute local într-o cutie Hive criptată
/// (cheia AES stă în secure storage — conține CNP-uri).
class AppStore extends ChangeNotifier {
  late Box _box;

  final List<Participant> participants = [];
  final List<Boat> boats = [];
  final List<Season> seasons = [];
  final List<CatchEntry> catches = [];
  final List<Spot> spots = [];
  final List<PermitFile> permitFiles = [];

  Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox(
      'pescar_delta',
      encryptionCipher: HiveAesCipher(await _encryptionKey()),
    );
    _load('participants', participants, Participant.fromJson);
    _load('boats', boats, Boat.fromJson);
    _load('seasons', seasons, Season.fromJson);
    _load('catches', catches, CatchEntry.fromJson);
    _load('spots', spots, Spot.fromJson);
    _load('permitFiles', permitFiles, PermitFile.fromJson);
    await _seedOnce();
  }

  Future<List<int>> _encryptionKey() async {
    const storage = FlutterSecureStorage();
    const keyName = 'pescar_delta_hive_key';
    var encoded = await storage.read(key: keyName);
    if (encoded == null) {
      encoded = base64UrlEncode(Hive.generateSecureKey());
      await storage.write(key: keyName, value: encoded);
    }
    return base64Url.decode(encoded);
  }

  void _load<T>(
    String key,
    List<T> target,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final raw = _box.get(key) as String?;
    if (raw == null) return;
    target.addAll(
      (jsonDecode(raw) as List).map(
        (e) => fromJson(Map<String, dynamic>.from(e)),
      ),
    );
  }

  Future<void> _save(String key, List<dynamic> items) async {
    await _box.put(key, jsonEncode(items.map((e) => e.toJson()).toList()));
    notifyListeners();
  }

  Future<void> _seedOnce() async {
    if (_box.get('seeded') == true) return;
    participants.add(
      Participant(
        id: newId(),
        nume: 'Pop',
        prenume: 'Simion Adrian',
        category: ParticipantCategory.pensionar,
      ),
    );
    await _save('participants', participants);
    await _box.put('seeded', true);
  }

  // ---------- Participanți ----------
  Participant? participant(String? id) =>
      participants.where((p) => p.id == id).firstOrNull;

  Future<void> upsertParticipant(Participant p) async {
    final i = participants.indexWhere((e) => e.id == p.id);
    i >= 0 ? participants[i] = p : participants.add(p);
    participants.sort((a, b) => a.fullName.compareTo(b.fullName));
    await _save('participants', participants);
  }

  Future<void> deleteParticipant(String id) async {
    participants.removeWhere((p) => p.id == id);
    for (final s in seasons) {
      s.participantIds.remove(id);
    }
    for (final b in boats.where((b) => b.ownerId == id)) {
      b.ownerId = null;
    }
    await _save('participants', participants);
    await _save('seasons', seasons);
    await _save('boats', boats);
  }

  // ---------- Bărci ----------
  Future<void> upsertBoat(Boat b) async {
    final i = boats.indexWhere((e) => e.id == b.id);
    i >= 0 ? boats[i] = b : boats.add(b);
    await _save('boats', boats);
  }

  Future<void> deleteBoat(String id) async {
    boats.removeWhere((b) => b.id == id);
    for (final s in seasons) {
      s.boatIds.remove(id);
    }
    await _save('boats', boats);
    await _save('seasons', seasons);
  }

  // ---------- Sezoane ----------
  List<Season> get activeSeasons =>
      seasons.where((s) => !s.archived).toList()
        ..sort((a, b) => a.start.compareTo(b.start));

  /// Arhiva, grupată pe ani (descrescător).
  Map<int, List<Season>> get archivedByYear {
    final map = <int, List<Season>>{};
    for (final s in seasons.where((s) => s.archived)) {
      map.putIfAbsent(s.year, () => []).add(s);
    }
    for (final l in map.values) {
      l.sort((a, b) => a.start.compareTo(b.start));
    }
    return Map.fromEntries(
      map.entries.toList()..sort((a, b) => b.key.compareTo(a.key)),
    );
  }

  Season? season(String? id) => seasons.where((s) => s.id == id).firstOrNull;

  Season? seasonForDate(DateTime d) =>
      seasons.where((s) => s.contains(d)).firstOrNull;

  Future<void> upsertSeason(Season s) async {
    final i = seasons.indexWhere((e) => e.id == s.id);
    i >= 0 ? seasons[i] = s : seasons.add(s);
    await _save('seasons', seasons);
  }

  Future<void> deleteSeason(String id) async {
    for (final f in permitFiles.where((f) => f.seasonId == id).toList()) {
      await deletePermitFile(f);
    }
    seasons.removeWhere((s) => s.id == id);
    await _save('seasons', seasons);
  }

  Future<void> setPurchased(Season s, String taskKey, bool value) async {
    s.purchased[taskKey] = value;
    await _save('seasons', seasons);
  }

  // ---------- Capturi ----------
  Future<void> upsertCatch(CatchEntry c) async {
    final i = catches.indexWhere((e) => e.id == c.id);
    i >= 0 ? catches[i] = c : catches.add(c);
    catches.sort((a, b) => b.date.compareTo(a.date));
    await _save('catches', catches);
  }

  Future<void> deleteCatch(String id) async {
    catches.removeWhere((c) => c.id == id);
    await _save('catches', catches);
  }

  // ---------- Locuri ----------
  Spot? spot(String? id) => spots.where((s) => s.id == id).firstOrNull;

  Future<void> upsertSpot(Spot s) async {
    final i = spots.indexWhere((e) => e.id == s.id);
    i >= 0 ? spots[i] = s : spots.add(s);
    await _save('spots', spots);
  }

  Future<void> deleteSpot(String id) async {
    spots.removeWhere((s) => s.id == id);
    for (final c in catches.where((c) => c.spotId == id)) {
      c.spotId = null;
    }
    await _save('spots', spots);
    await _save('catches', catches);
  }

  // ---------- Folderul „permise” ----------
  List<PermitFile> filesForSeason(String seasonId) =>
      permitFiles.where((f) => f.seasonId == seasonId).toList()
        ..sort((a, b) => a.fileName.compareTo(b.fileName));

  Future<String> _docsDir() async =>
      (await getApplicationDocumentsDirectory()).path;

  /// Salvează fișierul în `permise/<an>-<sezon>/<nume>`.
  Future<PermitFile> addPermitFile({
    required Season season,
    required String fileName,
    required Uint8List bytes,
    String? taskKey,
  }) async {
    final id = newId();
    var name = fileName;
    final existing = filesForSeason(season.id).map((f) => f.fileName).toSet();
    if (existing.contains(name)) {
      final dot = name.lastIndexOf('.');
      final base = dot > 0 ? name.substring(0, dot) : name;
      final ext = dot > 0 ? name.substring(dot) : '';
      var n = 2;
      while (existing.contains('${base}_$n$ext')) {
        n++;
      }
      name = '${base}_$n$ext';
    }
    final relative = 'permise/${season.folderName}/$name';
    if (kIsWeb) {
      await _box.put('file:$id', base64Encode(bytes));
    } else {
      final file = File('${await _docsDir()}/$relative');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes);
    }
    final pf = PermitFile(
      id: id,
      seasonId: season.id,
      fileName: name,
      relativePath: relative,
      addedAt: DateTime.now(),
      taskKey: taskKey,
    );
    permitFiles.add(pf);
    await _save('permitFiles', permitFiles);
    return pf;
  }

  Future<String?> permitFilePath(PermitFile f) async =>
      kIsWeb ? null : '${await _docsDir()}/${f.relativePath}';

  Future<Uint8List?> permitFileBytes(PermitFile f) async {
    if (kIsWeb) {
      final b64 = _box.get('file:${f.id}') as String?;
      return b64 == null ? null : base64Decode(b64);
    }
    final file = File((await permitFilePath(f))!);
    return await file.exists() ? file.readAsBytes() : null;
  }

  Future<void> deletePermitFile(PermitFile f) async {
    if (kIsWeb) {
      await _box.delete('file:${f.id}');
    } else {
      final file = File((await permitFilePath(f))!);
      if (await file.exists()) await file.delete();
    }
    permitFiles.removeWhere((e) => e.id == f.id);
    await _save('permitFiles', permitFiles);
  }
}
