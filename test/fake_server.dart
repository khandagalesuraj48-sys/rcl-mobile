/* A pretend Portal for the tests (no network): it answers like the real one, from data kept here. */
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class FakeServer {
  final calls = <String>[];
  int tickets = 0;
  bool portalSignedIn = false, superAdmin = false, mustChange = false;

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
          {'site': 'S1', 'siteName': 'VTR – NH 848', 'company': 'RCL', 'module': 'mechanical', 'moduleName': 'Mechanical', 'url': 'https://erp.test'},
          {'site': 'S1', 'siteName': 'VTR – NH 848', 'company': 'RCL', 'module': 'store', 'moduleName': 'Store', 'url': 'https://erp.test/store'},
          {'site': 'T2', 'siteName': '18B Kolhapur', 'company': 'RCL', 'module': 'mechanical', 'moduleName': 'Mechanical', 'url': 'https://erp.test'},
          {'site': 'X9', 'siteName': 'Bad', 'company': '', 'module': 'mechanical', 'moduleName': 'Mechanical', 'url': 'javascript:alert(1)'},
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
    return _j({'error': 'not found'}, 404);
  });
}
