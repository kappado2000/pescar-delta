import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/catch_entry.dart';
import '../services/location_service.dart';
import '../services/weather_service.dart';

final _dateTime = DateFormat('d MMM yyyy, HH:mm');

class CatchesScreen extends StatefulWidget {
  const CatchesScreen({super.key});

  @override
  State<CatchesScreen> createState() => _CatchesScreenState();
}

class _CatchesScreenState extends State<CatchesScreen> {
  String? _species;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final species = store.catches.map((c) => c.species).toSet().toList()
      ..sort();
    final list = store.catches
        .where((c) => _species == null || c.species == _species)
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Jurnal de capturi')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => openCatchEditor(context),
        icon: const Icon(Icons.add_a_photo_outlined),
        label: const Text('Captură'),
      ),
      body: Column(
        children: [
          if (species.length > 1)
            SizedBox(
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                children: [
                  ChoiceChip(
                    label: const Text('Toate'),
                    selected: _species == null,
                    onSelected: (_) => setState(() => _species = null),
                  ),
                  for (final s in species)
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: ChoiceChip(
                        label: Text(s),
                        selected: _species == s,
                        onSelected: (_) => setState(() => _species = s),
                      ),
                    ),
                ],
              ),
            ),
          Expanded(
            child: list.isEmpty
                ? const Center(
                    child: Text('Nicio captură încă. Fir întins! 🎣'),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 96),
                    itemCount: list.length,
                    itemBuilder: (_, i) => _CatchCard(entry: list[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _CatchCard extends StatelessWidget {
  const _CatchCard({required this.entry});
  final CatchEntry entry;

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    final c = entry;
    final spot = store.spot(c.spotId);
    final details = [
      if (c.weightKg != null) '${_num(c.weightKg!)} kg',
      if (c.lengthCm != null) '${_num(c.lengthCm!)} cm',
      if (c.bait.isNotEmpty) c.bait,
      if (c.method.isNotEmpty) c.method,
    ].join(' · ');
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openCatchEditor(context, entry: c),
        child: Row(
          children: [
            SizedBox(
              width: 92,
              height: 92,
              child: c.photoBase64 != null
                  ? Image.memory(
                      base64Decode(c.photoBase64!),
                      fit: BoxFit.cover,
                    )
                  : Container(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      child: const Icon(Icons.set_meal, size: 36),
                    ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            c.species,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        if (c.released)
                          const Tooltip(
                            message: 'Eliberat',
                            child: Icon(Icons.water, size: 18),
                          ),
                      ],
                    ),
                    if (details.isNotEmpty) Text(details),
                    Text(
                      '${_dateTime.format(c.date)}${spot != null ? ' · ${spot.name}' : ''}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _num(double v) => v == v.roundToDouble()
    ? v.toStringAsFixed(0)
    : v.toStringAsFixed(2).replaceAll(RegExp(r'0$'), '');

Future<void> openCatchEditor(
  BuildContext context, {
  CatchEntry? entry,
  double? lat,
  double? lng,
  String? spotId,
}) => Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) =>
        CatchEditScreen(entry: entry, lat: lat, lng: lng, spotId: spotId),
  ),
);

class CatchEditScreen extends StatefulWidget {
  const CatchEditScreen({
    super.key,
    this.entry,
    this.lat,
    this.lng,
    this.spotId,
  });
  final CatchEntry? entry;
  final double? lat;
  final double? lng;
  final String? spotId;

  @override
  State<CatchEditScreen> createState() => _CatchEditScreenState();
}

class _CatchEditScreenState extends State<CatchEditScreen> {
  late final CatchEntry _c =
      widget.entry ??
      CatchEntry(
        id: newId(),
        date: DateTime.now(),
        species: 'Crap',
        lat: widget.lat,
        lng: widget.lng,
        spotId: widget.spotId,
      );
  late String _species = _c.species;
  late final _otherSpecies = TextEditingController(
    text: commonSpecies.contains(_c.species) ? '' : _c.species,
  );
  late final _weight = TextEditingController(
    text: _c.weightKg == null ? '' : _num(_c.weightKg!),
  );
  late final _length = TextEditingController(
    text: _c.lengthCm == null ? '' : _num(_c.lengthCm!),
  );
  late final _bait = TextEditingController(text: _c.bait);

  /// Controller-ul creat de Autocomplete pentru câmpul de momeală.
  TextEditingController? _baitField;
  late final _notes = TextEditingController(text: _c.notes);
  late String _method = _c.method;
  late DateTime _date = _c.date;
  late String? _spotId = _c.spotId;
  late String? _participantId = _c.participantId;
  late double? _lat = _c.lat;
  late double? _lng = _c.lng;
  late String? _photo = _c.photoBase64;
  late bool _released = _c.released;
  bool _locating = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (!commonSpecies.contains(_species)) _species = 'Altă specie';
    if (widget.entry == null && _lat == null && _spotId == null) _locate();
  }

  Future<void> _locate() async {
    setState(() => _locating = true);
    final pos = await LocationService.current();
    if (!mounted) return;
    setState(() {
      _locating = false;
      if (pos != null) {
        _lat = pos.latitude;
        _lng = pos.longitude;
      }
    });
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final x = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1280,
      imageQuality: 70,
    );
    if (x == null) return;
    final bytes = await x.readAsBytes();
    setState(() => _photo = base64Encode(bytes));
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final isNew = widget.entry == null;
    final baits = store.catches
        .map((c) => c.bait)
        .where((b) => b.isNotEmpty)
        .toSet();
    return Scaffold(
      appBar: AppBar(
        title: Text(isNew ? 'Captură nouă' : 'Captură'),
        actions: [
          if (!isNew)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                await store.deleteCatch(_c.id);
                if (context.mounted) Navigator.pop(context);
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ---------- Poză ----------
          AspectRatio(
            aspectRatio: 16 / 10,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _photo != null
                  ? Image.memory(base64Decode(_photo!), fit: BoxFit.cover)
                  : Container(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      child: const Center(
                        child: Icon(Icons.photo_camera, size: 48),
                      ),
                    ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.photo_camera),
                label: const Text('Cameră'),
                onPressed: () => _pickPhoto(ImageSource.camera),
              ),
              TextButton.icon(
                icon: const Icon(Icons.photo_library),
                label: const Text('Galerie'),
                onPressed: () => _pickPhoto(ImageSource.gallery),
              ),
              if (_photo != null)
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _photo = null),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // ---------- Specie ----------
          DropdownButtonFormField<String>(
            initialValue: _species,
            decoration: const InputDecoration(labelText: 'Specie'),
            items: [
              for (final s in commonSpecies)
                DropdownMenuItem(value: s, child: Text(s)),
            ],
            onChanged: (v) => setState(() => _species = v!),
          ),
          if (_species == 'Altă specie') ...[
            const SizedBox(height: 12),
            TextField(
              controller: _otherSpecies,
              decoration: const InputDecoration(labelText: 'Care specie?'),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _weight,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Greutate (kg)'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _length,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Lungime (cm)'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Autocomplete<String>(
            initialValue: TextEditingValue(text: _bait.text),
            optionsBuilder: (v) => baits.where(
              (b) => b.toLowerCase().contains(v.text.toLowerCase()),
            ),
            fieldViewBuilder: (context, controller, focus, onSubmit) {
              _baitField = controller;
              return TextField(
                controller: controller,
                focusNode: focus,
                decoration: const InputDecoration(
                  labelText: 'Momeală / nadă / năluca',
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: fishingMethods.contains(_method) ? _method : null,
            decoration: const InputDecoration(labelText: 'Metodă'),
            items: [
              for (final m in fishingMethods)
                DropdownMenuItem(value: m, child: Text(m)),
            ],
            onChanged: (v) => setState(() => _method = v ?? ''),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            initialValue: store.participant(_participantId) == null
                ? null
                : _participantId,
            decoration: const InputDecoration(labelText: 'Cine a prins'),
            items: [
              const DropdownMenuItem(value: null, child: Text('—')),
              for (final p in store.participants)
                DropdownMenuItem(value: p.id, child: Text(p.fullName)),
            ],
            onChanged: (v) => setState(() => _participantId = v),
          ),
          const SizedBox(height: 12),

          // ---------- Loc ----------
          DropdownButtonFormField<String?>(
            initialValue: store.spot(_spotId) == null ? null : _spotId,
            decoration: const InputDecoration(labelText: 'Loc / baltă'),
            items: [
              const DropdownMenuItem(value: null, child: Text('— (doar GPS)')),
              for (final s in store.spots)
                DropdownMenuItem(value: s.id, child: Text(s.name)),
            ],
            onChanged: (v) => setState(() {
              _spotId = v;
              final s = store.spot(v);
              if (s != null) {
                _lat = s.lat;
                _lng = s.lng;
              }
            }),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.my_location),
            title: Text(
              _lat == null
                  ? (_locating ? 'Caut poziția GPS…' : 'Fără coordonate')
                  : '${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)}',
            ),
            trailing: IconButton(
              icon: const Icon(Icons.gps_fixed),
              onPressed: _locating ? null : _locate,
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.schedule),
            title: Text(_dateTime.format(_date)),
            onTap: _pickDate,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _released,
            onChanged: (v) => setState(() => _released = v),
            title: const Text('Eliberat (catch & release)'),
          ),
          if (_c.weather != null) _WeatherInfo(w: _c.weather!),
          TextField(
            controller: _notes,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Notițe'),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            label: const Text('Salvează'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_date),
    );
    setState(() {
      _date = DateTime(
        d.year,
        d.month,
        d.day,
        t?.hour ?? _date.hour,
        t?.minute ?? _date.minute,
      );
    });
  }

  double? _parse(String s) => double.tryParse(s.trim().replaceAll(',', '.'));

  Future<void> _save() async {
    setState(() => _saving = true);
    final store = context.read<AppStore>();
    final species =
        _species == 'Altă specie' && _otherSpecies.text.trim().isNotEmpty
        ? _otherSpecies.text.trim()
        : _species;
    // Vremea se salvează doar pentru capturile proaspete (din ultimele 3 ore).
    final fresh = DateTime.now().difference(_date).inHours < 3;
    if (_c.weather == null && fresh && _lat != null) {
      _c.weather = await WeatherService.snapshot(_lat!, _lng!);
    }
    _c
      ..species = species
      ..weightKg = _parse(_weight.text)
      ..lengthCm = _parse(_length.text)
      ..bait = (_baitField?.text ?? _bait.text).trim()
      ..method = _method
      ..date = _date
      ..spotId = _spotId
      ..participantId = _participantId
      ..lat = _lat
      ..lng = _lng
      ..photoBase64 = _photo
      ..released = _released
      ..notes = _notes.text.trim();
    await store.upsertCatch(_c);
    if (mounted) Navigator.pop(context);
  }
}

class _WeatherInfo extends StatelessWidget {
  const _WeatherInfo({required this.w});
  final WeatherSnapshot w;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.thermostat),
        title: const Text('Vremea la captură'),
        subtitle: Text(
          [
            if (w.tempC != null) '${w.tempC!.toStringAsFixed(1)} °C',
            if (w.pressureHpa != null)
              '${w.pressureHpa!.toStringAsFixed(0)} hPa',
            if (w.windKmh != null)
              'vânt ${w.windKmh!.toStringAsFixed(0)} km/h ${w.windDir != null ? windDirName(w.windDir!) : ''}',
          ].join(' · '),
        ),
      ),
    );
  }
}
