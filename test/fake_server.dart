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
        return _j({'signedIn': true, 'user': {'email': 'sujit@rcl.test', 'name': 'Sujit Mule', 'super': superAdmin}, 'items': superAdmin ? [] : [
          {'site': 'S1', 'siteName': 'VTR Site – NH 848', 'company': 'RCL', 'module': 'mechanical', 'moduleName': 'Mechanical', 'url': 'https://erp.test'},
          {'site': 'S1', 'siteName': 'VTR Site – NH 848', 'company': 'RCL', 'module': 'store', 'moduleName': 'Store', 'url': 'https://erp.test/store'},
          {'site': 'T2', 'siteName': '18B Kolhapur', 'company': 'RCL', 'module': 'mechanical', 'moduleName': 'Mechanical', 'url': 'https://erp.test'},
          {'site': 'X9', 'siteName': 'Bad', 'company': '', 'module': 'mechanical', 'moduleName': 'Mechanical', 'url': 'javascript:alert(1)'},
          {'site': 'Z5', 'siteName': 'Store only', 'company': '', 'module': 'store', 'moduleName': 'Store', 'url': 'https://erp.test/store'},
        ]});
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
        return _j({'result': {'token': 'tok-${args[0]}', 'user': {'email': 'sujit@rcl.test', 'name': 'Sujit Mule', 'admin': false, 'perms': perms}, 'site': b['site'], 'siteName': b['site'] == 'S1' ? 'VTR Site – NH 848' : '18B Kolhapur'}});
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
      switch (action) {
        case 'getInit':
          return _j({'result': {'today': '2026-10-14', 'company': 'Rachana Construction Limited', 'locations': ['Dispenser', 'VTR Store'], 'drivers': ['Gupta', 'Maruti'], 'pumps': ['IOC Bunk'], 'stock': stock,
            'user': {'email': 'sujit@rcl.test', 'name': 'Sujit Mule', 'admin': false, 'perms': perms},
            'master': [
              {'id': 'Sany 210 (No.1)', 'name': 'Sany 210', 'type': 'Excavator', 'owner': 'RCL', 'ownership': 'Own', 'supply': 'Company', 'status': 'Active', 'modes': ['Hrs', 'Time'], 'modesX': ['Time'], 'meterKm': false, 'meterHr': true},
              {'id': 'MH-25-AJ-2169', 'name': '', 'type': 'Tipper', 'owner': 'I E Enterprises', 'ownership': 'Rental', 'supply': 'Company', 'status': 'Active', 'modes': ['KM'], 'modesX': [], 'meterKm': true, 'meterHr': false},
              {'id': 'OLD-9', 'name': '', 'type': 'Roller', 'owner': 'RCL', 'ownership': 'Own', 'status': 'Inactive', 'modes': ['Hrs']},
            ]}});
        case 'getDieselIssues':
          return _j({'result': {'count': issues.length, 'totalQty': 240, 'rows': issues}});
        case 'getInwards':
          return _j({'result': {'count': 1, 'qty': 500, 'stock': stock, 'rows': [{'id': 'IN-000050', 'date': '2026-10-14', 'qty': 500, 'pump': 'IOC Bunk', 'rate': 90, 'amount': 45000, 'billNo': 'B-1', 'billDate': '2026-10-14', 'location': 'VTR Store'}]}});
        case 'getTransfers':
          return _j({'result': {'count': 0, 'qty': 0, 'rows': []}});
        case 'getLogBookList':
          return _j({'result': {'count': 6, 'rows': [
            for (final n in ['Sany 210 (No.1)', 'MH-25-AJ-2169', 'A', 'B', 'C']) {'no': n, 'mode': 'Hrs'},
            {'no': 'D', 'mode': 'Idle'},
          ]}});
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
