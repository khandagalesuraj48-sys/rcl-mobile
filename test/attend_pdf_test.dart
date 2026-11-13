// (3.117.0) A month of attendance as a PDF: its words, its hours, its period – and that a PDF comes out.
import 'package:flutter_test/flutter_test.dart';
import 'package:rcl_mobile/core/attend_pdf.dart';

void main() {
  test('the words the PDF can write; the hours of a day; the month and its period', () {
    expect(pdfWords('Site office – VTR · NH 848'), 'Site office - VTR - NH 848');
    expect(pdfWords('सुजित Mule'), 'Mule', reason: 'a letter the PDF has no type for is left out – the page is always made');
    expect(pdfWords(null), '');
    expect(pdfHours('08:24', '17:35'), '9 h 11 m');
    expect(pdfHours('22:00', '06:05'), '8 h 05 m', reason: 'a night: OUT on the next day');
    expect(pdfHours('08:24', ''), '');
    expect(pdfMonth('2026-11'), ('November 2026', '01-11-2026 to 30-11-2026'));
    expect(pdfMonth('2028-02'), ('February 2028', '01-02-2028 to 29-02-2028'));
  });

  test('a month with every day: a PDF comes out – one page, its parts where a reader looks for them', () async {
    final days = [
      for (var d = 1; d <= 31; d++)
        {'day': '2026-10-${d.toString().padLeft(2, '0')}', 'code': d % 7 == 4 ? 'WO' : d == 12 ? 'A' : d == 20 ? 'HD' : 'P', 'in': d % 7 == 4 || d == 12 ? '' : '08:3${d % 10}', 'out': d % 7 == 4 || d == 12 ? '' : '17:40', 'late_min': d == 13 ? 12 : 0, 'late_half': d == 20, 'auto': d == 21},
    ];
    final bytes = await attendancePdf(company: 'Rachana Construction Limited', site: 'VTR Site – NH 848', name: 'Test Person', code: 'E00012', month: '2026-10', days: days, total: {'P': 24, 'HD': 1, 'A': 1, 'L': 0, 'WO': 5, 'H': 0, 'late': 1, 'paid': 29.5}, made: '13-11-2026 11:00');
    expect(String.fromCharCodes(bytes.sublist(0, 5)), '%PDF-');
    expect(bytes.length, greaterThan(3000));
    final text = String.fromCharCodes(bytes);
    for (final w in ['(Rachana Construction Limited)', '(VTR Site - NH 848)', '(October 2026)', '(Period: 01-10-2026 to 31-10-2026)', '(E00012)', '(31-10-2026)', '(Late 12 min)', '(Days for pay)', '(29.5)']) {
      expect(text.contains(w), true, reason: w);
    }
    expect(RegExp(r'startxref\n(\d+)\n%%EOF').hasMatch(text), true);
    expect(pdfFit('A very long remark that cannot fit', 60, 9).endsWith('..'), true);
  });
}
