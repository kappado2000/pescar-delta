import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/boat.dart';
import '../models/catch_entry.dart';
import '../models/expense.dart';
import '../models/need_item.dart';
import '../models/participant.dart';
import '../models/permit_file.dart';
import '../models/season.dart';
import '../models/spot.dart';
import '../models/weather_day.dart';
import '../services/weather_collector.dart';

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
  final List<ExpensePreset> expensePresets = [];

  /// Categoriile paginii „Necesar” (comune tuturor sezoanelor).
  final List<NeedCategory> needCategories = [];

  /// Vremea zilnică colectată: locație (`Place.key`) → zi (`yyyy-MM-dd`).
  final Map<String, Map<String, WeatherDay>> weatherLog = {};
  bool collectingWeather = false;

  /// Tema aleasă din aplicație (implicit după sistem).
  ThemeMode get themeMode => switch (_box.get('themeMode')) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  Future<void> setThemeMode(ThemeMode m) async {
    await _box.put('themeMode', m.name);
    notifyListeners();
  }

  /// Ultimul participant care a plătit (implicit la cheltuiala rapidă).
  String? get lastPayerId => _box.get('lastPayerId') as String?;
  set lastPayerId(String? id) => _box.put('lastPayerId', id);

  /// Ultimul pescar care a prins (implicit la o captură nouă).
  String? get lastCatcherId => _box.get('lastCatcherId') as String?;
  set lastCatcherId(String? id) => _box.put('lastCatcherId', id);

  /// Pescarul implicit ales în Setări: primul în „Cine a prins” și ales
  /// din start la o captură nouă (null = ultimul care a prins).
  String? get defaultCatcherId => _box.get('defaultCatcherId') as String?;

  Future<void> setDefaultCatcher(String? id) async {
    await _box.put('defaultCatcherId', id);
    notifyListeners();
  }

  /// Plătitorul implicit ales în Setări (null = ultimul care a plătit).
  String? get defaultPayerId => _box.get('defaultPayerId') as String?;

  Future<void> setDefaultPayer(String? id) async {
    await _box.put('defaultPayerId', id);
    notifyListeners();
  }

  /// Cine apare ca plătitor la o cheltuială nouă în [season]: cel ales în
  /// Setări, altfel ultimul care a plătit, altfel primul din echipă.
  String payerFor(Season season) {
    final ids = season.participantIds;
    if (ids.contains(defaultPayerId)) return defaultPayerId!;
    if (ids.contains(lastPayerId)) return lastPayerId!;
    return ids.first;
  }

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
    _load('expensePresets', expensePresets, ExpensePreset.fromJson);
    // presetările nu mai au sumă: o scrii la fiecare cheltuială
    if (expensePresets.any((p) => p.amount != null)) {
      for (final p in expensePresets) {
        p.amount = null;
      }
      await _save('expensePresets', expensePresets);
    }
    _load('needCategories', needCategories, NeedCategory.fromJson);
    if (needCategories.isEmpty) {
      needCategories.addAll(NeedCategory.defaults());
      await _save('needCategories', needCategories);
    }
    final rawLog = _box.get('weatherLog') as String?;
    if (rawLog != null) {
      final decoded = jsonDecode(rawLog);
      if (decoded is Map) {
        decoded.forEach((place, days) {
          weatherLog[place] = {
            for (final e in days as List)
              WeatherDay.fromJson(Map<String, dynamic>.from(e))
                  .key: WeatherDay.fromJson(
                Map<String, dynamic>.from(e),
              ),
          };
        });
      }
    }
    await _seedOnce();
    await _seedPresetsOnce();
    // perioada sezoanelor urmează permisele (ex. 7 zile de la ziua de început)
    if (seasons.map((s) => s.syncPeriodWithPermits()).toList().any((c) => c)) {
      await _save('seasons', seasons);
    }
    collectWeather(); // în fundal; fără semnal pur și simplu nu adaugă nimic
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
        nume: 'Ionescu',
        prenume: 'Mihai Andrei',
        category: ParticipantCategory.pensionar,
      ),
    );
    await _save('participants', participants);
    await _box.put('seeded', true);
  }

  Future<void> _seedPresetsOnce() async {
    if (_box.get('presetsSeeded') == true) return;
    const defaults = [
      ('Benzină barcă', 'Combustibil'),
      ('Motorină mașină', 'Transport'),
      ('Mâncare', 'Mâncare-Băutură'),
      ('Băutură', 'Mâncare-Băutură'),
      ('Gheață', 'Mâncare-Băutură'),
      ('Momeli', 'Momeli'),
      ('Cazare', 'Cazare'),
      ('Permise', 'Permise'),
    ];
    for (final (name, category) in defaults) {
      expensePresets.add(
        ExpensePreset(id: newId(), name: name, category: category),
      );
    }
    await _save('expensePresets', expensePresets);
    await _box.put('presetsSeeded', true);
  }

  // ---------- Categorii „Necesar” ----------
  Future<NeedCategory> addNeedCategory(
    String label, {
    String doneLabel = 'bifat',
  }) async {
    final c = NeedCategory(id: newId(), label: label, doneLabel: doneLabel);
    needCategories.add(c);
    await _save('needCategories', needCategories);
    return c;
  }

  Future<void> updateNeedCategory(NeedCategory c) =>
      _save('needCategories', needCategories);

  Future<void> reorderNeedCategory(int from, int to) async {
    needCategories.insert(to, needCategories.removeAt(from));
    await _save('needCategories', needCategories);
  }

  /// Câte rânduri are categoria în toate sezoanele.
  int needItemsIn(NeedCategory c) => seasons.fold(
    0,
    (n, s) =>
        n + (s.needs[c.id]?.where((i) => i.text.trim().isNotEmpty).length ?? 0),
  );

  /// Șterge categoria și rândurile ei din toate sezoanele.
  Future<void> deleteNeedCategory(NeedCategory c) async {
    needCategories.removeWhere((x) => x.id == c.id);
    for (final s in seasons) {
      s.needs.remove(c.id);
    }
    await _save('needCategories', needCategories);
    await _save('seasons', seasons);
  }

  // ---------- Presetări cheltuieli ----------
  Future<void> upsertPreset(ExpensePreset p) async {
    final i = expensePresets.indexWhere((e) => e.id == p.id);
    i >= 0 ? expensePresets[i] = p : expensePresets.add(p);
    await _save('expensePresets', expensePresets);
  }

  Future<void> deletePreset(String id) async {
    expensePresets.removeWhere((p) => p.id == id);
    await _save('expensePresets', expensePresets);
  }

  /// Mută presetarea de pe poziția [from] pe poziția [to].
  Future<void> movePreset(int from, int to) async {
    if (from == to) return;
    expensePresets.insert(to, expensePresets.removeAt(from));
    await _save('expensePresets', expensePresets);
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

  /// Istoricul: toate sezoanele, grupate pe ani (cei mai recenți primii).
  Map<int, List<Season>> get seasonsByYear {
    final map = <int, List<Season>>{};
    for (final s in seasons) {
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
    collectWeather();
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

  // ---------- Vremea pe locația sezonului ----------
  /// Sezonul „de acum”: cel în desfășurare, altfel următorul, altfel ultimul.
  /// Problemele de remediat nebifate din sezoanele care au început înaintea
  /// lui [season] (fără cele scrise din nou în [season]).
  List<(Season, NeedItem)> openProblemsBefore(Season season) =>
      openProblems(seasons, needCategories, season);

  Season? get currentSeason {
    final now = DateTime.now();
    final inProgress = seasons.where((s) => s.contains(now)).firstOrNull;
    if (inProgress != null) return inProgress;
    final upcoming = seasons.where((s) => s.start.isAfter(now)).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    if (upcoming.isNotEmpty) return upcoming.first;
    final past = seasons.toList()..sort((a, b) => b.end.compareTo(a.end));
    return past.firstOrNull;
  }

  /// Vremea din ziua [d], în locația sezonului din care face parte ziua.
  WeatherDay? weatherOn(DateTime d) {
    final s = seasonForDate(d);
    return s == null ? null : weatherLog[s.place.key]?[WeatherDay.keyFor(d)];
  }

  /// Zilele colectate pentru un sezon (cele mai noi primele).
  List<WeatherDay> weatherForSeason(Season s) =>
      (weatherLog[s.place.key]?.values ?? const <WeatherDay>[])
          .where((d) => s.contains(d.date))
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));

  /// Completează golurile din jurnalul meteo pentru fiecare sezon: în
  /// locația lui, de la începutul sezonului până ieri (sau sfârșitul lui).
  /// Întoarce câte zile s-au adăugat.
  Future<int> collectWeather() async {
    if (collectingWeather) return 0;
    final now = DateTime.now();
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    collectingWeather = true;
    notifyListeners();
    var added = 0;
    try {
      for (final s in seasons.toList()) {
        final end = s.end.isBefore(yesterday) ? s.end : yesterday;
        final log = weatherLog.putIfAbsent(s.place.key, () => {});
        var first = DateTime(s.start.year, s.start.month, s.start.day);
        while (!first.isAfter(end) &&
            log.containsKey(WeatherDay.keyFor(first))) {
          first = DateTime(first.year, first.month, first.day + 1);
        }
        if (first.isAfter(end)) continue;
        try {
          final days = await WeatherCollector.fetchRange(s.place, first, end);
          for (final d in days) {
            if (!log.containsKey(d.key)) added++;
            log[d.key] = d;
          }
        } catch (_) {
          // fără semnal / eroare API: încercăm data viitoare
        }
      }
      if (added > 0) {
        await _box.put(
          'weatherLog',
          jsonEncode({
            for (final e in weatherLog.entries)
              e.key: e.value.values.map((d) => d.toJson()).toList(),
          }),
        );
      }
      return added;
    } finally {
      collectingWeather = false;
      notifyListeners();
    }
  }

  // ---------- Capturi ----------
  Future<void> upsertCatch(CatchEntry c) async {
    final i = catches.indexWhere((e) => e.id == c.id);
    i >= 0 ? catches[i] = c : catches.add(c);
    catches.sort((a, b) => b.date.compareTo(a.date));
    await _save('catches', catches);
  }

  /// Copiază un video în `media/<captură>/` și întoarce calea relativă.
  /// Pe web nu se pot păstra fișiere video → null.
  Future<String?> saveCatchVideo(
    String catchId,
    Uint8List bytes,
    String ext,
  ) async {
    if (kIsWeb) return null;
    final relative = 'media/$catchId/${newId()}$ext';
    final file = File('${await _docsDir()}/$relative');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes);
    return relative;
  }

  Future<String?> mediaFilePath(String? relative) async =>
      kIsWeb || relative == null ? null : '${await _docsDir()}/$relative';

  Future<void> deleteMediaFile(String? relative) async {
    final path = await mediaFilePath(relative);
    if (path == null) return;
    final f = File(path);
    if (await f.exists()) await f.delete();
  }

  Future<void> deleteCatch(String id) async {
    for (final m in catches.where((c) => c.id == id).expand((c) => c.media)) {
      await deleteMediaFile(m.path);
    }
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

  // ---------- Copie de siguranță (export / import) ----------
  /// Toate datele într-un singur obiect JSON (cu pozele și PDF-urile
  /// permiselor; fără video-uri, care rămân pe dispozitiv).
  Future<Map<String, dynamic>> exportData() async {
    List<Map<String, dynamic>> list(List items) => [
      for (final e in items) e.toJson() as Map<String, dynamic>,
    ];
    return {
      'app': 'pescar_delta',
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'participants': list(participants),
      'boats': list(boats),
      'seasons': list(seasons),
      'catches': [
        for (final c in catches)
          {
            ...c.toJson(),
            'media': [
              for (final m in c.media)
                if (!m.isVideo) m.toJson(),
            ],
          },
      ],
      'spots': list(spots),
      'expensePresets': list(expensePresets),
      'needCategories': list(needCategories),
      'weatherLog': {
        for (final e in weatherLog.entries)
          e.key: e.value.values.map((d) => d.toJson()).toList(),
      },
      'permitFiles': [
        for (final f in permitFiles)
          {
            ...f.toJson(),
            'data': switch (await permitFileBytes(f)) {
              final b? => base64Encode(b),
              null => null,
            },
          },
      ],
    };
  }

  /// Înlocuiește toate datele cu cele din [data] (un export).
  Future<void> importData(Map<String, dynamic> data) async {
    if (data['app'] != 'pescar_delta') {
      throw const FormatException('Fișierul nu e o copie Pescar Deltă.');
    }
    List<Map<String, dynamic>> maps(String key) => [
      for (final e in (data[key] as List? ?? [])) Map<String, dynamic>.from(e),
    ];
    for (final f in permitFiles.toList()) {
      await deletePermitFile(f);
    }
    participants
      ..clear()
      ..addAll(maps('participants').map(Participant.fromJson));
    boats
      ..clear()
      ..addAll(maps('boats').map(Boat.fromJson));
    seasons
      ..clear()
      ..addAll(maps('seasons').map(Season.fromJson));
    catches
      ..clear()
      ..addAll(maps('catches').map(CatchEntry.fromJson));
    spots
      ..clear()
      ..addAll(maps('spots').map(Spot.fromJson));
    expensePresets
      ..clear()
      ..addAll(maps('expensePresets').map(ExpensePreset.fromJson));
    final cats = maps('needCategories').map(NeedCategory.fromJson).toList();
    needCategories
      ..clear()
      ..addAll(cats.isEmpty ? NeedCategory.defaults() : cats);
    weatherLog.clear();
    ((data['weatherLog'] as Map?) ?? {}).forEach((place, days) {
      weatherLog[place as String] = {
        for (final d in days as List)
          WeatherDay.fromJson(Map<String, dynamic>.from(d))
              .key: WeatherDay.fromJson(
            Map<String, dynamic>.from(d),
          ),
      };
    });

    for (final key in [
      'participants',
      'boats',
      'seasons',
      'catches',
      'spots',
      'expensePresets',
      'needCategories',
    ]) {
      await _save(key, switch (key) {
        'participants' => participants,
        'boats' => boats,
        'seasons' => seasons,
        'catches' => catches,
        'spots' => spots,
        'expensePresets' => expensePresets,
        _ => needCategories,
      });
    }
    await _box.put(
      'weatherLog',
      jsonEncode({
        for (final e in weatherLog.entries)
          e.key: e.value.values.map((d) => d.toJson()).toList(),
      }),
    );
    // permisele (PDF) — rescrise în folderul „permise”
    permitFiles.clear();
    for (final f in maps('permitFiles')) {
      final b64 = f['data'] as String?;
      final meta = PermitFile.fromJson(f);
      if (b64 == null) continue;
      final bytes = base64Decode(b64);
      if (kIsWeb) {
        await _box.put('file:${meta.id}', b64);
      } else {
        final file = File('${await _docsDir()}/${meta.relativePath}');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes);
      }
      permitFiles.add(meta);
    }
    await _box.put('seeded', true);
    await _box.put('presetsSeeded', true);
    await _save('permitFiles', permitFiles);
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
