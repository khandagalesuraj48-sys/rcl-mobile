/* (3.171.0 patch 4 – SNI, his approval of 25-11-2026: "he sagle tu dilel screen pn ok aahet asch banaw … wifi ki mobile data as nko
 * olkhayla fkt mobile data") THE NETWORK, AS MEASURED – one monitor for the whole app (the SNI audit's finding 1).
 *   – Fed ONLY by the app's own requests (Api's client, [NetClient]): how long each answer took and how it ended. Nothing is guessed,
 *     nothing random; no test traffic while the app is used. Before the first answer: "Checking".
 *   – Each server apart (the Portal, Mechanical, HR, Store, Engineering, Purchase); the indicator shows the worst one used in the last
 *     2 minutes, the sheet each one.
 *   – Internet or our server: only when a request found no connection or got no answer, ONE request to Android's own check address
 *     (connectivitycheck.gstatic.com/generate_204 – nothing of the person is sent): it answers → SERVER DOWN; it fails too → OFFLINE.
 *   – Idle in front (nothing measured for 30 s): one small request to the Portal ([probe] – its public keys); in the background: nothing.
 *   – The rules (the doc's "The rules", the numbers to be tuned after measuring phones at the sites): the last 10 answers of the last
 *     2 minutes – middle time under 800 ms = GOOD; 800 ms or more, or one answer over 5 s = WEAK; 2 failures or more = UNSTABLE; the
 *     last request found no connection and the check is on its way = RECONNECTING. A change shows after it held 3 s (no flicker);
 *     RECONNECTING, SERVER DOWN and OFFLINE show at once.
 * No Wi-Fi / mobile data reading (his word: everybody is on mobile data) – no new plugin: the whole of it reaches the phones as a
 * Shorebird patch.
 * (3.174.1, his audit brief of 28-11-2026: "Do not falsely blame the internet when backend performance is the actual problem … clear
 * distinction between Internet Offline / Internet Weak / Backend Slow / Backend Unavailable / Good") what the audit found and changed:
 *   – SLOW IS NOT WEAK. An answer's time is the server's work + the network; the old rule called a slow answer "Weak" – the network was
 *     blamed for a server's 3.8 s. Now a server whose middle time is 800 ms or more (or one answer over 5 s) is [NetState.slow] ("Server
 *     slow") while the phone's own internet check is quick, and [NetState.weak] ("Internet weak") only when that check itself took
 *     [weakLinkMs] or more, or did not answer. The check for it: ONE request to Android's address, at most once in 2 minutes, only
 *     while a server is slow – nothing while everything is quick.
 *   – THE INTERNET ROW NEVER CONTRADICTS THE SERVERS: an answer of one of our servers after the last check is the proof that the
 *     internet works ([internetWorks]) – "no answer" beside servers that all answer (a check that failed once and was never asked
 *     again) is gone. The check itself asks a second address before it says "no answer".
 *   – LIGHTER: the idle request to the Portal every 30 s becomes 30 s → 60 s → 2 minutes while nothing is used and all is good (any
 *     real request starts it at 30 s again); "Check now" and the rhythm share one request on its way (no second one beside it). */
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'lang.dart';

enum NetEnd { ok, serverError, timeout, noConnection }

/// From the best to the worst (the indicator shows the worst server); [checking] = nothing measured yet.
/// [slow] = our SERVER answers slowly while the internet is quick (the server's work); [weak] = the INTERNET itself is slow.
enum NetState { checking, good, slow, weak, unstable, reconnecting, serverDown, offline }

int _bad(NetState s) => const {NetState.checking: -1, NetState.good: 0, NetState.slow: 1, NetState.weak: 2, NetState.unstable: 3, NetState.reconnecting: 4, NetState.serverDown: 5, NetState.offline: 6}[s]!;

class NetMark {
  NetMark(this.at, this.ms, this.end, {this.probe = false});
  final DateTime at;
  final int ms;
  final NetEnd end;

  /// The monitor's own small request to the Portal (not the person's work).
  final bool probe;
  bool get ok => end == NetEnd.ok;
}

/// Words in the app's language (new words come with the patch – the language files are not changed by it).
String w3(String en, String mr, String hi) => Lang.i.code == 'mr' ? mr : Lang.i.code == 'hi' ? hi : en;

/// "240 ms", "1.8 s".
String msText(int ms) => ms < 1000 ? '$ms ms' : '${(ms / 1000).toStringAsFixed(1)} s';

class NetMonitor extends ChangeNotifier {
  NetMonitor();
  static NetMonitor i = NetMonitor();

  /// Off in the tests (and in the background alarm): nothing is recorded, nothing is asked. main.dart switches it on.
  bool on = false;
  DateTime Function() now = DateTime.now;

  /// Android's own check: its time in ms, or null = no internet. A test puts its own.
  Future<int?> Function() internetCheck = _gstatic;

  /// One small request to the Portal (set by the app: Api.probe).
  Future<void> Function()? probe;

  static const window = Duration(minutes: 2), keepLast = 10, hold = Duration(seconds: 3), idle = Duration(seconds: 30), slowAfter = Duration(seconds: 5);

  /// A server's middle time from which it is "slow"; the internet check's own time from which the INTERNET is "weak" (a new
  /// connection each time: the name, the handshake and one answer – numbers to be tuned after measuring phones at the sites).
  static const slowMidMs = 800, weakLinkMs = 1200;

  final Map<String, List<NetMark>> _marks = {};
  final Map<int, (String, DateTime)> _going = {};
  int _seq = 0;

  bool? internet;
  DateTime? internetAt;
  int? internetMs;
  Future<void>? _checkF;
  DateTime? _checkedAt;
  Future<void>? _probeF;
  bool _probeOn = false;
  int _idleN = 0; // idle requests to the Portal in a row with no real request between them

  NetState _shown = NetState.checking;
  Timer? _holdT;

  /// When the indicator last changed, and from what (the sheet: "Last change").
  DateTime? changedAt;
  NetState? changedFrom;

  NetState get state => _shown;

  /// The servers measured in the last 2 minutes.
  List<String> get servers => [for (final e in _marks.entries) if (recent(e.key).isNotEmpty) e.key];

  /// The last 10 answers of [server] in the last 2 minutes (oldest first).
  List<NetMark> recent(String server) {
    final t = now().subtract(window);
    final l = (_marks[server] ?? const <NetMark>[]).where((m) => m.at.isAfter(t)).toList();
    return l.length > keepLast ? l.sublist(l.length - keepLast) : l;
  }

  DateTime? get lastAt {
    DateTime? a;
    for (final l in _marks.values) {
      if (l.isNotEmpty && (a == null || l.last.at.isAfter(a))) a = l.last.at;
    }
    return a;
  }

  static int? _middle(List<int> xs) {
    if (xs.isEmpty) return null;
    final s = [...xs]..sort();
    return s.length.isOdd ? s[s.length ~/ 2] : ((s[s.length ~/ 2 - 1] + s[s.length ~/ 2]) / 2).round();
  }

  /// The middle time of [server]'s answers (null: none in the last 2 minutes).
  int? middleMs(String server) => _middle([for (final m in recent(server)) if (m.ok) m.ms]);

  /// The middle time of every answer of the last 2 minutes.
  int? get middleAll => _middle([for (final s in servers) for (final m in recent(s)) if (m.ok) m.ms]);

  /// The state of one server by the rules (above).
  NetState stateOf(String server) {
    final m = recent(server);
    if (m.isEmpty) return NetState.checking;
    final last = m.last;
    if (!last.ok) {
      if (last.end == NetEnd.timeout || last.end == NetEnd.noConnection) {
        final at = internetAt;
        final checked = at != null && (!at.isBefore(last.at) || now().difference(at) < const Duration(seconds: 15));
        if (!checked) return NetState.reconnecting;
        return internet == true ? NetState.serverDown : NetState.offline;
      }
      var trail = 0;
      for (final x in m.reversed) {
        if (x.ok) break;
        trail++;
      }
      if (trail >= 2) return NetState.serverDown;
    }
    if (m.where((x) => !x.ok).length >= 2) return NetState.unstable;
    final oks = [for (final x in m) if (x.ok) x.ms];
    if (oks.isEmpty) return NetState.unstable;
    // (3.174.1) slow answers: the server's work unless the phone's own internet check says the internet is slow
    if (_slowOks(oks)) return linkWeak ? NetState.weak : NetState.slow;
    return NetState.good;
  }

  static bool _slowOks(List<int> oks) => oks.isNotEmpty && (_middle(oks)! >= slowMidMs || oks.any((x) => x > 5000));

  /// The last answer of any of our servers (the proof that the internet works).
  DateTime? get lastOkAt {
    DateTime? a;
    for (final l in _marks.values) {
      for (final x in l.reversed) {
        if (x.ok) {
          if (a == null || x.at.isAfter(a)) a = x.at;
          break;
        }
      }
    }
    return a;
  }

  /// Does the internet work – by the newest proof: an answer of one of our servers after the last check = yes, whatever that check
  /// said; else the check's own result (null: never checked and nothing answered).
  bool? get internetWorks {
    final ok = lastOkAt, at = internetAt;
    if (ok != null && (at == null || ok.isAfter(at))) return true;
    return internet;
  }

  bool get _linkFresh => internetAt != null && now().difference(internetAt!) <= window;

  /// The internet itself measured slow in the last 2 minutes (its check took [weakLinkMs] or more, or did not answer).
  bool get linkWeak => _linkFresh && (internet == false || (internetMs ?? 0) >= weakLinkMs);

  /// A slow server whose cause is not known yet (no internet check in the last 2 minutes).
  bool get _slowUnknown => !_linkFresh && servers.any((s) => _slowOks([for (final x in recent(s)) if (x.ok) x.ms]));

  /// The worst server of the last 2 minutes (and which one).
  (NetState, String) get worst {
    var w = NetState.checking;
    var who = '';
    for (final s in servers) {
      final x = stateOf(s);
      if (_bad(x) > _bad(w)) {
        w = x;
        who = s;
      }
    }
    return (w, who);
  }

  /// A request on its way for longer than 5 s (the "slow network" line): its age, or null.
  Duration? get slowest {
    Duration? d;
    final t = now();
    for (final g in _going.values) {
      final a = t.difference(g.$2);
      if (a >= slowAfter && (d == null || a > d)) d = a;
    }
    return d;
  }

  /// One answer of [server]: [ms] long, ended as [end].
  void record(String server, int ms, NetEnd end) {
    if (!on || server.isEmpty) return;
    final l = _marks.putIfAbsent(server, () => <NetMark>[]);
    final own = _probeOn && server == 'portal';
    l.add(NetMark(now(), ms, end, probe: own));
    if (l.length > 40) l.removeRange(0, l.length - 40);
    if (!own) _idleN = 0; // the app is used: the idle rhythm starts at 30 s again
    if (end == NetEnd.timeout || end == NetEnd.noConnection) unawaited(checkInternet());
    update();
  }

  /// Watches one request of [server] (Api's client): its time to the answer; a timeout after [limit] (a later answer is not counted).
  Future<T> watch<T>(String server, Future<T> f, Duration limit, {int Function(T r)? status}) {
    if (!on || server.isEmpty) return f;
    final id = ++_seq;
    final t0 = now();
    _going[id] = (server, t0);
    var done = false;
    final timer = Timer(limit, () {
      if (done) return;
      done = true;
      _going.remove(id);
      record(server, limit.inMilliseconds, NetEnd.timeout);
    });
    void end(NetEnd e) {
      if (done) return;
      done = true;
      timer.cancel();
      _going.remove(id);
      record(server, now().difference(t0).inMilliseconds, e);
    }

    Future<T> run() async {
      try {
        final r = await f;
        final st = status == null ? 200 : status(r);
        end(st >= 500 ? NetEnd.serverError : NetEnd.ok);
        return r;
      } catch (_) {
        end(NetEnd.noConnection);
        rethrow;
      }
    }

    return run();
  }

  /// Android's check (at most once in [every]; "Check now" asks it at once). One on its way is shared – never two side by side.
  Future<void> checkInternet({bool now0 = false, Duration every = const Duration(seconds: 10)}) {
    if (!on) return Future<void>.value();
    final f = _checkF;
    if (f != null) return f;
    final c = _checkedAt;
    if (!now0 && c != null && now().difference(c) < every) return Future<void>.value();
    return _checkF = () async {
      try {
        final ms = await internetCheck();
        internet = ms != null;
        internetMs = ms;
        internetAt = now();
        _checkedAt = internetAt;
      } finally {
        _checkF = null;
        update();
      }
    }();
  }

  /// The small request to the Portal – one on its way is shared (the rhythm and "Check now" never ask twice).
  Future<void> _probe() {
    final p = probe;
    if (p == null) return Future<void>.value();
    final f = _probeF;
    if (f != null) return f;
    _probeOn = true; // (before it starts: its answer is marked as the monitor's own, not the person's work)
    return _probeF = p().catchError((Object _) {}).whenComplete(() {
      _probeF = null;
      _probeOn = false;
    });
  }

  /// How long nothing must have been measured before the next idle request: 30 s, then 60 s, then 2 minutes while all is good and
  /// nothing is used (a real request, or a state that is not good, brings it back to 30 s).
  Duration get idleGap => _shown == NetState.good ? idle * (1 << (_idleN > 2 ? 2 : _idleN)) : idle;

  /// Every 5 s while the app is in front (NetHost): the 2 minutes move on; idle → one small request to the Portal.
  void tick() {
    if (!on) return;
    update();
    final a = lastAt;
    if (_probeF != null || probe == null || (a != null && now().difference(a) < idleGap)) return;
    _idleN++;
    unawaited(_probe());
  }

  /// "Check now" (the sheet): the Portal and Android's check, at once.
  Future<void> checkNow() async {
    if (!on) return;
    await Future.wait([_probe(), checkInternet(now0: true)]);
  }

  /// The state shown: worse at once; better / weak / unstable after it held 3 s.
  void update() {
    // (3.174.1) a slow server and no internet check in the last 2 minutes: one check tells the server's work from a weak internet
    if (on && _slowUnknown) unawaited(checkInternet(every: const Duration(seconds: 60)));
    final c = worst.$1;
    if (c == _shown) {
      _holdT?.cancel();
      _holdT = null;
      notifyListeners();
      return;
    }
    final atOnce = _shown == NetState.checking || c == NetState.reconnecting || c == NetState.serverDown || c == NetState.offline;
    if (atOnce) {
      _show(c);
      return;
    }
    _holdT ??= Timer(hold, () {
      _holdT = null;
      final again = worst.$1;
      if (again != _shown) _show(again);
    });
    notifyListeners();
  }

  void _show(NetState s) {
    _holdT?.cancel();
    _holdT = null;
    changedFrom = _shown;
    changedAt = now();
    _shown = s;
    notifyListeners();
  }

  /// For the tests: everything forgotten.
  @visibleForTesting
  void reset() {
    _marks.clear();
    _going.clear();
    internet = null;
    internetAt = null;
    internetMs = null;
    _checkedAt = null;
    _checkF = null;
    _probeF = null;
    _probeOn = false;
    _idleN = 0;
    _holdT?.cancel();
    _holdT = null;
    _shown = NetState.checking;
    changedAt = null;
    changedFrom = null;
  }
}

/// Android's own check address (generate_204): its time, or null when neither it nor Google's second check address answers with
/// 204 within 6 s each (3.174.1: one address that fails alone – blocked, its name not found – is not "no internet").
Future<int?> _gstatic() async {
  for (final u in const ['https://connectivitycheck.gstatic.com/generate_204', 'https://www.google.com/generate_204']) {
    final c = http.Client();
    final sw = Stopwatch()..start();
    try {
      final r = await c.get(Uri.parse(u)).timeout(const Duration(seconds: 6));
      if (r.statusCode == 204) return sw.elapsedMilliseconds;
    } catch (_) {
      // the next address
    } finally {
      c.close();
    }
  }
  return null;
}

/// Api's client: each request of one of our servers is measured ([serverOf] names it – '' = not ours: not measured).
class NetClient extends http.BaseClient {
  NetClient(this._inner, this.serverOf, this.limit, {this.limitOf});
  final http.Client _inner;
  final String Function(Uri u) serverOf;
  final Duration limit;

  /// (3.174.1) a request the app itself waits less for (the monitor's own to the Portal: 15 s) – counted as "no answer" then, not
  /// held as "still waiting" until the long limit.
  final Duration? Function(Uri u)? limitOf;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    final f = _inner.send(request);
    final key = serverOf(request.url);
    if (key.isEmpty) return f;
    return NetMonitor.i.watch<http.StreamedResponse>(key, f, limitOf?.call(request.url) ?? limit, status: (r) => r.statusCode);
  }

  @override
  void close() => _inner.close();
}

/// The name of a server in the sheet.
String serverName(String key, String site) => switch (key) {
      'portal' => w3('Portal (sign-in)', 'Portal (साइन-इन)', 'Portal (साइन-इन)'),
      'mech' => site.isEmpty ? 'Mechanical' : '$site – Mechanical',
      'hr' => 'HR',
      'store' => 'Store',
      'eng' => 'Engineering',
      'pur' => 'Purchase',
      _ => key,
    };
