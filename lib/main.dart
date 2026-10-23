import 'dart:io' show Platform;
import 'dart:ui' show PlatformDispatcher, PointerDeviceKind;

import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';

import 'config.dart';
import 'core/alerts.dart';
import 'core/api.dart';
import 'core/applock.dart';
import 'core/device.dart';
import 'core/lock_gate.dart';
import 'core/rtc_kit.dart';
import 'core/session.dart';
import 'core/update.dart' show updateContext, updateWatch;
import 'screens/call.dart';
import 'screens/lock.dart';
import 'screens/login.dart';
import 'screens/shell.dart';
import 'screens/site_pick.dart';
import 'ui/brand.dart';
import 'ui/scope.dart';
import 'ui/theme.dart';
import 'ui/t.dart';

/// The sign-in kept in the phone's own safe (Android Keystore / iOS Keychain) – never in plain files.
class SecureKeep implements Keep {
  static const _s = FlutterSecureStorage(aOptions: AndroidOptions(encryptedSharedPreferences: true));
  @override
  Future<String?> read(String key) => _s.read(key: key);
  @override
  Future<void> write(String key, String? value) => value == null ? _s.delete(key: key) : _s.write(key: key, value: value);
}

/// (3.1.8) With the app closed: Android runs this about every 15 minutes (an alarm) – Approvals asked once, a notification when
/// something waits for him or was sent back to him (alerts.dart).
@pragma('vm:entry-point')
Future<void> alertsInBackground() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await backgroundAlerts(Api(portalUrl: kPortalUrl, keep: SecureKeep()));
  } catch (_) {/* the next time */}
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  () async {
    if (Platform.isAndroid) {
      try {
        await AndroidAlarmManager.initialize();
        await AndroidAlarmManager.periodic(const Duration(minutes: 15), 3108, alertsInBackground, allowWhileIdle: true, rescheduleOnReboot: true);
      } catch (_) {/* no background work on this phone: the notifications come while the app is open */}
    }
    await Alerts.init(ask: true);
  }();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.light));
  if (Platform.isAndroid) Session.callKit = () => WebrtcKit(); // (3.26.0) calls with the web – the Android phone first
  final session = Session(Api(portalUrl: kPortalUrl, keep: SecureKeep())
        ..askApproval = askApprovalBox
        ..askReason = askReasonBox)
      ..start();
  // (3.14.0) a fault of the app's own code goes to the Admin's "Faults of the app" (as the web's page reports its faults)
  FlutterError.onError = (d) {
    FlutterError.presentError(d);
    session.reportFault(d.exceptionAsString(), '${d.stack ?? ''}');
  };
  PlatformDispatcher.instance.onError = (e, st) {
    session.reportFault('$e', '$st');
    return false;
  };
  // (3.27.0) the app lock: the phone's fingerprint / face / PIN – for everyone, asked again after a minute away (applock.dart)
  final lock = AppLock(PhoneLockGate());
  session.freshSignIn = lock.signedIn;
  runApp(RclApp(session: session, lock: lock));
  // (3.31.4) the update downloaded in the background: "Install?" over whatever screen is open – when the app opens and when it
  // comes back (core/update.dart updateWatch)
  updateContext = () => appNav.currentContext;
  AppLifecycleListener(onResume: () => updateWatch(opened: true)); // (it stays with the app's binding)
  WidgetsBinding.instance.addPostFrameCallback((_) => updateWatch(opened: true));
}


/// (14-10-2026) the app's navigator – the box "send it to the Super Admin?" opens over any screen (Api.askApproval).
final appNav = GlobalKey<NavigatorState>();

/// A save refused because its entry is in a submitted bill: the reason for the Super Admin, or null (not sent).
Future<String?> askApprovalBox(String message) async {
  final ctx = appNav.currentContext;
  if (ctx == null) return null;
  final why = TextEditingController();
  return showDialog<String>(
    context: ctx,
    builder: (c) => AlertDialog(
      title: Text(Api.crApproved(message) ? 'An approved entry – send it to the Super Admin?' : 'In a submitted bill – send it to the Super Admin?'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(message.replaceFirst(RegExp(r'^(Line|Row) [^:]+: '), ''), style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 10),
          Text(Api.crApproved(message) ? 'It is saved only when the Super Admin approves it.' : 'It is saved only when the Super Admin approves it. The bill is not changed – the difference comes in the next bill.', style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          TextField(key: const ValueKey('cr_reason'), controller: why, maxLines: 2, maxLength: 300, decoration: InputDecoration(labelText: tr('Why is this change needed?'))),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
        FilledButton(onPressed: () { if (why.text.trim().isNotEmpty) Navigator.pop(c, why.text.trim()); }, child: const Text('Send for approval')),
      ],
    ),
  );
}

/// (3.33.0 – Mechanical update-152) The Super Admin's save of a locked Log Book entry (approved, or in a submitted bill): the server asks
/// why – the reason is kept with the entry's history. null = not saved.
Future<String?> askReasonBox(String message) async {
  final ctx = appNav.currentContext;
  if (ctx == null) return null;
  final why = TextEditingController();
  return showDialog<String>(
    context: ctx,
    builder: (c) => AlertDialog(
      title: const Text('Locked entry – give the reason'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(message, style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 10),
          TextField(key: const ValueKey('sa_reason'), controller: why, maxLines: 2, maxLength: 300, decoration: InputDecoration(labelText: tr('Reason'))),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
        FilledButton(onPressed: () { if (why.text.trim().isNotEmpty) Navigator.pop(c, why.text.trim()); }, child: const Text('Save with this reason')),
      ],
    ),
  );
}

class RclApp extends StatelessWidget {
  const RclApp({super.key, required this.session, this.lock});
  final Session session;
  /// (3.27.0) the app lock (none in the tests of the other screens)
  final AppLock? lock;
  @override
  Widget build(BuildContext context) => SessionScope(
        session: session,
        child: LangScope(child: MaterialApp(
          navigatorKey: appNav,
          title: 'RCL ERP',
          debugShowCheckedModeBanner: false,
          theme: appTheme(),
          // (3.19.0) on a computer a list is also dragged with the mouse (and pulled down to refresh), as with a finger
          scrollBehavior: onComputer ? const _AnyPointerDrags() : null,
          // his "Size of the text" (Settings) – on every screen of the app
          // (3.26.0) a call: its ring, its screen and its green bar – over every screen of the app (screens/call.dart)
          builder: (context, child) {
            final m = MediaQuery.of(context), k = SessionScope.of(context).textScale;
            // (3.27.0) the lock over everything – the call's bar too
            final app = LockLayer(lock: lock, nav: appNav, child: CallLayer(nav: appNav, child: child!));
            return k == 1.0 ? app : MediaQuery(data: m.copyWith(textScaler: TextScaler.linear(m.textScaler.scale(1) * k)), child: app);
          },
          home: const Gate(),
        )),
      );
}

class _AnyPointerDrags extends MaterialScrollBehavior {
  const _AnyPointerDrags();
  @override
  Set<PointerDeviceKind> get dragDevices => PointerDeviceKind.values.toSet();
}

/// Which screen: opening · sign-in · pick a site · opening a site · the app.
class Gate extends StatelessWidget {
  const Gate({super.key});
  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      switchInCurve: Curves.easeOut,
      child: switch (s.stage) {
        Stage.starting => const Opening(key: ValueKey('start')),
        Stage.opening => Opening(key: const ValueKey('opening'), what: s.siteName),
        Stage.signedOut => const LoginScreen(key: ValueKey('login')),
        Stage.setPassword => const LoginScreen(key: ValueKey('setpw'), setPassword: true),
        Stage.pickSite => const SitePickScreen(key: ValueKey('site')),
        Stage.ready => Shell(key: ValueKey('app-${s.site?.code}')),
        Stage.waiting => const Waiting(key: ValueKey('wait')),
      },
    );
  }
}

/// (3.20.1, asked 18-10-2026: "app madhun pn auto log out nko aahe") No network – or the server not reached – while the kept
/// sign-in is checked or a site is opened: he is STILL SIGNED IN (never the sign-in screen for this). The app tries again by
/// itself (Session.retryEvery); "Try again" tries at once.
class Waiting extends StatelessWidget {
  const Waiting({super.key});
  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: C.greenDark,
        body: Backdrop(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Mark(size: 96),
                const SizedBox(height: 22),
                Text(bi('No connection', 'नेटवर्क नाही'), key: const Key('wait-title'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
                const SizedBox(height: 8),
                Text(bi('You are still signed in. The app tries again by itself.', 'तुमचा login चालू आहे. App स्वतः पुन्हा प्रयत्न करेल.', '\n'),
                    key: const Key('wait-kept'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, height: 1.35, color: Color(0xE6FFFFFF))),
                if (s.error.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(s.error, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: Color(0xB3FFFFFF))),
                ],
                const SizedBox(height: 26),
                if (s.retrying)
                  const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
                else
                  FilledButton(
                    key: const Key('wait-again'),
                    style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: C.greenDark, minimumSize: const Size(190, 52)),
                    onPressed: s.tryAgain,
                    child: const Text('Try again', mr: 'पुन्हा प्रयत्न करा'),
                  ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// The first moment: the Rachana mark on the green background while the kept sign-in is checked, or a site is opened.
class Opening extends StatelessWidget {
  const Opening({super.key, this.what = ''});
  final String what;
  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: C.greenDark,
          body: Backdrop(
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Mark(size: 96),
                const SizedBox(height: 22),
                Text(what.isEmpty ? 'RCL ERP' : 'Opening $what…', textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
                const SizedBox(height: 4),
                const Text('Fleet & Diesel Management', style: TextStyle(fontSize: 14, color: Color(0xCCFFFFFF))), // (3.31.0) the app is RCL ERP
                const SizedBox(height: 24),
                const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white)),
              ]),
            ),
          ),
        ),
      );
}
