/* "ME" OF A PERSON WITH HR ONLY, and the pages behind it (3.108.0 – the screens he sent back on 12-11-2026; asked: "me madhe
 * employee details astil document upload astil salary slips ani baki je required ahe te … me madhun user lanuadge setting kru
 * shakel marathi ki hindi ki english"):
 *   Me            – who he is (name, code, designation, site), how complete his profile is
 *   My details    – his record to READ: he changes nothing here, the HR office does (PF / bank numbers come masked)
 *   My documents  – the papers expected of him: which are there, which are missing; he attaches one himself (camera, gallery,
 *                   a PDF) and opens his own
 *   Salary slips  – they come here when the HR office starts payroll (nothing is made up before)
 *   My phone      – the phone his attendance is tied to
 *   Language      – English / मराठी / हिन्दी: the whole app in one language
 *   E-mail and password – verify my e-mail, change my password (the Portal's – one for everything)
 * The server (rcl-hr, lib/act_self.js) gives only the record of the employee the sign-in is. */
import 'dart:typed_data';

import 'package:flutter/material.dart' hide Text;
import 'package:flutter/material.dart' as m show Text;
import 'package:image/image.dart' as img;
import 'package:url_launcher/url_launcher.dart';

import '../core/api.dart' show ApiError;
import '../core/attend.dart' show AttendKit;
import '../core/attend_pdf.dart' show payslipPdf;
import '../core/attend_remind.dart';
import '../core/hr_cache.dart';
import '../core/update.dart';
import '../ui/done_pop.dart';
import '../ui/hr_look.dart';
import '../ui/hr_skin.dart';
import '../ui/motion.dart';
import '../ui/scope.dart';
import '../ui/t.dart';
import '../ui/design.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'attach_box.dart' show pickAttFiles;
import 'consent_gate.dart' show showConsent;
import 'attend_reqs.dart' show HrAsk;
import 'attendance.dart' show attendPdfLogo, attendPdfOut, hrModule, hrSite;
import 'email_verify.dart';
import 'hr_office.dart';
import 'hr_shell.dart' show initials;

String _t(String en, String mr) => Lang.i.pair(en, mr);
const kMeSky = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF184833), Color(0xFF277E55), Color(0xFF59B585)], stops: <double>[0, .7, 1]);
const _cat = {'staff': 'Staff', 'operator': 'Operator', 'driver': 'Driver', 'labour': 'Labour'};

/// One line of a list card: a sign in its tile, the title, a small line, › (or nothing).
Widget _li({required Key key, required String sign, IconData? icon, required Color c, required Color soft, required String en, required String mr, String sub = '', Color? ink, bool arrow = true, bool last = false, VoidCallback? onTap}) {
  final (Color fg, Color bg) = sk.tint(c, soft);
  return GestureDetector(
    key: key,
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(border: last ? null : Border(bottom: BorderSide(color: sk.hair))),
      child: Row(children: [
        Container(width: 36, height: 36, alignment: Alignment.center, decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)), child: icon != null ? Icon(icon, size: 19, color: fg) : m.Text(sign, style: TextStyle(fontFamily: 'Montserrat', fontSize: 13, fontWeight: FontWeight.w800, color: fg))),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(en, mr: mr, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: ink ?? sk.ink)),
            if (sub.isNotEmpty) m.Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: sk.muted, height: 1.25)),
          ]),
        ),
        if (arrow) Icon(Icons.chevron_right_rounded, size: 20, color: sk.blankInk),
      ]),
    ),
  );
}

class HrMeTab extends StatelessWidget {
  const HrMeTab({super.key, required this.mine, required this.day, required this.ask, required this.onDocs, required this.onPhoto, required this.reload, this.inErp = false});

  /// (3.115.0) inside the full app: what belongs to the whole app stays in the ERP's own Me
  final bool inErp;
  final Map<String, dynamic>? mine, day;
  final HrAsk ask;
  final VoidCallback onDocs;

  /// he takes or chooses his photo; true when a new one was set
  final Future<bool> Function() onPhoto;
  final Future<void> Function() reload;

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context), e = (mine?['employee'] as Map?) ?? (day?['employee'] as Map?) ?? const {};
    final name = '${e['name'] ?? s.name}', role = '${e['designation'] ?? ''}'.isNotEmpty ? '${e['designation']}' : (_cat['${e['category'] ?? ''}'] ?? '');
    final pct = (mine?['complete'] as Map?)?['pct'], miss = ((mine?['docs'] as Map?)?['missing'] as List? ?? const []).length;
    final team = mine?['team'] is num && (mine!['team'] as num) > 0, boss = '${e['manager'] ?? ''}', code = '${e['code'] ?? ''}';
    final pend = (mine?['policies'] as Map?)?['pending'], pol = pend is num && pend > 0 ? pend.toInt() : 0;
    final lang = switch (LangScope.of(context).code) { 'mr' => 'मराठी', 'hi' => 'हिन्दी', _ => 'English' };
    void open(Widget page) => Navigator.of(context).push(hrRoute<void>(page));
    final goldInk = sk.dark ? const Color(0xFFF2CC62) : const Color(0xFFA9741A);

    // one line of the card: "Code   E00012"
    Widget fact(String en, String mr, String v, String key) => Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Row(children: [
            SizedBox(width: 78, child: Text(en, mr: mr, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: sk.faint, fontWeight: FontWeight.w600))),
            Expanded(child: m.Text(v, key: Key(key), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: sk.ink))),
          ]),
        );

    // (3.154.0 – "me card 2 he perfect aahe") MY RECORD: one card, a gold-ringed round sign for each; a red count where
    // something waits for him
    Widget round(String key, IconData icon, Color c, String en, String mr, {int count = 0, required VoidCallback onTap}) => Expanded(
          child: GestureDetector(
            key: Key(key),
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Bounce(
              to: .94,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Stack(clipBehavior: Clip.none, children: [
                  Container(
                    width: 58,
                    height: 58,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: sk.dark ? const Color(0xFF1A2140) : const Color(0xFFF8F9FC), border: Border.all(color: const Color(0xFFDDAD40).withValues(alpha: .65), width: 1.3)),
                    child: Icon(icon, size: 25, color: sk.dark ? Color.lerp(c, Colors.white, .3) : c),
                  ),
                  if (count > 0)
                    Positioned(
                      right: -3,
                      top: -3,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 20),
                        height: 20,
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: sk.dark ? const Color(0xFFFF7A70) : const Color(0xFFC22A1B), borderRadius: BorderRadius.circular(10), border: Border.all(color: sk.card, width: 1.5)),
                        child: m.Text('$count', key: Key('$key-n'), style: const TextStyle(fontFamily: 'Montserrat', fontSize: 10.5, fontWeight: FontWeight.w800, color: Colors.white, height: 1)),
                      ),
                    ),
                ]),
                const SizedBox(height: 8),
                Text(en, mr: mr, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: sk.ink, height: 1.2)),
              ]),
            ),
          ),
        );

    // (3.160.0, rcl-hr step 21) COMPANY: Our team and Approvals for everybody; Transfers and Release phone for who has HR's office
    // (the server refuses what he may not do, with its own words)
    final office = hrModule(s)?.key == 'hr';
    final work = <Widget>[
      _pill(key: const Key('me-ourteam'), icon: Icons.groups_2_outlined, en: 'Our team', mr: 'आपली टीम', onTap: () => open(OurTeamScreen(ask: ask))),
      _pill(key: const Key('me-approvals'), icon: Icons.fact_check_outlined, en: 'Approvals', mr: 'Approvals', onTap: () => open(ApprovalsScreen(ask: ask))),
      if (office) _pill(key: const Key('me-transfers'), icon: Icons.swap_horiz_rounded, en: 'Transfers', mr: 'Transfers', onTap: () => open(TransfersScreen(ask: ask))),
      if (office) _pill(key: const Key('me-phones'), icon: Icons.phonelink_erase_outlined, en: 'Release phone', mr: 'Phone release', onTap: () => open(ReleasePhoneScreen(ask: ask))),
    ];
    // APP: a pill for each, two in a row (one left over: the whole row)
    final pills = <Widget>[
      _pill(key: const Key('me-lang'), icon: Icons.translate_rounded, en: 'Language', mr: 'भाषा', sub: lang, onTap: () => open(const LanguageScreen())),
      if (!inErp) _pill(key: const Key('me-account'), icon: Icons.mail_outline_rounded, en: 'E-mail & password', mr: 'E-mail व password', onTap: () => open(const AccountScreen())),
      // (20-11-2026) the app's terms / location notice and the Privacy Policy – always reachable; "Allow" again from here
      _pill(key: const Key('me-privacy'), icon: Icons.verified_user_outlined, en: 'Privacy', mr: 'Privacy', onTap: () => showConsent(context)),
      // (the look's name goes with them: a pill that keeps its own state is drawn again when the look changes)
      _RemindRow(look: sk.name),
      if (!inErp && s.sites.length > 1) _pill(key: const Key('me-site'), icon: Icons.swap_horiz_rounded, en: 'Change site', mr: 'Site बदला', sub: s.siteName, onTap: s.pickAnotherSite),
      if (!inErp) _UpdateRow(look: sk.name),
    ];
    return Container(
      decoration: BoxDecoration(gradient: sk.pageFill),
      child: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: reload,
          child: ListView(key: const Key('me-page'), padding: EdgeInsets.fromLTRB(16, 14, 16, 24 + MediaQuery.paddingOf(context).bottom), children: [
            // (3.154.0, his choice of 21-11-2026 – "M1 ID card"; "login page chi ui ashi me madhe nko, ekde purn wegle asawi") WHO HE
            // IS, as his identity card: his photo (a touch sets it), his name and designation, his code, his site, the person he
            // reports to, and how complete his record is. (3.158.0, asked 21-11-2026 with his picture: "warti te sketchline and lion
            // logo nko aahe te remove kr") the gold strip with the product's name and its lion is gone
            Container(
              key: const Key('me-card'),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(color: sk.card, borderRadius: BorderRadius.circular(26), border: Border.all(color: sk.dark ? const Color(0x66E6B94E) : (sk.cardLine ?? sk.line)), boxShadow: [BoxShadow(color: sk.dark ? const Color(0x66000000) : const Color(0x1F141E3C), blurRadius: 26, offset: const Offset(0, 12))]),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      // (3.109.0) his own photo – a touch sets it
                      GestureDetector(
                        key: const Key('me-face'),
                        behavior: HitTestBehavior.opaque,
                        onTap: onPhoto,
                        child: Stack(clipBehavior: Clip.none, children: [
                          hrFace(name, '${mine?['photo'] ?? ''}', size: 92, radius: 20, bg: const Color(0xFF14224A), border: const Color(0xFFDDAD40), ink: const Color(0xFFF3D889), letters: 30),
                          Positioned(right: -6, bottom: -6, child: Container(width: 28, height: 28, alignment: Alignment.center, decoration: BoxDecoration(gradient: Sk.goldFill, shape: BoxShape.circle, border: Border.all(color: sk.card, width: 2.5)), child: const Icon(Icons.photo_camera_outlined, size: 14, color: Sk.goldInk))),
                        ]),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                          m.Text(name, key: const Key('me-name'), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: 'Montserrat', fontSize: 19, fontWeight: FontWeight.w800, color: sk.ink, height: 1.15)),
                          if (role.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2, bottom: 4), child: m.Text(role, key: const Key('me-role'), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: goldInk))),
                          if (code.isNotEmpty) fact('Code', 'Code', code, 'me-code'),
                          fact('Site', 'Site', hrSite(s)?.name ?? s.siteName, 'me-site-name'), // (3.141.0) his HR site
                          if (boss.isNotEmpty) fact('Reports to', 'Reporting', boss, 'me-boss'),
                        ]),
                      ),
                    ]),
                    if (pct is num) ...[
                      const SizedBox(height: 18),
                      Row(children: [
                        Expanded(child: Text('Profile complete', mr: 'Profile पूर्ण', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: sk.muted))),
                        m.Text('${pct.round()}%', key: const Key('me-pct'), style: TextStyle(fontFamily: 'Montserrat', fontSize: 12.5, fontWeight: FontWeight.w800, color: sk.muted)),
                      ]),
                      const SizedBox(height: 7),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Stack(children: [
                          Container(height: 7, color: sk.hair),
                          FractionallySizedBox(widthFactor: (pct / 100).clamp(0.0, 1.0).toDouble(), child: Container(height: 7, decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFC9960A), Color(0xFFF7DE8E)]), borderRadius: BorderRadius.circular(4)))),
                        ]),
                      ),
                    ],
                  ]),
                ),
              ]),
            ),
            _head('My record', 'माझी नोंद'),
            Container(
              padding: const EdgeInsets.fromLTRB(6, 18, 6, 16),
              decoration: sk.box(radius: 26),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                round('me-details', Icons.info_outline_rounded, const Color(0xFF1F5FBF), 'My details', 'माझी माहिती', onTap: () => open(MyDetailsScreen(mine: mine, day: day, onPhoto: onPhoto))),
                round('me-docs', Icons.description_outlined, const Color(0xFF0F7A45), 'My documents', 'माझी कागदपत्रे', count: miss, onTap: onDocs),
                // (3.135.0, rcl-hr step 15) the company's policies: he reads and accepts the version in force himself
                round('me-policies', Icons.verified_user_outlined, const Color(0xFF7B3FD0), 'Company policies', 'Company policies', count: pol, onTap: () async {
                  await Navigator.of(context).push(hrRoute<void>(CompanyPoliciesScreen(ask: ask)));
                  await reload();
                }),
                // (3.139.0, rcl-hr Phase 6) a reporting manager's dashboard – only when people report to him
                if (team) round('me-team', Icons.groups_outlined, const Color(0xFFA9741A), 'My team', 'माझी टीम', onTap: () => open(MyTeamScreen(ask: ask))),
              ]),
            ),
            _head('Company', 'कंपनी'),
            for (var i = 0; i < work.length; i += 2)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: i + 1 < work.length ? Row(children: [Expanded(child: work[i]), const SizedBox(width: 10), Expanded(child: work[i + 1])]) : work[i],
              ),
            _head('App', 'App'),
            for (var i = 0; i < pills.length; i += 2)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: i + 1 < pills.length ? Row(children: [Expanded(child: pills[i]), const SizedBox(width: 10), Expanded(child: pills[i + 1])]) : pills[i],
              ),
            if (!inErp) ...[
              const SizedBox(height: 6),
              GestureDetector(
                key: const Key('me-out'),
                behavior: HitTestBehavior.opaque,
                onTap: () async {
                  if (await _askSignOut(context)) await s.signOut();
                },
                child: Container(
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: sk.dark ? const Color(0xFF2A1A28) : const Color(0xFFFBE4E1), borderRadius: BorderRadius.circular(22)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.logout_rounded, size: 20, color: sk.dark ? const Color(0xFFFF7A70) : const Color(0xFFC22A1B)),
                    const SizedBox(width: 10),
                    Text('Sign out', mr: 'Sign out', style: TextStyle(fontFamily: 'Montserrat', fontSize: 15, fontWeight: FontWeight.w800, color: sk.dark ? const Color(0xFFFF7A70) : const Color(0xFFC22A1B))),
                  ]),
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}

/// The name of a part of Me ("My record", "App").
Widget _head(String en, String mr) => Padding(padding: const EdgeInsets.fromLTRB(4, 22, 4, 10), child: Text(en, mr: mr, style: TextStyle(fontFamily: 'Montserrat', fontSize: 15, fontWeight: FontWeight.w800, color: sk.muted)));

/// A pill of "App": its sign in a round tile, its name, a small word of where it stands.
Widget _pill({required Key key, required IconData icon, required String en, required String mr, String sub = '', Color? tone, VoidCallback? onTap}) {
  final c = tone ?? (sk.dark ? const Color(0xFFF2CC62) : const Color(0xFFA9741A));
  return GestureDetector(
    key: key,
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Bounce(
      to: .96,
      child: Container(
        height: 58,
        padding: const EdgeInsets.fromLTRB(10, 0, 14, 0),
        decoration: sk.box(radius: 29),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(width: 38, height: 38, alignment: Alignment.center, decoration: BoxDecoration(color: sk.blank, shape: BoxShape.circle), child: Icon(icon, size: 19, color: c)),
          const SizedBox(width: 10),
          Flexible(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(en, mr: mr, maxLines: sub.isEmpty ? 2 : 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: sk.ink, height: 1.15)),
              if (sub.isNotEmpty) m.Text(sub, key: Key('${(key as ValueKey<String>).value}-st'), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: sk.muted, height: 1.2)),
            ]),
          ),
        ]),
      ),
    ),
  );
}

Future<bool> _askSignOut(BuildContext context) => ask(context, 'Sign out?', _t('You will be signed out of the app.', 'App मधून sign out होईल.'), yes: 'Sign out', danger: true);

/// MY DETAILS – read only. (3.153.0, asked 20-11-2026: "my photo my details he weg wegle aahe he ektr kr … my phone he my details
/// madhech ghe") his photo (he takes or chooses it here) on top, then what the HR office has of him, then his phone of attendance.
class MyDetailsScreen extends StatelessWidget {
  const MyDetailsScreen({super.key, required this.mine, this.day, this.onPhoto});
  final Map<String, dynamic>? mine, day;
  final Future<bool> Function()? onPhoto;
  @override
  Widget build(BuildContext context) {
    final groups = [for (final g in (mine?['details'] as List? ?? const []).whereType<Map>()) g];
    final missing = [for (final x in ((mine?['complete'] as Map?)?['missing'] as List? ?? const [])) '$x'];
    final e = (mine?['employee'] as Map?) ?? const {}, name = '${e['name'] ?? SessionScope.of(context).name}', has = '${mine?['photo'] ?? ''}'.isNotEmpty;
    final phone = (mine?['phone'] as Map?) ?? const {}, bound = phone['bound'] == true, here = '${day?['phone'] ?? ''}';
    return Scaffold(
      appBar: hrHead(context, sky: kMeSky, title: 'My details', mr: 'माझी माहिती', height: 100, below: [
        Text('What the HR office has of you. To change a detail, ask the HR office.', mr: 'HR office कडे तुमची असलेली माहिती. बदलासाठी HR office ला सांगा.', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, height: 1.3, color: sk.onHeadSoft)),
      ]),
      body: ListView(key: const Key('det-page'), padding: const EdgeInsets.fromLTRB(16, 14, 16, 40), children: [
        if (onPhoto != null) ...[
          hrCard(key: const Key('det-photo'), [
            Row(children: [
              hrFace(name, '${mine?['photo'] ?? ''}', size: 64, radius: 32, bg: sk.dark ? sk.blank : const Color(0xFF0F1F3D), border: const Color(0xFFDDAD40), ink: sk.dark ? sk.accent : Colors.white, letters: 21),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text('My photo', mr: 'माझा photo', style: TextStyle(fontFamily: 'Montserrat', fontSize: 15, fontWeight: FontWeight.w800, color: sk.ink)),
                  m.Text(has ? _t('Shown on your profile', 'तुमच्या profile वर दिसतो') : _t('Take or choose – shown on your profile', 'काढा किंवा निवडा – profile वर दिसेल'), style: TextStyle(fontSize: 12, color: sk.muted, height: 1.3)),
                ]),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                key: const Key('me-photo'),
                behavior: HitTestBehavior.opaque,
                onTap: () async {
                  // a new photo: back to Me, where it shows
                  if (await onPhoto!() && context.mounted) Navigator.of(context).maybePop();
                },
                child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9), decoration: BoxDecoration(color: sk.accent, borderRadius: BorderRadius.circular(99)), child: m.Text(has ? _t('Change', 'बदला') : _t('Set', 'ठेवा'), style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: sk.onAccent))),
              ),
            ]),
          ]),
          const SizedBox(height: 12),
        ],
        if (mine == null) hrNote(_t('Your details could not be read – pull down on Me to try again.', 'माहिती वाचता आली नाही – Me वर खाली ओढून पुन्हा करा.')),
        if (missing.isNotEmpty) ...[hrNote('${_t('Still needed', 'अजून हवे')}: ${missing.join(', ')}', key: const Key('det-missing')), const SizedBox(height: 12)],
        for (final g in groups) ...[
          hrCard(key: Key('det-${g['name']}'), [
            m.Text(tr('${g['name']}'), style: TextStyle(fontFamily: 'Montserrat', fontSize: 15, fontWeight: FontWeight.w800, color: sk.ink)),
            const SizedBox(height: 6),
            for (final r in (g['rows'] as List? ?? const []).whereType<Map>())
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(flex: 5, child: m.Text(tr('${r['label']}'), style: TextStyle(fontSize: 13, color: sk.muted, height: 1.3))),
                  const SizedBox(width: 10),
                  Expanded(flex: 6, child: m.Text('${r['value']}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: sk.ink, height: 1.3))),
                ]),
              ),
          ]),
          const SizedBox(height: 12),
        ],
        if (onPhoto != null)
          hrCard(key: const Key('me-phone'), [
            hrTitle('My phone', 'माझा phone'),
            m.Text(bound ? _t('Registered for attendance', 'हजेरीसाठी नोंदलेला') : _t('No phone registered yet', 'अजून phone नोंदलेला नाही'), style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: sk.ink)),
            if (bound && '${phone['model'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: m.Text('${phone['model']}', key: const Key('phone-model'), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: sk.ink))),
            if (here == 'this') Padding(padding: const EdgeInsets.only(top: 8), child: stateChip('This phone', 'a')) else if (here == 'other') Padding(padding: const EdgeInsets.only(top: 8), child: stateChip('Another phone', 'x')),
            const SizedBox(height: 8),
            Text(
                bound
                    ? 'Your attendance is marked only from this one phone. Another phone works only after the HR Admin releases this one.'
                    : 'The phone you mark your first attendance with becomes your phone. Afterwards another phone works only after the HR Admin releases it.',
                mr: bound ? 'तुमची हजेरी फक्त या एका phone वरून लागते. HR Admin ने हा सोडल्यावरच दुसरा phone चालतो.' : 'ज्या phone वरून पहिली हजेरी लावाल तो तुमचा phone होतो. नंतर HR Admin ने सोडल्यावरच दुसरा phone चालतो.',
                style: TextStyle(fontSize: 13, color: sk.muted, height: 1.5)),
          ]),
      ]),
    );
  }
}

/// MY DOCUMENTS – what is there, what is missing; he attaches a paper himself and opens his own.
class MyDocsScreen extends StatefulWidget {
  const MyDocsScreen({super.key, required this.ask});
  final HrAsk ask;
  @override
  State<MyDocsScreen> createState() => _MyDocsScreenState();
}

class _MyDocsScreenState extends State<MyDocsScreen> {
  Map<String, dynamic>? data;
  String err = '', busy = ''; // busy: the kind being sent
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// (3.154.0) what was read the last time is shown at once; the server's answer takes its place (core/hr_cache.dart)
  Future<void> _load() async {
    if (data == null) {
      final k = await HrCache.read('myDocs');
      if (!mounted) return;
      if (k != null && data == null) {
        setState(() {
          data = k;
          loading = false;
        });
      }
    }
    try {
      final j = await widget.ask({'action': 'myDocs'});
      HrCache.put('myDocs', j);
      if (!mounted) return;
      setState(() {
        data = j;
        loading = false;
        err = '';
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          // (3.157.0) the papers are on the page (what was read before) and only the network did not answer: nothing red
          err = e is ApiError && e.code == 'net' && data != null ? '' : errText(e);
        });
      }
    }
  }

  static (Uint8List, String)? _ready(String name, Uint8List raw) => docReady(name, raw);

  /// [replaces]: a rejected paper this new one takes the place of (it stays in his record)
  Future<void> _add(Map kind, {String replaces = ''}) async {
    if (busy.isNotEmpty) return;
    final how = await showModalBottomSheet<String>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 6), child: Align(alignment: Alignment.centerLeft, child: m.Text(tr('${kind['name']}'), style: TextStyle(fontFamily: 'Montserrat', fontSize: 16, fontWeight: FontWeight.w800, color: sk.ink)))),
          ListTile(key: const Key('doc-camera'), leading: const Icon(Icons.photo_camera_rounded), title: const Text('Take a photo', mr: 'Photo काढा'), onTap: () => Navigator.pop(c, 'camera')),
          ListTile(key: const Key('doc-gallery'), leading: const Icon(Icons.photo_library_rounded), title: const Text('Choose a photo', mr: 'Photo निवडा'), onTap: () => Navigator.pop(c, 'gallery')),
          ListTile(key: const Key('doc-pdf'), leading: const Icon(Icons.picture_as_pdf_rounded), title: const Text('Choose a PDF', mr: 'PDF निवडा'), onTap: () => Navigator.pop(c, 'pdf')),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (how == null || !mounted) return;
    setState(() {
      busy = '${kind['key']}';
      err = '';
    });
    try {
      final got = await pickAttFiles(how, 1);
      if (got.isEmpty) return;
      final f = _ready(got.first.name, got.first.bytes);
      if (f == null) throw ApiError('This file could not be read – a photo or a PDF.');
      final u = await widget.ask({'action': 'myDocUploadUrl', 'kind': kind['key'], 'type': f.$2, 'bytes': f.$1.length});
      if (!mounted) return;
      await SessionScope.read(context).api.hrFile('${u['url']}', f.$1, f.$2);
      await widget.ask({'action': 'myDocAdd', 'kind': kind['key'], 'path': u['path'], 'bytes': f.$1.length, if (replaces.isNotEmpty) 'replaces': replaces});
      await _load();
      if (mounted) donePop(context, _t('Document attached', 'कागदपत्र जोडले'));
    } catch (e) {
      if (mounted) setState(() => err = errText(e));
    } finally {
      if (mounted) setState(() => busy = '');
    }
  }

  /// (3.159.0) his own paper: what he can do with it
  Future<void> _more(Map kind, Map d) async {
    if (busy.isNotEmpty) return;
    final what = await showModalBottomSheet<String>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 6), child: Align(alignment: Alignment.centerLeft, child: m.Text(tr('${kind['name']}'), style: const TextStyle(fontFamily: 'Montserrat', fontSize: 16, fontWeight: FontWeight.w800)))),
          ListTile(key: const Key('doc-m-open'), leading: const Icon(Icons.open_in_new_rounded), title: const Text('Open', mr: 'उघडा'), onTap: () => Navigator.pop(c, 'open')),
          ListTile(key: const Key('doc-m-edit'), leading: const Icon(Icons.edit_outlined), title: const Text('Edit its number and dates', mr: 'नंबर आणि तारखा बदला'), onTap: () => Navigator.pop(c, 'edit')),
          ListTile(key: const Key('doc-m-change'), leading: const Icon(Icons.swap_horiz_rounded), title: const Text('Change – attach a new file in its place', mr: 'Change – त्याच्या जागी नवीन file जोडा'), onTap: () => Navigator.pop(c, 'change')),
          ListTile(key: const Key('doc-m-delete'), leading: const Icon(Icons.delete_outline_rounded, color: Color(0xFFC22A1B)), title: const Text('Delete', mr: 'Delete करा'), onTap: () => Navigator.pop(c, 'delete')),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (what == null || !mounted) return;
    if (what == 'open') return _open(d);
    if (what == 'edit') return _edit(kind, d);
    if (what == 'change') return _add(kind, replaces: '${d['id'] ?? ''}');
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete this document?', mr: 'हे कागदपत्र delete करायचं?'),
        content: const Text('It leaves your list. You can attach a new one any time.', mr: 'ते तुमच्या यादीतून जाईल. नवीन कधीही जोडता येईल.'),
        actions: [
          TextButton(key: const Key('doc-del-no'), onPressed: () => Navigator.pop(c, false), child: const Text('No', mr: 'नाही')),
          TextButton(key: const Key('doc-del-yes'), onPressed: () => Navigator.pop(c, true), child: const Text('Yes, delete', mr: 'हो, delete करा')),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    await _do({'action': 'myDocDelete', 'doc': d['id']}, _t('Document deleted', 'कागदपत्र delete झाले'));
  }

  /// one change of his own paper: sent, the list read again, said; what the server refuses is shown on the page
  Future<void> _do(Map<String, dynamic> body, String said) async {
    setState(() => err = '');
    try {
      await widget.ask(body);
      await _load();
      if (mounted) donePop(context, said);
    } catch (e) {
      if (mounted) setState(() => err = errText(e));
    }
  }

  static String _ymd(Object? v) => '${v ?? ''}'.length >= 10 ? '${v ?? ''}'.substring(0, 10) : '';

  /// (3.159.0) EDIT his own paper: its number, the day it was issued and – a paper that runs out – up to when it is valid
  Future<void> _edit(Map kind, Map d) async {
    final number = TextEditingController(text: '${d['number'] ?? ''}');
    var iss = _ymd(d['issued_on']), exp = _ymd(d['expires_on']);
    final expires = kind['expires'] == true;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (c) => StatefulBuilder(
        builder: (c, set) {
          Future<void> pick(bool forExp) async {
            final now = DateTime.now(), last = forExp ? DateTime(now.year + 40) : now;
            var at = DateTime.tryParse(forExp ? exp : iss) ?? now;
            if (at.isAfter(last)) at = last;
            final got = await showDatePicker(context: c, initialDate: at, firstDate: DateTime(1950), lastDate: last);
            if (got == null) return;
            final v = '${got.year.toString().padLeft(4, '0')}-${got.month.toString().padLeft(2, '0')}-${got.day.toString().padLeft(2, '0')}';
            set(() {
              if (forExp) {
                exp = v;
              } else {
                iss = v;
              }
            });
          }

          Widget date(String key, String en, String mr, String v, bool forExp) => ListTile(key: Key(key), contentPadding: EdgeInsets.zero, leading: const Icon(Icons.event_outlined), title: Text(en, mr: mr), subtitle: m.Text(v.isEmpty ? '–' : dayName(v)), onTap: () => pick(forExp));
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + MediaQuery.viewInsetsOf(c).bottom),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                m.Text(tr('${kind['name']}'), style: const TextStyle(fontFamily: 'Montserrat', fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                TextField(key: const Key('doc-ed-number'), controller: number, maxLength: 40, textCapitalization: TextCapitalization.characters, decoration: InputDecoration(labelText: _t('Its number (if any)', 'त्याचा नंबर (असल्यास)'), border: const OutlineInputBorder())),
                date('doc-ed-iss', 'Issued on', 'दिल्याची तारीख', iss, false),
                if (expires) date('doc-ed-exp', 'Valid up to', 'कधीपर्यंत वैध', exp, true),
                const SizedBox(height: 8),
                FilledButton(key: const Key('doc-ed-save'), onPressed: () => Navigator.pop(c, true), child: const Text('Save', mr: 'Save करा')),
              ]),
            ),
          );
        },
      ),
    );
    final typed = number.text.trim();
    if (ok != true || !mounted) return;
    await _do({'action': 'myDocEdit', 'doc': d['id'], 'number': typed, 'issued_on': iss, 'expires_on': exp}, _t('Saved', 'Save झाले'));
  }

  Future<void> _open(Map d) async {
    try {
      final j = await widget.ask({'action': 'myDocLink', 'doc': d['id']});
      await launchUrl(Uri.parse('${j['url']}'), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) setState(() => err = errText(e));
    }
  }

  static IconData _sign(String key) {
    final k = key.toLowerCase();
    if (k.contains('photo')) return Icons.photo_camera_outlined;
    if (k.contains('aadhaar') || k.contains('pan') || k.contains('voter') || k.contains('passport')) return Icons.badge_outlined;
    if (k.contains('bank') || k.contains('cheque')) return Icons.account_balance_outlined;
    if (k.contains('edu')) return Icons.school_outlined;
    if (k.contains('driv') || k.contains('licen')) return Icons.directions_car_outlined;
    if (k.contains('salary') || k.contains('slip')) return Icons.payments_outlined;
    if (k.contains('exp') || k.contains('reliev')) return Icons.work_outline_rounded;
    if (k.contains('medic') || k.contains('insur')) return Icons.favorite_border_rounded;
    return Icons.description_outlined;
  }

  /// (3.154.0, his choice of 21-11-2026: "d3 use kr") THE PAPERS IN GROUPS: on top how many are there; then what is needed from
  /// him, what is attached, and what he can also attach. Upload, Add, Attach again (a paper rejected before, with the HR office's
  /// reason), Open, the date.
  /// (3.159.0, his decision of 21-11-2026: "document upload hot aahet te verification and approval sathi jatat – as nko … edit delete
  /// change as option astil"; "employee pn swata update kru shakel") A PAPER IS THERE WHEN IT IS ATTACHED – nothing is "being
  /// checked" or "verified". Every attached paper has "⋯": Open · Edit (its number and dates) · Change (a new file in its place) ·
  /// Delete (it leaves his list; he attaches a new one when he wants).
  @override
  Widget build(BuildContext context) {
    final kinds = [for (final k in (data?['kinds'] as List? ?? const []).whereType<Map>()) k], docs = [for (final d in (data?['docs'] as List? ?? const []).whereType<Map>()) d];
    final missing = {for (final x in (data?['docsMissing'] as List? ?? const [])) '$x'};
    final need = <Map>[], good = <Map>[], also = <Map>[];
    List<Map> of(Map k) => docs.where((d) => d['kind'] == k['key']).toList();
    // the newest one of a kind: rejected before (with why – to attach again), else it is there
    String st(Map k) => of(k).isEmpty ? '' : '${of(k).first['status'] ?? ''}';
    for (final k in kinds) {
      final have = of(k).isNotEmpty, s = st(k);
      (s == 'rejected' || (!have && missing.contains('${k['name']}')) ? need : !have ? also : good).add(k);
    }
    final total = kinds.length, there = total - kinds.where((k) => of(k).isEmpty).length;
    final gold = sk.dark ? const Color(0xFFF2CC62) : const Color(0xFFA9741A), red = sk.dark ? const Color(0xFFFF7A70) : const Color(0xFFC22A1B);

    Widget row(Map k, bool last) {
      final have = of(k), s = st(k), newest = have.isEmpty ? null : have.first, note = '${newest?['verify_note'] ?? ''}', again = s == 'rejected';
      return Container(
        key: Key('doc-${k['key']}'),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(border: last ? null : Border(bottom: BorderSide(color: sk.hair))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Container(width: 40, height: 40, alignment: Alignment.center, decoration: BoxDecoration(color: sk.blank, borderRadius: BorderRadius.circular(13)), child: Icon(_sign('${k['key']}'), size: 20, color: gold)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              m.Text(tr('${k['name']}'), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: sk.ink, height: 1.25)),
              if (again) Padding(padding: const EdgeInsets.only(top: 4), child: Align(alignment: Alignment.centerLeft, child: stateChip('Rejected', 'x', key: Key('doc-st-${k['key']}')))),
              if (again && note.isNotEmpty)
                Padding(padding: const EdgeInsets.only(top: 3), child: m.Text('${_t('HR office says', 'HR office म्हणते')}: $note', key: Key('doc-why-${k['key']}'), style: TextStyle(fontSize: 12.5, color: red, height: 1.3))),
              for (final d in have)
                Row(children: [
                  Expanded(
                    child: GestureDetector(
                      key: Key('doc-open-${d['id']}'),
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _open(d),
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: m.Text.rich(
                          TextSpan(children: [
                            TextSpan(text: [if ('${d['number'] ?? ''}'.isNotEmpty) '${d['number']}', '${_t('Attached', 'जोडले')} ${dayName('${d['created_at'] ?? ''}'.length >= 10 ? '${d['created_at']}'.substring(0, 10) : '')}'.trim()].join(' · ')),
                            const TextSpan(text: '  •  '),
                            TextSpan(text: _t('Open', 'उघडा'), style: TextStyle(fontWeight: FontWeight.w700, color: sk.link)),
                          ]),
                          style: TextStyle(fontSize: 12.5, color: sk.muted, height: 1.3),
                        ),
                      ),
                    ),
                  ),
                  // (3.159.0) his own paper: Open · Edit · Change · Delete
                  GestureDetector(
                    key: Key('doc-more-${d['id']}'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _more(k, d),
                    child: Padding(padding: const EdgeInsets.fromLTRB(10, 4, 2, 0), child: Icon(Icons.more_horiz_rounded, size: 20, color: sk.muted)),
                  ),
                ]),
            ]),
          ),
          const SizedBox(width: 10),
          busy == '${k['key']}'
              ? const Padding(padding: EdgeInsets.symmetric(horizontal: 22), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5)))
              : GestureDetector(
                  key: Key('doc-add-${k['key']}'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _add(k, replaces: again ? '${newest?['id'] ?? ''}' : ''),
                  child: Bounce(
                    to: .94,
                    child: Container(
                      height: 38,
                      padding: const EdgeInsets.symmetric(horizontal: 13),
                      // (a paper not there yet, or one to attach again: the gold button; one more of a paper that is there: the quiet one)
                      decoration: have.isEmpty || again ? BoxDecoration(gradient: Sk.goldFill, borderRadius: BorderRadius.circular(19)) : BoxDecoration(color: sk.dark ? const Color(0xFF1E2A52) : const Color(0xFFE9F0FD), borderRadius: BorderRadius.circular(19)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(have.isEmpty || again ? Icons.file_upload_outlined : Icons.add_rounded, size: 16, color: have.isEmpty || again ? Sk.goldInk : (sk.dark ? const Color(0xFF9DB8FF) : const Color(0xFF1F5FBF))),
                        const SizedBox(width: 5),
                        Text(have.isEmpty ? 'Upload' : again ? 'Attach again' : 'Add', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: have.isEmpty || again ? Sk.goldInk : (sk.dark ? const Color(0xFF9DB8FF) : const Color(0xFF1F5FBF)))),
                      ]),
                    ),
                  ),
                ),
        ]),
      );
    }

    List<Widget> group(String key, Color dot, String en, String mr, List<Map> rows) => rows.isEmpty
        ? const []
        : [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
              child: Row(children: [
                Container(width: 9, height: 9, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
                const SizedBox(width: 9),
                Text(en, mr: mr, style: TextStyle(fontFamily: 'Montserrat', fontSize: 14.5, fontWeight: FontWeight.w800, color: sk.ink)),
                const SizedBox(width: 8),
                m.Text('${rows.length}', key: Key('docs-$key-n'), style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: sk.faint)),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              decoration: sk.box(radius: 22),
              child: Column(mainAxisSize: MainAxisSize.min, children: [for (final (i, k) in rows.indexed) row(k, i == rows.length - 1)]),
            ),
          ];

    Widget legend(Color c, String text) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 7, height: 7, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          m.Text(text, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.white, height: 1.2)),
        ]);

    return Scaffold(
      appBar: hrHead(context, sky: kMeSky, title: 'My documents', mr: 'माझी कागदपत्रे', height: 100, below: [
        Text('Attach a clear photo or PDF. The three dots: edit, change or delete.', mr: 'स्पष्ट photo किंवा PDF जोडा. तीन टिंबं: edit, change किंवा delete.', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, height: 1.3, color: sk.onHeadSoft)),
      ]),
      body: loading
          ? const SkeletonList(tiles: 0, rows: 5)
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(key: const Key('docs-page'), padding: const EdgeInsets.fromLTRB(16, 14, 16, 40), children: [
                if (err.isNotEmpty) InfoLine(err, bad: true, help: false, key: const Key('docs-err')),
                if (data != null && total > 0)
                  // how many are there: navy and gold in both modes
                  Container(
                    key: const Key('docs-sum'),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF0B1733), Color(0xFF1B2F66), Color(0xFF24408A)], stops: <double>[0, .6, 1]),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0x80E6B94E)),
                      boxShadow: const [BoxShadow(color: Color(0x400B1733), blurRadius: 24, offset: Offset(0, 12))],
                    ),
                    child: Row(children: [
                      SizedBox(
                        width: 70,
                        height: 70,
                        child: Stack(alignment: Alignment.center, children: [
                          SizedBox(width: 70, height: 70, child: CircularProgressIndicator(value: there / total, strokeWidth: 7, strokeCap: StrokeCap.round, backgroundColor: const Color(0x33FFFFFF), color: const Color(0xFFF2CC62))),
                          m.Text('$there/$total', key: const Key('docs-ring'), style: const TextStyle(fontFamily: 'Montserrat', fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
                        ]),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                          m.Text(_t('$there of $total attached', '$total पैकी $there जोडले'), style: const TextStyle(fontFamily: 'Montserrat', fontSize: 16.5, fontWeight: FontWeight.w800, color: Colors.white)),
                          const SizedBox(height: 2),
                          m.Text(
                              need.isEmpty
                                  ? _t('Nothing is needed from you now', 'आत्ता तुमच्याकडून काही हवे नाही')
                                  : need.length == 1
                                      ? _t('1 paper is still needed from you', 'तुमच्याकडून अजून 1 कागद हवा आहे')
                                      : _t('${need.length} papers are still needed from you', 'तुमच्याकडून अजून ${need.length} कागद हवे आहेत'),
                              style: const TextStyle(fontSize: 12.5, color: Color(0xFFC9D3EE), height: 1.3)),
                          const SizedBox(height: 9),
                          Wrap(spacing: 12, runSpacing: 5, children: [
                            if (need.isNotEmpty) legend(const Color(0xFFFF7A70), _t('${need.length} needed', '${need.length} हवे')),
                            if (good.isNotEmpty) legend(const Color(0xFF58D68D), _t('${good.length} attached', '${good.length} जोडले')),
                            if (also.isNotEmpty) legend(const Color(0xFF9AA6C8), _t('${also.length} not attached', '${also.length} जोडले नाहीत')),
                          ]),
                        ]),
                      ),
                    ]),
                  ),
                ...group('need', red, 'Needed from you', 'तुमच्याकडून हवे', need),
                ...group('ok', sk.dark ? const Color(0xFF58D68D) : const Color(0xFF0F7A45), 'Attached', 'जोडलेले', good),
                ...group('also', sk.faint, 'You can also attach', 'हेही जोडू शकता', also),
              ]),
            ),
    );
  }
}

/// (3.137.0, rcl-hr step 17) MY NOTIFICATIONS – what the HR office sent him (the same message may also have gone by WhatsApp or
/// e-mail); the new ones are marked; opening the list marks them seen.
class MyNoticesScreen extends StatefulWidget {
  const MyNoticesScreen({super.key, required this.ask});
  final HrAsk ask;
  @override
  State<MyNoticesScreen> createState() => _MyNoticesScreenState();
}

class _MyNoticesScreenState extends State<MyNoticesScreen> {
  List<Map> rows = const [];
  bool loading = true;
  String err = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final j = await widget.ask({'action': 'myNotices'});
      if (!mounted) return;
      setState(() {
        rows = (j['rows'] as List? ?? const []).whereType<Map>().toList();
        loading = false;
        err = '';
      });
      if (rows.any((r) => r['seen_at'] == null)) {
        try {
          await widget.ask({'action': 'myNoticeSeen'});
        } catch (_) {/* they stay "new" – nothing else is lost */}
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          err = errText(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: hrHead(context, sky: kMeSky, title: 'Notifications', mr: 'सूचना', height: 64),
      body: loading
          ? const SkeletonList(tiles: 0, rows: 4)
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(key: const Key('notices-page'), padding: const EdgeInsets.fromLTRB(16, 14, 16, 40), children: [
                if (err.isNotEmpty) InfoLine(err, bad: true, help: false, key: const Key('notices-err')),
                if (err.isEmpty && rows.isEmpty) InfoLine(_t('No message yet.', 'अजून कोणताही संदेश नाही.'), key: const Key('notices-none')),
                if (rows.isNotEmpty)
                  hrCard(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), [
                    for (final (i, r) in rows.indexed)
                      Container(
                        key: Key('notice-${r['id']}'),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        decoration: BoxDecoration(border: i == rows.length - 1 ? null : const Border(bottom: BorderSide(color: Color(0xFFF3F5FA)))),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Padding(padding: const EdgeInsets.only(top: 5, right: 10), child: Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: r['seen_at'] == null ? const Color(0xFFC22A1B) : Colors.transparent))),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                              m.Text('${r['title'] ?? ''}', style: TextStyle(fontSize: 14.5, fontWeight: r['seen_at'] == null ? FontWeight.w700 : FontWeight.w600, color: sk.ink, height: 1.3)),
                              if ('${r['body'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 3), child: m.Text('${r['body']}', style: TextStyle(fontSize: 13, color: sk.muted, height: 1.4))),
                              Padding(padding: const EdgeInsets.only(top: 4), child: m.Text(dayName('${r['created_at'] ?? ''}'.length >= 10 ? '${r['created_at']}'.substring(0, 10) : ''), style: TextStyle(fontSize: 11.5, color: sk.faint))),
                            ]),
                          ),
                        ]),
                      ),
                  ]),
              ]),
            ),
    );
  }
}

/// (3.139.0, rcl-hr Phase 6) MY TEAM – a reporting manager's own team (read only): today (in, late, on leave, not marked, off), what
/// waits for him (attendance corrections, leave – approved on their own screens), this month's counts, papers still missing.
class MyTeamScreen extends StatefulWidget {
  const MyTeamScreen({super.key, required this.ask});
  final HrAsk ask;
  @override
  State<MyTeamScreen> createState() => _MyTeamScreenState();
}

class _MyTeamScreenState extends State<MyTeamScreen> {
  Map j = const {};
  bool loading = true;
  String err = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await widget.ask({'action': 'myTeam'});
      if (!mounted) return;
      setState(() {
        j = r;
        loading = false;
        err = '';
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          err = errText(e);
        });
      }
    }
  }

  static const _now = {'in': ('In', 'आत', 'a'), 'late': ('Late', 'उशीर', 'w'), 'leave': ('On leave', 'रजेवर', 'i'), 'off': ('Off today', 'आज सुट्टी', 'i'), 'not': ('Not marked', 'हजेरी नाही', 'x')};

  Widget _count(String key, String en, String mr, Object? n, Color c) => Expanded(
        child: Container(
          key: Key('team-count-$key'),
          padding: const EdgeInsets.symmetric(vertical: 10),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(color: c.withValues(alpha: .08), borderRadius: BorderRadius.circular(14)),
          child: Column(children: [
            m.Text('${n ?? 0}', style: TextStyle(fontFamily: 'Montserrat', fontSize: 20, fontWeight: FontWeight.w800, color: c)),
            m.Text(_t(en, mr), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: sk.muted)),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final people = (j['people'] as List? ?? const []).whereType<Map>().toList(), c = (j['counts'] as Map?) ?? const {}, w = (j['waiting'] as Map?) ?? const {};
    final waits = ((w['attendance'] as num?) ?? 0) + ((w['leave'] as num?) ?? 0);
    return Scaffold(
      appBar: hrHead(context, sky: kMeSky, title: 'My team', mr: 'माझी टीम', height: 64),
      body: loading
          ? const SkeletonList(tiles: 0, rows: 4)
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(key: const Key('team-page'), padding: const EdgeInsets.fromLTRB(16, 14, 16, 40), children: [
                if (err.isNotEmpty) InfoLine(err, bad: true, help: false, key: const Key('team-err')),
                if (err.isEmpty) ...[
                  Row(children: [
                    _count('in', 'In', 'आत', ((c['in'] as num?) ?? 0) + ((c['late'] as num?) ?? 0), const Color(0xFF0F7A45)),
                    _count('late', 'Late', 'उशीर', c['late'], const Color(0xFF8A5A00)),
                    _count('leave', 'On leave', 'रजेवर', c['leave'], const Color(0xFF1F5FBF)),
                    _count('not', 'Not marked', 'हजेरी नाही', c['not'], const Color(0xFFC22A1B)),
                  ]),
                  const SizedBox(height: 10),
                  if (waits > 0)
                    InfoLine(_t('$waits requests of your team wait for your decision.', 'तुमच्या टीमच्या $waits विनंत्या तुमच्या निर्णयाची वाट बघत आहेत.'), key: const Key('team-waiting')),
                  if ((j['papers_missing'] as num? ?? 0) > 0)
                    InfoLine(_t('${j['papers_missing']} of your team still have papers missing.', 'तुमच्या टीममधल्या ${j['papers_missing']} जणांची कागदपत्रं अजून बाकी.'), key: const Key('team-papers')),
                  const SizedBox(height: 4),
                  hrCard(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), [
                    for (final (i, p) in people.indexed)
                      Container(
                        key: Key('team-${p['code']}'),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        decoration: BoxDecoration(border: i == people.length - 1 ? null : const Border(bottom: BorderSide(color: Color(0xFFF3F5FA)))),
                        child: Row(children: [
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                              m.Text('${p['name'] ?? ''}', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: sk.ink)),
                              m.Text(
                                  [
                                    '${p['code'] ?? ''}',
                                    if ('${p['in'] ?? ''}'.isNotEmpty) _t('in ${p['in']}', 'आत ${p['in']}'),
                                    _t('this month: ${(p['month'] as Map?)?['present'] ?? 0} present · ${(p['month'] as Map?)?['absent'] ?? 0} absent · ${(p['month'] as Map?)?['late'] ?? 0} late',
                                        'या महिन्यात: ${(p['month'] as Map?)?['present'] ?? 0} हजर · ${(p['month'] as Map?)?['absent'] ?? 0} गैरहजर · ${(p['month'] as Map?)?['late'] ?? 0} उशीर'),
                                  ].join(' · '),
                                  style: TextStyle(fontSize: 12.5, color: sk.muted, height: 1.35)),
                            ]),
                          ),
                          () {
                            final n = _now['${p['now']}'] ?? _now['not']!;
                            return stateChip(_t(n.$1, n.$2), n.$3);
                          }(),
                        ]),
                      ),
                  ]),
                ],
              ]),
            ),
    );
  }
}

/// (3.136.0, rcl-hr step 16) MY WORK LOCATIONS – "Employee can Sign In / Sign Out at the following locations": the places that count
/// for him today (IN / OUT), and a place given to him that does not count today with why (the HR office's dates, switched off).
class MyPlacesScreen extends StatefulWidget {
  const MyPlacesScreen({super.key, required this.ask});
  final HrAsk ask;
  @override
  State<MyPlacesScreen> createState() => _MyPlacesScreenState();
}

class _MyPlacesScreenState extends State<MyPlacesScreen> {
  List<Map> rows = const [];
  bool loading = true;
  String err = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final j = await widget.ask({'action': 'myPlaces'});
      if (!mounted) return;
      setState(() {
        rows = (j['places'] as List? ?? const []).whereType<Map>().toList();
        loading = false;
        err = '';
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          err = errText(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = rows.where((r) => r['counts'] == true).toList(), later = rows.where((r) => r['counts'] != true).toList();
    Widget line(Map r, int i, int n) => Container(
          key: Key('place-${r['id']}'),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(border: i == n - 1 ? null : const Border(bottom: BorderSide(color: Color(0xFFF3F5FA)))),
          child: Row(children: [
            Icon(Icons.place_rounded, size: 20, color: r['counts'] == true ? const Color(0xFF0F7A45) : sk.faint),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                m.Text('${r['name']}', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: sk.ink)),
                if ('${r['why'] ?? ''}'.isNotEmpty) m.Text(_t('Not today – ${r['why']}', 'आज नाही – ${r['why']}'), style: TextStyle(fontSize: 12.5, color: sk.muted)),
              ]),
            ),
            if (r['can_in'] == true) Padding(padding: const EdgeInsets.only(left: 6), child: stateChip('IN', r['counts'] == true ? 'a' : '')),
            if (r['can_out'] == true) Padding(padding: const EdgeInsets.only(left: 6), child: stateChip('OUT', r['counts'] == true ? 'a' : '')),
          ]),
        );
    return Scaffold(
      appBar: hrHead(context, sky: kMeSky, title: 'My work locations', mr: 'माझी कामाची ठिकाणं', height: 64),
      body: loading
          ? const SkeletonList(tiles: 0, rows: 3)
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(key: const Key('places-page'), padding: const EdgeInsets.fromLTRB(16, 14, 16, 40), children: [
                if (err.isNotEmpty) InfoLine(err, bad: true, help: false, key: const Key('places-err')),
                if (err.isEmpty && now.isEmpty) InfoLine(_t('No work place counts for you today – ask the HR office.', 'आज तुमच्यासाठी कोणतंही work place नाही – HR office ला सांगा.'), bad: true, key: const Key('places-none')),
                if (now.isNotEmpty) hrCard(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), [
                  hrTitle('You can sign in / out at', 'येथे sign in / out करता येतं'),
                  for (final (i, r) in now.indexed) line(r, i, now.length),
                ]),
                if (later.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  hrCard(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), [
                    hrTitle('Given to you – not today', 'तुम्हाला दिलेली – आज नाही'),
                    for (final (i, r) in later.indexed) line(r, i, later.length),
                  ]),
                ],
              ]),
            ),
    );
  }
}

/// (3.135.0, rcl-hr step 15) THE COMPANY'S POLICIES – the ones in force for him (made and published by the HO HR / Super Admin on
/// the web): each one's version; he opens it, reads it and accepts it himself ("I have read and accept"). A new version is asked
/// again. What he accepted is kept by the server with the version, the day and this phone.
class CompanyPoliciesScreen extends StatefulWidget {
  const CompanyPoliciesScreen({super.key, required this.ask});
  final HrAsk ask;
  @override
  State<CompanyPoliciesScreen> createState() => _CompanyPoliciesScreenState();
}

class _CompanyPoliciesScreenState extends State<CompanyPoliciesScreen> {
  List<Map> rows = const [];
  bool loading = true;
  String err = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final j = await widget.ask({'action': 'myPolicies'});
      if (!mounted) return;
      setState(() {
        rows = (j['rows'] as List? ?? const []).whereType<Map>().toList();
        loading = false;
        err = '';
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          err = errText(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: hrHead(context, sky: kMeSky, title: 'Company policies', mr: 'Company policies', height: 64),
      body: loading
          ? const SkeletonList(tiles: 0, rows: 3)
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(key: const Key('pol-page'), padding: const EdgeInsets.fromLTRB(16, 14, 16, 40), children: [
                if (err.isNotEmpty) InfoLine(err, bad: true, help: false, key: const Key('pol-err')),
                if (err.isEmpty && rows.isEmpty) InfoLine(_t('No company policy for you yet.', 'तुमच्यासाठी अजून company policy नाही.'), key: const Key('pol-none')),
                if (rows.isNotEmpty)
                  hrCard(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), [
                    for (final (i, r) in rows.indexed)
                      _li(
                          key: Key('pol-${r['policy']}'),
                          sign: '',
                          icon: r['accepted_at'] != null ? Icons.check_circle_rounded : Icons.description_outlined,
                          c: r['accepted_at'] != null ? const Color(0xFF146C2E) : const Color(0xFF0B5FA5),
                          soft: r['accepted_at'] != null ? const Color(0xFFDDF3E4) : const Color(0xFFE3EEFB),
                          en: '${r['title']}',
                          mr: '${r['title']}',
                          sub: r['accepted_at'] != null
                              ? _t('Version ${r['version']} · accepted ${dayName('${r['accepted_at']}'.substring(0, 10))}', 'Version ${r['version']} · स्वीकारली ${dayName('${r['accepted_at']}'.substring(0, 10))}')
                              : r['mandatory'] == true
                                  ? _t('Version ${r['version']} · read and accept', 'Version ${r['version']} · वाचा आणि स्वीकारा')
                                  : _t('Version ${r['version']} · to read', 'Version ${r['version']} · वाचण्यासाठी'),
                          ink: r['accepted_at'] == null && r['mandatory'] == true ? const Color(0xFFC22A1B) : null,
                          last: i == rows.length - 1,
                          onTap: () async {
                            final done = await Navigator.of(context).push<bool>(hrRoute<bool>(PolicyReadScreen(ask: widget.ask, policy: r)));
                            if (done == true) await _load();
                          }),
                  ]),
              ]),
            ),
    );
  }
}

/// One policy: its words, its PDF (if any), and "I have read and accept".
class PolicyReadScreen extends StatefulWidget {
  const PolicyReadScreen({super.key, required this.ask, required this.policy});
  final HrAsk ask;
  final Map policy;
  @override
  State<PolicyReadScreen> createState() => _PolicyReadScreenState();
}

class _PolicyReadScreenState extends State<PolicyReadScreen> {
  bool read = false, busy = false;
  String err = '';

  Future<void> _pdf() async {
    try {
      final j = await widget.ask({'action': 'myPolicyFile', 'version': widget.policy['version_id']});
      await launchUrl(Uri.parse('${j['url']}'), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) setState(() => err = errText(e));
    }
  }

  Future<void> _accept() async {
    setState(() {
      busy = true;
      err = '';
    });
    try {
      var model = '';
      try {
        model = '${(await AttendKit.kit.info())['model'] ?? ''}';
      } catch (_) {/* the acceptance does not wait for the phone's name */}
      await widget.ask({'action': 'myPolicyAccept', 'version': widget.policy['version_id'], 'read': read, 'via': 'app', 'device': {'model': model}});
      if (!mounted) return;
      donePop(context, _t('Accepted', 'स्वीकारली'));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => err = errText(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.policy, accepted = p['accepted_at'] != null, body = '${p['body'] ?? ''}';
    return Scaffold(
      appBar: hrHead(context, sky: kMeSky, title: '${p['title']}', mr: '${p['title']}', height: 64),
      body: ListView(key: const Key('pol-read'), padding: const EdgeInsets.fromLTRB(16, 14, 16, 40), children: [
        hrCard([
          m.Text(_t('Version ${p['version']} · in force from ${dayName('${p['effective_from'] ?? ''}')}', 'Version ${p['version']} · ${dayName('${p['effective_from'] ?? ''}')} पासून लागू'), style: TextStyle(fontSize: 12.5, color: sk.muted)),
          const SizedBox(height: 10),
          if (body.isNotEmpty) SelectableText(body, key: const Key('pol-body'), style: TextStyle(fontSize: 15, height: 1.55, color: sk.ink)),
          if (p['has_file'] == true) Padding(padding: const EdgeInsets.only(top: 12), child: stateChip('Open the PDF', 'w', key: const Key('pol-pdf'), onTap: _pdf)),
        ]),
        const SizedBox(height: 12),
        if (err.isNotEmpty) InfoLine(err, bad: true, help: false, key: const Key('pol-read-err')),
        if (accepted)
          InfoLine(_t('You accepted this version on ${dayName('${p['accepted_at']}'.substring(0, 10))}.', 'तुम्ही ही version ${dayName('${p['accepted_at']}'.substring(0, 10))} ला स्वीकारली.'), key: const Key('pol-accepted'))
        else ...[
          CheckboxListTile(
            key: const Key('pol-tick'),
            value: read,
            onChanged: busy ? null : (v) => setState(() => read = v == true),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            title: const Text('I have read this policy and I accept it.', mr: 'मी ही policy वाचली आहे आणि मला ती मान्य आहे.'),
          ),
          const SizedBox(height: 8),
          hrButton('Accept', 'स्वीकारा', key: const Key('pol-accept'), onTap: read && !busy ? _accept : null, busy: busy),
        ],
      ]),
    );
  }
}

/// SALARY SLIPS – they come from payroll, which the HR office has not started yet: nothing is shown before.
class SalarySlipsScreen extends StatefulWidget {
  const SalarySlipsScreen({super.key, required this.ask});
  final HrAsk ask;
  @override
  State<SalarySlipsScreen> createState() => _SalarySlipsScreenState();
}

/// (3.112.0, rcl-hr step 12) his own salary slips: one card a locked month, the newest first – what was earned, what was
/// deducted, the net pay. Read only; made by the HO HR on the web.
class _SalarySlipsScreenState extends State<SalarySlipsScreen> {
  List<Map> slips = const [];
  Map who = const {}; // (3.119.0) his name and code, as the server says them – the PDF's head
  int making = -1; // which slip's PDF is being made
  bool loading = true;
  String err = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final j = await widget.ask({'action': 'mySlips'});
      if (!mounted) return;
      setState(() {
        slips = (j['slips'] as List? ?? const []).whereType<Map>().toList();
        who = j['employee'] is Map ? j['employee'] as Map : const {};
        loading = false;
        err = '';
      });
    } on ApiError catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          err = e.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          err = 'Something went wrong – please try again.';
        });
      }
    }
  }

  /// (3.119.0, asked 13-11-2026: "Salary slip che Download PDF") this month's slip as a PDF – the slip as the server locked it,
  /// with the company's name and logo, his name, ID and site. Handed to the phone's own "save / share".
  Future<void> _pdf(Map s, int i) async {
    if (making >= 0) return;
    setState(() => making = i);
    try {
      final ses = SessionScope.read(context), name = '${who['name'] ?? ''}'.trim().isEmpty ? ses.name : '${who['name']}'.trim(), code = '${who['code'] ?? ''}'.trim();
      final hs = hrSite(ses) ?? ses.site, company = (hs?.company ?? '').isNotEmpty ? hs!.company : (ses.company.isNotEmpty ? ses.company : 'Salary slip');
      final now = DateTime.now().toUtc().add(const Duration(minutes: 330)).toIso8601String();
      final bytes = await payslipPdf(company: company, site: hs?.name ?? ses.siteName, name: name, code: code, slip: s, logo: await attendPdfLogo(company), made: '${now.substring(8, 10)}/${now.substring(5, 7)}/${now.substring(0, 4)} ${now.substring(11, 16)}');
      await attendPdfOut(bytes, 'Salary_slip_${code.isEmpty ? name : code}_${s['month']}.pdf');
    } catch (_) {
      if (mounted) toast(context, _t('The PDF could not be made – try again.', 'PDF बनली नाही – पुन्हा करा.'));
    }
    if (mounted) setState(() => making = -1);
  }

  static String _rs(Object? v) {
    final n = v is num ? v : num.tryParse('$v') ?? 0, neg = n < 0, t = n.abs().toStringAsFixed(n == n.roundToDouble() ? 0 : 2), p = t.split('.');
    var a = p[0];
    // (the Indian way: 1,23,456)
    if (a.length > 3) {
      final last = a.substring(a.length - 3);
      var rest = a.substring(0, a.length - 3);
      final parts = <String>[];
      while (rest.length > 2) {
        parts.insert(0, rest.substring(rest.length - 2));
        rest = rest.substring(0, rest.length - 2);
      }
      if (rest.isNotEmpty) parts.insert(0, rest);
      a = '${parts.join(',')},$last';
    }
    return '${neg ? '−' : ''}₹ $a${p.length > 1 ? '.${p[1]}' : ''}';
  }

  Widget _line(String label, Object? amount, {bool bold = false, Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(child: m.Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, fontWeight: bold ? FontWeight.w700 : FontWeight.w500, color: bold ? sk.ink : sk.muted))),
          m.Text(_rs(amount), style: TextStyle(fontSize: 14, fontWeight: bold ? FontWeight.w800 : FontWeight.w600, color: color ?? sk.ink)),
        ]),
      );

  Widget _slip(Map s, int i) {
    final good = sk.tint(const Color(0xFF0F7A45), const Color(0xFFE3F7EC)).$1, bad = sk.tint(C.red, C.redSoft).$1;
    final earn = (s['earnings'] as List? ?? const []).whereType<Map>().toList(), ded = (s['deductions'] as List? ?? const []).whereType<Map>().toList();
    // (3.138.0, rcl-hr step 18) the parts of his earned pay (his salary structure) and what the company pays beside it – only when there
    final parts = (s['components'] as List? ?? const []).whereType<Map>().toList(), er = (s['employer'] as List? ?? const []).whereType<Map>().toList();
    Widget small(String en, String mr) => Padding(padding: const EdgeInsets.only(top: 6, bottom: 2), child: m.Text(_t(en, mr), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: sk.muted)));
    final daily = '${s['pay_type']}' == 'daily', extra = s['extra_days'] is num ? s['extra_days'] as num : 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: hrCard(key: Key('slip-$i'), [
        Row(children: [
          Expanded(child: m.Text(monthName('${s['month']}'), style: TextStyle(fontFamily: 'Montserrat', fontSize: 16, fontWeight: FontWeight.w800, color: sk.ink))),
          m.Text(_rs(s['net']), key: Key('slip-net-$i'), style: TextStyle(fontFamily: 'Montserrat', fontSize: 19, fontWeight: FontWeight.w800, color: good)),
        ]),
        Padding(
          padding: const EdgeInsets.only(top: 2, bottom: 8),
          child: m.Text(
              [
                daily ? _t('${_rs(s['rate'])} a day', 'दिवसाला ${_rs(s['rate'])}') : _t('${_rs(s['rate'])} a month', 'महिन्याला ${_rs(s['rate'])}'),
                _t('${s['pay_days']} days paid', '${s['pay_days']} दिवसांचा पगार'),
                if (extra > 0) _t('$extra extra', '$extra extra'),
              ].join(' · '),
              style: TextStyle(fontSize: 12.5, color: sk.muted)),
        ),
        for (final l in earn) _line('${l['label']}', l['amount']),
        _line(_t('Gross', 'एकूण'), s['gross'], bold: true),
        if (parts.isNotEmpty) ...[
          small('Parts of the earned pay', 'कमावलेल्या पगाराचे भाग'),
          for (final l in parts) _line('${l['label']}', l['amount']),
        ],
        if (ded.isNotEmpty) Divider(height: 14, color: sk.hair),
        for (final l in ded) _line('${l['label']}', l['amount'], color: bad),
        if (ded.isNotEmpty) _line(_t('Total deductions', 'एकूण कपात'), s['total_deductions'], bold: true, color: bad),
        Divider(height: 14, color: sk.hair),
        _line(_t('Net pay', 'हातात येणारा पगार'), s['net'], bold: true, color: good),
        if (er.isNotEmpty) ...[
          Divider(height: 14, color: sk.hair),
          small('Paid by the company beside your pay', 'तुमच्या पगाराशिवाय कंपनीने भरलेले'),
          for (final l in er) _line('${l['label']}', l['amount']),
          if (s['ctc'] is num) _line(_t('Cost to the company', 'कंपनीचा एकूण खर्च (CTC)'), s['ctc'], bold: true),
        ],
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            key: Key('slip-pdf-$i'),
            onPressed: making >= 0 ? null : () => _pdf(s, i),
            icon: making == i ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.picture_as_pdf_outlined, size: 18),
            label: m.Text(_t('Download PDF', 'PDF घ्या')),
          ),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: hrHead(context, sky: kMeSky, title: 'Salary slips', mr: 'पगार पावत्या', height: 64),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(key: const Key('slips-page'), padding: const EdgeInsets.fromLTRB(16, 14, 16, 40), children: [
                if (err.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 12), child: hrNote(err, key: const Key('slips-err'))),
                if (slips.isEmpty && err.isEmpty)
                  hrCard([
                    hrTitle('No salary slip yet', 'अजून पगार पावती नाही'),
                    Text('Your salary slip of a month comes here when the head office has made and locked that month\'s pay.', mr: 'Head office ने त्या महिन्याचा पगार काढून lock केल्यावर तुमची पगार पावती इथे येते.', style: TextStyle(fontSize: 13.5, height: 1.4, color: sk.muted)),
                  ]),
                for (var i = 0; i < slips.length; i++) _slip(slips[i], i),
              ]),
      );
}

/// LANGUAGE – the whole app in one language.
class LanguageScreen extends StatefulWidget {
  const LanguageScreen({super.key});
  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  late String pick = Lang.i.code == 'mr' || Lang.i.code == 'hi' ? Lang.i.code : 'en';
  bool busy = false;
  String err = '';

  Future<void> _save() async {
    if (busy) return;
    setState(() {
      busy = true;
      err = '';
    });
    try {
      await SessionScope.read(context).chooseLanguage(pick);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          err = errText(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget radio(String code, String own, String en) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GestureDetector(
            key: Key('lang-$code'),
            behavior: HitTestBehavior.opaque,
            onTap: busy ? null : () => setState(() => pick = code),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(color: sk.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: pick == code ? sk.accent : (sk.cardLine ?? Colors.transparent), width: 2), boxShadow: sk.shadow),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    m.Text(own, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: sk.ink)),
                    m.Text(en, style: TextStyle(fontSize: 12, color: sk.muted)),
                  ]),
                ),
                Container(width: 22, height: 22, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: pick == code ? sk.accent : sk.line, width: pick == code ? 7 : 2))),
              ]),
            ),
          ),
        );
    return Scaffold(
      appBar: hrHead(context, sky: kMeSky, title: 'Language', mr: 'भाषा', height: 96, below: [
        Text('The whole app is shown in one language.', mr: 'संपूर्ण app एका भाषेत दिसते.', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.5, color: sk.onHeadSoft)),
      ]),
      body: ListView(key: const Key('lang-page'), padding: const EdgeInsets.fromLTRB(16, 14, 16, 40), children: [
        radio('en', 'English', 'English'),
        radio('mr', 'मराठी', 'Marathi'),
        radio('hi', 'हिन्दी', 'Hindi'),
        if (err.isNotEmpty) InfoLine(err, bad: true, help: false),
        const SizedBox(height: 4),
        hrButton('Save', 'Save करा', key: const Key('lang-save'), onTap: _save, busy: busy),
      ]),
    );
  }
}

/// E-MAIL AND PASSWORD – the Portal's: one sign-in for everything.
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});
  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  Future<void> _password() async {
    final old = TextEditingController(), now = TextEditingController(), again = TextEditingController();
    final ok = await popDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Change password'),
        scrollable: true,
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(key: const Key('pw-old'), controller: old, obscureText: true, decoration: InputDecoration(labelText: tr('Current password'))),
          const SizedBox(height: 10),
          TextField(key: const Key('pw-new'), controller: now, obscureText: true, decoration: InputDecoration(labelText: tr('New password'))),
          const SizedBox(height: 10),
          TextField(key: const Key('pw-again'), controller: again, obscureText: true, decoration: InputDecoration(labelText: tr('New password again'))),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')), FilledButton(key: const Key('pw-ok'), style: FilledButton.styleFrom(minimumSize: const Size(110, 46)), onPressed: () => Navigator.pop(c, true), child: const Text('Change'))],
      ),
    );
    if (ok != true || !mounted) return;
    if (now.text != again.text) {
      toast(context, 'The two new passwords are not the same.', bad: true);
      return;
    }
    try {
      await SessionScope.read(context).changePassword(old.text, now.text);
      if (mounted) donePop(context, 'Password changed');
    } catch (e) {
      if (mounted) toast(context, errText(e), bad: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    return Scaffold(
      appBar: hrHead(context, sky: kMeSky, title: 'E-mail and password', mr: 'E-mail आणि password', height: 64),
      body: ListView(key: const Key('acc-page'), padding: const EdgeInsets.fromLTRB(16, 14, 16, 40), children: [
        hrCard(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), [
          _li(key: const Key('acc-id'), sign: '@', c: sk.accent, soft: const Color(0xFFEEF1F7), en: 'User ID', mr: 'User ID', sub: s.email, arrow: false),
          if (s.mailVerified) _li(key: const Key('acc-verified'), sign: '✓', c: const Color(0xFF0F7A45), soft: const Color(0xFFE3F7EC), en: 'E-mail verified', mr: 'E-mail verify झाला', sub: s.mailLogin, arrow: false),
          if (s.mailCanVerify)
            _li(key: const Key('acc-verify'), sign: '!', c: const Color(0xFF8A5A00), soft: const Color(0xFFFFF3D1), en: 'Verify my e-mail', mr: 'माझा e-mail verify करा', sub: _t('Then you can also sign in with a code by e-mail', 'मग e-mail वरील code ने सुद्धा sign in करता येईल'), onTap: () async {
              await openVerifyEmail(context);
              if (mounted) setState(() {});
            }),
          _li(key: const Key('acc-pw'), sign: 'P', c: sk.accent, soft: const Color(0xFFEEF1F7), en: 'Change password', mr: 'Password बदला', sub: _t('One password for everything', 'सगळ्यासाठी एकच password'), last: true, onTap: _password),
        ]),
      ]),
    );
  }
}

/// The file as it is sent: a PDF as it is; a photo turned upright, at most 2000 points on its long side, a JPEG.
(Uint8List, String)? docReady(String name, Uint8List raw) {
  if (name.toLowerCase().endsWith('.pdf') || (raw.length > 4 && raw[0] == 0x25 && raw[1] == 0x50 && raw[2] == 0x44 && raw[3] == 0x46)) return (raw, 'application/pdf');
  final im = img.decodeImage(raw);
  if (im == null) return null;
  final up = img.bakeOrientation(im), big = up.width > up.height ? up.width : up.height;
  final fit = big > 2000 ? img.copyResize(up, width: up.width >= up.height ? 2000 : null, height: up.height > up.width ? 2000 : null) : up;
  return (Uint8List.fromList(img.encodeJpg(fit, quality: 85)), 'image/jpeg');
}

/// (3.109.0, asked 12-11-2026: "user swatacha photo pn set karu shakel profile picture") MY PHOTO: he takes or chooses a picture
/// of himself – it is kept as his paper "Photo" (the HR office sees it on his page and in its list). true = set.
Future<bool> setMyPhoto(BuildContext context, HrAsk ask) async {
  final how = await showModalBottomSheet<String>(
    context: context,
    builder: (c) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(padding: EdgeInsets.fromLTRB(20, 16, 20, 6), child: Align(alignment: Alignment.centerLeft, child: Text('My photo', mr: 'माझा photo', style: TextStyle(fontFamily: 'Montserrat', fontSize: 16, fontWeight: FontWeight.w800, color: sk.ink)))),
        ListTile(key: const Key('photo-camera'), leading: const Icon(Icons.photo_camera_rounded), title: const Text('Take a photo', mr: 'Photo काढा'), onTap: () => Navigator.pop(c, 'camera')),
        ListTile(key: const Key('photo-gallery'), leading: const Icon(Icons.photo_library_rounded), title: const Text('Choose a photo', mr: 'Photo निवडा'), onTap: () => Navigator.pop(c, 'gallery')),
        const SizedBox(height: 8),
      ]),
    ),
  );
  if (how == null || !context.mounted) return false;
  try {
    final got = await pickAttFiles(how, 1);
    if (got.isEmpty) return false;
    final f = docReady(got.first.name, got.first.bytes);
    if (f == null || f.$2 != 'image/jpeg') throw ApiError('This is not a picture – take or choose a photo.');
    final u = await ask({'action': 'myDocUploadUrl', 'kind': 'photo', 'type': f.$2, 'bytes': f.$1.length});
    if (!context.mounted) return false;
    await SessionScope.read(context).api.hrFile('${u['url']}', f.$1, f.$2);
    await ask({'action': 'myDocAdd', 'kind': 'photo', 'path': u['path'], 'bytes': f.$1.length});
    hrFaceForget();
    if (context.mounted) donePop(context, _t('Your photo is set', 'तुमचा photo ठेवला'));
    return true;
  } catch (e) {
    if (context.mounted) toast(context, errText(e), bad: true);
    return false;
  }
}

/// His face: his photo when he has set one (a link of the HR server), else the first letters of his name.
Widget hrFace(String name, String url, {required double size, required double radius, Color bg = const Color(0xFF0F1F3D), Color? border, Color ink = Colors.white, double letters = 15}) {
  final abc = m.Text(initials(name), style: TextStyle(fontFamily: 'Montserrat', fontSize: letters, fontWeight: FontWeight.w800, color: ink));
  // (3.153.0, asked 20-11-2026: "user cha jo image aahe to sarkha blink krt asto … stable nahi rahat, proper circle madhe disat
  // nahi") The HR server gives a NEW link to the same picture at every reading (good for ten minutes): the picture was fetched
  // again each time and the letters showed meanwhile – the blink. The first link of a picture is kept while the app runs, so the
  // picture already on the phone is shown and nothing is fetched twice; a link that no longer works is forgotten (the next
  // reading's link is used). The picture fills the whole circle; the gold ring is drawn over its edge.
  final file = url.split('?').first, link = url.isEmpty ? '' : _faceLink.putIfAbsent(file, () => url);
  return Container(
    width: size,
    height: size,
    foregroundDecoration: border == null ? null : BoxDecoration(borderRadius: BorderRadius.circular(radius), border: Border.all(color: border, width: 2)),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        width: size,
        height: size,
        color: bg,
        alignment: Alignment.center,
        child: url.isEmpty
            ? abc
            : Image.network(link, key: const Key('face-pic'), width: size, height: size, fit: BoxFit.cover, gaplessPlayback: true, errorBuilder: (_, __, ___) {
                _faceLink.remove(file);
                return abc;
              }, frameBuilder: (_, child, frame, sync) => sync || frame != null ? child : abc),
      ),
    ),
  );
}

/// the first link of each photo, by its file (see [hrFace])
final Map<String, String> _faceLink = {};

/// A new photo was set: the kept links are let go.
void hrFaceForget() => _faceLink.clear();

/// (3.112.0, asked 12-11-2026: "attendance app madhe app update check update as kahi nahiye te banaw") the app's version and its
/// update, for a person with HR only – the same check and the same update as Me of the full app. A newer version is said on the
/// row as soon as the page opens; a press checks again.
class _UpdateRow extends StatefulWidget {
  const _UpdateRow({required this.look});
  final String look;
  @override
  State<_UpdateRow> createState() => _UpdateRowState();
}

class _UpdateRowState extends State<_UpdateRow> {
  String version = '';
  AppUpdate? found;
  bool checking = false;

  @override
  void initState() {
    super.initState();
    appVersion().then((v) {
      if (mounted) setState(() => version = v);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final s = SessionScope.read(context), u = await checkUpdate(s.api, beta: s.tester);
      if (mounted && u != null) setState(() => found = u);
    });
  }

  Future<void> _check() async {
    if (checking) return;
    final s = SessionScope.read(context);
    setState(() => checking = true);
    final u = await checkUpdate(s.api, beta: s.tester);
    if (!mounted) return;
    setState(() {
      checking = false;
      found = u;
    });
    if (u == null) {
      toast(context, _t('You have the newest version.', 'नवीनतम version आहे.'));
    } else {
      await runUpdate(context, u);
    }
  }

  @override
  Widget build(BuildContext context) => _pill(
        key: const Key('me-update'),
        icon: Icons.file_download_outlined,
        tone: found != null ? (sk.dark ? const Color(0xFF58D68D) : const Color(0xFF0F7A45)) : null,
        en: found != null ? 'Update the app' : 'Check for update',
        mr: found != null ? 'App update करा' : 'Update तपासा',
        sub: checking
            ? _t('Checking…', 'तपासत आहे…')
            : found != null
                ? _t('New version ${found!.version}', 'नवीन version ${found!.version}')
                : (version.isEmpty ? '' : 'v$version'),
        onTap: _check,
      );
}

/// (3.113.0) the IN / OUT reminders: on (as they come) or off – his own choice, kept on this phone.
class _RemindRow extends StatefulWidget {
  const _RemindRow({required this.look});
  final String look;
  @override
  State<_RemindRow> createState() => _RemindRowState();
}

class _RemindRowState extends State<_RemindRow> {
  bool off = false;

  @override
  void initState() {
    super.initState();
    AttendRemind.isOff().then((v) {
      if (mounted) setState(() => off = v);
    });
  }

  Future<void> _flip() async {
    final v = !off;
    await AttendRemind.setOff(v);
    if (!mounted) return;
    setState(() => off = v);
    toast(context, v ? _t('Attendance reminders are off.', 'हजेरीची आठवण बंद केली.') : _t('Attendance reminders are on – they are set the next time your day is read.', 'हजेरीची आठवण चालू केली – पुढच्या वेळी दिवस वाचल्यावर लागते.'));
  }

  @override
  Widget build(BuildContext context) => _pill(
        key: const Key('me-remind'),
        icon: off ? Icons.notifications_off_outlined : Icons.notifications_none_rounded,
        tone: off ? sk.faint : null,
        en: 'Reminders',
        mr: 'आठवण',
        sub: off ? _t('Off', 'बंद') : _t('On', 'चालू'),
        onTap: _flip,
      );
}
