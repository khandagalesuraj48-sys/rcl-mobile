/* A pretend Portal + Mechanical for the tests (no network): it answers like the real ones, from data kept here. */
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class FakeServer {
  final calls = <String>[];
  String expireOnce = ''; // an action that first answers SESSION_EXPIRED (a Mechanical sign-in that ended)
  int tickets = 0;
  bool portalSignedIn = false;
  Map<String, String> perms = {'Diesel Issue': 'Edit', 'Diesel Inward': 'View', 'Diesel Transfer': 'None', 'Dashboard': 'View'};
  final saved = <Map<String, dynamic>>[];

  static final issues = [
    {'id': 'DI-000101', 'date': '2026-10-13', 'shift': 'Day', 'no': 'MH-04-KU-3331', 'type': 'Excavator PC210', 'qty': 120, 'source': 'Dispenser', 'driver': 'Ramesh P.'},
    {'id': 'DI-000102', 'date': '2026-10-13', 'shift': 'Day', 'no': 'TKX-1', 'type': 'Tipper 10 W', 'qty': 80, 'source': 'Dispenser', 'driver': 'Sanjay K.'},
    {'id': 'DI-000103', 'date': '2026-10-13', 'shift': 'Day', 'no': '400 KVA DG', 'type': 'Generator', 'qty': 150, 'source': 'Dispenser', 'driver': ''},
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
        return _j({'user': {'email': b['email'], 'name': 'Sujit Mule', 'super': false}, 'mustChange': false}, 200, {'set-cookie': 'rcl_portal=abc123; Path=/; HttpOnly; Secure'});
      }
      if (b['action'] == 'me') {
        if (!portalSignedIn || r.headers['Cookie'] != 'rcl_portal=abc123') return _j({'signedIn': false});
        return _j({'signedIn': true, 'user': {'email': 'sujit@rcl.test', 'name': 'Sujit Mule', 'super': false}, 'items': [
          {'site': 'S1', 'siteName': 'VTR – NH 848', 'company': 'RCL', 'module': 'mechanical'},
          {'site': 'S1', 'siteName': 'VTR – NH 848', 'company': 'RCL', 'module': 'store'},
          {'site': 'T2', 'siteName': '18B Kolhapur', 'company': 'RCL', 'module': 'mechanical'},
        ]});
      }
      if (b['action'] == 'logout') { portalSignedIn = false; return _j({'ok': true}, 200, {'set-cookie': 'rcl_portal=; Path=/; Max-Age=0'}); }
    }
    if (path.endsWith('/portal/api/go')) {
      calls.add('portal:go:${r.url.queryParameters['site']}');
      if (r.url.queryParameters['json'] != '1' || r.headers['X-RCL'] != '1') return _j({'error': 'Refused'}, 403);
      if (!portalSignedIn) return _j({'error': 'Sign in on the Portal first.', 'code': 'signin'}, 401);
      tickets++;
      return _j({'ticket': 'tk$tickets'});
    }
    if (path.endsWith('/api/rpc')) {
      final b = jsonDecode(r.body) as Map;
      final fn = b['fn'] as String, args = b['args'] as List;
      if (fn == 'ssoLogin') {
        calls.add('mech:ssoLogin:${args[0]}');
        return _j({'result': {'token': 'tok-${args[0]}', 'user': {'email': 'sujit@rcl.test', 'name': 'Sujit Mule', 'admin': false, 'perms': perms}, 'site': b['site'], 'siteName': b['site'] == 'S1' ? 'VTR – NH 848' : '18B Kolhapur'}});
      }
      if (fn == 'logout') { calls.add('mech:logout'); return _j({'result': true}); }
      final action = args[1] as String, a = args[2] as List;
      calls.add('mech:$action${b['rid'] != null ? '+rid' : ''}');
      if (!(args[0] as String).startsWith('tok-')) return _j({'error': 'SESSION_EXPIRED'}, 401);
      if (expireOnce == action) { expireOnce = ''; return _j({'error': 'SESSION_EXPIRED'}, 401); }
      switch (action) {
        case 'getInit':
          return _j({'result': {'today': '2026-10-13', 'locations': ['Dispenser', 'VTR Store'], 'drivers': ['Ramesh P.', 'Sanjay K.'], 'pumps': ['HP Petrol Pump'],
            'stock': {'stock': 813, 'byLoc': {'Dispenser': 813, 'VTR Store': 0}},
            'master': [
              {'id': 'MH-04-KU-3331', 'name': 'PC210', 'type': 'Excavator', 'owner': 'RCL', 'ownership': 'Own', 'supply': 'Self', 'status': 'Active', 'meterKm': false, 'meterHr': true},
              {'id': 'TKX-1', 'name': '', 'type': 'Tipper', 'owner': 'I E Enterprises', 'ownership': 'Rental', 'supply': 'Self', 'status': 'Active', 'meterKm': true, 'meterHr': false},
              {'id': 'OLD-9', 'name': '', 'type': 'Roller', 'owner': 'RCL', 'ownership': 'Own', 'supply': 'Self', 'status': 'Inactive', 'meterKm': false, 'meterHr': true},
            ]}});
        case 'getDieselIssues':
          return _j({'result': {'count': issues.length, 'totalQty': 350, 'rows': issues}});
        case 'getIssueBalance':
          return _j({'result': {'balance': 813, 'available': 813, 'loc': 'Dispenser'}});
        case 'saveDieselIssue':
          final d = (a[0] as Map).cast<String, dynamic>();
          if (d['force'] != true && (d['hrReading'] ?? '') == 1) return _j({'result': {'ok': false, 'warning': 'The Hrs reading 1 is lower than the last one (4,700). Save anyway?'}});
          saved.add(d);
          return _j({'result': {'ok': true, 'id': 'DI-000104', 'stock': {'stock': 813 - (d['qty'] as num), 'byLoc': {'Dispenser': 813 - (d['qty'] as num)}}}});
      }
      return _j({'error': 'Unknown action.'}, 404);
    }
    return _j({'error': 'not found'}, 404);
  });
}
