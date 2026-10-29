/* THE COMPANY'S OWN PAPERS OF THE STORE (3.62.0 – the Store's step 5, 28-10-2026: "he amche company che format ahet mala je po
 * bantil requiremet bantil te same ya format amddhe hawet"): the Purchase Order in his Diesel PO's format and the Purchase
 * Requisition Form of a requirement – the web's poPrint / reqPrint (rcl-store public/work.js) line by line, as one A4 page of HTML for
 * the phone's printing (a printer, or "Save as PDF" to send it on). Everything comes from the Store's server (poGet / reqList): the
 * PO's number as on his papers (RCL/VTR/PO/2026/0128), its Amount in word, the supplier from the Vendor Master, the company's heading
 * (name, address, GST, PAN and the Papers of Store Settings – e-mail, contact, CIN, web). Every value is escaped. */
library;

String _e(Object? s) => '${s ?? ''}'.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;').replaceAll("'", '&#39;');
String _nl(Object? s) => _e(s).replaceAll('\n', '<br>');
num _n(Object? v) => v is num ? v : num.tryParse('${v ?? ''}'.replaceAll(',', '')) ?? 0;
bool _blank(Object? v) => v == null || '$v'.trim().isEmpty;

/// yyyy-mm-dd → dd-mm-yyyy (the web's dmy)
/// (3.66.0) a time the server keeps (UTC, "2026-10-29T19:00:00.000Z") as India's (its date: 30-10-2026) – a photo's "when"
String istOf(Object? t) {
  final d = DateTime.tryParse('${t ?? ''}');
  return d == null ? '${t ?? ''}' : d.toUtc().add(const Duration(hours: 5, minutes: 30)).toIso8601String();
}

String paperDmy(Object? d) {
  final s = '${d ?? ''}';
  if (s.length < 10) return s;
  final p = s.substring(0, 10).split('-');
  return p.length == 3 ? '${p[2]}-${p[1]}-${p[0]}' : s;
}

String _grp(String whole) {
  if (whole.length <= 3) return whole;
  final last3 = whole.substring(whole.length - 3);
  var rest = whole.substring(0, whole.length - 3);
  final g = <String>[];
  while (rest.length > 2) {
    g.insert(0, rest.substring(rest.length - 2));
    rest = rest.substring(0, rest.length - 2);
  }
  if (rest.isNotEmpty) g.insert(0, rest);
  return '${g.join(',')},$last3';
}

/// A number as the web's toLocaleString('en-IN', { minimumFractionDigits: min, maximumFractionDigits: max }) – 2,25,699.00
String paperNum(Object? v, {int min = 2, int max = 2}) {
  final n = _n(v);
  var s = n.abs().toStringAsFixed(max);
  if (max > min) {
    var parts = s.split('.');
    var frac = parts.length > 1 ? parts[1] : '';
    while (frac.length > min && frac.endsWith('0')) {
      frac = frac.substring(0, frac.length - 1);
    }
    s = frac.isEmpty ? parts[0] : '${parts[0]}.$frac';
  }
  final p = s.split('.');
  return '${n < 0 ? '-' : ''}${_grp(p[0])}${p.length > 1 && p[1].isNotEmpty ? '.${p[1]}' : ''}';
}

// the page: the web's printHtml (A4, its base look) with the papers' own look (PCSS)
const _base = '@page{size:A4 portrait;margin:10mm}body{font:12px Arial,sans-serif;color:#000;margin:0}h1{font-size:17px;margin:0 0 2px}h2{font-size:14px;margin:8px 0 4px}'
    'table{border-collapse:collapse;width:100%}th,td{border:1px solid #444;padding:3px 5px;text-align:left;vertical-align:top}th{background:#eee}td.n,th.n{text-align:right}.muted{color:#555}';
const _pcss = '.fm{font:11px Arial,sans-serif}.fm table{border-collapse:collapse;width:100%}.fm td,.fm th{border:1px solid #000;padding:2px 5px;vertical-align:top}.fm .nb td{border:0;padding:1px 3px}'
    '.fm .cn{font-size:18px;font-weight:700;text-align:center}.fm .ttl{text-align:center;font-weight:700;font-size:14px}.fm .sh{text-align:center;font-weight:700;border-bottom:1px solid #000;margin:0 -5px 3px;padding-bottom:2px}'
    '.fm .r{text-align:right}.fm .c{text-align:center}.fm .sig{display:flex;justify-content:space-between;margin-top:120px;padding:0 40px}.fm .sig div{text-align:center;font-weight:700}.fm .cg{text-align:center;font-weight:700;margin-top:6px}'
    '.fm ol{margin:4px 0 0 18px;padding:0}.fm li{margin:6px 0}.fm .s2{margin-top:90px;display:flex;justify-content:space-between;padding:0 10px}.fm .s2 div{text-align:center;min-width:150px}.fm .s2 span{display:block;border-top:1px solid #000;margin-top:2px}'
    // (3.66.0) a requirement's photos (the web's 29-10-2026): two a row, each with who added it and when
    '.fm .phg{display:grid;grid-template-columns:1fr 1fr;gap:8px}.fm figure{margin:0;break-inside:avoid;page-break-inside:avoid;text-align:center;border:1px solid #ccc;padding:4px}.fm figure img{max-width:100%;max-height:115mm;object-fit:contain}.fm figcaption{font-size:10px;color:#333;margin-top:2px}';
String _page(String title, String body) =>
    '<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>${_e(title)}</title><style>$_base$_pcss</style></head><body>$body</body></html>';

/// The logo on top, as the web's logoOf: the company's own (the Portal's – https / data), else the one given (the app's own Rachana
/// picture, a data: address – Rachana's company), else its name.
String _logo(Map h, String logo) {
  final own = '${h['logo'] ?? ''}';
  if (RegExp(r'^(https://|data:image/)').hasMatch(own)) return '<img src="${_e(own)}" alt="" style="max-height:70px;max-width:100%">';
  if (logo.isNotEmpty) return '<img src="${_e(logo)}" alt="" style="max-height:70px;max-width:100%">';
  return '<b style="font-size:22px">${_e(h['company'])}</b>';
}

String _kv(List<(String, String)> rows) => '<table class="nb">${rows.map((r) => '<tr><td style="width:95px">${_e(r.$1)}</td><td style="width:10px">-</td><td>${r.$2}</td></tr>').join()}</table>';

/// The Purchase Order (poGet: po, heading, supplier) – the Diesel PO's format.
String poPaperHtml(Map po, Map heading, Map supplier, {String logo = ''}) {
  final p = po, h = heading, sup = supplier;
  final lines = (p['lines'] as List? ?? const []).whereType<Map>().toList();
  final head = StringBuffer()
    ..write('<table><tr><td style="width:50%;text-align:center;vertical-align:middle;border-right:0">${_logo(h, logo)}</td><td style="border-left:1px solid #000"><div class="cn">${_e(h['company'])}</div>')
    ..write('<div class="c">${_nl(h['address'])}</div><table class="nb">')
    ..write('<tr><td><b>Email ID.</b> : ${_e(h['email'])}</td><td><b>Contact</b> : ${_e(h['phone'])}</td></tr><tr><td><b>CIN No</b> : ${_e(h['cin'])}</td><td><b>Web</b> : ${_e(h['web'])}</td></tr>')
    ..write('<tr><td><b>GST No</b> : ${_e(h['gstin'])}</td><td><b>PAN No</b> : ${_e(h['pan'])}</td></tr></table></td></tr><tr><td colspan="2" class="ttl">Purchase Order</td></tr>')
    ..write('<tr><td style="width:50%"><div class="sh">Supplier Details</div>')
    ..write(_kv([
      ('Name', '<b>${_e(_blank(sup['name']) ? p['vendor'] : sup['name'])}</b>'),
      ('Address', _nl(sup['address'])),
      ('Mobile No.', _e(sup['mobile'])),
      ('E-mail', _e(sup['email'])),
      ('Contact Person', _e(sup['contact'])),
      ('GSTIN No', _e(_blank(sup['gstin']) ? (p['vendor_gst'] ?? '') : sup['gstin'])),
    ]))
    ..write('</td><td><div class="sh">PO Details</div>')
    ..write(_kv([
      ('PO No.', '<b>${_e(_blank(p['ref']) ? p['no'] : p['ref'])}</b>'),
      ('PO Date', paperDmy(p['date'])),
      ('Credit Period', p['credit_days'] == null || '${p['credit_days']}'.isEmpty ? '' : '${_e(p['credit_days'])} Days'),
      ('Project Name', _e(_blank(h['site']) ? (p['site'] ?? '') : h['site'])),
      ('Site Contact', _e(p['site_contact'])),
      if (!_blank(p['deliver_by'])) ('Delivery by', paperDmy(p['deliver_by'])),
    ]))
    ..write('<div class="sh" style="border-top:1px solid #000;padding-top:2px;margin-top:3px">Shipping Address</div>${_nl(p['ship_to'])}</td></tr></table>');
  final rows = StringBuffer();
  for (final (i, l) in lines.indexed) {
    final name = '${l['name'] ?? ''}${_blank(l['spec']) ? '' : ' - ${l['spec']}'}';
    rows.write('<tr><td class="c">${i + 1}</td><td>${_e(name)}</td><td class="c">${_e(_blank(l['brand']) ? '-' : l['brand'])}</td><td class="c">${_e(l['hsn'])}</td><td class="r">${paperNum(l['gst_pct'])}'
        '</td><td class="r">${paperNum(l['qty'], min: 1, max: 3)}</td><td class="c">${_e(l['unit'])}</td><td class="r">${paperNum(l['rate'])}</td><td class="r">${paperNum(l['disc_pct'])}</td><td class="r">${paperNum(l['taxable'])}</td></tr>');
  }
  num sum(String k) => lines.fold<num>(0, (a, l) => a + _n(l[k]));
  final disc = sum('disc'), gross = sum('taxable'), gst = _n(p['gst']);
  String row(String t, Object? v, [bool b = false]) => '<tr><td colspan="9"><b>${_e(t)}</b></td><td class="r">${b ? '<b>${paperNum(v)}</b>' : paperNum(v)}</td></tr>';
  final items = '<table style="margin-top:6px"><thead><tr><th>S.N.</th><th>Item Description- Specification</th><th>Brand</th><th>HSN</th><th>GST %</th><th>Qty</th><th>Unit</th><th>Rate</th><th>Disc. %</th><th>Amount</th></tr></thead><tbody>$rows'
      '${row('Total Disc. Amount', disc)}${row('Gross Amount', gross)}${gst > 0 ? row('Total GST Amount', gst) : ''}<tr><td colspan="10" style="height:22px"></td></tr>'
      '${row('Total Freight Charges', p['freight'] ?? 0)}${row('Total Load / Unload Amount', p['load_unload'] ?? 0)}${row('TOTAL AMOUNT (Rs.)', p['total'], true)}'
      '<tr><td colspan="2"><b>Amount in word :</b></td><td colspan="8"><b>${_e(p['words'])}</b></td></tr></tbody></table>';
  final terms = '${p['terms'] ?? ''}'.split('\n').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
  final numbered = terms.isNotEmpty && terms.every((t) => RegExp(r'^\d+[.)]').hasMatch(t));
  final tc = terms.isEmpty
      ? ''
      : '<p style="margin-top:14px"><b>Terms And Conditions:</b></p>${numbered ? terms.map((t) => '<p style="margin:6px 0">${_e(t)}</p>').join() : '<ol>${terms.map((t) => '<li>${_e(t)}</li>').join()}</ol>'}';
  final ap = p['appr'] == 'Waiting' ? '(waiting for approval)' : p['appr'] == 'Rejected' ? '(rejected)' : _e(p['appr_name']);
  return _page('PO ${_blank(p['ref']) ? p['no'] : p['ref']}',
      '<div class="fm">$head$items<p style="margin-top:8px"><b>Remark:</b> ${_e(p['remark'])}</p>$tc<div class="sig"><div>${_e(p['created_name'])}<br><br>Prepared By</div><div>$ap<br><br>Approved By</div></div>'
      '<div class="cg">This Purchase Order is computer generated it does not require signature.</div></div>');
}

/// The Purchase Requisition Form of a requirement (reqList: the requirement, its heading): Prepared By – who made it; Checked By – the
/// levels that approved before the last; Approved By – the last.
String reqPaperHtml(Map x, Map heading, {String logo = '', List<Map> photos = const []}) {
  final h = heading, lines = (x['lines'] as List? ?? const []).whereType<Map>().toList();
  final ok = (x['approvals'] as List? ?? const []).whereType<Map>().where((a) => a['ok'] == true).toList();
  final done = x['status'] == 'Approved' || x['status'] == 'Closed';
  final last = done && ok.isNotEmpty ? ok.last : null;
  final checked = (last != null ? ok.sublist(0, ok.length - 1) : ok).map((a) => '${a['name'] ?? ''}').join(', ');
  final appr = last != null ? '${last['name'] ?? ''}' : x['status'] == 'Pending' ? '(waiting – level ${x['level']})' : x['status'] == 'Rejected' ? '(rejected)' : '';
  String slash(Object? d) => paperDmy(d).replaceAll('-', '/');
  final forText = '${x['for_kind'] ?? ''}${_blank(x['for_text']) ? '' : ' – ${x['for_text']}'}';
  // (3.65.0, as the web's 29-10-2026: "print war rachana address nahi site address nahi ani rachana logo nahiye") the company's address and
  // details as the PO's heading, and the site's address (Store Settings → Papers → Site Address; else the Shipping Address)
  final head = '<table><tr><td style="width:50%;text-align:center;vertical-align:middle;border-right:0">${_logo(h, logo)}</td><td style="border-left:1px solid #000"><div class="cn">${_e(h['company'])}</div>'
      '${_blank(h['address']) ? '' : '<div class="c">${_nl(h['address'])}</div>'}<table class="nb">'
      '<tr><td><b>Email ID.</b> : ${_e(h['email'])}</td><td><b>Contact</b> : ${_e(h['phone'])}</td></tr><tr><td><b>CIN No</b> : ${_e(h['cin'])}</td><td><b>Web</b> : ${_e(h['web'])}</td></tr>'
      '<tr><td><b>GST No</b> : ${_e(h['gstin'])}</td><td><b>PAN No</b> : ${_e(h['pan'])}</td></tr></table></td></tr>'
      '<tr><td colspan="2" class="ttl" style="font-size:16px">Purchase Requisition Form</td></tr></table>'
      '<table class="nb" style="border:1px solid #000;border-top:0"><tr><td style="width:15%">Project Name :</td><td style="width:45%">${_e(h['site'])}</td><td style="width:15%">Sub Project :</td><td>${_e(forText)}</td></tr>'
      '<tr><td>Site Address :</td><td colspan="3">${_nl(h['site_address'])}</td></tr>'
      '<tr><td>Indent No. :</td><td>${_e(_blank(x['ref']) ? x['no'] : x['ref'])}</td><td>Date :</td><td>${slash(x['date'])}</td></tr></table>';
  final rows = StringBuffer();
  for (final (i, l) in lines.indexed) {
    final spec = [if (!_blank(l['brand'])) 'Brand: ${l['brand']}', if (!_blank(l['spec'])) '${l['spec']}', if (!_blank(l['note'])) '${l['note']}'].join(' · ');
    rows.write('<tr><td class="c">${i + 1}</td><td class="c">${_e(l['code'])}</td><td>${_e(l['name'])}</td><td>${_e(spec)}</td><td class="c">${_e(l['unit'])}'
        '</td><td class="r">${paperNum(l['qty'], min: 1, max: 3)}</td><td class="c">${slash(_blank(x['need_by']) ? x['date'] : x['need_by'])}</td></tr>');
  }
  final items = '<table><thead><tr><th>Sr No</th><th>Item Code</th><th>Item Description</th><th>Item Specification</th><th>Unit</th><th>Quantity</th><th>Required Date</th></tr></thead><tbody>$rows</tbody></table>';
  // (3.66.0, the web's 29-10-2026: "Print मध्ये photos पण") its photos on the pages after the form
  final ph = [for (final p in photos) if (RegExp(r'^https?://').hasMatch('${p['url'] ?? ''}')) p];
  final pics = StringBuffer();
  for (final (i, p) in ph.indexed) {
    pics.write('<figure><img src="${_e(p['url'])}" alt="Photo ${i + 1}"><figcaption>Photo ${i + 1}${_blank(p['by']) ? '' : ' · ${_e(p['by'])}'}${_blank(p['at']) ? '' : ' · ${paperDmy(istOf(p['at']))}'}</figcaption></figure>');
  }
  final photoPage = ph.isEmpty
      ? ''
      : '<div class="fm" style="page-break-before:always;border:1px solid #000;padding:6px"><div class="ttl" style="margin-bottom:6px">Photos of the material – ${_e(_blank(x['ref']) ? x['no'] : x['ref'])} (${ph.length})</div><div class="phg">$pics</div></div>';
  return _page('Requirement ${_blank(x['ref']) ? x['no'] : x['ref']}',
      '<div class="fm" style="border:1px solid #000;min-height:260mm;padding:0">$head$items<p style="margin:6px">Remark:${_e(x['remark'])}</p>'
      '<div class="s2"><div>${_e(x['created_name'])}<span>Prepared By</span></div><div>${_e(checked)}<span>Checked By</span></div><div>${_e(appr)}<span>Approved By</span></div></div></div>$photoPage');
}
