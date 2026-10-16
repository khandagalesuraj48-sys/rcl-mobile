/* THE DIESEL HISTORY OF A MACHINERY (3.14.0) – the web's dhGet / dhCard / dhLine (App.html, "diesel history of the machinery
 * being filled"): its last fills up to the entry's date (dieselHistory, at most 5), the last KM / Hrs reading, this month's
 * litres; shown while a Diesel Issue is filled (one entry, and each row of "one date – many machinery"). The last reading is the
 * hint in the reading box; the driver of the last fill goes into an empty Driver box (not when an entry is changed). */
import 'rdoc.dart' show fmt;

/// "today" / "yesterday" / "N days ago" – how long ago [d] was, counted from [today] (both yyyy-mm-dd).
String dhAgo(String d, String today) {
  final a = DateTime.tryParse('${today}T00:00:00Z'), b = DateTime.tryParse('${d}T00:00:00Z');
  if (a == null || b == null) return '';
  final n = (a.difference(b).inHours / 24).round();
  return n <= 0 ? 'today' : n == 1 ? 'yesterday' : '$n days ago';
}

bool _has(Object? v) => v != null && v != '';

/// The reading of a fill: "12,345 km · 1,234 hr", or "–".
String dhRead(Map x) {
  final t = [if (_has(x['km'])) '${fmt(x['km'])} km', if (_has(x['hr'])) '${fmt(x['hr'])} hr'].join(' · ');
  return t.isEmpty ? '–' : t;
}

String _sd(Object? d) {
  final p = '${d ?? ''}'.split('-');
  return p.length >= 3 ? '${p[2]}-${p[1]}-${p[0]}' : '${d ?? ''}';
}

List<Map> dhRows(Map? h) => [for (final r in (h?['rows'] as List? ?? const [])) if (r is Map) r];

/// The one line under a row of "one date – many machinery": its last fill (null = nothing to show).
String? dhLine(Map? h, String today) {
  if (h == null) return null;
  final rows = dhRows(h);
  if (rows.isEmpty) return 'No diesel given before';
  final x = rows.first;
  return 'Last: ${_sd(x['date'])} (${dhAgo('${x['date']}', today)}) · ${fmt(x['qty'])} L · ${dhRead(x)}';
}

/// The head line of the card: last fill, last reading, this month.
String dhHead(Map h, String today) {
  final rows = dhRows(h), last = rows.isEmpty ? null : rows.first;
  final lk = h['lastKm'] is Map ? h['lastKm'] as Map : null, lh = h['lastHr'] is Map ? h['lastHr'] as Map : null;
  final rd = [if (lk != null) 'KM ${fmt(lk['value'])} (${_sd(lk['date'])})', if (lh != null) 'Hrs ${fmt(lh['value'])} (${_sd(lh['date'])})'].join(' · ');
  final mo = h['month'] is Map ? h['month'] as Map : const {};
  final n = (mo['count'] as num?)?.toInt() ?? 0;
  return [
    last != null ? 'Last fill ${_sd(last['date'])} (${dhAgo('${last['date']}', today)}) · ${fmt(last['qty'])} L' : 'No diesel given before',
    if (rd.isNotEmpty) 'Last reading $rd',
    'This month ${fmt(mo['qty'] ?? 0)} L in $n fill${n == 1 ? '' : 's'}',
  ].join(' · ');
}

/// The hint of the KM / Hrs box: "last 12,345" (empty = none).
String dhHint(Map? h, String key) {
  final v = h?[key];
  return v is Map && _has(v['value']) ? 'last ${fmt(v['value'])}' : '';
}

/// The driver of the last fill that has one ('' = none).
String dhDriver(Map? h) {
  for (final r in dhRows(h)) {
    final d = '${r['driver'] ?? ''}'.trim();
    if (d.isNotEmpty) return d;
  }
  return '';
}
