/* Numbers and dates as the people at the sites read them: 1,240 · 12,34,567 (Indian grouping) · 13-10-2026. */

String fmtNum(num? n, {int maxDecimals = 2}) {
  if (n == null) return '–';
  final neg = n < 0;
  final v = n.abs();
  var s = v.toStringAsFixed(maxDecimals);
  if (s.contains('.')) s = s.replaceFirst(RegExp(r'\.?0+$'), '');
  final parts = s.split('.');
  var whole = parts[0];
  if (whole.length > 3) {
    final last3 = whole.substring(whole.length - 3);
    var rest = whole.substring(0, whole.length - 3);
    final groups = <String>[];
    while (rest.length > 2) {
      groups.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) groups.insert(0, rest);
    whole = '${groups.join(',')},$last3';
  }
  return (neg ? '−' : '') + whole + (parts.length > 1 ? '.${parts[1]}' : '');
}

num? asNum(dynamic v) {
  if (v == null || v == '') return null;
  if (v is num) return v;
  return num.tryParse(v.toString().replaceAll(',', '').trim());
}

/// '2026-10-13' → '13-10-2026'
String showDate(String? key) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(key ?? '');
  return m == null ? (key ?? '') : '${m.group(3)}-${m.group(2)}-${m.group(1)}';
}

String dateKey(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime parseKey(String key) {
  final p = key.split('-').map(int.parse).toList();
  return DateTime(p[0], p[1], p[2]);
}

const weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// (3.2.0) A time of the server (ISO) as the people read it: 16-10-2026 13:54 ('' when there is none).
String whenText(String? iso) {
  final t = DateTime.tryParse(iso ?? '')?.toLocal();
  if (t == null) return '';
  String p(int n) => n.toString().padLeft(2, '0');
  return '${p(t.day)}-${p(t.month)}-${t.year} ${p(t.hour)}:${p(t.minute)}';
}

/// (3.2.0) How long ago: 12 min · 3 h 5 min · 2 day(s) ('' when there is no time).
String agoText(String? iso, [DateTime? now]) {
  final t = DateTime.tryParse(iso ?? '');
  if (t == null) return '';
  final m = (now ?? DateTime.now()).difference(t).inMinutes;
  if (m < 0) return '';
  return m < 60 ? '$m min' : m < 1440 ? '${m ~/ 60} h ${m % 60} min' : '${m ~/ 1440} day(s)';
}
