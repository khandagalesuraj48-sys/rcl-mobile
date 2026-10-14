/* A PAGE OF THE WEB ERP INSIDE THE APP – for the modules not yet made for the phone (Log Book, Maintenance, Billing, Store,
 * Reports, Administration …). Asked 14-10-2026: the app has its own phone screens; until a module has its own, it opens here,
 * signed in with a Portal ticket straight on its page (nothing typed). The One Click opening film is not shown in the app.
 * What a phone's web view does not do by itself, the app does (assets/web_bridge.js): the camera and the location, Excel / CSV
 * files (share sheet), printing (Android printing / PDF), links to other sites outside, Back = one step back in the web, the
 * web's Logout = the app's sign-out. */
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

class WebPage extends StatefulWidget {
  const WebPage({super.key, required this.title, required this.page, this.pic = 'clipboard'});

  /// The page's name (shown at the top) and its key in the web ERP (log, brk, bill, store__dashboard …).
  final String title, page, pic;
  @override
  State<WebPage> createState() => _WebPageState();
}

/// Opens a web page of the ERP inside the app.
Future<void> openWeb(BuildContext context, String title, String page, {String pic = 'clipboard'}) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => WebPage(title: title, page: page, pic: pic)));

class _WebPageState extends State<WebPage> {
  InAppWebViewController? _c;
  String? _url;
  String _bridge = '', _err = '';
  double _progress = 0;
  bool _ready = false, _leaving = false;
  Timer? _poll;

  Session get _s => SessionScope.read(context);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
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
      final url = await _s.webUrl(widget.page);
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
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
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
      callback: (List<dynamic> a) async {
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
      callback: (List<dynamic> a) {
        if (mounted) toast(context, 'The file could not be made – try again.', bad: true);
        return false;
      },
    );
    c.addJavaScriptHandler(
      handlerName: 'print',
      callback: (List<dynamic> a) {
        if (!mounted || a.isEmpty) return false;
        Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PrintView(html: '${a[0]}', title: a.length > 1 ? '${a[1]}' : '')));
        return true;
      },
    );
    c.addJavaScriptHandler(
      handlerName: 'openUrl',
      callback: (List<dynamic> a) {
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
      _leave();
      return;
    }
    String r = 'none';
    try {
      r = '${await c.evaluateJavascript(source: 'window.__rclAppBack ? window.__rclAppBack() : "none"')}';
    } catch (_) {/* below */}
    if (r == 'done') return;
    if (r == 'exit') {
      _leave(); // the web is at its first page: back to the app's own screens
      return;
    }
    if (await c.canGoBack()) {
      await c.goBack();
      return;
    }
    _leave();
  }

  void _leave() {
    if (mounted) Navigator.of(context).pop();
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
          applicationNameForUserAgent: 'RCLApp/3',
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

  Widget _cover() => Container(
        color: C.bg,
        alignment: Alignment.center,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Pic(widget.pic, size: 84),
          const SizedBox(height: 16),
          Text('Opening ${widget.title}…', textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          const SizedBox(width: 160, child: LinearProgressIndicator(minHeight: 4, color: C.green, backgroundColor: C.greenSoft, borderRadius: BorderRadius.all(Radius.circular(4)))),
        ]),
      );

  Widget _problem() => Container(
        color: C.bg,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.wifi_off_rounded, size: 50, color: C.red),
          const SizedBox(height: 12),
          Text(_err, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, height: 1.4, color: C.ink)),
          const Text('Internet तपासा आणि पुन्हा प्रयत्न करा.', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'NotoDeva', fontSize: 13.5, color: C.muted)),
          const SizedBox(height: 18),
          FilledButton.icon(style: FilledButton.styleFrom(minimumSize: const Size(180, 52)), onPressed: _start, icon: const Icon(Icons.refresh_rounded), label: const Text('Try again')),
        ]),
      );

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _back();
        },
        child: AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
          child: Scaffold(
            backgroundColor: Colors.white,
            body: SafeArea(
              child: Column(children: [
                // the app's own slim bar: back to the app's screens, the page's name
                Container(
                  height: 52,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: C.line))),
                  child: Row(children: [
                    IconButton(tooltip: 'Back to the app', onPressed: _leave, icon: const Icon(Icons.arrow_back_rounded)),
                    Pic(widget.pic, size: 26),
                    const SizedBox(width: 8),
                    Expanded(child: Text(widget.title, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700))),
                    IconButton(tooltip: 'Reload', onPressed: () => _c?.reload(), icon: const Icon(Icons.refresh_rounded, color: C.muted)),
                  ]),
                ),
                if (_url != null && _progress < 1 && _ready) LinearProgressIndicator(value: _progress, minHeight: 2, color: C.green, backgroundColor: Colors.transparent),
                Expanded(
                  child: Stack(children: [
                    if (_url != null) _web(),
                    IgnorePointer(ignoring: _ready, child: AnimatedOpacity(opacity: _ready ? 0 : 1, duration: const Duration(milliseconds: 300), child: _cover())),
                    if (_err.isNotEmpty) Positioned.fill(child: _problem()),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      );
}
