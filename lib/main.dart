import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'config.dart';
import 'core/api.dart';
import 'core/session.dart';
import 'screens/login.dart';
import 'screens/site_pick.dart';
import 'ui/brand.dart';
import 'ui/scope.dart';
import 'ui/theme.dart';
import 'web/web_shell.dart';

/// The sign-in kept in the phone's own safe (Android Keystore / iOS Keychain) – never in plain files.
class SecureKeep implements Keep {
  static const _s = FlutterSecureStorage(aOptions: AndroidOptions(encryptedSharedPreferences: true));
  @override
  Future<String?> read(String key) => _s.read(key: key);
  @override
  Future<void> write(String key, String? value) => value == null ? _s.delete(key: key) : _s.write(key: key, value: value);
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.light));
  final session = Session(Api(portalUrl: kPortalUrl, keep: SecureKeep()))..start();
  runApp(RclApp(session: session));
}

class RclApp extends StatelessWidget {
  const RclApp({super.key, required this.session, this.web});
  final Session session;

  /// The screen of a site that is open (the web ERP); the tests give a stand-in (a web view cannot run in a test).
  final WidgetBuilder? web;
  @override
  Widget build(BuildContext context) => SessionScope(
        session: session,
        child: MaterialApp(
          title: 'RCL ERP',
          debugShowCheckedModeBanner: false,
          theme: appTheme(),
          home: Gate(web: web),
        ),
      );
}

/// Which screen: opening · sign-in · pick a site · the ERP.
class Gate extends StatelessWidget {
  const Gate({super.key, this.web});
  final WidgetBuilder? web;
  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      switchInCurve: Curves.easeOut,
      child: switch (s.stage) {
        Stage.starting => const Opening(key: ValueKey('start')),
        Stage.signedOut => const LoginScreen(key: ValueKey('login')),
        Stage.pickSite => const SitePickScreen(key: ValueKey('site')),
        Stage.ready => KeyedSubtree(key: const ValueKey('web'), child: web != null ? web!(context) : const WebShell()),
      },
    );
  }
}

/// The first moment: the RCL mark on the green background while the kept sign-in is checked.
class Opening extends StatelessWidget {
  const Opening({super.key});
  @override
  Widget build(BuildContext context) => const AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: C.greenDark,
          body: Backdrop(
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Mark(size: 92),
                SizedBox(height: 20),
                Text('RCL ERP', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: Colors.white)),
                SizedBox(height: 22),
                SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white)),
              ]),
            ),
          ),
        ),
      );
}
