/* (3.160.0, rcl-hr step 21 – the pictures he approved on 21-11-2026) THE HR THINGS OF STEP 21 IN THE APP – the app's own screens,
 * the same server actions, checks and access as the web:
 *   OUR TEAM (teamAll)            – every employee of every site: name, photo, designation, site, mobile, e-mail, the birthday with the
 *                                   age (never the year); today's and the coming week's birthdays on top. For everybody.
 *   APPROVALS (flowList …)        – what waits for ME, what I approved, what I rejected: a punch from outside (how far, the reason, his
 *                                   voice, the photos) and a new employee; Verify / Approve / Reject (a reject asks for the reason).
 *   A PUNCH FROM OUTSIDE          – the reason spoken (the phone writes it, he corrects it; his voice is kept where the phone gives the
 *                                   microphone to both) or typed, and at least one photo TAKEN BY THE CAMERA with the time and the place
 *                                   written on it (no gallery). attendance.dart sends the punch with them; it waits for his steps.
 *   RELEASE PHONE (devList …)     – who may: the phone of a person of his site, with the reason.
 *   TRANSFERS (transferList …)    – who may: send a person to any site (some days / permanent); the new site accepts (from which day,
 *                                   all / selected places) or rejects with the reason.
 * Nothing is kept on the phone; a thing the person may not do is refused by the server with its own words. */
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart' hide Text;
import 'package:flutter/material.dart' as m show Text;
import 'package:url_launcher/url_launcher.dart';

import '../core/photo.dart';
import '../core/vl_voice.dart';
import '../core/voice.dart';
import '../ui/design.dart';
import '../ui/hr_look.dart';
import '../ui/hr_skin.dart';
import '../ui/scope.dart';
import '../ui/t.dart';
import '../ui/widgets.dart';
import 'attend_reqs.dart' show HrAsk;
import 'hr_me.dart' show kMeSky;
import 'hr_shell.dart' show initials;

String _t(String en, String mr) => Lang.i.pair(en, mr);
String _dmy(Object? d) {
  final t = '${d ?? ''}';
  return t.length >= 10 ? '${t.substring(8, 10)}-${t.substring(5, 7)}-${t.substring(0, 4)}' : t;
}

/// "13:42" of a moment the server gave (India time).
String _hm(Object? iso) {
  final t = DateTime.tryParse('${iso ?? ''}');
  if (t == null) return '';
  final i = t.toUtc().add(const Duration(hours: 5, minutes: 30));
  return '${two(i.hour)}:${two(i.minute)}';
}

/// A card whose rows can be pressed (ListTile, check boxes): the rows get their own Material inside the card's box.
Widget _tapCard(List<Widget> children, {Key? key}) => hrCard(key: key, [Material(type: MaterialType.transparency, child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: children))]);

const _cats = {'staff': 'Staff', 'operator': 'Operator', 'driver': 'Driver', 'labour': 'Labour'};

Widget _face(Map p, {double size = 48}) {
  final url = '${p['photo'] ?? ''}';
  return Container(
    width: size,
    height: size,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(shape: BoxShape.circle, color: sk.dark ? const Color(0xFF26324D) : const Color(0xFFE8ECF8)),
    alignment: Alignment.center,
    child: url.isEmpty
        ? m.Text(initials('${p['name'] ?? ''}'), style: TextStyle(fontFamily: 'Montserrat', fontSize: size * .32, fontWeight: FontWeight.w800, color: const Color(0xFF2C5BD8)))
        : Image.network(url, width: size, height: size, fit: BoxFit.cover, errorBuilder: (_, __, ___) => m.Text(initials('${p['name'] ?? ''}'), style: TextStyle(fontSize: size * .32, fontWeight: FontWeight.w800, color: const Color(0xFF2C5BD8)))),
  );
}

Widget _title(String en, String mr) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
      child: Text(en, mr: mr, style: TextStyle(fontFamily: 'Montserrat', fontSize: 15.5, fontWeight: FontWeight.w800, color: sk.ink)),
    );

/// The three parts of a page: Waiting · Approved · Rejected (or any others).
Widget _tabs(List<(String, String, String)> tabs, String on, void Function(String) pick) => Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: sk.dark ? const Color(0xFF1B2437) : const Color(0xFFE6E9F2), borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        for (final t in tabs)
          Expanded(
            child: GestureDetector(
              key: Key('tab-${t.$1}'),
              behavior: HitTestBehavior.opaque,
              onTap: () => pick(t.$1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: on == t.$1 ? (sk.dark ? const Color(0xFF2B3650) : Colors.white) : Colors.transparent, borderRadius: BorderRadius.circular(11)),
                child: Text(t.$2, mr: t.$3, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: on == t.$1 ? sk.ink : sk.muted)),
              ),
            ),
          ),
      ]),
    );

/// A reason asked in a small window; null = he went back. [must]: it cannot be empty.
Future<String?> _askReason(BuildContext context, String en, String mr, {bool must = true, String yesEn = 'OK', String yesMr = 'ठीक'}) async {
  final c = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (d) => AlertDialog(
      title: Text(en, mr: mr, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      content: TextField(key: const Key('reason-box'), controller: c, autofocus: true, maxLength: 300, minLines: 1, maxLines: 3, decoration: InputDecoration(hintText: _t('Reason', 'कारण'))),
      actions: [
        TextButton(key: const Key('reason-no'), onPressed: () => Navigator.pop(d, false), child: const Text('Cancel', mr: 'रद्द')),
        FilledButton(key: const Key('reason-yes'), onPressed: () => Navigator.pop(d, true), child: Text(yesEn, mr: yesMr)),
      ],
    ),
  );
  final v = c.text.trim();
  if (ok != true) return null;
  if (must && v.length < 3) {
    if (context.mounted) toast(context, _t('Write the reason.', 'कारण लिहा.'), bad: true);
    return null;
  }
  return v;
}

/* ───────────────────────── OUR TEAM ───────────────────────── */
class OurTeamScreen extends StatefulWidget {
  const OurTeamScreen({super.key, required this.ask});
  final HrAsk ask;
  @override
  State<OurTeamScreen> createState() => _OurTeamScreenState();
}

class _OurTeamScreenState extends State<OurTeamScreen> {
  Map j = const {};
  bool loading = true;
  String err = '', q = '', site = '';
  Timer? wait;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    wait?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await widget.ask({'action': 'teamAll', 'q': q, 'site': site});
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

  void _typed(String v) {
    wait?.cancel();
    wait = Timer(const Duration(milliseconds: 350), () {
      q = v.trim();
      _load();
    });
  }

  Future<void> _go(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Widget _round(Key key, IconData icon, VoidCallback onTap) => GestureDetector(
        key: key,
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(color: sk.dark ? const Color(0xFF26324D) : const Color(0xFFEEF1F8), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, size: 18, color: sk.ink),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final people = (j['people'] as List? ?? const []).whereType<Map>().toList(), sites = (j['sites'] as List? ?? const []).whereType<Map>().toList();
    final days = (j['birthdays'] as List? ?? const []).whereType<Map>().toList();
    return Scaffold(
      appBar: hrHead(context, sky: kMeSky, title: 'Our team', mr: 'आपली टीम', height: 64),
      body: loading
          ? const SkeletonList(tiles: 0, rows: 5)
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(key: const Key('ourteam-page'), padding: const EdgeInsets.fromLTRB(16, 14, 16, 40), children: [
                TextField(
                  key: const Key('ourteam-q'),
                  onChanged: _typed,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(hintText: _t('Search name, mobile, site', 'नाव, mobile, site शोधा'), prefixIcon: const Icon(Icons.search_rounded), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)), isDense: true),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    Padding(padding: const EdgeInsets.only(right: 6), child: stateChip(_t('All sites · ${j['total'] ?? 0}', 'सगळ्या site · ${j['total'] ?? 0}'), site.isEmpty ? 'w' : '', key: const Key('ourteam-site-all'), onTap: () => setState(() { site = ''; _load(); }))),
                    for (final s in sites)
                      Padding(padding: const EdgeInsets.only(right: 6), child: stateChip('${s['code']} · ${s['count']}', site == '${s['code']}' ? 'w' : '', key: Key('ourteam-site-${s['code']}'), onTap: () => setState(() { site = '${s['code']}'; _load(); }))),
                  ]),
                ),
                if (err.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: InfoLine(err, bad: true, help: false, key: const Key('ourteam-err'))),
                if (days.isNotEmpty && q.isEmpty) ...[
                  _title('Birthdays', 'वाढदिवस'),
                  hrCard(key: const Key('ourteam-bdays'), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4), [
                    for (final (i, b) in days.take(8).indexed)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(border: i == 0 ? null : Border(top: BorderSide(color: sk.dark ? const Color(0xFF26324D) : const Color(0xFFF3F5FA)))),
                        child: Row(children: [
                          _face(b, size: 40),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                              m.Text('${b['name'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: sk.ink)),
                              m.Text(['${b['designation'] ?? ''}', '${b['site'] ?? ''}'].where((x) => x.isNotEmpty).join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: sk.muted)),
                            ]),
                          ),
                          stateChip(b['today'] == true ? _t('Today', 'आज') : '${b['day'] ?? ''}', b['today'] == true ? 'a' : ''),
                        ]),
                      ),
                  ]),
                ],
                _title('People', 'लोक'),
                if (people.isEmpty && err.isEmpty) InfoLine(_t('Nobody found.', 'कोणी सापडले नाही.'), help: false, key: const Key('ourteam-none')),
                for (final p in people)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: hrCard(key: Key('ourteam-${p['id']}'), padding: const EdgeInsets.fromLTRB(14, 12, 12, 8), [
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        _face(p, size: 54),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                            m.Text('${p['name'] ?? ''}', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: sk.ink)),
                            m.Text(['${p['designation'] ?? ''}', _cats['${p['category']}'] ?? ''].where((x) => x.isNotEmpty).join(' · '), style: TextStyle(fontSize: 12.5, color: sk.muted, height: 1.35)),
                            m.Text(['${p['site'] ?? ''}', '${p['department'] ?? ''}'].where((x) => x.isNotEmpty).join(' · '), style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: sk.ink, height: 1.35)),
                            if ('${p['mobile'] ?? ''}'.isNotEmpty) m.Text('${p['mobile']}', style: TextStyle(fontSize: 12.5, color: sk.muted, height: 1.35)),
                            if ('${p['email'] ?? ''}'.isNotEmpty) m.Text('${p['email']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: sk.muted, height: 1.35)),
                            if ('${p['birthday'] ?? ''}'.isNotEmpty)
                              m.Text(_t('Birthday ${p['birthday']}', 'वाढदिवस ${p['birthday']}') + (p['age'] is num ? _t(' · ${p['age']} years', ' · ${p['age']} वर्षं') : ''), style: TextStyle(fontSize: 12.5, color: sk.muted, height: 1.35)),
                          ]),
                        ),
                        Column(mainAxisSize: MainAxisSize.min, children: [
                          if ('${p['mobile'] ?? ''}'.isNotEmpty) _round(Key('ourteam-call-${p['id']}'), Icons.call_outlined, () => _go('tel:${p['mobile']}')),
                          if ('${p['email'] ?? ''}'.isNotEmpty) _round(Key('ourteam-mail-${p['id']}'), Icons.mail_outline_rounded, () => _go('mailto:${p['email']}')),
                        ]),
                      ]),
                    ]),
                  ),
                if (j['more'] == true) InfoLine(_t('More people: search by name or choose a site.', 'अजून लोक आहेत: नावाने शोधा किंवा site निवडा.'), help: false),
              ]),
            ),
    );
  }
}

/* ───────────────────────── APPROVALS ───────────────────────── */
class ApprovalsScreen extends StatefulWidget {
  const ApprovalsScreen({super.key, required this.ask});
  final HrAsk ask;
  @override
  State<ApprovalsScreen> createState() => _ApprovalsScreenState();
}

class _ApprovalsScreenState extends State<ApprovalsScreen> {
  String tab = 'waiting', err = '';
  List<Map> rows = const [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await widget.ask({'action': 'flowList', 'tab': tab});
      if (!mounted) return;
      setState(() {
        rows = (r['rows'] as List? ?? const []).whereType<Map>().toList();
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

  void _pick(String t) {
    setState(() {
      tab = t;
      loading = true;
    });
    _load();
  }

  String _what(Map f) => f['kind'] == 'outside_punch'
      ? _t('${f['punch'] == 'out' ? 'PUNCH OUT' : 'PUNCH IN'} from outside · ${_dmy(f['day'])} ${_hm(f['at'])}${'${f['distance'] ?? ''}'.isEmpty ? '' : ' · ${f['distance']} from ${f['place']}'}',
          'बाहेरून ${f['punch'] == 'out' ? 'PUNCH OUT' : 'PUNCH IN'} · ${_dmy(f['day'])} ${_hm(f['at'])}${'${f['distance'] ?? ''}'.isEmpty ? '' : ' · ${f['place']} पासून ${f['distance']}'}')
      : _t('New employee · added by ${f['asked_by']}', 'नवीन employee · ${f['asked_by']} ने जोडला');

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: hrHead(context, sky: kMeSky, title: 'Approvals', mr: 'Approvals', height: 64),
        body: RefreshIndicator(
          onRefresh: _load,
          child: ListView(key: const Key('appr-page'), padding: const EdgeInsets.fromLTRB(16, 14, 16, 40), children: [
            _tabs(const [('waiting', 'Waiting', 'थांबलेले'), ('approved', 'Approved', 'Approved'), ('rejected', 'Rejected', 'Rejected')], tab, _pick),
            const SizedBox(height: 12),
            if (err.isNotEmpty) InfoLine(err, bad: true, help: false, key: const Key('appr-err')),
            if (loading) const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator())),
            if (!loading && rows.isEmpty && err.isEmpty)
              InfoLine(tab == 'waiting' ? _t('Nothing waits for you.', 'तुमच्याकडे काही थांबलेले नाही.') : _t('Nothing here yet.', 'इथे अजून काही नाही.'), help: false, key: const Key('appr-none')),
            if (!loading)
              for (final f in rows)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GestureDetector(
                    key: Key('appr-${f['id']}'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () async {
                      final changed = await Navigator.of(context).push<bool>(hrRoute(ApprovalOpenScreen(ask: widget.ask, id: '${f['id']}')));
                      if (changed == true) _load();
                    },
                    child: hrCard(padding: const EdgeInsets.fromLTRB(14, 12, 14, 12), [
                      Row(children: [
                        _face(f, size: 44),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                            m.Text('${f['name'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: sk.ink)),
                            m.Text(_what(f), style: TextStyle(fontSize: 12.5, color: sk.muted, height: 1.35)),
                            if ('${f['waits'] ?? ''}'.isNotEmpty) m.Text('${f['waits']}', style: TextStyle(fontSize: 12.5, color: sk.muted, height: 1.35)),
                            if ('${f['note'] ?? ''}'.isNotEmpty) m.Text('${f['note']}', style: const TextStyle(fontSize: 12.5, color: Color(0xFFC22A1B), height: 1.35)),
                          ]),
                        ),
                        stateChip(f['status'] == 'pending' ? _t('Step ${(f['step'] as num? ?? 0) + 1} of ${f['of'] ?? 1}', 'Step ${(f['step'] as num? ?? 0) + 1} / ${f['of'] ?? 1}') : f['status'] == 'approved' ? 'Approved' : 'Rejected', f['status'] == 'pending' ? 'w' : f['status'] == 'approved' ? 'a' : 'x'),
                      ]),
                    ]),
                  ),
                ),
          ]),
        ),
      );
}

/// One thing with its proof and the decision of the person it waits for. Pops true when something was decided.
class ApprovalOpenScreen extends StatefulWidget {
  const ApprovalOpenScreen({super.key, required this.ask, required this.id});
  final HrAsk ask;
  final String id;
  @override
  State<ApprovalOpenScreen> createState() => _ApprovalOpenScreenState();
}

class _ApprovalOpenScreenState extends State<ApprovalOpenScreen> {
  Map f = const {};
  bool loading = true, busy = false;
  String err = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await widget.ask({'action': 'flowOpen', 'id': widget.id});
      if (!mounted) return;
      setState(() {
        f = (r['flow'] as Map?) ?? const {};
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

  Future<void> _decide(bool ok) async {
    var note = '';
    if (!ok) {
      final r = await _askReason(context, 'Why is it rejected?', 'Reject का?', yesEn: 'Reject', yesMr: 'Reject');
      if (r == null) return;
      note = r;
    }
    if (!mounted) return;
    setState(() => busy = true);
    try {
      final r = await widget.ask({'action': 'flowDecide', 'id': widget.id, 'ok': ok, 'note': note});
      if (!mounted) return;
      final st = '${(r['flow'] as Map?)?['status'] ?? ''}';
      toast(context, st == 'approved' ? _t('Approved.', 'Approve झाले.') : st == 'rejected' ? _t('Rejected.', 'Reject झाले.') : _t('Done – it moved to the next step.', 'झाले – पुढच्या step कडे गेले.'));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          err = errText(e);
        });
      }
    }
  }

  Future<void> _go(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final near = (f['near'] as List? ?? const []).whereType<Map>().toList(), photos = (f['photo_list'] as List? ?? const []).whereType<Map>().toList(), chain = (f['chain'] as List? ?? const []).whereType<Map>().toList();
    final steps = (f['steps'] as List? ?? const []).whereType<Map>().toList(), outside = f['kind'] == 'outside_punch', can = f['can'] == true;
    return Scaffold(
      appBar: hrHead(context, sky: kMeSky, title: outside ? 'Outside punch' : 'New employee', mr: outside ? 'बाहेरून punch' : 'नवीन employee', height: 64),
      body: loading
          ? const SkeletonList(tiles: 0, rows: 4)
          : ListView(key: const Key('appr-open'), padding: const EdgeInsets.fromLTRB(16, 14, 16, 40), children: [
              if (err.isNotEmpty) InfoLine(err, bad: true, help: false, key: const Key('appr-open-err')),
              hrCard([
                Row(children: [
                  _face(f, size: 46),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      m.Text('${f['name'] ?? ''}', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: sk.ink)),
                      m.Text(outside ? '${f['punch'] == 'out' ? 'PUNCH OUT' : 'PUNCH IN'} · ${_dmy(f['day'])} ${_hm(f['at'])} · ${f['site'] ?? ''}' : _t('Added by ${f['asked_by'] ?? ''} · ${f['site'] ?? ''}', '${f['asked_by'] ?? ''} ने जोडला · ${f['site'] ?? ''}'), style: TextStyle(fontSize: 12.5, color: sk.muted, height: 1.35)),
                    ]),
                  ),
                ]),
              ]),
              if (outside) ...[
                const SizedBox(height: 10),
                hrCard(key: const Key('appr-where'), [
                  Text('Where he was', mr: 'तो कुठे होता', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: sk.ink)),
                  const SizedBox(height: 6),
                  for (final (i, n) in near.indexed)
                    m.Text(i == 0 ? _t('Nearest work place: ${n['name']} – ${n['distance']} away', 'जवळची work place: ${n['name']} – ${n['distance']} लांब') : _t('Next: ${n['name']} – ${n['distance']}', 'पुढची: ${n['name']} – ${n['distance']}'),
                        style: TextStyle(fontSize: 13, height: 1.4, fontWeight: i == 0 ? FontWeight.w700 : FontWeight.w400, color: i == 0 ? const Color(0xFFC22A1B) : sk.muted)),
                  if (near.isEmpty && '${f['place'] ?? ''}'.isNotEmpty) m.Text(_t('Nearest work place: ${f['place']} – ${f['distance']} away', 'जवळची work place: ${f['place']} – ${f['distance']} लांब'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFC22A1B))),
                  if (f['lat'] is num && f['lng'] is num)
                    Align(alignment: Alignment.centerLeft, child: TextButton.icon(key: const Key('appr-map'), onPressed: () => _go('https://www.google.com/maps?q=${f['lat']},${f['lng']}'), icon: const Icon(Icons.map_outlined, size: 18), label: const Text('Open the place on the map', mr: 'नकाशावर जागा उघडा'))),
                ]),
                const SizedBox(height: 10),
                hrCard(key: const Key('appr-reason'), [
                  Text('Reason', mr: 'कारण', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: sk.ink)),
                  const SizedBox(height: 6),
                  m.Text('${f['reason'] ?? ''}', style: TextStyle(fontSize: 14, height: 1.4, color: sk.ink)),
                  if ('${f['voice_url'] ?? ''}'.isNotEmpty)
                    Align(alignment: Alignment.centerLeft, child: TextButton.icon(key: const Key('appr-voice'), onPressed: () => _go('${f['voice_url']}'), icon: const Icon(Icons.play_circle_outline_rounded, size: 20), label: const Text('Hear his voice', mr: 'त्याचा आवाज ऐका'))),
                ]),
                const SizedBox(height: 10),
                hrCard(key: const Key('appr-photos'), [
                  Text('Proof photos (camera)', mr: 'Proof photo (camera)', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: sk.ink)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final p in photos)
                      if ('${p['url'] ?? ''}'.isNotEmpty) GestureDetector(onTap: () => _go('${p['url']}'), child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network('${p['url']}', width: 104, height: 104, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(width: 104, height: 104, color: const Color(0xFFE8ECF8), alignment: Alignment.center, child: const Icon(Icons.image_outlined))))),
                    if ('${f['selfie_url'] ?? ''}'.isNotEmpty) GestureDetector(onTap: () => _go('${f['selfie_url']}'), child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network('${f['selfie_url']}', width: 104, height: 104, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(width: 104, height: 104, color: const Color(0xFFE8ECF8), alignment: Alignment.center, child: const Icon(Icons.person_outline_rounded))))),
                  ]),
                ]),
              ],
              if (!outside) Padding(padding: const EdgeInsets.only(top: 10), child: InfoLine(_t('His full form and papers are on the web: HR › Employees › New employees › Waiting for me.', 'त्याचा पूर्ण form आणि कागद web वर आहेत: HR › Employees › New employees › Waiting for me.'), help: false, key: const Key('appr-web'))),
              const SizedBox(height: 10),
              hrCard(key: const Key('appr-steps'), [
                Text('Step by step', mr: 'Step by step', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: sk.ink)),
                const SizedBox(height: 6),
                for (final (i, c) in chain.indexed)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      stateChip('Step ${i + 1}', i < steps.length ? (steps[i]['ok'] == true ? 'a' : 'x') : c['here'] == true ? 'w' : ''),
                      const SizedBox(width: 8),
                      Expanded(child: m.Text('${c['stage'] == 'verify' ? 'Verify' : 'Approve'} – ${c['name'] ?? ''}${i < steps.length ? ' · ${steps[i]['ok'] == true ? 'done' : 'rejected'}${'${steps[i]['note'] ?? ''}'.isEmpty ? '' : ' · ${steps[i]['note']}'}' : c['here'] == true ? ' · waiting' : ''}', style: TextStyle(fontSize: 13, color: sk.ink, height: 1.35))),
                    ]),
                  ),
              ]),
              if (can) ...[
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: OutlinedButton(key: const Key('appr-no'), onPressed: busy ? null : () => _decide(false), style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFC22A1B), padding: const EdgeInsets.symmetric(vertical: 14)), child: const Text('Reject', mr: 'Reject'))),
                  const SizedBox(width: 10),
                  Expanded(child: FilledButton(key: const Key('appr-yes'), onPressed: busy ? null : () => _decide(true), style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)), child: Text(f['stage'] == 'verify' ? 'Verify' : 'Approve', mr: f['stage'] == 'verify' ? 'Verify' : 'Approve'))),
                ]),
              ],
            ]),
    );
  }
}

/* ───────────────────────── A PUNCH FROM OUTSIDE: THE REASON AND THE PROOF ───────────────────────── */
/// What he gave: his words, his voice (may be null) and the photos of the camera (each with its moment and place).
class OutsideProof {
  OutsideProof(this.reason, this.voice, this.photos);
  final String reason;
  final Uint8List? voice;
  final List<TakenPhoto> photos;
}

/// Sends the proof to its place (rcl-hr proofUrl) and gives the punch's "outside" part. [put]: the upload (api.hrFile).
Future<Map<String, dynamic>> sendOutsideProof(HrAsk ask, Future<void> Function(String url, List<int> bytes, String type) put, OutsideProof p) async {
  final photos = <Map<String, dynamic>>[];
  for (final x in p.photos) {
    final u = await ask({'action': 'proofUrl', 'kind': 'photo'});
    await put('${u['url']}', x.jpg, 'image/jpeg');
    photos.add({'path': u['path'], 'at': x.at.toUtc().toIso8601String(), 'lat': x.spot.lat, 'lng': x.spot.lng});
  }
  String? voice;
  if (p.voice != null) {
    try {
      final u = await ask({'action': 'proofUrl', 'kind': 'voice', 'ext': 'm4a'});
      await put('${u['url']}', p.voice!, 'audio/mp4');
      voice = '${u['path']}';
    } catch (_) {
      voice = null; // the voice could not be kept: his words and the photos are enough
    }
  }
  return {'reason': p.reason, if (voice != null) 'voice': voice, 'photos': photos};
}

class OutsideReasonScreen extends StatefulWidget {
  const OutsideReasonScreen({super.key, required this.kind, required this.place, required this.distance});

  /// 'in' / 'out'
  final String kind, place;
  final int distance;
  @override
  State<OutsideReasonScreen> createState() => _OutsideReasonScreenState();
}

class _OutsideReasonScreenState extends State<OutsideReasonScreen> {
  final words = TextEditingController();
  final photos = <TakenPhoto>[];
  Uint8List? voice;
  bool listening = false, busy = false;
  String err = '';

  @override
  void dispose() {
    words.dispose();
    super.dispose();
  }

  String get _far => widget.distance >= 1000 ? '${(widget.distance / 100).round() / 10} km' : '${widget.distance} m';

  Future<void> _listen() async {
    if (listening) {
      await stopListening();
      return;
    }
    setState(() {
      listening = true;
      err = '';
    });
    final keep = SessionScope.read(context).api.keep, rec = await VlVoice.i.allowed(keep);
    if (rec) await VlVoice.i.start(); // his voice is kept while the phone listens – where the phone gives both the microphone
    try {
      final lang = const ['mr', 'hi', 'en'].contains(Lang.i.code) ? Lang.i.code : 'mr';
      final w = await listenOnce(lang, (x) {
        if (mounted) setState(() => words.text = x);
      });
      final v = rec ? await VlVoice.i.stop() : null;
      if (v != null) voice = v;
      if (!mounted) return;
      if (w.trim().isNotEmpty) {
        words.text = w.trim();
      } else if (v != null && words.text.trim().isEmpty) {
        await VlVoice.i.notBoth(keep);
        if (mounted) setState(() => err = _t('Nothing was heard – press the mic again and say it, or type the reason.', 'काहीच ऐकू आले नाही – mic पुन्हा दाबा आणि सांगा, किंवा कारण टाइप करा.'));
      }
    } catch (_) {
      if (rec) await VlVoice.i.stop();
      if (mounted) setState(() => err = _t('The phone could not listen – type the reason.', 'फोन ऐकू शकला नाही – कारण टाइप करा.'));
    } finally {
      if (mounted) setState(() => listening = false);
    }
  }

  Future<void> _photo() async {
    if (photos.length >= 4 || busy) return;
    setState(() {
      busy = true;
      err = '';
    });
    try {
      // the camera only (photo.dart cameraShot – never the gallery on a phone); the time and the place are written on the photo
      final p = await cameraShot('${widget.kind == 'out' ? 'PUNCH OUT' : 'PUNCH IN'} from outside', '$_far from ${widget.place}');
      if (p != null && mounted) setState(() => photos.add(p));
    } on PhotoProblem catch (e) {
      if (mounted) setState(() => err = '$e');
    } catch (_) {
      if (mounted) setState(() => err = _t('The photo could not be taken – try again.', 'Photo काढता आला नाही – पुन्हा करा.'));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _done() {
    final r = words.text.trim();
    if (r.length < 10) {
      setState(() => err = _t('Say or write the reason – why you mark attendance from outside your work place.', 'कारण सांगा किंवा लिहा – work place च्या बाहेरून हजेरी का लावत आहात.'));
      return;
    }
    if (photos.isEmpty) {
      setState(() => err = _t('Take at least one photo as proof – with the camera, now.', 'Proof म्हणून किमान एक photo काढा – camera ने, आत्ता.'));
      return;
    }
    Navigator.of(context).pop(OutsideProof(r, voice, List.of(photos)));
  }

  @override
  Widget build(BuildContext context) {
    final out = widget.kind == 'out';
    return Scaffold(
      appBar: hrHead(context, sky: kMeSky, title: out ? 'Punch out – outside' : 'Punch in – outside', mr: out ? 'Punch out – बाहेरून' : 'Punch in – बाहेरून', height: 64),
      body: ListView(key: const Key('outside-page'), padding: const EdgeInsets.fromLTRB(16, 14, 16, 40), children: [
        InfoLine(_t('You are $_far from ${widget.place}. This punch waits for approval – it counts only when it is approved.', 'तुम्ही ${widget.place} पासून $_far लांब आहात. हा punch approval साठी थांबेल – approve झाल्यावरच मोजला जाईल.'), help: false, key: const Key('outside-far')),
        const SizedBox(height: 10),
        hrCard(key: const Key('outside-reason'), [
          Text('1 · Say the reason', mr: '1 · कारण सांगा', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: sk.ink)),
          const SizedBox(height: 10),
          Center(
            child: GestureDetector(
              key: const Key('outside-mic'),
              onTap: _listen,
              child: Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(shape: BoxShape.circle, color: listening ? const Color(0xFFC22A1B) : const Color(0xFF0F1F3D), boxShadow: [BoxShadow(color: (listening ? const Color(0xFFC22A1B) : const Color(0xFF0F1F3D)).withValues(alpha: .18), spreadRadius: 9)]),
                child: Icon(listening ? Icons.stop_rounded : Icons.mic_rounded, color: const Color(0xFFF3D27A), size: 34),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Center(child: Text(listening ? 'Listening… press to stop' : 'Press and speak – or type below', mr: listening ? 'ऐकत आहे… थांबवायला दाबा' : 'दाबा आणि बोला – किंवा खाली टाइप करा', style: TextStyle(fontSize: 12.5, color: sk.muted))),
          const SizedBox(height: 10),
          TextField(key: const Key('outside-words'), controller: words, minLines: 2, maxLines: 5, maxLength: 600, decoration: InputDecoration(labelText: _t('What you said (you can correct it)', 'तुम्ही काय सांगितलं (दुरुस्त करू शकता)'), border: const OutlineInputBorder())),
          if (voice != null) Row(children: [const Icon(Icons.graphic_eq_rounded, size: 18, color: Color(0xFF0F7A45)), const SizedBox(width: 6), Text('Your voice is kept', mr: 'तुमचा आवाज ठेवला आहे', key: const Key('outside-voice'), style: const TextStyle(fontSize: 12.5, color: Color(0xFF0F7A45), fontWeight: FontWeight.w600))]),
        ]),
        const SizedBox(height: 10),
        hrCard(key: const Key('outside-photos'), [
          Text('2 · Proof photo', mr: '2 · Proof photo', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: sk.ink)),
          const SizedBox(height: 4),
          Text('Camera only – no gallery. The time and the place are written on the photo.', mr: 'फक्त camera – gallery नाही. Photo वर वेळ आणि ठिकाण लिहिले जाते.', style: TextStyle(fontSize: 12.5, color: sk.muted, height: 1.35)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final (i, p) in photos.indexed)
              Stack(children: [
                ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(p.jpg, key: Key('outside-photo-$i'), width: 96, height: 96, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(width: 96, height: 96, color: const Color(0xFF8FA3B8)))),
                Positioned(right: 2, top: 2, child: GestureDetector(key: Key('outside-photo-x-$i'), onTap: () => setState(() => photos.removeAt(i)), child: const CircleAvatar(radius: 11, backgroundColor: Colors.black54, child: Icon(Icons.close_rounded, size: 14, color: Colors.white)))),
              ]),
            if (photos.length < 4)
              GestureDetector(
                key: const Key('outside-camera'),
                onTap: _photo,
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF9AA2B8), width: 1.5)),
                  alignment: Alignment.center,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.photo_camera_outlined, color: Color(0xFF2C5BD8)), const SizedBox(height: 4), Text('Camera', mr: 'Camera', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF2C5BD8)))]),
                ),
              ),
          ]),
        ]),
        if (err.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: InfoLine(err, bad: true, help: false, key: const Key('outside-err'))),
        const SizedBox(height: 14),
        FilledButton(key: const Key('outside-send'), onPressed: busy ? null : _done, style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15)), child: Text(out ? 'Punch out & send' : 'Punch in & send', mr: out ? 'Punch out करा आणि पाठवा' : 'Punch in करा आणि पाठवा')),
      ]),
    );
  }
}

/* ───────────────────────── RELEASE PHONE ───────────────────────── */
class ReleasePhoneScreen extends StatefulWidget {
  const ReleasePhoneScreen({super.key, required this.ask});
  final HrAsk ask;
  @override
  State<ReleasePhoneScreen> createState() => _ReleasePhoneScreenState();
}

class _ReleasePhoneScreenState extends State<ReleasePhoneScreen> {
  List<Map> rows = const [];
  bool loading = true;
  String err = '', q = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await widget.ask({'action': 'devList'});
      if (!mounted) return;
      setState(() {
        rows = (r['devices'] as List? ?? const []).whereType<Map>().where((d) => d['active'] == true).toList();
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

  Future<void> _release(Map d) async {
    final why = await _askReason(context, 'Release the phone of ${d['name']}?', '${d['name']} चा phone release करायचा?', yesEn: 'Yes, release', yesMr: 'हो, release करा');
    if (why == null || !mounted) return;
    try {
      await widget.ask({'action': 'devRelease', 'id': d['id'], 'reason': why});
      if (!mounted) return;
      toast(context, _t('Released – his next sign-in ties attendance to the new phone.', 'Release झाला – पुढच्या sign-in ला हजेरी नवीन phone शी जोडली जाईल.'));
      await _load();
    } catch (e) {
      if (mounted) setState(() => err = errText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final show = rows.where((d) => q.isEmpty || '${d['name']} ${d['code']}'.toLowerCase().contains(q.toLowerCase())).toList();
    return Scaffold(
      appBar: hrHead(context, sky: kMeSky, title: 'Release phone', mr: 'Phone release', height: 64),
      body: loading
          ? const SkeletonList(tiles: 0, rows: 5)
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(key: const Key('phones-page'), padding: const EdgeInsets.fromLTRB(16, 14, 16, 40), children: [
                TextField(key: const Key('phones-q'), onChanged: (v) => setState(() => q = v.trim()), decoration: InputDecoration(hintText: _t('Search employee', 'Employee शोधा'), prefixIcon: const Icon(Icons.search_rounded), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)), isDense: true)),
                const SizedBox(height: 10),
                if (err.isNotEmpty) InfoLine(err, bad: true, help: false, key: const Key('phones-err')),
                if (show.isEmpty && err.isEmpty) InfoLine(_t('No phone is tied to attendance here.', 'इथे हजेरीला जोडलेला phone नाही.'), help: false, key: const Key('phones-none')),
                if (show.isNotEmpty)
                  hrCard(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4), [
                    for (final (i, d) in show.indexed)
                      Container(
                        key: Key('phone-${d['id']}'),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(border: i == 0 ? null : Border(top: BorderSide(color: sk.dark ? const Color(0xFF26324D) : const Color(0xFFF3F5FA)))),
                        child: Row(children: [
                          _face(d, size: 42),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                              m.Text('${d['name'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: sk.ink)),
                              m.Text(['${d['code'] ?? ''}', '${d['model'] ?? ''}', _t('since ${_dmy(d['bound_at'])}', '${_dmy(d['bound_at'])} पासून')].where((x) => x.isNotEmpty).join(' · '), style: TextStyle(fontSize: 12.5, color: sk.muted, height: 1.35)),
                            ]),
                          ),
                          OutlinedButton(key: Key('phone-release-${d['id']}'), onPressed: () => _release(d), style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40), padding: const EdgeInsets.symmetric(horizontal: 14)), child: const Text('Release', mr: 'Release')),      // (the app's buttons are as wide as their place: in a row it has its own size)
                        ]),
                      ),
                  ]),
                const SizedBox(height: 10),
                InfoLine(_t('Only people of this site. Who released, when and why is kept.', 'फक्त या site चे लोक. कोणी, कधी आणि का release केला ते ठेवले जाते.'), help: false),
              ]),
            ),
    );
  }
}

/* ───────────────────────── TRANSFERS ───────────────────────── */
class TransfersScreen extends StatefulWidget {
  const TransfersScreen({super.key, required this.ask});
  final HrAsk ask;
  @override
  State<TransfersScreen> createState() => _TransfersScreenState();
}

class _TransfersScreenState extends State<TransfersScreen> {
  String tab = 'in', err = '';
  Map setup = const {};
  List<Map> rows = const [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final s = await widget.ask({'action': 'transferSetup'}), r = await widget.ask({'action': 'transferList', 'dir': tab});
      if (!mounted) return;
      setState(() {
        setup = s;
        rows = (r['rows'] as List? ?? const []).whereType<Map>().toList();
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

  void _pick(String t) {
    setState(() {
      tab = t;
      loading = true;
    });
    _load();
  }

  static const _st = {'sent': ('Waiting', 'थांबलेले', 'w'), 'accepted': ('Accepted', 'Accepted', 'a'), 'rejected': ('Rejected', 'Rejected', 'x'), 'cancelled': ('Taken back', 'परत घेतले', ''), 'returned': ('Back', 'परत आला', '')};

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: hrHead(context, sky: kMeSky, title: 'Transfers', mr: 'Transfers', height: 64),
        body: RefreshIndicator(
          onRefresh: _load,
          child: ListView(key: const Key('tr-page'), padding: const EdgeInsets.fromLTRB(16, 14, 16, 40), children: [
            _tabs([('in', 'Coming here${(setup['coming'] as num? ?? 0) > 0 ? ' · ${setup['coming']}' : ''}', 'इथे येणारे${(setup['coming'] as num? ?? 0) > 0 ? ' · ${setup['coming']}' : ''}'), ('out', 'Sent from here', 'इथून पाठवलेले')], tab, _pick),
            const SizedBox(height: 12),
            if (setup['may'] == true)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: FilledButton.icon(
                  key: const Key('tr-new'),
                  onPressed: () async {
                    final ok = await Navigator.of(context).push<bool>(hrRoute(TransferSendScreen(ask: widget.ask, setup: setup)));
                    if (ok == true) _pick('out');
                  },
                  icon: const Icon(Icons.swap_horiz_rounded),
                  label: const Text('Transfer an employee', mr: 'Employee transfer करा'),
                ),
              ),
            if (err.isNotEmpty) InfoLine(err, bad: true, help: false, key: const Key('tr-err')),
            if (loading) const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator())),
            if (!loading && rows.isEmpty && err.isEmpty) InfoLine(tab == 'in' ? _t('Nobody is coming to this site.', 'या site ला कोणी येत नाही.') : _t('Nothing here yet.', 'इथे अजून काही नाही.'), help: false, key: const Key('tr-none')),
            if (!loading)
              for (final t in rows)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GestureDetector(
                    key: Key('tr-${t['id']}'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () async {
                      final ok = await Navigator.of(context).push<bool>(hrRoute(TransferOpenScreen(ask: widget.ask, id: '${t['id']}')));
                      if (ok == true) _load();
                    },
                    child: hrCard(padding: const EdgeInsets.fromLTRB(14, 12, 14, 12), [
                      Row(children: [
                        _face((t['employee'] as Map?) ?? const {}, size: 44),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                            m.Text('${(t['employee'] as Map?)?['name'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: sk.ink)),
                            m.Text('${t['from_site']} › ${t['to_site']} · ${t['mode'] == 'days' ? _t('up to ${_dmy(t['to_day'])}', '${_dmy(t['to_day'])} पर्यंत') : _t('permanent', 'permanent')} · ${_dmy(t['from_day'])}', style: TextStyle(fontSize: 12.5, color: sk.muted, height: 1.35)),
                            if (t['status'] == 'sent' && t['travel'] == true) Text('On his way – may punch at any site', mr: 'वाटेत आहे – कुठल्याही site वर punch करू शकतो', style: TextStyle(fontSize: 12.5, color: sk.muted, height: 1.35)),
                            if ('${t['reject_reason'] ?? ''}'.isNotEmpty) m.Text('${t['reject_reason']}', style: const TextStyle(fontSize: 12.5, color: Color(0xFFC22A1B), height: 1.35)),
                          ]),
                        ),
                        () {
                          final s = _st['${t['status']}'] ?? _st['sent']!;
                          return stateChip(_t(s.$1, s.$2), s.$3);
                        }(),
                      ]),
                    ]),
                  ),
                ),
          ]),
        ),
      );
}

/// A small search of people (rcl-hr apprPick): [here] – only of this site. Returns the person chosen, or null.
Future<Map?> _pickPerson(BuildContext context, HrAsk ask, {bool here = false}) => showModalBottomSheet<Map>(
      context: context,
      isScrollControlled: true,
      builder: (c) {
        List<Map> found = const [];
        Timer? wait;
        return StatefulBuilder(
          builder: (c, set) => SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 14, 16, 14 + MediaQuery.viewInsetsOf(c).bottom),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                  key: const Key('pick-q'),
                  autofocus: true,
                  decoration: InputDecoration(hintText: _t('Search a person', 'व्यक्ती शोधा'), prefixIcon: const Icon(Icons.search_rounded), border: const OutlineInputBorder()),
                  onChanged: (v) {
                    wait?.cancel();
                    wait = Timer(const Duration(milliseconds: 300), () async {
                      if (v.trim().length < 2) return;
                      try {
                        final r = await ask({'action': 'apprPick', 'q': v.trim(), if (here) 'here': 1 else 'any': 1});
                        set(() => found = (r['people'] as List? ?? const []).whereType<Map>().take(12).toList());
                      } catch (_) {}
                    });
                  },
                ),
                const SizedBox(height: 6),
                Flexible(
                  child: ListView(shrinkWrap: true, children: [
                    for (final p in found) ListTile(key: Key('pick-${p['id']}'), dense: true, title: m.Text('${p['name']}'), subtitle: m.Text('${p['code']} · ${p['site']}'), onTap: () => Navigator.pop(c, p)),
                  ]),
                ),
              ]),
            ),
          ),
        );
      },
    );

class TransferSendScreen extends StatefulWidget {
  const TransferSendScreen({super.key, required this.ask, required this.setup});
  final HrAsk ask;
  final Map setup;
  @override
  State<TransferSendScreen> createState() => _TransferSendScreenState();
}

class _TransferSendScreenState extends State<TransferSendScreen> {
  Map? who;
  String to = '', mode = 'permanent', toDay = '', err = '';
  final why = TextEditingController();
  bool busy = false;

  @override
  void dispose() {
    why.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (who == null) {
      setState(() => err = _t('Choose the employee.', 'Employee निवडा.'));
      return;
    }
    setState(() {
      busy = true;
      err = '';
    });
    try {
      await widget.ask({'action': 'transferSend', 'id': who!['id'], 'to_site': to, 'mode': mode, 'to_day': toDay, 'reason': why.text.trim()});
      if (!mounted) return;
      toast(context, _t('Transfer sent – it waits for the new site.', 'Transfer पाठवला – नवीन site च्या accept ची वाट.'));
      Navigator.of(context).pop(true);
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
    final sites = (widget.setup['sites'] as List? ?? const []).whereType<Map>().toList();
    return Scaffold(
      appBar: hrHead(context, sky: kMeSky, title: 'Transfer employee', mr: 'Employee transfer', height: 64),
      body: ListView(key: const Key('trs-page'), padding: const EdgeInsets.fromLTRB(16, 14, 16, 40), children: [
        _tapCard([
          ListTile(
            key: const Key('trs-who'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.person_outline_rounded),
            title: who == null ? const Text('Choose the employee', mr: 'Employee निवडा') : m.Text('${who!['name']}'),
            subtitle: who == null ? null : m.Text('${who!['code']} · ${widget.setup['site'] ?? ''}'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () async {
              final p = await _pickPerson(context, widget.ask, here: true);
              if (p != null && mounted) setState(() => who = p);
            },
          ),
        ]),
        const SizedBox(height: 10),
        _tapCard([
          DropdownButtonFormField<String>(
            key: const Key('trs-to'),
            initialValue: to.isEmpty ? null : to,
            decoration: InputDecoration(labelText: _t('To site (every site)', 'कोणत्या site ला (सगळ्या site)'), border: const OutlineInputBorder()),
            items: [for (final s in sites) DropdownMenuItem(value: '${s['code']}', child: m.Text('${s['code']}'))],
            onChanged: (v) => setState(() => to = v ?? ''),
          ),
          const SizedBox(height: 12),
          _tabs(const [('permanent', 'Permanent', 'Permanent'), ('days', 'Some days', 'काही दिवस')], mode, (v) => setState(() => mode = v)),
          if (mode == 'days')
            ListTile(
              key: const Key('trs-today'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_outlined),
              title: const Text('Last day at the new site', mr: 'नवीन site वरचा शेवटचा दिवस'),
              subtitle: m.Text(toDay.isEmpty ? '–' : _dmy(toDay)),
              onTap: () async {
                final now = DateTime.now(), d = await showDatePicker(context: context, initialDate: now.add(const Duration(days: 1)), firstDate: now, lastDate: now.add(const Duration(days: 365)));
                if (d != null && mounted) setState(() => toDay = '${d.year}-${two(d.month)}-${two(d.day)}');
              },
            ),
          const SizedBox(height: 12),
          TextField(key: const Key('trs-why'), controller: why, maxLength: 300, decoration: InputDecoration(labelText: _t('Reason', 'कारण'), border: const OutlineInputBorder())),
        ]),
        const SizedBox(height: 10),
        InfoLine(_t('He leaves now. Until the new site\'s HR accepts, he may punch at a work place of any site – the travel day is not lost.', 'तो आत्ता निघतो. नवीन site चा HR accept करेपर्यंत तो कुठल्याही site च्या work place वर punch करू शकतो – प्रवासाचा दिवस जात नाही.'), help: false),
        if (err.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: InfoLine(err, bad: true, help: false, key: const Key('trs-err'))),
        const SizedBox(height: 14),
        FilledButton(key: const Key('trs-send'), onPressed: busy ? null : _send, style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15)), child: const Text('Send transfer', mr: 'Transfer पाठवा')),
      ]),
    );
  }
}

class TransferOpenScreen extends StatefulWidget {
  const TransferOpenScreen({super.key, required this.ask, required this.id});
  final HrAsk ask;
  final String id;
  @override
  State<TransferOpenScreen> createState() => _TransferOpenScreenState();
}

class _TransferOpenScreenState extends State<TransferOpenScreen> {
  Map j = const {};
  bool loading = true, busy = false, selected = false;
  String err = '', start = '';
  final picked = <String>{};
  final rep = <Map>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await widget.ask({'action': 'transferOpen', 'id': widget.id});
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

  Future<void> _run(Map<String, dynamic> body, String en, String mr) async {
    setState(() {
      busy = true;
      err = '';
    });
    try {
      await widget.ask(body);
      if (!mounted) return;
      toast(context, _t(en, mr));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          err = errText(e);
        });
      }
    }
  }

  Future<void> _go(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final t = (j['transfer'] as Map?) ?? const {}, p = (j['person'] as Map?) ?? const {}, papers = (j['papers'] as List? ?? const []).whereType<Map>().toList(), places = (j['places'] as List? ?? const []).whereType<Map>().toList();
    final accept = j['may_accept'] == true, cancel = j['may_cancel'] == true;
    return Scaffold(
      appBar: hrHead(context, sky: kMeSky, title: 'Transfer', mr: 'Transfer', height: 64),
      body: loading
          ? const SkeletonList(tiles: 0, rows: 4)
          : ListView(key: const Key('tro-page'), padding: const EdgeInsets.fromLTRB(16, 14, 16, 40), children: [
              if (err.isNotEmpty) InfoLine(err, bad: true, help: false, key: const Key('tro-err')),
              hrCard(key: const Key('tro-person'), [
                Row(children: [
                  _face(p, size: 54),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      m.Text('${p['name'] ?? ''}', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: sk.ink)),
                      m.Text(['${p['code'] ?? ''}', '${p['designation'] ?? ''}', _cats['${p['category']}'] ?? ''].where((x) => x.isNotEmpty).join(' · '), style: TextStyle(fontSize: 12.5, color: sk.muted, height: 1.35)),
                      m.Text('${t['from_site']} › ${t['to_site']} · ${t['mode'] == 'days' ? _t('up to ${_dmy(t['to_day'])}', '${_dmy(t['to_day'])} पर्यंत') : 'permanent'}', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: sk.ink, height: 1.35)),
                      m.Text(_t('Left ${_dmy(t['from_day'])} ${_hm(t['leaves_at'])} · sent by ${t['sent_by'] ?? ''}', '${_dmy(t['from_day'])} ${_hm(t['leaves_at'])} ला निघाला · ${t['sent_by'] ?? ''} ने पाठवला'), style: TextStyle(fontSize: 12.5, color: sk.muted, height: 1.35)),
                      if ('${p['mobile'] ?? ''}'.isNotEmpty) m.Text('${p['mobile']}', style: TextStyle(fontSize: 12.5, color: sk.muted, height: 1.35)),
                    ]),
                  ),
                ]),
                const SizedBox(height: 8),
                m.Text('${t['reason'] ?? ''}', style: TextStyle(fontSize: 13.5, color: sk.ink, height: 1.4)),
              ]),
              const SizedBox(height: 10),
              hrCard(key: const Key('tro-papers'), [
                Text('Papers (${papers.length})', mr: 'कागदपत्रं (${papers.length})', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: sk.ink)),
                const SizedBox(height: 6),
                if (papers.isEmpty) Text('No paper is attached.', mr: 'कागद जोडलेला नाही.', style: TextStyle(fontSize: 12.5, color: sk.muted)),
                Wrap(spacing: 6, runSpacing: 6, children: [for (final d in papers) stateChip('${d['name']}', 'w', key: Key('tro-paper-${d['id']}'), onTap: () => _go('${d['url']}'))]),
              ]),
              if (accept) ...[
                const SizedBox(height: 10),
                _tapCard(key: const Key('tro-accept'), [
                  ListTile(
                    key: const Key('tro-start'),
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_outlined),
                    title: Text('At ${t['to_site']} from', mr: '${t['to_site']} वर कधीपासून'),
                    subtitle: m.Text(start.isEmpty ? _t('Today', 'आज') : _dmy(start)),
                    onTap: () async {
                      final now = DateTime.now(), d = await showDatePicker(context: context, initialDate: now, firstDate: now.subtract(const Duration(days: 3)), lastDate: now.add(const Duration(days: 30)));
                      if (d != null && mounted) setState(() => start = '${d.year}-${two(d.month)}-${two(d.day)}');
                    },
                  ),
                  Text('Where may he punch?', mr: 'तो कुठे punch करू शकतो?', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: sk.muted)),
                  const SizedBox(height: 6),
                  _tabs([('all', 'All places of ${t['to_site']}', '${t['to_site']} ची सगळी ठिकाणं'), ('sel', 'Selected', 'निवडलेली')], selected ? 'sel' : 'all', (v) => setState(() => selected = v == 'sel')),
                  if (selected)
                    for (final x in places)
                      CheckboxListTile(key: Key('tro-place-${x['id']}'), dense: true, contentPadding: EdgeInsets.zero, controlAffinity: ListTileControlAffinity.leading, value: picked.contains('${x['id']}'), title: m.Text('${x['name']}'), onChanged: (v) => setState(() => v == true ? picked.add('${x['id']}') : picked.remove('${x['id']}'))),
                  const SizedBox(height: 8),
                  Text('Reporting persons', mr: 'Reporting persons', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: sk.muted)),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    for (final (i, r) in rep.indexed) stateChip('${i + 1}. ${r['name']}  ×', '', key: Key('tro-rep-$i'), onTap: () => setState(() => rep.removeAt(i))),
                    if (rep.length < 5)
                      stateChip(_t('+ Add', '+ जोडा'), 'w', key: const Key('tro-rep-add'), onTap: () async {
                        final x = await _pickPerson(context, widget.ask);
                        if (x != null && mounted && !rep.any((y) => y['id'] == x['id'])) setState(() => rep.add(x));
                      }),
                  ]),
                ]),
                const SizedBox(height: 10),
                InfoLine(_t('On "Accept" he is ${t['to_site']}\'s employee from that day and the HO HR is told.', '"Accept" केल्यावर तो त्या दिवसापासून ${t['to_site']} चा employee होतो आणि HO HR ला कळवले जाते.'), help: false),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      key: const Key('tro-no'),
                      onPressed: busy
                          ? null
                          : () async {
                              final why = await _askReason(context, 'Why is it rejected?', 'Reject का?', yesEn: 'Reject', yesMr: 'Reject');
                              if (why != null && mounted) await _run({'action': 'transferReject', 'id': widget.id, 'reason': why}, 'Rejected – he stays where he was.', 'Reject झाले – तो होता तिथेच राहतो.');
                            },
                      style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFC22A1B), padding: const EdgeInsets.symmetric(vertical: 14)),
                      child: const Text('Reject', mr: 'Reject'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      key: const Key('tro-yes'),
                      onPressed: busy ? null : () => _run({'action': 'transferAccept', 'id': widget.id, 'start_day': start, 'places_mode': selected ? 'selected' : 'all', 'place_ids': picked.toList(), 'reporting': [for (final r in rep) r['id']]}, 'Accepted – the HO HR is told.', 'Accept झाले – HO HR ला कळवले.'),
                      style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                      child: const Text('Accept', mr: 'Accept'),
                    ),
                  ),
                ]),
              ],
              if (cancel && !accept) ...[
                const SizedBox(height: 12),
                OutlinedButton(
                  key: const Key('tro-cancel'),
                  onPressed: busy
                      ? null
                      : () async {
                          final why = await _askReason(context, 'Why is it taken back?', 'परत का घेताय?', yesEn: 'Take back', yesMr: 'परत घ्या');
                          if (why != null && mounted) await _run({'action': 'transferReject', 'id': widget.id, 'reason': why, 'cancel': 1}, 'Taken back – he stays here.', 'परत घेतले – तो इथेच राहतो.');
                        },
                  style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFC22A1B)),
                  child: const Text('Take back', mr: 'परत घ्या'),
                ),
              ],
            ]),
    );
  }
}
