// (3.117.0 / 3.118.0) A month of attendance as a PDF: its words, its hours, its period – and that a PDF comes out with its parts.
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:rcl_mobile/core/attend_pdf.dart';

void main() {
  test('the words the PDF can write; the hours of a day; the month and its period; a long line broken between words', () {
    expect(pdfWords('Site office – VTR · NH 848'), 'Site office - VTR - NH 848');
    expect(pdfWords('सुजित Mule'), 'Mule', reason: 'a letter the PDF has no type for is left out – the page is always made');
    expect(pdfWords(null), '');
    expect(pdfHours('08:24', '17:35'), '9 h 11 m');
    expect(pdfHours('22:00', '06:05'), '8 h 05 m', reason: 'a night: OUT on the next day');
    expect(pdfHours('08:24', ''), '');
    expect(pdfMonth('2026-11'), ('November-2026', '01/11/2026 to 30/11/2026'));
    expect(pdfMonth('2028-02'), ('February-2028', '01/02/2028 to 29/02/2028'));
    expect(pdfFit('A very long remark that cannot fit', 60, 9).endsWith('..'), true);
    final lines = pdfWrap('Half day: 4.5 working hours or more, but fewer than 9. Fewer than 4.5 hours: absent.', 200, 7.6);
    expect(lines.length, greaterThan(1));
    expect(lines.join(' '), 'Half day: 4.5 working hours or more, but fewer than 9. Fewer than 4.5 hours: absent.');
    expect(lines.every((l) => pdfWidth(l, 7.6) <= 200), true);
  });

  test('a month with every day: one page – the head, the days ruled, the Summary, the rules, room to sign; with a logo too', () async {
    final days = [
      for (var d = 1; d <= 31; d++)
        {'day': '2026-10-${d.toString().padLeft(2, '0')}', 'code': d % 7 == 4 ? 'WO' : d == 12 ? 'A' : d == 20 ? 'HD' : 'P', 'in': d % 7 == 4 || d == 12 ? '' : '08:3${d % 10}', 'out': d % 7 == 4 || d == 12 ? '' : '17:40', 'late_min': d == 13 ? 12 : 0, 'late_half': d == 20, 'auto': d == 21, 'place': d % 7 == 4 || d == 12 ? '' : 'Site office'},
    ];
    const total = {'P': 24, 'HD': 1, 'A': 1, 'L': 0, 'WO': 5, 'H': 0, 'late': 1, 'paid': 29.5};
    const rules = ['Full day: 9 working hours or more.', 'Late: IN more than 15 minutes after the shift starts.', 'Weekly off: Sunday.'];
    final bytes = await attendancePdf(company: 'Rachana Construction Limited', site: 'VTR Site – NH 848', name: 'Test Person', code: 'E00012', month: '2026-10', days: days, total: total, rules: rules, made: '13/11/2026 11:00');
    expect(String.fromCharCodes(bytes.sublist(0, 5)), '%PDF-');
    expect(bytes.length, greaterThan(3000));
    final text = String.fromCharCodes(bytes);
    for (final w in ['(Rachana Construction Limited)', '(Attendance for the Month October-2026)', '(VTR Site - NH 848)', '(01/10/2026 to 31/10/2026)', '(E00012)', '(31/10/2026)', '(Saturday)', '(Site office)', '(Late 12 min)', '(Half day)', '(Total Paid Days)', '(29.5)', '(Rules of attendance)', 'Full day: 9 working hours or more.', '(HR)', '(Accounts)', '(Director)']) {
      expect(text.contains(w), true, reason: w);
    }
    expect(text.contains('/Im1'), false, reason: 'no logo given: no picture in the file');
    expect(RegExp(r'startxref\n(\d+)\n%%EOF').hasMatch(text), true);
    // … and with a picture in its head
    final jpg = Uint8List.fromList(img.encodeJpg(img.Image(width: 40, height: 10)));
    final withLogo = String.fromCharCodes(await attendancePdf(company: 'Rachana Construction Limited', site: 'VTR', name: 'Test Person', code: 'E1', month: '2026-11', days: days.sublist(0, 30), total: total, logo: PdfLogo(jpg, 40, 10)));
    expect(withLogo.contains('/XObject << /Im1 8 0 R >>') && withLogo.contains('/Filter /DCTDecode') && withLogo.contains('/Width 40 /Height 10'), true);
    expect(await pdfLogo('Some Other Company'), null, reason: 'the logo is Rachana\'s: not put on another company\'s sheet');
  });

  test('(3.119.0) a month\'s salary slip as a PDF: the head, what was earned, what was deducted, the net pay – as the server gave them', () async {
    expect([pdfAmount(127400), pdfAmount(122548.39), pdfAmount(496), pdfAmount('1800'), pdfAmount(-250.5), pdfAmount(null)], ['1,27,400', '1,22,548.39', '496', '1,800', '-250.50', '0']);
    const slip = {
      'month': '2026-10', 'net': 127400, 'pay_type': 'monthly', 'rate': 131000, 'month_days': 31, 'pay_days': 29, 'extra_days': 2, 'gross': 131500, 'total_deductions': 4100,
      'earnings': [{'label': 'Earned pay', 'amount': 122548.39}, {'label': 'Extra days', 'amount': 8451.61}, {'label': 'arrear', 'amount': 500}],
      'deductions': [{'label': 'PF', 'amount': 1800}, {'label': 'Profession Tax', 'amount': 200}, {'label': 'Advance', 'amount': 2000}, {'label': 'Other deduction', 'amount': 100}],
    };
    final bytes = await payslipPdf(company: 'Rachana Construction Limited', site: 'Mumbai HO', name: 'Test Person', code: 'RCL012', slip: slip, made: '13/11/2026 17:00');
    final text = String.fromCharCodes(bytes);
    expect(String.fromCharCodes(bytes.sublist(0, 5)), '%PDF-');
    for (final w in ['(Rachana Construction Limited)', '(Salary Slip for the Month October-2026)', '(Test Person)', '(RCL012)', '(Mumbai HO)', '(Salary a month :)', '(Rs. 1,31,000)', '(29  \\(+ 2 extra\\))', '(Earnings)', '(Earned pay)', '(1,22,548.39)', '(Gross)', '(1,31,500)', '(Deductions)', '(Profession Tax)', '(Total deductions)', '(4,100)', '(Net pay)', '(Rs. 1,27,400)', '(HR)', '(Accounts)', '(Director)']) {
      expect(text.contains(w), true, reason: w);
    }
    expect(RegExp(r'startxref\n(\d+)\n%%EOF').hasMatch(text), true);
    // a day's rate, nothing deducted
    final daily = String.fromCharCodes(await payslipPdf(company: 'Test Company', site: 'Site', name: 'Day Person', code: '', slip: const {'month': '2026-09', 'net': 500, 'pay_type': 'daily', 'rate': 500, 'month_days': 30, 'pay_days': 1, 'extra_days': 0, 'gross': 500, 'total_deductions': 0, 'earnings': [{'label': 'Earned pay', 'amount': 500}], 'deductions': []}));
    expect(daily.contains('(Rate a day :)') && daily.contains('(Rs. 500)') && daily.contains('(Salary Slip for the Month September-2026)'), true);
  });
}
