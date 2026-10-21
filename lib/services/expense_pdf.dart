import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../data/app_store.dart';
import '../models/expense.dart';
import '../models/season.dart';

final _lei = NumberFormat('#,##0', 'ro');
String _sum(double v) => '${_lei.format(v.round())} lei';

/// Diferența de decont: +80 lei (primește) / −80 lei (dă).
String _diff(double v) => v.round() == 0
    ? '0 lei (achitat)'
    : v > 0
    ? '+${_sum(v)} (primește)'
    : '−${_sum(-v)} (dă)';
final _when = DateFormat('dd.MM.yyyy HH:mm');

/// Toate cheltuielile sezonului într-un PDF: lista numerotată, totalurile,
/// situația pe participant și decontarea.
Future<Uint8List> buildExpensesPdf(AppStore store, Season season) async {
  final regular = pw.Font.ttf(
    await rootBundle.load('assets/fonts/Roboto-Regular.ttf'),
  );
  final bold = pw.Font.ttf(
    await rootBundle.load('assets/fonts/Roboto-Bold.ttf'),
  );
  String name(String id) => store.participant(id)?.fullName ?? '?';
  String short(String id) => store.participant(id)?.shortName ?? '?';

  final list = season.expenses.toList()
    ..sort((a, b) => a.number.compareTo(b.number));
  final total = list.fold<double>(0, (s, e) => s + e.amount);
  final common = list
      .where((e) => e.common)
      .fold<double>(0, (s, e) => s + e.amount);
  final balances = balancesOf(season.expenses, season.participantIds);
  final ids = balances.keys.toList();
  final commonPaid = <String, double>{};
  final ownPaid = <String, double>{};
  for (final e in list) {
    final m = e.common ? commonPaid : ownPaid;
    m[e.paidBy] = (m[e.paidBy] ?? 0) + e.amount;
  }
  // toate cheltuielile comune împărțite la aceiași oameni?
  final equalSplit = list
      .where((e) => e.common)
      .every(
        (e) =>
            e.sharedWith.toSet().containsAll(ids) &&
            e.sharedWith.length == ids.length,
      );
  final transfers = settle(balances);

  const navy = PdfColor.fromInt(0xFF0B3C5D);
  const brown = PdfColor.fromInt(0xFF6B4423);
  const light = PdfColor.fromInt(0xFFDDEEF8);

  pw.Widget heading(String t) => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 14, bottom: 6),
    child: pw.Text(
      t,
      style: pw.TextStyle(font: bold, fontSize: 13, color: navy),
    ),
  );

  final doc = pw.Document(
    theme: pw.ThemeData.withFont(base: regular, bold: bold),
    title: 'Cheltuieli ${season.title}',
  );
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      footer: (ctx) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          'Pescar Deltă · pagina ${ctx.pageNumber} din ${ctx.pagesCount}',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
        ),
      ),
      build: (ctx) => [
        pw.Text(
          'Cheltuieli — ${season.title}',
          style: pw.TextStyle(font: bold, fontSize: 20, color: navy),
        ),
        pw.Text(
          '${season.place.name} · ${season.periodLabel} · '
          'generat ${_when.format(DateTime.now())}',
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 10),
        pw.Row(
          children: [
            for (final (label, v) in [
              ('Total', total),
              ('Comune', common),
              ('Proprii', total - common),
            ])
              pw.Expanded(
                child: pw.Container(
                  margin: const pw.EdgeInsets.only(right: 6),
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    color: light,
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
                      pw.Text(
                        _sum(v),
                        style: pw.TextStyle(
                          font: bold,
                          fontSize: 14,
                          color: brown,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        heading('Toate cheltuielile (${list.length})'),
        pw.TableHelper.fromTextArray(
          headers: [
            'Nr.',
            'Data',
            'Ce',
            'Categorie',
            'Achitată de',
            'Tip',
            'Sumă',
          ],
          data: [
            for (final (i, e) in list.indexed)
              [
                '${i + 1}.',
                _when.format(e.date),
                e.description.isEmpty ? e.category : e.description,
                e.category,
                name(e.paidBy),
                e.common ? 'comună (${e.sharedWith.length})' : 'proprie',
                _sum(e.amount),
              ],
          ],
          headerStyle: pw.TextStyle(
            font: bold,
            fontSize: 9,
            color: PdfColors.white,
          ),
          headerDecoration: const pw.BoxDecoration(color: navy),
          cellStyle: const pw.TextStyle(fontSize: 9),
          oddRowDecoration: const pw.BoxDecoration(color: light),
          cellAlignments: {
            0: pw.Alignment.centerRight,
            6: pw.Alignment.centerRight,
          },
          columnWidths: {
            0: const pw.FixedColumnWidth(26),
            1: const pw.FixedColumnWidth(72),
            6: const pw.FixedColumnWidth(56),
          },
        ),
        heading('Decontul cheltuielilor comune'),
        pw.Text(
          equalSplit
              ? 'Total cheltuieli comune: ${_sum(common)}, împărțite egal la '
                    '${ids.length} participanți = ${_sum(common / ids.length)} '
                    'de fiecare.'
              : 'Total cheltuieli comune: ${_sum(common)}, fiecare împărțită '
                    'egal între cei care au luat parte la ea.',
          style: const pw.TextStyle(fontSize: 10),
        ),
        pw.SizedBox(height: 6),
        pw.TableHelper.fromTextArray(
          headers: [
            'Participant',
            'A achitat la comun',
            'Partea lui din comun',
            'Diferență (decont)',
            'Cheltuieli proprii',
          ],
          data: [
            for (final id in ids)
              [
                name(id),
                _sum(commonPaid[id] ?? 0),
                _sum(balances[id]?.commonShare ?? 0),
                _diff((commonPaid[id] ?? 0) - (balances[id]?.commonShare ?? 0)),
                _sum(ownPaid[id] ?? 0),
              ],
            [
              'TOTAL',
              _sum(common),
              _sum(common),
              '0 lei',
              _sum(total - common),
            ],
          ],
          headerStyle: pw.TextStyle(
            font: bold,
            fontSize: 9,
            color: PdfColors.white,
          ),
          headerDecoration: const pw.BoxDecoration(color: navy),
          cellStyle: const pw.TextStyle(fontSize: 9),
          oddRowDecoration: const pw.BoxDecoration(color: light),
          cellAlignments: {
            1: pw.Alignment.centerRight,
            2: pw.Alignment.centerRight,
            3: pw.Alignment.centerRight,
            4: pw.Alignment.centerRight,
          },
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Diferența = cât a achitat la comun − partea lui. Plus: primește '
          'banii înapoi; minus: are de dat. Cheltuielile proprii nu intră în '
          'decont.',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
        ),
        heading('Decontare'),
        if (transfers.isEmpty)
          pw.Text('Nimeni nu datorează nimic.')
        else
          for (final (i, t) in transfers.indexed)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 3),
              child: pw.Text(
                '${i + 1}. ${short(t.from)} – dator cu suma de '
                '${_sum(t.amount)} către ${short(t.to)}',
                style: const pw.TextStyle(fontSize: 11),
              ),
            ),
      ],
    ),
  );
  return doc.save();
}
