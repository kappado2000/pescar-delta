import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/boat.dart';
import '../models/doc_copy.dart';
import '../widgets/documents_editor.dart';

class BoatsScreen extends StatelessWidget {
  const BoatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    return Scaffold(
      appBar: AppBar(title: const Text('Bărci')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, null),
        icon: const Icon(Icons.add),
        label: const Text('Barcă'),
      ),
      body: store.boats.isEmpty
          ? const Center(child: Text('Nicio barcă încă.'))
          : ListView(
              children: [
                for (final b in store.boats)
                  ListTile(
                    leading: const Icon(Icons.directions_boat),
                    title: Text(b.denumire),
                    subtitle: Text(
                      [
                        b.tip,
                        if (b.nrInmatriculare.isNotEmpty) b.nrInmatriculare,
                        if (b.capacitateMotor.isNotEmpty) b.capacitateMotor,
                        'proprietar: ${store.participant(b.ownerId)?.fullName ?? '—'}',
                      ].join(' · '),
                    ),
                    onTap: () => _edit(context, b),
                  ),
              ],
            ),
    );
  }

  void _edit(BuildContext context, Boat? b) => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => BoatEditScreen(boat: b)),
  );
}

class BoatEditScreen extends StatefulWidget {
  const BoatEditScreen({super.key, this.boat});
  final Boat? boat;

  @override
  State<BoatEditScreen> createState() => _BoatEditScreenState();
}

class _BoatEditScreenState extends State<BoatEditScreen> {
  final _form = GlobalKey<FormState>();
  late final Boat _b = widget.boat ?? Boat(id: newId(), denumire: '');
  late final _denumire = TextEditingController(text: _b.denumire);
  late final _nr = TextEditingController(text: _b.nrInmatriculare);
  late final _motor = TextEditingController(text: _b.capacitateMotor);
  late final _port = TextEditingController(text: _b.port);
  late String _tip = _b.tip;
  late String? _ownerId = _b.ownerId;
  late bool _gratuit = _b.gratuit;
  late final _marca = TextEditingController(text: _b.marcaMotor);
  late final _serie = TextEditingController(text: _b.serieMotor);
  late final _lungime = TextEditingController(text: _b.lungime);
  late final _notes = TextEditingController(text: _b.notes);
  late final List<DocCopy> _docs = List.of(_b.documents);

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final isNew = widget.boat == null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isNew ? 'Barcă nouă' : 'Editare barcă'),
        actions: [
          if (!isNew)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                await store.deleteBoat(_b.id);
                if (context.mounted) Navigator.pop(context);
              },
            ),
        ],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _field(_denumire, 'Denumire ambarcațiune', required: true),
            _field(_nr, 'Număr înmatriculare'),
            _field(_lungime, 'Lungime (m)'),
            Text('Motorizare', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            _field(_motor, 'Capacitate motor (ex. 25 CP)'),
            _field(_marca, 'Marcă / model motor (ex. Yamaha F25)'),
            _field(_serie, 'Serie motor'),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DropdownButtonFormField<String>(
                initialValue: _tip,
                decoration: const InputDecoration(
                  labelText: 'Tip ambarcațiune',
                ),
                items: [
                  for (final t in boatTypes)
                    DropdownMenuItem(value: t, child: Text(t)),
                ],
                onChanged: (v) => setState(() => _tip = v!),
              ),
            ),
            _field(_port, 'Port înmatriculare'),
            DropdownButtonFormField<String?>(
              initialValue: store.participant(_ownerId) == null
                  ? null
                  : _ownerId,
              decoration: const InputDecoration(
                labelText: 'Pe numele cui se face permisul',
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('—')),
                for (final p in store.participants)
                  DropdownMenuItem(value: p.id, child: Text(p.fullName)),
              ],
              onChanged: (v) => setState(() => _ownerId = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _gratuit,
              onChanged: (v) => setState(() => _gratuit = v),
              title: const Text('Permis gratuit'),
              subtitle: const Text(
                'Doar pentru rezidenții din rezervație / localitățile limitrofe',
              ),
            ),
            DocumentsEditor(
              docs: _docs,
              presets: const [
                'Certificat înmatriculare',
                'Carte de identitate barcă',
                'Permis conducere ambarcațiune',
                'Asigurare',
                'Alt act',
              ],
              title: 'Copii acte barcă',
            ),
            const SizedBox(height: 12),
            _field(_notes, 'Notițe'),
            FilledButton.icon(
              onPressed: () async {
                if (!_form.currentState!.validate()) return;
                _b
                  ..denumire = _denumire.text.trim()
                  ..nrInmatriculare = _nr.text.trim()
                  ..capacitateMotor = _motor.text.trim()
                  ..port = _port.text.trim()
                  ..tip = _tip
                  ..ownerId = _ownerId
                  ..gratuit = _gratuit
                  ..marcaMotor = _marca.text.trim()
                  ..serieMotor = _serie.text.trim()
                  ..lungime = _lungime.text.trim()
                  ..notes = _notes.text.trim()
                  ..documents = _docs;
                await store.upsertBoat(_b);
                if (context.mounted) Navigator.pop(context);
              },
              icon: const Icon(Icons.save),
              label: const Text('Salvează'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController c,
    String label, {
    bool required = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        decoration: InputDecoration(labelText: label),
        validator: required
            ? (v) => (v?.trim().isEmpty ?? true) ? 'Obligatoriu' : null
            : null,
      ),
    );
  }
}
