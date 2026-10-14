import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models/place.dart';

/// Alegerea locației sezonului: localitățile din Deltă sau căutare după nume.
Future<Place?> pickPlace(BuildContext context, {Place? current}) {
  return showModalBottomSheet<Place>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _PlacePicker(current: current),
  );
}

class _PlacePicker extends StatefulWidget {
  const _PlacePicker({this.current});
  final Place? current;

  @override
  State<_PlacePicker> createState() => _PlacePickerState();
}

class _PlacePickerState extends State<_PlacePicker> {
  final _query = TextEditingController();
  List<(Place, String)>? _results;
  bool _searching = false;
  String? _error;

  Future<void> _search() async {
    final q = _query.text.trim();
    if (q.length < 2) return;
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final uri = Uri.https('geocoding-api.open-meteo.com', '/v1/search', {
        'name': q,
        'count': '15',
        'language': 'ro',
        'countryCode': 'RO',
      });
      final res = await http.get(uri).timeout(const Duration(seconds: 15));
      final list = (jsonDecode(res.body)['results'] as List?) ?? [];
      final results = [
        for (final r in list)
          (
            Place(
              r['name'],
              (r['latitude'] as num).toDouble(),
              (r['longitude'] as num).toDouble(),
            ),
            (r['admin1'] as String?) ?? '',
          ),
      ];
      // județul Tulcea primul
      results.sort(
        (a, b) => (b.$2.contains('Tulcea') ? 1 : 0).compareTo(
          a.$2.contains('Tulcea') ? 1 : 0,
        ),
      );
      setState(() => _results = results);
    } catch (e) {
      setState(() => _error = 'Căutarea a eșuat (ai internet?)');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Locația sezonului', style: text.titleLarge),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final p in deltaPlaces)
                ChoiceChip(
                  label: Text(p.name),
                  selected: widget.current?.key == p.key,
                  onSelected: (_) => Navigator.pop(context, p),
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _query,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(),
            decoration: InputDecoration(
              labelText: 'Altă localitate',
              suffixIcon: _searching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: _search,
                    ),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          if (_results != null)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260),
              child: _results!.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('Nicio localitate găsită.'),
                    )
                  : ListView(
                      shrinkWrap: true,
                      children: [
                        for (final (p, county) in _results!)
                          ListTile(
                            leading: const Icon(Icons.place_outlined),
                            title: Text(p.name),
                            subtitle: Text(county),
                            onTap: () => Navigator.pop(context, p),
                          ),
                      ],
                    ),
            ),
        ],
      ),
    );
  }
}
