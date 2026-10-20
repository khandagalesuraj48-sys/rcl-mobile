/* ME (picture 3, 14-10-2026): who is signed in and his role, the site (change it), the app's version and its update, sign out
 * (of the Portal and every module). (3.18.0) No web page in the app any more: every page of the web is the app's own screen.
 * (3.31.0, asked 20-10-2026 with his picture) the green top with his photo (✏️ – change it in My settings) and the robot; RCL ERP
 * and his role; the site; App Version; My Settings; Approvals; Help & Support; Sign out. No Rachana logo at the bottom any more. */
import 'dart:convert';

import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';

import '../core/update.dart';
import '../ui/ask_bot.dart';
import 'home.dart' show openHelp;
import '../ui/scope.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'approvals.dart';
import 'settings.dart';
import 'super_admin.dart';
import '../ui/t.dart';

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
      toast(context, bi('You have the newest version.', 'नवीनतम version आहे.'));
    } else {
      await runUpdate(context, u);
    }
  }

  Future<void> _signOut() async {
    final s = SessionScope.read(context);
    if (await ask(context, 'Sign out?', bi('You will be signed out of the Portal and every module.', 'Portal आणि सर्व modules मधून sign out होईल.'), yes: 'Sign out', danger: true)) await s.signOut();
  }

  Widget _row({required String pic, required String en, required String mr, String sub = '', Widget? trailing, VoidCallback? onTap, Color color = C.greenSoft, Color text = C.ink, Key? key}) => Padding(
        padding: const EdgeInsets.only(bottom: Sp.chips),
        child: Press(
          key: key,
          onTap: onTap,
          radius: 18,
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Container(width: 48, height: 48, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(14)), alignment: Alignment.center, child: Pic(pic, size: 30)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(en, mr: mr, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: text)),
                if (sub.isNotEmpty) Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: C.muted)),
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
    final role = s.superAdmin ? 'Super Admin' : (s.admin ? 'Admin' : 'User');
    void settings() => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));
    Widget chip(IconData icon, String t, {bool gold = false}) => Expanded(
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: gold ? C.goldLight : Colors.white.withValues(alpha: .28)),
            ),
            child: Row(children: [
              Icon(icon, size: 20, color: gold ? C.goldLight : Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text(t, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: gold ? C.goldLight : Colors.white))),
            ]),
          ),
        );
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
      child: ListView(padding: EdgeInsets.zero, children: [
        Container(
          padding: EdgeInsets.fromLTRB(Sp.edge, top + 14, Sp.edge, 44),
          decoration: const BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [C.greenLight, C.green, Color(0xFF2A6148)]),
          ),
          child: Column(children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(color: const Color(0xFFF3E6CC), shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: .85), width: 3)),
                alignment: Alignment.center,
                clipBehavior: Clip.antiAlias,
                child: s.pref('photo').startsWith('data:image')
                    ? Image.memory(base64Decode(s.pref('photo').split(',').last), fit: BoxFit.cover, width: 84, height: 84, gaplessPlayback: true)
                    : Text(initial, style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: C.greenDark)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white)),
                    Text(s.email, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, color: Color(0xE6FFFFFF))),
                  ]),
                ),
              ),
              IconButton(
                key: const Key('me-edit'),
                tooltip: tr('My settings'),
                onPressed: settings,
                style: IconButton.styleFrom(backgroundColor: Colors.white.withValues(alpha: .16), fixedSize: const Size(40, 40)),
                icon: const Icon(Icons.edit_outlined, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 6),
              const AskBot(size: 40, onLight: false),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              chip(Icons.apartment_rounded, 'RCL ERP'),
              const SizedBox(width: Sp.chips),
              chip(Icons.verified_user_rounded, role, gold: true),
            ]),
          ]),
        ),
        Transform.translate(
          offset: const Offset(0, -28),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Sp.edge),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _row(
                pic: 'round_pushpin',
                en: s.siteName,
                mr: '',
                color: C.redSoft,
                sub: s.sites.length > 1 ? bi('Tap to change site', 'साइट बदला') : bi('Your site', 'तुमची साइट'),
                onTap: s.sites.length > 1 ? () => s.pickAnotherSite() : null,
                trailing: s.sites.length > 1 ? null : const SizedBox.shrink(),
              ),
              // (3.17.0) the Super Admin's console of the whole system (the Portal's "Super Admin"), in the app's own screens
              if (s.superAdmin)
                _row(
                  key: const Key('me-super'),
                  pic: 'shield',
                  en: 'Super Admin',
                  mr: 'सुपर ॲडमिन',
                  sub: 'Users & access, sites, companies, modules, activity',
                  color: C.purpleSoft,
                  onTap: () => openSuperAdmin(context),
                ),
              _row(
                pic: 'mobile_phone',
                en: 'App Version',
                mr: 'ॲप आवृत्ती',
                sub: version.isEmpty ? 'RCL ERP' : 'RCL ERP · v$version',
                color: C.greenSoft,
                trailing: FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 38), padding: const EdgeInsets.symmetric(horizontal: 12), textStyle: const TextStyle(fontFamily: 'Rubik', fontSize: 13, fontWeight: FontWeight.w600)),
                  onPressed: checking ? null : _check,
                  child: checking ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)) : const Text('Check Update'),
                ),
              ),
              _row(pic: 'gear', en: 'My settings', mr: 'माझ्या सेटिंग्ज', sub: 'Language, default site, password', color: C.greenSoft, onTap: settings),
              // (update-114) Approvals – for everybody: what waits for him to approve (one or several at once), what he sent (waiting,
              // approved, rejected); the Super Admin also sets the verification rules there. (3.2.0) The app's own screens, live.
              _row(
                pic: 'clipboard',
                en: 'Approvals',
                mr: 'मंजुरी',
                sub: s.crForMe > 0
                    ? bi('${s.crForMe} waiting for you to approve', '${s.crForMe} तुमच्या मंजुरीसाठी थांबले आहेत')
                    : s.crWaiting > 0
                        ? bi('${s.crWaiting} waiting', '${s.crWaiting} थांबलेले')
                        : bi('Pending approvals', 'थांबलेल्या मंजुरी'),
                color: C.greenSoft,
                trailing: s.crForMe > 0
                    ? Row(mainAxisSize: MainAxisSize.min, children: [
                        Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3), decoration: BoxDecoration(color: C.gold, borderRadius: BorderRadius.circular(10)), child: Text('${s.crForMe}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13))),
                        const Icon(Icons.chevron_right_rounded, color: C.faint),
                      ])
                    : null,
                onTap: () async {
                  await openApprovals(context);      // (3.2.0) the app's own screen
                  s.loadApprovals();
                },
              ),
              // (3.1.7) entries kept on this phone with no network – sent by themselves when the network is back
              if (s.kept.isNotEmpty)
                _row(
                  pic: 'calendar',
                  en: 'Waiting on this phone',
                  mr: 'फोनवर थांबलेल्या',
                  sub: s.keptBad > 0 ? bi('${s.keptBad} not saved – open to see why', '${s.keptBad} सेव्ह झाल्या नाहीत – कारण पहा') : bi('${s.kept.length} to send when the network is back', 'नेटवर्क आल्यावर ${s.kept.length} पाठवायच्या'),
                  color: s.keptBad > 0 ? C.redSoft : C.amberSoft,
                  onTap: () => showModalBottomSheet<void>(context: context, isScrollControlled: true, useSafeArea: true, builder: (_) => const KeptSheet()),
                ),
              _row(key: const Key('me-help'), pic: 'robot', en: 'Help & Support', mr: 'मदत', sub: 'Ask the app, page guides', color: C.blueSoft, onTap: () => openHelp(context)),
              _row(pic: 'locked_with_key', en: 'Sign out', mr: 'साईन आउट करा', sub: 'Sign out from your account', color: C.redSoft, text: C.red, onTap: _signOut),
              const SizedBox(height: 8),
            ]),
          ),
        ),
      ]),
    );
  }
}

/// (3.1.7) The entries kept on this phone: each with its state; "Send now"; a refused one shows the server's words and can be deleted.
class KeptSheet extends StatefulWidget {
  const KeptSheet({super.key});
  @override
  State<KeptSheet> createState() => _KeptSheetState();
}

class _KeptSheetState extends State<KeptSheet> {
  bool busy = false;
  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    final list = s.kept.where((x) => x['site'] == (s.site?.code ?? '')).toList();
    return SizedBox(
      height: MediaQuery.of(context).size.height * .8,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Padding(padding: EdgeInsets.fromLTRB(20, 4, 20, 4), child: TwoLang('Waiting on this phone', 'फोनवर थांबलेल्या एन्ट्री', size: 20, weight: FontWeight.w700)),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
          child: Text(bi('Saved with no network. They are sent by themselves when the network is back (each one once).', 'नेटवर्क नसताना ठेवलेल्या. नेटवर्क आल्यावर आपोआप पाठवल्या जातात (प्रत्येक एकदाच).'), style: const TextStyle(color: C.muted, fontSize: 13.5)),
        ),
        Expanded(
          child: list.isEmpty
              ? const EmptyState('Nothing waiting', 'Everything was sent.', pic: 'clipboard')
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final x = list[i], bad = x['state'] == 'refused';
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: bad ? C.redSoft : C.bg, borderRadius: BorderRadius.circular(16)),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Icon(bad ? Icons.error_outline_rounded : Icons.hourglass_top_rounded, color: bad ? C.red : C.amber),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('${x['label']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                            Text(bad ? tr('Not saved: ${x['msg']}') : bi('Waiting for the network', 'नेटवर्कची वाट'), style: TextStyle(fontSize: 13, color: bad ? C.red : C.muted)),
                          ]),
                        ),
                        if (bad)
                          IconButton(
                            tooltip: tr('Delete'),
                            icon: const Icon(Icons.delete_outline_rounded, color: C.red),
                            onPressed: () async {
                              if (await ask(context, 'Delete it?', bi('This entry was not saved. Delete it from this phone? (Enter it again if it is needed.)', 'ही एन्ट्री सेव्ह झाली नाही. फोनवरून काढायची?'), yes: 'Delete', danger: true)) {
                                await s.dropKept('${x['rid']}');
                              }
                            },
                          ),
                      ]),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: FilledButton.icon(
            onPressed: busy || list.isEmpty
                ? null
                : () async {
                    setState(() => busy = true);
                    await s.sendKept(again: true);
                    if (mounted) setState(() => busy = false);
                  },
            icon: busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)) : const Icon(Icons.send_rounded),
            label: Text(busy ? tr('Sending…') : tr('Send now')),
          ),
        ),
      ]),
    );
  }
}
