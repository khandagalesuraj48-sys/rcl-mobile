/* (3.9.0) Administration – the web's own working of its Admin pages: an activity's change lines, the access report and its
 * full list, the SQL of a new site's first Admin (Read Me), and the small HTML reader that draws Read Me with the app's widgets. */
import 'package:flutter_test/flutter_test.dart';
import 'package:rcl_mobile/core/admin.dart';
import 'package:rcl_mobile/core/html_lite.dart';

void main() {
  test('An activity: "Field: old → new" one per line; the action\'s kind', () {
    expect(changeLines('Close KM: 15100 → 15130; Work: a → b'), [('Close KM', '15100 → 15130'), ('Work', 'a → b')]);
    expect(changeLines('Deleted the row'), [('', 'Deleted the row')]);
    expect(changeLines(''), isEmpty);
    expect([actKind('Add'), actKind('Edit many'), actKind('Login failed'), actKind('Login')], ['Add', 'Edit', 'fail', 'Login']);
  });

  test('The access report: the summary, the odd cells, the full list as the web\'s file (a formula never runs in Excel)', () {
    final d = {
      'count': {'written': 5, 'empty': 1, 'admin': 3},
      'rows': [
        {'name': 'Site Clerk', 'email': 'clerk@rcl.test', 'active': true, 'admin': false, 'module': 'Billing', 'raw': '', 'effective': 'View', 'why': 'empty'},
        {'name': '=Boss "B"', 'email': 'b@rcl.test', 'active': false, 'admin': true, 'module': 'Log Book', 'raw': 'Edit', 'effective': 'Edit', 'why': 'admin'},
      ],
    };
    expect(accessSummary(d).first, 'Written as Edit / View / No access: 5');
    expect(accessSummary(d)[2], 'Other text → counts as View today: 0');
    expect(accessOdd(d).single['email'], 'clerk@rcl.test');
    expect(accessCsv(d).split('\r\n'), [
      '﻿"User","Email","Active","Admin","Page","Written in the Users table","Access the app gives now","Why"',
      '"Site Clerk","clerk@rcl.test","Yes","No","Billing","(empty)","View","empty"',
      '"\'=Boss ""B""","b@rcl.test","No","Yes","Log Book","Edit","Edit","admin"',
    ]);
    expect(accessOf({'admin': true, 'perms': {'X': 'None'}}, 'X'), 'Edit');
    expect(accessOf({'admin': false, 'perms': {'X': 'View'}}, 'Y'), 'None');
  });

  test('Read Me SQL-3: the first Admin from what is typed – as the web\'s rmAdminSql', () {
    final cols = [{'col': 'email'}, {'col': 'name'}, {'col': 'password_hash'}, {'col': 'active'}, {'col': 'admin'}, {'col': 'perm_dashboard'}, {'col': 'mobile'}];
    expect(adminSql(cols), '-- SQL-3: first Admin (one-time password – the app asks for a new one at the first sign-in)\n'
        'insert into public.app_users (id, email, name, password_hash, active, admin, perm_dashboard, mobile)\n'
        "values ('admin@company.com', 'admin@company.com', 'Admin', 'CHANGE-ME-123', 'Yes', 'Yes', 'Edit', null)\n"
        "on conflict (id) do update set password_hash = excluded.password_hash, active = 'Yes', admin = 'Yes';");
    final x = adminSql(cols, email: ' Boss@Site.COM ', name: "D'Souza", pw: 'short');
    expect(x, contains("values ('boss@site.com', 'boss@site.com', 'D''Souza', 'short'"));
    expect(x, endsWith("\n-- ⚠ password किमान 8 अक्षरांचा ठेवा"));
  });

  test('The HTML reader: headings, paragraphs with bold and code, lists, tables, code to copy, an input; entities', () {
    final r = parseHtml('<h3 id="a">One &amp; two</h3><p>Some <b>bold</b> and <code>Code.gs</code><br>next<p>second para'
        '<ol><li>first<li>second <span class="rm-ok">✔ ok</span></ol><table class="rm-t"><tr><th>A<th>B<tr><td>1<td><b>2</b></table>'
        '<div class="rm-code"><button>Copy</button><pre id="s1">select 1;\nselect &lt;2&gt;;</pre></div><label>Email <input id="rm_ad_email" placeholder="x@y"></label><!-- a note -->');
    final tags = r.kids.map((k) => k.tag).toList();
    expect(tags, ['h3', 'p', 'p', 'ol', 'table', 'div', 'label']);
    expect(r.kids[0].plain, 'One & two');
    expect(r.kids[0].attr('id'), 'a');
    expect(r.kids[1].plain, 'Some bold and Code.gs\nnext');
    expect(r.kids[2].plain, 'second para', reason: 'a new <p> closes the one open');
    expect(r.kids[3].kids.map((k) => k.plain).toList(), ['first', 'second ✔ ok']);
    expect(r.kids[3].kids[1].kids.last.has('rm-ok'), true);
    final rows = r.kids[4].all().where((x) => x.tag == 'tr').toList();
    expect(rows.map((tr) => tr.kids.map((c) => '${c.tag}:${c.plain}').join('|')).toList(), ['th:A|th:B', 'td:1|td:2']);
    expect(r.kids[5].all().firstWhere((x) => x.tag == 'pre').plain, 'select 1;\nselect <2>;');
    final input = r.kids[6].all().firstWhere((x) => x.tag == 'input');
    expect([input.attr('id'), input.attr('placeholder'), input.kids.length], ['rm_ad_email', 'x@y', 0]);
    expect(unescapeHtml('&#8377; &#x20B9; &nbsp;&rarr; &unknown;'), '₹ ₹  → &unknown;');
  });
}
