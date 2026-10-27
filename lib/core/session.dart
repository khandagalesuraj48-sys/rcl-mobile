/* THE PERSON ON THIS PHONE: signed in on the Portal or not, his sites (and the modules he has there), the site open, what he
 * may open on it (the same Edit / View / None as on the web – set by the site's Admin) and the site's lists the screens need
 * (machinery, drivers, pumps, locations, stock). Every number comes from Mechanical, as on the web. */
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'alerts.dart';
import 'api.dart';
import 'rtc.dart';
import 'format.dart';
import 'fuel.dart';
import 'lang.dart';
export 'fuel.dart';      // (3.44.0) kFuels, fuelUnit, fuelText – for every screen that has the session

enum Stage { starting, signedOut, setPassword, pickSite, opening, ready, waiting }

class Module {
  Module(this.key, this.name, this.url);
  final String key, name, url;
}

class SiteChoice {
  SiteChoice(this.code, this.name, this.company, this.modules);
  final String code, name, company;
  final List<Module> modules;
  Module? module(String key) {
    for (final m in modules) {
      if (m.key == key) return m;
    }
    return null;
  }
}

/// (3.45.0, Mechanical update-164) "Cash": a fill at a site on fuel cards paid without a card
const kCash = 'Cash';

/// (3.45.0, Mechanical update-164) a fuel card of a site on fuel cards, with its balance now
class FuelCard {
  FuelCard(this.m);
  final Map<String, dynamic> m;
  String get name => '${m['name'] ?? ''}';
  String get last4 => '${m['last4'] ?? ''}';
  String get type => '${m['type'] ?? 'Fuel card'}';
  List<String> get cars => [for (final x in (m['cars'] as List? ?? const [])) '$x'];
  num get opening => m['opening'] is num ? m['opening'] as num : 0;
  String get openDate => '${m['openDate'] ?? ''}';
  bool get active => m['active'] != false;
  num get paid => m['paid'] is num ? m['paid'] as num : 0;
  num get spent => m['spent'] is num ? m['spent'] as num : 0;
  num get balance => m['balance'] is num ? m['balance'] as num : 0;
  String get lastFill => '${m['lastFill'] ?? ''}';
  bool get used => m['used'] == true;
}

class Machine {
  Machine(this.m);
  final Map<String, dynamic> m;
  String get id => (m['id'] ?? '').toString();
  String get name => (m['name'] ?? '').toString();
  String get type => (m['type'] ?? '').toString();
  String get owner => (m['owner'] ?? '').toString();
  String get ownership => (m['ownership'] ?? '').toString();
  String get status => (m['status'] ?? 'Active').toString();
  bool get active => status != 'Inactive';
  /// (15-10-2026, update-115) On the site on [dk] (yyyy-mm-dd): from its "Active From" until the day BEFORE its "Inactive
  /// From" – the same rule as the server's check of an entry. From that date it is not offered where an entry is made.
  /// (3.1.12, Mechanical update-119) A machinery may be on a site several times: its EARLIER periods (it left and came back –
  /// Mechanical's "earlier": [{from, until}], until = the first day away) count too.
  bool onSite(String dk) {
    String d(String k) { final v = '${m[k] ?? ''}'; return v.length >= 10 ? v.substring(0, 10) : v; }
    final af = d('activeFrom'), inf = d('inactiveFrom');
    if (dk.isEmpty) return active;
    for (final p in (m['earlier'] as List? ?? const []).whereType<Map>()) {
      final f = '${p['from'] ?? ''}', u = '${p['until'] ?? ''}';
      if (u.isNotEmpty && (f.isEmpty || f.compareTo(dk) <= 0) && dk.compareTo(u) < 0) return true;
    }
    if (af.isNotEmpty && af.compareTo(dk) > 0) return false;
    if (status == 'Inactive' && (inf.isEmpty || inf.compareTo(dk) <= 0)) return false;
    return true;
  }
  bool get debit => (m['supply'] ?? '') == 'Debit Basis'; // no readings are kept for diesel on Debit Basis
  /// (3.44.0, Mechanical update-163) its fuel – Asset Master → Fuel: Diesel / Petrol / CNG / Electric (none = Diesel)
  String get fuel => kFuels.contains('${m['fuel'] ?? ''}') ? '${m['fuel']}' : 'Diesel';
  List<String> _list(String k) => (m[k] is List) ? (m[k] as List).map((e) => e.toString()).toList() : <String>[];
  String get lbFormat => (m['lbFormat'] ?? 'A').toString();

  /// Its own Log Book format fixes its ways (as the web: LB_FMT_MODES).
  static const fmtModes = {'B': ['KM', 'Hrs', 'KM + Hrs', 'Trip'], 'C': ['KM'], 'D': ['Hrs'], 'E': ['Hrs'], 'F': ['Time'], 'G': ['Time'], 'H': ['Trip'], 'I': ['Trip']};
  List<String> get _base {
    final f = fmtModes[lbFormat];
    if (f != null) return f;
    final md = _list('modes');
    if (md.isNotEmpty) return md;
    final w = _list('worksOn'), o = <String>[];
    if (w.contains('KM')) o.add('KM');
    if (w.contains('Hrs')) o.add('Hrs');
    if (w.contains('KM + Hrs') || (w.contains('KM') && w.contains('Hrs'))) o.add('KM + Hrs');
    for (final x in ['Time', 'Trip', 'Day']) {
      if (w.contains(x)) o.add(x);
    }
    return o;
  }

  /// A machinery on hours may also have a day on Time (its meter gave no reading) – as the web (update-76).
  static List<String> _timeX(List<String> l) => l.any(hasHr) && !l.contains('Time') ? ['Time'] : [];

  /// Every way it may be measured by (Asset Master "Measured by", its format).
  List<String> get modes => [..._base, ..._timeX(_base)];

  /// The ways picked only on a special day (Time: the hour meter gave no reading).
  List<String> get modesX => m['modesX'] is List ? _list('modesX') : _timeX(_base);
  List<String> get modesMain => modes.where((w) => !modesX.contains(w)).toList();

  /// The way picked by itself: when there is only one usual way (as on the web).
  String get wayAuto => modesMain.length == 1 ? modesMain.first : '';

  /// (3.1.9, asked 16-10-2026: "vehicle select kel ki auto tyach km km+hrs trip je kay asel te auto select") THE LOG BOOK: the
  /// way is picked by itself, as on the web – the way of its last entry ([last], from the server), else its Asset Master unit,
  /// else its first way. It can still be changed (Idle, Holiday, Breakdown, a day on Time …).
  String logWay([String last = '']) {
    final main = modesMain, u = '${m['unit'] ?? ''}';
    if (last.isNotEmpty && main.contains(last)) return last;
    if (main.contains(u)) return u;
    return main.isNotEmpty ? main.first : '';
  }

  /// (3.1.8, Mechanical update-116) A DIESEL FILL: KM / Hrs / KM + Hrs by itself from the Asset Master – the readings its meters
  /// give; nothing to pick (only "No reading" when its meter is broken). '' = no meter (no reading).
  String get dieselWay {
    final md = modes, unit = '${m['unit'] ?? ''}';
    if (const ['KM', 'Hrs', 'KM + Hrs'].contains(unit) && md.contains(unit)) return unit;
    final k = md.any(hasKm), h = md.any(hasHr);
    return k && h && md.contains('KM + Hrs') ? 'KM + Hrs' : k ? 'KM' : h ? 'Hrs' : '';
  }
  bool get waterTanker => lbFormat == 'I';
  bool get hasMeter => modes.any((w) => hasKm(w) || hasHr(w));
  num? get tankCap => asNum(m['tankCap']);
  String get label => [id, if (name.isNotEmpty && name != id) name, type].where((s) => s.isNotEmpty).join(' · ');
  bool matches(String q) {
    final words = q.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    final text = [id, name, type, owner, (m['no'] ?? '').toString()].join(' ').toLowerCase();
    final flat = text.replaceAll(RegExp(r'[^a-z0-9]'), '');
    return words.every((w) => text.contains(w) || flat.contains(w.replaceAll(RegExp(r'[^a-z0-9]'), '')));
  }
}

/// "No reading": the meter is not working – a fill without a reading (as on the web: METER_OFF).
const kNoReading = 'No reading';
bool hasKm(String w) => w == 'KM' || w == 'KM + Hrs';
bool hasHr(String w) => w == 'Hrs' || w == 'KM + Hrs';

class Session extends ChangeNotifier {
  Session(this.api, {this.langRead});
  final Api api;

  /// (15-10-2026) how the language files are read (the app's files; the tests give their own)
  final Future<String> Function(String path)? langRead;
  static const kLang = 'app_lang';

  /// The language of the app: his choice (kept with his account, the same at all his sites and on the web); on this phone
  /// the last one is kept, so the sign-in screen is in it too.
  Future<void> _lang(String c) async {
    await Lang.i.set(c, read: langRead);
    await api.keep.write(kLang, Lang.i.code);
  }

  /// (3.31.0) the language picked on the sign-in screen, before he signs in: kept on this phone; his account's choice (My settings)
  /// comes after the sign-in as before.
  Future<void> pickLanguageHere(String c) async {
    await _lang(c);
    notifyListeners();
  }

  /// Settings → App language: '' / 'en' / 'mr' / 'hi' – the help of the web follows it.
  Future<void> setLanguage(String c) => savePrefs({'appLang': c, 'lang': c == 'mr' || c == 'hi' ? c : 'en'});

  Stage stage = Stage.starting;
  String error = '';

  /// (3.37.0) How far the opening is, 0 – 1 – the start screen's bar (screens/splash.dart). Each value is set when that step is
  /// really done: the sign-in kept on this phone read, the sites from the Portal, the site's sign-in, the site's lists.
  double boot = 0;
  void _boot(double v) {
    boot = v;
    notifyListeners();
  }
  String name = '', email = '';
  bool admin = false;
  /// (14-10-2026) the Super Admin (his Portal ticket says so): he changes entries of a submitted bill; others send them for approval.
  bool superAdmin = false;
  Map<String, String> perms = {};
  List<SiteChoice> sites = [];
  SiteChoice? site;
  String siteName = '';

  /// His default site (the Portal's "start": 'mechanical|S1'), '' = none.
  String startItem = '';

  /// His own settings, kept with his account in Mechanical (the web's Settings page): usual shift, usual diesel place, the
  /// usual way of the Log Book entry, text size, mobile number, photo …
  Map<String, dynamic> prefs = {};
  String pref(String k) => '${prefs[k] ?? ''}';

  /// (14-10-2026) Day or Night by the time (the site's hours), as on the web – a new entry starts with it; it can be changed by hand.
  String autoShift([DateTime? at]) {
    int m(String s) { final p = s.split(':'); return (int.tryParse(p[0]) ?? 0) * 60 + (int.tryParse(p.length > 1 ? p[1] : '0') ?? 0); }
    final a = m(dayFrom), b = m(nightFrom), t = at ?? clock(), now = t.hour * 60 + t.minute;
    return (a < b ? now >= a && now < b : now >= a || now < b) ? 'Day' : 'Night';
  }

  /// His own "usual shift" (Settings) when he set one, else [autoShift]; [allowed] = the shifts the form has.
  String myShift(List<String> allowed) {
    final p = pref('shift');
    return allowed.contains(p) ? p : autoShift();
  }
  String get defaultSite => startItem.startsWith('mechanical|') ? startItem.substring(11) : '';

  /// The app's text a little larger (Settings → Size of the text).
  double get textScale => switch (pref('text')) { 'large' => 1.1, 'xlarge' => 1.2, _ => 1.0 };

  // the site's lists (getInit)
  String today = '', company = '', closedUpto = '';
  /// (3.2.0) the site's "Company & site" (web Settings): the customer, the site's name, the names bills are made in
  Map<String, dynamic> org = {};
  /// The name a report / Log Book print is headed with – the company first, then the other bill names (as the web).
  List<String> get printNames {
    final names = (org['billNames'] is List ? (org['billNames'] as List).map((e) => '$e').where((e) => e.isNotEmpty).toList() : <String>[]);
    final cust = '${org['customer'] ?? company}';
    final list = [if (names.contains(cust) || names.isEmpty) cust, ...names.where((n) => n != cust)];
    return list.where((n) => n.isNotEmpty).toList().isEmpty ? ['Rachana Construction Limited'] : list.where((n) => n.isNotEmpty).toList();
  }
  /// The site as printed on every report (web: SITE_NAME).
  String get siteLabel => '${org['site'] ?? ''}'.isNotEmpty ? '${org['site']}' : siteName;
  /// (14-10-2026) the site's shift hours (Settings → Rules of the site on the web): Day from [dayFrom] to [nightFrom], Night the rest.
  String dayFrom = '08:00', nightFrom = '20:00';
  /// (3.9.0) the rules of the site as the server gave them (backDays, announce, dayFrom, nightFrom) – Administration shows them
  Map<String, dynamic> siteRules = {};
  /// The clock (a test sets its own time).
  DateTime Function() clock = DateTime.now;
  List<Machine> machines = [];
  List<String> drivers = [], pumps = [], locations = [];
  /// (3.43.0, Mechanical update-162) the diesel sources the Super Admin gave him (Portal → Users & Access → Pages): {page: places}
  /// – 'Diesel Issue' (its source) and 'Diesel Transfer' (its From). A page not there = every place (as before; an Admin always).
  Map<String, List<String>> dsrc = {};
  /// The places he may give diesel FROM on [page], in the site's order. The server refuses any other, whatever the app sends.
  List<String> mySources(String page) {
    final l = dsrc[page];
    return l == null ? locations : locations.where(l.contains).toList();
  }

  /// Only some places for [page] (then even one is shown, so he sees where the diesel comes from).
  bool ownSources(String page) => dsrc.containsKey(page);
  bool _dsrc(dynamic u) {
    final d = u is Map ? u['dsrc'] : null, was = dsrc.toString();
    dsrc = d is Map ? {for (final e in d.entries) if (e.value is List) '${e.key}': [for (final x in e.value as List) '$x']} : {};
    return dsrc.toString() != was;
  }
  /// (3.44.0, Mechanical update-163) the fuel each diesel place holds (Diesel / Petrol / CNG – Portal → Sites → Diesel places)
  Map<String, String> placeFuels = {};
  String placeFuel(String place) => placeFuels[place] ?? 'Diesel';
  String placeUnit(String place) => fuelUnit(placeFuel(place));
  /// The fuels of this site's places, in their order (one = a site as before: VTR, 18B); (3.45.0) a site on fuel cards: its machinery's
  List<String> get siteFuels {
    if (cardSite && serverFuels.isNotEmpty) return serverFuels;
    final o = <String>[]; for (final l in locations) { final f = placeFuel(l); if (!o.contains(f)) o.add(f); } return o;
  }
  /// (3.45.0, Mechanical update-164) a site on FUEL CARDS (HO – the Super Admin, Portal → Sites → Diesel places): no diesel stock; a
  /// fill is paid by a card or in Cash with its ₹; the cards and their balances come with the stock (getStock / a save's answer)
  String fuelMode = '';
  bool get cardSite => fuelMode == 'card';
  List<String> serverFuels = [];
  List<FuelCard> cards = [];
  FuelCard? card(String name) { final k = name.trim().toUpperCase(); for (final c in cards) { if (c.name.toUpperCase() == k) return c; } return null; }
  /// The cards that may pay for [m] (Active; its cars – none = every car), then Cash
  List<String> payFor(Machine? m) => [for (final c in cards) if (c.active && (c.cars.isEmpty || (m != null && c.cars.any((x) => _nk(x) == _nk(m.id))))) c.name, kCash];
  static String _nk(String v) => v.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  bool get multiFuel => siteFuels.length > 1;
  /// A site with more than one fuel, or a machinery that is not Diesel: the fuel is checked on the phone too
  bool get fuelChecks => multiFuel || machines.any((m) => m.fuel != 'Diesel');
  /// The places a fill of [m] may come from, of [list] – those of its fuel (none of that fuel / Electric: all – the check says why)
  List<String> fuelPlaces(List<String> list, Machine? m) {
    if (m == null || !multiFuel || m.fuel == 'Electric') return list;
    final f = m.fuel, l = list.where((x) => placeFuel(x) == f).toList();
    return l.isEmpty ? list : l;
  }
  /// A fill of [m] from [place]: '' = fine; else what is wrong (the server's words)
  String fuelProblem(Machine? m, String place) {
    if (m == null || !fuelChecks) return '';
    if (m.fuel == 'Electric') return '${m.id} runs on Electric – no fuel is issued to it (Asset Master → Fuel).';
    if (cardSite) return '';      // (3.45.0) a site on fuel cards: paid by a card or Cash – not a place of a fuel
    final pf = placeFuel(place);
    return pf == m.fuel ? '' : '$place holds $pf and ${m.id} runs on ${m.fuel} – pick a ${m.fuel} place (Asset Master → Fuel).';
  }
  /// The To of a transfer from [from]: the places of its fuel
  List<String> transferTos(String from) {
    if (!multiFuel) return locations;
    final f = placeFuel(from);
    return locations.where((l) => placeFuel(l) == f).toList();
  }
  num? stockTotal;
  Map<String, num> stockByLoc = {};

  /// May open the page (View or Edit) – as canSee on the web.
  bool canSee(String module) => admin || perms[module] == 'Edit' || perms[module] == 'View';

  /// May add / change (Edit) – as canEdit on the web.
  bool canEdit(String module) => admin || perms[module] == 'Edit';

  /// He has this module of the Portal on the site open (the Store …).
  bool hasModule(String key) => site?.module(key) != null;

  Machine? machine(String id) {
    final k = id.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    for (final m in machines) {
      if (m.id.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '') == k) return m;
    }
    return null;
  }

  void _go(Stage s, [String err = '']) {
    if (s != Stage.waiting) _again?.cancel();
    final was = stage;
    stage = s;
    error = err;
    notifyListeners();
    // (3.42.0) at a site: this phone is given for the notifications (core/push.dart – once a day; the app is not kept waiting)
    final f = onReady;
    if (s == Stage.ready && was != Stage.ready && f != null) unawaited(f(this).catchError((Object _) {}));
  }

  /// (3.42.0) the app's notifications through Firebase (main.dart sets these on the phone; none in the tests unless a test sets them):
  /// at a site – the phone is given; signing out – taken off first (while the sign-in still works).
  static Future<void> Function(Session s)? onReady;
  static Future<void> Function(Session s)? onSignOut;

  /* (3.20.1, asked 18-10-2026: "app madhun pn auto log out nko aahe") The sign-in kept on this phone could not be checked, or the
   * site could not be opened, because there is NO NETWORK or the server did not answer: the person is NOT signed out. Before,
   * he was shown the sign-in (his kept sign-in stayed, but it looked like a log-out). Now the app waits – Stage.waiting: "No
   * connection – you are still signed in" – and tries again by itself every [retryEvery], or at once with "Try again". Only the
   * Portal saying it does not know him any more (and his own Sign out) shows the sign-in. */
  static bool notReached(ApiError e) => e.noConnection || e.status == 502 || e.status == 503 || e.status == 504; // no network / the server not reached now
  Duration retryEvery = const Duration(seconds: 10);
  Timer? _again;
  Future<void> Function()? _retry;
  bool retrying = false;
  void _wait(String msg, Future<void> Function() again) {
    _retry = again;
    retrying = false;
    _go(Stage.waiting, msg);
    _again?.cancel();
    _again = Timer(retryEvery, () {
      if (stage == Stage.waiting) tryAgain();
    });
  }

  /// "Try again" on the waiting screen (and the timer): the same step again – the kept sign-in, or opening the site.
  Future<void> tryAgain() async {
    final f = _retry;
    if (f == null || stage != Stage.waiting || retrying) return;
    _again?.cancel();
    retrying = true;
    notifyListeners();
    try {
      await f();
    } finally {
      retrying = false;
      if (stage == Stage.waiting) notifyListeners();
    }
  }

  @override
  void dispose() {
    _again?.cancel();
    super.dispose();
  }

  /// The app opens: the sign-in kept on this phone is used – nothing to type while the Portal still knows the person.
  Future<void> start() async {
    boot = .05;
    await api.load();
    // (3.39.0, asked 25-10-2026: "app opening slow zal aahe … ultra fast") with the sign-in kept on this phone, the Portal ("is he
    // still signed in, which sites") and the kept site's first lists (getInit) are asked AT THE SAME TIME – one wait, not two – and
    // the language is read meanwhile. Nothing of the site's answer is used before the Portal says he is still signed in and still
    // has that site at that address; otherwise it is dropped (and asked the normal way).
    final meF = api.hasPortal ? _quiet(api.auth({'action': 'me'})) : null;
    _keptMech = await api.keep.read(kMechUrl) ?? '';
    final keptSite = api.site ?? '';
    Future<dynamic>? early;
    if (meF != null && (api.token ?? '').isNotEmpty && keptSite.isNotEmpty && _keptMech.startsWith('https://')) {
      api.mechUrl = _keptMech;
      early = _quiet(api.callOnce('getInit'));
    }
    await Lang.i.set(await api.keep.read(kLang) ?? '', read: langRead);
    if (!api.hasPortal) return _go(Stage.signedOut);
    _boot(.15);
    try {
      await _loadSites(meF);
      _boot(.4);
      final kept = api.site ?? '';
      if (sites.any((x) => x.code == kept)) {
        final at = sites.firstWhere((x) => x.code == kept).module('mechanical')?.url ?? '';
        await chooseSite(kept, early: kept == keptSite && at == _keptMech ? early : null);
      } else if (sites.length == 1) {
        await chooseSite(sites.first.code);
      } else {
        _go(Stage.pickSite);
      }
    } on ApiError catch (e) {
      if (e.code == 'mustchange') return _go(Stage.setPassword);
      if (e.needsSignIn || e.status == 401) {
        await api.forget();
        return _go(Stage.signedOut);
      }
      if (notReached(e)) return _wait(e.toString(), start); // (3.20.1) no network: still signed in – it tries again
      _go(Stage.signedOut, e.toString());
    }
  }

  /// [meF]: the Portal's answer already asked (Session.start).
  Future<void> _loadSites([Future<Map<String, dynamic>>? meF]) async {
    final me = await (meF ?? api.auth({'action': 'me'}));
    if (me['signedIn'] != true) throw ApiError('Please sign in.', code: 'signin');
    // (15-10-2026) still on the password the Super Admin gave: he sets his own first (here in the app)
    if (me['mustChange'] == true) throw ApiError('Set your own password first.', code: 'mustchange');
    final u = (me['user'] as Map?)?.cast<String, dynamic>() ?? {};
    // (14-10-2026) the Super Admin opens every module of every site too (the Portal lists them all for him, as Admin)
    final by = <String, SiteChoice>{};
    for (final x in (me['items'] as List? ?? []).whereType<Map>()) {
      final code = (x['site'] ?? '').toString(), url = (x['url'] ?? '').toString().replaceAll(RegExp(r'/+$'), '');
      if (code.isEmpty || !url.startsWith('https://')) continue;
      by.putIfAbsent(code, () => SiteChoice(code, (x['siteName'] ?? code).toString(), (x['company'] ?? '').toString(), [])).modules.add(Module((x['module'] ?? '').toString(), (x['moduleName'] ?? '').toString(), url));
    }
    // the app works through Mechanical: a site without it cannot be opened here
    sites = by.values.where((s) => s.module('mechanical') != null).toList();
    if (sites.isEmpty) throw ApiError('You have no site with Mechanical yet – ask the Super Admin.', code: 'nosite');
    name = (u['name'] ?? '').toString();
    email = (u['email'] ?? '').toString();
    startItem = (me['start'] ?? '').toString();
  }

  /// Email + password of the Portal (one password for every module).
  Future<void> signIn(String mail, String password) async {
    error = '';
    try {
      final r = await api.auth({'action': 'login', 'email': mail.trim(), 'password': password});
      // (15-10-2026) a new user, or a one-time password of the Super Admin: he sets his own password here in the app
      if (r['mustChange'] == true) return _go(Stage.setPassword);
      freshSignIn?.call(); // (3.27.0) the password typed just now: the app lock does not ask again
      await _afterSignIn();
    } on ApiError catch (e) {
      _go(Stage.signedOut, e.toString());
    }
  }

  /// (3.27.0) A sign-in typed just now (the app lock – applock.dart – then does not ask the fingerprint again).
  void Function()? freshSignIn;

  Future<void> _afterSignIn() async {
    await _loadSites();
    final def = defaultSite;
    if (def.isNotEmpty && sites.any((x) => x.code == def)) {
      await chooseSite(def); // his default site opens at once (Settings)
    } else if (sites.length == 1) {
      await chooseSite(sites.first.code);
    } else {
      _go(Stage.pickSite);
    }
  }

  /// (15-10-2026) The first sign-in with the password the Super Admin gave (or a one-time password): his own password is set
  /// here – [given] is the password he was given. The Portal checks it and its rules; then the app opens as after a sign-in.
  Future<void> setOwnPassword(String given, String now) async {
    error = '';
    try {
      await api.auth({'action': 'changePassword', 'old': given, 'password': now});
    } on ApiError catch (e) {
      if (e.needsSignIn || e.status == 401) {
        await api.forget();
        return _go(Stage.signedOut, 'Please sign in again with the password you were given.');
      }
      return _go(Stage.setPassword, e.toString());
    }
    freshSignIn?.call(); // (3.27.0) his own password set just now: not asked again
    try {
      await _afterSignIn();
    } on ApiError catch (e) {
      _go(Stage.signedOut, e.toString());
    }
  }

  /// Back to the sign-in (the password is not set now).
  Future<void> leaveSetPassword() async {
    await api.signOut();
    _go(Stage.signedOut);
  }

  /// Opens a site: Mechanical's sign-in (a kept one, else a new ticket), the person's access and the site's lists.
  /// The kept address of the site's Mechanical (written only when it changes).
  String _keptMech = '';

  /// (3.39.0) A future asked ahead whose fault is taken up later (where it is awaited) – never an "unhandled" error meanwhile.
  static Future<T> _quiet<T>(Future<T> f) {
    f.then<void>((_) {}, onError: (Object _) {});
    return f;
  }

  /// [early]: the site's first lists already asked (Session.start) – used when they came; else they are asked here.
  Future<void> chooseSite(String code, {Future<dynamic>? early}) async {
    final s = sites.firstWhere((x) => x.code == code);
    if (site?.code != code) clearMemory(); // (update-155) another site: nothing the screens kept of the one before
    site = s;
    siteName = s.name;
    api.mechUrl = s.module('mechanical')!.url;
    await api.keepSite(code);
    boot = .5; // (3.37.0) signed in, his sites known: the site is opened now
    _go(Stage.opening);
    try {
      if ((api.token ?? '').isEmpty) _user(await api.openSite(code));
      if (_keptMech != api.mechUrl) {
        await api.keep.write(kMechUrl, api.mechUrl);      // (3.1.8) for the notifications with the app closed
        _keptMech = api.mechUrl;
      }
      _boot(.7);
      await loadInit(early);
      versions = {};
      boot = 1;
      _go(Stage.ready);
      prefsReady = loadPrefs(); // his settings – the screens use them as soon as they come
      await loadKept();
    } on ApiError catch (e) {
      if (e.needsSignIn) {
        await api.forget();
        return _go(Stage.signedOut, 'Your sign-in has ended – please sign in again.');
      }
      if (notReached(e)) return _wait(e.toString(), () => chooseSite(code)); // (3.20.1) no network: still signed in
      _go(sites.length > 1 ? Stage.pickSite : Stage.signedOut, e.toString());
    }
  }

  void _user(Map<String, dynamic> r) {
    final u = (r['user'] as Map?)?.cast<String, dynamic>();
    if (u == null) return;
    if ((u['name'] ?? '').toString().isNotEmpty) name = u['name'].toString();
    email = (u['email'] ?? email).toString();
    admin = u['admin'] == true;
    superAdmin = u['super'] == true;
    final p = u['perms'];
    perms = p is Map ? p.map((k, v) => MapEntry(k.toString(), v.toString())) : {};
    _dsrc(u);
    if ((r['siteName'] ?? '').toString().isNotEmpty) siteName = r['siteName'].toString();
  }

  /// [early]: getInit already asked (Session.start); if it failed, it is asked again the normal way.
  Future<void> loadInit([Future<dynamic>? early]) async {
    dynamic got;
    if (early != null) {
      try {
        got = await early;
      } catch (_) {
        got = null; // (an ended sign-in, no network …: the normal call below renews, tries again and says what is wrong)
      }
    }
    final d = ((got is Map ? got : await api.call('getInit')) as Map).cast<String, dynamic>();
    final u = d['user'];
    if (u is Map) _user({'user': u});
    today = (d['today'] ?? '').toString();
    company = (d['company'] ?? '').toString();
    org = (d['org'] is Map) ? (d['org'] as Map).cast<String, dynamic>() : <String, dynamic>{};
    closedUpto = (d['closedUpto'] ?? '').toString();
    final rules = d['rules'];
    if (rules is Map) {
      siteRules = rules.cast<String, dynamic>();
      dayFrom = RegExp(r'^\d{2}:\d{2}$').hasMatch('${rules['dayFrom']}') ? '${rules['dayFrom']}' : '08:00';
      nightFrom = RegExp(r'^\d{2}:\d{2}$').hasMatch('${rules['nightFrom']}') ? '${rules['nightFrom']}' : '20:00';
    }
    machines = (d['master'] as List? ?? []).whereType<Map>().map((m) => Machine(m.cast<String, dynamic>())).toList();
    drivers = (d['drivers'] as List? ?? []).map((e) => e.toString()).toList();
    pumps = (d['pumps'] as List? ?? []).map((e) => e.toString()).toList();
    locations = (d['locations'] as List? ?? []).map((e) => e.toString()).toList();
    placeFuels = d['placeFuels'] is Map ? {for (final e in (d['placeFuels'] as Map).entries) '${e.key}': '${e.value}'} : {};      // (3.44.0)
    fuelMode = '${d['fuelMode'] ?? ''}';      // (3.45.0) a site on fuel cards
    serverFuels = d['siteFuels'] is List ? [for (final f in d['siteFuels'] as List) '$f'] : [];
    aiOn = d['ai'] is Map && (d['ai'] as Map)['on'] == true;
    _flow(d['flow']);
    _admin(d);
    setStock(d['stock']);
  }

  /// (3.14.0) A fault of the app's own code (an exception) is sent to the server – the Admin's "Faults of the app" lists it, as the
  /// web reports a fault of its page (reportError). The same fault once in 10 minutes, at most 12 in a run; only when signed in.
  final _faultSeen = <String, DateTime>{};
  int _faultSent = 0;
  void reportFault(String msg, String detail) {
    final m = msg.length > 300 ? msg.substring(0, 300) : msg;
    if (m.trim().isEmpty || stage != Stage.ready || (api.token ?? '').isEmpty) return;
    if (RegExp(r'SESSION_EXPIRED|No connection|SocketException|ClientException|HandshakeException|TimeoutException').hasMatch(m)) return;
    final now = DateTime.now(), was = _faultSeen[m];
    if (was != null && now.difference(was).inMinutes < 10) return;
    _faultSeen[m] = now;
    if (++_faultSent > 12) return;
    api.call('reportError', [{'where': 'phone app', 'msg': m, 'detail': detail.length > 1500 ? detail.substring(0, 1500) : detail}]).catchError((_) => null);
  }

  /// (3.14.0) For the Admin: the Google Sheet backup's state and today's faults of the app (getInit / the live sync).
  Map<String, dynamic> backup = {}, faults = {};
  void _admin(Map d) {
    if (d['backup'] is Map) backup = (d['backup'] as Map).cast<String, dynamic>();
    if (d['faults'] is Map) faults = (d['faults'] as Map).cast<String, dynamic>();
  }

  /// (3.4.0) The machinery list the server sent back after a change in Asset Master (saveMaster … : "master") – every screen
  /// of the app has it at once, as the web's setMaster.
  void setMaster(dynamic list) {
    if (list is! List) return;
    machines = list.whereType<Map>().map((m) => Machine(m.cast<String, dynamic>())).toList()..sort((a, b) => a.id.compareTo(b.id));
    lastChanged = {'master'};
    dataTick.value++;
    notifyListeners();
  }

  /// (3.45.0) the cards as the server sent them (with the stock, a save of a card / a payment, the dashboard)
  void setCards(dynamic l) {
    if (l is! List) return;
    cards = [for (final x in l.whereType<Map>()) FuelCard(x.cast<String, dynamic>())];
  }

  void setStock(dynamic s) {
    if (s is! Map) return;
    final t = s['stock'];
    if (t is num) stockTotal = t;
    final by = s['byLoc'];
    if (by is Map) stockByLoc = by.map((k, v) => MapEntry(k.toString(), (v is num) ? v : 0));
    setCards(s['cards']);      // (3.45.0) a site on fuel cards: the cards' balances
    notifyListeners();
  }

  /// (3.14.0) His settings have come (the start page waits for them); his last sign-ins (Settings shows them).
  Future<void>? prefsReady;
  List<String> logins = [];

  /// (3.15.0) The AI service is set up on the server (getInit → ai.on): a typed question can go to it.
  bool aiOn = false;

  /// (3.15.0) The daily summary waits on the Ask button (a red dot) – once a day, as the web's aiBriefAuto on a phone.
  final ValueNotifier<bool> briefDue = ValueNotifier<bool>(false);

  /// Once a day (kept on this phone for him), unless his settings say no ("brief": false): the summary waits on the Ask button.
  Future<void> checkBrief() async {
    if (prefs['brief'] == false || email.isEmpty || today.isEmpty) return;
    final k = 'oc_brief_${email.toLowerCase()}';
    try {
      if (await api.keep.read(k) == today) return;
      await api.keep.write(k, today);
    } catch (_) {
      return;
    }
    briefDue.value = true;
  }

  Future<void> loadPrefs() async {
    try {
      final r = (await api.call('getMyPrefs') as Map).cast<String, dynamic>();
      prefs = ((r['prefs'] as Map?) ?? {}).cast<String, dynamic>();
      logins = [for (final x in (r['logins'] as List? ?? const [])) '$x'];
      if (r['rules'] is Map) siteRules = (r['rules'] as Map).cast<String, dynamic>(); // the notice of the site on Home
      if (prefs.containsKey('appLang')) await _lang('${prefs['appLang']}');
      notifyListeners();
    } catch (_) {/* the app works with the usual settings */}
  }

  /// Saves some of his settings (only the ones given change).
  Future<void> savePrefs(Map<String, dynamic> x) async {
    final r = (await api.call('saveMyPrefs', [x], true) as Map).cast<String, dynamic>();
    prefs = ((r['prefs'] as Map?) ?? prefs).cast<String, dynamic>();
    if (prefs.containsKey('appLang')) await _lang('${prefs['appLang']}');
    notifyListeners();
  }

  /// His default site – it opens straight after the sign-in ('' = ask / the last one).
  Future<void> setDefaultSite(String code) async {
    final r = await api.auth({'action': 'setStart', 'module': code.isEmpty ? '' : 'mechanical', 'site': code});
    startItem = (r['start'] ?? '').toString();
    notifyListeners();
  }

  /// His password (the Portal's – one password for every module). The Portal ends his other sign-ins.
  Future<void> changePassword(String old, String now) async {
    await api.auth({'action': 'changePassword', 'old': old, 'password': now});
  }

  /// A page of the web ERP opened inside the app (a module not yet made for the phone): its address, signed in with a fresh
  /// ticket – the web opens straight on that page.
  Future<String> webUrl(String page) async {
    final s = site!, m = s.module('mechanical')!;
    try {
      final t = await api.ticket(s.code);
      return '${m.url}/#sso=$t${page.isEmpty ? '' : '&page=${Uri.encodeComponent(page)}'}';
    } on ApiError catch (e) {
      if (e.needsSignIn) {
        await api.forget();
        _go(Stage.signedOut, 'Your sign-in has ended – please sign in again.');
      }
      rethrow;
    }
  }

  /// Another site opened from inside the web ("Change site"): it opens next time (the screen is not rebuilt).
  Future<void> rememberSite(String code) async {
    if (!sites.any((x) => x.code == code) || site?.code == code) return;
    await api.keepSite(code);
  }

  /* ---------------- LIVE (3.1.7, asked 15-10-2026: "app madhe live sync haway, app refresh kraychi kahich garaj nahi") ----------------
   * While the app is on the screen it asks Mechanical what changed (the same light "sync" as the web page). When the machinery,
   * the stock, the Log Book or the diesel entries change – also by another person, on the web or another phone – the screens
   * load again by themselves ([dataTick]); a verification request ("flow") updates the Approvals count. In the background nothing
   * is asked; coming back asks at once.
   * (update-155 of Mechanical, asked 24-10-2026: "User A ने Data Save केला की User B ला सक्रिय Screen वर शक्यतो 2 सेकंदांत Update
   * दिसला पाहिजे … Web, Android, iPhone आणि Windows") – the same rhythm as the web page (was every 15 seconds): Home and Entries
   * (the screens that show others' entries) every 2 seconds, Reports and Me every 5, after 5 minutes without a touch every 15;
   * the first touch after a quiet spell asks at once. Each answer is "the same" in a few bytes when nothing changed (answers.dart). */
  Map<String, String> versions = {};
  final ValueNotifier<int> dataTick = ValueNotifier<int>(0);
  Set<String> lastChanged = {};
  Timer? _live;
  bool _ticking = false, _liveOn = false;
  static const liveEvery = Duration(seconds: 15), liveFast = Duration(seconds: 2), liveOther = Duration(seconds: 5);
  static const liveTabs = {'home', 'entries'};

  /// the tab on the screen (set by the shell)
  String screen = 'home';
  DateTime _touched = DateTime.now();

  /// how long until the next "what changed?"
  Duration liveGap() {
    if (DateTime.now().difference(_touched) > const Duration(minutes: 5)) return liveEvery;
    return liveTabs.contains(screen) ? liveFast : liveOther;
  }

  /// a touch of the screen (main.dart): the quick rhythm stays; the first touch after a quiet spell asks at once
  void touch() {
    final quiet = DateTime.now().difference(_touched) > const Duration(seconds: 30);
    _touched = DateTime.now();
    if (quiet && _liveOn) _liveLoop();
  }

  /// another tab: a live one asks at once
  void showing(String tab) {
    if (tab == screen) return;
    screen = tab;
    if (_liveOn && liveTabs.contains(tab)) _liveLoop();
  }

  void _liveNext() {
    _live?.cancel();
    _live = _liveOn ? Timer(liveGap(), _liveLoop) : null;
  }

  Future<void> _liveLoop() async {
    _live?.cancel();
    await liveTick();
    _liveNext();
  }

  void startLive() {
    _liveOn = true;
    _touched = DateTime.now();
    _rtcOn();
    _liveLoop();
  }

  /* (3.26.0) CALLS with the web (lib/core/rtc.dart): the phone's media come from [callKit] (main.dart gives flutter_webrtc on Android;
   * the tests give a pretend one; none = no calls here). The notes of a call come with this same heartbeat ({r} – as the web's). */
  static RtcKit Function()? callKit;
  Rtc? rtc;
  void _rtcOn() {
    if (rtc != null || callKit == null || stage != Stage.ready) return;
    rtc = Rtc((fn, args) => api.call(fn, args), callKit!(), onBeat: liveTick);
    notifyListeners();
  }

  /// Another site / signed out: a call ends, nothing rings any more.
  void rtcOff() {
    final r = rtc;
    if (r == null) return;
    rtc = null;
    r.close();
  }

  void stopLive() {
    _liveOn = false;
    _live?.cancel();
    _live = null;
  }

  /* (update-155) WHAT THE SCREENS KEEP IN MEMORY (a day's list, the pending list …) is emptied at sign-out and at another site, with
   * the server answers kept by the Api (answers.dart): a screen registers its own clean-up here the first time it keeps something. */
  static final memoryClears = <void Function()>{};
  void clearMemory() {
    for (final f in memoryClears.toList()) {
      try {
        f();
      } catch (_) {/* the others are still emptied */}
    }
    api.answers.clear();
  }

  /// (update-155) the app is open and asking (kept on the phone at most once a minute): the Android alarm does not ask then
  DateTime _liveMark = DateTime.fromMillisecondsSinceEpoch(0);
  Future<void> _markLive() async {
    if (DateTime.now().difference(_liveMark) < const Duration(minutes: 1)) return;
    _liveMark = DateTime.now();
    try {
      await api.keep.write(kLiveAt, '${_liveMark.millisecondsSinceEpoch}');
    } catch (_) {/* the alarm asks as before */}
  }

  Future<void> liveTick() async {
    if (stage != Stage.ready || _ticking) return;
    _ticking = true;
    try {
      final r = await api.call('sync', [rtc?.beatArg() ?? <String, dynamic>{}]);
      unawaited(_markLive());
      if (r is Map && r['rtc'] != null) rtc?.inbox(r['rtc']); // (3.26.0) the notes of a call
      if (r is Map) _admin(r);
      final dsNew = r is Map && r['user'] is Map && _dsrc(r['user']); // (3.43.0) his diesel sources changed in the Portal: the forms at once
      final v = (r is Map && r['versions'] is Map) ? (r['versions'] as Map).map((k, x) => MapEntry('$k', '$x')) : <String, String>{};
      final first = versions.isEmpty;
      final changed = first ? <String>{} : v.keys.where((k) => versions[k] != v[k]).toSet();
      versions = v;
      if (first) {
        await loadApprovals();
      } else if (changed.isNotEmpty) {
        if (changed.contains('master')) {
          await loadInit();
        } else if (changed.contains('stock')) {
          try {
            setStock(await api.call('getStock'));
          } catch (_) {/* the stock only */}
        }
        if (changed.contains('flow')) await loadApprovals();
        lastChanged = changed;
        dataTick.value++;
        notifyListeners();
      } else if (dsNew) {
        notifyListeners();
      }
      // (3.1.8) an entry sent back to him: asked again every 10 minutes (its notification every 30 – alerts.dart)
      if (crBack > 0 && DateTime.now().difference(_apprAt).inMinutes >= 10) await loadApprovals();
      await sendKept();
    } catch (_) {/* the next tick tries again */} finally {
      _ticking = false;
    }
  }

  /// (update-114) Approvals: [crWaiting] = waiting in his list (what he sent, what waits for him); [crForMe] = for him to decide.
  int crWaiting = 0, crForMe = 0, crBack = 0;

  /// (3.1.8) notifications on the phone (the tests switch them off)
  bool notify = true;

  /// (3.1.8, update-116) his works under verification (Mechanical's getInit "flow" / Approvals "mine"): {page: {daysBack, qtyAbove, to}}
  Map<String, Map<String, dynamic>> flowMine = {};
  void _flow(dynamic f) {
    if (f is! Map) return;
    flowMine = f.map((k, v) => MapEntry('$k', v is Map ? v.cast<String, dynamic>() : <String, dynamic>{}));
  }

  /// Does a save of [module] (dated [dates], [qty] litres) go to verification? Then its button says "Send to verification".
  bool flowWill(String module, {List<String> dates = const [], num qty = 0}) {
    final r = flowMine[module];
    if (r == null) return false;
    final db = num.tryParse('${r['daysBack'] ?? ''}'), qa = num.tryParse('${r['qtyAbove'] ?? ''}');
    if (db == null && qa == null) return true;
    if (db != null) {
      final t = today.isNotEmpty ? DateTime.tryParse(today) ?? clock() : clock();
      final lim = t.subtract(Duration(days: db.toInt()));
      final limKey = '${lim.year.toString().padLeft(4, '0')}-${lim.month.toString().padLeft(2, '0')}-${lim.day.toString().padLeft(2, '0')}';
      if (dates.any((d) => d.length == 10 && d.compareTo(limKey) < 0)) return true;
    }
    return qa != null && qty > qa;
  }
  String flowTo(String module) => ((flowMine[module]?['to'] as List?) ?? const []).join(', ');
  DateTime _apprAt = DateTime.fromMillisecondsSinceEpoch(0);
  Future<void> loadApprovals() async {
    _apprAt = DateTime.now();
    try {
      final d = await api.call('getChangeRequests', [<String, dynamic>{}]);
      if (d is! Map) return;
      takeApprovals(d);
      if (notify) await tellAlerts(d, api.keep);      // (3.1.8) waiting for him / sent back to him: a notification; (3.1.11) a reminder
    } catch (_) {/* the count only */}
  }

  /// (3.2.0) The Approvals answer [d] taken: the counts, his works under verification, his entries (the Approvals screen gives
  /// every answer of a decision here too).
  void takeApprovals(Map d) {
    crWaiting = (d['pending'] is num) ? (d['pending'] as num).toInt() : 0;
    crForMe = (d['forMe'] is num) ? (d['forMe'] as num).toInt() : 0;
    crBack = (d['backToMe'] is num) ? (d['backToMe'] as num).toInt() : 0;
    _flow(d['mine']);
    crMine = mineOf(d);
    notifyListeners();
  }

  /* (3.1.11, Mechanical update-118, asked 16-10-2026: "jyan verification sathi pathwale aahe to pn direct entry wise or all send
   * reminder dable ki … approval krnar aahe tyala samjel patkan") HIS ENTRIES IN VERIFICATION – the ones he sent (Mechanical's
   * Approvals list): Home and the entry forms show them – waiting (at whom), sent back, approved, not saved – and "Remind" tells the
   * approver now (one entry, or all that wait). The same entry once in 5 minutes (Mechanical says when). */
  List<Map<String, dynamic>> crMine = [];

  /// His entries of the Approvals answer [d]: waiting and sent back always, the decided ones of the last [days] days.
  static List<Map<String, dynamic>> mineOf(Map d, {int days = 7, DateTime? now}) {
    final since = (now ?? DateTime.now()).subtract(Duration(days: days));
    return (d['requests'] as List? ?? []).whereType<Map>().map((r) => r.cast<String, dynamic>()).where((r) {
      if (r['kind'] != 'Flow' || r['mine'] != true) return false;
      final st = '${r['status'] ?? ''}';
      if (st == 'Pending' || st == 'Reverted') return true;
      final at = DateTime.tryParse('${r['decidedAt'] ?? ''}') ?? DateTime.tryParse('${r['at'] ?? ''}');
      return at != null && at.isAfter(since);
    }).toList();
  }

  /// His entries of one page ([module] = Mechanical's page, e.g. "Diesel Issue"); all pages when empty.
  List<Map<String, dynamic>> mineFor(String module, {int days = 7}) {
    final since = DateTime.now().subtract(Duration(days: days));
    return crMine.where((r) {
      if (module.isNotEmpty && r['m'] != module) return false;
      final st = '${r['status'] ?? ''}';
      if (st == 'Pending' || st == 'Reverted') return true;
      final at = DateTime.tryParse('${r['decidedAt'] ?? ''}') ?? DateTime.tryParse('${r['at'] ?? ''}');
      return at != null && at.isAfter(since);
    }).toList();
  }

  /// "Remind": the approver of each entry is told now. Returns Mechanical's answer (reminded, later: [{id, at, next}]).
  Future<Map<String, dynamic>> remindFlow({List<String> ids = const [], bool all = false}) async {
    final r = await api.call('remindFlow', [all ? <String, dynamic>{'all': true} : <String, dynamic>{'ids': ids}]);
    final m = r is Map ? r.cast<String, dynamic>() : <String, dynamic>{};
    if (m['list'] is Map) takeApprovals(m['list'] as Map);
    return m;
  }

  /// (3.21.1, Mechanical update-128) "Send again": his rejected / returned entries go to verification again exactly as they were sent
  /// (the same lines and photos), with his remark – nothing typed again. Mechanical checks each as a save first; one that would be
  /// refused again is told and stays as it is. Returns Mechanical's answer (done: [{id, level, levels}], failed: [{id, error, warn}]).
  /// (Mechanical update-131) no "anyway": what the save refuses is corrected first.
  Future<Map<String, dynamic>> resendFlow(List<String> ids, String note) async {
    final r = await api.call('resendFlow', [ids.length == 1 ? <String, dynamic>{'id': ids.first, 'note': note} : <String, dynamic>{'ids': ids, 'note': note}], true);
    final m = r is Map ? r.cast<String, dynamic>() : <String, dynamic>{};
    if (m['list'] is Map) takeApprovals(m['list'] as Map);
    return m;
  }

  /// (3.22.0, Mechanical update-130) "Open & correct": his rejected / returned entry as it was sent, the form it opens in, and what
  /// the save says of it now ({id, fn, form, args, status, result, decidedBy, note, check}).
  Future<Map<String, dynamic>> openFlow(String id) async {
    final r = await api.call('openFlow', [<String, dynamic>{'id': id}]);
    return r is Map ? r.cast<String, dynamic>() : <String, dynamic>{};
  }

  /// …corrected: Mechanical checks it as a save – its own answer when it refuses (errors / warnings / warning: nothing sent), else
  /// sent again, corrected ({ok, id, level, levels, changes, list}).
  Future<Map<String, dynamic>> editFlow(String id, String note, List<Object?> args) async {
    final r = await api.call('editFlow', [<String, dynamic>{'id': id, 'note': note, 'args': args}], true);
    final m = r is Map ? r.cast<String, dynamic>() : <String, dynamic>{};
    if (m['list'] is Map) takeApprovals(m['list'] as Map);
    return m;
  }

  /* ---------------- KEPT ON THIS PHONE (3.1.7): an entry saved with no network ----------------
   * The person may keep it on the phone; it is sent by itself when the network is back (every live tick, and when the app comes
   * back), with the SAME save number – the server saves it once, also when the first try had reached it. What the server then
   * refuses stays here with its words ("Waiting on this phone" in Me) until he deletes it; nothing is ever changed by the app. */
  List<Map<String, dynamic>> kept = [];
  /// Kept entries of the site open that the server did not save (they wait for the person).
  int get keptBad => kept.where((x) => x['state'] == 'refused' && x['site'] == (site?.code ?? '')).length;
  String get _keptKey => 'kept_${email.toLowerCase()}';
  bool _sending = false;
  /// Something the person should hear about the kept entries (the screen shows it once).
  final ValueNotifier<String> keptNote = ValueNotifier<String>('');

  Future<void> loadKept() async {
    try {
      final j = jsonDecode(await api.keep.read(_keptKey) ?? '[]');
      kept = j is List ? j.whereType<Map>().map((m) => m.cast<String, dynamic>()).toList() : [];
    } catch (_) {
      kept = [];
    }
    notifyListeners();
  }

  Future<void> _saveKept() async {
    await api.keep.write(_keptKey, kept.isEmpty ? null : jsonEncode(kept));
    notifyListeners();
  }

  /// Keeps a save that got no answer ([rid] = its number) to send it later.
  Future<void> keepEntry(String fn, List<dynamic> args, String rid, String label) async {
    kept.add({'rid': rid, 'fn': fn, 'args': args, 'label': label, 'site': site?.code ?? '', 'at': DateTime.now().toIso8601String(), 'state': 'waiting', 'msg': ''});
    await _saveKept();
  }

  Future<void> dropKept(String rid) async {
    kept.removeWhere((x) => x['rid'] == rid);
    await _saveKept();
  }

  /// Sends what is kept for the site open (in the order kept); stops at the first "no network".
  Future<void> sendKept({bool again = false}) async {
    if (_sending || stage != Stage.ready) return;
    final mine = kept.where((x) => x['site'] == (site?.code ?? '') && (x['state'] == 'waiting' || (again && x['state'] == 'refused'))).toList();
    if (mine.isEmpty) return;
    _sending = true;
    var sent = 0;
    try {
      for (final x in mine) {
        try {
          final r = await api.call('${x['fn']}', (x['args'] as List?) ?? const [], true, '${x['rid']}');
          if (r is Map && (r['ok'] == false || (r['errors'] is List && (r['errors'] as List).isNotEmpty))) {
            final errs = (r['errors'] as List? ?? []).map((e) => e is Map ? '${e['msg'] ?? ''}' : '$e').where((e) => e.isNotEmpty).toList();
            x['state'] = 'refused';
            x['msg'] = errs.isEmpty ? '${r['error'] ?? r['warning'] ?? 'Not saved.'}' : errs.join(' | ');
          } else {
            kept.removeWhere((y) => y['rid'] == x['rid']);
            sent++;
          }
        } on ApiError catch (e) {
          if (e.noConnection) break;
          if (e.code == 'sent') {
            kept.removeWhere((y) => y['rid'] == x['rid']);
            sent++;
            keptNote.value = e.message;
            continue;
          }
          x['state'] = 'refused';
          x['msg'] = e.toString();
        }
      }
    } finally {
      _sending = false;
      await _saveKept();
    }
    if (sent > 0) {
      keptNote.value = bi('Entries kept on this phone sent: $sent', 'फोनवर ठेवलेल्या एन्ट्री पाठवल्या: $sent');
      dataTick.value++;
    }
    if (kept.any((x) => x['state'] == 'refused' && x['site'] == (site?.code ?? ''))) keptNote.value = bi('An entry kept on this phone was not saved – see Me → Waiting on this phone.', 'फोनवर ठेवलेली एक एन्ट्री सेव्ह झाली नाही – Me पहा.');
  }

  /// Back to the list of sites (another site).
  void pickAnotherSite() {
    if (sites.length > 1) _go(Stage.pickSite);
  }

  Future<void> signOut([String msg = '']) async {
    final off = onSignOut;
    if (off != null) {
      try {
        await off(this).timeout(const Duration(seconds: 4));
      } catch (_) {/* signing out never waits for it */}
    }
    stopLive();
    rtcOff();
    clearMemory(); // (update-155) nothing the screens kept stays after sign-out
    await api.signOut();
    site = null;
    machines = [];
    perms = {};
    dsrc = {};
    placeFuels = {};
    fuelMode = '';
    serverFuels = [];
    cards = [];
    admin = false;
    superAdmin = false;
    _go(Stage.signedOut, msg);
  }
}
