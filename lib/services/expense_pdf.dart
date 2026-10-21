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
        heading('Pe participant'),
        pw.TableHelper.fromTextArray(
          headers: ['Participant', 'A plătit', 'Partea lui', 'Rezultat'],
          data: [
            for (final b in balances.values)
              [
                name(b.participantId),
                _sum(b.paid),
                _sum(b.owes),
                b.balance.abs() < 0.5
                    ? 'achitat'
                    : b.balance > 0
                    ? 'de primit ${_sum(b.balance)}'
                    : 'dator cu ${_sum(-b.balance)}',
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
