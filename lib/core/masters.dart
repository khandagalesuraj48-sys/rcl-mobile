/* THE OTHER MASTERS' RULES (3.4.0) – Vendor Master, Vendor BOQ, Vehicle Compliance and Log Book Format, as the web works them
 * out on its page (Mechanical App.html: renderVendors / gstRead, boqLineText / bTaken / bNextNo, cpRender, LB_FORMATS). The
 * server checks and saves everything (saveVendor, saveBoq, renewDoc, saveCmpRules, saveLbFormats …). */
import 'format.dart';

String _s(dynamic v) => v == null ? '' : '$v';
String rupees(dynamic v) => '₹${fmtNum(asNum(v) ?? 0)}';

/* ================= VENDORS ================= */
List<Map<String, dynamic>> machinesOfVendor(Map<String, dynamic> v) => [for (final m in (v['machines'] as List? ?? const []).whereType<Map>()) m.cast<String, dynamic>()];

/// "Own company" · "Complete" · "Incomplete" · "Not filled" (and its tone), as the web's list.
(String, String) vendorState(Map<String, dynamic> v) {
  final ms = machinesOfVendor(v);
  if (ms.isNotEmpty && ms.every((m) => m['ownership'] == 'Own') && v['saved'] != true) return ('Own company', 'good');
  if (v['complete'] == true) return ('Complete', 'good');
  return v['saved'] == true ? ('Incomplete', 'warn') : ('Not filled', 'bad');
}

/// The vendors shown: search (name, GST, PAN) and Details (all / missing / done).
List<Map<String, dynamic>> vendorsShown(List<Map<String, dynamic>> all, String q, String st, {String ty = ''}) {
  final qq = q.trim().toUpperCase();
  return all.where((v) => (qq.isEmpty || [v['name'], v['gst'], v['pan']].map(_s).join(' ').toUpperCase().contains(qq)) && (st.isEmpty || (st == 'done' ? v['complete'] == true : v['complete'] != true)) &&
      (ty.isEmpty || (ty == 'mat') == (v['type'] == kMatSup))).toList();
}

/// (3.57.0, Mechanical update-181) a Material Supplier – made by the Store's import of its old inward register: in the Vendor Master
/// (marked, its own filter), not offered for an asset's owner, a BOQ, a bill or a payment – unless it has machinery or a BOQ here
/// (the web's matOnly; the server's parties list the same)
const kMatSup = 'Material Supplier';
bool vendorMatOnly(Map v) => v['type'] == kMatSup && (v['machines'] as List? ?? const []).isEmpty && ((v['boqs'] as num?) ?? 0) == 0;

String bankText(Map<String, dynamic> v) {
  final b = _s(v['bank']), a = _s(v['account']);
  if (b.isEmpty) return '–';
  return a.isEmpty ? b : '$b · ${(a.length > 4 ? a.substring(a.length - 4) : a).padLeft(8, '•')}';
}

const kGstStates = {
  '01': 'Jammu & Kashmir', '02': 'Himachal Pradesh', '03': 'Punjab', '04': 'Chandigarh', '05': 'Uttarakhand', '06': 'Haryana', '07': 'Delhi', '08': 'Rajasthan', '09': 'Uttar Pradesh', '10': 'Bihar',
  '11': 'Sikkim', '12': 'Arunachal Pradesh', '13': 'Nagaland', '14': 'Manipur', '15': 'Mizoram', '16': 'Tripura', '17': 'Meghalaya', '18': 'Assam', '19': 'West Bengal', '20': 'Jharkhand', '21': 'Odisha', '22': 'Chhattisgarh',
  '23': 'Madhya Pradesh', '24': 'Gujarat', '25': 'Daman & Diu', '26': 'Dadra & Nagar Haveli and Daman & Diu', '27': 'Maharashtra', '28': 'Andhra Pradesh (old)', '29': 'Karnataka', '30': 'Goa', '31': 'Lakshadweep', '32': 'Kerala',
  '33': 'Tamil Nadu', '34': 'Puducherry', '35': 'Andaman & Nicobar Islands', '36': 'Telangana', '37': 'Andhra Pradesh', '38': 'Ladakh', '97': 'Other Territory', '99': 'Centre Jurisdiction',
};
const kPanKinds = {'P': 'Individual / Proprietor', 'C': 'Company', 'H': 'HUF', 'F': 'Firm / LLP', 'A': 'Association of Persons', 'T': 'Trust', 'B': 'Body of Individuals', 'L': 'Local Authority', 'J': 'Artificial Juridical Person', 'G': 'Government'};

/// The 15th character of a GST number, worked out from the first 14 (its check letter).
String gstCheckLetter(String g) {
  const c = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  var t = 0;
  for (var i = 0; i < 14; i++) {
    final x = c.indexOf(g[i]);
    if (x < 0) return '';
    final p = x * (i % 2 == 1 ? 2 : 1);
    t += p ~/ 36 + p % 36;
  }
  return c[(36 - t % 36) % 36];
}

class GstRead {
  const GstRead({this.bad = '', this.gst = '', this.pan = '', this.state = '', this.code = '', this.kind = ''});
  final String bad, gst, pan, state, code, kind;
}

/// What a whole GST number says (null while it is not 15 characters) – as the web's gstRead.
GstRead? gstRead(String v) {
  final g = v.toUpperCase().replaceAll(RegExp(r'\s'), '');
  if (g.length != 15) return null;
  if (!RegExp(r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]$').hasMatch(g)) return GstRead(bad: 'GST number "$g" is not in the right format (2 digits of the State, the PAN, entity number, Z, check letter).');
  if (kGstStates[g.substring(0, 2)] == null) return GstRead(bad: 'GST number: "${g.substring(0, 2)}" is not a State code.');
  final want = gstCheckLetter(g);
  if (want != g[14]) return GstRead(bad: 'GST number: the last letter does not fit the rest – one character is mistyped (for these 14 characters it would be "$want"). Check it against the certificate.');
  return GstRead(gst: g, pan: g.substring(2, 12), state: kGstStates[g.substring(0, 2)]!, code: g.substring(0, 2), kind: kPanKinds[g[5]] ?? '');
}

/* ================= BOQ ================= */
const kBoqBasis = ['Monthly', 'Per Day', 'Per Hour', 'Per KM', 'Per Trip', 'Item-wise', 'No rent – diesel only'];
const kBoqBasisWords = {'Monthly': 'Monthly (per month)', 'Per Day': 'Daily (per day)', 'Per Hour': 'Hourly (per hour)', 'Per KM': 'Per KM', 'Per Trip': 'Per trip', 'Item-wise': 'Item-wise (several items, own rates)', 'No rent – diesel only': 'No rent – diesel only'};
const kItemBasis = ['Per Hour', 'Per Day', 'Monthly', 'Per KM', 'Per Trip'];
const kItemBasisWords = {'Monthly': 'Monthly', 'Per Day': 'Per day', 'Per Hour': 'Per hour', 'Per KM': 'Per KM', 'Per Trip': 'Per trip'};
String itemKind(String b) => b == 'Per Hour' ? 'hr' : b == 'Per KM' ? 'km' : b == 'Per Trip' ? 'trip' : 'day';

List<Map<String, dynamic>> _maps(dynamic l) => [for (final x in (l as List? ?? const []).whereType<Map>()) x.cast<String, dynamic>()];

String _slabsText(List<Map<String, dynamic>> slabs, String slabOn) =>
    'Per Hour: ${[for (final (k, s) in slabs.indexed) '${k == 0 ? 'first ${fmtNum(asNum(s['upTo']))} hr' : _s(s['upTo']).isEmpty ? 'after that' : 'up to ${fmtNum(asNum(s['upTo']))} hr'} ${rupees(s['rate'])}'].join(', ')} (${slabOn == 'Period' ? 'on total hrs' : 'each day'})';

String boqRateText(Map<String, dynamic> l) {
  final slabs = _maps(l['slabs']);
  return slabs.isNotEmpty ? _slabsText(slabs, _s(l['slabOn'])) : '${l['basis']} ${rupees(l['rate'])}';
}

/// One BOQ line in words (as the web's boqLineText).
String boqLineText(Map<String, dynamic> l) {
  final items = _maps(l['items']), slabs = _maps(l['slabs']);
  if (items.isNotEmpty) return 'Item-wise: ${items.map((it) => '${it['name']} – ${boqRateText(it)}${it['qty'] == 'typed' ? ' [typed in Log Book]' : ''}').join('; ')}';
  if (slabs.isNotEmpty) return _slabsText(slabs, _s(l['slabOn']));
  if (l['basis'] == 'No rent – diesel only') return 'No rent – diesel only (all diesel debited)';
  return '${l['basis']} ${rupees(l['rate'])}${(asNum(l['nightRate']) ?? 0) > 0 ? ', Night trip ${rupees(l['nightRate'])}' : ''}';
}

String boqDieselText(Map<String, dynamic> l) => l['diesel'] == 'Debit Basis' ? 'diesel: debit basis' : 'diesel: company paid';

/// The next BOQ number of a vendor (vendor-wise).
String boqNextNo(List<Map<String, dynamic>> boqs, String vendor) {
  var m = 0;
  for (final x in boqs.where((x) => x['vendor'] == vendor)) {
    final n = RegExp(r'^\d+$').hasMatch(_s(x['no'])) ? int.parse(_s(x['no'])) : 0;
    if (n > m) m = n;
  }
  return '${m + 1}';
}

/// Machinery of this vendor already in another BOQ (not an amendment) for these dates → that BOQ (as the web's bTaken).
Map<String, Map<String, dynamic>> boqTaken(List<Map<String, dynamic>> boqs, {required String vendor, required String from, required String to, required String mode, String editId = ''}) {
  final out = <String, Map<String, dynamic>>{};
  if (mode == 'amend') return out; // an amendment is meant to change machinery that are in the BOQ
  final end = to.isEmpty ? '9999-12-31' : to;
  for (final x in boqs) {
    if (_s(x['amendOf']).isNotEmpty || x['vendor'] != vendor || (mode == 'edit' && x['id'] == editId)) continue;
    if (_s(x['from']).compareTo(end) > 0 || (_s(x['to']).isEmpty ? '9999-12-31' : _s(x['to'])).compareTo(from) < 0) continue;
    for (final l in _maps(x['lines'])) {
      out[_s(l['no'])] = x;
    }
  }
  return out;
}

/// One line of the BOQ form (the same shape as a saved line).
class BoqLine {
  BoqLine({this.no = '', this.basis = 'Monthly', this.rate = '', this.nightRate = '', this.slabOn = 'Day', this.diesel = 'Company', this.remark = '', List<BoqSlab>? slabs, List<BoqItem>? items})
      : slabs = slabs ?? [],
        items = items ?? [];
  String no, basis, rate, nightRate, slabOn, diesel, remark;
  final List<BoqSlab> slabs;
  final List<BoqItem> items;

  factory BoqLine.of(Map<String, dynamic> l) => BoqLine(
        no: _s(l['no']),
        basis: kBoqBasis.contains(_s(l['basis'])) ? _s(l['basis']) : 'Monthly',
        rate: _maps(l['slabs']).isNotEmpty || (asNum(l['rate']) ?? 0) == 0 ? '' : _numText(l['rate']),
        nightRate: (asNum(l['nightRate']) ?? 0) > 0 ? _numText(l['nightRate']) : '',
        slabOn: l['slabOn'] == 'Period' ? 'Period' : 'Day',
        diesel: l['diesel'] == 'Debit Basis' ? 'Debit Basis' : 'Company',
        remark: _s(l['remark']),
        slabs: [for (final s in _maps(l['slabs'])) BoqSlab(_s(s['upTo']), _numText(s['rate']))],
        items: [for (final it in _maps(l['items'])) BoqItem.of(it)],
      );

  /// A copy with the same terms for another machinery ("same terms → other machinery").
  BoqLine sameFor(String id) => BoqLine(no: id, basis: basis, rate: rate, nightRate: nightRate, slabOn: slabOn, diesel: diesel, slabs: [for (final s in slabs) BoqSlab(s.upTo, s.rate)], items: [for (final it in items) it.copy()]);

  bool get empty => no.isEmpty && rate.isEmpty && slabs.isEmpty && items.isEmpty;

  Map<String, dynamic> toJson() => {
        'no': no, 'basis': basis, 'rate': rate, 'nightRate': basis == 'Per Trip' ? nightRate : '',
        'slabs': [for (final s in slabs) {'upTo': s.upTo, 'rate': s.rate}], 'slabOn': slabs.isEmpty ? '' : slabOn,
        'items': basis == 'Item-wise' ? [for (final it in items) it.toJson()] : <Map<String, dynamic>>[],
        'diesel': diesel, 'remark': remark,
      };

  /// The rules of the form (bNumber): slabs only by the hour, no rent = all diesel debited, Item-wise: the rate per item.
  void tidy() {
    if (basis != 'Per Hour') slabs.clear();
    if (slabs.isNotEmpty) rate = '';
    if (basis == 'No rent – diesel only') {
      rate = '';
      diesel = 'Debit Basis';
    }
    if (basis == 'Item-wise') {
      rate = '';
      if (items.isEmpty) items.addAll([BoqItem(qty: 'rest'), BoqItem(qty: 'typed')]);
    }
    for (final it in items) {
      if (it.basis != 'Per Hour') it.slabs.clear();
      if (it.slabs.isNotEmpty) it.rate = '';
    }
  }

  /// "Monthly ₹30,000 · company diesel" (the "same terms" question).
  String get termsText => '${basis == 'Item-wise' ? 'Item-wise: ${items.isEmpty ? 'no items yet' : items.map((it) => '${it.name} ₹${it.slabs.isNotEmpty ? 'slabs' : it.rate} ${it.basis.replaceFirst('Per ', '/ ').toLowerCase()}').join(', ')}' : '$basis${slabs.isNotEmpty ? ' – ${slabs.map((x) => '${x.upTo.isEmpty ? 'after that' : 'up to ${x.upTo} hr'} ₹${x.rate}').join(', ')}' : rate.isNotEmpty ? ' ₹$rate' : ''}'} · ${diesel == 'Debit Basis' ? 'all diesel debited' : 'company diesel'}';
}

class BoqSlab {
  BoqSlab(this.upTo, this.rate);
  String upTo, rate;
}

class BoqItem {
  BoqItem({this.name = '', this.basis = 'Per Hour', this.rate = '', this.qty = 'rest', this.slabOn = 'Day', List<BoqSlab>? slabs}) : slabs = slabs ?? [];
  String name, basis, rate, qty, slabOn;
  final List<BoqSlab> slabs;
  factory BoqItem.of(Map<String, dynamic> it) => BoqItem(
        name: _s(it['name']),
        basis: kItemBasis.contains(_s(it['basis'])) ? _s(it['basis']) : 'Per Hour',
        rate: _maps(it['slabs']).isNotEmpty || (asNum(it['rate']) ?? 0) == 0 ? '' : _numText(it['rate']),
        qty: it['qty'] == 'typed' ? 'typed' : 'rest',
        slabOn: it['slabOn'] == 'Period' ? 'Period' : 'Day',
        slabs: [for (final s in _maps(it['slabs'])) BoqSlab(_s(s['upTo']), _numText(s['rate']))],
      );
  BoqItem copy() => BoqItem(name: name, basis: basis, rate: rate, qty: qty, slabOn: slabOn, slabs: [for (final s in slabs) BoqSlab(s.upTo, s.rate)]);
  Map<String, dynamic> toJson() => {'name': name, 'basis': basis, 'rate': rate, 'qty': qty, 'slabOn': slabs.isEmpty ? '' : slabOn, 'slabs': [for (final s in slabs) {'upTo': s.upTo, 'rate': s.rate}]};
}

String _numText(dynamic v) {
  final n = asNum(v);
  if (n == null) return _s(v);
  return n == n.roundToDouble() ? n.toInt().toString() : n.toString();
}

/* ================= VEHICLE COMPLIANCE ================= */
const kCmpChips = [('attention', 'Needs attention'), ('expired', 'Expired'), ('due', 'Due in 30 days'), ('missing', 'Not entered'), ('all', 'All machinery')];
/// (3.59.0, Mechanical update-184: "asset master madhe papers fkt own mhanje rachana che ghenar mi je rental debit or other aahet tyanche
/// atatchment nko") the papers only of Own machinery – the server gives only those; no ownership choice any more (as the web's cp_own)
const kCmpOwn = [('', 'Own')];

List<String> cmpDocs(Map<String, dynamic> d) => [for (final x in (d['docs'] as List? ?? const [])) '$x'];
Map<String, dynamic> cmpDoc(Map<String, dynamic> m, String k) => ((m['docs'] as Map?)?[k] as Map?)?.cast<String, dynamic>() ?? const {'s': 'notreq', 'v': '', 'days': ''};

bool cmpChipHas(Map<String, dynamic> d, Map<String, dynamic> m, String chip) {
  final docs = cmpDocs(d);
  bool any(List<String> st) => docs.any((k) => st.contains(cmpDoc(m, k)['s']));
  return switch (chip) { 'attention' => any(['expired', 'due', 'missing']), 'expired' => any(['expired']), 'due' => any(['due']), 'missing' => any(['missing']), _ => true };
}

/// The machinery of the filters (ownership, search) – before the chip.
List<Map<String, dynamic>> cmpBase(Map<String, dynamic> d, String own, String q) {
  final qq = q.trim().toUpperCase();
  return [
    for (final m in _maps(d['machines']))
      if ((own.isEmpty || own.split(',').contains(m['ownership'])) && (qq.isEmpty || '${m['no']} ${m['owner']} ${m['type']}'.toUpperCase().contains(qq))) m,
  ];
}

/// The rows of a chip, the worst first (as the web's rank).
List<Map<String, dynamic>> cmpRows(Map<String, dynamic> d, List<Map<String, dynamic>> base, String chip) {
  final docs = cmpDocs(d);
  int rank(Map<String, dynamic> m) => docs.fold(0, (r, k) => r + switch (cmpDoc(m, k)['s']) { 'expired' => 100, 'due' => 10, 'missing' => 1, _ => 0 });
  return base.where((m) => cmpChipHas(d, m, chip)).toList()
    ..sort((a, b) {
      final x = rank(b) - rank(a);
      return x != 0 ? x : _s(a['no']).compareTo(_s(b['no']));
    });
}

/// The four cards: expired, due, not entered, valid (papers and machinery).
Map<String, int> cmpCounts(Map<String, dynamic> d, List<Map<String, dynamic>> base) {
  final docs = cmpDocs(d), out = <String, int>{};
  for (final m in base) {
    for (final k in docs) {
      final s = '${cmpDoc(m, k)['s']}';
      if (s == 'notreq') continue;
      out[s] = (out[s] ?? 0) + 1;
    }
  }
  for (final s in ['expired', 'due', 'missing']) {
    out['m$s'] = base.where((m) => docs.any((k) => cmpDoc(m, k)['s'] == s)).length;
  }
  return out;
}

/// A paper's words: its date / Lifetime / N/A / Not entered, and what it means (expired 3 days ago, in 12 days …).
(String, String) cmpCellText(Map<String, dynamic> x) {
  final s = '${x['s']}', days = (asNum(x['days']) ?? 0).toInt();
  if (s == 'notreq') return ('—', 'not needed');
  final lab = s == 'life' ? 'Lifetime' : s == 'na' ? 'N/A' : s == 'missing' ? 'Not entered' : showDate('${x['v']}');
  final sub = switch (s) {
    'expired' => 'expired ${-days} day${days == -1 ? '' : 's'} ago',
    'due' => days == 0 ? 'expires today' : 'in $days day${days == 1 ? '' : 's'}',
    'ok' => 'valid',
    'life' => 'tax paid for life',
    'missing' => 'enter the date',
    _ => 'not applicable',
  };
  return (lab, sub);
}

String cmpDateWords(dynamic v) {
  final s = _s(v);
  return s == 'NA' ? 'N/A' : s == 'LIFETIME' ? 'Lifetime' : s.isNotEmpty ? showDate(s) : '–';
}

const kCmpPresets = [('All', ['Tax', 'PUC', 'Permit', 'Fitness', 'Insurance']), ('No permit', ['Tax', 'PUC', 'Fitness', 'Insurance']), ('Insurance only', ['Insurance']), ('None', <String>[])];

/* ================= LOG BOOK FORMAT ================= */
class LbFormat {
  const LbFormat(this.id, this.name, this.about);
  final String id, name, about;
}

const kLbFormats = [
  LbFormat('A', 'Format A – Standard Log Book (Monthly)', 'Unit, reading / work (KM, Hrs, Time, Trip), diesel with refilling reading, average, chainage, work.'),
  LbFormat('B', 'Format B – KM + Hrs + Trip', 'KM reading, Hrs reading, diesel, trip, chainage, work.'),
  LbFormat('C', 'Format C – KM', 'KM reading, diesel with refilling reading, average, work.'),
  LbFormat('D', 'Format D – Hrs', 'Hrs reading, diesel with refilling reading, average, chainage, work.'),
  LbFormat('E', 'Format E – Particular / Challan (reading)', 'Particular, challan no, start / closed reading, total hrs, diesel, average, chainage, work – no shift.'),
  LbFormat('F', 'Format F – Time sheet', 'Reg no, particular, challan no, start / closed time, total hrs, chainage, work – no diesel.'),
  LbFormat('G', 'Format G – Time sheet, 1st hr / 2nd hrs', 'Reg no, particular, challan no, start / closed time, total hrs, 1st hr, 2nd hrs (BOQ slab), chainage, work.'),
  LbFormat('H', 'Format H – Trip register (vehicle / challan)', 'Shift, vehicle no, challan no, diesel qty, in time, out time, trip, chainage, work.'),
  LbFormat('I', 'Format I – Water tanker (trip by trip)', 'Water Tanker Report: date, shift, agency, tanker no, challan no, dispatch / unload time, trip, chainage, use for – one line per trip; total, day and night trips. Entered on Log Book → "Water tanker – trip by trip".'),
];

/// The name given in the app (getLbFormatNames), else the default.
String lbName(LbFormat f, Map<String, dynamic> names) => _s(names[f.id]).isNotEmpty ? _s(names[f.id]) : f.name;
