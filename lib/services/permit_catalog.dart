import 'dart:convert';

import 'package:intl/intl.dart';

import '../models/boat.dart';
import '../models/participant.dart';
import '../models/season.dart';

const ddbraBaseUrl = 'https://permise.ddbra.ro';

enum PermitKind {
  acces('Acces turist'),
  pescuit('Pescuit recreativ'),
  barca('Ambarcațiune');

  const PermitKind(this.label);
  final String label;
}

/// Un produs din magazinul permise.ddbra.ro (`comanda_rapida&currentId=`).
class DdbraProduct {
  const DdbraProduct(this.id, this.title, this.dateField);

  final int id;
  final String title;

  /// Numele câmpului de valabilitate din formular (`form[<dateField>]`).
  final String dateField;

  String get url =>
      '$ddbraBaseUrl/general?module=shop&currentAction=comanda_rapida&currentId=$id';
}

const _accesZi = DdbraProduct(
  3,
  'Permis acces turist 1 zi',
  'valabilitate_1_zile',
);
const _acces7 = DdbraProduct(
  6,
  'Permis acces turist 7 zile',
  'valabilitate_7_zile',
);
const _accesAn = DdbraProduct(
  7,
  'Permis acces turist până la finele anului',
  'valabilitate_this_year_365_zile',
);
const _accesGratuit = DdbraProduct(
  4,
  'Permis acces turist gratuit',
  'valabilitate_this_year_365_zile',
);
const _pescuit = DdbraProduct(
  12,
  'Permis pescuit recreativ',
  'valabilitate_this_year_365_zile',
);
const _barcaGratuit = DdbraProduct(
  5,
  'Permis ambarcațiune gratuit',
  'valabilitate_this_year_365_zile',
);
const _barca7 = DdbraProduct(
  8,
  'Permis ambarcațiune 7 zile',
  'valabilitate_7_zile',
);
const _barcaAn = DdbraProduct(
  9,
  'Permis ambarcațiune până la finele anului',
  'valabilitate_this_year_365_zile',
);

/// Un permis de cumpărat într-un sezon, cu datele de completat în formular.
class PermitTask {
  PermitTask({
    required this.kind,
    required this.product,
    required this.ownerName,
    required this.fields,
    required this.missing,
    required this.entityId,
    this.subtitle,
  });

  final PermitKind kind;
  final DdbraProduct product;
  final String ownerName;
  final String? subtitle;
  final Map<String, String> fields;
  final List<String> missing;
  final String entityId;

  String get key => '${kind.name}:$entityId';
  bool get ready => missing.isEmpty;
  String get fileLabel =>
      '${ownerName.replaceAll(RegExp(r'[^A-Za-z0-9ĂÂÎȘȚăâîșț]+'), '_')}_${kind.name}';
}

final _ddbraDate = DateFormat('dd-MM-yyyy');

/// Ziua de început scrisă de user, în formatul site-ului (`dd-MM-yyyy`).
String _validFrom(Season s) =>
    s.permitStart == null ? '' : _ddbraDate.format(s.permitStart!);

Map<String, String> _personFields(Participant p) => {
  'fname': p.nume.trim(),
  'lname': p.prenume.trim(),
  'email': p.email.trim(),
  'country': p.tara.trim().isEmpty ? 'Romania' : p.tara.trim(),
  'state': p.judet.trim(),
};

List<PermitTask> buildPermitTasks({
  required Season season,
  required List<Participant> participants,
  required List<Boat> boats,
}) {
  final tasks = <PermitTask>[];
  final from = _validFrom(season);
  final noStart = [if (season.permitStart == null) 'ziua de început'];

  for (final p in participants.where(
    (p) => season.participantIds.contains(p.id),
  )) {
    final accessProduct = p.category.freeAccess
        ? _accesGratuit
        : switch (season.accessDuration) {
            AccessDuration.zi1 => _accesZi,
            AccessDuration.zile7 => _acces7,
            AccessDuration.an => _accesAn,
          };
    tasks.add(
      PermitTask(
        kind: PermitKind.acces,
        product: accessProduct,
        ownerName: p.fullName,
        subtitle: p.category.freeAccess
            ? 'Gratuit — ${p.category.label.toLowerCase()}'
            : season.accessDuration.label,
        fields: {..._personFields(p), accessProduct.dateField: from},
        missing: [...noStart, ...p.missingFields()],
        entityId: p.id,
      ),
    );
    tasks.add(
      PermitTask(
        kind: PermitKind.pescuit,
        product: _pescuit,
        ownerName: p.fullName,
        subtitle: 'Gratuit — valabil doar cu permis de acces',
        fields: {
          ..._personFields(p),
          'cnp': p.cnp.trim(),
          _pescuit.dateField: from,
        },
        missing: [...noStart, ...p.missingFields(needsCnp: true)],
        entityId: p.id,
      ),
    );
  }

  for (final b in boats.where((b) => season.boatIds.contains(b.id))) {
    final owner = participants.where((p) => p.id == b.ownerId).firstOrNull;
    final product = b.gratuit
        ? _barcaGratuit
        : switch (season.boatDuration) {
            BoatDuration.zile7 => _barca7,
            BoatDuration.an => _barcaAn,
          };
    final missing = <String>[
      ...noStart,
      if (owner == null)
        'proprietar'
      else
        ...owner.missingFields(needsPhone: true),
      if (b.nrInmatriculare.trim().isEmpty) 'nr. înmatriculare',
      if (b.capacitateMotor.trim().isEmpty) 'capacitate motor',
      if (b.port.trim().isEmpty) 'port',
    ];
    tasks.add(
      PermitTask(
        kind: PermitKind.barca,
        product: product,
        ownerName: b.denumire,
        subtitle:
            '${b.gratuit ? 'Gratuit (rezident)' : season.boatDuration.label}'
            '${owner != null ? ' — pe numele ${owner.fullName}' : ''}',
        fields: {
          if (owner != null) ..._personFields(owner),
          if (owner != null) 'phone': owner.telefon.trim(),
          'denumire_nava': b.denumire.trim(),
          'numar_inmatriculare': b.nrInmatriculare.trim(),
          'capacitate_motor': b.capacitateMotor.trim(),
          'tipul_ambarcatiunii': b.tip,
          'port_inmatriculare': b.port.trim(),
          product.dateField: from,
        },
        missing: missing,
        entityId: b.id,
      ),
    );
  }
  return tasks;
}

/// JavaScript injectat în pagina de comandă: completează câmpurile `form_<x>`
/// și bifează acordul GDPR. Întoarce numărul de câmpuri completate.
String buildAutofillScript(Map<String, String> fields) {
  final data = jsonEncode(fields);
  return '''
(function(v){
  var n = 0;
  for (var k in v) {
    var el = document.getElementById('form_' + k);
    if (!el || v[k] === '') continue;
    el.value = v[k];
    el.dispatchEvent(new Event('input', {bubbles: true}));
    el.dispatchEvent(new Event('change', {bubbles: true}));
    el.style.backgroundColor = '#e3f7ec';
    n++;
  }
  var gdpr = document.getElementById('form_gdpr');
  if (gdpr && n > 0) { gdpr.checked = true; }
  var ac = document.getElementById('inputAutoComplete');
  if (ac) ac.parentNode.removeChild(ac);
  var btn = document.getElementById('atem-submit');
  if (btn) btn.scrollIntoView({block: 'center'});
  return n;
})($data);
''';
}
