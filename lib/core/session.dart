/* THE PERSON ON THIS PHONE: signed in on the Portal or not, his sites, and the module the app opens on a site (Mechanical
 * first – the web ERP; the Store and every module of that site are reached inside it, as on the web). */
import 'package:flutter/foundation.dart';

import 'api.dart';

enum Stage { starting, signedOut, pickSite, ready }

class Module {
  Module(this.key, this.name, this.url);
  final String key, name, url;
}

class SiteChoice {
  SiteChoice(this.code, this.name, this.company, this.modules);
  final String code, name, company;
  final List<Module> modules;

  /// The module the app opens on this site: Mechanical (the ERP's screen; the others are inside it), else the first one.
  Module get main => modules.firstWhere((m) => m.key == 'mechanical', orElse: () => modules.first);
}

class Session extends ChangeNotifier {
  Session(this.api);
  final Api api;

  Stage stage = Stage.starting;
  String error = '';
  String name = '', email = '';
  List<SiteChoice> sites = [];
  SiteChoice? site;

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
      _afterSites();
    } on ApiError catch (e) {
      if (e.needsSignIn || e.status == 401) {
        await api.forget();
        return _go(Stage.signedOut);
      }
      _go(Stage.signedOut, e.toString());
    }
  }

  void _afterSites() {
    final kept = api.site ?? '';
    final s = sites.where((x) => x.code == kept).toList();
    if (s.isNotEmpty) {
      site = s.first;
      _go(Stage.ready);
    } else if (sites.length == 1) {
      chooseSite(sites.first.code);
    } else {
      _go(Stage.pickSite);
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
      final code = (x['site'] ?? '').toString(), url = (x['url'] ?? '').toString();
      if (code.isEmpty || !url.startsWith('https://')) continue;
      by.putIfAbsent(code, () => SiteChoice(code, (x['siteName'] ?? code).toString(), (x['company'] ?? '').toString(), [])).modules.add(Module((x['module'] ?? '').toString(), (x['moduleName'] ?? '').toString(), url));
    }
    sites = by.values.toList();
    if (sites.isEmpty) throw ApiError('You have no module on any site yet – ask the Super Admin.', code: 'nosite');
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
      _afterSites();
    } on ApiError catch (e) {
      _go(Stage.signedOut, e.toString());
    }
  }

  Future<void> chooseSite(String code) async {
    site = sites.firstWhere((s) => s.code == code);
    await api.keepSite(code);
    _go(Stage.ready);
  }

  /// Another site opened from inside the web ("Change site"): it opens next time (the screen is not rebuilt).
  Future<void> rememberSite(String code) async {
    final s = sites.where((x) => x.code == code).toList();
    if (s.isEmpty || site?.code == code) return;
    site = s.first;
    await api.keepSite(code);
  }

  /// The address the app's web view opens: the site's main module, signed in with a fresh ticket (nothing typed).
  Future<String> startUrl() async {
    final s = site!, m = s.main;
    try {
      final t = await api.ticket(s.code, m.key);
      return '${m.url.replaceAll(RegExp(r'/+$'), '')}/#sso=$t';
    } on ApiError catch (e) {
      if (e.needsSignIn) {
        await api.forget();
        _go(Stage.signedOut, 'Your sign-in has ended – please sign in again.');
      }
      rethrow;
    }
  }

  Future<void> signOut([String msg = '']) async {
    await api.signOut();
    site = null;
    _go(Stage.signedOut, msg);
  }
}
