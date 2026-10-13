/* THE WHOLE WEB ERP INSIDE THE APP (asked 14-10-2026: "web warti jya user la jo access asel tya user la pratek task kam tya app
 * madhun hoil … same web warcha full access app war"; chosen: "web-ch app madhe").
 * The app opens the site's ERP – the very same pages, menu (☰), Dashboard, checks and access as on the web – signed in with a
 * Portal ticket (nothing typed). What a phone's web view does not do by itself, the app does:
 *   the camera for a photo (Diesel Issue …) and the location – the phone asks once;
 *   Excel / CSV files – offered to open, send or keep (assets/web_bridge.js → saveFile);
 *   printing – the print window inside the app, then Android's printing / Save as PDF (→ print);
 *   a link to another site (a photo in full size, the map) – opened outside the app;
 *   the phone's Back – one step back in the ERP (its own Back), never out of it by mistake;
 *   the web's Logout – the app's sign-out (back to the app's sign-in screen).
 * Every change stays on the server's side: the same /api/rpc, the same access, nothing is saved by the app itself. */
import 'dart:async';
import 'dart:collection';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../core/api.dart';
import '../core/session.dart';
import '../core/update.dart';
import '../ui/brand.dart';
import '../ui/scope.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'files.dart';
import 'print_view.dart';

/// Where a link may go inside the app (else it opens outside): the ERP's own address and the site's module addresses.
bool ownHost(String host, Session s) {
  final hosts = <String>{Uri.parse(kMainUrl).host, for (final m in s.site?.modules ?? <Module>[]) Uri.tryParse(m.url)?.host ?? ''}..remove('');
  return hosts.contains(host);
}

/// What the app does with an address the web goes to (kept apart so the tests can check it).
enum Go { stay, outside, signOut }

Go whereTo(Uri u, bool mainFrame, Session s) {
  final scheme = u.scheme.toLowerCase();
  if (const {'about', 'data', 'blob', 'javascript'}.contains(scheme)) return Go.stay;
  if (scheme != 'http' && scheme != 'https') return Go.outside; // tel:, mailto:, whatsapp:, …
  if (!mainFrame) return Go.stay; // a module's page inside the ERP's page
  if (!ownHost(u.host, s)) return Go.outside;
  if (u.path.contains('/portal') && u.queryParameters.containsKey('signout')) return Go.signOut; // the web's Logout
  return Go.stay;
}

class WebShell extends StatefulWidget {
  const WebShell({super.key});
  @override
  State<WebShell> createState() => _WebShellState();
}

class _WebShellState extends State<WebShell> {
  InAppWebViewController? _c;
  String? _url;
  String _bridge = '', _err = '';
  double _progress = 0;
  bool _ready = false, _leaving = false;
  AppUpdate? _update;
  DateTime? _lastBack;
  Timer? _poll;

  Session get _s => SessionScope.read(context);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
    checkUpdate(_s.api).then((u) {
      if (mounted && u != null) setState(() => _update = u);
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _err = '';
      _ready = false;
    });
    try {
      if (_bridge.isEmpty) _bridge = await rootBundle.loadString('assets/web_bridge.js');
      await _askOnce();
      final url = await _s.startUrl();
      await _cookie();
      if (!mounted) return;
      if (_c != null) {
        await _c!.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
      } else {
        setState(() => _url = url);
      }
    } on ApiError catch (e) {
      if (mounted && !e.needsSignIn) setState(() => _err = e.toString());
    } catch (_) {
      if (mounted) setState(() => _err = 'The ERP could not be opened – check the internet and try again.');
    }
  }

  /// The camera (photos in Diesel Issue …) and the location (every entry carries it): Android asks the person once.
  Future<void> _askOnce() async {
    if (!Platform.isAndroid) return; // the iPhone asks by itself when the page needs it
    try {
      await [Permission.camera, Permission.locationWhenInUse].request();
    } catch (_) {/* the page asks again when it needs it */}
  }

  /// The Portal's sign-in for the web view too: the web's "Change site", its modules (the Store …) open without a sign-in.
  Future<void> _cookie() async {
    final v = _s.api.cookieValue;
    if (v == null || v.isEmpty) return;
    final urls = <String>{kMainUrl, for (final m in _s.site?.modules ?? <Module>[]) m.url};
    for (final u in urls) {
      try {
        await CookieManager.instance().setCookie(url: WebUri(u), name: 'rcl_portal', value: v, path: '/', isSecure: true, isHttpOnly: true, sameSite: HTTPCookieSameSitePolicy.LAX);
      } catch (_) {/* the web asks the Portal itself */}
    }
  }

  Future<void> _signOut([String msg = '']) async {
    if (_leaving) return;
    _leaving = true;
    try {
      await CookieManager.instance().deleteAllCookies();
      if (Platform.isAndroid) await WebStorageManager.instance().deleteAllData();
    } catch (_) {/* the sign-in ends on the servers anyway */}
    await _s.signOut(msg);
  }

  Future<void> _outside(String url) async {
    try {
      final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!ok && mounted) toast(context, 'This link cannot be opened on this phone.', bad: true);
    } catch (_) {
      if (mounted) toast(context, 'This link cannot be opened on this phone.', bad: true);
    }
  }

  void _handlers(InAppWebViewController c) {
    c.addJavaScriptHandler(
      handlerName: 'saveFile',
      callback: (a) async {
        if (a.length < 3) return false;
        try {
          await saveAndShare('${a[0]}', '${a[1]}', '${a[2]}');
          return true;
        } catch (_) {
          if (mounted) toast(context, 'The file could not be saved on this phone – try again.', bad: true);
          return false;
        }
      },
    );
    c.addJavaScriptHandler(
      handlerName: 'saveFailed',
      callback: (a) {
        if (mounted) toast(context, 'The file could not be made – try again.', bad: true);
        return false;
      },
    );
    c.addJavaScriptHandler(
      handlerName: 'print',
      callback: (a) {
        if (!mounted || a.isEmpty) return false;
        Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PrintView(html: '${a[0]}', title: a.length > 1 ? '${a[1]}' : '')));
        return true;
      },
    );
    c.addJavaScriptHandler(
      handlerName: 'openUrl',
      callback: (a) {
        if (a.isNotEmpty) _outside('${a[0]}');
        return true;
      },
    );
  }

  /// After a page has loaded: wait until the ERP shows its page, then take the opening cover away.
  void _watchReady(InAppWebViewController c, WebUri? url) {
    _poll?.cancel();
    var n = 0;
    _poll = Timer.periodic(const Duration(milliseconds: 300), (t) async {
      n++;
      bool ok = false;
      try {
        ok = (await c.evaluateJavascript(source: 'window.__rclAppReady ? window.__rclAppReady() : true')) == true;
      } catch (_) {
        ok = n > 10;
      }
      if (ok || n > 50) {
        t.cancel();
        if (mounted && !_ready) setState(() => _ready = true);
      }
    });
    // the Portal's own sign-in page in the app = the Portal sign-in has ended: the app's sign-in screen instead
    if (url != null && url.path.contains('/portal')) {
      Future<void>.delayed(const Duration(milliseconds: 900), () async {
        try {
          final login = await c.evaluateJavascript(source: '(function(){var e=document.getElementById("l_email");return !!(e&&e.offsetParent)})()');
          if (login == true && mounted) await _signOut('Your sign-in has ended – please sign in again.');
        } catch (_) {/* not the Portal's page */}
      });
    }
  }

  Future<void> _back() async {
    final c = _c;
    if (_err.isNotEmpty || c == null) {
      _leaveAsk();
      return;
    }
    String r = 'none';
    try {
      r = '${await c.evaluateJavascript(source: 'window.__rclAppBack ? window.__rclAppBack() : "none"')}';
    } catch (_) {/* below */}
    if (r == 'done') return;
    if (r == 'exit') {
      await SystemNavigator.pop(); // the ERP already said "press Back again to leave"
      return;
    }
    if (await c.canGoBack()) {
      await c.goBack();
      return;
    }
    _leaveAsk();
  }

  void _leaveAsk() {
    final now = DateTime.now();
    if (_lastBack != null && now.difference(_lastBack!) < const Duration(seconds: 3)) {
      SystemNavigator.pop();
      return;
    }
    _lastBack = now;
    toast(context, 'Press Back again to leave the app.');
  }

  Future<PermissionResponse> _permission(PermissionRequest r) async {
    final res = r.resources;
    if (!ownHost(r.origin.host, _s)) return PermissionResponse(resources: res, action: PermissionResponseAction.DENY);
    final cam = res.contains(PermissionResourceType.CAMERA) || res.contains(PermissionResourceType.CAMERA_AND_MICROPHONE);
    final mic = res.contains(PermissionResourceType.MICROPHONE) || res.contains(PermissionResourceType.CAMERA_AND_MICROPHONE);
    var ok = true;
    if (Platform.isAndroid) {
      if (cam) ok = (await Permission.camera.request()).isGranted;
      if (mic) ok = ok && (await Permission.microphone.request()).isGranted;
    }
    return PermissionResponse(resources: res, action: ok ? PermissionResponseAction.GRANT : PermissionResponseAction.DENY);
  }

  Future<GeolocationPermissionShowPromptResponse> _location(String origin) async {
    var ok = ownHost(Uri.tryParse(origin)?.host ?? '', _s);
    if (ok && Platform.isAndroid) ok = (await Permission.locationWhenInUse.request()).isGranted;
    return GeolocationPermissionShowPromptResponse(origin: origin, allow: ok, retain: ok);
  }

  Widget _web() => InAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(_url!)),
        initialUserScripts: UnmodifiableListView([UserScript(source: _bridge, injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START, forMainFrameOnly: true)]),
        initialSettings: InAppWebViewSettings(
          useShouldOverrideUrlLoading: true,
          useOnDownloadStart: true,
          supportMultipleWindows: true,
          javaScriptCanOpenWindowsAutomatically: true,
          geolocationEnabled: true,
          mediaPlaybackRequiresUserGesture: false,
          allowsInlineMediaPlayback: true,
          domStorageEnabled: true,
          databaseEnabled: true,
          supportZoom: false,
          disableDefaultErrorPage: true,
          allowsBackForwardNavigationGestures: false,
          applicationNameForUserAgent: 'RCLApp/2',
        ),
        onWebViewCreated: (c) {
          _c = c;
          _handlers(c);
        },
        shouldOverrideUrlLoading: (c, a) async {
          final u = a.request.url;
          if (u == null) return NavigationActionPolicy.ALLOW;
          switch (whereTo(u, a.isForMainFrame, _s)) {
            case Go.stay:
              // another site opened from the web's "Change site": the app opens that site next time
              if (a.isForMainFrame && u.path.endsWith('/api/go') && u.queryParameters['module'] == 'mechanical') {
                await _s.rememberSite(u.queryParameters['site'] ?? '');
              }
              return NavigationActionPolicy.ALLOW;
            case Go.outside:
              await _outside(u.toString());
              return NavigationActionPolicy.CANCEL;
            case Go.signOut:
              await _signOut();
              return NavigationActionPolicy.CANCEL;
          }
        },
        onCreateWindow: (c, a) async {
          final u = a.request.url;
          if (u != null && u.scheme.startsWith('http')) await _outside(u.toString());
          return false;
        },
        onDownloadStartRequest: (c, r) {
          if (r.url.scheme.startsWith('http')) _outside(r.url.toString());
        },
        onPermissionRequest: (c, r) => _permission(r),
        onGeolocationPermissionsShowPrompt: (c, origin) => _location(origin),
        onProgressChanged: (c, p) {
          if (mounted) setState(() => _progress = p / 100);
        },
        onLoadStop: (c, url) => _watchReady(c, url),
        onReceivedError: (c, req, e) {
          if (req.isForMainFrame != true || e.type == WebResourceErrorType.CANCELLED) return;
          if (mounted) setState(() => _err = 'No connection – check the internet and try again.\n(${e.description})');
        },
      );

  Widget _cover(String site) => Backdrop(
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Mark(size: 78),
            const SizedBox(height: 22),
            Text('Opening $site…', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
            const SizedBox(height: 18),
            const SizedBox(width: 30, height: 30, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white)),
          ]),
        ),
      );

  Widget _problem() => Backdrop(
        road: false,
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(26)),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.wifi_off_rounded, size: 46, color: C.red),
                  const SizedBox(height: 12),
                  Text(_err, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, height: 1.4, color: C.ink)),
                  const Text('Internet तपासा आणि पुन्हा प्रयत्न करा.', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'NotoDeva', fontSize: 13.5, color: C.muted)),
                  const SizedBox(height: 18),
                  FilledButton.icon(onPressed: _start, icon: const Icon(Icons.refresh_rounded), label: const Text('Try again')),
                  TextButton(onPressed: () => _signOut(), child: const Text('Sign out')),
                ]),
              ),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final site = SessionScope.of(context).site?.name ?? '';
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: (_ready && _err.isEmpty ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light).copyWith(statusBarColor: Colors.transparent),
        child: Scaffold(
          backgroundColor: Colors.white,
          body: Stack(children: [
            if (_url != null) SafeArea(child: _web()),
            if (_url != null && _progress < 1 && _ready) SafeArea(child: LinearProgressIndicator(value: _progress, minHeight: 3, color: C.green, backgroundColor: Colors.transparent)),
            IgnorePointer(
              ignoring: _ready,
              child: AnimatedOpacity(opacity: _ready ? 0 : 1, duration: const Duration(milliseconds: 380), child: _cover(site)),
            ),
            if (_err.isNotEmpty) Positioned.fill(child: _problem()),
            if (_update != null && _ready)
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: SafeArea(
                  child: Material(
                    color: C.ink,
                    borderRadius: BorderRadius.circular(18),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
                      child: Row(children: [
                        const Icon(Icons.system_update_rounded, color: Colors.white),
                        const SizedBox(width: 10),
                        Expanded(child: Text('New version ${_update!.version}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
                        TextButton(onPressed: () => runUpdate(context, _update!), child: const Text('Update', style: TextStyle(color: Color(0xFFFFD54F), fontWeight: FontWeight.w700))),
                        IconButton(tooltip: 'Later', onPressed: () => setState(() => _update = null), icon: const Icon(Icons.close_rounded, color: Colors.white70)),
                      ]),
                    ),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}
