import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/app_store.dart';
import '../models/doc_copy.dart';
import '../models/participant.dart';
import '../widgets/documents_editor.dart';

class ParticipantsScreen extends StatelessWidget {
  const ParticipantsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    return Scaffold(
      appBar: AppBar(title: const Text('Participanți')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, null),
        icon: const Icon(Icons.person_add),
        label: const Text('Participant'),
      ),
      body: store.participants.isEmpty
          ? const Center(child: Text('Niciun participant încă.'))
          : ListView(
              padding: const EdgeInsets.only(bottom: 88),
              children: [
                for (final p in store.participants)
                  ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.person_outline),
                    ),
                    title: Text(p.fullName),
                    subtitle: Text(_subtitle(p)),
                    trailing: p.missingFields(needsCnp: true).isEmpty
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : const Icon(Icons.error_outline, color: Colors.orange),
                    onTap: () => _edit(context, p),
                  ),
              ],
            ),
    );
  }

  String _subtitle(Participant p) {
    final missing = p.missingFields(needsCnp: true);
    return [
      p.category.label,
      if (p.documents.isNotEmpty) '${p.documents.length} copii acte',
      if (p.ciExpired) 'CI EXPIRAT',
      if (missing.isNotEmpty) 'lipsește: ${missing.join(', ')}',
    ].join(' · ');
  }

  void _edit(BuildContext context, Participant? p) => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => ParticipantEditScreen(participant: p)),
  );
}

class ParticipantEditScreen extends StatefulWidget {
  const ParticipantEditScreen({super.key, this.participant});
  final Participant? participant;

  @override
  State<ParticipantEditScreen> createState() => _ParticipantEditScreenState();
}

class _ParticipantEditScreenState extends State<ParticipantEditScreen> {
  final _form = GlobalKey<FormState>();
  late final Participant _p =
      widget.participant ?? Participant(id: newId(), nume: '', prenume: '');
  late final _nume = TextEditingController(text: _p.nume);
  late final _prenume = TextEditingController(text: _p.prenume);
  late final _cnp = TextEditingController(text: _p.cnp);
  late final _email = TextEditingController(text: _p.email);
  late final _telefon = TextEditingController(text: _p.telefon);
  late final _judet = TextEditingController(text: _p.judet);
  late final _tara = TextEditingController(text: _p.tara);
  late final _notes = TextEditingController(text: _p.notes);
  late ParticipantCategory _category = _p.category;
  late final _ciSerie = TextEditingController(text: _p.ciSerie);
  late final _ciNumar = TextEditingController(text: _p.ciNumar);
  late final _pensieDoc = TextEditingController(text: _p.pensieDoc);
  late DateTime? _ciExpira = _p.ciExpira;
  late final List<DocCopy> _docs = List.of(_p.documents);

  static const _docPresets = [
    'CI față',
    'CI verso',
    'Cupon pensie',
    'Decizie pensie',
    'Legitimație elev / student',
    'Certificat handicap',
    'Alt act',
  ];

  @override
  Widget build(BuildContext context) {
    final isNew = widget.participant == null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isNew ? 'Participant nou' : 'Editare participant'),
        actions: [
          if (!isNew)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _field(_nume, 'Nume (de familie)', required: true),
            _field(_prenume, 'Prenume', required: true),
            DropdownButtonFormField<ParticipantCategory>(
              initialValue: _category,
              decoration: const InputDecoration(
                labelText: 'Calitate (pentru gratuitate)',
              ),
              items: [
                for (final c in ParticipantCategory.values)
                  DropdownMenuItem(value: c, child: Text(c.label)),
              ],
              onChanged: (c) => setState(() => _category = c!),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 4, 12),
              child: Text(
                _category.freeAccess
                    ? 'Permisul de acces turist va fi cel GRATUIT.'
                    : 'Permisul de acces turist se plătește.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            _field(
              _cnp,
              'CNP (necesar la permisul de pescuit)',
              keyboard: TextInputType.number,
              validator: (v) {
                final s = v?.trim() ?? '';
                if (s.isEmpty) return null;
                return RegExp(r'^\d{13}$').hasMatch(s)
                    ? null
                    : 'CNP-ul are 13 cifre';
              },
            ),
            if (_category == ParticipantCategory.pensionar)
              _field(_pensieDoc, 'Nr. decizie / cupon de pensie'),
            const Divider(height: 24),
            Text(
              'Act de identitate',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                SizedBox(width: 90, child: _field(_ciSerie, 'Serie')),
                const SizedBox(width: 12),
                Expanded(
                  child: _field(
                    _ciNumar,
                    'Număr',
                    keyboard: TextInputType.number,
                  ),
                ),
              ],
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.event,
                color: _ciExpira != null && _ciExpira!.isBefore(DateTime.now())
                    ? Colors.red
                    : null,
              ),
              title: Text(
                _ciExpira == null
                    ? 'Valabil până la — (apasă să alegi)'
                    : 'Valabil până la ${DateFormat('d MMMM yyyy').format(_ciExpira!)}'
                          '${_ciExpira!.isBefore(DateTime.now()) ? ' — EXPIRAT' : ''}',
              ),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _ciExpira ?? DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (d != null) setState(() => _ciExpira = d);
              },
            ),
            DocumentsEditor(
              docs: _docs,
              presets: _docPresets,
              title: 'Copii acte (CI, cupon pensie…)',
            ),
            const Divider(height: 24),
            _field(_email, 'Email', keyboard: TextInputType.emailAddress),
            _field(_telefon, 'Telefon', keyboard: TextInputType.phone),
            _field(_judet, 'Județ'),
            _field(_tara, 'Țară'),
            _field(_notes, 'Notițe', maxLines: 3),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _save,
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
    TextInputType? keyboard,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        keyboardType: keyboard,
        maxLines: maxLines,
        textCapitalization: keyboard == null
            ? TextCapitalization.words
            : TextCapitalization.none,
        decoration: InputDecoration(labelText: label),
        validator:
            validator ??
            (required
                ? (v) => (v?.trim().isEmpty ?? true) ? 'Obligatoriu' : null
                : null),
      ),
    );
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    _p
      ..nume = _nume.text.trim()
      ..prenume = _prenume.text.trim()
      ..cnp = _cnp.text.trim()
      ..email = _email.text.trim()
      ..telefon = _telefon.text.trim()
      ..judet = _judet.text.trim()
      ..tara = _tara.text.trim().isEmpty ? 'Romania' : _tara.text.trim()
      ..category = _category
      ..ciSerie = _ciSerie.text.trim().toUpperCase()
      ..ciNumar = _ciNumar.text.trim()
      ..ciExpira = _ciExpira
      ..pensieDoc = _pensieDoc.text.trim()
      ..documents = _docs
      ..notes = _notes.text.trim();
    await context.read<AppStore>().upsertParticipant(_p);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Ștergi participantul?'),
        content: Text('${_p.fullName} va fi scos și din toate sezoanele.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Anulează'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Șterge'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await context.read<AppStore>().deleteParticipant(_p.id);
    if (mounted) Navigator.pop(context);
  }
}
