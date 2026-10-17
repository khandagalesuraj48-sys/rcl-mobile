/* A pretend Portal + Mechanical for the tests (no network): it answers like the real ones, from data kept here. */
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class FakeServer {
  final calls = <String>[];
  int tickets = 0;
  bool portalSignedIn = false, superAdmin = false, mustChange = false;
  String newPassword = '';
  String expireOnce = ''; // an action that first answers SESSION_EXPIRED (a Mechanical sign-in that ended)
  Map<String, String> perms = {'Diesel Issue': 'Edit', 'Diesel Inward': 'View', 'Diesel Transfer': 'None', 'Dashboard': 'View', 'Log Book': 'View', 'Reports': 'View', 'Master': 'View'};
  final saved = <Map<String, dynamic>>[];
  final logSaved = <Map<String, dynamic>>[];
  bool billLock = false; // (14-10-2026) the entries are in a submitted bill: Mechanical refuses a change (not the Super Admin's)
  final requests = <Map<String, dynamic>>[];
  bool tanker = false; // a water tanker (Log Book Format I) on the site, with an entry of 2 trips today
  bool tanker2 = false; // (3.18.1) a second water tanker of another agency, with a trip on 13-10-2026
  // (3.1.7) verification (update-114), the live sync, no network
  String flowFor = ''; // an action the Super Admin put under verification: answered "Sent for verification …" (nothing saved)
  Map<String, String> versions = {'master': '1', 'stock': '1', 'log': '1', 'users': '1', 'activity': '1', 'flow': '1'};
  int crPending = 0, crForMe = 0;
  Map<String, dynamic> flowMine = {}; // (update-116) his works under verification (getInit "flow")
  final flowReqs = <Map<String, dynamic>>[]; // (3.1.11, update-118) the Approvals list (his entries in verification)
  final reminded = <List<String>>[];
  int billsSent = 0; // (3.1.13) bill copies sent (inwardPhoto)
  final decided = <Map<String, dynamic>>[]; // (3.2.0) what the Approvals screen sent (decide, several, answer)
  final rulesSaved = <Map<String, dynamic>>[];
  final reportAsked = <Map<String, dynamic>>[]; // (3.2.0) the reports asked, with their filters
  bool down = false; // no network to Mechanical
  final rids = <String>[]; // the save numbers that came
  final tankerCalls = <Map<String, dynamic>>[];
  static const _tTrips = [
    {'shift': 'Day', 'n': 1, 'c': '123', 'a': '07:35', 'b': '07:50', 'ch': '', 'u': '', 'old': 0},
    {'shift': 'Day', 'n': 2, 'c': '18522', 'a': '10:30', 'b': '10:36', 'ch': 'VTR', 'u': 'PQC curing', 'old': 0},
  ];
  Map<String, dynamic> get _tankerDay => {'machine': {'id': 'MH-04-J-9844', 'owner': 'Chalke Enterprises', 'type': 'Water Tanker'}, 'date': '2026-10-14', 'trips': _tTrips, 'problem': '', 'other': ''};
  Map<String, dynamic> prefs = {'shift': '', 'loc': '', 'lbMode': '', 'text': 'normal', 'mobile': '', 'photo': ''};
  // (3.15.0) the assistant: the AI service set up or not, what it was sent, its next steps (scripted), the daily summary
  bool aiOn = false;
  final aiAsked = <Map<String, dynamic>>[];
  final aiScript = <Map<String, dynamic>>[];
  Map<String, dynamic> brief = {
    'name': 'Sujit Mule', 'day': '2026-10-13',
    'sections': {
      'diesel': {'entries': 4, 'litres': 240, 'top': [{'name': 'Kobelco Sk 220', 'litres': 80}, {'name': 'MH-25-AJ-2169', 'litres': 80}, {'name': 'Sany 210 (No.1)', 'litres': 60}]},
      'stock': {'litres': 1133, 'byLoc': {'Dispenser': 813, 'VTR Store': 320}},
      'logbook': {'entries': 6, 'pending': 1, 'names': ['MH-25-AJ-2169']},
      'papers': {'expired': 1, 'due': 1, 'soonDays': 30, 'first': ['MH-25-AJ-2169 PUC']},
    },
  };
  String start = '';

  static final issues = [
    {'id': 'DI-000525', 'date': '2026-10-14', 'shift': 'Day', 'no': 'Sany 210 (No.1)', 'type': 'Excavator', 'qty': 60, 'source': 'VTR Store', 'driver': 'Gupta', 'ph': 4},
    {'id': 'DI-000522', 'date': '2026-10-14', 'shift': 'Day', 'no': 'MH-12-SY-6216', 'type': 'Bolero', 'qty': 20, 'source': 'Dispenser', 'driver': 'Maruti'},
    {'id': 'DI-000521', 'date': '2026-10-14', 'shift': 'Day', 'no': 'Kobelco Sk 220', 'type': 'Excavator', 'qty': 80, 'source': 'Dispenser', 'driver': 'Babu Bag'},
    {'id': 'DI-000520', 'date': '2026-10-14', 'shift': 'Night', 'no': 'MH-25-AJ-2169', 'type': 'Tipper', 'qty': 80, 'source': 'Dispenser', 'driver': 'Rupesh'},
  ];

  // (3.4.0) Asset Master and the other masters: the machinery (changed by the saves), the vendors, the BOQs, the papers
  final masterCalls = <Map<String, dynamic>>[];
  final master = <Map<String, dynamic>>[
    {'id': 'Sany 210 (No.1)', 'name': 'Sany 210', 'type': 'Excavator', 'make': 'Sany', 'owner': 'RCL', 'ownership': 'Own', 'supply': 'Company', 'status': 'Active', 'modes': ['Hrs', 'Time'], 'modesX': ['Time'], 'meterKm': false, 'meterHr': true,
      'worksOn': ['Hrs'], 'unit': 'Hrs', 'hrStd': 14, 'kmStd': '', 'tankCap': 400, 'activeFrom': '2026-09-01', 'inactiveFrom': '', 'earlier': [], 'insuranceUpto': '2027-03-31', 'enteredBy': 'Tester'},
    {'id': 'MH-25-AJ-2169', 'no': 'MH-25-AJ-2169', 'name': '', 'type': 'Tipper', 'make': 'Tata', 'owner': 'I E Enterprises', 'ownership': 'Rental', 'supply': 'Company', 'status': 'Active', 'modes': ['KM'], 'modesX': [], 'meterKm': true, 'meterHr': false,
      'worksOn': ['KM'], 'unit': 'KM', 'kmStd': 3.5, 'hrStd': '', 'tankCap': 300, 'activeFrom': '', 'inactiveFrom': '', 'earlier': [{'from': '2026-06-01', 'until': '2026-08-01'}],
      'taxUpto': 'LIFETIME', 'pucUpto': '2026-09-30', 'insuranceUpto': '2026-10-20', 'engineNo': 'E123', 'chassisNo': 'C456', 'enteredBy': 'Tester', 'updatedBy': 'Checker'},
    {'id': 'OLD-9', 'no': 'OLD-9', 'name': '', 'type': 'Roller', 'owner': '', 'ownership': 'Own', 'status': 'Inactive', 'inactiveFrom': '2026-10-01', 'modes': ['Hrs'], 'worksOn': ['Hrs'], 'unit': 'Hrs', 'hrStd': 8},
  ];
  List<Map<String, dynamic>> get _master => [
        ...master,
        if (tanker) {'id': 'MH-04-J-9844', 'name': '', 'type': 'Water Tanker', 'owner': 'Chalke Enterprises', 'ownership': 'Rental', 'supply': 'Company', 'status': 'Active', 'modes': ['Trip'], 'modesX': [], 'lbFormat': 'I'},
        if (tanker2) {'id': 'MH-12-AB-1001', 'name': '', 'type': 'Water Tanker', 'owner': 'Patil Water Supply', 'ownership': 'Rental', 'supply': 'Company', 'status': 'Active', 'modes': ['Trip'], 'modesX': [], 'lbFormat': 'I'},
      ];
  final vendors = <Map<String, dynamic>>[
    {'name': 'I E Enterprises', 'saved': true, 'complete': false, 'gstReg': 'No', 'pan': 'ABCDE1234F', 'bank': 'State Bank of India', 'account': '000000004321', 'ifsc': 'SBIN0001234', 'phone': '9000000000', 'boqs': 1,
      'ownership': 'Rental', 'machines': [{'id': 'MH-25-AJ-2169', 'type': 'Tipper', 'ownership': 'Rental', 'status': 'Active'}]},
    {'name': 'RCL', 'saved': false, 'complete': true, 'gstReg': 'No', 'boqs': 0, 'ownership': 'Own', 'machines': [{'id': 'Sany 210 (No.1)', 'type': 'Excavator', 'ownership': 'Own', 'status': 'Active'}]},
    {'name': 'Chalke Enterprises', 'saved': true, 'complete': true, 'gstReg': 'Yes', 'gst': '27AAAAA0000A1Z5', 'gstPct': 18, 'pan': 'AAAAA0000A', 'bank': 'Bank of Maharashtra', 'account': '000000009999', 'ifsc': 'MAHB0000123', 'boqs': 0, 'ownership': 'Rental', 'machines': [{'id': 'MH-04-J-9844', 'type': 'Water Tanker', 'ownership': 'Rental', 'status': 'Active'}]},
  ];
  final boqs = <Map<String, dynamic>>[
    {'id': 'BOQ-0001', 'no': '1', 'vendor': 'I E Enterprises', 'from': '2026-09-01', 'to': '', 'amendOf': '', 'amendNo': 0, 'gstPct': '', 'tdsPct': 2, 'woNo': 'WO-12', 'woDate': '', 'remark': '', 'enteredBy': 'Tester',
      'lines': [{'no': 'MH-25-AJ-2169', 'type': 'Tipper', 'basis': 'Monthly', 'rate': 45000, 'slabs': [], 'slabOn': '', 'diesel': 'Company', 'remark': ''}]},
  ];
  Map<String, String> lbNames = {};
  final dashAsked = <Map<String, dynamic>>[]; // (3.5.0)
  final tankChecks = <Map<String, dynamic>>[
    {'id': 'TC-0001', 'date': '2026-10-10', 'no': 'Sany 210 (No.1)', 'system': 200, 'physical': 150, 'diff': -50, 'pct': -25, 'method': 'Measured', 'toFill': '', 'reason': 'Leak at the hose', 'by': 'Tester', 'enteredBy': 'Tester'},
  ];
  // (3.6.0) Edit Log Book: a KM machinery's entries (MH-25-AJ-2169), and a water tanker's trips; what was sent
  final logBulk = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> get _editRows => [
        for (final x in const [('2026-10-12', 15000, 15040), ('2026-10-13', 15040, 15100), ('2026-10-14', 15100, 15230)])
          {'key': 'MH-25-AJ-2169|${x.$1}|Full Day', 'date': x.$1, 'shift': 'Full Day', 'no': 'MH-25-AJ-2169', 'type': 'Tipper', 'owner': 'I E Enterprises', 'unit': 'KM', 'mode': 'KM',
            'okm': x.$2, 'ckm': x.$3, 'wkm': x.$3 - x.$2, 'ohr': '', 'chr': '', 'whr': '', 'tStart': '', 'tEnd': '', 'tBrk': '', 'tSlots': '', 'trip': '', 'challan': '', 'remark': '',
            'chFrom': '12+000', 'chTo': '12+800', 'work': 'Earth carting', 'odsl': '', 'odSet': '', 'itemWork': {}, 'half': false, 'meter': '', 'debitTo': '', 'debitRate': '', 'itemQty': [], 'boqItems': []},
      ];
  Map<String, dynamic> _editData(String from, String to) => {
        'machine': master[1], 'from': from, 'to': to, 'boqItems': {},
        'rows': _editRows.where((r) => '${r['date']}'.compareTo(from) >= 0 && '${r['date']}'.compareTo(to) <= 0).toList(),
        'prev': {'key': 'MH-25-AJ-2169|2026-10-11|Full Day', 'date': '2026-10-11', 'shift': 'Full Day', 'okm': 14950, 'ckm': 15000, 'ohr': '', 'chr': '', 'stock': 120},
        'next': null, 'diesel': {'2026-10-14': {'Day': 0, 'Night': 80}}, 'prevKm': 15000, 'prevHr': '', 'locks': [], 'nextHr': null, 'hrsOnly': false,
      };
  Map<String, dynamic> _tankerRange(String from, String to, List trips) => {
        'machine': {'id': 'MH-04-J-9844', 'owner': 'Chalke Enterprises', 'type': 'Water Tanker'}, 'from': from, 'to': to,
        'trips': [for (final t in trips) {'date': t['date'] ?? '2026-10-14', 'shift': t['shift'], 'c': t['c'], 'a': t['a'], 'b': t['b'], 'ch': t['ch'], 'u': t['u'], 'old': 0}],
        'days': [], 'locks': [],
      };
  // (3.7.0) Breakdown: a breakdown carried from the last saved day, the history of breakdown runs; what was sent
  bool bdRich = false;
  final bdSent = <Map<String, dynamic>>[];
  List<Map<String, dynamic>>? bdSaved; // the status saved for 14-10-2026
  Map<String, dynamic> _bd(String date) => {
        'today': '2026-10-14', 'date': date.isEmpty ? '2026-10-14' : date,
        'report': bdSaved == null ? null : {'date': '2026-10-14', 'at': '14-10-2026 18:05', 'by': 'Tester', 'rows': bdSaved, 'count': bdSaved!.where((r) => r['status'] == 'Breakdown').length},
        'carried': bdSaved == null ? '2026-10-13' : '',
        'status': bdSaved == null
            ? {'MH25AJ2169': {'status': 'Breakdown', 'reason': 'Tyre puncture', 'remark': '', 'carried': true}}
            : {for (final r in bdSaved!) '${r['no']}'.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), ''): {'status': r['status'], 'reason': r['reason'], 'remark': r['remark']}},
        'onDate': [{'no': 'MH-25-AJ-2169', 'from': '2026-10-10', 'days': 5, 'reason': 'Tyre puncture', 'remark': '', 'id': 'MH-25-AJ-2169', 'type': 'Tipper', 'owner': 'I E Enterprises', 'ownership': 'Rental'}],
        'history': [
          {'no': 'MH-25-AJ-2169', 'from': '2026-10-10', 'backOn': '', 'reason': 'Tyre puncture', 'remark': '', 'days': 5, 'type': 'Tipper', 'owner': 'I E Enterprises', 'ownership': 'Rental', 'id': 'MH-25-AJ-2169|2026-10-10'},
          {'no': 'Sany 210 (No.1)', 'from': '2026-10-02', 'backOn': '2026-10-05', 'reason': 'Hydraulic problem', 'remark': '', 'days': 3, 'type': 'Excavator', 'owner': 'RCL', 'ownership': 'Own', 'id': 'Sany 210 (No.1)|2026-10-02'},
        ],
        'reports': [
          if (bdSaved != null) {'date': '2026-10-14', 'at': '14-10-2026 18:05', 'by': 'Tester', 'total': bdSaved!.length, 'count': bdSaved!.where((r) => r['status'] == 'Breakdown').length},
          {'date': '2026-10-13', 'at': '13-10-2026 18:00', 'by': 'Tester', 'total': 2, 'count': 1},
        ],
      };
  // (3.8.0) Billing: the vendors to bill, September's Log Book / diesel / BOQ of MH-25-AJ-2169 (a Monthly BOQ, an Idle day,
  // diesel above the standard), the saved bills, notes, payments, ledger; what was sent
  bool billing = false;
  static Object? _arg(List a, String k) => a.isNotEmpty && a[0] is Map ? (a[0] as Map)[k] : null;
  // (3.11.0) the imports and the multiple entries of the diesel pages: what was sent, the lists' filters asked
  final importSent = <Map<String, dynamic>>[];
  // (3.14.0) the other calls of part 13 (diesel history, photos, transfer stock, faults, backup) and the site's notice
  final extraCalls = <Map<String, dynamic>>[];
  String notice = '';
  final faults = <Map<String, dynamic>>[
    {'at': '2026-10-14T05:00:00Z', 'by': 'clerk@rcl.test', 'kind': 'server', 'where': 'getStock', 'msg': 'x is undefined', 'detail': 'TypeError: x is undefined'},
  ];
  final listAsked = <Map<String, dynamic>>[];
  final billSent = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> get _billRows => [
        for (var d = 1; d <= 6; d++)
          {'no': 'MH-25-AJ-2169', 'date': '2026-09-0$d', 'shift': 'Full Day', 'mode': d == 6 ? 'Idle' : 'KM', 'unit': 'KM', 'okm': d == 6 ? '' : 900 + 100 * d, 'ckm': d == 6 ? '' : 1000 + 100 * d, 'wkm': d == 6 ? '' : 100,
            'whr': '', 'trip': '', 'half': false, 'owner': 'I E Enterprises', 'type': 'Tipper', 'key': 'MH-25-AJ-2169|2026-09-0$d|Full Day', 'work': 'Earth carting', 'itemQty': []},
      ];
  Map<String, dynamic> get _billExtra => {
        'debit': {},
        'boq': {
          'MH25AJ2169': {
            for (var d = 1; d <= 30; d++)
              '2026-09-${d.toString().padLeft(2, '0')}': {'boq': '1', 'amendNo': 0, 'basis': 'Monthly', 'rate': 45000, 'nightRate': '', 'slabs': [], 'slabOn': '', 'items': [], 'diesel': 'Company', 'gstPct': '', 'tdsPct': 2, 'woNo': 'WO-12', 'woDate': ''}
          }
        },
        'issues': {
          'MH25AJ2169': {
            '2026-09-01': {'qty': 120, 'km': 1000, 'hr': '', 'lastQty': 120, 'lastKm': 1000, 'lastHr': ''},
            '2026-09-03': {'qty': 60, 'km': 1200, 'hr': '', 'lastQty': 60, 'lastKm': 1200, 'lastHr': ''},
          }
        },
        'avgRate': 92.5, 'lastRate': 93.1,
      };
  Map<String, dynamic> get _billInit => {
        'vendors': [
          {...vendors[0]},
          {...vendors[2]},
        ],
        'lastNo': {'I E ENTERPRISES|Sketchline Industries': 7},
        'settings': {
          'project': 'Test Project', 'siteAddress': 'SITE OFFICE, TEST VILLAGE',
          'companies': {
            'Sketchline Industries': {'address': 'TEST ADDRESS 1, PUNE', 'gstin': '27AAAAA0000A1Z0', 'pan': 'AAAAA0000A', 'invPrefix': 'SLI/TST/RA-', 'dnPrefix': 'SLI/TST/DN-'},
            'Rachana Construction Limited': {'address': '', 'gstin': '27BBBBB0000B1Z0', 'pan': 'BBBBB0000B', 'invPrefix': 'RCL/TST/RA-', 'dnPrefix': 'RCL/TST/DN-'},
          },
        },
        'pendingDn': [{'id': 'DN-0003', 'no': 'SLI/TST/DN-3', 'date': '2026-09-20', 'vendor': 'I E Enterprises', 'company': 'Sketchline Industries', 'total': 1500}],
      };
  static const _savedBills = [
    {'id': 'BILL-00001', 'vendor': 'I E Enterprises', 'company': 'Sketchline Industries', 'billNo': '7', 'rev': 0, 'from': '2026-08-01', 'to': '2026-08-31', 'billDate': '2026-09-05', 'net': 41250.5, 'status': 'Active', 'enteredBy': 'Tester', 'dnNo': 'SLI/TST/DN-2', 'dnAmt': 3200},
    {'id': 'BILL-00002', 'vendor': 'Chalke Enterprises', 'company': 'Rachana Construction Limited', 'billNo': '3', 'rev': 1, 'from': '2026-08-01', 'to': '2026-08-31', 'billDate': '2026-09-06', 'net': 18000, 'status': 'Superseded', 'enteredBy': 'Tester', 'dnNo': '', 'dnAmt': 0},
  ];
  static const _ledger = {
    'vendor': 'I E Enterprises', 'from': '', 'to': '', 'opening': 5000, 'openEntry': {'date': '2026-08-01', 'side': 'Payable', 'amount': 5000},
    'rows': [
      {'date': '2026-09-05', 'kind': 'bill', 'id': 'BILL-00001', 'bill': 41250.5, 'paid': 0, 'company': 'Sketchline Industries', 'billNo': '7', 'rev': 0, 'from': '2026-08-01', 'to': '2026-08-31', 'basic': 45000, 'diesel': 3200, 'other': 0, 'gst': 0, 'tds': 549.5, 'balance': 46250.5},
      {'date': '2026-09-25', 'kind': 'payment', 'id': 'PAY-00001', 'bill': 0, 'paid': 40000, 'company': '', 'mode': 'NEFT', 'ref': 'UTR123', 'against': 'RA 7 (01-08-2026 – 31-08-2026)', 'remark': '', 'balance': 6250.5},
      {'date': '2026-09-28', 'kind': 'dn', 'id': 'DN-0003', 'bill': -1500, 'paid': 0, 'company': 'Sketchline Industries', 'dnNo': 'SLI/TST/DN-3', 'remark': 'Work for the party', 'balance': 4750.5},
    ],
    'totalBill': 39750.5, 'totalPaid': 40000, 'closing': 4750.5,
  };
  // (3.9.0) Administration: the users and their access, the activity, the rules, Read Me; what was sent
  final adminSent = <Map<String, dynamic>>[];
  bool usersBySuper = false;
  final adminUsers = <Map<String, dynamic>>[
    {'email': 'sujit@rcl.test', 'name': 'Sujit Mule', 'active': true, 'admin': true, 'mustChange': false, 'perms': {'Dashboard': 'Edit', 'Log Book': 'Edit', 'Machinery Billing': 'Edit'}},
    {'email': 'clerk@rcl.test', 'name': 'Site Clerk', 'active': true, 'admin': false, 'mustChange': true, 'perms': {'Dashboard': 'View', 'Log Book': 'Edit', 'Machinery Billing': 'None'}},
  ];
  static const _readme = '<div class="rm-toc"><a href="#rm-what" data-rmgo="rm-what">1. हे app काय आहे</a></div><h3 id="rm-what">1. हे app काय आहे</h3><p>App चे <b>तीन</b> भाग &amp; <code>Code.gs</code>.</p>'
      '<table class="rm-t"><tr><th>भाग</th><th>काम</th></tr><tr><td><b>Supabase</b></td><td>data</td></tr></table><ol><li>पहिले</li><li>दुसरे <span class="rm-ok">✔ ok</span></li></ol>'
      '<div class="rm-step"><div class="rm-n">1</div><div class="rm-sb"><h4>Supabase project</h4><p>New project.</p></div></div>'
      '<div class="rm-adm"><label>Email <input id="rm_ad_email" type="email" placeholder="admin@company.com"></label></div><div class="rm-code"><button class="btn ghost small rm-copy" data-copy="rm_sql_admin">Copy</button><pre id="rm_sql_admin"></pre></div>';
  // (3.10.0) the Store: its sign-in (a ticket), the Item Master of the site; what was sent
  final storeSent = <Map<String, dynamic>>[];
  int storeSessions = 0;
  final storeItems = <Map<String, dynamic>>[
    {'code': 'ITM-0001', 'name': 'Hydraulic Hose 1/2 inch', 'unit': 'Mtr', 'category': 'Spare Parts', 'hsn': '40092100', 'gst_pct': 18, 'min_stock': 10, 'status': 'Active', 'similar_note': null, 'created_by': 'sujit@rcl.test', 'created_at': '2026-10-02T06:00:00Z'},
    {'code': 'ITM-0002', 'name': 'Sugar', 'unit': 'Kg', 'category': 'Canteen', 'hsn': '', 'gst_pct': 5, 'min_stock': null, 'status': 'Active', 'similar_note': null, 'created_by': 'sujit@rcl.test', 'created_at': '2026-10-10T06:00:00Z'},
    {'code': 'ITM-0003', 'name': 'Oil Filter', 'unit': 'Nos', 'category': 'Spare Parts', 'hsn': '8421', 'gst_pct': 18, 'min_stock': 4, 'status': 'Inactive', 'similar_note': null, 'created_by': 'clerk@rcl.test', 'created_at': '2026-09-20T06:00:00Z'},
  ];
  Map<String, dynamic> get _compliance => {
        'today': '2026-10-14', 'soonDays': 30, 'docs': ['Tax', 'PUC', 'Permit', 'Fitness', 'Insurance'], 'noPapers': 1,
        'machines': [
          {'no': 'MH-25-AJ-2169', 'type': 'Tipper', 'owner': 'I E Enterprises', 'ownership': 'Rental', 'docs': {
            'Tax': {'v': 'LIFETIME', 's': 'life', 'days': ''}, 'PUC': {'v': '2026-09-30', 's': 'expired', 'days': -14}, 'Permit': {'v': '', 's': 'missing', 'days': ''},
            'Fitness': {'v': '2027-01-31', 's': 'ok', 'days': 109}, 'Insurance': {'v': '2026-10-20', 's': 'due', 'days': 6}}},
          {'no': 'Sany 210 (No.1)', 'type': 'Excavator', 'owner': 'RCL', 'ownership': 'Own', 'docs': {
            'Tax': {'v': '', 's': 'notreq', 'days': ''}, 'PUC': {'v': '', 's': 'notreq', 'days': ''}, 'Permit': {'v': '', 's': 'notreq', 'days': ''}, 'Fitness': {'v': '', 's': 'notreq', 'days': ''},
            'Insurance': {'v': '2027-03-31', 's': 'ok', 'days': 168}}},
        ],
        'types': [
          {'type': 'Tipper', 'key': 'TIPPER', 'count': 1, 'docs': ['Tax', 'PUC', 'Permit', 'Fitness', 'Insurance'], 'set': false, 'guess': 'Road vehicle – all papers'},
          {'type': 'Excavator', 'key': 'EXCAVATOR', 'count': 1, 'docs': ['Insurance'], 'set': true, 'guess': ''},
        ],
        'history': [{'on': '2026-10-02', 'no': 'MH-25-AJ-2169', 'doc': 'Fitness', 'from': '2026-09-30', 'to': '2027-01-31', 'docNo': 'F-77', 'amount': 1200, 'remark': '', 'source': '', 'by': 'Tester'}],
      };
  List<String> _works(dynamic w) => '${w ?? ''}'.split(',').map((x) => x.trim()).where((x) => x.isNotEmpty).toList();

  http.Response _j(Object o, [int code = 200, Map<String, String> h = const {}]) => http.Response(jsonEncode(o), code, headers: {'content-type': 'application/json', ...h});

  /* ---- (3.17.0) the Portal's Super Admin console (api/admin): its data and its checks, as the Portal's (the same words) ---- */
  final portalAdminSent = <Map<String, dynamic>>[];
  final saUsers = <Map<String, dynamic>>[
    {'email': 'sujit@rcl.test', 'name': 'Sujit Mule', 'active': true, 'super': true, 'mustChange': false, 'noPassword': false},
    {'email': 'amol@rcl.test', 'name': 'Amol Patil', 'active': true, 'super': false, 'mustChange': false, 'noPassword': false},
    {'email': 'ravi@rcl.test', 'name': 'Ravi Shinde', 'active': false, 'super': false, 'mustChange': true, 'noPassword': false},
  ];
  final saSites = <Map<String, dynamic>>[
    {'code': 'S1', 'name': 'VTR Site – NH 848', 'company_id': 'RACHANA', 'status': 'active', 'sort': 1},
    {'code': 'T2', 'name': '18B Kolhapur', 'company_id': 'RACHANA', 'status': 'active', 'sort': 2},
    {'code': 'K7', 'name': 'Karad Bypass', 'company_id': null, 'status': 'closed', 'sort': 3},
  ];
  final saModules = <Map<String, dynamic>>[
    {'key': 'mechanical', 'name': 'Mechanical', 'url': 'https://erp.test', 'status': 'live', 'sort': 1},
    {'key': 'store', 'name': 'Store', 'url': 'https://erp.test/store', 'status': 'live', 'sort': 2},
    {'key': 'hr', 'name': 'HR', 'url': null, 'status': 'off', 'sort': 3},
  ];
  final saCompanies = <Map<String, dynamic>>[
    {'id': 'RACHANA', 'name': 'Rachana Construction', 'address': 'Nashik', 'gstin': '27ABCDE1234F1Z5', 'pan': 'ABCDE1234F', 'logo': ''},
    {'id': 'SKETCHLINE', 'name': 'Sketchline', 'address': '', 'gstin': '', 'pan': '', 'logo': ''},
  ];
  final saAccess = <Map<String, dynamic>>[
    {'email': 'amol@rcl.test', 'site': 'S1', 'module': 'mechanical', 'role': 'user', 'pages': null},
    {'email': 'amol@rcl.test', 'site': 'S1', 'module': 'store', 'role': 'user', 'pages': {'dashboard': 'View', 'items': 'View'}},
    {'email': 'ravi@rcl.test', 'site': 'S1', 'module': 'mechanical', 'role': 'admin', 'pages': null},
  ];
  final saAudit = <Map<String, dynamic>>[
    {'at': '2026-10-16T13:35:12Z', 'actor': 'sujit@rcl.test', 'action': 'Access', 'target': 'amol@rcl.test', 'detail': {'site': 'S1', 'module': 'store', 'role': 'user'}},
    {'at': '2026-10-16T09:02:00Z', 'actor': 'amol@rcl.test', 'action': 'Signed in', 'target': '', 'detail': null},
  ];
  final mechUserPerms = <String, Map<String, String>>{'amol@rcl.test': {'diesel': 'Edit', 'log': 'View'}};
  static const mechPageList = [
    {'key': 'diesel', 'label': 'Diesel Issue'},
    {'key': 'log', 'label': 'Log Book'},
    {'key': 'reports', 'label': 'Reports'},
  ];
  List<Map<String, dynamic>> sitePlaces = [
    {'name': 'Camp Pump', 'cap': 18000, 'used': true, 'stock': 12450.5},
    {'name': 'MH12ZE1739', 'cap': 2650, 'used': false, 'stock': 800},
  ];
  bool siteKey = false, siteTables = false; // the New site checklist: the key in Vercel, Mechanical's tables run
  static const kStorePages = [
    {'key': 'dashboard', 'label': 'Dashboard', 'opts': ['View', 'None']},
    {'key': 'items', 'label': 'Item Master', 'opts': ['Edit', 'View', 'None']},
  ];

  http.Response _no(String msg, [int code = 400, String c = '']) => _j({'error': msg, if (c.isNotEmpty) 'code': c}, code);

  http.Response _admin(String a, Map<String, dynamic> x) {
    Map<String, dynamic>? user(String e) => saUsers.where((u) => u['email'] == e).firstOrNull;
    Map<String, dynamic>? acc(String e, String site, String m) => saAccess.where((y) => y['email'] == e && y['site'] == site && y['module'] == m).firstOrNull;
    bool siteOk(String c) => saSites.any((y) => y['code'] == c);
    void log(String what, String target, [Object? detail]) => saAudit.insert(0, {'at': '2026-10-17T10:00:00Z', 'actor': 'sujit@rcl.test', 'action': what, 'target': target, 'detail': detail});
    final email = '${x['email'] ?? ''}'.trim().toLowerCase(), site = '${x['site'] ?? ''}'.toUpperCase();
    switch (a) {
      case 'overview':
        {
          return _j({'users': saUsers, 'sites': saSites, 'modules': saModules, 'companies': saCompanies, 'access': saAccess, 'storePages': kStorePages});
        }
      case 'userSave':
        {
          if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) return _no('Enter a proper email.');
          final cur = user(email), temp = '${x['newPassword'] ?? ''}', name = '${x['name'] ?? ''}'.trim();
          if (cur != null && cur['super'] == true) return _no('The Super Admin changes his own account under "My account".');
          if (temp.isNotEmpty && temp.length < 6) return _no('Give a one-time password of at least 6 characters – the user must change it at the first sign-in.');
          if (x['isNew'] == true) {
            if (cur != null) return _no('$email is already a user.', 409);
            if (temp.isEmpty) return _no('Give a one-time password of at least 6 characters – the user must change it at the first sign-in.');
            if (name.length < 2) return _no('Enter the name of the user (2 to 80 letters).');
            saUsers.add({'email': email, 'name': name, 'active': x['active'] != false, 'super': false, 'mustChange': true, 'noPassword': false});
            log('User added', email, {'name': name});
            return _j({'ok': true, 'added': true});
          }
          if (cur == null) return _no('User $email was not found.', 404);
          if (name.isNotEmpty) cur['name'] = name;
          if (x['active'] is bool) cur['active'] = x['active'];
          if (temp.isNotEmpty) cur['mustChange'] = true;
          return _j({'ok': true, 'changed': true});
        }
      case 'accessSet':
        {
          final u = user(email), role = '${x['role'] ?? ''}', m = '${x['module'] ?? ''}';
          if (u == null) return _no('User $email was not found.', 404);
          if (!siteOk(site)) return _no('This site is not in the list.', 404);
          if (role.isNotEmpty && !['admin', 'user'].contains(role)) return _no('Choose Admin, User or No access.');
          saAccess.removeWhere((y) => y['email'] == email && y['site'] == site && y['module'] == m);
          if (role.isNotEmpty) saAccess.add({'email': email, 'site': site, 'module': m, 'role': role, 'pages': null});
          log('Access', email, {'site': site, 'module': m, 'role': role.isEmpty ? 'none' : role});
          return _j({'ok': true});
        }
      case 'mechPages':
        {
          if (!siteOk(site)) return _no('Pick a site.');
          return _j({'site': site, 'pages': mechPageList, 'users': [for (final e in mechUserPerms.entries) {'email': e.key, 'perms': e.value}]});
        }
      case 'mechPagesSave':
        {
          final y = acc(email, site, 'mechanical');
          if (y == null) return _no('First give him Mechanical on this site (Admin or User), then his pages.', 400, 'noaccess');
          final given = (x['perms'] as Map).map((k, v) => MapEntry('$k', '$v')), was = mechUserPerms[email] ?? {};
          final ch = [for (final e in given.entries) if (was[e.key] != e.value) e.key];
          mechUserPerms[email] = given;
          return _j({'ok': true, 'added': was.isEmpty, 'changes': ch.join(', ')});
        }
      case 'storePagesSave':
        {
          final y = acc(email, site, 'store');
          if (y == null) return _no('First give him the Store on this site (Admin or User), then his pages.', 400, 'noaccess');
          if (y['role'] == 'admin') return _no('A Store Admin has every page. To give single pages, make him User first.', 400, 'admin');
          y['pages'] = x['pages'];
          return _j({'ok': true, 'pages': x['pages']});
        }
      case 'placesGet':
        {
          if (!siteOk(site)) return _no('Pick a site.');
          return _j({'site': site, 'places': sitePlaces, 'set': true, 'entries': true, 'firstFixed': true});
        }
      case 'placesSave':
        {
          final l = [for (final p in (x['places'] as List? ?? const [])) if (p is Map) {'name': '${p['name'] ?? ''}', 'cap': p['cap'] ?? 0}];
          if (l.isEmpty) return _no('Add at least one diesel place (its name and tank size).');
          sitePlaces = [for (final p in l) {...p, 'used': p['name'] == 'Camp Pump', 'stock': p['name'] == 'Camp Pump' ? 12450.5 : 0}];
          return _j({'ok': true, 'site': site, 'places': sitePlaces, 'set': true, 'entries': true, 'firstFixed': true});
        }
      case 'siteSave':
        {
          final cur = saSites.where((y) => y['code'] == '${x['code']}'.toUpperCase()).firstOrNull;
          if ('${x['name'] ?? ''}'.trim().length < 2) return _no('Give the site a name (2 to 80 letters).');
          if (cur == null) return _no('This site is not in the list.', 404);
          cur['name'] = '${x['name']}'.trim();
          cur['company_id'] = '${x['company'] ?? ''}'.isEmpty ? null : x['company'];
          cur['status'] = x['status'];
          return _j({'ok': true});
        }
      case 'siteSetup':
        {
          final code = '${x['code'] ?? ''}'.trim().toUpperCase(), url = '${x['url'] ?? ''}'.trim();
          if (!RegExp(r'^[A-Z0-9]{1,12}$').hasMatch(code)) return _no('The site code: 1 to 12 capital letters or digits (e.g. VTR, 18B).');
          if ('${x['name'] ?? ''}'.trim().length < 2) return _no('Give the site a name (2 to 80 letters).');
          if (!siteOk(code)) saSites.add({'code': code, 'name': '${x['name']}'.trim(), 'company_id': '${x['company'] ?? ''}'.isEmpty ? null : x['company'], 'status': 'closed', 'sort': saSites.length + 1});
          final steps = <Map<String, dynamic>>[];
          Map<String, dynamic> out([Map<String, dynamic> more = const {}]) => {'site': code, 'keyName': 'SITE_${code}_KEY', 'steps': steps, 'ready': false, ...more};
          const ref = 'abcdefghijklmnopqrst';
          if (!RegExp(r'^https://[a-z0-9]{20}\.supabase\.co$').hasMatch(url)) {
            steps.add({'step': 'link', 'ok': false, 'note': 'The link must be the project\'s address, like https://abcdefghijklmnopqrst.supabase.co (Supabase → the project → Connect).'});
            return _j(out());
          }
          steps.add({'step': 'link', 'ok': true, 'note': ''});
          final links = {'sqlLink': 'https://supabase.com/dashboard/project/$ref/sql/new', 'keysLink': 'https://supabase.com/dashboard/project/$ref/settings/api-keys'};
          steps.add({'step': 'key', 'ok': siteKey, 'note': 'Vercel → …'});
          if (!siteKey) return _j(out(links));
          steps.add({'step': 'connect', 'ok': true, 'note': ''});
          steps.add({'step': 'tables', 'ok': siteTables, 'note': siteTables ? '' : 'Not there yet: rcl_diesel_issue · rcl_log_book'});
          if (!siteTables) return _j(out({'sqlLink': links['sqlLink']}));
          steps.add({'step': 'company', 'ok': true, 'note': ''});
          steps.add({'step': 'places', 'ok': true, 'note': '2 diesel places set'});
          steps.add({'step': 'ready', 'ok': true, 'note': ''});
          saSites.firstWhere((y) => y['code'] == code)['status'] = 'active';
          return _j(out({'ready': true, 'backupEmail': 'backup@rcl-erp.iam.test'}));
        }
      case 'siteSql':
        {
          return _j({'sql': '-- Mechanical\n${'create table x (id int);\n' * 200}', 'files': ['supabase_step1.sql']});
        }
      case 'siteDelete':
        {
          final code = '${x['code'] ?? ''}'.toUpperCase(), cur = saSites.where((y) => y['code'] == code).firstOrNull;
          if (cur == null) return _no('This site is not in the list.', 404);
          if (cur['status'] != 'closed') return _no('First set the site to Closed and Save – then delete it.', 400, 'notclosed');
          if ('${x['confirm'] ?? ''}'.trim().toUpperCase() != code) return _no('Type the site code ($code) to delete it.', 400, 'confirm');
          final n = saAccess.where((y) => y['site'] == code).length;
          saAccess.removeWhere((y) => y['site'] == code);
          saSites.remove(cur);
          return _j({'ok': true, 'accessRemoved': n});
        }
      case 'companySave':
        {
          final name = '${x['name'] ?? ''}'.trim(), gstin = '${x['gstin'] ?? ''}'.trim().toUpperCase(), id = '${x['id'] ?? ''}';
          if (name.length < 2) return _no('Enter the name of the company (2 to 80 letters).');
          if (gstin.isNotEmpty && !RegExp(r'^\d{2}[A-Z]{5}\d{4}[A-Z][A-Z\d]Z[A-Z\d]$').hasMatch(gstin)) return _no('GST Number "$gstin" is not in the right format (15 characters, e.g. 27ABCDE1234F1Z5).');
          final row = {'name': name, 'gstin': gstin, 'pan': '${x['pan'] ?? ''}'.toUpperCase(), 'address': '${x['address'] ?? ''}', 'logo': '${x['logo'] ?? ''}'};
          if (id.isNotEmpty) {
            saCompanies.firstWhere((c) => c['id'] == id).addAll(row);
            return _j({'ok': true, 'id': id});
          }
          final nid = name.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]+'), '');
          saCompanies.add({'id': nid, ...row});
          return _j({'ok': true, 'id': nid});
        }
      case 'companyDelete':
        {
          final used = saSites.where((y) => y['company_id'] == x['id']).map((y) => y['code']).toList();
          if (used.isNotEmpty) return _no('Sites of this company: ${used.join(', ')} – give them another company first (Sites), then delete it.', 400, 'inuse');
          saCompanies.removeWhere((c) => c['id'] == x['id']);
          return _j({'ok': true});
        }
      case 'moduleSave':
        {
          final key = '${x['key'] ?? ''}', url = '${x['url'] ?? ''}', status = '${x['status'] ?? 'off'}';
          if (!RegExp(r'^[a-z]{2,20}$').hasMatch(key)) return _no('The module key: 2 to 20 small letters (e.g. store).');
          if (status == 'live' && url.isEmpty) return _no('A module can be Live only with its link.');
          final cur = saModules.where((m) => m['key'] == key).firstOrNull;
          if (x['isNew'] == true) {
            if (cur != null) return _no('This module is already there.', 409);
            saModules.add({'key': key, 'name': '${x['name']}'.trim(), 'url': url.isEmpty ? null : url, 'status': status, 'sort': saModules.length + 1});
          } else {
            final m = cur!;
            m['url'] = url.isEmpty ? null : url;
            m['status'] = status;
            if ('${x['name'] ?? ''}'.trim().isNotEmpty) m['name'] = '${x['name']}'.trim();
          }
          return _j({'ok': true});
        }
      case 'moduleDelete':
        {
          final key = '${x['key'] ?? ''}', m = saModules.where((y) => y['key'] == key).firstOrNull;
          if (m == null) return _no('This module is not in the list.', 404);
          if (key == 'mechanical') return _no('Mechanical cannot be deleted – the sites and the pages are set up through it. Set it Off instead.', 400, 'mech');
          if (m['status'] != 'off') return _no('First set the module Off and Save – then delete it.', 400, 'notoff');
          if ('${x['confirm'] ?? ''}'.trim().toLowerCase() != key) return _no('Type the module key ($key) to delete it.', 400, 'confirm');
          final n = saAccess.where((y) => y['module'] == key).length;
          saAccess.removeWhere((y) => y['module'] == key);
          saModules.remove(m);
          return _j({'ok': true, 'accessRemoved': n});
        }
      case 'audit':
        {
          return _j({'rows': saAudit});
        }
    }
    return _no('Unknown action.', 404);
  }

  late final client = MockClient((r) async {
    final path = r.url.path;
    if (down && path.endsWith('/api/rpc')) throw http.ClientException('no network');
    if (path.endsWith('/portal/api/auth')) {
      final b = jsonDecode(r.body) as Map;
      calls.add('portal:${b['action']}');
      if (r.headers['X-RCL'] != '1') return _j({'error': 'Refused'}, 403);
      if (b['action'] == 'login') {
        if (b['password'] != 'Nashik#Road848!') return _j({'error': 'Email or password is wrong.', 'code': 'wrong'}, 401);
        portalSignedIn = true;
        return _j({'user': {'email': b['email'], 'name': 'Sujit Mule', 'super': superAdmin}, 'mustChange': mustChange}, 200, {'set-cookie': 'rcl_portal=abc123; Path=/; HttpOnly; Secure; SameSite=Lax'});
      }
      if (b['action'] == 'me') {
        if (!portalSignedIn || r.headers['Cookie'] != 'rcl_portal=abc123') return _j({'signedIn': false});
        // (as the Portal: still on a given password – no module until his own is set)
        if (mustChange) return _j({'signedIn': true, 'mustChange': true, 'user': {'email': 'sujit@rcl.test', 'name': 'Sujit Mule'}, 'items': []});
        return _j({'signedIn': true, 'start': start, 'user': {'email': 'sujit@rcl.test', 'name': 'Sujit Mule', 'super': superAdmin}, 'items': [
          {'site': 'S1', 'siteName': 'VTR Site – NH 848', 'company': 'RCL', 'module': 'mechanical', 'moduleName': 'Mechanical', 'url': 'https://erp.test'},
          {'site': 'S1', 'siteName': 'VTR Site – NH 848', 'company': 'RCL', 'module': 'store', 'moduleName': 'Store', 'url': 'https://erp.test/store'},
          {'site': 'T2', 'siteName': '18B Kolhapur', 'company': 'RCL', 'module': 'mechanical', 'moduleName': 'Mechanical', 'url': 'https://erp.test'},
          {'site': 'X9', 'siteName': 'Bad', 'company': '', 'module': 'mechanical', 'moduleName': 'Mechanical', 'url': 'javascript:alert(1)'},
          {'site': 'Z5', 'siteName': 'Store only', 'company': '', 'module': 'store', 'moduleName': 'Store', 'url': 'https://erp.test/store'},
        ]});
      }
      if (b['action'] == 'setStart') {
        start = b['module'] == '' ? '' : '${b['module']}|${b['site']}';
        return _j({'ok': true, 'start': start});
      }
      if (b['action'] == 'changePassword') {
        if (!portalSignedIn) return _j({'error': 'Please sign in.', 'code': 'signin'}, 401);
        if (b['old'] != 'Nashik#Road848!') return _j({'error': 'Current password is wrong.', 'code': 'oldpw'}, 400);
        final pw = (b['password'] ?? '').toString();
        if (pw.length < 8 || !RegExp(r'[A-Za-z]').hasMatch(pw) || !RegExp(r'[0-9]').hasMatch(pw)) {
          return _j({'error': 'The password must have at least 8 characters, with letters and numbers.', 'code': 'policy'}, 400);
        }
        mustChange = false;
        newPassword = pw;
        return _j({'ok': true}, 200, {'set-cookie': 'rcl_portal=abc123; Path=/; HttpOnly; Secure; SameSite=Lax'});      // (a fresh sign-in)
      }
      if (b['action'] == 'logout') {
        portalSignedIn = false;
        return _j({'ok': true}, 200, {'set-cookie': 'rcl_portal=; Path=/; Max-Age=0'});
      }
    }
    // (3.17.0) the Portal's Super Admin console: only the Super Admin, signed in (his own password set)
    if (path.endsWith('/portal/api/admin')) {
      final x = (jsonDecode(r.body) as Map).cast<String, dynamic>();
      portalAdminSent.add(x);
      calls.add('admin:${x['action']}');
      if (r.headers['X-RCL'] != '1') return _j({'error': 'Refused'}, 403);
      if (!portalSignedIn || r.headers['Cookie'] != 'rcl_portal=abc123') return _j({'error': 'SESSION_EXPIRED', 'code': 'session'}, 401);
      if (!superAdmin) return _j({'error': 'Only the Super Admin can do this.', 'code': 'forbidden'}, 403);
      return _admin('${x['action']}', x);
    }
    if (path.endsWith('/portal/api/go')) {
      final q = r.url.queryParameters;
      calls.add('portal:go:${q['module']}:${q['site']}');
      if (q['json'] != '1' || r.headers['X-RCL'] != '1') return _j({'error': 'Refused'}, 403);
      if (!portalSignedIn) return _j({'error': 'Sign in on the Portal first.', 'code': 'signin'}, 401);
      tickets++;
      return _j({'ticket': 'tk$tickets'});
    }
    if (r.url.host == 'ifsc.razorpay.com') {
      calls.add('ifsc:${r.url.path}');
      return r.url.path == '/SBIN0001234' ? _j({'BANK': 'State Bank of India', 'BRANCH': 'Nashik Road', 'CITY': 'Nashik', 'STATE': 'Maharashtra'}) : _j('Not Found', 404);
    }
    if (path.endsWith('/store/api/sso')) {
      final b = jsonDecode(r.body) as Map;
      storeSent.add({'fn': 'sso', 'ticket': b['ticket']});
      if (r.headers['X-RCL'] != '1') return _j({'error': 'Refused: this request did not come from the Store page.'}, 403);
      storeSessions++;
      return _j({'ok': true, 'user': {'email': 'sujit@rcl.test', 'name': 'Sujit Mule', 'admin': true}, 'pages': {'dashboard': 'View', 'items': 'Edit'}, 'site': 'S1', 'siteName': 'VTR Site – NH 848'}, 200,
          {'set-cookie': 'rcl_store=S1.store$storeSessions-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa; Path=/; HttpOnly; SameSite=Lax'});
    }
    if (path.endsWith('/store/api/items')) {
      final b = (jsonDecode(r.body) as Map).cast<String, dynamic>();
      storeSent.add({'cookie': r.headers['Cookie'], ...b});
      if (!'${r.headers['Cookie']}'.startsWith('rcl_store=S1.store')) return _j({'error': 'SESSION_EXPIRED', 'code': 'session'}, 401);
      switch (b['action']) {
        case 'list':
          return _j({'items': storeItems, 'units': ['Nos', 'Kg', 'Ltr', 'Mtr'], 'categories': ['Canteen', 'Spare Parts'], 'admin': true, 'site': 'S1'});
        case 'check':
          final n = '${b['name']}'.trim();
          final near = n.toLowerCase() == 'sugaar' ? [{'code': 'ITM-0002', 'name': 'Sugar', 'unit': 'Kg', 'category': 'Canteen', 'why': 'spelling'}] : [];
          return _j({'proper': {'name': n == 'hydrolic pump' ? 'Hydraulic Pump' : n, 'fixes': n == 'hydrolic pump' ? ['hydrolic → hydraulic'] : []}, 'exact': null, 'similar': near, 'cat': {'category': b['category'], 'near': []}});
        case 'save':
          final it = (b['item'] as Map).cast<String, dynamic>();
          if ('${it['name']}'.toLowerCase() == 'sugaar' && !((b['confirm'] as List?) ?? const []).contains('ITM-0002')) {
            return _j({'error': 'Please confirm: "Sugar" (ITM-0002) is already there – is "Sugaar" a different item?', 'code': 'similar', 'similar': [{'code': 'ITM-0002', 'name': 'Sugar', 'unit': 'Kg', 'category': 'Canteen', 'why': 'spelling'}]}, 409);
          }
          final out = {'code': 'ITM-000${storeItems.length + 1}', 'name': it['name'], 'unit': it['unit'], 'category': it['category'], 'hsn': it['hsn'], 'gst_pct': num.tryParse('${it['gst']}'), 'min_stock': num.tryParse('${it['minStock']}'), 'status': 'Active', 'created_by': 'sujit@rcl.test', 'created_at': '2026-10-14T05:00:00Z'};
          storeItems.add(out);
          return _j({'ok': true, 'item': out});
        case 'remove':
          storeItems.removeWhere((i) => i['code'] == b['code']);
          return _j({'ok': true});
        // (3.13.0) Import from Excel: the report of every row (a name already there left out, "Sugaar" near "Sugar" – confirm)
        case 'import':
          final rows = [for (final r in b['rows'] as List) (r as Map).cast<String, dynamic>()];
          final conf = ((b['confirm'] as Map?) ?? const {}).cast<String, dynamic>();
          final out = [
            for (final r in rows)
              if ('${r['name']}'.isEmpty)
                {'line': r['line'], 'name': r['name'], 'status': 'error', 'msg': 'Item Name is required.'}
              else if (storeItems.any((i) => '${i['name']}'.toLowerCase() == '${r['name']}'.toLowerCase()))
                {'line': r['line'], 'name': r['name'], 'status': 'exists', 'msg': 'Already there.'}
              else if ('${r['name']}'.toLowerCase() == 'sugaar')
                {'line': r['line'], 'name': r['name'], 'status': 'similar', 'similar': [{'code': 'ITM-0002', 'name': 'Sugar'}], 'confirmed': conf.containsKey('${r['line']}')}
              else
                {'line': r['line'], 'name': r['name'], 'status': 'new', 'catNote': ''},
          ];
          final rep = {
            'fresh': out.where((x) => x['status'] == 'new').length,
            'exists': out.where((x) => x['status'] == 'exists').length,
            'similar': out.where((x) => x['status'] == 'similar').length,
            'errors': out.where((x) => x['status'] == 'error').length,
            'rows': out,
          };
          if (b['check'] == true) return _j(rep);
          if (out.any((x) => x['status'] == 'similar' && x['confirmed'] != true)) return _j({'error': 'Confirm the near names first.', 'code': 'similar', 'report': rep}, 409);
          var added = 0;
          for (final x in out) {
            if (x['status'] == 'new' || x['status'] == 'similar') {
              added++;
              storeItems.add({'code': 'ITM-00${10 + added}', 'name': x['name'], 'unit': 'Nos', 'category': 'Spare Parts', 'hsn': '', 'gst_pct': null, 'min_stock': null, 'status': 'Active', 'created_by': 'sujit@rcl.test', 'created_at': '2026-10-14T05:00:00Z'});
            }
          }
          return _j({'ok': true, 'added': added, 'exists': rep['exists']});
      }
      return _j({'error': 'Unknown action.'}, 404);
    }
    if (path.endsWith('/api/rpc')) {
      final b = jsonDecode(r.body) as Map;
      final fn = b['fn'] as String, args = b['args'] as List;
      if (fn == 'ssoLogin') {
        calls.add('mech:ssoLogin:${args[0]}');
        return _j({'result': {'token': 'tok-${args[0]}', 'user': {'email': 'sujit@rcl.test', 'name': 'Sujit Mule', 'admin': superAdmin, 'super': superAdmin, 'perms': perms}, 'site': b['site'], 'siteName': b['site'] == 'S1' ? 'VTR Site – NH 848' : '18B Kolhapur'}});
      }
      if (fn == 'logout') {
        calls.add('mech:logout');
        return _j({'result': true});
      }
      final action = args[1] as String, a = args[2] as List;
      calls.add('mech:$action${b['rid'] != null ? '+rid' : ''}');
      if (!(args[0] as String).startsWith('tok-')) return _j({'error': 'SESSION_EXPIRED'}, 401);
      if (expireOnce == action) {
        expireOnce = '';
        return _j({'error': 'SESSION_EXPIRED'}, 401);
      }
      final stock = {'stock': 1133, 'byLoc': {'Dispenser': 813, 'VTR Store': 320}};
      const lockMsg = 'Log Book entry of MH-25-AJ-2169 on 14-10-2026: this machinery is in the submitted RA Bill 9 of Rana (RCL, 01-10-2026 to 14-10-2026) – its Log Book and diesel entries of those dates cannot be added, changed or deleted without the Super Admin.';
      if (billLock && !superAdmin && action == 'updateLogRow') return _j({'error': lockMsg}, 500);
      if (billLock && !superAdmin && action == 'saveLogRows') return _j({'result': {'ok': false, 'errors': [{'row': 1, 'msg': lockMsg}]}});
      if (action == 'sendChangeRequest') {
        requests.add((a[0] as Map).cast<String, dynamic>());
        return _j({'result': {'ok': true, 'id': 'CR-0000${requests.length}'}});
      }
      if (b['rid'] != null) rids.add('$action:${b['rid']}');
      if (flowFor == action) return _j({'error': 'Sent for verification to Checker One – VF-00007. It is saved when it is approved; nothing is saved until then.'}, 500);
      switch (action) {
        case 'sync':
          return _j({'result': {'versions': versions}});
        case 'getChangeRequests':
          return _j({'result': {'requests': flowReqs, 'pending': crPending, 'forMe': crForMe}});
        case 'remindFlow':
          final x = (a[0] as Map).cast<String, dynamic>();
          final ids = x['all'] == true ? flowReqs.where((r) => r['canRemind'] == true).map((r) => '${r['id']}').toList() : (x['ids'] as List).map((e) => '$e').toList();
          reminded.add(ids);
          for (final r in flowReqs.where((r) => ids.contains(r['id']))) {
            r['reminds'] = ((r['reminds'] as num?) ?? 0) + 1;
            r['remindedAt'] = DateTime.now().toUtc().toIso8601String();
          }
          return _j({'result': {'ok': true, 'reminded': ids, 'later': [], 'list': {'requests': flowReqs, 'pending': crPending, 'forMe': crForMe}}});
        // (3.2.0) the reports: the real answers of the test server (test/fixtures/reports)
        case 'rptDebit' || 'rptMachineCost' || 'rptCost' || 'rptPurchase' || 'rptLedger' || 'rptWatch' || 'rptOwner' || 'rptType' || 'rptStock' || 'rptCompare' || 'rptTank' || 'rptAverage' || 'getDailyInwardIssueReport' || 'getMonthlyDieselReport' || 'getMonthlyAvgReport':
          reportAsked.add({'fn': action, ...((a.isNotEmpty ? a[0] : const {}) as Map).cast<String, dynamic>()});
          return _j({'result': jsonDecode(File('test/fixtures/reports/$action.json').readAsStringSync())});
        case 'saveDebitRates':
          return _j({'result': {'ok': true, 'count': (a[0] as List).length}});
        // (3.2.0) the Approvals screen: decide one / several, answer, the rules
        case 'decideChangeRequest':
          final x = (a[0] as Map).cast<String, dynamic>();
          decided.add(x);
          final r = flowReqs.firstWhere((r) => r['id'] == x['id']);
          final st = x['revert'] == true ? 'Reverted' : x['approve'] == true ? 'Approved' : 'Rejected';
          r['status'] = st;
          r['canDecide'] = false;
          r['decidedBy'] = 'Sujit Mule';
          r['note'] = '${x['note'] ?? ''}';
          return _j({'result': {'ok': true, 'id': x['id'], 'status': st, 'level': 1, 'levels': 1, 'list': {'requests': flowReqs, 'pending': crPending, 'forMe': crForMe}}});
        case 'decideChangeRequests':
          final x = (a[0] as Map).cast<String, dynamic>();
          decided.add(x);
          final ids = (x['ids'] as List).map((e) => '$e').toList();
          for (final r in flowReqs.where((r) => ids.contains(r['id']))) {
            r['status'] = x['revert'] == true ? 'Reverted' : x['approve'] == true ? 'Approved' : 'Rejected';
            r['canDecide'] = false;
          }
          return _j({'result': {'ok': true, 'done': [for (final id in ids) {'id': id, 'status': 'Approved'}], 'failed': [], 'list': {'requests': flowReqs, 'pending': crPending, 'forMe': crForMe}}});
        case 'answerFlow':
          final x = (a[0] as Map).cast<String, dynamic>();
          decided.add({'answer': true, ...x});
          final r = flowReqs.firstWhere((r) => r['id'] == x['id']);
          r['status'] = x['withdraw'] == true ? 'Withdrawn' : 'Pending';
          r['canAnswer'] = false;
          return _j({'result': {'ok': true, 'id': x['id'], 'status': r['status'], 'list': {'requests': flowReqs, 'pending': crPending, 'forMe': crForMe}}});
        case 'getFlowRules':
          return _j({'result': {
            'tasks': [{'m': 'Diesel Issue', 'label': 'Diesel Issue', 'fns': ['saveDieselIssue'], 'diesel': true}, {'m': 'Log Book', 'label': 'Log Book', 'fns': ['saveLogRows'], 'diesel': false}],
            'rules': {'remindHours': 4, 'tasks': {'Diesel Issue': {'on': true, 'levels': [['mahesh@rcl.test']], 'daysBack': '', 'qtyAbove': '200'}}},
            'users': [{'email': 'mahesh@rcl.test', 'name': 'Mahesh Jadhav'}, {'email': 'shubham@rcl.test', 'name': 'Shubham'}],
          }});
        case 'saveFlowRules':
          rulesSaved.add((a[0] as Map).cast<String, dynamic>());
          return _j({'result': {'ok': true, 'rules': (a[0] as Map)}});
        case 'getStock':
          return _j({'result': stock});
        case 'getInit':
          return _j({'result': {'flow': flowMine, 'today': '2026-10-14', 'company': 'Rachana Construction Limited', 'locations': ['Dispenser', 'VTR Store'], 'drivers': ['Gupta', 'Maruti'], 'pumps': ['IOC Bunk'], 'stock': stock,
            'user': {'email': 'sujit@rcl.test', 'name': 'Sujit Mule', 'admin': superAdmin, 'super': superAdmin, 'perms': perms},
            'master': _master, 'ai': {'on': aiOn}}});
        // (3.4.0) the masters
        case 'getVendors':
          return _j({'result': vendors});
        case 'getBoqs':
          return _j({'result': {'vendors': vendors, 'boqs': boqs}});
        case 'saveMaster':
          final m = (a[0] as Map).cast<String, dynamic>();
          masterCalls.add({'fn': action, 'm': m, 'mode': a[1], 'id': a.length > 2 ? a[2] : null});
          final id = '${m['no'] ?? ''}'.isNotEmpty ? '${m['no']}' : '${m['name']}';
          if (a[1] == 'add') {
            master.add({...m, 'id': id, 'worksOn': _works(m['worksOn'])});
          } else {
            final i = master.indexWhere((x) => x['id'] == a[2]);
            master[i] = {...master[i], ...m, 'id': id, 'worksOn': _works(m['worksOn'])};
          }
          return _j({'result': {'ok': true, 'master': _master, 'renamed': a[1] == 'edit' && id != a[2] ? {'from': a[2], 'to': id, 'text': '3 diesel issues'} : null}});
        case 'saveMasterBulk':
          final list = (a[0] as List).whereType<Map>().map((x) => x.cast<String, dynamic>()).toList();
          masterCalls.add({'fn': action, 'list': list});
          final errs = [
            for (final (k, m) in list.indexed)
              if (['no', 'name', 'type', 'make', 'unit', 'kmStd', 'hrStd', 'owner', 'ownership'].any((f) => '${m[f] ?? ''}'.isNotEmpty) && '${m['ownership']}'.isEmpty) {'row': k + 1, 'msg': '${'${m['no']}'.isNotEmpty ? m['no'] : m['name']}: select Ownership (Own / Rental / Hired / Debit / Other).'}
          ];
          if (errs.isNotEmpty) return _j({'result': {'ok': false, 'errors': errs}});
          final add = list.where((m) => '${m['no']}${m['name']}'.isNotEmpty).toList();
          for (final m in add) {
            master.add({...m, 'id': '${m['no']}'.isNotEmpty ? m['no'] : m['name'], 'status': 'Active'});
          }
          return _j({'result': {'ok': true, 'count': add.length, 'master': _master}});
        case 'deleteMaster':
          masterCalls.add({'fn': action, 'id': a[0], 'force': a[1]});
          if (a[1] != true && a[0] == 'MH-25-AJ-2169') return _j({'result': {'ok': false, 'warning': 'MH-25-AJ-2169 has 3 Diesel Issue and 2 Log Book entries. Those entries will stay, but this machinery will be removed from Master. Delete anyway?'}});
          master.removeWhere((x) => x['id'] == a[0]);
          return _j({'result': {'ok': true, 'master': _master}});
        case 'editMasterMany':
          final ids = (a[0] as List).map((e) => '$e').toList(), ch = (a[1] as Map).cast<String, dynamic>();
          masterCalls.add({'fn': action, 'ids': ids, 'changes': ch});
          for (final m in master.where((x) => ids.contains(x['id']))) {
            m.addAll(ch);
          }
          return _j({'result': {'ok': true, 'count': ids.length, 'master': _master}});
        case 'deleteMasterMany':
          final ids = (a[0] as List).map((e) => '$e').toList();
          masterCalls.add({'fn': action, 'ids': ids, 'force': a[1]});
          if (a[1] != true && ids.contains('MH-25-AJ-2169')) return _j({'result': {'ok': false, 'used': [{'id': 'MH-25-AJ-2169', 'diesel': 3, 'log': 2}]}});
          master.removeWhere((x) => ids.contains(x['id']));
          return _j({'result': {'ok': true, 'count': ids.length, 'ids': ids, 'master': _master}});
        case 'assignVendors':
          final items = (a[0] as List).whereType<Map>().map((x) => x.cast<String, dynamic>()).toList();
          masterCalls.add({'fn': action, 'items': items});
          for (final it in items) {
            master.firstWhere((x) => x['id'] == it['id'])['owner'] = it['vendor'];
          }
          return _j({'result': {'ok': true, 'count': items.length, 'master': _master, 'vendors': vendors}});
        case 'vendorsFromOwners':
          masterCalls.add({'fn': action, 'names': a[0]});
          return _j({'result': {'ok': true, 'count': (a[0] as List).length, 'names': a[0], 'vendors': vendors}});
        // (3.13.0) Asset Master – Import from Excel: checked (save false), then saved; a row named "BAD" is a mistake
        case 'importMaster':
          final rows = [for (final r in a[0] as List) (r as Map).cast<String, dynamic>()];
          masterCalls.add({'fn': action, 'rows': rows, 'save': a[1]});
          final bad = [for (final r in rows) if (r['name'] == 'BAD') {'row': r['line'], 'msg': 'Type of Machinery is required.'}];
          if (bad.isNotEmpty) return _j({'result': {'errors': bad, 'adds': 0, 'updates': 0, 'same': 0}});
          if (a[1] == true) master.add({'id': 'NEW-1', 'no': '', 'name': 'NEW-1', 'type': 'Roller', 'unit': 'Hrs', 'status': 'Active', 'activeFrom': '2026-10-01', 'owner': 'RCL', 'ownership': 'Own', 'supply': 'Company'});
          return _j({'result': {'errors': [], 'adds': 1, 'updates': rows.length - 1, 'same': 0, if (a[1] == true) 'master': _master}});
        case 'exportMaster':
          return _j({'result': {'headers': ['Machinery Number', 'Machinery Name', 'Type of Machinery', 'Standard Average (KM/Ltr)'], 'rows': [for (final m in master) [m['no'] ?? '', m['name'] ?? '', m['type'] ?? '', m['kmStd'] ?? '']]}});
        case 'getBreakdowns' when bdRich:
          bdSent.add({'fn': action, 'args': a});
          return _j({'result': _bd('${(a[0] as Map)['date'] ?? ''}')});
        case 'getBreakdowns':
          return _j({'result': {'date': (a[0] as Map)['date'], 'history': [], 'onDate': []}});
        case 'submitBdReport':
          bdSent.add({'fn': action, 'x': a[0]});
          final sent = ((a[0] as Map)['rows'] as List).cast<Map>().map((r) => r.cast<String, dynamic>()).toList();
          bdSaved = sent;
          return _j({'result': {'ok': true, 'date': (a[0] as Map)['date'], 'replaced': false, 'total': sent.length, 'count': sent.where((r) => r['status'] == 'Breakdown').length, 'list': ''}});
        case 'deleteBdReport':
          bdSent.add({'fn': action, 'date': a[0]});
          bdSaved = null;
          return _j({'result': {'ok': true, 'date': a[0], 'deleted': true}});
        case 'saveVendor':
          final v = (a[0] as Map).cast<String, dynamic>();
          masterCalls.add({'fn': action, 'v': v, 'mode': a[1]});
          final was = '${v['oldName']}'.isNotEmpty ? '${v['oldName']}' : '${v['name']}';
          final i = vendors.indexWhere((x) => x['name'] == was);
          if (i > -1) {
            vendors[i] = {...vendors[i], ...v, 'saved': true};
          } else {
            vendors.add({...v, 'saved': true, 'machines': [], 'boqs': 0});
          }
          return _j({'result': {'ok': true, 'name': v['name'], 'renamed': '${v['oldName']}'.isNotEmpty ? {'from': v['oldName'], 'to': v['name'], 'text': '1 assets'} : null, 'vendors': vendors}});
        case 'deleteVendor':
          masterCalls.add({'fn': action, 'name': a[0]});
          return _j({'result': {'ok': true}});
        case 'saveBoq':
          final b = (a[0] as Map).cast<String, dynamic>();
          masterCalls.add({'fn': action, 'b': b, 'mode': a[1], 'id': a.length > 2 ? a[2] : null});
          return _j({'result': {'ok': true, 'id': 'BOQ-0002', 'no': '${b['no']}'.isEmpty ? '2' : b['no'], 'amendNo': b['amendOf'] != null ? 1 : 0}});
        case 'deleteBoq':
          masterCalls.add({'fn': action, 'id': a[0]});
          boqs.removeWhere((x) => x['id'] == a[0]);
          return _j({'result': {'ok': true}});
        case 'boqMissing':
          return _j({'result': {'date': (a[0] as Map)['date'], 'rows': [{'no': 'MH-04-J-9844', 'type': 'Water Tanker', 'vendor': 'Chalke Enterprises', 'ownership': 'Rental', 'vendorSaved': true}]}});
        case 'boqRateCheck':
          final x = (a[0] as Map).cast<String, dynamic>();
          return _j({'result': {'no': x['no'], 'date': x['date'], 'vendor': 'I E Enterprises', 'hit': {'line': boqs.first['lines'][0], 'boqNo': '1', 'amendNo': 0, 'from': '2026-09-01', 'to': ''}}});
        case 'getCompliance':
          return _j({'result': _compliance});
        // (3.13.0) Vehicle Compliance – Import Excel: checked (save false), then saved
        case 'importCompliance':
          masterCalls.add({'fn': action, 'rows': a[0], 'save': a[1]});
          return _j({'result': {'errors': [], 'changes': 2, 'machines': 1, 'preview': ['MH-25-AJ-2169 – PUC: 01-10-2026 → 30-09-2027', 'MH-25-AJ-2169 – Permit: – → N/A']}});
        case 'renewDoc':
          masterCalls.add({'fn': action, 'x': a[0]});
          return _j({'result': {'ok': true}});
        case 'saveCmpRules':
          masterCalls.add({'fn': action, 'rules': a[0]});
          return _j({'result': {'ok': true}});
        case 'getLbFormatNames':
          return _j({'result': lbNames});
        case 'saveLbFormatName':
          final x = (a[0] as Map).cast<String, dynamic>();
          masterCalls.add({'fn': action, ...x});
          lbNames['${x['id']}'] = '${x['name']}';
          return _j({'result': {'ok': true, 'names': lbNames}});
        case 'saveLbFormats':
          final ch = (a[0] as Map).cast<String, dynamic>();
          masterCalls.add({'fn': action, 'ch': ch});
          for (final e in ch.entries) {
            master.firstWhere((x) => x['id'] == e.key)['lbFormat'] = e.value;
          }
          return _j({'result': {'ok': true, 'count': ch.length, 'master': _master}});
        // (3.5.0) the Dashboard and Tank Check: the real answers of the test server (test/fixtures/dash)
        case 'getDashboard' || 'logDashboard' || 'pendingLog' || 'getStockLedger' || 'getOwnershipDetail':
          dashAsked.add({'fn': action, 'args': a});
          return _j({'result': jsonDecode(File('test/fixtures/dash/$action.json').readAsStringSync())});
        case 'saveTankSettings':
          masterCalls.add({'fn': action, 'x': a[0]});
          return _j({'result': {'caps': (a[0] as Map)['caps'], 'low': (a[0] as Map)['low']}});
        case 'getTankSystem':
          return _j({'result': {'machine': master.firstWhere((m) => m['id'] == a[0], orElse: () => master.first), 'date': a[1], 'system': 120, 'fromLog': {'date': '2026-10-13', 'shift': 'Day', 'stock': 120}, 'fromCheck': null, 'addedAfter': 60, 'cap': 400}});
        case 'getTankChecks':
          return _j({'result': {'rows': tankChecks}});
        case 'saveTankCheck':
          masterCalls.add({'fn': action, 'x': a[0]});
          return _j({'result': {'ok': true, 'id': 'TC-0002'}});
        case 'deleteTankCheck':
          masterCalls.add({'fn': action, 'id': a[0]});
          tankChecks.removeWhere((x) => x['id'] == a[0]);
          return _j({'result': {'ok': true}});
        case 'getDieselIssues':
          if (a.isNotEmpty && a[0] is Map) listAsked.add({'fn': action, ...(a[0] as Map).cast<String, dynamic>()});
          return _j({'result': {'count': issues.length, 'totalQty': 240, 'rows': issues, 'share': [
            for (final i in issues) {'no': i['no'], 'type': i['type'], 'owner': '', 'entries': 1, 'qty': i['qty']},
          ]}});
        case 'importInward' || 'importDiesel' || 'saveTransferBulk':
          final rows = [for (final r in a[0] as List) (r as Map).cast<String, dynamic>()];
          importSent.add({'fn': action, 'rows': rows});
          final no = rows.where((r) => r['remark'] == 'server says no').toList();
          if (no.isNotEmpty) return _j({'result': {'ok': false, 'errors': [for (final r in no) {'row': r['line'], 'msg': 'The server refused this row.'}]}});
          return _j({'result': {'ok': true, 'count': rows.length, 'qty': rows.fold<num>(0, (x, r) => x + (r['qty'] as num)), 'stock': stock}});
        case 'saveDieselBulk':
          final b = (a[0] as Map).cast<String, dynamic>();
          importSent.add({'fn': action, 'b': b});
          final rows = [for (final r in b['rows'] as List) (r as Map).cast<String, dynamic>()];
          if (b['force'] != true && rows.any((r) => r['hrReading'] == '1')) return _j({'result': {'warnings': [{'row': 1, 'msg': 'The Hrs reading 1 is lower than the last one (4,700).'}]}});
          return _j({'result': {'ok': true, 'count': rows.where((r) => '${r['no']}'.isNotEmpty).length, 'firstId': 'DI-000527', 'lastId': 'DI-000527'}});
        case 'getStockPoints':
          return _j({'result': [for (final _ in a[0] as List) {'balance': 813, 'available': 813}]});
        case 'getInwards':
          return _j({'result': {'count': 1, 'qty': 500, 'stock': stock, 'rows': [{'id': 'IN-000050', 'date': '2026-10-14', 'qty': 500, 'pump': 'IOC Bunk', 'rate': 90, 'amount': 45000, 'billNo': 'B-1', 'billDate': '2026-10-14', 'location': 'VTR Store', 'ph': 2}]}});
        case 'getInwardPhotos': // (3.1.13, update-120) the bill copies of an inward
          return _j({'result': {'id': a[0], 'photos': [for (final n in [1, 2]) {'p': 'inward/2026-10/00000000-0000-0000-0000-00000000000$n.jpg', 'at': '2026-10-14T05:00:00.000Z', 'url': 'https://erp.test/storage/v1/object/sign/diesel-photos/inward/$n.jpg?token=t'}]}});
        case 'inwardPhoto':
          billsSent++;
          return _j({'result': {'ok': true, 'path': 'inward/2026-10/00000000-0000-0000-0000-0000000001${billsSent.toString().padLeft(2, '0')}.jpg'}});
        case 'saveInward':
          saved.add((a[0] as Map).cast<String, dynamic>());
          return _j({'result': {'ok': true, 'id': 'IN-000051', 'stock': stock}});
        case 'updateInward':
          saved.add({'update': a[0], ...(a[1] as Map).cast<String, dynamic>()});
          return _j({'result': {'ok': true, 'id': a[0], 'stock': stock}});
        case 'getTransfers':
          if (a.isNotEmpty && a[0] is Map) listAsked.add({'fn': action, ...(a[0] as Map).cast<String, dynamic>()});
          return _j({'result': {'count': 0, 'qty': 0, 'rows': []}});
        // (3.9.0) Administration
        case 'usersAdmin':
          return _j({'result': {'users': adminUsers, 'modules': [{'key': 'Dashboard', 'label': 'Dashboard'}, {'key': 'Log Book', 'label': 'Log Book'}, {'key': 'Machinery Billing', 'label': 'Machinery Billing'}], 'managedBySuper': usersBySuper, 'canCreateSuper': false}});
        case 'saveUserAdmin':
          adminSent.add({'fn': action, 'x': a[0]});
          final x = (a[0] as Map).cast<String, dynamic>();
          if (x['isNew'] == true) adminUsers.add({'email': x['email'], 'name': x['name'], 'active': x['active'], 'admin': x['admin'], 'mustChange': true, 'perms': x['perms']});
          return _j({'result': {'ok': true}});
        case 'accessReport':
          return _j({'result': {'users': 2, 'modules': 3, 'count': {'written': 5, 'empty': 1, 'admin': 3}, 'rows': [{'name': 'Site Clerk', 'email': 'clerk@rcl.test', 'active': true, 'admin': false, 'module': 'Machinery Billing', 'raw': '', 'effective': 'View', 'why': 'empty'}]}});
        case 'getActivity':
          adminSent.add({'fn': action, 'f': a[0]});
          return _j({'result': {'count': 2, 'rows': [
            {'id': 'L-2', 'when': '14-10-2026 10:12:03', 'email': 'clerk@rcl.test', 'name': 'Site Clerk', 'action': 'Edit', 'module': 'Log Book', 'record': 'MH-25-AJ-2169|2026-10-13|Full Day', 'summary': 'Log Book entry changed', 'changes': 'Close KM: 15100 → 15130; Work: Earth carting → Earth carting (Ch 12+000)'},
            {'id': 'L-1', 'when': '14-10-2026 09:01:44', 'email': 'sujit@rcl.test', 'name': 'Sujit Mule', 'action': 'Login', 'module': '', 'record': '', 'summary': 'Signed in (app)', 'changes': ''},
          ]}});
        case 'saveSiteRules':
          adminSent.add({'fn': action, 'x': a[0]});
          final r = (a[0] as Map).cast<String, dynamic>();
          return _j({'result': {'ok': true, 'rules': {'backDays': r['backDays'] == '' ? '' : int.parse('${r['backDays']}'), 'announce': r['announce'], 'dayFrom': r['dayFrom'], 'nightFrom': r['nightFrom']}}});
        case 'saveOrgSettings':
          adminSent.add({'fn': action, 'x': a[0]});
          return _j({'result': {'ok': true, 'org': a[0]}});
        case 'rtcRights':
          return _j({'result': {'users': [{'uid': 'u1', 'name': 'Site Clerk', 'admin': false, 'on': true}, {'uid': 'u2', 'name': 'Sujit Mule', 'admin': true, 'on': true}]}});
        case 'rtcRightsSave':
          adminSent.add({'fn': action, 'x': a[0]});
          return _j({'result': {'users': [{'uid': 'u1', 'name': 'Site Clerk', 'admin': false, 'on': false}, {'uid': 'u2', 'name': 'Sujit Mule', 'admin': true, 'on': true}]}});
        case 'dbHealth':
          return _j({'result': {'ok': false, 'at': '2026-10-14T05:00:00.000Z', 'checks': [{'name': 'Database answers', 'ok': true, 'fix': '', 'note': ''}, {'name': '"½ day" in the Log Book (step 1v)', 'ok': false, 'fix': 'supabase_step1v_half_day.sql', 'note': ''}]}});
        case 'readme':
          return _j({'result': {'html': _readme, 'adminCols': [{'col': 'email'}, {'col': 'name'}, {'col': 'password_hash'}, {'col': 'active'}, {'col': 'admin'}, {'col': 'perm_dashboard'}, {'col': 'mobile'}]}});
        // (3.8.0) Billing
        case 'getLogBookList' when billing && _arg(a, 'all') == true:
          billSent.add({'fn': action, 'args': a});
          return _j({'result': {'count': 6, 'rows': _billRows, 'summary': []}});
        case 'logPrintExtra' when billing:
          billSent.add({'fn': action, 'args': a});
          return _j({'result': _billExtra});
        case 'billInit':
          return _j({'result': _billInit});
        case 'billCorrections':
          billSent.add({'fn': action, 'args': a});
          return _j({'result': {'items': []}});
        case 'verifyBills':
          final bs = ((a[0] as Map)['bills'] as List).cast<Map>();
          billSent.add({'fn': action, 'bills': bs});
          return _j({'result': {'bills': [
            for (final b in bs) {'vendor': (b['vendor'] as Map)['name'], 'billNo': b['billNo'], 'net': b['I'], 'bad': 0, 'warn': 1, 'checks': [{'s': 'ok', 't': 'Log Book, diesel and BOQ match the bill'}, {'s': 'warn', 't': 'Idle days paid in this bill'}]}
          ]}});
        case 'submitBills':
          billSent.add({'fn': action, 'x': a[0]});
          return _j({'result': {'ok': true, 'saved': [for (var i = 0; i < ((a[0] as Map)['bills'] as List).length; i++) {'id': 'BILL-0000${9 + i}', 'rev': 0}]}});
        case 'getBills' when _arg(a, 'id') != null:
          return _j({'result': {'bills': []}}); // (a test does not open the print view)
        case 'getBills':
          billSent.add({'fn': action, 'args': a});
          return _j({'result': {'bills': _savedBills}});
        case 'getDebitNotes':
          return _j({'result': {'notes': [
            {'id': 'DN-0003', 'no': 'SLI/TST/DN-3', 'date': '2026-09-28', 'vendor': 'I E Enterprises', 'company': 'Sketchline Industries', 'kind': 'Work', 'billNo': '', 'from': '2026-09-20', 'to': '2026-09-21', 'total': 1500, 'status': 'Active'},
          ]}});
        case 'getLookups':
          return _j({'result': {'vendors': ['I E Enterprises', 'Chalke Enterprises']}});
        case 'getDebitPending':
          billSent.add({'fn': action, 'args': a});
          return _j({'result': {'vendor': 'I E Enterprises', 'already': 0, 'rows': [{'logId': 'MH-25-AJ-2169|2026-10-02|Day', 'no': 'MH-25-AJ-2169', 'type': 'Tipper', 'date': '2026-10-02', 'shift': 'Day', 'work': 'Carting for the party', 'qty': 6, 'unit': 'Hrs', 'rate': 1100}]}});
        case 'saveDebitNote':
          billSent.add({'fn': action, 'x': a[0]});
          return _j({'result': {'ok': true, 'no': 'SLI/TST/DN-4', 'vendor': (a[0] as Map)['vendor'], 'total': 6600}});
        case 'vendorLedger':
          billSent.add({'fn': action, 'args': a});
          return _j({'result': _ledger});
        case 'billSummary':
          return _j({'result': {'rows': [
            {'id': 'BILL-00001', 'vendor': 'I E Enterprises', 'company': 'Sketchline Industries', 'billNo': '7', 'rev': 0, 'from': '2026-08-01', 'to': '2026-08-31', 'billDate': '2026-09-05', 'month': '2026-08', 'basic': 45000, 'diesel': 3200, 'other': 0, 'gst': 0, 'gstPct': 0, 'tds': 549.5, 'tdsPct': 1.32, 'net': 41250.5},
          ]}});
        case 'getPayments':
          return _j({'result': {'payments': [
            {'id': 'PAY-00001', 'type': 'Payment', 'date': '2026-09-25', 'vendor': 'I E Enterprises', 'amount': 40000, 'side': 'Payable', 'mode': 'NEFT', 'ref': 'UTR123', 'bill': 'RA 7 (01-08-2026 – 31-08-2026)', 'remark': '', 'enteredBy': 'Tester', 'updatedBy': ''},
          ], 'modes': ['NEFT', 'RTGS', 'IMPS', 'UPI', 'Cheque', 'Cash', 'Adjustment']}});
        case 'savePayment':
          billSent.add({'fn': action, 'x': a[0], 'how': a[1]});
          return _j({'result': {'ok': true, 'id': 'PAY-00002', 'amount': num.tryParse('${(a[0] as Map)['amount']}') ?? 0}});
        case 'vendorOutstanding':
          return _j({'result': {'months': ['2026-08', '2026-09', '2026-10'], 'rows': [
            {'vendor': 'I E Enterprises', 'opening': 5000, 'bills': 39750.5, 'paid': 40000, 'closing': 4750.5, 'monthEnd': [5000, 4750.5, 4750.5], 'lastPay': '2026-09-25'},
          ]}});
        case 'getLogBookList' when ((a.isNotEmpty ? a[0] : null) as Map?)?['no'] == 'MH-25-AJ-2169':
          return _j({'result': {'count': 3, 'rows': _editRows, 'summary': []}});
        // (3.6.0) Edit Log Book
        case 'getLogEditData':
          logBulk.add({'fn': action, 'args': a});
          return _j({'result': _editData('${a[1]}', '${a[2]}')});
        case 'saveLogBulk':
          logBulk.add({'fn': action, 'x': a[0]});
          final rs = ((a[0] as Map)['rows'] as List).cast<Map>();
          return _j({'result': {'ok': true, 'no': (a[0] as Map)['no'], 'changed': rs.where((r) => r['same'] != true && '${r['key']}'.isNotEmpty).length, 'added': rs.where((r) => '${r['key']}'.isEmpty).length, 'deleted': ((a[0] as Map)['deleted'] as List).length, 'shifted': 0}});
        case 'getTankerRange':
          logBulk.add({'fn': action, 'args': a});
          return _j({'result': _tankerRange('${a[1]}', '${a[2]}', _tTrips)});
        case 'saveTankerRange':
          logBulk.add({'fn': action, 'x': a[0]});
          return _j({'result': {..._tankerRange('${(a[0] as Map)['from']}', '${(a[0] as Map)['to']}', (a[0] as Map)['trips'] as List), 'ok': true, 'changed': 1, 'added': 1, 'removed': 0}});
        // (3.13.0) a water tanker's trips from a file
        case 'checkTankerImport':
          logBulk.add({'fn': action, 'x': a[0]});
          return _j({'result': {'ok': true, 'errors': [], 'added': 2, 'same': 1, 'tankers': 1}});
        case 'importTankerTrips':
          logBulk.add({'fn': action, 'x': a[0]});
          return _j({'result': {'ok': true, 'added': 2, 'same': 1}});
        case 'logPrintExtra':
          return _j({'result': {'debit': {}, 'boq': {}, 'issues': {}, 'avgRate': 90, 'lastRate': 92}});
        // (3.12.0) Log Book – all dates (the web's list filter has "ownership"), the import
        case 'getLogBookList' when ((a.isNotEmpty ? a[0] : null) as Map?)?.containsKey('ownership') == true:
          listAsked.add({'fn': action, ...(a[0] as Map).cast<String, dynamic>()});
          return _j({'result': {'count': 3, 'rows': [
            {'date': '2026-10-14', 'no': 'Sany 210 (No.1)', 'type': 'Excavator', 'owner': 'RCL', 'shift': 'Full Day', 'unit': 'Hrs', 'mode': 'Hrs', 'ohr': 4692, 'chr': 4700, 'whr': 8, 'wkm': '', 'okm': '', 'ckm': '', 'qty': 60, 'work': 'Excavation', 'chFrom': '12+000', 'chTo': '12+300', 'key': 'Sany 210 (No.1)|2026-10-14|Full Day'},
            {'date': '2026-10-14', 'no': 'MH-25-AJ-2169', 'type': 'Tipper', 'owner': 'I E Enterprises', 'shift': 'Full Day', 'unit': 'KM', 'mode': 'KM', 'okm': 15100, 'ckm': 15230, 'wkm': 130, 'whr': '', 'ohr': '', 'chr': '', 'qty': 80, 'work': 'Earth carting', 'key': 'MH-25-AJ-2169|2026-10-14|Full Day'},
            {'date': '2026-10-13', 'no': 'MH-25-AJ-2169', 'type': 'Tipper', 'owner': 'I E Enterprises', 'shift': 'Full Day', 'unit': 'KM', 'mode': 'KM', 'okm': 14970, 'ckm': 15100, 'wkm': 130, 'whr': '', 'ohr': '', 'chr': '', 'qty': 0, 'work': 'Earth carting', 'key': 'MH-25-AJ-2169|2026-10-13|Full Day'},
          ], 'totals': {'machines': 2, 'km': 260, 'hr': 8, 'issued': 140, 'consumed': 186.29}, 'summary': [
            {'no': 'MH-25-AJ-2169', 'type': 'Tipper', 'unit': 'KM', 'days': 2, 'okm': 14970, 'ckm': 15230, 'ohr': '', 'chr': '', 'firstDate': '2026-10-13', 'lastDate': '2026-10-14', 'km': 260, 'hr': 0, 'issued': 80, 'consumed': 74.29, 'diff': 5.71, 'average': '3.25 km/L', 'kmStd': 3.5, 'hrStd': ''},
            {'no': 'Sany 210 (No.1)', 'type': 'Excavator', 'unit': 'Hrs', 'days': 1, 'okm': '', 'ckm': '', 'ohr': 4692, 'chr': 4700, 'firstDate': '2026-10-14', 'lastDate': '2026-10-14', 'km': 0, 'hr': 8, 'issued': 60, 'consumed': 112, 'diff': -52, 'average': '7.5 L/hr', 'kmStd': '', 'hrStd': 14},
          ], 'itemBoq': {}}});
        case 'checkLogImport':
          importSent.add({'fn': action, 'x': a[0]});
          final rs = [for (final r in (a[0] as Map)['rows'] as List) (r as Map).cast<String, dynamic>()];
          return _j({'result': {'ok': true, 'errors': [], 'fresh': rs.length - 1, 'same': 0, 'changed': [
            {'line': rs.last['line'], 'no': rs.last['no'], 'date': rs.last['date'], 'shift': rs.last['shift'], 'diffs': [{'f': 'Close Hrs', 'from': 4700, 'to': rs.last['closingHr']}]},
          ]}});
        case 'importLogBook':
          importSent.add({'fn': action, 'x': a[0]});
          final rs = (a[0] as Map)['rows'] as List;
          final ow = (a[0] as Map)['overwrite'] == true;
          return _j({'result': {'ok': true, 'added': rs.length - 1, 'overwritten': ow ? 1 : 0, 'same': 0, 'changed': ow ? [] : [{}]}});
        case 'getLogBookList':
          return _j({'result': {'count': 6, 'rows': [
            {'no': 'Sany 210 (No.1)', 'type': 'Excavator', 'owner': 'RCL', 'shift': 'Full Day', 'mode': 'Hrs', 'ohr': 4692, 'chr': 4700, 'whr': 8, 'qty': 60, 'work': 'Excavation', 'chFrom': '12+000', 'chTo': '12+300', 'key': 'Sany 210 (No.1)|2026-10-14|Full Day'},
            {'no': 'MH-25-AJ-2169', 'type': 'Tipper', 'owner': 'I E Enterprises', 'shift': 'Full Day', 'mode': 'KM', 'okm': 15100, 'ckm': 15230, 'wkm': 130, 'qty': 80, 'work': 'Earth carting', 'key': 'MH-25-AJ-2169|2026-10-14|Full Day'},
            for (final n in ['A', 'B', 'C']) {'no': n, 'type': 'Tipper', 'mode': 'Trip', 'trip': 6, 'shift': 'Day', 'key': '$n|2026-10-14|Day'},
            {'no': 'D', 'type': 'Roller', 'mode': 'Idle', 'shift': 'Full Day', 'key': 'D|2026-10-14|Full Day'},
            if (tanker)
              {'no': 'MH-04-J-9844', 'type': 'Water Tanker', 'owner': 'Chalke Enterprises', 'date': '2026-10-14', 'shift': 'Day', 'unit': 'Trip', 'mode': 'Trip', 'trip': 2, 'challan': '123, 18522', 'key': 'MH-04-J-9844|2026-10-14|Day',
                'itemWork': {'_trips': [for (final t in _tTrips) {'c': t['c'], 'a': t['a'], 'b': t['b'], if ('${t['ch']}'.isNotEmpty) 'ch': t['ch'], if ('${t['u']}'.isNotEmpty) 'u': t['u']}]}},
            if (tanker2)
              {'no': 'MH-12-AB-1001', 'type': 'Water Tanker', 'owner': 'Patil Water Supply', 'date': '2026-10-13', 'shift': 'Night', 'unit': 'Trip', 'mode': 'Trip', 'trip': 1, 'challan': 'P-7', 'key': 'MH-12-AB-1001|2026-10-13|Night',
                'itemWork': {'_trips': [{'c': 'P-7', 'a': '21:10', 'b': '21:40', 'u': 'Curing'}]}},
          ]}});
        case 'getAiReply':
          aiAsked.add((a[0] as Map).cast<String, dynamic>());
          if (!aiOn) return _j({'error': 'The assistant is not set up yet: the Admin has to put the AI key (GEMINI_API_KEY) in the server\'s settings.'}, 500);
          return _j({'result': aiScript.isNotEmpty ? aiScript.removeAt(0) : {'parts': [{'text': 'Nothing more to say.'}], 'model': 'gemini-test-flash'}});
        case 'getBrief':
          return _j({'result': brief});
        case 'getAiCheck':
          return _j({'result': {'key': aiOn, 'fixedModel': '', 'listError': '', 'tests': [{'model': 'gemini-3.8-flash', 'ok': true, 'ms': 1240}, {'model': 'gemini-3.7-flash', 'ok': false, 'code': 503, 'said': 'The model is overloaded.'}]}});
        case 'getMyPrefs':
          return _j({'result': {'prefs': prefs, 'logins': ['2026-10-14T03:35:00Z', '2026-10-13T12:10:00Z'], 'rules': {'backDays': '', 'announce': notice, 'dayFrom': '08:00', 'nightFrom': '20:00'}}});
        // (3.14.0) the diesel history of a machinery, the photos of a fill, a transfer's stock, the Admin's faults and backup
        case 'dieselHistory':
          extraCalls.add({'fn': action, 'x': a[0]});
          final no = '${(a[0] as Map)['no']}';
          return _j({'result': no == 'MH-25-AJ-2169'
              ? {'no': no, 'unit': 'KM', 'date': (a[0] as Map)['date'], 'rows': [{'id': 'DI-000520', 'date': '2026-10-13', 'shift': 'Day', 'qty': 80, 'km': 15100, 'hr': '', 'source': 'Dispenser', 'driver': 'Ramesh'}], 'total': 7, 'lastKm': {'value': 15100, 'date': '2026-10-13'}, 'lastHr': null, 'month': {'qty': 520, 'count': 7}}
              : {'no': no, 'unit': '', 'date': (a[0] as Map)['date'], 'rows': [], 'total': 0, 'lastKm': null, 'lastHr': null, 'month': {'qty': 0, 'count': 0}}});
        case 'getDieselPhotos':
          extraCalls.add({'fn': action, 'id': a[0]});
          return _j({'result': {'id': a[0], 'no': 'Sany 210 (No.1)', 'date': '2026-10-14', 'shift': 'Day', 'qty': 60, 'photos': [
            {'k': 'dash', 'label': 'Dashboard (reading)', 'at': '2026-10-14T03:30:00Z', 'lat': 18.52, 'lng': 73.85, 'acc': 12, 'url': ''},
            {'k': 'pump', 'label': 'Dispenser (litres)', 'at': '2026-10-14T03:31:00Z', 'lat': '', 'lng': '', 'acc': '', 'url': ''},
          ]}});
        case 'getTransferBalance':
          extraCalls.add({'fn': action, 'args': a});
          return _j({'result': {'from': {'balance': 900, 'available': 850}, 'to': {'balance': 300, 'available': 300}}});
        case 'getErrors':
          return _j({'result': {'stamp': {'day': '2026-10-14', 'n': 1, 'at': '2026-10-14T05:00:00Z', 'last': 'getStock: x is undefined'}, 'errors': faults}});
        case 'clearErrors':
          extraCalls.add({'fn': action});
          faults.clear();
          return _j({'result': {'ok': true}});
        case 'reportError':
          extraCalls.add({'fn': action, 'x': a[0]});
          return _j({'result': {'ok': true}});
        case 'globalSearch':
          extraCalls.add({'fn': action, 'q': a[0]});
          final gq = '${a[0]}'.toUpperCase();
          return _j({'result': {
            'issues': gq.contains('525') ? [{'id': 'DI-000525', 'date': '2026-10-14', 'shift': 'Day', 'no': 'Sany 210 (No.1)', 'qty': 60, 'driver': 'Gupta', 'source': 'VTR Store', 'why': 'Issue ID'}] : [],
            'logs': [], 'inwards': [], 'transfers': [], 'tanks': [], 'breakdowns': [], 'bills': [], 'notes': [], 'payments': [], 'boqs': [], 'papers': [],
            'vendors': gq.contains('ENTERPRI') ? [{'name': 'I E Enterprises', 'gst': '', 'ownership': 'Rental', 'machines': 1, 'why': 'Vendor'}] : [],
            'counts': {'issues': gq.contains('525') ? 3 : 0}, 'fixes': gq.contains('ENTERPRIZE') ? [{'w': 'ENTERPRIZE', 'to': 'ENTERPRISES'}] : [],
          }});
        case 'backupNow':
          extraCalls.add({'fn': action});
          return _j({'result': {'ok': true, 'lines': [['diesel_issue', '3 rows'], ['log_book', '5 rows']], 'pending': 0, 'info': {'ok': true, 'lastCheck': '2026-10-14T05:10:00Z', 'url': 'https://docs.google.com/spreadsheets/d/x'}}});
        case 'saveMyPrefs':
          prefs = {...prefs, ...(a[0] as Map).cast<String, dynamic>()};
          return _j({'result': {'ok': true, 'prefs': prefs}});
        case 'getMeterReading':
          return _j({'result': (a[0] as Map)['kind'] == 'dash' ? {'hr': 4712.5, 'check': ''} : {'litres': 60}});
        case 'logPending':
          return _j({'result': {'items': [['OLD-9', '2026-10-14'], ['MH-25-AJ-2169', '2026-10-14'], ['MH-25-AJ-2169', '2026-10-13']]}});
        case 'getLogRowPrefill':
          final no = a[0] as String;
          return _j({'result': {'machine': {'id': no}, 'problem': '', 'first': false, 'openingKm': no == 'MH-25-AJ-2169' ? 15230 : '', 'openingHr': no.startsWith('Sany') ? 4700 : '', 'firstKm': false, 'firstHr': false,
            'lastDate': '2026-10-13', 'lastShift': 'Full Day', 'diesel': 80, 'dieselText': 'DI-000520', 'reads': [], 'boqItems': [], 'avgWork': {'km': 120, 'hr': '', 'src': 'own'}}});
        case 'saveLogRows':
          final rows = ((a[0] as Map)['rows'] as List).map((x) => (x as Map).cast<String, dynamic>()).toList();
          logSaved.addAll(rows);
          return _j({'result': {'ok': true, 'count': rows.length}});
        case 'getLogEntry':
          return _j({'result': {'key': a[0], 'no': 'MH-25-AJ-2169', 'date': '2026-10-14', 'shift': 'Full Day', 'unit': 'KM', 'okm': 15100, 'ckm': 15230, 'ohr': '', 'chr': '', 'work': 'Earth carting', 'chFrom': '12+000', 'chTo': '12+500', 'first': false, 'boqItems': [], 'itemWork': {}, 'lock': null, 'next': null, 'prev': {'date': '2026-10-13', 'shift': 'Full Day'}}});
        case 'updateLogRow':
          logSaved.add({'update': a[0], ...(a[1] as Map).cast<String, dynamic>()});
          return _j({'result': {'ok': true}});
        case 'deleteLogRow':
          return _j({'result': {'ok': true}});
        case 'getTankerTrips':
          return _j({'result': _tankerDay});
        case 'updateTankerTrip':
        case 'deleteTankerTrip':
          tankerCalls.add({'action': action, ...(a[0] as Map).cast<String, dynamic>()});
          return _j({'result': {..._tankerDay, 'ok': true}});
        case 'getIssueBalance':
          return _j({'result': {'balance': 813, 'available': 813, 'loc': 'Dispenser'}});
        case 'dieselPhoto':
          return _j({'result': {'ok': true, 'kind': (a[0] as Map)['kind'], 'path': '2026-10/00000000-0000-0000-0000-000000000001.jpg'}});
        case 'saveDieselIssue':
          final d = (a[0] as Map).cast<String, dynamic>();
          if (d['force'] != true && (d['hrReading'] ?? '') == 1) return _j({'result': {'ok': false, 'warning': 'The Hrs reading 1 is lower than the last one (4,700). Save anyway?'}});
          saved.add(d);
          return _j({'result': {'ok': true, 'id': 'DI-000526', 'stock': {'stock': 1133 - (d['qty'] as num), 'byLoc': {'Dispenser': 813 - (d['qty'] as num), 'VTR Store': 320}}}});
      }
      return _j({'error': 'Unknown action.'}, 404);
    }
    return _j({'error': 'not found'}, 404);
  });
}
