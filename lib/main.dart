import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'config.dart';
import 'core/api.dart';
import 'core/session.dart';
import 'screens/login.dart';
import 'screens/shell.dart';
import 'screens/site_pick.dart';
import 'ui/scope.dart';
import 'ui/theme.dart';

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
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.dark));
  final session = Session(Api(portalUrl: kPortalUrl, mechUrl: kMainUrl, keep: SecureKeep()))..start();
  runApp(RclApp(session: session));
}

class RclApp extends StatelessWidget {
  const RclApp({super.key, required this.session});
  final Session session;
  @override
  Widget build(BuildContext context) => SessionScope(
        session: session,
        child: MaterialApp(
          title: 'RCL ERP',
          debugShowCheckedModeBanner: false,
          theme: appTheme(),
          home: const Gate(),
        ),
      );
}

/// Which screen: starting · sign-in · pick a site · the app.
class Gate extends StatelessWidget {
  const Gate({super.key});
  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: switch (s.stage) {
        Stage.starting => const _Starting(key: ValueKey('start')),
        Stage.signedOut => const LoginScreen(key: ValueKey('login')),
        Stage.pickSite => const SitePickScreen(key: ValueKey('site')),
        Stage.ready => Shell(key: ValueKey('app-${s.siteCode}')),
      },
    );
  }
}

class _Starting extends StatelessWidget {
  const _Starting({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.local_gas_station_rounded, size: 56, color: C.green),
            SizedBox(height: 18),
            Text('RCL ERP', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
            SizedBox(height: 18),
            SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3, color: C.green)),
          ]),
        ),
      );
}
