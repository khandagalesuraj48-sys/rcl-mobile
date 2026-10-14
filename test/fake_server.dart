/* A pretend Portal + Mechanical for the tests (no network): it answers like the real ones, from data kept here. */
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class FakeServer {
  final calls = <String>[];
  int tickets = 0;
  bool portalSignedIn = false, superAdmin = false, mustChange = false;
  String expireOnce = ''; // an action that first answers SESSION_EXPIRED (a Mechanical sign-in that ended)
  Map<String, String> perms = {'Diesel Issue': 'Edit', 'Diesel Inward': 'View', 'Diesel Transfer': 'None', 'Dashboard': 'View', 'Log Book': 'View', 'Reports': 'View', 'Master': 'View'};
  final saved = <Map<String, dynamic>>[];
  final logSaved = <Map<String, dynamic>>[];
  bool billLock = false; // (14-10-2026) the entries are in a submitted bill: Mechanical refuses a change (not the Super Admin's)
  final requests = <Map<String, dynamic>>[];
  bool tanker = false; // a water tanker (Log Book Format I) on the site, with an entry of 2 trips today
  final tankerCalls = <Map<String, dynamic>>[];
  static const _tTrips = [
    {'shift': 'Day', 'n': 1, 'c': '123', 'a': '07:35', 'b': '07:50', 'ch': '', 'u': '', 'old': 0},
    {'shift': 'Day', 'n': 2, 'c': '18522', 'a': '10:30', 'b': '10:36', 'ch': 'VTR', 'u': 'PQC curing', 'old': 0},
  ];
  Map<String, dynamic> get _tankerDay => {'machine': {'id': 'MH-04-J-9844', 'owner': 'Chalke Enterprises', 'type': 'Water Tanker'}, 'date': '2026-10-14', 'trips': _tTrips, 'problem': '', 'other': ''};
  Map<String, dynamic> prefs = {'shift': '', 'loc': '', 'lbMode': '', 'text': 'normal', 'mobile': '', 'photo': ''};
  String start = '';

  static final issues = [
    {'id': 'DI-000525', 'date': '2026-10-14', 'shift': 'Day', 'no': 'Sany 210 (No.1)', 'type': 'Excavator', 'qty': 60, 'source': 'VTR Store', 'driver': 'Gupta', 'ph': 4},
    {'id': 'DI-000522', 'date': '2026-10-14', 'shift': 'Day', 'no': 'MH-12-SY-6216', 'type': 'Bolero', 'qty': 20, 'source': 'Dispenser', 'driver': 'Maruti'},
    {'id': 'DI-000521', 'date': '2026-10-14', 'shift': 'Day', 'no': 'Kobelco Sk 220', 'type': 'Excavator', 'qty': 80, 'source': 'Dispenser', 'driver': 'Babu Bag'},
    {'id': 'DI-000520', 'date': '2026-10-14', 'shift': 'Night', 'no': 'MH-25-AJ-2169', 'type': 'Tipper', 'qty': 80, 'source': 'Dispenser', 'driver': 'Rupesh'},
  ];

  http.Response _j(Object o, [int code = 200, Map<String, String> h = const {}]) => http.Response(jsonEncode(o), code, headers: {'content-type': 'application/json', ...h});

  late final client = MockClient((r) async {
    final path = r.url.path;
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
        if (b['old'] != 'Nashik#Road848!') return _j({'error': 'Current password is wrong.', 'code': 'oldpw'}, 400);
        return _j({'ok': true});
      }
      if (b['action'] == 'logout') {
        portalSignedIn = false;
        return _j({'ok': true}, 200, {'set-cookie': 'rcl_portal=; Path=/; Max-Age=0'});
      }
    }
    if (path.endsWith('/portal/api/go')) {
      final q = r.url.queryParameters;
      calls.add('portal:go:${q['module']}:${q['site']}');
      if (q['json'] != '1' || r.headers['X-RCL'] != '1') return _j({'error': 'Refused'}, 403);
      if (!portalSignedIn) return _j({'error': 'Sign in on the Portal first.', 'code': 'signin'}, 401);
      tickets++;
      return _j({'ticket': 'tk$tickets'});
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
      switch (action) {
        case 'getInit':
          return _j({'result': {'today': '2026-10-14', 'company': 'Rachana Construction Limited', 'locations': ['Dispenser', 'VTR Store'], 'drivers': ['Gupta', 'Maruti'], 'pumps': ['IOC Bunk'], 'stock': stock,
            'user': {'email': 'sujit@rcl.test', 'name': 'Sujit Mule', 'admin': superAdmin, 'super': superAdmin, 'perms': perms},
            'master': [
              {'id': 'Sany 210 (No.1)', 'name': 'Sany 210', 'type': 'Excavator', 'owner': 'RCL', 'ownership': 'Own', 'supply': 'Company', 'status': 'Active', 'modes': ['Hrs', 'Time'], 'modesX': ['Time'], 'meterKm': false, 'meterHr': true},
              {'id': 'MH-25-AJ-2169', 'name': '', 'type': 'Tipper', 'owner': 'I E Enterprises', 'ownership': 'Rental', 'supply': 'Company', 'status': 'Active', 'modes': ['KM'], 'modesX': [], 'meterKm': true, 'meterHr': false},
              {'id': 'OLD-9', 'name': '', 'type': 'Roller', 'owner': 'RCL', 'ownership': 'Own', 'status': 'Inactive', 'modes': ['Hrs']},
              if (tanker) {'id': 'MH-04-J-9844', 'name': '', 'type': 'Water Tanker', 'owner': 'Chalke Enterprises', 'ownership': 'Rental', 'supply': 'Company', 'status': 'Active', 'modes': ['Trip'], 'modesX': [], 'lbFormat': 'I'},
            ]}});
        case 'getDieselIssues':
          return _j({'result': {'count': issues.length, 'totalQty': 240, 'rows': issues}});
        case 'getInwards':
          return _j({'result': {'count': 1, 'qty': 500, 'stock': stock, 'rows': [{'id': 'IN-000050', 'date': '2026-10-14', 'qty': 500, 'pump': 'IOC Bunk', 'rate': 90, 'amount': 45000, 'billNo': 'B-1', 'billDate': '2026-10-14', 'location': 'VTR Store'}]}});
        case 'getTransfers':
          return _j({'result': {'count': 0, 'qty': 0, 'rows': []}});
        case 'getLogBookList':
          return _j({'result': {'count': 6, 'rows': [
            {'no': 'Sany 210 (No.1)', 'type': 'Excavator', 'owner': 'RCL', 'shift': 'Full Day', 'mode': 'Hrs', 'ohr': 4692, 'chr': 4700, 'whr': 8, 'qty': 60, 'work': 'Excavation', 'chFrom': '12+000', 'chTo': '12+300', 'key': 'Sany 210 (No.1)|2026-10-14|Full Day'},
            {'no': 'MH-25-AJ-2169', 'type': 'Tipper', 'owner': 'I E Enterprises', 'shift': 'Full Day', 'mode': 'KM', 'okm': 15100, 'ckm': 15230, 'wkm': 130, 'qty': 80, 'work': 'Earth carting', 'key': 'MH-25-AJ-2169|2026-10-14|Full Day'},
            for (final n in ['A', 'B', 'C']) {'no': n, 'type': 'Tipper', 'mode': 'Trip', 'trip': 6, 'shift': 'Day', 'key': '$n|2026-10-14|Day'},
            {'no': 'D', 'type': 'Roller', 'mode': 'Idle', 'shift': 'Full Day', 'key': 'D|2026-10-14|Full Day'},
            if (tanker)
              {'no': 'MH-04-J-9844', 'type': 'Water Tanker', 'owner': 'Chalke Enterprises', 'date': '2026-10-14', 'shift': 'Day', 'unit': 'Trip', 'mode': 'Trip', 'trip': 2, 'challan': '123, 18522', 'key': 'MH-04-J-9844|2026-10-14|Day',
                'itemWork': {'_trips': [for (final t in _tTrips) {'c': t['c'], 'a': t['a'], 'b': t['b'], if ('${t['ch']}'.isNotEmpty) 'ch': t['ch'], if ('${t['u']}'.isNotEmpty) 'u': t['u']}]}},
          ]}});
        case 'getMyPrefs':
          return _j({'result': {'prefs': prefs}});
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
