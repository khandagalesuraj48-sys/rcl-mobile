/* (3.55.0) The Store's work – the rules worked out on the phone as the web's page works them out (rcl-store public/work.js): the
 * pages a person has, the numbers as the web writes them, a report as a table (Excel / print), his GRN / Issue registers read from
 * his Excel, the requirement filters. */
import 'package:flutter_test/flutter_test.dart';
import 'package:rcl_mobile/core/sheet_read.dart' show SheetTab;
import 'package:rcl_mobile/screens/store_work.dart';

void main() {
  Future<Map<String, dynamic>> none(String a, [Map<String, dynamic>? x]) async => {};

  test('the pages: as the web\'s menu – Store Purchase only when given, Opening stock & Numbers the Store Admin\'s', () {
    final user = StoreKit(call: none, pages: {'dashboard': 'View', 'items': 'View', 'req': 'Edit', 'grn': 'View', 'issue': 'None', 'reports': 'None', 'po': 'None', 'purchase': 'None'}, admin: false);
    expect([for (final p in kWorkPages) if (user.can(p.$1)) p.$1], ['req', 'grn']);
    expect([user.edit('req'), user.edit('grn'), user.buyer, user.anyWork], [true, false, false, true]);
    final admin = StoreKit(call: none, pages: {'req': 'Edit', 'grn': 'Edit', 'issue': 'Edit', 'reports': 'View', 'po': 'View', 'purchase': 'Edit'}, admin: true);
    expect([for (final p in kWorkPages) if (admin.can(p.$1)) p.$1], ['req', 'purchase', 'po', 'grn', 'issue', 'reports', 'settings']);
    expect(StoreKit(call: none, pages: const {}, admin: false).anyWork, false);
  });

  test('(3.62.1, 29-10-2026) a Store User dates an entry only today; the Store Admin and the Super Admin any day', () {
    final user = StoreKit(call: none, pages: const {'grn': 'Edit'}, admin: false)..b = {'today': '2026-10-29'};
    expect(user.entryFirst, DateTime(2026, 10, 29));
    expect((StoreKit(call: none, pages: const {}, admin: true)..b = {'today': '2026-10-29'}).entryFirst, null, reason: 'the Store Admin');
    expect((StoreKit(call: none, pages: const {}, admin: false, superAdmin: true)..b = {'today': '2026-10-29'}).entryFirst, null, reason: 'the Super Admin');
  });

  test('numbers as the web writes them: a quantity (up to 3 decimals, Indian grouping), a box\'s number, money', () {
    expect([q3(1234567.5), q3(0.125), q3(12), q3(-1500), q3(''), q3(null)], ['12,34,567.5', '0.125', '12', '-1,500', '', '']);
    expect([plainN(12.5), plainN(100), plainN(0), plainN(null), plainN('7.250')], ['12.5', '100', '0', '', '7.25']);
    expect([rs(1575), rs(null), rs(0.5)], ['₹1,575.00', '₹0.00', '₹0.50']);
    final l = SLine(qty: '30', rate: '50', gst: '5'), m = l.money();
    expect([m.t, m.g, m.all], [1500, 75, 1575]);
    expect(linesMoney([l, SLine(qty: '2', rate: '10.555', gst: '18')]).all, closeTo(1599.91, 1e-9), reason: 'each line rounded to paise, as the web');
    // (3.62.0) a PO's line less its Disc. % (the web's lineMoney: qty × rate, less the Disc. %, then the GST on it)
    final d = SLine(qty: '30', rate: '50', disc: '10', gst: '5').money();
    expect([d.t, d.g, d.all], [1350, 67.5, 1417.5]);
    expect(SLine(qty: '3', rate: '33.33', disc: '12.5', gst: '18').money().all, closeTo(103.24, 1e-9), reason: '99.99 less 12.5 % = 87.49, its GST 15.75');
  });

  test('a report of the Store → a table: number columns as numbers, the total line, the sheet\'s name', () {
    final d = storeRepDoc({
      'title': 'Issue register',
      'sub': '01-10-2026 to 28-10-2026',
      'cols': [{'h': 'Outward'}, {'h': 'Item'}, {'h': 'Qty', 'n': true}, {'h': 'Amount ₹', 'n': true}],
      'rows': [[7, 'Hose', 4, 1200], [8, 'Sugar', 0.5, '']],
      'total': ['', 'Total', '', 1200],
    });
    expect([d.title, d.period, d.meta, d.file.startsWith('Issue_register_')], ['Issue register', '01-10-2026 to 28-10-2026', '01-10-2026 to 28-10-2026 · 2 row(s)', true]);
    final t = d.tables.single;
    expect([t.head, t.numCols, t.sheet], [['Outward', 'Item', 'Qty', 'Amount ₹'], {2, 3}, 'Issue register']);
    expect(t.rows[0].cells.map((c) => c.text), ['7', 'Hose', '4', '1,200']);
    expect([t.rows[0].cells[3].value, t.rows[1].cells[2].value, t.rows[1].cells[3].value], [1200, 0.5, null]);
    expect(t.foot.single.cells.map((c) => c.text), ['', 'Total', '', '1,200']);
    expect(storeRepDoc({'title': 'Stock statement (day / month / period) of every item', 'cols': [], 'rows': []}).tables.single.sheet.length, 31);
  });

  test('(3.57.0) the GRN\'s Import format: his inward register\'s columns (the register\'s import reads them – core/grn_reg.dart)', () {
    expect(kDocImpHead['grn'], ['Sr No', 'GRN No', 'GRN Date', 'Challan No', 'Invoice No.', 'Invoice Date', 'Vehicle No', 'Supplier Name', 'Material Description', 'Received Qty', 'UOM', 'Basic Rate', 'Taxable Amount', 'GST Amount', 'TCS', 'Gross Amount', 'Remark']);
    expect(grnRef({'no': 1000000003, 'ref': '342-A'}), '342-A');
    expect(grnRef({'no': 12, 'ref': null}), '12');
  });

  test('his Issue register read: the sub-contractor, else the party; the machinery, the returnable mark', () {
    final rows = storeDocRows('issue', [
      SheetTab('OUTWORD', [
        ['Date', 'Outward No', 'Party Name', 'Sub Contractor Name', 'Machinery', 'Material', 'Qty', 'Location', 'Use For', 'Returnable'],
        ['14-10-2026', 7, 'RCL', '', 'Sany 210 (No.1)', 'Hose', 2, '540+450', 'Breakdown', 'Yes'],
        ['14-10-2026', 8, '', 'Ganesh Contractor', '', 'Sugar', 1, '', '', ''],
      ]),
    ]);
    expect([rows[0]['party'], rows[0]['machinery'], rows[0]['returnable'], rows[0]['use_for'], rows[0].containsKey('party0')], ['RCL', 'Sany 210 (No.1)', 'Yes', 'Breakdown', false]);
    expect(rows[1]['party'], 'Ganesh Contractor');
  });

  test('the requirements\' filters (the web\'s reqIn): open = pending + approved with something still to order; waiting for me', () {
    final p = {'status': 'Pending', 'mayApprove': true, 'lines': []};
    final a = {'status': 'Approved', 'lines': [{'left': 0}, {'left': 2}]};
    final done = {'status': 'Approved', 'lines': [{'left': 0}]};
    expect([reqIn(p, 'open'), reqIn(a, 'open'), reqIn(done, 'open'), reqIn(p, 'mine'), reqIn(a, 'mine'), reqIn(done, 'Approved'), reqIn(p, 'all')], [true, true, false, true, false, true, true]);
    expect(storeToWho({'to_kind': 'Machinery', 'machinery': 'JCB-7', 'party': 'Ganesh'}), 'JCB-7 (Ganesh)');
    expect([storeToWho({'to_kind': 'Site work'}), storeToWho({'to_kind': 'Sub-contractor', 'party': 'Ganesh'}), storeToWho({'to_kind': 'Office'})], ['RCL – site work', 'Ganesh', 'Office']);
  });
}
