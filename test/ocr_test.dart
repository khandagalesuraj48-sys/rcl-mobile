// (3.28.0) The phone reads the photo: what the lines of text mean – the meter, the dispenser's litres, the bill of an inward.
// (The reading itself is Google ML Kit on the phone; here the lines it gives are written out, as a phone gives them.)
import 'package:flutter_test/flutter_test.dart';
import 'package:rcl_mobile/core/ocr_read.dart';

List<OcrLine> L(List<String> t) => [for (final x in t) OcrLine(x)];

void main() {
  test('a line made ready: dates, times and percents out; O → 0 inside numbers; 1,23,456.50 and 45,60', () {
    expect(cleanLine('Date 20/10/2026 Time 10:45 AM'), 'Date Time');
    expect(cleanLine('ODO 4517O km'), 'ODO 45170 km');
    expect(cleanLine('Total 1,23,456.50'), 'Total 123456.50');
    expect(cleanLine('Vol 45,60'), 'Vol 45.60');
    expect(cleanLine('Oil Bill'), 'Oil Bill', reason: 'a word without a digit stays as it is');
    expect(cleanLine('VAT 5% 450.00'), 'VAT 450.00');
    expect(numbersOf(L(['Rate 94.50', 'Qty 200'])).map((n) => n.value), [94.5, 200]);
  });

  group('the meter (KM / Hrs) – the number that fits the last reading', () {
    test('the odometer among the clock, the trip and the temperature', () {
      final r = meterFrom(L(['12:45', 'ODO 45173 km', 'TRIP A 123.4', '88 C']), lastKm: const LastReading(45120, '2026-10-18'), today: '2026-10-20');
      expect(r.km, 45173);
      expect(r.hr, null);
      expect(r.check, '');
    });
    test('the tenth digit in another colour read as one more digit: 451734 → 45173.4', () {
      expect(meterFrom(L(['451734']), lastKm: const LastReading(45120, '2026-10-18'), today: '2026-10-20').km, 45173.4);
      expect(meterFrom(L(['45173 4']), lastKm: const LastReading(45120, '2026-10-18'), today: '2026-10-20').km, 45173.4);
    });
    test('KM and Hrs on one dashboard, each by its own last reading', () {
      final r = meterFrom(L(['45173', 'HRS 1234.5']), wantKm: true, wantHr: true,
          lastKm: const LastReading(45120, '2026-10-18'), lastHr: const LastReading(1230, '2026-10-18'), today: '2026-10-20');
      expect(r.km, 45173);
      expect(r.hr, 1234.5);
    });
    test('an hour meter alone; a letter read for a digit', () {
      expect(meterFrom(L(['HOURS', 'O1234.5']), wantKm: false, wantHr: true, lastHr: const LastReading(1230, '2026-10-19'), today: '2026-10-20').hr, 1234.5);
      expect(meterFrom(L(['4517O']), lastKm: const LastReading(45120, '2026-10-19'), today: '2026-10-20').km, 45170);
    });
    test('nothing that fits (below the last, or far more than it can run): nothing is put – he types it', () {
      expect(meterFrom(L(['99999', '120']), lastKm: const LastReading(45120, '2026-10-19'), today: '2026-10-20').km, null);
      expect(meterFrom(L(['45000']), lastKm: const LastReading(45120, '2026-10-19'), today: '2026-10-20').km, null);
    });
    test('no earlier reading: one clear long number only, and it says to check', () {
      final r = meterFrom(L(['ODO 45173', 'TRIP 123']));
      expect(r.km, 45173);
      expect(r.check, 'KM: no earlier reading to compare');
      expect(meterFrom(L(['45173', '51200'])).km, null, reason: 'two long numbers: which one is not known');
      expect(meterFrom(L(['45173', '1234']), wantKm: true, wantHr: true).km, null, reason: 'KM and Hrs without a last reading: not guessed');
    });
  });

  group('(3.29.0) what went wrong on the phones', () {
    const last = LastReading(45120, '2026-10-19');
    test('the digits of a display read apart, or as letters (LED / LCD segments)', () {
      expect(meterFrom(L(['45 173']), lastKm: last, today: '2026-10-20').km, 45173);
      expect(meterFrom(L(['45I73']), lastKm: last, today: '2026-10-20').km, 45173);
      expect(meterFrom(L(['4517D']), lastKm: last, today: '2026-10-20').km, 45170);
      expect(meterFrom(L(['O1Gb.5']), wantKm: false, wantHr: true, lastHr: const LastReading(160, '2026-10-19'), today: '2026-10-20').hr, 166.5);
    });
    test('the digit after the point given by the reader as a line of its own, right of the number: kept (45173.4, not 45173)', () {
      final lines = [const OcrLine('45173', left: 100, top: 100, width: 300, height: 60), const OcrLine('4', left: 410, top: 105, width: 40, height: 55)];
      expect(meterFrom(lines, lastKm: last, today: '2026-10-20').km, 45173.4);
    });
    test('the dispenser\'s points not seen: 472500 / 5000 / 9450 → 4725.00 = 50.00 L × 94.50 (two decimals, as a display shows)', () {
      expect(pumpFrom(L(['472500', '5000', '9450'])).litres, 50);
      expect(pumpFrom(L(['472500', '5000', '9450'])).sure, true);
      expect(pumpFrom(L(['4725.00', '5000', '94.50'])).litres, 50);
      expect(pumpFrom(L(['1890000', '20000', '9450'])).litres, 200);
      expect(pumpFrom(L(['Volume 45.20'])).sure, false, reason: 'by the word only: not as sure as the three numbers');
    });
  });

  group('the dispenser – the litres of this fill', () {
    test('litres × rate = amount tells which number is the litres', () {
      expect(pumpFrom(L(['SALE', '4725.00', 'LITRE', '50.00', 'PRICE', '94.50'])).litres, 50);
      expect(pumpFrom(L(['Rs 9450.00', '100.00 L', '94.50 Rs/L'])).litres, 100);
    });
    test('the words on the display decide when litres and rate are both near 100 (places on the picture)', () {
      final lines = [
        const OcrLine('AMOUNT', left: 10, top: 10, width: 120, height: 30), const OcrLine('9450.00', left: 200, top: 12, width: 200, height: 30),
        const OcrLine('RATE', left: 10, top: 60, width: 80, height: 30), const OcrLine('100.00', left: 200, top: 62, width: 150, height: 30),
        const OcrLine('VOLUME', left: 10, top: 110, width: 120, height: 30), const OcrLine('94.50', left: 200, top: 112, width: 150, height: 30),
      ];
      expect(pumpFrom(lines).litres, 94.5);
    });
    test('the totaliser is not the litres; the word Volume alone; amount ÷ rate', () {
      expect(pumpFrom(L(['TOTALISER 1234567.89', 'Volume(L) 45.20'])).litres, 45.2);
      expect(pumpFrom(L(['Qty 38.6'])).litres, 38.6);
      expect(pumpFrom(L(['Amount 4725', 'Rate 94.50'])).litres, 50);
      expect(pumpFrom(L(['HP', 'Welcome'])).litres, null);
    });
  });

  group('the bill of a Diesel Inward – Bill No., litres, rate', () {
    test('a pump\'s printed receipt', () {
      final b = billFrom(L(['HP PETROL PUMP', 'Bill No: 004512', 'Date: 20/10/2026 Time: 10:45', 'Product: DIESEL', 'Rate (Rs/L): 94.50', 'Volume (L): 200.00', 'Amount (Rs): 18900.00']));
      expect(b.billNo, '004512');
      expect(b.qty, 200);
      expect(b.rate, 94.5);
      expect(b.amount, 18900);
    });
    test('a tanker\'s invoice in KL and ₹ per KL → litres and ₹ per litre', () {
      final b = billFrom(L(['TAX INVOICE', 'Invoice No. TI/2026/1187', 'HSD 12.000 KL 92,000.00 11,04,000.00']));
      expect(b.billNo, 'TI/2026/1187');
      expect(b.qty, 12000);
      expect(b.rate, 92);
    });
    test('the bill number: its word on the line, or under it; never a date', () {
      expect(billNoFrom(L(['Invoice Number: 5678'])), '5678');
      expect(billNoFrom(L(['Receipt No.', 'A-0045'])), 'A-0045');
      expect(billNoFrom(L(['Bill Date: 20/10/2026', 'Bill To: ABC'])), '');
      expect(billNoFrom(L(['Txn No 88931'])), '88931');
    });
    test('only what is there: litres and rate by their words, no bill number', () {
      final b = billFrom(L(['DIESEL', 'Qty 150 Ltr', 'Rate 95.10']));
      expect(b.billNo, '');
      expect(b.qty, 150);
      expect(b.rate, 95.1);
      expect(billFrom(L(['Thank you'])).any, false);
    });
  });
}
