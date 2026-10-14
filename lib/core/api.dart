/* THE ROAD TO THE SERVERS – the same ones the web ERP uses; nothing new on the server for the app:
 *   the Portal  (<main>/portal)  – the one sign-in: email + password → its sign-in (a cookie), the person's sites and modules,
 *                                  and a TICKET for a module on one site (/api/go?…&json=1);
 *   Mechanical  (<main>/api/rpc) – the ticket becomes a Mechanical sign-in (a token) on that site; every action then goes
 *                                  through the same api() as the web page – the same checks, rules and access, every time.
 * A Mechanical sign-in that ended is renewed by itself with a new ticket (the Portal still knows the person): nothing to type.
 * A save carries its own number (rid): sent again after a dropped connection, the server saves it ONCE (as on the web). */
import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

/// What the server answered instead of a result – its own words (English, as the web app shows them).
class ApiError implements Exception {
  ApiError(this.message, {this.status = 0, this.code = ''});
  final String message;
  final int status;
  final String code;

  /// The Mechanical sign-in ended (a new ticket fixes it).
  bool get sessionEnded => message.contains('SESSION_EXPIRED');

  /// The Portal does not know the person any more: the sign-in screen.
  bool get needsSignIn => code == 'signin';

  /// No answer at all (no network, the server did not answer in time).
  bool get noConnection => code == 'net';

  @override
  String toString() => message.replaceAll('SESSION_EXPIRED', 'Your sign-in ended – please sign in again.');
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
  Api({required this.portalUrl, required this.keep, http.Client? client, this.timeout = const Duration(seconds: 40)}) : _c = client ?? http.Client();

  final String portalUrl; // https://oneclicksolution-erp.vercel.app/portal
  final Keep keep;
  final Duration timeout;
  final http.Client _c;
  final Random _rnd = Random.secure();

  /// Mechanical's address on the site open (from the Portal's list of modules).
  String mechUrl = '';
  String? _cookie; // rcl_portal=…  (the Portal's sign-in)
  String? token; //   Mechanical's sign-in on [site]
  String? site;

  static const kCookie = 'portal_cookie', kToken = 'mech_token', kSite = 'site';

  /// The Portal's sign-in value (for the app's web view, so the web knows the person too).
  String? get cookieValue => _cookie?.split('=').skip(1).join('=');

  Future<void> load() async {
    _cookie = await keep.read(kCookie);
    token = await keep.read(kToken);
    site = await keep.read(kSite);
  }

  bool get hasPortal => (_cookie ?? '').isNotEmpty;

  Future<void> keepSite(String code) async {
    if (site != code) {
      token = null;
      await keep.write(kToken, null);
    }
    site = code;
    await keep.write(kSite, code);
  }

  Future<void> forget() async {
    _cookie = null;
    token = null;
    site = null;
    for (final k in [kCookie, kToken, kSite]) {
      await keep.write(k, null);
    }
  }

  // ---------------- the Portal ----------------
  Map<String, String> get _portalHeaders => {
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

  Map<String, dynamic> _json(http.Response r, String who) {
    try {
      final j = jsonDecode(utf8.decode(r.bodyBytes));
      if (j is Map<String, dynamic>) return j;
    } catch (_) {/* below */}
    throw ApiError('$who did not answer properly (${r.statusCode}).', status: r.statusCode);
  }

  /// POST <portal>/api/auth { action, … }
  Future<Map<String, dynamic>> auth(Map<String, dynamic> body) async {
    final r = await _send(() => _c.post(Uri.parse('$portalUrl/api/auth'), headers: _portalHeaders, body: jsonEncode(body)));
    await _keepCookie(r);
    final j = _json(r, 'The Portal');
    if (r.statusCode >= 400 || j['error'] != null) {
      throw ApiError(j['error']?.toString() ?? 'Error ${r.statusCode}', status: r.statusCode, code: (j['code'] ?? (r.statusCode == 401 ? 'signin' : '')).toString());
    }
    return j;
  }

  /// A ticket of the Portal for [module] on [siteCode] – an answer, no page change (json=1).
  Future<String> ticket(String siteCode, [String module = 'mechanical']) async {
    final u = Uri.parse('$portalUrl/api/go').replace(queryParameters: {'module': module, 'site': siteCode, 'json': '1'});
    final r = await _send(() => _c.get(u, headers: _portalHeaders));
    final j = _json(r, 'The Portal');
    final t = j['ticket']?.toString() ?? '';
    if (r.statusCode != 200 || t.isEmpty) {
      throw ApiError(j['error']?.toString() ?? 'The Portal gave no ticket (${r.statusCode}).', status: r.statusCode, code: (j['code'] ?? (r.statusCode == 401 ? 'signin' : '')).toString());
    }
    return t;
  }

  // ---------------- Mechanical ----------------
  Future<dynamic> _rpc(String fn, List<dynamic> args, {String? rid}) async {
    if (mechUrl.isEmpty) throw ApiError('Mechanical is not open on this site.');
    final body = <String, dynamic>{'fn': fn, 'args': args, if (rid != null) 'rid': rid, if ((site ?? '').isNotEmpty) 'site': site};
    final r = await _send(() => _c.post(Uri.parse('$mechUrl/api/rpc'), headers: {'Content-Type': 'application/json'}, body: jsonEncode(body)));
    final j = _json(r, 'The ERP server');
    if (j.containsKey('error')) throw ApiError(j['error'].toString(), status: r.statusCode);
    return j['result'];
  }

  /// The Portal's ticket → a Mechanical sign-in on [siteCode]. Returns { token, user, site, siteName, portal }.
  Future<Map<String, dynamic>> openSite(String siteCode) async {
    final t = await ticket(siteCode);
    site = siteCode;
    final res = await _rpc('ssoLogin', [t]);
    final m = (res as Map).cast<String, dynamic>();
    token = m['token']?.toString();
    if ((m['site'] ?? '').toString().isNotEmpty) site = m['site'].toString();
    await keep.write(kToken, token);
    await keep.write(kSite, site);
    return m;
  }

  String _newRid() => 'm${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}${_rnd.nextInt(1 << 32).toRadixString(36)}';

  /* (14-10-2026, update-108 of Mechanical) A SAVE THE BILL LOCK REFUSED – its entry is in a submitted bill: as on the web page, the
   * person may send exactly that save to the Super Admin for approval, with a reason (sendChangeRequest). It is saved only when he
   * approves it (Mechanical → Approvals). [askApproval] is set by the app (a box asking for the reason; null = not sent); the
   * screen then gets [crSent] as its error – nothing was saved. The Super Admin himself is not refused (his ticket says so). */
  static const crFns = {'saveLogRows', 'saveLogBook', 'saveLogDay', 'updateLogRow', 'deleteLogRow', 'saveLogBulk', 'importLogBook', 'saveTankerTrips', 'deleteTankerTrip',
    'updateTankerTrip', 'saveTankerRange', 'importTankerTrips', 'saveDieselIssue', 'saveDieselBulk', 'importDiesel', 'updateDieselIssue', 'deleteDieselIssue'};
  static const crSent = 'Sent to the Super Admin for approval – it is saved only when he approves (nothing is saved until then).';
  static bool crLocked(String m) => m.contains('is in the submitted RA Bill');
  Future<String?> Function(String message)? askApproval;
  /// true = sent (with the person's reason); false = he did not send it.
  Future<bool> _offer(String fn, List<dynamic> args, String msg) async {
    final ask = askApproval;
    final why = ask == null ? null : await ask(msg);
    if (why == null || why.trim().isEmpty) return false;
    await _rpc('api', [token, 'sendChangeRequest', [{'fn': fn, 'args': args, 'reason': why.trim()}]]);
    return true;
  }

  /// One action of Mechanical (getInit, saveDieselIssue …) with the person's sign-in. [save]: it changes data – it gets its
  /// own number and is sent again after a lost connection (at most 4 tries); a question is asked again at most twice.
  Future<dynamic> call(String fn, [List<dynamic> args = const [], bool save = false]) async {
    final rid = save ? _newRid() : null;
    var renewed = false;
    for (var tryNo = 1;; tryNo++) {
      try {
        if ((token ?? '').isEmpty) throw ApiError('SESSION_EXPIRED', status: 401);
        final res = await _rpc('api', [token, fn, args], rid: rid);
        // a save that answers "not saved" with a line refused by the bill lock (saveLogRows …)
        if (crFns.contains(fn) && res is Map && res['ok'] == false && res['errors'] is List) {
          final lk = (res['errors'] as List).map((x) => x is Map ? (x['msg'] ?? '').toString() : x.toString()).where(crLocked).toList();
          if (lk.isNotEmpty && await _offer(fn, args, lk.first)) throw ApiError(crSent, code: 'sent');
        }
        return res;
      } on ApiError catch (e) {
        if (e.code == 'sent') rethrow;
        if (crFns.contains(fn) && crLocked(e.message) && await _offer(fn, args, e.message)) throw ApiError(crSent, code: 'sent');
        if (e.sessionEnded && !renewed && (site ?? '').isNotEmpty && hasPortal) {
          renewed = true; // a new Mechanical sign-in with a new ticket, nothing typed
          await openSite(site!);
          continue;
        }
        final again = e.noConnection || e.status == 503;
        if (again && tryNo < (save ? 4 : 3)) {
          await Future<void>.delayed(Duration(milliseconds: 700 * tryNo));
          continue;
        }
        rethrow;
      }
    }
  }

  /// Signs out of Mechanical and of the Portal (one sign-out for every module, as on the web).
  Future<void> signOut() async {
    try {
      if ((token ?? '').isNotEmpty && mechUrl.isNotEmpty) await _rpc('logout', [token]);
    } catch (_) {/* it ends by itself */}
    try {
      if (hasPortal) await auth({'action': 'logout'});
    } catch (_) {/* it ends by itself */}
    await forget();
  }
}
