/* THE PERSON ON THIS PHONE: signed in on the Portal or not, his sites (and the modules he has there), the site open, what he
 * may open on it (the same Edit / View / None as on the web – set by the site's Admin) and the site's lists the screens need
 * (machinery, drivers, pumps, locations, stock). Every number comes from Mechanical, as on the web. */
import 'package:flutter/foundation.dart';

import 'api.dart';
import 'format.dart';

enum Stage { starting, signedOut, pickSite, opening, ready }

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
  bool get debit => (m['supply'] ?? '') == 'Debit Basis'; // no readings are kept for diesel on Debit Basis
  List<String> _list(String k) => (m[k] is List) ? (m[k] as List).map((e) => e.toString()).toList() : <String>[];

  /// The ways it is measured by (Asset Master: "Measured by") – KM, Hrs, KM + Hrs, Time, Trip, Day.
  List<String> get modes => _list('modes');

  /// The ways picked only on a special day (Time: the hour meter gave no reading).
  List<String> get modesX => _list('modesX');
  List<String> get modesMain => modes.where((w) => !modesX.contains(w)).toList();

  /// The way picked by itself: when there is only one usual way (as on the web).
  String get wayAuto => modesMain.length == 1 ? modesMain.first : '';
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
  Session(this.api);
  final Api api;

  Stage stage = Stage.starting;
  String error = '';
  String name = '', email = '';
  bool admin = false;
  Map<String, String> perms = {};
  List<SiteChoice> sites = [];
  SiteChoice? site;
  String siteName = '';

  // the site's lists (getInit)
  String today = '', company = '', closedUpto = '';
  List<Machine> machines = [];
  List<String> drivers = [], pumps = [], locations = [];
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
    stage = s;
    error = err;
    notifyListeners();
  }

  /// The app opens: the sign-in kept on this phone is used – nothing to type while the Portal still knows the person.
  Future<void> start() async {
    await api.load();
    if (!api.hasPortal) return _go(Stage.signedOut);
    try {
      await _loadSites();
      final kept = api.site ?? '';
      if (sites.any((x) => x.code == kept)) {
        await chooseSite(kept);
      } else if (sites.length == 1) {
        await chooseSite(sites.first.code);
      } else {
        _go(Stage.pickSite);
      }
    } on ApiError catch (e) {
      if (e.needsSignIn || e.status == 401) {
        await api.forget();
        return _go(Stage.signedOut);
      }
      _go(Stage.signedOut, e.toString());
    }
  }

  Future<void> _loadSites() async {
    final me = await api.auth({'action': 'me'});
    if (me['signedIn'] != true) throw ApiError('Please sign in.', code: 'signin');
    final u = (me['user'] as Map?)?.cast<String, dynamic>() ?? {};
    if (u['super'] == true) {
      await api.signOut();
      throw ApiError('The Super Admin manages access on the Portal (web); the app is for the people at the sites.', code: 'super');
    }
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
  }

  /// Email + password of the Portal (one password for every module).
  Future<void> signIn(String mail, String password) async {
    error = '';
    try {
      final r = await api.auth({'action': 'login', 'email': mail.trim(), 'password': password});
      if (r['mustChange'] == true) {
        await api.signOut();
        return _go(Stage.signedOut, 'Set your own password on the Portal (web) first, then sign in here.');
      }
      await _loadSites();
      if (sites.length == 1) {
        await chooseSite(sites.first.code);
      } else {
        _go(Stage.pickSite);
      }
    } on ApiError catch (e) {
      _go(Stage.signedOut, e.toString());
    }
  }

  /// Opens a site: Mechanical's sign-in (a kept one, else a new ticket), the person's access and the site's lists.
  Future<void> chooseSite(String code) async {
    final s = sites.firstWhere((x) => x.code == code);
    site = s;
    siteName = s.name;
    api.mechUrl = s.module('mechanical')!.url;
    await api.keepSite(code);
    _go(Stage.opening);
    try {
      if ((api.token ?? '').isEmpty) _user(await api.openSite(code));
      await loadInit();
      _go(Stage.ready);
    } on ApiError catch (e) {
      if (e.needsSignIn) {
        await api.forget();
        return _go(Stage.signedOut, 'Your sign-in has ended – please sign in again.');
      }
      _go(sites.length > 1 ? Stage.pickSite : Stage.signedOut, e.toString());
    }
  }

  void _user(Map<String, dynamic> r) {
    final u = (r['user'] as Map?)?.cast<String, dynamic>();
    if (u == null) return;
    if ((u['name'] ?? '').toString().isNotEmpty) name = u['name'].toString();
    email = (u['email'] ?? email).toString();
    admin = u['admin'] == true;
    final p = u['perms'];
    perms = p is Map ? p.map((k, v) => MapEntry(k.toString(), v.toString())) : {};
    if ((r['siteName'] ?? '').toString().isNotEmpty) siteName = r['siteName'].toString();
  }

  Future<void> loadInit() async {
    final d = (await api.call('getInit') as Map).cast<String, dynamic>();
    final u = d['user'];
    if (u is Map) _user({'user': u});
    today = (d['today'] ?? '').toString();
    company = (d['company'] ?? '').toString();
    closedUpto = (d['closedUpto'] ?? '').toString();
    machines = (d['master'] as List? ?? []).whereType<Map>().map((m) => Machine(m.cast<String, dynamic>())).toList();
    drivers = (d['drivers'] as List? ?? []).map((e) => e.toString()).toList();
    pumps = (d['pumps'] as List? ?? []).map((e) => e.toString()).toList();
    locations = (d['locations'] as List? ?? []).map((e) => e.toString()).toList();
    setStock(d['stock']);
  }

  void setStock(dynamic s) {
    if (s is! Map) return;
    final t = s['stock'];
    if (t is num) stockTotal = t;
    final by = s['byLoc'];
    if (by is Map) stockByLoc = by.map((k, v) => MapEntry(k.toString(), (v is num) ? v : 0));
    notifyListeners();
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

  /// Back to the list of sites (another site).
  void pickAnotherSite() {
    if (sites.length > 1) _go(Stage.pickSite);
  }

  Future<void> signOut([String msg = '']) async {
    await api.signOut();
    site = null;
    machines = [];
    perms = {};
    admin = false;
    _go(Stage.signedOut, msg);
  }
}
