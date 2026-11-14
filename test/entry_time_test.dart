// (3.123.0, Mechanical update-246, asked 14-11-2026) WHEN AN ENTRY WAS SAVED AND BY WHOM – in the list itself, under the card.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rcl_mobile/screens/entries.dart';

void main() {
  test('the time of saving: "09:42 AM" from the server\'s yyyy-MM-dd HH:mm; the day too when it is another day; anything else: nothing', () {
    expect(savedTime('2026-11-14 09:42', '2026-11-14'), '09:42 AM');
    expect(savedTime('2026-11-14 13:05', '2026-11-14'), '01:05 PM');
    expect(savedTime('2026-11-14 00:07', '2026-11-14'), '12:07 AM');
    expect(savedTime('2026-11-14 12:00', '2026-11-14'), '12:00 PM');
    expect(savedTime('2026-11-14 23:59', '2026-11-14'), '11:59 PM');
    expect(savedTime('2026-11-14 18:30', '2026-11-12'), '06:30 PM · 14-11-2026');
    for (final bad in ['', 'x', '2026-11-14', '09:42', '2026-11-14T09:42:00Z', 'null']) {
      expect(savedTime(bad, '2026-11-14'), '', reason: bad);
    }
  });

  test('the card: the line with the time and "Entry: <who>" is under every kind of entry (issue, inward, transfer – one card)', () {
    final src = File('lib/screens/entries.dart').readAsStringSync();
    expect(src, contains("if (_savedAt.isNotEmpty || _by.isNotEmpty) _saved(),"));
    expect(src, contains("String get _savedAt => savedTime('\${r['at'] ?? ''}', '\${r['date'] ?? ''}');"));
    expect(src, contains("Text('Entry: \$_by', key: const Key('entry_saved_by')"));
    expect(src, contains("key: const Key('entry_saved_at')"));
  });
}
