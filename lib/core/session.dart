/* THE PERSON ON THIS PHONE: signed in or not, his site, what he may open (the same access as Mechanical on the web – set by
 * the site's Admin), and the site's lists the forms need (machinery, drivers, pumps, locations, stock). */
import 'package:flutter/foundation.dart';

import 'api.dart';

enum Stage { starting, signedOut, pickSite, ready }

class SiteChoice {
  SiteChoice(this.code, this.name, this.company);
  final String code, name, company;
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
  bool get km => !debit && m['meterKm'] == true;
  bool get hr => !debit && m['meterHr'] == true;
  String get label => [id, if (name.isNotEmpty && name != id) name, type].where((s) => s.isNotEmpty).join(' · ');
  bool matches(String q) {
    final words = q.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    final text = [id, name, type, owner, (m['no'] ?? '').toString()].join(' ').toLowerCase();
    final flat = text.replaceAll(RegExp(r'[^a-z0-9]'), '');
    return words.every((w) => text.contains(w) || flat.contains(w.replaceAll(RegExp(r'[^a-z0-9]'), '')));
  }
}

class Session extends ChangeNotifier {
  Session(this.api);
  final Api api;

  Stage stage = Stage.starting;
  String error = '';
  String name = '', email = '';
  bool admin = false;
  Map<String, String> perms = {};
  String siteCode = '', siteName = '';
  List<SiteChoice> sites = [];

  // the site's lists (getInit)
  String today = '';
  List<Machine> machines = [];
  List<String> drivers = [], pumps = [], locations = [];
  num? stockTotal;
  Map<String, num> stockByLoc = {};

  /// May open the page (View or Edit) – as canSee on the web.
  bool canSee(String module) => admin || perms[module] == 'Edit' || perms[module] == 'View';

  /// May add / change (Edit) – as canEdit on the web.
  bool canEdit(String module) => admin || perms[module] == 'Edit';

  void _user(Map<String, dynamic>? u) {
    if (u == null) return;
    name = (u['name'] ?? '').toString();
    email = (u['email'] ?? '').toString();
    admin = u['admin'] == true;
    final p = u['perms'];
    perms = p is Map ? p.map((k, v) => MapEntry(k.toString(), v.toString())) : {};
  }

  void _go(Stage s, [String err = '']) {
    stage = s;
    error = err;
    notifyListeners();
  }

  /// The app opens: the sign-in kept on this phone is tried – nothing to type while the Portal still knows the person.
  Future<void> start() async {
    await api.load();
    if (!api.hasPortal) return _go(Stage.signedOut);
    try {
      await _loadSites();
      final keep = api.site ?? '';
      if (keep.isNotEmpty && sites.any((s) => s.code == keep)) {
        await openSite(keep);
      } else if (sites.length == 1) {
        await openSite(sites.first.code);
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
    final me = await api.portalAuth({'action': 'me'});
    if (me['signedIn'] != true) throw ApiError('Please sign in.', code: 'signin');
    final u = (me['user'] as Map?)?.cast<String, dynamic>() ?? {};
    if (u['super'] == true) {
      await api.signOut();
      throw ApiError('The Super Admin manages access on the Portal (web); the app is for the people at the sites.', code: 'super');
    }
    final items = (me['items'] as List? ?? []).whereType<Map>().where((x) => x['module'] == 'mechanical');
    sites = items.map((x) => SiteChoice(x['site'].toString(), (x['siteName'] ?? x['site']).toString(), (x['company'] ?? '').toString())).toList();
    if (sites.isEmpty) throw ApiError('You have no site with Mechanical yet – ask the Super Admin.', code: 'nosite');
    name = (u['name'] ?? '').toString();
    email = (u['email'] ?? '').toString();
  }

  /// Email + password of the Portal (one password for every module).
  Future<void> signIn(String mail, String password) async {
    error = '';
    try {
      final r = await api.portalAuth({'action': 'login', 'email': mail.trim(), 'password': password});
      if (r['mustChange'] == true) {
        await api.signOut();
        return _go(Stage.signedOut, 'Set your own password on the Portal (web) first, then sign in here.');
      }
      await _loadSites();
      if (sites.length == 1) {
        await openSite(sites.first.code);
      } else {
        _go(Stage.pickSite);
      }
    } on ApiError catch (e) {
      _go(Stage.signedOut, e.toString());
    }
  }

  Future<void> openSite(String code) async {
    final r = await api.openSite(code);
    _user((r['user'] as Map?)?.cast<String, dynamic>());
    siteCode = code;
    siteName = (r['siteName'] ?? sites.firstWhere((s) => s.code == code, orElse: () => SiteChoice(code, code, '')).name).toString();
    await loadInit();
    _go(Stage.ready);
  }

  Future<void> loadInit() async {
    final d = (await api.call('getInit') as Map).cast<String, dynamic>();
    today = (d['today'] ?? '').toString();
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

  Future<void> switchSite(String code) async {
    _go(Stage.starting);
    try {
      await openSite(code);
    } on ApiError catch (e) {
      _go(Stage.pickSite, e.toString());
    }
  }

  Future<void> signOut() async {
    await api.signOut();
    machines = [];
    perms = {};
    _go(Stage.signedOut);
  }
}
