import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'config.dart';
import 'core/api.dart';
import 'core/session.dart';
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

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.light));
  final session = Session(Api(portalUrl: kPortalUrl, keep: SecureKeep())..askApproval = askApprovalBox)..start();
  runApp(RclApp(session: session));
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
      title: const Text('In a submitted bill – send it to the Super Admin?'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(message.replaceFirst(RegExp(r'^(Line|Row) [^:]+: '), ''), style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 10),
          const Text('It is saved only when the Super Admin approves it. The bill is not changed – the difference comes in the next bill.', style: TextStyle(fontWeight: FontWeight.w600)),
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

class RclApp extends StatelessWidget {
  const RclApp({super.key, required this.session});
  final Session session;
  @override
  Widget build(BuildContext context) => SessionScope(
        session: session,
        child: LangScope(child: MaterialApp(
          navigatorKey: appNav,
          title: 'RCL ERP',
          debugShowCheckedModeBanner: false,
          theme: appTheme(),
          // his "Size of the text" (Settings) – on every screen of the app
          builder: (context, child) {
            final m = MediaQuery.of(context), k = SessionScope.of(context).textScale;
            return k == 1.0 ? child! : MediaQuery(data: m.copyWith(textScaler: TextScaler.linear(m.textScaler.scale(1) * k)), child: child!);
          },
          home: const Gate(),
        )),
      );
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
      },
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
                const Text('Mechanical Management ERP', style: TextStyle(fontSize: 14, color: Color(0xCCFFFFFF))),
                const SizedBox(height: 24),
                const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white)),
              ]),
            ),
          ),
        ),
      );
}
