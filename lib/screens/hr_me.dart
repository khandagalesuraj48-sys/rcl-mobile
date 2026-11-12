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
import '../ui/hr_look.dart';
import '../ui/motion.dart';
import '../ui/scope.dart';
import '../ui/t.dart';
import '../ui/design.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'attach_box.dart' show pickAttFiles;
import 'attend_reqs.dart' show HrAsk;
import 'email_verify.dart';
import 'hr_shell.dart' show initials;

String _t(String en, String mr) => Lang.i.pair(en, mr);
const kMeSky = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF184833), Color(0xFF277E55), Color(0xFF59B585)], stops: <double>[0, .7, 1]);
const _cat = {'staff': 'Staff', 'operator': 'Operator', 'driver': 'Driver', 'labour': 'Labour'};

/// One line of a list card: a letter in its tile, the title, a small line, › (or nothing).
Widget _li({required Key key, required String sign, IconData? icon, required Color c, required Color soft, required String en, required String mr, String sub = '', Color ink = C.ink, bool arrow = true, bool last = false, VoidCallback? onTap}) => GestureDetector(
      key: key,
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(border: last ? null : const Border(bottom: BorderSide(color: Color(0xFFF3F5FA)))),
        child: Row(children: [
          Container(width: 36, height: 36, alignment: Alignment.center, decoration: BoxDecoration(color: soft, borderRadius: BorderRadius.circular(12)), child: icon != null ? Icon(icon, size: 19, color: c) : m.Text(sign, style: TextStyle(fontFamily: 'Montserrat', fontSize: 13, fontWeight: FontWeight.w800, color: c))),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(en, mr: mr, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: ink)),
              if (sub.isNotEmpty) m.Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: C.muted, height: 1.25)),
            ]),
          ),
          if (arrow) const Icon(Icons.chevron_right_rounded, size: 20, color: Color(0xFFB3B9C9)),
        ]),
      ),
    );

class HrMeTab extends StatelessWidget {
  const HrMeTab({super.key, required this.mine, required this.day, required this.ask, required this.onDocs, required this.onSlips, required this.onPhoto, required this.reload});
  final Map<String, dynamic>? mine, day;
  final HrAsk ask;
  final VoidCallback onDocs, onSlips, onPhoto;
  final Future<void> Function() reload;

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context), e = (mine?['employee'] as Map?) ?? (day?['employee'] as Map?) ?? const {};
    final name = '${e['name'] ?? s.name}', role = '${e['designation'] ?? ''}'.isNotEmpty ? '${e['designation']}' : (_cat['${e['category'] ?? ''}'] ?? '');
    final pct = (mine?['complete'] as Map?)?['pct'], miss = ((mine?['docs'] as Map?)?['missing'] as List? ?? const []).length, phone = (mine?['phone'] as Map?) ?? const {};
    final lang = switch (LangScope.of(context).code) { 'mr' => 'मराठी', 'hi' => 'हिन्दी', _ => 'English' };
    void open(Widget page) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
    return Column(children: [
      Container(
        width: double.infinity,
        decoration: const BoxDecoration(gradient: kMeSky, borderRadius: BorderRadius.vertical(bottom: Radius.circular(28))),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
            child: Row(children: [
              // (3.109.0) his own photo – a touch sets it
              GestureDetector(
                key: const Key('me-face'),
                behavior: HitTestBehavior.opaque,
                onTap: onPhoto,
                child: Stack(clipBehavior: Clip.none, children: [
                  hrFace(name, '${mine?['photo'] ?? ''}', size: 62, radius: 20, bg: Colors.white.withValues(alpha: .2), border: Colors.white.withValues(alpha: .4), letters: 21),
                  Positioned(right: -5, bottom: -5, child: Container(width: 24, height: 24, alignment: Alignment.center, decoration: BoxDecoration(color: const Color(0xFFFFC93C), shape: BoxShape.circle, border: Border.all(color: const Color(0xFF277E55), width: 2)), child: const Icon(Icons.photo_camera_rounded, size: 12, color: Color(0xFF3A2A00)))),
                ]),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  m.Text(name, key: const Key('me-name'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'Montserrat', fontSize: 21, fontWeight: FontWeight.w800, color: Colors.white)),
                  m.Text([if ('${e['code'] ?? ''}'.isNotEmpty) '${e['code']}', if (role.isNotEmpty) role].join(' · '), key: const Key('me-role'), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: Colors.white.withValues(alpha: .92))),
                  m.Text(s.siteName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: Colors.white.withValues(alpha: .92))),
                ]),
              ),
              if (pct is num)
                Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 50, height: 50, alignment: Alignment.center, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFFFFC93C), width: 5)), child: m.Text('${pct.round()}%', key: const Key('me-pct'), style: const TextStyle(fontFamily: 'Montserrat', fontSize: 12.5, fontWeight: FontWeight.w800, color: Colors.white))),
                  const SizedBox(height: 3),
                  const Text('Profile', mr: 'Profile', style: TextStyle(fontSize: 11, color: Colors.white)),
                ]),
            ]),
          ),
        ),
      ),
      Expanded(
        child: RefreshIndicator(
          onRefresh: reload,
          child: ListView(key: const Key('me-page'), padding: const EdgeInsets.fromLTRB(16, 14, 16, 24), children: [
            hrCard(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), [
              _li(key: const Key('me-photo'), sign: '', icon: Icons.account_circle_rounded, c: const Color(0xFF0B5FA5), soft: const Color(0xFFE3EEFB), en: 'My photo', mr: 'माझा photo', sub: '${mine?['photo'] ?? ''}'.isEmpty ? _t('Take or choose – shown on your profile', 'काढा किंवा निवडा – profile वर दिसेल') : _t('Set – touch to change', 'ठेवला आहे – बदलण्यासाठी touch करा'), onTap: onPhoto),
              _li(key: const Key('me-details'), sign: 'i', c: const Color(0xFF0B5FA5), soft: const Color(0xFFE3EEFB), en: 'My details', mr: 'माझी माहिती', sub: _t('Personal, job, bank – ask HR to change', 'वैयक्तिक, नोकरी, bank – बदलासाठी HR ला सांगा'), onTap: () => open(MyDetailsScreen(mine: mine))),
              _li(key: const Key('me-docs'), sign: 'D', c: const Color(0xFF0F7A45), soft: const Color(0xFFE3F7EC), en: 'My documents', mr: 'माझी कागदपत्रे', sub: mine == null ? _t('Upload', 'Upload') : miss > 0 ? _t('Upload – $miss still missing', 'Upload – अजून $miss बाकी') : _t('All expected papers are there', 'अपेक्षित सर्व कागदपत्रे आहेत'), onTap: onDocs),
              _li(key: const Key('me-slips'), sign: '₹', c: const Color(0xFF8A5A00), soft: const Color(0xFFFFF3D1), en: 'Salary slips', mr: 'पगार पावत्या', sub: _t('None yet', 'अजून नाही'), onTap: onSlips),
              _li(key: const Key('me-phone'), sign: 'P', c: kPurple, soft: const Color(0xFFF1E8F6), en: 'My phone', mr: 'माझा phone', sub: phone['bound'] == true ? _t('Registered for attendance', 'हजेरीसाठी नोंदलेला') : _t('No phone registered yet', 'अजून phone नोंदलेला नाही'), last: true, onTap: () => open(MyPhoneScreen(phone: phone, day: day))),
            ]),
            const SizedBox(height: 12),
            hrCard(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), [
              _li(key: const Key('me-lang'), sign: 'A', c: kNavy, soft: const Color(0xFFEEF1F7), en: 'Language', mr: 'भाषा', sub: lang, onTap: () => open(const LanguageScreen())),
              _li(key: const Key('me-account'), sign: '@', c: kNavy, soft: const Color(0xFFEEF1F7), en: 'E-mail and password', mr: 'E-mail आणि password', sub: s.mailVerified ? _t('Verified ✓', 'Verify झाला ✓') : s.mailKnown ? _t('Not verified yet', 'अजून verify नाही') : s.email, onTap: () => open(const AccountScreen())),
              if (s.sites.length > 1) _li(key: const Key('me-site'), sign: 'S', c: kNavy, soft: const Color(0xFFEEF1F7), en: 'Change site', mr: 'Site बदला', sub: s.siteName, onTap: s.pickAnotherSite),
              _li(
                  key: const Key('me-out'),
                  sign: '',
                  icon: Icons.power_settings_new_rounded,
                  c: const Color(0xFFC22A1B),
                  soft: const Color(0xFFFFE6E3),
                  en: 'Sign out',
                  mr: 'Sign out',
                  ink: const Color(0xFFC22A1B),
                  arrow: false,
                  last: true,
                  onTap: () async {
                    if (await _askSignOut(context)) await s.signOut();
                  }),
            ]),
          ]),
        ),
      ),
    ]);
  }
}

Future<bool> _askSignOut(BuildContext context) => ask(context, 'Sign out?', _t('You will be signed out of the app.', 'App मधून sign out होईल.'), yes: 'Sign out', danger: true);

/// MY DETAILS – read only.
class MyDetailsScreen extends StatelessWidget {
  const MyDetailsScreen({super.key, required this.mine});
  final Map<String, dynamic>? mine;
  @override
  Widget build(BuildContext context) {
    final groups = [for (final g in (mine?['details'] as List? ?? const []).whereType<Map>()) g];
    final missing = [for (final x in ((mine?['complete'] as Map?)?['missing'] as List? ?? const [])) '$x'];
    return Scaffold(
      appBar: hrHead(context, sky: kMeSky, title: 'My details', mr: 'माझी माहिती', height: 100, below: [
        Text('What the HR office has of you. To change a detail, ask the HR office.', mr: 'HR office कडे तुमची असलेली माहिती. बदलासाठी HR office ला सांगा.', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, height: 1.3, color: Colors.white.withValues(alpha: .95))),
      ]),
      body: ListView(key: const Key('det-page'), padding: const EdgeInsets.fromLTRB(16, 14, 16, 40), children: [
        if (mine == null) hrNote(_t('Your details could not be read – pull down on Me to try again.', 'माहिती वाचता आली नाही – Me वर खाली ओढून पुन्हा करा.')),
        if (missing.isNotEmpty) ...[hrNote('${_t('Still needed', 'अजून हवे')}: ${missing.join(', ')}', key: const Key('det-missing')), const SizedBox(height: 12)],
        for (final g in groups) ...[
          hrCard(key: Key('det-${g['name']}'), [
            m.Text(tr('${g['name']}'), style: const TextStyle(fontFamily: 'Montserrat', fontSize: 15, fontWeight: FontWeight.w800, color: C.ink)),
            const SizedBox(height: 6),
            for (final r in (g['rows'] as List? ?? const []).whereType<Map>())
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(flex: 5, child: m.Text(tr('${r['label']}'), style: const TextStyle(fontSize: 13, color: C.muted, height: 1.3))),
                  const SizedBox(width: 10),
                  Expanded(flex: 6, child: m.Text('${r['value']}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: C.ink, height: 1.3))),
                ]),
              ),
          ]),
          const SizedBox(height: 12),
        ],
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

  Future<void> _load() async {
    try {
      final j = await widget.ask({'action': 'myDocs'});
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
          err = errText(e);
        });
      }
    }
  }

  static (Uint8List, String)? _ready(String name, Uint8List raw) => docReady(name, raw);

  Future<void> _add(Map kind) async {
    if (busy.isNotEmpty) return;
    final how = await showModalBottomSheet<String>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 6), child: Align(alignment: Alignment.centerLeft, child: m.Text(tr('${kind['name']}'), style: const TextStyle(fontFamily: 'Montserrat', fontSize: 16, fontWeight: FontWeight.w800, color: C.ink)))),
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
      await widget.ask({'action': 'myDocAdd', 'kind': kind['key'], 'path': u['path'], 'bytes': f.$1.length});
      await _load();
      if (mounted) toast(context, _t('Attached.', 'जोडले.'));
    } catch (e) {
      if (mounted) setState(() => err = errText(e));
    } finally {
      if (mounted) setState(() => busy = '');
    }
  }

  Future<void> _open(Map d) async {
    try {
      final j = await widget.ask({'action': 'myDocLink', 'doc': d['id']});
      await launchUrl(Uri.parse('${j['url']}'), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) setState(() => err = errText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final kinds = [for (final k in (data?['kinds'] as List? ?? const []).whereType<Map>()) k], docs = [for (final d in (data?['docs'] as List? ?? const []).whereType<Map>()) d];
    final missing = {for (final x in (data?['docsMissing'] as List? ?? const [])) '$x'};
    return Scaffold(
      appBar: hrHead(context, sky: kMeSky, title: 'My documents', mr: 'माझी कागदपत्रे', height: 100, below: [
        Text('Attach a clear photo or a PDF of each paper. Only the HR office removes one.', mr: 'प्रत्येक कागदाचा स्पष्ट photo किंवा PDF जोडा. काढणे फक्त HR office करते.', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, height: 1.3, color: Colors.white.withValues(alpha: .95))),
      ]),
      body: loading
          ? const SkeletonList(tiles: 0, rows: 5)
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(key: const Key('docs-page'), padding: const EdgeInsets.fromLTRB(16, 14, 16, 40), children: [
                if (err.isNotEmpty) InfoLine(err, bad: true, help: false, key: const Key('docs-err')),
                if (data != null)
                  hrCard(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), [
                    for (final (i, k) in kinds.indexed)
                      () {
                        final have = docs.where((d) => d['kind'] == k['key']).toList(), need = missing.contains('${k['name']}');
                        return Container(
                          key: Key('doc-${k['key']}'),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(border: i == kinds.length - 1 ? null : const Border(bottom: BorderSide(color: Color(0xFFF3F5FA)))),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                            Row(children: [
                              Expanded(child: m.Text(tr('${k['name']}'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: C.ink, height: 1.25))),
                              if (have.isNotEmpty) stateChip('Attached', 'a') else if (need) stateChip('Missing', 'x'),
                              const SizedBox(width: 6),
                              busy == '${k['key']}'
                                  ? const Padding(padding: EdgeInsets.symmetric(horizontal: 14), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5)))
                                  : stateChip(have.isEmpty ? 'Upload' : 'Add', 'w', key: Key('doc-add-${k['key']}'), onTap: () => _add(k)),
                            ]),
                            for (final d in have)
                              GestureDetector(
                                key: Key('doc-open-${d['id']}'),
                                behavior: HitTestBehavior.opaque,
                                onTap: () => _open(d),
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Row(children: [
                                    Icon('${d['mime']}' == 'application/pdf' ? Icons.picture_as_pdf_rounded : Icons.image_rounded, size: 17, color: C.faint),
                                    const SizedBox(width: 6),
                                    Expanded(child: m.Text([if ('${d['number'] ?? ''}'.isNotEmpty) '${d['number']}', dayName('${d['created_at'] ?? ''}'.length >= 10 ? '${d['created_at']}'.substring(0, 10) : '')].where((x) => x.isNotEmpty).join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: C.muted))),
                                    const Text('Open', mr: 'उघडा', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: C.blue)),
                                  ]),
                                ),
                              ),
                          ]),
                        );
                      }(),
                  ]),
              ]),
            ),
    );
  }
}

/// SALARY SLIPS – they come from payroll, which the HR office has not started yet: nothing is shown before.
class SalarySlipsScreen extends StatelessWidget {
  const SalarySlipsScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: hrHead(context, sky: kMeSky, title: 'Salary slips', mr: 'पगार पावत्या', height: 64),
        body: ListView(key: const Key('slips-page'), padding: const EdgeInsets.fromLTRB(16, 14, 16, 40), children: [
          hrCard([
            hrTitle('No salary slip yet', 'अजून पगार पावती नाही'),
            const Text('Your salary slip of each month comes here when the HR office starts payroll in this app.', mr: 'HR office या app मध्ये payroll सुरू केल्यावर प्रत्येक महिन्याची पगार पावती इथे येईल.', style: TextStyle(fontSize: 13, color: C.muted, height: 1.5)),
          ]),
        ]),
      );
}

/// MY PHONE – the one his attendance is tied to.
class MyPhoneScreen extends StatelessWidget {
  const MyPhoneScreen({super.key, required this.phone, required this.day});
  final Map phone;
  final Map<String, dynamic>? day;
  @override
  Widget build(BuildContext context) {
    final bound = phone['bound'] == true, here = '${day?['phone'] ?? ''}';
    return Scaffold(
      appBar: hrHead(context, sky: kMeSky, title: 'My phone', mr: 'माझा phone', height: 64),
      body: ListView(key: const Key('phone-page'), padding: const EdgeInsets.fromLTRB(16, 14, 16, 40), children: [
        hrCard([
          hrTitle(bound ? 'Registered for attendance' : 'No phone registered yet', bound ? 'हजेरीसाठी नोंदलेला' : 'अजून phone नोंदलेला नाही'),
          if (bound && '${phone['model'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 6), child: m.Text('${phone['model']}', key: const Key('phone-model'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: C.ink))),
          if (here == 'this') Padding(padding: const EdgeInsets.only(bottom: 8), child: stateChip('This phone', 'a')) else if (here == 'other') Padding(padding: const EdgeInsets.only(bottom: 8), child: stateChip('Another phone', 'x')),
          Text(
              bound
                  ? 'Your attendance is marked only from this one phone. Another phone works only after the HR Admin releases this one.'
                  : 'The phone you mark your first attendance with becomes your phone. Afterwards another phone works only after the HR Admin releases it.',
              mr: bound ? 'तुमची हजेरी फक्त या एका phone वरून लागते. HR Admin ने हा सोडल्यावरच दुसरा phone चालतो.' : 'ज्या phone वरून पहिली हजेरी लावाल तो तुमचा phone होतो. नंतर HR Admin ने सोडल्यावरच दुसरा phone चालतो.',
              style: const TextStyle(fontSize: 13, color: C.muted, height: 1.5)),
        ]),
      ]),
    );
  }
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
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: pick == code ? kNavy : Colors.transparent, width: 2), boxShadow: kSoftShadow),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    m.Text(own, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: C.ink)),
                    m.Text(en, style: const TextStyle(fontSize: 12, color: C.muted)),
                  ]),
                ),
                Container(width: 22, height: 22, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: pick == code ? kNavy : const Color(0xFFC9CFDC), width: pick == code ? 7 : 2))),
              ]),
            ),
          ),
        );
    return Scaffold(
      appBar: hrHead(context, sky: kMeSky, title: 'Language', mr: 'भाषा', height: 96, below: [
        Text('The whole app is shown in one language.', mr: 'संपूर्ण app एका भाषेत दिसते.', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.5, color: Colors.white.withValues(alpha: .95))),
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
      if (mounted) toast(context, 'Password changed');
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
          _li(key: const Key('acc-id'), sign: '@', c: kNavy, soft: const Color(0xFFEEF1F7), en: 'User ID', mr: 'User ID', sub: s.email, arrow: false),
          if (s.mailVerified) _li(key: const Key('acc-verified'), sign: '✓', c: const Color(0xFF0F7A45), soft: const Color(0xFFE3F7EC), en: 'E-mail verified', mr: 'E-mail verify झाला', sub: s.mailLogin, arrow: false),
          if (s.mailCanVerify)
            _li(key: const Key('acc-verify'), sign: '!', c: const Color(0xFF8A5A00), soft: const Color(0xFFFFF3D1), en: 'Verify my e-mail', mr: 'माझा e-mail verify करा', sub: _t('Then you can also sign in with a code by e-mail', 'मग e-mail वरील code ने सुद्धा sign in करता येईल'), onTap: () async {
              await openVerifyEmail(context);
              if (mounted) setState(() {});
            }),
          _li(key: const Key('acc-pw'), sign: 'P', c: kNavy, soft: const Color(0xFFEEF1F7), en: 'Change password', mr: 'Password बदला', sub: _t('One password for everything', 'सगळ्यासाठी एकच password'), last: true, onTap: _password),
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
        const Padding(padding: EdgeInsets.fromLTRB(20, 16, 20, 6), child: Align(alignment: Alignment.centerLeft, child: Text('My photo', mr: 'माझा photo', style: TextStyle(fontFamily: 'Montserrat', fontSize: 16, fontWeight: FontWeight.w800, color: C.ink)))),
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
    if (context.mounted) toast(context, _t('Your photo is set.', 'तुमचा photo ठेवला.'));
    return true;
  } catch (e) {
    if (context.mounted) toast(context, errText(e), bad: true);
    return false;
  }
}

/// His face: his photo when he has set one (a link of the HR server), else the first letters of his name.
Widget hrFace(String name, String url, {required double size, required double radius, Color bg = kNavy, Color? border, double letters = 15}) {
  final abc = m.Text(initials(name), style: TextStyle(fontFamily: 'Montserrat', fontSize: letters, fontWeight: FontWeight.w800, color: Colors.white));
  return Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(radius), border: border == null ? null : Border.all(color: border, width: 2)),
    child: url.isEmpty ? abc : Image.network(url, key: const Key('face-pic'), width: size, height: size, fit: BoxFit.cover, gaplessPlayback: true, errorBuilder: (_, __, ___) => abc, loadingBuilder: (_, child, p) => p == null ? child : abc),
  );
}
