/* (3.14.0) The diesel history texts and a label's machinery – the same as the web's own code (fixtures/dh/web_dh.json: App.html's
 * dhAgo / dhLine / dhCard run in node, and qrArrive's URLSearchParams on the label links; the scratchpad's dh/gen.js). */
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rcl_mobile/core/diesel_hist.dart';
import 'package:rcl_mobile/core/qr_scan.dart';
import 'package:rcl_mobile/screens/admin.dart' show dtFull, faultsLine, backupLine;
import 'package:rcl_mobile/screens/diesel_photos.dart' show photoStamp;

void main() {
  final fx = jsonDecode(File('test/fixtures/dh/web_dh.json').readAsStringSync()) as Map<String, dynamic>;
  final today = '${fx['today']}';

  test('The diesel history: the last-fill line and the card\'s head line, as the web writes them', () {
    for (final c in fx['cases'] as List) {
      final h = (c as Map)['h'] as Map;
      expect(dhLine(h, today), c['line'], reason: '${h['no']}');
      expect(dhHead(h, today), c['head'], reason: '${h['no']}');
    }
    expect(dhLine(null, today), isNull, reason: 'not read yet: nothing');
  });

  test('How long ago (today / yesterday / N days ago)', () {
    for (final a in fx['agos'] as List) {
      expect(dhAgo('${a[0]}', today), a[1], reason: '${a[0]}');
    }
  });

  test('The hint of the reading box and the last driver', () {
    final h = ((fx['cases'] as List).first as Map)['h'] as Map;
    expect(dhHint(h, 'lastKm'), 'last 15,230');
    expect(dhHint(h, 'lastHr'), '');
    expect(dhDriver(h), 'Ramesh');
    expect(dhDriver(((fx['cases'] as List)[2] as Map)['h'] as Map), '', reason: 'no fill with a driver');
  });

  test('A scanned label: its machinery, as the web reads ?m= (URLSearchParams)', () {
    for (final l in fx['labels'] as List) {
      expect(labelMachine('${l[0]}'), l[1], reason: '${l[0]}');
    }
  });

  test('Times as the web shows them (photo stamp, sign-ins, backup) and the Admin\'s lines', () {
    final t = DateTime(2026, 10, 16, 9, 5, 3);
    expect(photoStamp(t.toUtc().toIso8601String()), '16-10-2026 09:05:03');
    expect(dtFull(t.toUtc().toIso8601String()), '16/10/2026, 09:05:03 am');
    expect(dtFull(DateTime(2026, 10, 16, 21, 0, 0).toUtc().toIso8601String()), '16/10/2026, 09:00:00 pm');
    expect(dtFull(''), '–');
    expect(faultsLine({'day': '2026-10-16', 'n': 2, 'last': 'getStock: x'}, '2026-10-16'), 'Faults today: 2 – last: getStock: x');
    expect(faultsLine({'day': '2026-10-15', 'n': 2}, '2026-10-16'), 'No fault reported today');
    expect(backupLine({'ok': false, 'error': 'quota'}), 'Backup problem: quota – press to try now');
  });
}
