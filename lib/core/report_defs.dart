/* THE REPORTS OF THE WEB, IN THE APP (3.2.0): each one the same server report as the web (Mechanical's rpt… / get…Report action –
 * the server works every figure out), laid out with the same tables, columns and totals as the web page draws them
 * (App.html reportDefs / rdTableHtml / setupMonthly). The phone shows them in its own screens; Excel and PDF are made here. */
import 'rdoc.dart';

class ReportDef {
  const ReportDef({required this.key, required this.label, required this.mr, required this.fn, required this.filters, required this.note, required this.build, this.portrait = true, this.pic = 'bar_chart', this.perm = 'Reports'});
  final String key, label, mr, fn, note, pic, perm;
  /// range · vendor · rate · owns · pump · location · location1 · machine · months · monthly (source, shift, supply, zero, machinery) · dloc
  final List<String> filters;
  final RDoc Function(Map<String, dynamic> d) build;
  final bool portrait;
}

const kOwns = ['Own', 'Rental', 'Hired', 'Other', 'Debit'];

String _period(Map<String, dynamic> d) => blankV(d['from']) ? '' : '${dmy(d['from'])} to ${dmy(d['to'])}';
String _meta(Map<String, dynamic> d, String m) => [if (_period(d).isNotEmpty) _period(d), if (m.isNotEmpty) m, 'Generated ${d['generated'] ?? ''}'].join('  |  ');
String _file(String name, Map<String, dynamic> d) => 'RCL_${name}_${d['from'] ?? ''}_to_${d['to'] ?? ''}';

/* ---------- Owner summary: transfers and the stock summary (shared by the web) ---------- */
List<Object> _ownerTransfers(Map<String, dynamic> d) {
  final tr = listOf(d['transfers']);
  if (tr.isEmpty) return [];
  return [
    const RNote('Transfer between locations', heading: true),
    RTable(sheet: 'Transfers', head: const ['Sr', 'Date', 'Shift', 'Transfer ID', 'From', 'To', 'Diesel (Ltr)'], numCols: const {6}, rows: [
      for (var i = 0; i < tr.length; i++) RRow([sc(i + 1), tc(dmy(tr[i]['date'])), tc(tr[i]['shift']), tc(tr[i]['id']), tc(tr[i]['from']), tc(tr[i]['to']), nc(tr[i]['qty'])]),
    ], foot: [
      RRow([RCell('Transfer total – ${tr.length} transfer${tr.length == 1 ? '' : 's'} (moved inside the company, not issued)', bold: true, span: 6), nc(d['transferQty'], bold: true)], kind: RKind.grand),
    ]),
  ];
}

List<Object> _ownerStock(Map<String, dynamic> d) {
  final st = listOf(d['stock']);
  if (st.isEmpty) return [];
  return [
    RNote('Diesel stock summary – ${dmy(d['from'])} to ${dmy(d['to'])}', heading: true),
    RTable(sheet: 'Stock summary', head: const ['Location', 'Opening', 'Inward', 'Received (transfer)', 'Total', 'Issued', 'Sent (transfer)', 'Balance'], numCols: const {1, 2, 3, 4, 5, 6, 7}, rows: [
      for (final x in st)
        () {
          final all = x['loc'] == 'All locations';
          final total = r2(nOf(x['opening']) + nOf(x['inward']) + nOf(x['tin']));
          return RRow([tc(x['loc'], bold: true), nc(x['opening']), nc(x['inward']), all ? const RCell('–', n: true) : nc(x['tin']), nc(total, bold: true), nc(x['issued']), all ? const RCell('–', n: true) : nc(x['tout']), nc(x['closing'], bold: true)], kind: all ? RKind.grand : RKind.normal);
        }(),
    ]),
    const RNote('Total = Opening + Inward + Received. Balance = Total − Issued − Sent. For all locations together, transfers stay inside the company, so they are not counted.'),
  ];
}

/* ================= THE 12 DIESEL REPORTS ================= */
final kDieselReports = <ReportDef>[
  ReportDef(
    key: 'debit',
    label: 'Debit Recovery Statement',
    mr: 'डेबिट वसुली',
    fn: 'rptDebit',
    pic: 'receipt',
    filters: const ['range', 'vendor', 'rate'],
    note: 'Diesel given on "Debit Basis": a summary (one line per vendor), then every entry vendor by vendor. The rate of each entry is the rate of that day; you can change the rate of any entry and save it.',
    build: (d) {
      final vs = listOf(d['vendors']), tot = mapOf(d['total']);
      final details = <RRow>[];
      for (final v in vs) {
        final rows = listOf(v['rows']);
        details.add(grp('${v['owner']}  |  ${v['machines']} machinery  |  ${rows.length} entries', 11));
        for (var i = 0; i < rows.length; i++) {
          final r = rows[i];
          details.add(RRow([sc(i + 1), tc(dmy(r['date'])), tc(r['shift']), tc(r['id']), tc(r['no'], bold: true), tc(r['type']), tc(r['driver']), tc(r['source']), nc(r['qty']), RCell('${money(r['rate'])}${r['manual'] == true ? ' *' : ''}', n: true, value: nOf(r['rate'])), mc(r['amount'])]));
        }
        details.add(RRow([RCell('Total – ${v['owner']}', bold: true, span: 8), nc(v['qty'], bold: true), mc(v['rate']), mc(v['amount'], bold: true)], kind: RKind.sub));
      }
      return RDoc(
        title: '${d['title'] ?? 'Debit Recovery Statement'}',
        period: _period(d),
        file: _file('Debit_Recovery', d),
        meta: _meta(d, 'Rate: ${d['rateText'] ?? ''}'),
        kpis: [('Vendors', '${vs.length}'), ('Entries', '${tot['entries'] ?? 0}'), ('Diesel', '${fmt(tot['qty'])} Ltr'), ('Amount to recover', '₹${money(tot['amount'])}')],
        blocks: [
          const RNote('Summary', heading: true),
          RTable(sheet: 'Summary', head: const ['Sr', 'Vendor', 'Machinery', 'Entries', 'Diesel (Ltr)', 'Avg rate (₹)', 'Amount to recover (₹)'], numCols: const {2, 3, 4, 5, 6}, empty: 'No diesel on Debit Basis in this period.', rows: [
            for (var i = 0; i < vs.length; i++) RRow([sc(i + 1), tc(vs[i]['owner'], bold: true), nc(vs[i]['machines']), nc(listOf(vs[i]['rows']).length), nc(vs[i]['qty']), mc(vs[i]['rate']), mc(vs[i]['amount'], bold: true)]),
          ], foot: [
            RRow([RCell('Total – ${vs.length} vendors', bold: true, span: 2), nc(tot['machines']), nc(tot['entries']), nc(tot['qty']), nOf(tot['qty']) != 0 ? mc(nOf(tot['amount']) / nOf(tot['qty'])) : const RCell('', n: true), mc(tot['amount'])], kind: RKind.grand),
          ]),
          if (vs.isNotEmpty) const RNote('Details', heading: true),
          if (vs.isNotEmpty)
            RTable(sheet: 'Details', head: const ['Sr', 'Date', 'Shift', 'Issue ID', 'Machinery', 'Type', 'Driver', 'Source', 'Diesel (Ltr)', 'Rate (₹)', 'Amount (₹)'], numCols: const {8, 9, 10}, rows: details, foot: [
              RRow([const RCell('Grand total', bold: true, span: 8), nc(tot['qty'], bold: true), const RCell('', n: true), mc(tot['amount'], bold: true)], kind: RKind.grand),
            ]),
          const RNote('* = a rate changed by hand (only for recovering from the vendor).'),
        ],
      );
    },
  ),
  ReportDef(
    key: 'mcost',
    label: 'Machinery Cost Sheet',
    mr: 'यंत्र खर्च',
    fn: 'rptMachineCost',
    pic: 'tractor',
    portrait: false,
    filters: const ['range', 'owns'],
    note: 'What every machinery cost in the period, with the working: Rent (as the bill works it out) + Diesel issued × diesel rate − Diesel recovered from the party = Net cost; and the cost per hour / per KM. Own machinery has no rent in the app (salary, repairs and EMI are not recorded here).',
    build: (d) {
      final gs = listOf(d['groups']), tot = mapOf(d['total']);
      String n(dynamic v) => nOf(v) != 0 ? money(v) : '–';
      String q(dynamic v) => nOf(v) != 0 ? fmt(v) : '–';
      String how(Map<String, dynamic> r) {
        final parts = <String>[];
        if (nOf(r['rent']) != 0) parts.add('Rent ${money(r['rent'])}${'${r['basis'] ?? ''}'.isNotEmpty ? ' (${r['basis']})' : ''}');
        if (nOf(r['issued']) != 0) parts.add('Diesel ${fmt(r['issued'])} L × ₹${fmt(d['rate'])} = ${money(r['dieselCost'])}');
        if (nOf(r['rent']) == 0 && nOf(r['workDays']) != 0 && (r['ownership'] == 'Rental' || r['ownership'] == 'Hired')) parts.insert(0, 'Rent 0.00 – NO BOQ RATE for this machinery in the period');
        var s = parts.isEmpty ? 'no rent, no diesel' : parts.join(' + ');
        if (nOf(r['recover']) != 0) s += ' − recovered ${money(r['recover'])}';
        s += ' = ${money(r['net'])}';
        if (!blankV(r['perHr'])) s += ' ; ÷ ${fmt(r['hrs'])} hr = ₹${money(r['perHr'])} per hr';
        if (!blankV(r['perKm'])) s += ' ; ÷ ${fmt(r['km'])} km = ₹${money(r['perKm'])} per km';
        return s;
      }

      var no = 0;
      final rows = <RRow>[];
      for (final g in gs) {
        final rs = listOf(g['rows']);
        rows.add(grp('${g['ownership']} machinery – ${rs.length}', 15));
        for (final r in rs) {
          rows.add(RRow([
            sc(++no), tc(r['no'], bold: true), tc(r['type']), tc(r['owner']), RCell(nOf(r['workDays']) != 0 ? fmt(r['workDays']) : '–', n: true, value: r['workDays']), RCell(q(r['hrs']), n: true, value: r['hrs']), RCell(q(r['km']), n: true, value: r['km']),
            RCell(n(r['rent']), n: true, value: r['rent']), RCell(q(r['issued']), n: true, value: r['issued']), RCell(n(r['dieselCost']), n: true, value: r['dieselCost']),
            RCell(nOf(r['recover']) != 0 ? '− ${money(r['recover'])}' : '–', n: true, value: r['recover']), mc(r['net'], bold: true),
            RCell(blankV(r['perHr']) ? '–' : money(r['perHr']), n: true, value: r['perHr']), RCell(blankV(r['perKm']) ? '–' : money(r['perKm']), n: true, value: r['perKm']),
            tc('${blankV(r['actualAvg']) ? '–' : fmt(r['actualAvg'])} / ${nOf(r['stdAvg']) != 0 ? fmt(r['stdAvg']) : '–'} ${r['avgUnit'] ?? ''}'),
          ]));
          rows.add(RRow([const RCell(''), RCell(how(r), span: 14, tone: 'muted')]));
        }
        rows.add(RRow([RCell('${g['ownership']} total', bold: true, span: 5), RCell(q(g['hrs']), n: true), RCell(q(g['km']), n: true), RCell(n(g['rent']), n: true), RCell(q(g['issued']), n: true), RCell(n(g['dieselCost']), n: true),
          RCell(nOf(g['recover']) != 0 ? '− ${money(g['recover'])}' : '–', n: true), mc(g['net']), const RCell(''), const RCell(''), const RCell('')], kind: RKind.sub));
      }
      return RDoc(
        title: '${d['title'] ?? 'Machinery Cost Sheet'}',
        period: _period(d),
        portrait: false,
        file: _file('Machinery_Cost', d),
        meta: _meta(d, 'Diesel rate ₹${fmt(d['rate'])} per Ltr (the rate the bills use)'),
        kpis: [('Machinery', '${tot['machines'] ?? 0}'), ('Rent', '₹${money(tot['rent'])}'), ('Diesel cost', '₹${money(tot['dieselCost'])}'), ('Recovered from parties', '₹${money(tot['recover'])}'), ('Net cost', '₹${money(tot['net'])}'), for (final g in gs) ('${g['ownership']}', '₹${money(g['net'])}')],
        blocks: [
          RTable(sheet: 'Machinery cost', head: const ['Sr', 'Machinery', 'Type', 'Owner', 'Days worked', 'Hrs', 'KM', 'Rent (₹)', 'Diesel (Ltr)', 'Diesel cost (₹)', 'Recovered (₹)', 'Net cost (₹)', '₹ / Hr', '₹ / KM', 'Average (actual / standard)'], numCols: const {4, 5, 6, 7, 8, 9, 10, 11, 12, 13}, rows: rows, foot: [
            RRow([const RCell('Grand total', bold: true, span: 5), RCell(q(tot['hrs']), n: true), RCell(q(tot['km']), n: true), RCell(n(tot['rent']), n: true), RCell(q(tot['issued']), n: true), RCell(n(tot['dieselCost']), n: true),
              RCell(nOf(tot['recover']) != 0 ? '− ${money(tot['recover'])}' : '–', n: true), mc(tot['net']), const RCell(''), const RCell(''), const RCell('')], kind: RKind.grand),
          ]),
        ],
      );
    },
  ),
  ReportDef(
    key: 'cost',
    label: 'Diesel Cost Report',
    mr: 'डिझेल खर्च',
    fn: 'rptCost',
    pic: 'receipt',
    filters: const ['range', 'owns', 'rate'],
    note: 'Diesel cost (₹) of every machinery, grouped Own, Rental, Hired, Other, Debit.',
    build: (d) {
      final gs = listOf(d['groups']), tot = mapOf(d['total']);
      var no = 0;
      final rows = <RRow>[];
      for (final g in gs) {
        final rs = listOf(g['rows']);
        rows.add(grp('${g['ownership']} machinery – ${rs.length}', 9));
        for (final r in rs) {
          rows.add(RRow([sc(++no), tc(r['no'], bold: true), tc(r['type']), tc(r['owner']), tc(r['supply']), nc(r['entries']), nc(r['qty']), mc(r['rate']), mc(r['amount'])]));
        }
        rows.add(RRow([RCell('${g['ownership']} total', bold: true, span: 5), nc(g['entries']), nc(g['qty']), nOf(g['qty']) != 0 ? mc(nOf(g['amount']) / nOf(g['qty'])) : const RCell('', n: true), mc(g['amount'])], kind: RKind.sub));
      }
      return RDoc(
        title: '${d['title'] ?? 'Diesel Cost Report'}',
        period: _period(d),
        file: _file('Diesel_Cost', d),
        meta: _meta(d, 'Rate: ${d['rateText'] ?? ''}'),
        kpis: [('Machinery', '${tot['machines'] ?? 0}'), ('Diesel', '${fmt(tot['qty'])} Ltr'), ('Average rate', '₹${money(tot['rate'])}'), ('Total cost', '₹${money(tot['amount'])}'), for (final g in gs) ('${g['ownership']}', '₹${money(g['amount'])}')],
        blocks: [
          RTable(sheet: 'Diesel Cost', head: const ['Sr', 'Machinery', 'Type', 'Owner', 'Diesel Supply', 'Entries', 'Diesel (Ltr)', 'Avg rate (₹)', 'Cost (₹)'], numCols: const {5, 6, 7, 8}, rows: rows, foot: [
            RRow([const RCell('Grand total', bold: true, span: 6), nc(tot['qty']), mc(tot['rate']), mc(tot['amount'])], kind: RKind.grand),
          ]),
        ],
      );
    },
  ),
  ReportDef(
    key: 'purchase',
    label: 'Diesel Purchase Register',
    mr: 'डिझेल खरेदी रजिस्टर',
    fn: 'rptPurchase',
    pic: 'receipt',
    filters: const ['range', 'pump', 'location'],
    note: 'Every diesel purchase (Inward) with bill details, and a pump-wise summary.',
    build: (d) {
      final rs = listOf(d['rows']), ps = listOf(d['pumps']), tot = mapOf(d['total']);
      return RDoc(
        title: '${d['title'] ?? 'Diesel Purchase Register'}',
        period: _period(d),
        file: _file('Diesel_Purchase', d),
        meta: _meta(d, '${d['location'] ?? ''}'),
        kpis: [('Bills', '${tot['bills'] ?? 0}'), ('Diesel', '${fmt(tot['qty'])} Ltr'), ('Average rate', '₹${money(tot['rate'])}'), ('Amount', '₹${money(tot['amount'])}')],
        blocks: [
          const RNote('Purchase register', heading: true),
          RTable(sheet: 'Register', head: const ['Sr', 'Date', 'Inward ID', 'Pump', 'Bill No.', 'Bill Date', 'Location', 'Qty (Ltr)', 'Rate (₹)', 'Amount (₹)'], numCols: const {7, 8, 9}, empty: 'No purchases in this period.', rows: [
            for (var i = 0; i < rs.length; i++) RRow([sc(i + 1), tc(dmy(rs[i]['date'])), tc(rs[i]['id']), tc(rs[i]['pump']), tc(rs[i]['billNo']), tc(dmy(rs[i]['billDate'])), tc(rs[i]['location']), nc(rs[i]['qty']), mc(rs[i]['rate']), mc(rs[i]['amount'])]),
          ], foot: [
            RRow([RCell('Total – ${tot['bills'] ?? 0} bills', bold: true, span: 7), nc(tot['qty']), mc(tot['rate']), mc(tot['amount'])], kind: RKind.grand),
          ]),
          const RNote('Pump-wise summary', heading: true),
          RTable(sheet: 'Pump summary', head: const ['Pump', 'Bills', 'Qty (Ltr)', 'Avg rate (₹)', 'Amount (₹)'], numCols: const {1, 2, 3, 4}, rows: [
            for (final p in ps) RRow([tc(p['pump'], bold: true), nc(p['bills']), nc(p['qty']), mc(p['rate']), mc(p['amount'])]),
          ], foot: [
            RRow([const RCell('Total', bold: true), nc(tot['bills']), nc(tot['qty']), mc(tot['rate']), mc(tot['amount'])], kind: RKind.grand),
          ]),
        ],
      );
    },
  ),
  ReportDef(
    key: 'ledger',
    label: 'Machinery Diesel Ledger',
    mr: 'यंत्राचे डिझेल खाते',
    fn: 'rptLedger',
    pic: 'ledger',
    filters: const ['machine', 'range'],
    note: 'Only the chosen dates: every diesel entry of one machinery, and for each fill the Log Book KM / Hrs from that day until the next fill (or the end of the dates). Totals: all diesel and all Log Book work in the dates.',
    build: (d) {
      final m = mapOf(d['machine']), tot = mapOf(d['total']), rs = listOf(d['rows']);
      final km = m['unit'] != 'Hrs', hr = m['unit'] == 'Hrs' || m['unit'] == 'KM + Hrs';
      final pre = rs.isNotEmpty && rs.first['pre'] == true;
      final facts = [
        ('Machinery', m['id']), ('Name', m['name']), ('Type', m['type']), ('Make', m['make']), ('Owner', m['owner']), ('Ownership', m['ownership']), ('Diesel Supply', m['supply']), ('Unit', m['unit']), ('Standard', tot['std']),
        ('Status', '${m['status'] ?? ''}${blankV(m['inactiveFrom']) ? '' : ' from ${dmy(m['inactiveFrom'])}'}'),
      ].where((x) => '${x.$2 ?? ''}'.trim().isNotEmpty).map((x) => '${x.$1}: ${x.$2}').join('  ·  ');
      final head = ['Sr', 'Date', 'Shift', 'Issue ID', 'Source', 'Driver', 'Diesel (Ltr)', if (km) 'KM run on this fill', if (hr) 'Hrs run on this fill', 'Fill lasted till', 'Average of this fill'];
      return RDoc(
        title: '${d['title'] ?? 'Machinery Diesel Ledger'}',
        period: _period(d),
        file: _file('Diesel_Ledger_${m['id'] ?? ''}', d),
        meta: _meta(d, '${m['id'] ?? ''}${blankV(m['type']) ? '' : '  |  ${m['type']}'}'),
        kpis: [('Diesel entries', '${tot['entries'] ?? 0}'), ('Diesel', '${fmt(tot['qty'])} Ltr'), if (km) ('KM (Log Book)', fmt(tot['kmRun'])), if (hr) ('Hrs (Log Book)', fmt(tot['hrRun'])), ('Average for the period', blankV(tot['overall']) ? '–' : '${tot['overall']}'), ('Standard', blankV(tot['std']) ? '–' : '${tot['std']}')],
        blocks: [
          RNote(facts),
          RTable(sheet: 'Ledger', head: head, numCols: {6, if (km) 7, if (hr) (km ? 8 : 7)}, empty: 'No diesel for this machinery in these dates.', rows: [
            for (var i = 0; i < rs.length; i++)
              RRow([
                rs[i]['pre'] == true ? const RCell('') : sc(i + 1 - (pre ? 1 : 0)), tc(dmy(rs[i]['date'])), tc(rs[i]['shift']), tc(rs[i]['pre'] == true ? 'Before first fill' : rs[i]['id']), tc(rs[i]['source']), tc(rs[i]['driver']),
                rs[i]['pre'] == true ? const RCell('–', n: true) : nc(rs[i]['qty']),
                if (km) nc(rs[i]['kmRun']),
                if (hr) nc(rs[i]['hrRun']),
                tc(blankV(rs[i]['upto']) ? '' : dmy(rs[i]['upto'])), tc(blankV(rs[i]['avg']) ? (blankV(rs[i]['upto']) ? '' : '–') : rs[i]['avg']),
              ], kind: rs[i]['pre'] == true ? RKind.sub : RKind.normal),
          ], foot: [
            RRow([RCell('Total – ${tot['entries'] ?? 0} diesel entries', bold: true, span: 6), nc(tot['qty']), if (km) nc(tot['kmRun']), if (hr) nc(tot['hrRun']), const RCell(''), tc(tot['overall'])], kind: RKind.grand),
          ]),
        ],
      );
    },
  ),
  ReportDef(
    key: 'watch',
    label: 'Diesel Watch – signs of loss',
    mr: 'डिझेल वॉच – गळतीची चिन्हे',
    fn: 'rptWatch',
    pic: 'shield',
    portrait: false,
    filters: const ['range'],
    note: 'Where the diesel figures do not fit: more diesel than the work needs, diesel with no work, a fill bigger than the tank, a meter that did not move, a tank check that found less – and the machinery whose diesel cannot be checked because their Log Book is not kept. Things to look at, not proof.',
    build: (d) {
      final tot = mapOf(d['total']), fs = listOf(d['findings']), ms = listOf(d['machines']), un = listOf(d['unchecked']);
      const tone = {'No work': 'bad', 'More than the work needs': 'warn', 'Over the tank': 'bad', 'Tank check': 'warn', 'Reading': 'info'};
      return RDoc(
        title: '${d['title'] ?? 'Diesel Watch – signs of loss'}',
        period: _period(d),
        portrait: false,
        file: _file('Diesel_Watch', d),
        meta: _meta(d, 'a fill is shown when it is more than ${d['pct']}% and 5 L over what the work until the next fill needs'),
        kpis: [('Signs', '${tot['signs'] ?? 0}'), ('Machinery with a sign', '${tot['machines'] ?? 0}'), ('Litres that do not fit', '${fmt(tot['litres'])} Ltr'), ('Value', money(tot['amount'])), ('Diesel checked', '${fmt(tot['checkedQty'])} Ltr'), ('Diesel that cannot be checked', '${fmt(tot['uncheckedQty'])} Ltr (${tot['uncheckedMachines'] ?? 0} machinery)')],
        blocks: [
          if (fs.isEmpty) RNote('No sign in these dates: wherever the Log Book is kept, the diesel fits the work (within ${d['pct']}%).'),
          if (fs.isNotEmpty)
            RTable(sheet: 'Signs', head: const ['Sr', 'Machinery', 'Type', 'Owner', 'Date', 'Sign', 'What the figures say', 'Litres that do not fit', 'Value (₹)'], numCols: const {7, 8}, rows: [
              for (var i = 0; i < fs.length; i++)
                RRow([sc(i + 1), tc(fs[i]['no'], bold: true), tc(fs[i]['type']), tc(fs[i]['owner']), tc(dmy(fs[i]['date'])), tc(fs[i]['kind'], bold: true, tone: tone['${fs[i]['kind']}'] ?? ''), tc(fs[i]['text']), zc(fs[i]['litres']), RCell(nOf(fs[i]['amount']) != 0 ? money(fs[i]['amount']) : '–', n: true, value: fs[i]['amount'])]),
            ], foot: [
              RRow([RCell('Total – ${tot['signs'] ?? 0} sign(s) on ${tot['machines'] ?? 0} machinery (a fill with two signs counts once)', bold: true, span: 7), nc(tot['litres']), mc(tot['amount'])], kind: RKind.grand),
            ]),
          if (ms.isNotEmpty) const RNote('Machinery to look at first', heading: true),
          if (ms.isNotEmpty)
            RTable(sheet: 'By machinery', head: const ['Sr', 'Machinery', 'Type', 'Owner', 'Signs', 'Litres', 'Value (₹)'], numCols: const {4, 5, 6}, rows: [
              for (var i = 0; i < ms.length; i++) RRow([sc(i + 1), tc(ms[i]['no'], bold: true), tc(ms[i]['type']), tc(ms[i]['owner']), nc(ms[i]['signs']), nc(ms[i]['litres']), mc(ms[i]['amount'])]),
            ]),
          if (un.isNotEmpty) const RNote('Diesel that CANNOT be checked – no Log Book reading in these dates', heading: true),
          if (un.isNotEmpty) const RNote('These machinery took diesel, but there is no KM / hours for them in the Log Book, so nobody can say whether the diesel fits the work. Keep their Log Book and they come under the check.'),
          if (un.isNotEmpty)
            RTable(sheet: 'Not checked', head: const ['Sr', 'Machinery', 'Type', 'Owner', 'Ownership', 'Fills', 'Diesel (Ltr)', 'Value (₹)'], numCols: const {5, 6, 7}, rows: [
              for (var i = 0; i < un.length; i++) RRow([sc(i + 1), tc(un[i]['no'], bold: true), tc(un[i]['type']), tc(un[i]['owner']), tc(un[i]['ownership']), nc(un[i]['fills']), nc(un[i]['qty']), mc(un[i]['amount'])]),
            ], foot: [
              RRow([RCell('Total – ${tot['uncheckedMachines'] ?? 0} machinery', bold: true, span: 5), const RCell(''), nc(tot['uncheckedQty']), mc(tot['uncheckedAmount'])], kind: RKind.grand),
            ]),
        ],
      );
    },
  ),
  ReportDef(
    key: 'owner',
    label: 'Owner / Vendor-wise Summary',
    mr: 'मालक / vendor नुसार',
    fn: 'rptOwner',
    pic: 'office_building',
    filters: const ['range', 'owns'],
    note: 'Grouped by Ownership (Own, Rental, Hired, Other, Debit): under each, every owner / vendor with the machinery under it.',
    build: (d) {
      final owners = listOf(d['owners']), tot = mapOf(d['total']);
      final groups = <(String, List<Map<String, dynamic>>)>[];
      for (final o in owners) {
        final i = groups.indexWhere((g) => g.$1 == '${o['ownership']}');
        if (i < 0) {
          groups.add(('${o['ownership']}', [o]));
        } else {
          groups[i].$2.add(o);
        }
      }
      final locs = (d['locations'] is List ? (d['locations'] as List).map((e) => '$e').toList() : ['Dispenser', 'VTR Store']);
      final cols = 6 + locs.length, all = nOf(tot['qty']);
      String pc(dynamic v) => all > 0 ? '${fmt(r2(nOf(v) / all * 100))}%' : '–';
      List<double> srcSum(List<Map<String, dynamic>> ms) => [for (final l in locs) r2(ms.fold<num>(0, (s, mm) => s + nOf(mapOf(mm['bySource'])[l])))];
      var no = 0;
      final rows = <RRow>[], allM = <Map<String, dynamic>>[];
      for (final g in groups) {
        final ms = [for (final o in g.$2) ...listOf(o['machines'])];
        allM.addAll(ms);
        final q = r2(g.$2.fold<num>(0, (s, o) => s + nOf(o['qty'])));
        rows.add(grp(g.$1, cols));
        for (final o in g.$2) {
          for (final mm in listOf(o['machines'])) {
            rows.add(RRow([sc(++no), tc(o['owner']), tc(mm['no'], bold: true), tc(blankV(mm['type']) ? '–' : mm['type']), for (final l in locs) zc(mapOf(mm['bySource'])[l]), nc(mm['qty'], bold: true), RCell(pc(mm['qty']), n: true)]));
          }
        }
        rows.add(RRow([RCell('${g.$1} total', bold: true, span: 4), for (final v in srcSum(ms)) zc(v), nc(q), RCell(pc(q), n: true, bold: true)], kind: RKind.sub));
      }
      final gs = srcSum(allM);
      return RDoc(
        title: '${d['title'] ?? 'Owner / Vendor-wise Summary'}',
        period: _period(d),
        file: _file('Owner_Summary', d),
        meta: _meta(d, '${owners.length} owners'),
        kpis: [
          ('Owners', '${tot['owners'] ?? 0}'), ('Diesel issued', '${fmt(tot['qty'])} Ltr'),
          for (var i = 0; i < locs.length; i++) ('From ${locs[i]}', '${fmt(gs[i])} Ltr (${pc(gs[i])})'),
          for (final g in groups) (g.$1, '${fmt(r2(g.$2.fold<num>(0, (s, o) => s + nOf(o['qty']))))} Ltr (${pc(g.$2.fold<num>(0, (s, o) => s + nOf(o['qty'])))})'),
        ],
        blocks: [
          RTable(sheet: 'Owner summary', head: ['Sr No', 'Owner Name', 'Machine Number / Name', 'Vehicle Type', for (final l in locs) 'From $l (Ltr)', 'Total Diesel Issue (Ltr)', '% of total'], numCols: {for (var i = 4; i < cols; i++) i}, empty: 'No diesel in this period.', rows: rows, foot: [
            RRow([const RCell('Grand total – issued to machinery', bold: true, span: 4), for (final v in gs) nc(v), nc(tot['qty']), RCell(all > 0 ? '100%' : '–', n: true)], kind: RKind.grand),
          ]),
          const RNote('Head-wise share', heading: true),
          RTable(sheet: 'Head-wise share', head: const ['Head', 'Machinery', 'Diesel issued (Ltr)', '% of total'], numCols: const {1, 2, 3}, rows: [
            for (final g in groups)
              () {
                final q = r2(g.$2.fold<num>(0, (s, o) => s + nOf(o['qty'])));
                return RRow([tc(g.$1, bold: true), nc(g.$2.fold<num>(0, (s, o) => s + listOf(o['machines']).length)), nc(q), RCell(pc(q), n: true, bold: true)]);
              }(),
          ], foot: [
            RRow([const RCell('Total', bold: true), nc(allM.length), nc(tot['qty']), RCell(all > 0 ? '100%' : '–', n: true)], kind: RKind.grand),
          ]),
          ..._ownerTransfers(d),
          ..._ownerStock(d),
        ],
      );
    },
  ),
  ReportDef(
    key: 'type',
    label: 'Type-wise Summary',
    mr: 'प्रकारानुसार',
    fn: 'rptType',
    pic: 'articulated_lorry',
    filters: const ['range', 'owns'],
    note: 'Diesel by type of machinery (Tipper, Excavator, DG…), per machinery and per entry.',
    build: (d) {
      final types = listOf(d['types']), tot = mapOf(d['total']);
      final gs = kOwns.where((g) => ['Own', 'Rental', 'Debit'].contains(g) || types.any((x) => !blankV(mapOf(x['byOwn'])[g]))).toList();
      return RDoc(
        title: '${d['title'] ?? 'Type-wise Summary'}',
        period: _period(d),
        file: _file('Type_Summary', d),
        meta: _meta(d, '${tot['types'] ?? 0} types'),
        kpis: [('Types', '${tot['types'] ?? 0}'), ('Diesel', '${fmt(tot['qty'])} Ltr')],
        blocks: [
          RTable(sheet: 'Type summary', head: ['Sr', 'Type of Machinery', 'Machinery', 'Entries', ...gs, 'Total (Ltr)', 'Per machinery', 'Per entry', 'Share'], numCols: {for (var i = 2; i < 8 + gs.length; i++) i}, rows: [
            for (var i = 0; i < types.length; i++)
              RRow([sc(i + 1), tc(types[i]['type'], bold: true), nc(types[i]['machines']), nc(types[i]['entries']), for (final g in gs) zc(mapOf(types[i]['byOwn'])[g]), nc(types[i]['qty'], bold: true), nc(types[i]['perMachine']), nc(types[i]['perEntry']), RCell('${fmt(types[i]['share'])}%', n: true)]),
          ], foot: [
            RRow([RCell('Total', bold: true, span: 4 + gs.length), nc(tot['qty']), const RCell(''), const RCell(''), const RCell('100%', n: true)], kind: RKind.grand),
          ]),
        ],
      );
    },
  ),
  ReportDef(
    key: 'stock',
    label: 'Stock Register',
    mr: 'स्टॉक रजिस्टर',
    fn: 'rptStock',
    pic: 'oil_drum',
    filters: const ['location1', 'range'],
    note: 'Every diesel movement of one location (Dispenser or VTR Store) with the running balance.',
    build: (d) {
      final rs = listOf(d['rows']), tot = mapOf(d['total']);
      return RDoc(
        title: '${d['title'] ?? 'Stock Register'}',
        period: _period(d),
        file: _file('Stock_Register_${d['location'] ?? ''}', d),
        meta: _meta(d, '${d['location'] ?? ''}'),
        kpis: [('Opening', fmt(d['opening'])), ('In', fmt(tot['inQ'])), ('Out', fmt(tot['outQ'])), ('Closing', fmt(tot['closing']))],
        blocks: [
          RTable(sheet: 'Stock register', head: const ['Sr', 'Date', 'Shift', 'Ref. ID', 'Particulars', 'In (Ltr)', 'Out (Ltr)', 'Balance (Ltr)'], numCols: const {5, 6, 7}, rows: [
            RRow([const RCell(''), tc(dmy(d['from'])), const RCell(''), const RCell(''), const RCell('Opening balance', bold: true), const RCell('', n: true), const RCell('', n: true), nc(d['opening'])], kind: RKind.sub),
            for (var i = 0; i < rs.length; i++)
              RRow([sc(i + 1), tc(dmy(rs[i]['date'])), tc(rs[i]['shift']), tc(rs[i]['ref']), tc(rs[i]['part']), RCell(nOf(rs[i]['inQ']) != 0 ? fmt(rs[i]['inQ']) : '', n: true, value: nOf(rs[i]['inQ']) != 0 ? nOf(rs[i]['inQ']) : null), RCell(nOf(rs[i]['outQ']) != 0 ? fmt(rs[i]['outQ']) : '', n: true, value: nOf(rs[i]['outQ']) != 0 ? nOf(rs[i]['outQ']) : null), nc(rs[i]['bal'], bold: true)]),
          ], foot: [
            RRow([RCell('Total  |  Closing balance on ${dmy(d['to'])}', bold: true, span: 5), nc(tot['inQ']), nc(tot['outQ']), nc(tot['closing'])], kind: RKind.grand),
          ]),
        ],
      );
    },
  ),
  ReportDef(
    key: 'compare',
    label: 'Month vs Month',
    mr: 'महिना विरुद्ध महिना',
    fn: 'rptCompare',
    pic: 'calendar',
    filters: const ['months', 'owns'],
    note: 'Diesel of every machinery in two months side by side – where it went up or down.',
    build: (d) {
      final gs = listOf(d['groups']), tot = mapOf(d['total']);
      var no = 0;
      final rows = <RRow>[];
      for (final g in gs) {
        final rs = listOf(g['rows']);
        rows.add(grp('${g['ownership']} machinery – ${rs.length}', 8));
        for (final r in rs) {
          rows.add(RRow([sc(++no), tc(r['no'], bold: true), tc(r['type']), tc(r['owner']), zc(r['a']), zc(r['b']), RCell(signed(r['diff']), n: true, tone: nOf(r['diff']) > 0 ? 'bad' : nOf(r['diff']) < 0 ? 'good' : '', value: nOf(r['diff'])), RCell(nOf(r['a']) != 0 ? pct(r['pct']) : 'New', n: true)]));
        }
        rows.add(RRow([RCell('${g['ownership']} total', bold: true, span: 4), nc(g['a']), nc(g['b']), RCell(signed(g['diff']), n: true, value: nOf(g['diff'])), RCell(pct(g['pct']), n: true)], kind: RKind.sub));
      }
      return RDoc(
        title: '${d['title'] ?? 'Month vs Month'}',
        file: 'RCL_Month_vs_Month_${d['nameA'] ?? ''}_${d['nameB'] ?? ''}',
        meta: _meta(d, '${d['nameA'] ?? ''} vs ${d['nameB'] ?? ''}'),
        kpis: [('${d['nameA'] ?? ''}', '${fmt(tot['a'])} Ltr'), ('${d['nameB'] ?? ''}', '${fmt(tot['b'])} Ltr'), ('Change', '${signed(tot['diff'])} Ltr'), ('Change %', pct(tot['pct']))],
        blocks: [
          RTable(sheet: 'Comparison', head: ['Sr', 'Machinery', 'Type', 'Owner', '${d['nameA'] ?? ''}', '${d['nameB'] ?? ''}', 'Change (Ltr)', 'Change %'], numCols: const {4, 5, 6, 7}, rows: rows, foot: [
            RRow([const RCell('Grand total', bold: true, span: 4), nc(tot['a']), nc(tot['b']), RCell(signed(tot['diff']), n: true, value: nOf(tot['diff'])), RCell(pct(tot['pct']), n: true)], kind: RKind.grand),
          ]),
        ],
      );
    },
  ),
  ReportDef(
    key: 'tank',
    label: 'Tank Check – System vs Physical',
    mr: 'टँक तपासणी',
    fn: 'rptTank',
    pic: 'oil_drum',
    portrait: false,
    filters: const ['range'],
    note: 'Tank checks in the dates (what the system said, what was found, difference and reason), and every machinery’s system tank at the end of the dates. A tank shows in amber only when it is more than the Tank Capacity set in Master.',
    build: (d) {
      final cs = listOf(d['checks']), cur = listOf(d['current']), tot = mapOf(d['total']);
      return RDoc(
        title: '${d['title'] ?? 'Tank Check – System vs Physical'}',
        period: _period(d),
        portrait: false,
        file: _file('Tank_Check', d),
        meta: _meta(d, '${tot['checks'] ?? 0} checks  |  ${tot['bigDiff'] ?? 0} with more than 10% difference'),
        kpis: [('Tank checks', '${tot['checks'] ?? 0}'), ('Total difference', '${signed(tot['diff'])} Ltr'), ('More than 10% off', '${tot['bigDiff'] ?? 0}'), ('Above tank capacity', '${tot['over'] ?? 0}')],
        blocks: [
          const RNote('Tank checks', heading: true),
          RTable(sheet: 'Tank checks', head: const ['Date', 'Machinery', 'System (L)', 'Found (L)', 'Difference (L)', '%', 'How', 'Reason', 'Checked by'], numCols: const {2, 3, 4, 5}, empty: 'No tank check in these dates.', rows: [
            for (final x in cs)
              () {
                final big = nOf(x['diff']).abs() > (nOf(x['system']).abs() * 0.1 > 5 ? nOf(x['system']).abs() * 0.1 : 5);
                return RRow([tc(dmy(x['date'])), tc(x['no'], bold: true), nc(x['system']), nc(x['physical']), RCell(signed(x['diff']), n: true, bold: true, tone: big ? 'bad' : '', value: nOf(x['diff'])), RCell(blankV(x['pct']) ? '–' : '${signed(x['pct'])}%', n: true), tc(x['method']), tc(x['reason']), tc(x['by'])]);
              }(),
          ]),
          RNote('System tank on ${dmy(d['asOn'])} (as per standard)', heading: true),
          RTable(sheet: 'System tank', head: const ['Machinery', 'Type', 'Ownership', 'System tank (L)', 'Tank capacity (L)', 'Last check', 'Difference at last check (L)'], numCols: const {3, 4, 6}, rows: [
            for (final x in cur)
              RRow([tc(x['no'], bold: true), tc(x['type']), tc(x['ownership']), RCell('${fmt(x['system'])}${x['over'] == true ? '  (more than the tank)' : ''}', n: true, bold: true, tone: x['over'] == true ? 'warn' : '', value: nOf(x['system'])), RCell(nOf(x['cap']) != 0 ? fmt(x['cap']) : '–', n: true, value: x['cap']),
                tc(blankV(x['lastCheck']) ? '–' : dmy(x['lastCheck'])), RCell(blankV(x['lastDiff']) ? '–' : signed(x['lastDiff']), n: true, value: x['lastDiff'])]),
          ]),
        ],
      );
    },
  ),
  ReportDef(
    key: 'average',
    label: 'Actual vs Standard Average',
    mr: 'प्रत्यक्ष व standard सरासरी',
    fn: 'rptAverage',
    pic: 'bar_chart',
    portrait: false,
    filters: const ['range', 'owns'],
    note: 'For the chosen dates: all diesel issued, and all KM / Hrs from the Log Book, added up per machinery – the actual average compared with the Standard Average in Master. Within 10% of the standard = Good; 10–30% less diesel = Very good; 10–30% more = More diesel; over 30% more = Bad; over 30% less = Check reading (too good to be true – usually a reading).',
    build: (d) {
      final gs = listOf(d['groups']), tot = mapOf(d['total']);
      const tone = {'bad': 'bad', 'more': 'warn', 'ok': 'good', 'less': 'good', 'check': 'info'};
      var no = 0;
      final rows = <RRow>[];
      for (final g in gs) {
        final rs = listOf(g['rows']);
        rows.add(grp('${g['ownership']} machinery – ${rs.length}', 15));
        for (final r in rs) {
          rows.add(RRow([
            sc(++no), tc(r['no'], bold: true), tc(r['type']), tc(r['unit']), nc(r['fills']), nc(r['runs']), RCell(blankV(r['km']) ? '–' : fmt(r['km']), n: true, value: r['km']), RCell(blankV(r['hr']) ? '–' : fmt(r['hr']), n: true, value: r['hr']), nc(r['used'], bold: true),
            tc(blankV(r['actual']) ? '–' : r['actual'], bold: true), tc(blankV(r['std']) ? '–' : r['std']), RCell(blankV(r['expected']) ? '–' : fmt(r['expected']), n: true, value: r['expected']),
            RCell(blankV(r['excess']) ? '–' : signed(r['excess']), n: true, tone: nOf(r['excess']) > 0 ? 'bad' : nOf(r['excess']) < 0 ? 'good' : '', value: r['excess']), RCell(blankV(r['pct']) ? '–' : pct(r['pct']), n: true), tc(r['status'], bold: true, tone: tone['${r['statusCode']}'] ?? 'muted'),
          ]));
        }
      }
      return RDoc(
        title: '${d['title'] ?? 'Actual vs Standard Average'}',
        period: _period(d),
        portrait: false,
        file: _file('Actual_vs_Standard', d),
        meta: _meta(d, '${tot['machines'] ?? 0} machinery  |  ${tot['excessCount'] ?? 0} with more diesel than the standard  |  ${tot['checkCount'] ?? 0} to check'),
        kpis: [('Diesel issued', '${fmt(tot['issuedAll'])} Ltr'), ('As per standard', '${fmt(tot['expected'])} Ltr'), ('More / (Less)', '${signed(tot['excess'])} Ltr'), ('More diesel / Bad', '${tot['excessCount'] ?? 0}'), ('Check reading', '${tot['checkCount'] ?? 0}')],
        blocks: [
          RTable(sheet: 'Average', head: const ['Sr', 'Machinery', 'Type', 'Unit', 'Diesel entries', 'Log Book days', 'KM run', 'Hrs run', 'Diesel issued (L)', 'Actual average', 'Standard', 'Diesel as per std (L)', 'More / (Less) L', '%', 'Status'], numCols: const {4, 5, 6, 7, 8, 11, 12, 13}, rows: rows, foot: [
            RRow([const RCell('Total', bold: true, span: 8), nc(tot['issuedAll']), const RCell(''), const RCell(''), nc(tot['expected']), RCell(signed(tot['excess']), n: true, value: tot['excess']), const RCell(''), const RCell('')], kind: RKind.grand),
          ]),
        ],
      );
    },
  ),
];

/* ================= DAILY DIESEL INWARD & ISSUE SUMMARY (rdaily) ================= */
final kDailyReport = ReportDef(
  key: 'rdaily',
  label: 'Daily Inward & Issue',
  mr: 'दैनिक आवक व वाटप',
  fn: 'getDailyInwardIssueReport',
  pic: 'calendar',
  filters: const ['range', 'dloc'],
  note: 'Every day of the dates: opening stock, inward from the pump, diesel issued (by ownership) and closing stock.',
  build: (d) {
    final byLoc = d['byLocation'] == true, other = (d['otherLocations'] is List ? (d['otherLocations'] as List).join(' / ') : '').toString();
    final gs = (d['groups'] is List ? (d['groups'] as List).map((e) => '$e').toList() : <String>[]);
    final rs = listOf(d['rows']), t0 = mapOf(d['totals']);
    const dows = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    String dayOf(String k) {
      final p = DateTime.tryParse(k);
      return p == null ? '' : dows[p.weekday - 1];
    }

    final check = 'Opening ${fmt(t0['opening'])} + Inward ${fmt(t0['inward'])}${byLoc ? ' + Received ${fmt(t0['tin'])} − Sent ${fmt(t0['tout'])}' : ''} − Issued ${fmt(t0['issued'])} = Closing ${fmt(t0['closing'])}';
    final head = ['Date', 'Opening stock', 'Inward (pump)', if (byLoc) 'Received from ${other.isEmpty ? 'other location' : other}', if (byLoc) 'Sent to ${other.isEmpty ? 'other location' : other}', for (final g in gs) 'Issued – $g', 'Total issued', 'Closing stock'];
    return RDoc(
      title: 'Daily Diesel Inward & Issue Summary',
      period: _period(d),
      file: _file('Daily_Inward_Issue', d),
      meta: _meta(d, '${d['location'] ?? ''}  |  $check'),
      kpis: [('Opening', fmt(t0['opening'])), ('Inward', fmt(t0['inward'])), for (final g in gs) (g, fmt(mapOf(t0['issue'])[g] ?? 0)), ('Total issued', fmt(t0['issued'])), ('Closing', fmt(t0['closing']))],
      blocks: [
        RTable(sheet: 'Daily Inward & Issue', head: head, numCols: {for (var i = 1; i < head.length; i++) i}, rows: [
          for (final x in rs)
            RRow([
              tc('${dmy(x['date'])} ${dayOf('${x['date']}')}'), nc(x['opening']), zc(x['inward']), if (byLoc) zc(x['tin']), if (byLoc) zc(x['tout']), for (final g in gs) zc(mapOf(x['issue'])[g] ?? 0), zc(x['issued'], bold: true), nc(x['closing']),
            ], kind: dayOf('${x['date']}') == 'Sun' ? RKind.sunday : RKind.normal),
        ], foot: [
          RRow([const RCell('Total', bold: true), nc(t0['opening']), nc(t0['inward']), if (byLoc) nc(t0['tin']), if (byLoc) nc(t0['tout']), for (final g in gs) nc(mapOf(t0['issue'])[g] ?? 0), nc(t0['issued']), nc(t0['closing'])], kind: RKind.grand),
        ]),
      ],
    );
  },
);

/* ================= MONTHLY DIESEL ISSUE (rmonthly) / MONTHLY DIESEL & AVERAGE (ravg) ================= */
RDoc monthlyDoc(Map<String, dynamic> d, bool withAvg) {
  final days = listOf(d['days']), gs = listOf(d['groups']);
  final title = withAvg ? 'Monthly Diesel & Average Report' : 'Monthly Diesel Issue Report';
  String two(dynamic a, dynamic b, dynamic unit) {
    final km = unit == 'KM' || unit == 'KM + Hrs', hr = unit == 'Hrs' || unit == 'KM + Hrs';
    return [if (km && !blankV(a)) '${fmt(a)}${hr ? ' km' : ''}', if (hr && !blankV(b)) '${fmt(b)}${km ? ' hr' : ''}'].join(' / ');
  }

  String rdd(dynamic dk) => '$dk'.length < 10 ? '' : ' (${'$dk'.substring(8, 10)}-${'$dk'.substring(5, 7)})';
  final f = mapOf(d['filters']);
  final filterText = 'Diesel Source: ${f['source'] ?? 'All'}  |  Shift: ${f['shift'] ?? 'All'}  |  Diesel Supply: ${f['supply'] ?? 'All'}  |  Ownership: ${(f['ownerships'] is List ? (f['ownerships'] as List).join(', ') : f['ownerships'] ?? '')}  |  Machinery: ${f['machines'] == 'All' || f['machines'] == null ? 'All' : '${f['machines']} selected'}';
  final lead = ['Sr', 'Machinery', 'Owner', if (withAvg) 'Unit', if (withAvg) 'Opening reading', if (withAvg) 'Closing reading', if (withAvg) 'Total KM / Hrs'];
  final tail = withAvg ? ['Actual average', 'Standard average', 'Status'] : <String>[];
  final head = [...lead, for (final x in days) '${x['d']}${'${x['dow'] ?? ''}'.isNotEmpty ? ' ${x['dow']}' : ''}', 'Total diesel (Ltr)', ...tail];
  const tone = {'bad': 'bad', 'more': 'warn', 'ok': 'good', 'less': 'good', 'check': 'info', 'na': 'muted'};
  var no = 0;
  final rows = <RRow>[];
  final blankLead = withAvg ? 4 : 0;
  for (final g in gs) {
    final rs = listOf(g['rows']);
    rows.add(grp('${g['ownership']} machinery – ${rs.length}', head.length));
    for (final r in rs) {
      final sub = [r['name'] != null && r['name'] != r['id'] ? r['name'] : '', r['type'], r['supply'] != null && r['supply'] != 'Company' ? r['supply'] : '', r['status'] == 'Inactive' ? 'Inactive${blankV(r['inactiveFrom']) ? '' : ' from ${dmy(r['inactiveFrom'])}'}' : ''].where((x) => '${x ?? ''}'.isNotEmpty).join('  |  ');
      final ds = (r['days'] is List ? r['days'] as List : const []);
      rows.add(RRow([
        sc(++no), RCell('${r['id']}${sub.isNotEmpty ? '\n$sub' : ''}', bold: true), tc(r['owner']),
        if (withAvg) tc(r['unit']),
        if (withAvg) tc('${two(r['oKm'], r['oHr'], r['unit'])}${(!blankV(r['oKm']) || !blankV(r['oHr'])) ? rdd(r['oDate']) : ''}'),
        if (withAvg) tc('${two(r['cKm'], r['cHr'], r['unit'])}${(!blankV(r['cKm']) || !blankV(r['cHr'])) ? rdd(r['cDate']) : ''}'),
        if (withAvg) tc(two(r['tKm'], r['tHr'], r['unit']), bold: true),
        for (final v in ds) RCell(nOf(v) != 0 ? fmt(v) : '', n: true, value: nOf(v) != 0 ? nOf(v) : null),
        nc(r['total'], bold: true),
        if (withAvg) tc(blankV(r['actual']) ? '–' : r['actual'], bold: true),
        if (withAvg) tc(blankV(r['standard']) ? '–' : r['standard']),
        if (withAvg) tc(blankV(r['status']) ? '–' : r['status'], bold: true, tone: tone['${r['statusCode']}'] ?? 'muted'),
      ]));
    }
    final dt = (g['dayTotals'] is List ? g['dayTotals'] as List : const []);
    rows.add(RRow([RCell('${g['ownership']} total', bold: true, span: 3), if (blankLead > 0) RCell('', span: blankLead), for (final v in dt) RCell(nOf(v) != 0 ? fmt(v) : '', n: true, value: nOf(v) != 0 ? nOf(v) : null), nc(g['total'], bold: true), if (withAvg) const RCell('', span: 3)], kind: RKind.sub));
  }
  final all = [for (final g in gs) ...listOf(g['rows'])];
  int cnt(String c) => all.where((r) => r['statusCode'] == c).length;
  final dt = (d['dayTotals'] is List ? d['dayTotals'] as List : const []);
  return RDoc(
    title: '$title – ${d['monthName'] ?? ''}',
    period: _period(d),
    portrait: false,
    file: 'RCL_${withAvg ? 'Diesel_Average' : 'Diesel_Issue'}_${d['from'] ?? ''}_to_${d['to'] ?? ''}',
    meta: '$filterText  |  Generated ${d['generated'] ?? ''}',
    kpis: [
      ('Total diesel', '${fmt(d['total'])} Ltr'), ('Machinery', '${d['machines'] ?? 0}'),
      if (withAvg) ...[('Bad (over 30% more diesel)', '${cnt('bad')}'), ('More diesel (10–30%)', '${cnt('more')}'), ('Good / Very good', '${cnt('ok') + cnt('less')}'), ('Check reading', '${cnt('check')}'), ('No status (no readings)', '${cnt('na')}')]
      else ...[('Entries', '${d['entries'] ?? 0}'), for (final g in gs) ('${g['ownership']}', fmt(g['total']))],
    ],
    blocks: [
      RTable(sheet: withAvg ? 'Diesel & Average' : 'Monthly Diesel', head: head, numCols: {for (var i = lead.length; i < lead.length + days.length + 1; i++) i}, empty: 'No diesel issued for this selection in ${d['monthName'] ?? ''}.', rows: rows, foot: [
        if (gs.isNotEmpty) RRow([const RCell('Day total – all machinery', bold: true, span: 3), if (blankLead > 0) RCell('', span: blankLead), for (final v in dt) RCell(nOf(v) != 0 ? fmt(v) : '', n: true, value: nOf(v) != 0 ? nOf(v) : null), nc(d['total'], bold: true), if (withAvg) const RCell('', span: 3)], kind: RKind.grand),
      ]),
    ],
  );
}

final kMonthlyReport = ReportDef(
  key: 'rmonthly',
  label: 'Monthly Diesel Issue',
  mr: 'मासिक डिझेल वाटप',
  fn: 'getMonthlyDieselReport',
  pic: 'fuel_pump',
  portrait: false,
  filters: const ['range', 'monthly', 'owns'],
  note: 'Diesel of every machinery day by day for the dates, grouped by ownership, with the day totals.',
  build: (d) => monthlyDoc(d, false),
);

final kAvgReport = ReportDef(
  key: 'ravg',
  label: 'Monthly Diesel & Average',
  mr: 'मासिक डिझेल व सरासरी',
  fn: 'getMonthlyAvgReport',
  pic: 'clipboard',
  portrait: false,
  filters: const ['range', 'monthly', 'owns'],
  note: 'The monthly diesel with the opening / closing reading, the KM / Hrs run and the actual average against the standard – Good, More diesel, Bad or Check reading.',
  build: (d) => monthlyDoc(d, true),
);
