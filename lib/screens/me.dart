import 'package:flutter/material.dart';

import '../core/update.dart';
import '../ui/scope.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

/// Another of his sites (only those with Mechanical given to him on the Portal).
Future<void> pickSite(BuildContext context) async {
  final s = SessionScope.read(context);
  final code = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (c) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Padding(padding: EdgeInsets.fromLTRB(20, 18, 20, 6), child: TwoLang('Change site', 'site बदला')),
        for (final x in s.sites)
          ListTile(
            leading: Icon(x.code == s.siteCode ? Icons.radio_button_checked : Icons.radio_button_off, color: C.green),
            title: Text(x.name, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(x.code),
            onTap: () => Navigator.pop(c, x.code),
          ),
        const SizedBox(height: 10),
      ]),
    ),
  );
  if (code != null && code != s.siteCode) await s.switchSite(code);
}

class MeTab extends StatefulWidget {
  const MeTab({super.key, this.update});
  final AppUpdate? update;
  @override
  State<MeTab> createState() => _MeTabState();
}

class _MeTabState extends State<MeTab> {
  String version = '';
  bool checking = false;

  @override
  void initState() {
    super.initState();
    appVersion().then((v) => mounted ? setState(() => version = v) : null);
  }

  Future<void> _check() async {
    setState(() => checking = true);
    final u = await checkUpdate(SessionScope.read(context).api);
    if (!mounted) return;
    setState(() => checking = false);
    if (u == null) {
      toast(context, 'You have the newest version.');
    } else {
      await runUpdate(context, u);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    Widget row(IconData i, String t, String sub, {VoidCallback? onTap, Widget? trail}) => Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          child: ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: Icon(i, color: C.green),
            title: Text(t, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: sub.isEmpty ? null : Text(sub),
            trailing: trail ?? (onTap == null ? null : const Icon(Icons.chevron_right)),
            onTap: onTap,
          ),
        );
    return SafeArea(
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 24), children: [
        Row(children: [
          CircleAvatar(radius: 30, backgroundColor: C.green, child: Text(s.name.isEmpty ? '?' : s.name[0].toUpperCase(), style: const TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.w700))),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.name, style: Theme.of(context).textTheme.titleLarge),
              Text(s.email, style: const TextStyle(color: C.muted)),
              Text(s.admin ? 'Admin' : 'User', style: const TextStyle(color: C.greenDark, fontWeight: FontWeight.w600)),
            ]),
          ),
        ]),
        const SizedBox(height: 20),
        row(Icons.location_on_outlined, s.siteName, s.sites.length > 1 ? 'Tap to change site · site बदला' : s.siteCode, onTap: s.sites.length > 1 ? () => pickSite(context) : null),
        const SizedBox(height: 10),
        row(Icons.system_update_outlined, widget.update != null ? 'Update to ${widget.update!.version}' : 'Check for an update', version.isEmpty ? '' : 'This app: $version',
            onTap: checking ? null : (widget.update != null ? () => runUpdate(context, widget.update!) : _check),
            trail: checking ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: C.green)) : null),
        const SizedBox(height: 10),
        row(Icons.logout_rounded, 'Sign out', 'Signs out of the Portal and every module', onTap: () async {
          if (await ask(context, 'Sign out?', 'You will sign in again with your Portal email and password.', yes: 'Sign out')) await s.signOut();
        }),
      ]),
    );
  }
}
