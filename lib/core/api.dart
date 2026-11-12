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
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'answers.dart';

/// What the server answered instead of a result – its own words (English, as the web app shows them).
class ApiError implements Exception {
  ApiError(this.message, {this.status = 0, this.code = '', this.rid = '', this.data = const {}});
  final String message;
  final int status;
  final String code;

  /// (3.10.0) what else the server said with it (the Store: the near names, the categories, an import's report)
  final Map<String, dynamic> data;

  /// (3.1.7) The number of a save that got no answer: kept with it on the phone, it is sent again with the SAME number – the
  /// server saves it once, also when the first try did reach it.
  final String rid;

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
    if (site == code) return; // (3.39.0) the same site as kept: nothing written again at every opening
    token = null;
    answers.clear(); // (update-155) another site: nothing kept of this one
    await keep.write(kToken, null);
    site = code;
    await keep.write(kSite, code);
  }

  Future<void> forget() async {
    _cookie = null;
    token = null;
    site = null;
    answers.clear(); // (update-155) signed out: no answer is kept
    _storeCookie = '';
    _storeKey = '';
    _engCookie = '';
    _engKey = '';
    _purCookie = '';
    _purKey = '';
    for (final k in [kCookie, kToken, kSite, 'mech_url', 'alerts_seen', 'live_at']) {
      await keep.write(k, null);
    }
  }

  /// (3.4.0) Vendor Master: the bank and branch of an IFSC, from the public IFSC list of Razorpay (ifsc.razorpay.com – free, no
  /// key; only the code is sent), as the web. {'missing': true} = not a branch; null = no answer (no internet).
  Future<Map<String, dynamic>?> ifsc(String code) async {
    try {
      final r = await _c.get(Uri.parse('https://ifsc.razorpay.com/${Uri.encodeComponent(code)}')).timeout(const Duration(seconds: 7));
      if (r.statusCode == 404) return {'missing': true};
      if (r.statusCode != 200) return null;
      final j = jsonDecode(utf8.decode(r.bodyBytes));
      return j is Map<String, dynamic> ? j : null;
    } catch (_) {
      return null;
    }
  }

  /// (3.59.0, Mechanical update-184) a kept file from its short link (a vendor's document – Download / Print): its bytes. Only the
  /// file's own link is asked (https; no sign-in is sent with it).
  Future<Uint8List> fileBytes(String url) async {
    final u = Uri.tryParse(url);
    if (u == null || u.scheme != 'https') throw ApiError('This file has no link now – open the documents again.');
    final http.Response r;
    try {
      r = await _c.get(u).timeout(timeout);
    } catch (_) {
      throw ApiError('The file could not be downloaded now – check the network and try again.', code: 'net');
    }
    if (r.statusCode != 200) throw ApiError('The file could not be downloaded – its link works for 15 minutes: open the documents again.');
    return r.bodyBytes;
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

  /// (3.100.0) POST <portal>/api/ads { action, … } – the Advertise Corner: 'live' = the posts that show now on a site.
  Future<Map<String, dynamic>> ads(Map<String, dynamic> body) async {
    final r = await _send(() => _c.post(Uri.parse('$portalUrl/api/ads'), headers: _portalHeaders, body: jsonEncode(body)));
    final j = _json(r, 'The Portal');
    if (r.statusCode >= 400 || j['error'] != null) {
      throw ApiError(j['error']?.toString() ?? 'Error ${r.statusCode}', status: r.statusCode, code: (j['code'] ?? '').toString());
    }
    return j;
  }

  /// (3.17.0) POST <portal>/api/admin { action, … } – the Super Admin's console (users, access, sites, companies, modules, activity).
  Future<Map<String, dynamic>> admin(Map<String, dynamic> body) async {
    final r = await _send(() => _c.post(Uri.parse('$portalUrl/api/admin'), headers: _portalHeaders, body: jsonEncode(body)));
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
  /// (update-155) the last answers of the questions, in memory only (answers.dart)
  final answers = KeptAnswers();

  Future<dynamic> _rpc(String fn, List<dynamic> args, {String? rid, bool whole = false}) async {
    if (mechUrl.isEmpty) throw ApiError('Mechanical is not open on this site.');
    // (update-155) a question (never a save): "the same" / only what changed / whole – the key is the site and the whole question
    String? mk;
    if (fn == 'api' && rid == null && args.length > 1 && keptQuestion('${args[1]}')) {
      mk = '${site ?? ''}|${jsonEncode(args)}';
      if (mk.length > 20000) mk = null;
    }
    final had = mk == null || whole ? null : answers.get(mk);
    final body = <String, dynamic>{'fn': fn, 'args': args, if (rid != null) 'rid': rid, if ((site ?? '').isNotEmpty) 'site': site, if (mk != null) 'm': 1, if (had != null) 'have': had.h, if (had != null) 'dx': 1};
    final r = await _send(() => _c.post(Uri.parse('$mechUrl/api/rpc'), headers: {'Content-Type': 'application/json'}, body: jsonEncode(body)));
    final j = _json(r, 'The ERP server');
    if (j.containsKey('error')) {
      if (mk != null) answers.drop(mk); // a refusal (no access any more …): nothing of it is kept
      throw ApiError(j['error'].toString(), status: r.statusCode);
    }
    final h = j['h'];
    if (mk != null && h is String) {
      if (j['same'] != null) {
        if (had != null && had.h == h) {
          answers.same++;
          answers.touch(mk);
          return jsonDecode(had.text);
        }
        return _rpc(fn, args, whole: true);
      }
      if (j['delta'] != null) {
        final t = had != null && had.h == j['base'] ? rclPatch(had.text, j['delta']) : null;
        if (t != null && fingerprint(t) == h) {
          answers.delta++;
          answers.keep(mk, h, t);
          return jsonDecode(t);
        }
        answers.mismatch++;
        answers.drop(mk);
        return _rpc(fn, args, whole: true);
      }
      if (j.containsKey('result')) {
        final text = utf8.decode(r.bodyBytes), p = text.indexOf('"result":');
        if (text.startsWith('{"h":"') && p > 0) {
          answers.full++;
          answers.keep(mk, h, text.substring(p + 9, text.length - 1));
        }
      }
    }
    return j['result'];
  }

  /// The Portal's ticket → a Mechanical sign-in on [siteCode]. Returns { token, user, site, siteName, portal }.
  Future<Map<String, dynamic>> openSite(String siteCode) async {
    final t = await ticket(siteCode);
    site = siteCode;
    final res = await _rpc('ssoLogin', [t]);
    final m = (res as Map).cast<String, dynamic>();
    answers.clear(); // (update-155) a new sign-in: nothing kept of the one before
    token = m['token']?.toString();
    if ((m['site'] ?? '').toString().isNotEmpty) site = m['site'].toString();
    await keep.write(kToken, token);
    await keep.write(kSite, site);
    return m;
  }

  String _newRid() => 'm${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}${_rnd.nextInt(1 << 32).toRadixString(36)}';
  /// (3.85.0) a save's own number for an entry kept on the phone before it was ever sent (no network)
  String newRid() => _newRid();

  /* (14-10-2026, update-108 of Mechanical) A SAVE THE BILL LOCK REFUSED – its entry is in a submitted bill: as on the web page, the
   * person may send exactly that save to the Super Admin for approval, with a reason (sendChangeRequest). It is saved only when he
   * approves it (Mechanical → Approvals). [askApproval] is set by the app (a box asking for the reason; null = not sent); the
   * screen then gets [crSent] as its error – nothing was saved. The Super Admin himself is not refused (his ticket says so). */
  static const crFns = {'saveLogRows', 'saveLogBook', 'saveLogDay', 'updateLogRow', 'deleteLogRow', 'saveLogBulk', 'importLogBook', 'saveTankerTrips', 'deleteTankerTrip',
    'updateTankerTrip', 'saveTankerRange', 'importTankerTrips', 'saveDieselIssue', 'saveDieselBulk', 'importDiesel', 'updateDieselIssue', 'deleteDieselIssue'};
  static const crSent = 'Sent to the Super Admin for approval – it is saved only when he approves (nothing is saved until then).';
  static bool crLocked(String m) => m.contains('is in the submitted RA Bill') || crApproved(m);
  /// (3.33.0 – Mechanical update-152) an entry approved in verification: locked as well – only the Super Admin changes it.
  static bool crApproved(String m) => m.contains(' – an approved entry cannot be changed or deleted without the Super Admin');
  /// (3.33.0) the Super Admin's save of a locked entry: the server asks his reason ("SA_REASON: …") – [askReason] (a box) gives it.
  static bool saReason(String m) => m.startsWith('SA_REASON: ');
  Future<String?> Function(String message)? askReason;
  /// (15-10-2026, update-114) A work the Super Admin put under verification: the server CHECKED the entry and sent it to the
  /// people who approve it ("Sent for verification to … – VF-00001 …"); it is saved when the last of them approves. Not a fault.
  static bool isSent(String m) => m.startsWith('Sent for verification ') || m.startsWith('Kept as stock short ') || m == crSent;      // (3.85.0) kept as stock short: told the same way
  /* (3.85.0, Mechanical update-211, asked 04-11-2026) STOCK SHORT: a diesel issue or transfer the stock cannot cover now – the person is
   * asked ([askShort]); yes: the same save again with {short: true} (a new number) – the server checks everything but its stock and
   * keeps it in Approvals ("Stock short"), saved by itself when the stock comes. An entry kept on the phone with no network is sent so
   * by itself (sendKept). */
  static const shortFns = {'saveDieselIssue', 'saveDieselBulk', 'saveTransfer', 'saveTransferBulk'};
  static final shortRe = RegExp(r'^Not enough [^\n]*? at ');
  /// the words when the stock alone refused it ('' = something else, or saved)
  static String shortOf(Object? r) {
    if (r is String) return shortRe.hasMatch(r) ? r : '';
    if (r is! Map || r['ok'] != false || r['warning'] != null || (r['warnings'] is List && (r['warnings'] as List).isNotEmpty)) return '';
    final l = [for (final e in (r['errors'] as List? ?? const [])) e is Map ? '${e['msg'] ?? ''}' : '$e'];
    return l.isNotEmpty && l.every(shortRe.hasMatch) ? l.join(' | ') : '';
  }
  /// true = keep it as stock short (the screen asks); null / false = not kept
  Future<bool> Function(String message)? askShort;
  /// (3.85.0) the server's signed time from the last answer (getInit / sync): sent with an entry kept with no network – the server then
  /// measures the user's date rule from that day (an entry of last night sent this morning is still his)
  String stamp = '';
  /// (3.1.7) An entry kept on the phone (no network) – sent by itself later.
  static const keptMsg = 'Kept on this phone – it is sent by itself when the network is back (Me → Waiting on this phone).';
  static bool isGood(String m) => isSent(m) || m == keptMsg;
  Future<String?> Function(String message)? askApproval;
  Future<bool> _askShort(String msg) async {
    final f = askShort;
    if (f == null) return false;
    try {
      return await f(msg);
    } catch (_) {
      return false;
    }
  }
  /// true = sent (with the person's reason); false = he did not send it.
  Future<bool> _offer(String fn, List<dynamic> args, String msg) async {
    final ask = askApproval;
    final why = ask == null ? null : await ask(msg);
    if (why == null || why.trim().isEmpty) return false;
    await _rpc('api', [token, 'sendChangeRequest', [{'fn': fn, 'args': args, 'reason': why.trim()}]]);
    return true;
  }

  /// (3.39.0, asked 25-10-2026: "app opening slow … ultra fast") A question asked once, as it is – with the sign-in kept on the
  /// phone, nothing renewed or tried again (Session.start asks the site's first lists this way while the Portal is still being
  /// asked; if it fails the normal [call] is made).
  Future<dynamic> callOnce(String fn) {
    if ((token ?? '').isEmpty) return Future.error(ApiError('SESSION_EXPIRED', status: 401));
    return _rpc('api', [token, fn, const []]);
  }

  /// One action of Mechanical (getInit, saveDieselIssue …) with the person's sign-in. [save]: it changes data – it gets its
  /// own number and is sent again after a lost connection (at most 4 tries); a question is asked again at most twice.
  /// [with0] (3.85.0): what goes with it from the start – {short: true} (kept as stock short), {made: stamp} (made with no network)
  Future<dynamic> call(String fn, [List<dynamic> args = const [], bool save = false, String? sameRid, Map<String, dynamic>? with0]) async {
    var rid = save ? (sameRid ?? _newRid()) : null;
    var renewed = false;
    Map<String, dynamic>? meta = with0 == null || with0.isEmpty ? null : {...with0}; // (3.33.0) the Super Admin's reason, when the server asked for it
    for (var tryNo = 1;; tryNo++) {
      try {
        if ((token ?? '').isEmpty) throw ApiError('SESSION_EXPIRED', status: 401);
        final res = await _rpc('api', [token, fn, args, if (meta != null) meta], rid: rid);
        // a save that answers "not saved" with a line refused by the bill lock (saveLogRows …)
        if (crFns.contains(fn) && res is Map && res['ok'] == false && res['errors'] is List) {
          final lk = (res['errors'] as List).map((x) => x is Map ? (x['msg'] ?? '').toString() : x.toString()).where(crLocked).toList();
          if (lk.isNotEmpty && await _offer(fn, args, lk.first)) throw ApiError(crSent, code: 'sent');
        }
        // (3.85.0) only the stock refused it ("Multiple entries" of transfers): kept as stock short?
        final sw = shortFns.contains(fn) && meta?['short'] != true ? shortOf(res) : '';
        if (sw.isNotEmpty && await _askShort(sw)) {
          meta = {...?meta, 'short': true};
          if (rid != null) rid = _newRid();
          continue;
        }
        return res;
      } on ApiError catch (e) {
        if (e.code == 'sent') rethrow;
        if (isSent(e.message)) throw ApiError(e.message, code: 'sent');      // sent for verification: told as it is, never sent again
        if (crFns.contains(fn) && crLocked(e.message) && await _offer(fn, args, e.message)) throw ApiError(crSent, code: 'sent');
        // (3.85.0) the stock cannot cover it: kept as stock short? (a new number – the refused one keeps its answer on the server)
        if (shortFns.contains(fn) && meta?['short'] != true && shortRe.hasMatch(e.message) && await _askShort(e.message)) {
          meta = {...?meta, 'short': true};
          if (rid != null) rid = _newRid();
          continue;
        }
        if (saReason(e.message) && meta?['reason'] == null) {
          final ask = askReason, why = ask == null ? null : await ask(e.message.replaceFirst('SA_REASON: ', ''));
          if (why == null || why.trim().isEmpty) throw ApiError('Not saved – no reason was given.', code: 'noreason');
          meta = {...?meta, 'reason': why.trim()};
          if (rid != null) rid = _newRid(); // (the refused number keeps its answer on the server: the save with the reason is a new one)
          continue;
        }
        if (e.sessionEnded && !renewed && (site ?? '').isNotEmpty && hasPortal) {
          renewed = true; // a new Mechanical sign-in with a new ticket, nothing typed
          await openSite(site!);
          continue;
        }
        // (update-155, the audit's R3) sent again by itself: a question, or a save with its number (saved once on the server); a
        // change WITHOUT a number only when the server said it did not start it (busy, another save running): after no answer – or
        // "could not reach the database" – it may have been done, so it is not sent again (the person sees the message and decides)
        final notStarted = e.status == 503 && RegExp(r'RETRY_LATER|Another save is still running').hasMatch(e.message);
        final again = (save || keptQuestion(fn) || fn == 'whoami') ? (e.noConnection || e.status == 503) : notStarted;
        if (again && tryNo < (save ? 4 : 3)) {
          await Future<void>.delayed(Duration(milliseconds: 700 * tryNo));
          continue;
        }
        if (e.noConnection && rid != null) throw ApiError(e.message, status: e.status, code: e.code, rid: rid);
        rethrow;
      }
    }
  }

  /// (3.61.0, Mechanical update-186) THE ASSISTANT'S ANSWER WORD BY WORD: POST <mechanical>/api/ai { token, x, site } – each line of the
  /// answer as it comes ({t: 'd', x: words} …, then {t: 'end', parts, model, …} or {t: 'err', e, cut}) is handed to [onLine]; gives the
  /// last one ('end' / 'err' – read no further; null: the line was lost before the end). Every check is the server's own (aiPrepare –
  /// getAiReply's). A refusal before the first line comes as JSON {error} (not signed in, the limits, no Claude key: "AI_NO_STREAM"); a
  /// server without it (404, an older one): "AI_NO_STREAM".
  Future<Map<String, dynamic>?> aiStream(Map<String, dynamic> x, void Function(Map<String, dynamic> line) onLine) async {
    if (mechUrl.isEmpty) throw ApiError('Mechanical is not open on this site.');
    if ((token ?? '').isEmpty) throw ApiError('SESSION_EXPIRED', status: 401);
    final rq = http.Request('POST', Uri.parse('$mechUrl/api/ai'))
      ..headers['Content-Type'] = 'application/json'
      ..body = jsonEncode({'token': token, 'x': x, if ((site ?? '').isNotEmpty) 'site': site});
    http.StreamedResponse r;
    try {
      r = await _c.send(rq).timeout(timeout);
    } on TimeoutException {
      throw ApiError('The server did not answer in time – check the network and try again.', code: 'net');
    } catch (e) {
      if (e is ApiError) rethrow;
      throw ApiError('No connection – check the internet and try again.', code: 'net');
    }
    if (!(r.headers['content-type'] ?? '').contains('ndjson')) {
      var body = '';
      try {
        body = await r.stream.bytesToString().timeout(timeout);
      } catch (_) {/* nothing readable */}
      Map? j;
      try {
        final d = jsonDecode(body);
        if (d is Map) j = d;
      } catch (_) {/* not JSON: an older server's page */}
      if (r.statusCode == 404 || j == null || j['error'] == null) throw ApiError('AI_NO_STREAM', status: r.statusCode);
      throw ApiError('${j['error']}', status: r.statusCode);
    }
    Map<String, dynamic>? last;
    try {
      await for (final l in r.stream.transform(utf8.decoder).transform(const LineSplitter()).timeout(const Duration(seconds: 50))) {
        aiStreamLine(l, (m) {
          if (last != null) return;
          onLine(m);
          if (m['t'] == 'end' || m['t'] == 'err') last = m;
        });
        if (last != null) break; // the answer is there with its last line: what the server still does after it is not waited for
      }
    } catch (e) {
      if (e is ApiError) rethrow; // (the line lost or too slow: what came is what there is – the chat asks again in one piece)
    }
    return last;
  }

  // ---------------- the Store (3.10.0) ----------------
  String _storeCookie = '', _storeKey = '';

  /// The Store's sign-in on [siteCode] (a ticket of the Portal, used once): who, Admin or User, the pages he may open.
  Future<Map<String, dynamic>> storeOpen(String siteCode, String storeUrl) async {
    final t = await ticket(siteCode, 'store');
    final r = await _send(() => _c.post(Uri.parse('$storeUrl/api/sso'), headers: {'Content-Type': 'application/json', 'X-RCL': '1'}, body: jsonEncode({'ticket': t})));
    final j = _json(r, 'The Store');
    if (r.statusCode >= 400 || j['error'] != null) throw ApiError(j['error']?.toString() ?? 'Error ${r.statusCode}', status: r.statusCode, code: (j['code'] ?? '').toString());
    final m = RegExp(r'rcl_store=([^;]*)').firstMatch(r.headers['set-cookie'] ?? '');
    _storeCookie = m == null ? '' : 'rcl_store=${m.group(1)}';
    _storeKey = '$siteCode|$storeUrl';
    return j;
  }

  /// POST <store>/api/items { action, … } – a new Store sign-in when it has ended (once).
  /// (3.54.0, the Store's step 2) [path] 'work': the Store's work (api/work – requirements, POs, GRN, issues, returns, reports).
  Future<Map<String, dynamic>> store(String siteCode, String storeUrl, Map<String, dynamic> body, {String path = 'items'}) async {
    for (var tryNo = 1;; tryNo++) {
      if (_storeCookie.isEmpty || _storeKey != '$siteCode|$storeUrl') await storeOpen(siteCode, storeUrl);
      final r = await _send(() => _c.post(Uri.parse('$storeUrl/api/$path'), headers: {'Content-Type': 'application/json', 'X-RCL': '1', 'Cookie': _storeCookie}, body: jsonEncode(body)));
      final j = _json(r, 'The Store');
      if (r.statusCode == 401 && j['code'] == 'session' && tryNo == 1) {
        _storeCookie = '';
        continue;
      }
      if (r.statusCode >= 400 || j['error'] != null) {
        throw ApiError(j['error']?.toString() ?? 'Error ${r.statusCode}', status: r.statusCode, code: (j['code'] ?? '').toString(), data: {...j}..remove('error'));
      }
      return j;
    }
  }

  // ---------------- Engineering (3.59.0) ----------------
  String _engCookie = '', _engKey = '';

  /// (3.59.0, Mechanical update-185) Engineering's sign-in on [siteCode] – as the Store's: a ticket of the Portal for the module
  /// 'engineering', POST <eng>/api/sso { ticket } → its cookie rcl_eng.
  Future<Map<String, dynamic>> engOpen(String siteCode, String engUrl) async {
    final t = await ticket(siteCode, 'engineering');
    final r = await _send(() => _c.post(Uri.parse('$engUrl/api/sso'), headers: {'Content-Type': 'application/json', 'X-RCL': '1'}, body: jsonEncode({'ticket': t})));
    final j = _json(r, 'Engineering');
    if (r.statusCode >= 400 || j['error'] != null) throw ApiError(j['error']?.toString() ?? 'Error ${r.statusCode}', status: r.statusCode, code: (j['code'] ?? '').toString());
    final m = RegExp(r'rcl_eng=([^;]*)').firstMatch(r.headers['set-cookie'] ?? '');
    _engCookie = m == null ? '' : 'rcl_eng=${m.group(1)}';
    _engKey = '$siteCode|$engUrl';
    return j;
  }

  /// POST <eng>/api/eng { action, … } with his Engineering sign-in of this site – a new sign-in when it has ended (once).
  Future<Map<String, dynamic>> eng(String siteCode, String engUrl, Map<String, dynamic> body) async {
    for (var tryNo = 1;; tryNo++) {
      if (_engCookie.isEmpty || _engKey != '$siteCode|$engUrl') await engOpen(siteCode, engUrl);
      final r = await _send(() => _c.post(Uri.parse('$engUrl/api/eng'), headers: {'Content-Type': 'application/json', 'X-RCL': '1', 'Cookie': _engCookie}, body: jsonEncode(body)));
      final j = _json(r, 'Engineering');
      if (r.statusCode == 401 && j['code'] == 'session' && tryNo == 1) {
        _engCookie = '';
        continue;
      }
      if (r.statusCode >= 400 || j['error'] != null) throw ApiError(j['error']?.toString() ?? 'Error ${r.statusCode}', status: r.statusCode, code: (j['code'] ?? '').toString());
      return j;
    }
  }

  // ---------------- Purchase (3.72.0) ----------------
  String _purCookie = '', _purKey = '';

  /// (3.72.0, rcl-purchase – the Purchase Department, one for every site) Purchase's sign-in on [siteCode] – as Engineering's: a
  /// ticket of the Portal for the module 'purchase', POST <purchase>/api/sso { ticket }. The answer: who, his role (super / admin /
  /// user), the site open now and every site where he has Purchase (its Dashboard). (3.94.0) Its cookie (rcl_pur) is kept for the
  /// Purchase pages (api.pur).
  Future<Map<String, dynamic>> purOpen(String siteCode, String purUrl) async {
    final t = await ticket(siteCode, 'purchase');
    final r = await _send(() => _c.post(Uri.parse('$purUrl/api/sso'), headers: {'Content-Type': 'application/json', 'X-RCL': '1'}, body: jsonEncode({'ticket': t})));
    final j = _json(r, 'Purchase');
    if (r.statusCode >= 400 || j['error'] != null) throw ApiError(j['error']?.toString() ?? 'Error ${r.statusCode}', status: r.statusCode, code: (j['code'] ?? '').toString());
    final m = RegExp(r'rcl_pur=([^;]*)').firstMatch(r.headers['set-cookie'] ?? '');
    _purCookie = m == null ? '' : 'rcl_pur=${m.group(1)}';
    _purKey = '$siteCode|$purUrl';
    return j;
  }

  /// (3.94.0, Purchase Phase 1) POST <purchase>/api/pur { action, … } with his Purchase sign-in of this site – the same actions,
  /// checks and access as the web's pages; a new sign-in when it has ended (once).
  Future<Map<String, dynamic>> pur(String siteCode, String purUrl, Map<String, dynamic> body) async {
    for (var tryNo = 1;; tryNo++) {
      if (_purCookie.isEmpty || _purKey != '$siteCode|$purUrl') await purOpen(siteCode, purUrl);
      final r = await _send(() => _c.post(Uri.parse('$purUrl/api/pur'), headers: {'Content-Type': 'application/json', 'X-RCL': '1', 'Cookie': _purCookie}, body: jsonEncode(body)));
      final j = _json(r, 'Purchase');
      if (r.statusCode == 401 && j['code'] == 'session' && tryNo == 1) {
        _purCookie = '';
        continue;
      }
      if (r.statusCode >= 400 || j['error'] != null) throw ApiError(j['error']?.toString() ?? 'Error ${r.statusCode}', status: r.statusCode, code: (j['code'] ?? '').toString());
      return j;
    }
  }

  // ---------------- HR (3.103.0) ----------------
  String _hrCookie = '', _hrKey = '';

  /// (3.103.0, rcl-hr) HR's sign-in on [siteCode] – as Purchase's: a ticket of the Portal for [module] ('hr' – the HR office's
  /// people; 'hrme' – "My HR", an employee for himself), POST <hr>/api/sso { ticket } → its cookie rcl_hr.
  Future<Map<String, dynamic>> hrOpen(String siteCode, String hrUrl, String module) async {
    final t = await ticket(siteCode, module);
    final r = await _send(() => _c.post(Uri.parse('$hrUrl/api/sso'), headers: {'Content-Type': 'application/json', 'X-RCL': '1'}, body: jsonEncode({'ticket': t})));
    final j = _json(r, 'HR');
    if (r.statusCode >= 400 || j['error'] != null) throw ApiError(j['error']?.toString() ?? 'Error ${r.statusCode}', status: r.statusCode, code: (j['code'] ?? '').toString());
    final m = RegExp(r'rcl_hr=([^;]*)').firstMatch(r.headers['set-cookie'] ?? '');
    _hrCookie = m == null ? '' : 'rcl_hr=${m.group(1)}';
    _hrKey = '$siteCode|$hrUrl|$module';
    return j;
  }

  /// POST <hr>/api/hr { action, … } with his HR sign-in of this site – a new sign-in when it has ended (once).
  /// [path] (3.111.0): 'hr' – HR's actions; 'face' – the face for attendance (its own endpoint of the same server, the same sign-in).
  Future<Map<String, dynamic>> hr(String siteCode, String hrUrl, String module, Map<String, dynamic> body, {String path = 'hr'}) async {
    for (var tryNo = 1;; tryNo++) {
      if (_hrCookie.isEmpty || _hrKey != '$siteCode|$hrUrl|$module') await hrOpen(siteCode, hrUrl, module);
      final r = await _send(() => _c.post(Uri.parse('$hrUrl/api/$path'), headers: {'Content-Type': 'application/json', 'X-RCL': '1', 'Cookie': _hrCookie}, body: jsonEncode(body)));
      final j = _json(r, 'HR');
      if (r.statusCode == 401 && j['code'] == 'session' && tryNo == 1) {
        _hrCookie = '';
        continue;
      }
      if (r.statusCode >= 400 || j['error'] != null) {
        throw ApiError(j['error']?.toString() ?? 'Error ${r.statusCode}', status: r.statusCode, code: (j['code'] ?? '').toString(), data: {...j}..remove('error'));
      }
      return j;
    }
  }

  /// (3.103.0) The proof photo of a punch, sent straight to its place ([url] – a link of HR's server for this ONE file).
  Future<void> hrPhoto(String url, List<int> jpg) async {
    final r = await _send(() => _c.put(Uri.parse(url), headers: {'Content-Type': 'image/jpeg', 'x-upsert': 'false'}, body: jpg));
    if (r.statusCode >= 400) throw ApiError('The photo could not be sent (${r.statusCode}) – try again.', status: r.statusCode, code: 'photo');
  }

  /// (3.108.0) A paper he attaches himself (Me → My documents), sent straight to its place ([url] – a link of HR's server for
  /// this ONE file; [type] – image/jpeg, image/png, image/webp or application/pdf).
  Future<void> hrFile(String url, List<int> bytes, String type) async {
    final r = await _send(() => _c.put(Uri.parse(url), headers: {'Content-Type': type, 'x-upsert': 'false'}, body: bytes));
    if (r.statusCode >= 400) throw ApiError('The file could not be sent (${r.statusCode}) – try again.', status: r.statusCode, code: 'file');
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


/// (3.61.0) one line of the answer word by word (JSON) → its map; an empty or broken line is left out.
void aiStreamLine(String l, void Function(Map<String, dynamic> m) on) {
  if (l.trim().isEmpty) return;
  Object? j;
  try {
    j = jsonDecode(l);
  } catch (_) {
    return;
  }
  if (j is Map) on(j.cast<String, dynamic>());
}
