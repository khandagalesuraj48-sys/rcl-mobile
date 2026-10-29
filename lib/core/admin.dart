/* ADMINISTRATION (3.9.0) – the web's own working of its Admin pages (App.html "USERS & ACCESS", "Activity Log", "READ ME",
 * "Rules of this site"): the access report and its full list, the change lines of an activity, the SQL of the first Admin of a
 * new site. Every figure is the server's (usersAdmin, accessReport, getActivity, readme …). */

/// "Field: old → new; Field: old → new" – one per line: (the field, what changed); a line without a field: ('', it).
List<(String, String)> changeLines(String t) {
  if (t.isEmpty) return const [];
  return [
    for (final x in t.split('; '))
      if (x.contains(': ')) (x.substring(0, x.indexOf(': ')), x.substring(x.indexOf(': ') + 2)) else ('', x),
  ];
}

/// The first word of an action ("Add", "Edit", "Delete", "Login failed" …) – its colour on the web.
String actKind(String action) => action == 'Login failed' ? 'fail' : action.split(' ').first;

/// The access report, short: what is written in each access cell and the access it gives.
List<String> accessSummary(Map d) {
  final c = (d['count'] as Map?) ?? const {};
  String n(String k) => '${c[k] ?? 0}';
  return [
    'Written as Edit / View / No access: ${n('written')}',
    'EMPTY cell → counts as View today: ${n('empty')}',
    'Other text → counts as View today: ${n('unknown')}',
    'Admin (Edit everywhere, whatever the cell says): ${n('admin')}',
    'Page without its own column → taken from the page it came out of: ${n('from')}',
    'No column at all → No access: ${n('nocolumn')}',
  ];
}

/// The cells that are empty or hold other text (the report shows the first 40).
List<Map> accessOdd(Map d) => [for (final r in (d['rows'] as List? ?? const []).whereType<Map>()) if (r['why'] == 'empty' || r['why'] == 'unknown') r];

/// The full list, one line per user and page (as the web's file, for Excel).
String accessCsv(Map d) {
  String q(Object? v) {
    final s = (v == null ? '' : '$v').replaceAll('"', '""').replaceFirstMapped(RegExp(r'^([=+\-@])'), (m) => "'${m[1]}");
    return '"$s"';
  }

  final rows = [
    ['User', 'Email', 'Active', 'Admin', 'Page', 'Written in the Users table', 'Access the app gives now', 'Why'],
    for (final r in (d['rows'] as List? ?? const []).whereType<Map>())
      [r['name'], r['email'], r['active'] == true ? 'Yes' : 'No', r['admin'] == true ? 'Yes' : 'No', r['module'], r['raw'] == '' ? '(empty)' : r['raw'], r['effective'], r['why']],
  ];
  return '﻿${rows.map((r) => r.map(q).join(',')).join('\r\n')}';
}

/// SQL-3 of Read Me: the first Admin of a new site, from what is typed (a one-time password).
String adminSql(List cols0, {String email = '', String name = '', String pw = ''}) {
  String q(String v) => "'${v.replaceAll("'", "''")}'";
  final e = (email.isEmpty ? 'admin@company.com' : email).trim().toLowerCase(), n = (name.isEmpty ? 'Admin' : name).trim(), p = pw.isEmpty ? 'CHANGE-ME-123' : pw;
  final cols = [for (final c in cols0.whereType<Map>()) '${c['col']}'];
  final vals = [
    for (final c in cols)
      c == 'email'
          ? q(e)
          : c == 'password_hash'
              ? q(p)
              : c == 'name'
                  ? q(n)
                  : c == 'active' || c == 'admin'
                      ? q('Yes')
                      : RegExp(r'^perm_').hasMatch(c)
                          ? q('Edit')
                          : 'null',
  ];
  return '-- SQL-3: first Admin (one-time password – the app asks for a new one at the first sign-in)\n'
      'insert into public.app_users (id, ${cols.join(', ')})\nvalues (${q(e)}, ${vals.join(', ')})\n'
      "on conflict (id) do update set password_hash = excluded.password_hash, active = 'Yes', admin = 'Yes';"
      '${p.length < 8 ? '\n-- ⚠ password किमान 8 अक्षरांचा ठेवा' : ''}';
}

/// The access of a user on a page as shown: an Admin has Edit everywhere.
String accessOf(Map u, String module) => u['admin'] == true ? 'Edit' : '${((u['perms'] as Map?) ?? const {})[module] ?? 'None'}';

const kAccessWord = {'Admin': 'Admin', 'Edit': 'Edit', 'View': 'View', 'None': 'No access'}; // (3.64.0, update-189) Admin: a page with a date – Edit, and its entries of an earlier day
