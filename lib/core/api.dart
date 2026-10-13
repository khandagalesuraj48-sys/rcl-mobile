/* THE ROAD TO THE PORTAL – the one sign-in (14-10-2026: "web warcha full access app war"): the app signs the person in on
 * the Portal (email + password → its sign-in cookie, kept in the phone's safe), lists his sites and modules, and asks a
 * TICKET for the module to open. The whole ERP then runs inside the app exactly as on the web (screens/web_shell.dart):
 * the same pages, checks and access – nothing of the work is done twice here. */
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// What the server answered instead of a result – its own words.
class ApiError implements Exception {
  ApiError(this.message, {this.status = 0, this.code = ''});
  final String message;
  final int status;
  final String code;
  bool get needsSignIn => code == 'signin';
  bool get noConnection => code == 'net';
  @override
  String toString() => message;
}

/// Where the sign-in is kept on the phone (flutter_secure_storage in the app, a map in the tests).
abstract class Keep {
  Future<String?> read(String key);
  Future<void> write(String key, String? value);
}

class MemoryKeep implements Keep {
  final Map<String, String> data = {};
  @override
  Future<String?> read(String key) async => data[key];
  @override
  Future<void> write(String key, String? value) async => value == null ? data.remove(key) : data[key] = value;
}

class Api {
  Api({required this.portalUrl, required this.keep, http.Client? client, this.timeout = const Duration(seconds: 30)}) : _c = client ?? http.Client();

  final String portalUrl; // https://oneclicksolution-erp.vercel.app/portal
  final Keep keep;
  final Duration timeout;
  final http.Client _c;

  String? _cookie; // rcl_portal=…  (the Portal's sign-in)
  String? site;
  static const kCookie = 'portal_cookie', kSite = 'site';

  /// The Portal's sign-in value (for the app's web view, so the web knows the person too).
  String? get cookieValue => _cookie?.split('=').skip(1).join('=');

  Future<void> load() async {
    _cookie = await keep.read(kCookie);
    site = await keep.read(kSite);
  }

  bool get hasPortal => (_cookie ?? '').isNotEmpty;

  Future<void> keepSite(String code) async {
    site = code;
    await keep.write(kSite, code);
  }

  Future<void> forget() async {
    _cookie = null;
    site = null;
    await keep.write(kCookie, null);
    await keep.write(kSite, null);
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'X-RCL': '1', // the Portal takes changes only with this header (a page of another site cannot send it)
        if (_cookie != null) 'Cookie': _cookie!,
      };

  Future<void> _keepCookie(http.Response r) async {
    final m = RegExp(r'rcl_portal=([^;]*)').firstMatch(r.headers['set-cookie'] ?? '');
    if (m == null) return;
    final v = m.group(1) ?? '';
    _cookie = v.isEmpty ? null : 'rcl_portal=$v';
    await keep.write(kCookie, _cookie);
  }

  Future<http.Response> _send(Future<http.Response> Function() fn) async {
    try {
      return await fn().timeout(timeout);
    } on TimeoutException {
      throw ApiError('The server did not answer in time – check the network and try again.', code: 'net');
    } catch (e) {
      if (e is ApiError) rethrow;
      throw ApiError('No connection – check the internet and try again.', code: 'net');
    }
  }

  Map<String, dynamic> _json(http.Response r) {
    try {
      final j = jsonDecode(utf8.decode(r.bodyBytes));
      if (j is Map<String, dynamic>) return j;
    } catch (_) {/* below */}
    throw ApiError('The Portal did not answer properly (${r.statusCode}).', status: r.statusCode);
  }

  /// POST <portal>/api/auth { action, … }
  Future<Map<String, dynamic>> auth(Map<String, dynamic> body) async {
    final r = await _send(() => _c.post(Uri.parse('$portalUrl/api/auth'), headers: _headers, body: jsonEncode(body)));
    await _keepCookie(r);
    final j = _json(r);
    if (r.statusCode >= 400 || j['error'] != null) {
      throw ApiError(j['error']?.toString() ?? 'Error ${r.statusCode}', status: r.statusCode, code: (j['code'] ?? (r.statusCode == 401 ? 'signin' : '')).toString());
    }
    return j;
  }

  /// A ticket of the Portal for [module] on [siteCode] – an answer, no page change (json=1).
  Future<String> ticket(String siteCode, String module) async {
    final u = Uri.parse('$portalUrl/api/go').replace(queryParameters: {'module': module, 'site': siteCode, 'json': '1'});
    final r = await _send(() => _c.get(u, headers: _headers));
    final j = _json(r);
    final t = j['ticket']?.toString() ?? '';
    if (r.statusCode != 200 || t.isEmpty) throw ApiError(j['error']?.toString() ?? 'The Portal gave no ticket (${r.statusCode}).', status: r.statusCode, code: (j['code'] ?? '').toString());
    return t;
  }

  Future<void> signOut() async {
    try {
      if (hasPortal) await auth({'action': 'logout'});
    } catch (_) {/* it ends by itself */}
    await forget();
  }
}
