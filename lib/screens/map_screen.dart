import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import 'home_shell.dart';
import '../models/catch_entry.dart';
import '../models/spot.dart';
import '../services/location_service.dart';
import 'catches_screen.dart';
import 'weather_screen.dart';
import '../widgets/delta_scene.dart';

/// Centrul Deltei Dunării.
const _deltaCenter = LatLng(45.10, 29.20);

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _map = MapController();
  bool _showCatches = true;
  LatLng? _me;
  bool _locating = false;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: SceneAppBar(
        title: 'Hartă',
        subtitle: '${store.spots.length} locuri salvate',
        height: 104,
        actions: [
          IconButton(
            tooltip: _showCatches ? 'Ascunde capturile' : 'Arată capturile',
            icon: Icon(_showCatches ? Icons.set_meal : Icons.set_meal_outlined),
            onPressed: () => setState(() => _showCatches = !_showCatches),
          ),
          IconButton(
            tooltip: 'Lista locurilor',
            icon: const Icon(Icons.list),
            onPressed: () => _spotList(context, store),
          ),
        ],
      ),
      floatingActionButton: aboveBanner(
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            FloatingActionButton.small(
              heroTag: 'me',
              tooltip: 'Poziția mea',
              onPressed: _goToMe,
              child: const Icon(Icons.my_location),
            ),
            const SizedBox(height: 12),
            FloatingActionButton.extended(
              heroTag: 'mark',
              onPressed: _locating ? null : _markHere,
              icon: _locating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_location_alt),
              label: const Text('Marchează locul'),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: _deltaCenter,
              initialZoom: 9,
              onLongPress: (_, p) => _editSpot(context, null, p),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'ro.kappa.pescar_delta',
              ),
              MarkerLayer(
                markers: [
                  if (_showCatches)
                    for (final c in store.catches.where((c) => c.hasLocation))
                      Marker(
                        point: LatLng(c.lat!, c.lng!),
                        width: 28,
                        height: 28,
                        child: GestureDetector(
                          onTap: () => _catchSheet(context, c),
                          child: CircleAvatar(
                            backgroundColor: scheme.tertiary,
                            child: Icon(
                              Icons.set_meal,
                              size: 16,
                              color: scheme.onTertiary,
                            ),
                          ),
                        ),
                      ),
                  for (final s in store.spots)
                    Marker(
                      point: LatLng(s.lat, s.lng),
                      width: 44,
                      height: 44,
                      alignment: Alignment.topCenter,
                      child: GestureDetector(
                        onTap: () => _spotSheet(context, s),
                        child: Icon(
                          Icons.location_on,
                          size: 44,
                          color: scheme.primary,
                        ),
                      ),
                    ),
                  if (_me != null)
                    Marker(
                      point: _me!,
                      width: 20,
                      height: 20,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                      ),
                    ),
                ],
              ),
              const RichAttributionWidget(
                attributions: [TextSourceAttribution('© OpenStreetMap')],
              ),
            ],
          ),
          Positioned(
            top: 8,
            left: 8,
            right: 8,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Text(
                  '„Marchează locul” salvează poziția GPS a telefonului. '
                  'Sau ține apăsat pe hartă.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<LatLng?> _gps() async {
    setState(() => _locating = true);
    final pos = await LocationService.current();
    if (!mounted) return null;
    setState(() => _locating = false);
    if (pos == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nu am acces la GPS — pornește locația telefonului.'),
        ),
      );
      return null;
    }
    setState(() => _me = LatLng(pos.latitude, pos.longitude));
    return _me;
  }

  Future<void> _goToMe() async {
    final p = await _gps();
    if (p != null) _map.move(p, 14);
  }

  /// Salvează locul unde stă telefonul acum. Dacă există deja un loc salvat
  /// la mai puțin de 50 m, îl propune pe acela.
  Future<void> _markHere() async {
    final p = await _gps();
    if (p == null || !mounted) return;
    _map.move(p, 15);
    final store = context.read<AppStore>();
    const distance = Distance();
    final near = store.spots
        .where((s) => distance(p, LatLng(s.lat, s.lng)) < 50)
        .firstOrNull;
    if (near != null) {
      _spotSheet(context, near);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ești la „${near.name}” (loc deja salvat).')),
      );
      return;
    }
    await _editSpot(
      context,
      null,
      p,
      suggestedName: 'Loc ${DateFormat('d MMM, HH:mm').format(DateTime.now())}',
    );
  }

  void _spotList(BuildContext context, AppStore store) {
    showModalBottomSheet(
      useRootNavigator: true,
      context: context,
      builder: (c) => store.spots.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Niciun loc salvat. Ține apăsat pe hartă.'),
            )
          : ListView(
              shrinkWrap: true,
              children: [
                for (final s in store.spots)
                  ListTile(
                    leading: const Icon(Icons.location_on),
                    title: Text(s.name),
                    subtitle: Text(
                      '${store.catches.where((x) => x.spotId == s.id).length} capturi',
                    ),
                    onTap: () {
                      Navigator.pop(c);
                      _map.move(LatLng(s.lat, s.lng), 14);
                    },
                  ),
              ],
            ),
    );
  }

  void _spotSheet(BuildContext context, Spot s) {
    final store = context.read<AppStore>();
    final catches = store.catches.where((c) => c.spotId == s.id).toList();
    final bySpecies = <String, int>{};
    for (final c in catches) {
      bySpecies[c.species] = (bySpecies[c.species] ?? 0) + 1;
    }
    showModalBottomSheet(
      useRootNavigator: true,
      context: context,
      builder: (c) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.name, style: Theme.of(c).textTheme.titleLarge),
            if (s.depthM != null) Text('Adâncime: ${s.depthM} m'),
            if (s.notes.isNotEmpty) Text(s.notes),
            const SizedBox(height: 8),
            Text(
              catches.isEmpty
                  ? 'Nicio captură aici încă.'
                  : '${catches.length} capturi: ${bySpecies.entries.map((e) => '${e.key} ${e.value}').join(', ')}',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                FilledButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Captură aici'),
                  onPressed: () {
                    Navigator.pop(c);
                    openCatchEditor(
                      context,
                      lat: s.lat,
                      lng: s.lng,
                      spotId: s.id,
                    );
                  },
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.cloud_outlined),
                  label: const Text('Vremea'),
                  onPressed: () {
                    Navigator.pop(c);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => WeatherScreen(spotId: s.id),
                      ),
                    );
                  },
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.edit),
                  label: const Text('Editează'),
                  onPressed: () {
                    Navigator.pop(c);
                    _editSpot(context, s, LatLng(s.lat, s.lng));
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _catchSheet(BuildContext context, CatchEntry c) =>
      openCatchEditor(context, entry: c);

  Future<void> _editSpot(
    BuildContext context,
    Spot? spot,
    LatLng p, {
    String? suggestedName,
  }) async {
    final store = context.read<AppStore>();
    final name = TextEditingController(text: spot?.name ?? suggestedName ?? '');
    final notes = TextEditingController(text: spot?.notes ?? '');
    final depth = TextEditingController(text: spot?.depthM?.toString() ?? '');
    await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(spot == null ? 'Loc nou' : 'Editare loc'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Nume (ex. Lacul Roșu)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: depth,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Adâncime (m)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notes,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Notițe'),
            ),
          ],
        ),
        actions: [
          if (spot != null)
            TextButton(
              onPressed: () async {
                await store.deleteSpot(spot.id);
                if (c.mounted) Navigator.pop(c);
              },
              child: const Text('Șterge'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Anulează'),
          ),
          FilledButton(
            onPressed: () async {
              if (name.text.trim().isEmpty) return;
              final s =
                  spot ??
                  Spot(
                    id: newId(),
                    name: '',
                    lat: p.latitude,
                    lng: p.longitude,
                  );
              s
                ..name = name.text.trim()
                ..notes = notes.text.trim()
                ..depthM = double.tryParse(depth.text.replaceAll(',', '.'));
              await store.upsertSpot(s);
              if (c.mounted) Navigator.pop(c);
            },
            child: const Text('Salvează'),
          ),
        ],
      ),
    );
  }
}
