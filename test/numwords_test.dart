/* (3.67.0) a number said in words → the number: the same cases as the web's voice.js (rcl-store test/voice.test.js). */
import 'package:flutter_test/flutter_test.dart';
import 'package:rcl_mobile/core/numwords.dart';

void main() {
  test('English, हिंदी, मराठी – words, digits, ₹, units after it, halves and quarters, lakh / crore; nothing heard: empty', () {
    const cases = [
      ('12', '12'),
      ('12.5', '12.5'),
      ('१२.५', '12.5'),
      ('1,200', '1200'),
      ('₹500', '500'),
      ('twelve', '12'),
      ('twelve point five', '12.5'),
      ('zero point five', '0.5'),
      ('point two five', '0.25'),
      ('one hundred twenty', '120'),
      ('two thousand five hundred', '2500'),
      ('twenty five thousand', '25000'),
      ('two and a half', '2.5'),
      ('1 lakh 20 thousand', '120000'),
      ('a hundred', '100'),
      ('बारा', '12'),
      ('बारा पॉइंट पाच', '12.5'),
      ('बारा लिटर', '12'),
      ('लिटर बारा', '12'),
      ('साडे तीन हजार', '3500'),
      ('साडेतीन', '3.5'),
      ('साडेतीनशे', '350'),
      ('दीडशे', '150'),
      ('दोनशे', '200'),
      ('सव्वाशे', '125'),
      ('पावणे दोन', '1.75'),
      ('दीड हजार', '1500'),
      ('अडीच लाख', '250000'),
      ('एक लाख वीस हजार', '120000'),
      ('पंधरा हजार पाचशे', '15500'),
      ('एकशेवीस', '120'),
      ('शंभर', '100'),
      ('अर्धा', '0.5'),
      ('चौऱ्याहत्तर', '74'),
      ('नव्व्याण्णव', '99'),
      ('पंचाहत्तर बॅग', '75'),
      ('बारा पंधरा', '12'),
      ('दो सौ', '200'),
      ('डेढ़ सौ', '150'),
      ('ढाई हज़ार', '2500'),
      ('एक सौ बीस', '120'),
      ('साढ़े चार', '4.5'),
      ('सवा दो', '2.25'),
      ('पौने तीन', '2.75'),
      ('अड़तीस', '38'),
      ('पचहत्तर', '75'),
      ('दो करोड़ पचास लाख', '25000000'),
      ('निन्यानवे', '99'),
      ('पाँच', '5'),
      ('सात सौ पचास रुपये', '750'),
      ('cement', ''),
      ('', ''),
      ('twenty twenty', '20'),
      ('twenty five', '25'),
      ('12 kg', '12'),
      ('12kg', '12'),
      ('50 bag', '50'),
      ('three point one four', '3.14'),
      ('एक हजार दोनशे पन्नास', '1250'),
      ('दोन हजार', '2000'),
      ('शून्य', '0'),
      ('सहाशे', '600'),
      ('पाचशे पन्नास', '550'),
    ];
    for (final (said, want) in cases) {
      expect(spokenNumber(said), want, reason: said);
    }
  });
  test('a phone number said digit by digit', () {
    expect(spokenNumber('नऊ आठ दोन शून्य एक', digits: true), '98201');
    expect(spokenNumber('98 20 one two', digits: true), '982012');
  });
}
