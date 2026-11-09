/* (3.88.0, Mechanical update-213, asked 08-11-2026: "ata he sagle ek sath bana ani ha ho sathi pn ani other site sathi pn he hawe
 * aahet") THE VEHICLE ALERTS of the site – the server's (getVehAlerts), each part only for a person who may see it:
 *   – papers (Tax, PUC, Permit, Fitness, Insurance of an Own machinery) expired, or due within 30 days;
 *   – the service (Asset Master → Service every KM / Hrs / months, from its last maintenance bill marked Service);
 *   – more diesel than its standard this month (as Actual vs Standard Average);
 *   – a fuel card below its "Alert below ₹" (a site on fuel cards).
 * Read with Home (every load) – shown in the bell, on the Dashboard, on HO's cars and on a car's screen. The morning message (once a
 * day after 08:00, to the site's Admins and the Super Admin) is sent by the server. */
import 'package:flutter/foundation.dart';

import 'format.dart';
import 'lang.dart';
import 'session.dart';

class VehAlert {
  VehAlert(this.m);
  final Map<String, dynamic> m;
  String get k => '${m['k'] ?? ''}';
  String get s => '${m['s'] ?? ''}';
  /// red: expired / overdue / bad; amber: due soon / more diesel / no service recorded
  bool get bad => s == 'expired' || s == 'over' || s == 'bad';

  /// the alert in words (the chosen language)
  String get text {
    switch (k) {
      case 'paper':
        final d = '${m['upto'] ?? ''}', n = m['days'] is num ? (m['days'] as num).toInt() : null;
        return s == 'expired'
            ? '${tr('${m['doc']}')} ${tr('expired')} ${showDate(d)}'
            : '${tr('${m['doc']}')} ${tr('due')} ${showDate(d)}${n == null ? '' : ' ($n ${tr(n == 1 ? 'day' : 'days')})'}';
      case 'svc':
        if (s == 'none') return tr('Service – no bill marked Service yet');
        final parts = [
          for (final p in (m['parts'] as List? ?? const []).whereType<Map>())
            '${p['by']}' == 'months'
                ? '${tr((p['left'] is num && (p['left'] as num) < 0) ? 'since' : 'by')} ${showDate('${p['due']}')}'
                : (p['left'] is num && (p['left'] as num) <= 0)
                    ? '${fmtNum(-(p['left'] as num))} ${p['by']} ${tr('over')}'
                    : '${fmtNum(p['left'] is num ? p['left'] as num : 0)} ${p['by']} ${tr('left')}',
        ];
        return '${tr(s == 'over' ? 'Service overdue' : 'Service due')}: ${parts.join(', ')}';
      case 'avg':
        final pct = m['pct'] is num ? ', +${(m['pct'] as num).round()}%' : '';
        return '${tr(s == 'bad' ? 'Bad average' : 'More diesel')}: ${m['actual']} (${tr('standard')} ${m['std']})$pct';
    }
    return '';
  }
}

/// The alerts of this site, as the server last gave them.
class VehAlerts extends ChangeNotifier {
  VehAlerts._() {
    Session.memoryClears.add(clear);      // another site / signing out: none of these stay
  }
  static final VehAlerts i = VehAlerts._();
  Map<String, List<VehAlert>> cars = {};
  List<Map<String, dynamic>> cards = [];
  Map<String, num> count = {};
  int n = 0;
  bool loaded = false;
  Future<void>? _now;

  /// read again (one at a time); a problem leaves the last list as it was
  Future<void> load(Session s) => _now ??= () async {
        try {
          final r = await s.api.call('getVehAlerts', const []);
          if (r is Map) put(r.cast<String, dynamic>());
        } catch (_) {/* the alerts stop nothing – read again with Home's next load */} finally {
          _now = null;
        }
      }();

  void put(Map<String, dynamic> r) {
    final c = (r['cars'] as Map?) ?? const {};
    cars = {for (final e in c.entries) '${e.key}': [for (final a in (e.value as List? ?? const []).whereType<Map>()) VehAlert(a.cast<String, dynamic>())]};
    cards = [for (final x in (r['cards'] as List? ?? const []).whereType<Map>()) x.cast<String, dynamic>()];
    count = {for (final e in ((r['count'] as Map?) ?? const {}).entries) '${e.key}': e.value is num ? e.value as num : 0};
    n = r['n'] is num ? (r['n'] as num).toInt() : 0;
    loaded = true;
    notifyListeners();
  }

  /// a machinery's alerts (by its number as the app knows it)
  List<VehAlert> of(String no) {
    final a = cars[no];
    if (a != null) return a;
    String key(String v) => v.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    final k = key(no);
    for (final e in cars.entries) {
      if (key(e.key) == k) return e.value;
    }
    return const [];
  }

  void clear() {
    cars = {};
    cards = [];
    count = {};
    n = 0;
    loaded = false;
  }
}
