/* (3.124.0, asked 14-11-2026: "ata super admin multiple changes kru shakel, pratek weli code change krne garjech nahi … portal madhun
 * changes kel tri sagle changes app madhe … hou shaktil") THE PRODUCT'S NAME AND LOGO COME FROM THE PORTAL. The Super Admin sets them
 * in the Portal's "Branding" (rcl-portal /api/brand): the name in two parts, the line under it, the logo, the opening screen's photo,
 * and a logo for each client company. The app asks when it opens and keeps the answer on the phone – so the next opening shows it at
 * once, also with no network. Until the first answer, and whenever the Portal has nothing, the built-in "Sketchline Lion" and its
 * lion are shown. Nothing here needs a sign-in; a client's logo is asked for only with the id of a site's company, which the app
 * learns after the sign-in. A new build is needed only for the icon on the phone and the name under it. */
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ProductBrand extends ChangeNotifier {
  ProductBrand._();
  static final ProductBrand i = ProductBrand._();

  static const firstBuiltIn = 'Sketchline', secondBuiltIn = 'Lion', lineBuiltIn = 'Integrated Construction Management';
  String first = firstBuiltIn, second = secondBuiltIn, line = lineBuiltIn;
  String get name => second.isEmpty ? first : '$first $second';

  /// The pictures as the Portal keeps them (null: the built-in one).
  Uint8List? logo, photo;
  final Map<String, Uint8List> _client = {};
  final Set<String> _asked = {};
  String _logoV = '', _photoV = '', _portal = '';
  Directory? _dir;
  http.Client? _http;

  /// A client company's own logo (by the company's id) – null until it is there; asked for once.
  Uint8List? client(String id) {
    if (!_okId(id)) return null;
    final b = _client[id];
    if (b == null && _portal.isNotEmpty && _asked.add(id)) _fetchClient(id);
    return b;
  }

  static bool _okId(String id) => RegExp(r'^[A-Z0-9]{1,20}$').hasMatch(id);

  /// What was kept on the phone (the app's opening shows it at once).
  Future<void> open(Directory dir) async {
    _dir = dir;
    try {
      final f = File('${dir.path}/brand.json');
      if (!await f.exists()) return;
      final j = jsonDecode(await f.readAsString());
      if (j is! Map || !take(j)) return;
      _logoV = '${j['logo'] ?? ''}';
      _photoV = '${j['photo'] ?? ''}';
      logo = await _kept('logo', _logoV);
      photo = await _kept('photo', _photoV);
      notifyListeners();
    } catch (_) {/* nothing kept, or not readable: the built-in one */}
  }

  /// The name and the line of an answer – true when it is one. (Text only: it is shown as text, never run.)
  bool take(Map j) {
    String one(Object? v, int n) {
      final s = '${v ?? ''}'.replaceAll(RegExp(r'[\u0000-\u001f]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
      return s.length > n ? s.substring(0, n) : s;
    }

    final f = one(j['first'], 24);
    if (f.isEmpty) return false;
    first = f;
    second = one(j['second'], 24);
    line = one(j['line'], 60);
    return true;
  }

  /// Ask the Portal; what changed is taken, kept and shown. Never throws – with no network what is shown stays.
  Future<void> refresh(String portalUrl, {http.Client? client}) async {
    _portal = portalUrl.replaceAll(RegExp(r'/+$'), '');
    _http = client ?? _http ?? http.Client();
    try {
      final r = await _http!.get(Uri.parse('$_portal/api/brand')).timeout(const Duration(seconds: 12));
      if (r.statusCode != 200) return;
      final j = jsonDecode(utf8.decode(r.bodyBytes));
      if (j is! Map) return;
      final was = '$first|$second|$line|$_logoV|$_photoV';
      if (!take(j)) return;
      final lv = _stamp(j['logo']), pv = _stamp(j['photo']);
      if (lv != _logoV) {
        logo = lv.isEmpty ? null : await _fetch('logo', lv) ?? logo;
        if (lv.isEmpty || logo != null) _logoV = lv;
      }
      if (pv != _photoV) {
        photo = pv.isEmpty ? null : await _fetch('photo', pv) ?? photo;
        if (pv.isEmpty || photo != null) _photoV = pv;
      }
      if ('$first|$second|$line|$_logoV|$_photoV' != was) {
        await _keep();
        notifyListeners();
      }
    } catch (_) {/* no network: as it is */}
  }

  static String _stamp(Object? v) => RegExp(r'^\d{1,16}$').hasMatch('${v ?? ''}') ? '$v' : '';

  Future<Uint8List?> _fetch(String name, String v) async {
    try {
      final r = await _http!.get(Uri.parse('$_portal/api/brand?img=$name${v.isEmpty ? '' : '&v=$v'}')).timeout(const Duration(seconds: 20));
      final t = r.headers['content-type'] ?? '';
      if (r.statusCode != 200 || !t.startsWith('image/') || r.bodyBytes.isEmpty || r.bodyBytes.length > 1500000) return null;
      final d = _dir;
      if (d != null && v.isNotEmpty) await File('${d.path}/brand_$name.bin').writeAsBytes(r.bodyBytes, flush: true);
      return r.bodyBytes;
    } catch (_) {
      return null;
    }
  }

  Future<void> _fetchClient(String id) async {
    final b = await _fetch('co-$id', '');
    if (b == null) return;
    _client[id] = b;
    notifyListeners();
  }

  Future<Uint8List?> _kept(String name, String v) async {
    final d = _dir;
    if (d == null || v.isEmpty) return null;
    final f = File('${d.path}/brand_$name.bin');
    return await f.exists() ? await f.readAsBytes() : null;
  }

  Future<void> _keep() async {
    final d = _dir;
    if (d == null) return;
    try {
      await File('${d.path}/brand.json').writeAsString(jsonEncode({'first': first, 'second': second, 'line': line, 'logo': _logoV, 'photo': _photoV}), flush: true);
    } catch (_) {/* shown anyway; asked again at the next opening */}
  }

  /// (tests) as when the app is new.
  @visibleForTesting
  void reset() {
    first = firstBuiltIn;
    second = secondBuiltIn;
    line = lineBuiltIn;
    logo = photo = null;
    _client.clear();
    _asked.clear();
    _logoV = _photoV = _portal = '';
    _dir = null;
    _http = null;
  }
}
