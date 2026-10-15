/* ME (picture 3, 14-10-2026): who is signed in and his role, the site (change it), the app's version and its update, the full
 * web ERP, sign out (of the Portal and every module). */
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/update.dart';
import '../ui/brand.dart';
import '../ui/scope.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import '../web/web_host.dart';
import 'settings.dart';

class MeTab extends StatefulWidget {
  const MeTab({super.key});
  @override
  State<MeTab> createState() => _MeTabState();
}

class _MeTabState extends State<MeTab> {
  String version = '';
  bool checking = false;

  @override
  void initState() {
    super.initState();
    appVersion().then((v) {
      if (mounted) setState(() => version = v);
    });
  }

  Future<void> _check() async {
    final s = SessionScope.read(context);
    setState(() => checking = true);
    final u = await checkUpdate(s.api);
    if (!mounted) return;
    setState(() => checking = false);
    if (u == null) {
      toast(context, 'You have the newest version. · नवीनतम version आहे.');
    } else {
      await runUpdate(context, u);
    }
  }

  Future<void> _signOut() async {
    final s = SessionScope.read(context);
    if (await ask(context, 'Sign out?', 'You will be signed out of the Portal and every module. · Portal आणि सर्व modules मधून sign out होईल.', yes: 'Sign out', danger: true)) await s.signOut();
  }

  Widget _row({required String pic, required String en, required String mr, String sub = '', Widget? trailing, VoidCallback? onTap, Color color = C.greenSoft, Color text = C.ink}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Press(
          onTap: onTap,
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(width: 56, height: 56, decoration: BoxDecoration(color: color, shape: BoxShape.circle), alignment: Alignment.center, child: Pic(pic, size: 34)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                TwoLang(en, mr, size: 16.5, weight: FontWeight.w700, color: text),
                if (sub.isNotEmpty) Text(sub, style: const TextStyle(fontSize: 13, color: C.muted)),
              ]),
            ),
            trailing ?? const Icon(Icons.chevron_right_rounded, color: C.faint),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    final top = MediaQuery.of(context).padding.top;
    final initial = s.name.trim().isEmpty ? '?' : s.name.trim()[0].toUpperCase();
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
      child: ListView(padding: EdgeInsets.zero, children: [
        HeroScene(
          height: 200 + top,
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, top + 22, 20, 0),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(color: C.green, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 4), boxShadow: softShadow(.3)),
                alignment: Alignment.center,
                clipBehavior: Clip.antiAlias,
                child: s.pref('photo').startsWith('data:image')
                    ? Image.memory(base64Decode(s.pref('photo').split(',').last), fit: BoxFit.cover, width: 92, height: 92, gaplessPlayback: true)
                    : Text(initial, style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800, color: Colors.white)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const SizedBox(height: 6),
                  Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white)),
                  Text(s.email, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14.5, color: Color(0xE6FFFFFF))),
                  const SizedBox(height: 8),
                  Pill(s.admin ? 'Admin' : 'User', icon: Icons.verified_user_rounded, color: Colors.white, bg: const Color(0x55FFFFFF)),
                ]),
              ),
            ]),
          ),
        ),
        Transform.translate(
          offset: const Offset(0, -26),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _row(
                pic: 'round_pushpin',
                en: s.siteName,
                mr: s.sites.length > 1 ? 'Site बदला · Tap to change site' : 'Your site · तुमची site',
                onTap: s.sites.length > 1 ? () => s.pickAnotherSite() : null,
                trailing: s.sites.length > 1 ? null : const SizedBox.shrink(),
              ),
              const Padding(padding: EdgeInsets.fromLTRB(6, 8, 6, 10), child: Text('App', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: C.muted))),
              _row(
                pic: 'mobile_phone',
                en: 'App Version',
                mr: 'ॲप आवृत्ती',
                sub: version,
                color: C.blueSoft,
                trailing: FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 40), padding: const EdgeInsets.symmetric(horizontal: 12), textStyle: const TextStyle(fontFamily: 'Rubik', fontSize: 13.5, fontWeight: FontWeight.w600)),
                  onPressed: checking ? null : _check,
                  child: checking ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)) : const Text('Check Update'),
                ),
              ),
              _row(pic: 'gear', en: 'My settings', mr: 'माझ्या सेटिंग्ज', sub: 'Default site, shift, diesel place, text size, password', color: C.slateSoft, onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()))),
              // (14-10-2026) Approvals: the Super Admin approves there; a user sees the changes he sent (waiting / approved / rejected)
              if (s.superAdmin || s.canEdit('Log Book') || s.canEdit('Diesel Issue'))
                _row(pic: 'bell', en: 'Approvals', mr: 'मंजुरी', sub: s.superAdmin ? 'Changes of a submitted bill sent by the users – approve or reject' : 'What you sent to the Super Admin – waiting, approved, rejected', color: C.blueSoft, onTap: () => openWeb(context, 'Approvals', 'approvals', pic: 'bell')),
              _row(pic: 'office_building', en: 'Full web ERP', mr: 'पूर्ण web ERP', sub: 'Every page of the web, inside the app', color: C.amberSoft, onTap: () => openWeb(context, 'Web ERP', 'dash', pic: 'office_building')),
              const SizedBox(height: 6),
              _row(pic: 'locked_with_key', en: 'Sign out', mr: 'साईन आउट करा', sub: 'Signs out of the Portal and every module', color: C.redSoft, text: C.red, onTap: _signOut),
              const SizedBox(height: 18),
              const Center(child: Opacity(opacity: .6, child: RachanaLogo(height: 34))),
              const SizedBox(height: 8),
            ]),
          ),
        ),
      ]),
    );
  }
}
