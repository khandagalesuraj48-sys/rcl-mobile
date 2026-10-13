import 'package:flutter_test/flutter_test.dart';
import 'package:rcl_mobile/core/format.dart';

void main() {
  test('numbers in the Indian way', () {
    expect(fmtNum(813), '813');
    expect(fmtNum(1240), '1,240');
    expect(fmtNum(1234567), '12,34,567');
    expect(fmtNum(120.5), '120.5');
    expect(fmtNum(99.999), '100');
    expect(fmtNum(-2000), '−2,000');
    expect(fmtNum(null), '–');
  });
  test('dates', () {
    expect(showDate('2026-10-13'), '13-10-2026');
    expect(dateKey(DateTime(2026, 1, 5)), '2026-01-05');
    expect(parseKey('2026-10-13'), DateTime(2026, 10, 13));
    expect(asNum('1,240'), 1240);
    expect(asNum(''), null);
  });
}
