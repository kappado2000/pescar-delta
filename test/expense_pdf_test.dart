import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('fontul PDF-ului are diacriticele românești', () async {
    final data = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
    final glyphs = TtfParser(data).charToGlyphIndexMap;
    for (final ch in 'ĂăÎîȘșȚțÂâ'.runes) {
      expect(glyphs[ch], isNotNull, reason: String.fromCharCode(ch));
    }
    final font = pw.Font.ttf(data);
    final doc = pw.Document(theme: pw.ThemeData.withFont(base: font))
      ..addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (_) => pw.Text('Ăă Îî Șș Țț Ââ — cheltuială comună'),
        ),
      );
    expect((await doc.save()).length, greaterThan(1000));
  });
}
