/* (3.62.0) The Store's papers in his formats (28-10-2026 – "DIESEL PURCHASE ORDER", "REQUIREMENT OF EXHAUST FANS"), as the web
 * prints them (rcl-store public/work.js poPrint / reqPrint): the numbers as the web writes them, the boxes and columns, the totals,
 * the terms, who prepared / checked / approved; what a person typed never becomes a tag of the page. */
import 'package:flutter_test/flutter_test.dart';
import 'package:rcl_mobile/core/store_papers.dart';

void main() {
  final heading = {'company': 'Rachana Construction Limited', 'address': 'Plot 1, Nashik\nMaharashtra', 'gstin': '27ABCDE1234F1Z5', 'pan': 'ABCDE1234F', 'email': 'store@rcl.test', 'phone': '0253 000000', 'cin': 'U00000MH0000PLC000000', 'web': 'rcl.test', 'site': 'VTR Site – NH 848'};
  Map<String, dynamic> po({String appr = 'Approved', String terms = '1. Payment within 30 days.\n2. Delivery at site.', num gst = 225}) => {
        'no': 128, 'ref': 'RCL/VTR/PO/2026/0128', 'date': '2026-10-28', 'site': 'S1', 'vendor': 'Shri <Traders>', 'vendor_gst': '27AAAAA0000A1Z5', 'credit_days': 0, 'site_contact': 'Store Keeper : 90000 00000', 'ship_to': 'VTR Site Store\nNH 848',
        'deliver_by': '2026-11-02', 'freight': 500, 'load_unload': 0, 'gst': gst, 'total': 225699, 'words': 'Two Lakh Twenty Five Thousand Six Hundred Ninety Nine Rupees Only', 'remark': 'Urgent', 'terms': terms,
        'created_name': 'Amol Patil', 'appr': appr, 'appr_name': appr == 'Approved' ? 'Sujit Mule' : null,
        'lines': [
          {'name': 'HSD', 'spec': 'BS-VI', 'brand': '', 'hsn': '27101944', 'gst_pct': 0, 'qty': 2500, 'unit': 'Ltr', 'rate': 90.1, 'disc_pct': 0, 'disc': 0, 'taxable': 225250},
          {'name': 'Grease', 'spec': '', 'brand': 'Servo', 'hsn': '3403', 'gst_pct': 18, 'qty': 1.25, 'unit': 'Kg', 'rate': 200, 'disc_pct': 10, 'disc': 25, 'taxable': 225},
        ],
      };

  test('the numbers as the web writes them: Indian grouping, the decimals asked; dd-mm-yyyy', () {
    expect([paperNum(225699), paperNum(1234567.5), paperNum(0), paperNum(null), paperNum(-1500), paperNum(2500, min: 1, max: 3), paperNum(1.25, min: 1, max: 3), paperNum(0.1256, min: 1, max: 3)],
        ['2,25,699.00', '12,34,567.50', '0.00', '0.00', '-1,500.00', '2,500.0', '1.25', '0.126']);
    expect([paperDmy('2026-10-28'), paperDmy('2026-10-28T06:00:00Z'), paperDmy(''), paperDmy(null)], ['28-10-2026', '28-10-2026', '', '']);
  });

  test('the Purchase Order in the Diesel PO\'s format: the heading, Supplier / PO Details, Shipping Address, the columns, the totals, Amount in word, the terms, Prepared / Approved By', () {
    final h = poPaperHtml(po(), heading, {'name': 'Shri <Traders>', 'address': 'Nashik Road', 'mobile': '90000 11111', 'email': '', 'contact': 'Owner', 'gstin': ''});
    for (final w in ['<title>PO RCL/VTR/PO/2026/0128</title>', 'Rachana Construction Limited', 'Plot 1, Nashik<br>Maharashtra', '<b>Email ID.</b> : store@rcl.test', '<b>CIN No</b> : U00000MH0000PLC000000', '<b>PAN No</b> : ABCDE1234F',
      'Purchase Order', 'Supplier Details', '<b>Shri &lt;Traders&gt;</b>', 'Nashik Road', '27AAAAA0000A1Z5', 'PO Details', '<b>RCL/VTR/PO/2026/0128</b>', '28-10-2026', '0 Days', 'VTR Site – NH 848', 'Store Keeper : 90000 00000',
      'Delivery by', '02-11-2026', 'VTR Site Store<br>NH 848',
      '<th>S.N.</th><th>Item Description- Specification</th><th>Brand</th><th>HSN</th><th>GST %</th><th>Qty</th><th>Unit</th><th>Rate</th><th>Disc. %</th><th>Amount</th>',
      'HSD - BS-VI', '27101944', '2,500.0', '90.10', '2,25,250.00', 'Servo', '1.25', '10.00', '225.00',
      'Total Disc. Amount</b></td><td class="r">25.00', 'Gross Amount</b></td><td class="r">2,25,475.00', 'Total GST Amount</b></td><td class="r">225.00', 'Total Freight Charges</b></td><td class="r">500.00',
      'Total Load / Unload Amount</b></td><td class="r">0.00', 'TOTAL AMOUNT (Rs.)</b></td><td class="r"><b>2,25,699.00</b>', 'Two Lakh Twenty Five Thousand Six Hundred Ninety Nine Rupees Only', '<b>Remark:</b> Urgent',
      '<p style="margin:6px 0">1. Payment within 30 days.</p>', 'Amol Patil<br><br>Prepared By', 'Sujit Mule<br><br>Approved By', 'This Purchase Order is computer generated it does not require signature.']) {
      expect(h, contains(w), reason: w);
    }
    expect(h, isNot(contains('<Traders>')), reason: 'what is typed is never a tag of the page');
    expect(h, contains('<td class="c">-</td>'), reason: 'no brand: "-"');
    expect(h, contains('<b style="font-size:22px">Rachana Construction Limited</b>'), reason: 'no logo given: the company\'s name');
  });

  test('the PO: waiting / rejected on its Approved By; terms not numbered as a list; no GST row without GST; the logo – the company\'s own first, else the one given', () {
    expect(poPaperHtml(po(appr: 'Waiting'), heading, const {}), contains('(waiting for approval)<br><br>Approved By'));
    expect(poPaperHtml(po(appr: 'Rejected'), heading, const {}), contains('(rejected)<br><br>Approved By'));
    final plain = poPaperHtml(po(terms: 'Payment within 30 days\n\n  Delivery at site  ', gst: 0), heading, const {}, logo: 'data:image/png;base64,AAAA');
    expect(plain, contains('<ol><li>Payment within 30 days</li><li>Delivery at site</li></ol>'));
    expect(plain, isNot(contains('Total GST Amount')));
    expect(plain, contains('<img src="data:image/png;base64,AAAA"'));
    expect(plain, contains('<b>Shri &lt;Traders&gt;</b>'), reason: 'no supplier from the Vendor Master: the PO\'s vendor');
    expect(plain, contains('27AAAAA0000A1Z5'), reason: 'and its GST no.');
    final own = poPaperHtml(po(), {...heading, 'logo': 'https://example.test/logo.png'}, const {}, logo: 'data:image/png;base64,AAAA');
    expect(own, contains('<img src="https://example.test/logo.png"'));
    expect(own, isNot(contains('base64,AAAA')));
    expect(poPaperHtml(po(), {...heading, 'logo': 'javascript:alert(1)'}, const {}), isNot(contains('javascript:')), reason: 'only an https / data: picture');
  });

  test('the Purchase Requisition Form (3.69.0: as his paper "REQUIREMENT OF FOUNDATION BOLT"): Project / Sub Project NA / Indent No. / Date; the item code, description, specification line by line (spec · Brand · note), Required Date; "Remark:Require For :" what it is for, its remark; Prepared, Checked (the levels before the last), Approved By (the last)', () {
    final x = {
      'no': 232, 'ref': 'RCL/VTR/PR/2026/0232', 'date': '2026-10-12', 'need_by': '2026-10-20', 'for_kind': 'Site work', 'for_text': 'Ch 540+450 toe wall', 'status': 'Approved', 'level': 0, 'remark': 'Before the rain', 'created_name': 'Amol Patil',
      'approvals': [{'level': 1, 'name': 'Ravi Pawar', 'ok': true}, {'level': 2, 'name': 'Sujit Mule', 'ok': true}],
      'lines': [{'code': 'ITM-0101', 'name': 'Exhaust Fan 12 inch', 'brand': 'Crompton', 'spec': '1400 rpm\nAll Dimension : MM', 'note': 'for the store room', 'unit': 'Nos', 'qty': 4}],
    };
    final h = reqPaperHtml(x, heading);
    for (final w in ['<title>Requirement RCL/VTR/PR/2026/0232</title>', '<tr><td class="pt">Purchase Requisition Form</td></tr></table>', 'Project Name :</td><td style="width:45%">VTR Site – NH 848', 'Sub Project :</td><td>NA</td>', 'RCL/VTR/PR/2026/0232', '12/10/2026',
      '<th style="width:6%">Sr No</th><th style="width:11%">Item Code</th><th style="width:17%">Item Description</th><th>Item Specification</th><th style="width:7%">Unit</th><th style="width:9%">Quantity</th><th style="width:10%">Required Date</th>', 'ITM-0101', 'Exhaust Fan 12 inch',
      '<td>1400 rpm<br>All Dimension : MM<br>Brand: Crompton<br>for the store room</td>', '4.0', '20/10/2026',
      '<div class="prm">Remark:Require For :Site work – Ch 540+450 toe wall<br>Before the rain</div>', 'Amol Patil<span>Prepared By</span>', 'Ravi Pawar<span>Checked By</span>', 'Sujit Mule<span>Approved By</span>', '.prf{border:1px solid #000;min-height:268mm;font-size:12px}']) {
      expect(h, contains(w), reason: w);
    }
    final waiting = reqPaperHtml({...x, 'status': 'Pending', 'level': 2, 'approvals': [{'level': 1, 'name': 'Ravi Pawar', 'ok': true}], 'need_by': null}, heading);
    expect(waiting, contains('Ravi Pawar<span>Checked By</span>'));
    expect(waiting, contains('(waiting – level 2)<span>Approved By</span>'));
    expect(waiting, contains('<td class="c m">12/10/2026</td></tr>'), reason: 'no Needed by: its date');
    expect(reqPaperHtml({...x, 'status': 'Rejected', 'approvals': []}, heading), contains('(rejected)<span>Approved By</span>'));
    // (3.65.0, "print war rachana address nahi site address nahi"; 3.69.0 – his answer: as his paper, the two addresses kept) the company's
    // address under its name, the Site Address; no e-mail / CIN / GST / PAN rows (not on his paper)
    final full = reqPaperHtml(x, {...heading, 'address': 'Office 2\nMumbai', 'site_address': 'Site office at Valshind\nBhiwandi'}, logo: 'data:image/png;base64,AAAA');
    for (final w in ['<div class="pn">', '<div class="pa">Office 2<br>Mumbai</div>', 'Site Address :</td><td colspan="3">Site office at Valshind<br>Bhiwandi', '<img src="data:image/png;base64,AAAA" alt="" style="width:270px;max-width:92%;height:auto;vertical-align:middle">']) {
      expect(full, contains(w), reason: w);
    }
    for (final w in ['<b>Email ID.</b>', '<b>CIN No</b>', '<b>GST No</b>', '<b>PAN No</b>']) {
      expect(full, isNot(contains(w)), reason: 'not on his paper: $w');
    }
    expect(reqPaperHtml(x, heading), isNot(contains('Site Address')), reason: 'no site address: no row');
  });

  test('(3.66.0, "Print मध्ये photos पण") the requirement\'s photos on the pages after the form – two a row, who added each and its day in India; none: no photos page; only proper links', () {
    final x = {'no': 7, 'ref': 'RCL/VTR/PR/2026/0007', 'date': '2026-10-29', 'for_kind': 'Site work', 'status': 'Pending', 'level': 1, 'approvals': [], 'created_name': 'Amol Patil', 'lines': []};
    final h = reqPaperHtml(x, heading, photos: [
      {'url': 'https://s.test/storage/v1/object/sign/erp-files/store/req/aa/a.jpg?token=1', 'by': 'Amol Patil', 'at': '2026-10-28T19:00:00.000Z'},
      {'url': 'https://s.test/b.jpg?token=2', 'by': 'Sujit Mule', 'at': '2026-10-29T05:00:00.000Z'},
      {'url': 'javascript:alert(1)', 'by': 'x'},
    ]);
    for (final w in ['page-break-before:always', 'Photos of the material – RCL/VTR/PR/2026/0007 (2)', '<img src="https://s.test/storage/v1/object/sign/erp-files/store/req/aa/a.jpg?token=1" alt="Photo 1">',
      'Photo 1 · Amol Patil · 29-10-2026', 'Photo 2 · Sujit Mule · 29-10-2026', '.fm .phg{display:grid;grid-template-columns:1fr 1fr']) {
      expect(h, contains(w), reason: w);
    }
    expect(h, isNot(contains('javascript:')), reason: 'only an http(s) link');
    expect(reqPaperHtml(x, heading), isNot(contains('Photos of the material')), reason: 'no photos: no photos page');
    expect(istOf('2026-10-28T19:00:00.000Z').substring(0, 10), '2026-10-29', reason: '19:00 UTC = 00:30 the next day in India');
  });

  test('(3.70.0, the web\'s 29-10-2026) the requirement\'s contact (Contact Person · Contact No.) and its machinery\'s maintenance log book on the pages after the photos – as the Store sends it; none: no row, no page', () {
    final x = {'no': 9, 'ref': 'RCL/VTR/2026-27/M/0001', 'date': '2026-10-29', 'for_kind': 'Machinery', 'for_text': 'MH-25-AJ-5506', 'status': 'Pending', 'level': 1, 'approvals': [], 'created_name': 'Amol Patil', 'lines': [],
      'contact_name': 'Ramesh Patil', 'contact_phone': '98765 43210'};
    final h = reqPaperHtml(x, heading, logbook: {'html': '<div class="mlbw"><div class="mlbt">Maintenance Log Book – MH-25-AJ-5506</div><table class="mlb"></table></div>', 'css': '.mlb{border-collapse:collapse}</style><script>'});
    expect(h, contains('<tr><td>Contact Person :</td><td>Ramesh Patil</td><td>Contact No. :</td><td>98765 43210</td></tr>'));
    expect(h, contains('<style>.mlb{border-collapse:collapse}style><script></style><div style="page-break-before:always"><div class="mlbw"><div class="mlbt">Maintenance Log Book – MH-25-AJ-5506</div>'), reason: 'its look cannot close the style');
    expect(h, contains('<title>Requirement RCL/VTR/2026-27/M/0001</title>'));
    final none = reqPaperHtml({...x, 'contact_name': '', 'contact_phone': null}, heading);
    expect(none, isNot(contains('Contact Person')));
    expect(none, isNot(contains('Maintenance Log Book')));
  });
}
