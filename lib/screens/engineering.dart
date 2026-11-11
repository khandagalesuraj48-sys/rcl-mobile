/* (3.95.0, with rcl-engineering "Engineering 2B") + the MEASUREMENT BOOK (the Admin and the Super Admin): the quantity of a finished layer
 * worked out from the reports → measured → check-measured by another → the abstract for the RA bill.
 * ENGINEERING – the app's own screens (3.93.0, with rcl-engineering "Engineering 2A", asked 09-11-2026: "aple app la banwayla chalu kr …
 * enginnering modual"). Home → Engineering: RFI (the IE's approval of a layer – asked here, the IE's answer recorded by the Engineering
 * Admin / Super Admin), Hindrances (the evidence for an extension of time) and PPC (plan lines done as planned – the Admin and the Super
 * Admin). The same actions, checks and access as the web page (POST <engineering>/api/eng – api.eng, the Portal's ticket for
 * 'engineering'). My work, the dashboard and the strip chart stay on the web, as before. */
import 'package:flutter/material.dart' hide Text;

import '../core/api.dart' show ApiError;
import '../core/format.dart';
import '../ui/ask_bot.dart';
import '../ui/fields.dart';
import '../ui/scope.dart';
import '../ui/t.dart';
import '../ui/design.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import '../ui/motion.dart';

Future<void> openEngineering(BuildContext context) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const EngineeringScreen()));

/// One call to Engineering of the site open now.
Future<Map<String, dynamic>> engCall(BuildContext context, Map<String, dynamic> body) {
  final s = SessionScope.read(context), site = s.site, m = site?.module('engineering');
  if (site == null || m == null) throw StateError('none');
  return s.api.eng(site.code, m.url, body);
}

/// 8020 → "8+020" (the chainage as the web writes it)
String engCh(Object? v) {
  final m = v is num ? v.toDouble() : double.tryParse('${v ?? ''}');
  if (m == null) return '';
  final km = (m / 1000).floor(), r = m - km * 1000, whole = r.floor(), part = ((r - whole) * 1000).round();
  return '$km+${whole.toString().padLeft(3, '0')}${part > 0 ? '.${part.toString().padLeft(3, '0').replaceAll(RegExp(r'0+$'), '')}' : ''}';
}

String _day(Object? d) => showDate('${d ?? ''}');
num _n(Object? v) => v is num ? v : num.tryParse('${v ?? ''}') ?? 0;

/// What Engineering of the site has set up (init): the works of a day, their layers and sides, the people's works, his role.
class EngSetup {
  EngSetup(this.j);
  final Map<String, dynamic> j;
  String get today => '${j['today'] ?? ''}';
  String get role => '${(j['me'] as Map?)?['role'] ?? ''}';
  String get email => '${(j['me'] as Map?)?['email'] ?? ''}';
  bool get canView => role == 'admin' || role == 'super';
  List<Map<String, dynamic>> get _masters => [for (final m in (j['masters'] as List? ?? const []).whereType<Map>()) m.cast<String, dynamic>()];
  List<String> get roadSides => [for (final x in (j['sides'] as List? ?? const [])) '$x'];
  Map<String, dynamic>? get rule => (j['rfiRule'] as Map?)?.cast<String, dynamic>();

  /// the version of a work on a day (the newest period that covers it)
  Map<String, dynamic>? workOn(String item, String d) {
    Map<String, dynamic>? best;
    for (final m in _masters) {
      if (m['kind'] != 'work' || m['item'] != item) continue;
      final f = '${m['valid_from']}', t = '${m['valid_to'] ?? ''}';
      if (f.compareTo(d) <= 0 && (t.isEmpty || t.compareTo(d) >= 0) && (best == null || f.compareTo('${best['valid_from']}') > 0)) best = m;
    }
    return best;
  }

  Map<String, dynamic> data(Map<String, dynamic>? w) => ((w?['data'] as Map?) ?? const {}).cast<String, dynamic>();
  String workName(String item, String d) => '${data(workOn(item, d) ?? workOn(item, today))['name'] ?? item}';
  String layerName(String item, String key, String d) {
    for (final l in (data(workOn(item, d) ?? workOn(item, today))['layers'] as List? ?? const []).whereType<Map>()) {
      if (l['key'] == key) return '${l['name']}';
    }
    return '';
  }

  /// the active works of a day – his own (the Admin and the Super Admin: every work)
  List<Map<String, dynamic>> works(String d, {bool all = false}) {
    final mine = {for (final a in (j['assign'] as List? ?? const []).whereType<Map>()) if (a['email'] == email && a['active'] == true) '${a['work']}'};
    final items = {for (final m in _masters) if (m['kind'] == 'work') '${m['item']}'};
    final out = [for (final i in items) if (workOn(i, d) != null && workOn(i, d)!['active'] == true && (all || canView || mine.contains(i))) workOn(i, d)!];
    out.sort((a, b) => _n(data(a)['sort']).compareTo(_n(data(b)['sort'])) != 0 ? _n(data(a)['sort']).compareTo(_n(data(b)['sort'])) : '${data(a)['name']}'.compareTo('${data(b)['name']}'));
    return out;
  }

  /// the sides a work is done on (its own, else the road's); "Both" when LHS and RHS are among them
  List<String> sidesFor(Map<String, dynamic> w) {
    final own = [for (final x in (data(w)['sides'] as List? ?? const [])) '$x'];
    final l = (own.isNotEmpty ? own : roadSides).where((x) => x != 'Both').toList();
    return l.contains('LHS') && l.contains('RHS') ? [...l, 'Both'] : l;
  }
}

/// Engineering's first screen: RFI, Hindrances and (the Admin) PPC
class EngineeringScreen extends StatefulWidget {
  const EngineeringScreen({super.key});
  @override
  State<EngineeringScreen> createState() => _EngineeringScreenState();
}

class _EngineeringScreenState extends State<EngineeringScreen> {
  EngSetup? setup;
  int waiting = 0, open = 0;
  String err = '', missing = '';
  bool loading = true, started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (started) return;
    started = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      err = '';
    });
    try {
      final j = EngSetup(await engCall(context, {'action': 'init'}));
      if (!mounted) return;
      final t = j.today, from = dateKey(parseKey(t).subtract(const Duration(days: 89)));
      final r = await engCall(context, {'action': 'rfiList', 'from': from, 'to': t, 'status': 'Pending'});
      if (!mounted) return;
      final h = await engCall(context, {'action': 'hindList', 'from': from, 'to': t});
      if (!mounted) return;
      setState(() {
        setup = j;
        missing = '${r['missing'] ?? ''}';
        waiting = (r['rows'] as List? ?? const []).length;
        open = _n(h['open']).toInt();
        loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          err = e is StateError ? 'You have no Engineering on this site – the Super Admin gives it in the Portal.' : errText(e);
        });
      }
    }
  }

  Widget _card(String key, String en, String mr, String sub, IconData ic, Color c, Color soft, Widget Function() page) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Press(
          key: Key(key),
          onTap: () async {
            await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page()));
            if (mounted) _load();
          },
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Container(width: 52, height: 52, decoration: BoxDecoration(color: soft, borderRadius: BorderRadius.circular(16)), child: Icon(ic, color: c, size: 28)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [TwoLang(en, mr, size: 17, weight: FontWeight.w700), const SizedBox(height: 4), Text(sub, style: const TextStyle(fontSize: 13, color: C.muted))])),
            const Icon(Icons.chevron_right_rounded, color: C.faint),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final j = setup, rule = j?.rule;
    return Scaffold(
      backgroundColor: C.bg,
      // (3.97.0, his designs 1 and 2) the Engineering band (teal) with its picture and the site
      appBar: moduleBar(context, Tone.engineering, en: 'Engineering', mr: 'अभियांत्रिकी', pic: 'building_construction', line: SessionScope.of(context).siteName, actions: withAsk([IconButton(tooltip: tr('Refresh'), onPressed: _load, icon: const Icon(Icons.refresh_rounded))])),
      body: loading
          ? const SkeletonList(rows: 4)
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(key: const Key('eng-home'), padding: const EdgeInsets.fromLTRB(Sp.edge, 10, Sp.edge, 40), children: [
                if (err.isNotEmpty) InfoLine(err, bad: true),
                if (missing.isNotEmpty) InfoLine(missing, bad: true),
                if (j != null) ...[
                  if (rule != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: InfoLine(rfiRuleText(rule), icon: Icons.verified_user_outlined, help: false)),
                  _card('eng-rfi', 'RFI – layer approval', 'RFI – layer मंजुरी', waiting > 0 ? tr('{0} waiting for the IE').replaceAll('{0}', '$waiting') : tr('Ask the IE to inspect a layer'), Icons.verified_rounded, C.green, C.greenSoft, () => EngRfiScreen(setup: j)),
                  _card('eng-hind', 'Hindrances', 'अडथळे', open > 0 ? tr('{0} still on').replaceAll('{0}', '$open') : tr('What stopped the work – for EOT'), Icons.block_rounded, C.red, C.redSoft, () => EngHindScreen(setup: j)),
                  if (j.canView) _card('eng-ppc', 'PPC – plan done', 'PPC – नियोजन पूर्ण', tr('Plan lines done as planned, and why not'), Icons.insights_rounded, C.blue, C.blueSoft, () => EngPpcScreen(setup: j)),
                  if (j.canView) _card('eng-mb', 'Measurement Book', 'मोजमाप पुस्तक (MB)', tr('The quantity of a finished layer – measured, check-measured'), Icons.straighten_rounded, C.purple, C.purpleSoft, () => EngMbScreen(setup: j)),
                  const SizedBox(height: 6),
                  const Text('My work, the dashboard and the strip chart are on the web (Engineering).', style: TextStyle(fontSize: 12.5, color: C.muted)),
                ],
              ]),
            ),
    );
  }
}

String rfiRuleText(Map<String, dynamic> r) => r['on'] == true
    ? tr('RFI rule on from {0}: the next layer waits until the layer below is approved.').replaceAll('{0}', _day(r['from']))
    : tr('RFI rule is off.');

/* ---------------- RFI ---------------- */
class EngRfiScreen extends StatefulWidget {
  const EngRfiScreen({super.key, required this.setup});
  final EngSetup setup;
  @override
  State<EngRfiScreen> createState() => _EngRfiScreenState();
}

const _kRfiTabs = [('Pending', 'Waiting'), ('Approved', 'Approved'), ('Rejected', 'Rejected'), ('', 'All')];

class _EngRfiScreenState extends State<EngRfiScreen> {
  String st = 'Pending', err = '', missing = '';
  List<Map<String, dynamic>> rows = [];
  bool loading = true, decide = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      err = '';
    });
    try {
      final t = widget.setup.today, r = await engCall(context, {'action': 'rfiList', 'from': dateKey(parseKey(t).subtract(const Duration(days: 179))), 'to': t, 'status': st});
      if (!mounted) return;
      setState(() {
        rows = [for (final x in (r['rows'] as List? ?? const []).whereType<Map>()) x.cast<String, dynamic>()];
        decide = r['decide'] == true;
        missing = '${r['missing'] ?? ''}';
        loading = false;
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

  Future<void> _form([Map<String, dynamic>? old]) async {
    final done = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => EngRfiForm(setup: widget.setup, old: old)));
    if (done == true && mounted) _load();
  }

  Future<void> _decide(Map<String, dynamic> x) async {
    final done = await popDialog<bool>(context: context, builder: (_) => _RfiDecide(setup: widget.setup, rfi: x));
    if (done == true && mounted) _load();
  }

  Future<void> _cancel(Map<String, dynamic> x) async {
    if (!await ask(context, tr('Cancel {0}?').replaceAll('{0}', '${x['no']}'), tr('It is kept, as Cancelled.'), yes: 'Cancel the RFI', no: 'Keep it', danger: true)) return;
    if (!mounted) return;
    try {
      await engCall(context, {'action': 'rfiCancel', 'no': x['no'], 'ver': x['ver']});
      if (!mounted) return;
      toast(context, tr('{0} cancelled.').replaceAll('{0}', '${x['no']}'));
      _load();
    } catch (e) {
      if (mounted) toast(context, errText(e), bad: true);
    }
  }

  Widget _row(Map<String, dynamic> x) {
    final j = widget.setup, d = '${x['day']}', wait = x['status'] == 'Pending', mine = x['asked_by'] == j.email;
    final where = x['ch_from'] != null ? '${engCh(x['ch_from'])} – ${engCh(x['ch_to'])} · ${(_n(x['ch_to']) - _n(x['ch_from'])).round()} m' : '${x['qty'] ?? ''}';
    final (Color c, Color bg) = switch ('${x['status']}') { 'Approved' => (C.greenDark, C.greenSoft), 'Rejected' => (C.red, C.redSoft), 'Pending' => (C.amber, C.amberSoft), _ => (C.muted, C.line) };
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        key: Key('erf-row-${x['no']}'),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: softShadow()),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text('${x['no']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
            const SizedBox(width: 8),
            Text(_day(d), style: const TextStyle(color: C.muted, fontSize: 13)),
            const Spacer(),
            Pill(tr(wait ? 'Waiting' : '${x['status']}'), color: c, bg: bg),
          ]),
          const SizedBox(height: 6),
          Text('${j.workName('${x['work']}', d)}${'${x['layer'] ?? ''}'.isNotEmpty ? ' · ${j.layerName('${x['work']}', '${x['layer']}', d)}' : ''}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          Text('${'${x['side'] ?? ''}'.isEmpty ? '' : '${x['side']} · '}$where', style: const TextStyle(fontSize: 13.5)),
          if ('${x['note'] ?? ''}'.isNotEmpty) Text('${x['note']}', style: const TextStyle(fontSize: 12.5, color: C.muted)),
          if ('${x['ie_day'] ?? ''}'.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('${tr('IE')}: ${_day(x['ie_day'])}${'${x['ie_name'] ?? ''}'.isNotEmpty ? ' · ${x['ie_name']}' : ''}${'${x['ie_ref'] ?? ''}'.isNotEmpty ? ' · ${x['ie_ref']}' : ''}${'${x['ie_remark'] ?? ''}'.isNotEmpty ? ' – ${x['ie_remark']}' : ''}',
                  style: TextStyle(fontSize: 13, color: c, fontWeight: FontWeight.w600)),
            ),
          Text('${tr('Asked by')} ${x['asked_name'] ?? x['asked_by'] ?? ''}', style: const TextStyle(fontSize: 12, color: C.muted)),
          if (wait && (decide || mine))
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(spacing: 8, runSpacing: 8, children: [
                if (decide) FilledButton.tonal(key: Key('erf-dec-${x['no']}'), style: FilledButton.styleFrom(minimumSize: const Size(0, 40)), onPressed: () => _decide(x), child: const Text("IE's answer")),
                OutlinedButton(key: Key('erf-chg-${x['no']}'), style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)), onPressed: () => _form(x), child: const Text('Change')),
                TextButton(key: Key('erf-can-${x['no']}'), onPressed: () => _cancel(x), child: const Text('Cancel', style: TextStyle(color: C.red))),
              ]),
            ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rule = widget.setup.rule;
    return Scaffold(
      backgroundColor: C.bg,
      appBar: toneBar(Tone.engineering, title: const Text('RFI – layer approval', style: TextStyle(fontWeight: FontWeight.w700)), actions: withAsk()),
      floatingActionButton: missing.isEmpty ? FloatingActionButton.extended(key: const Key('erf-new'), onPressed: () => _form(), icon: const Icon(Icons.add_rounded), label: const Text('Ask RFI')) : null,
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(key: const Key('erf-list'), padding: const EdgeInsets.fromLTRB(Sp.edge, 8, Sp.edge, 100), children: [
          if (rule != null) Text(rfiRuleText(rule), style: const TextStyle(fontSize: 13, color: C.muted)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final t in _kRfiTabs)
              ChoiceChip(key: Key('erf-st-${t.$1}'), label: Text(t.$2), selected: st == t.$1, onSelected: (_) {
                setState(() => st = t.$1);
                _load();
              }),
          ]),
          if (missing.isNotEmpty) InfoLine(missing, bad: true),
          if (err.isNotEmpty) InfoLine(err, bad: true),
          const SizedBox(height: 10),
          if (loading) const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator())),
          if (!loading && rows.isEmpty && missing.isEmpty) const EmptyState('No RFI here', 'Ask the IE to inspect a layer with "Ask RFI".', pic: 'clipboard'),
          if (!loading) for (final x in rows) _row(x),
        ]),
      ),
    );
  }
}

/// Ask an RFI (or change a waiting one): day, work, layer, side, chainage from–to (or a quantity), note
class EngRfiForm extends StatefulWidget {
  const EngRfiForm({super.key, required this.setup, this.old});
  final EngSetup setup;
  final Map<String, dynamic>? old;
  @override
  State<EngRfiForm> createState() => _EngRfiFormState();
}

class _EngRfiFormState extends State<EngRfiForm> {
  final from = TextEditingController(), to = TextEditingController(), qty = TextEditingController(), note = TextEditingController();
  String day = '', work = '', layer = '', side = '', err = '';
  bool busy = false;

  @override
  void initState() {
    super.initState();
    final o = widget.old, j = widget.setup;
    day = o == null ? j.today : '${o['day']}';
    if (o != null) {
      work = '${o['work']}';
      layer = '${o['layer'] ?? ''}';
      side = '${o['side'] ?? ''}';
      if (o['ch_from'] != null) {
        from.text = engCh(o['ch_from']);
        to.text = engCh(o['ch_to']);
      } else {
        qty.text = '${o['qty'] ?? ''}';
      }
      note.text = '${o['note'] ?? ''}';
    }
    _fit();
  }

  // the work, layer and side always one of the day's (the first when none fits)
  void _fit() {
    final j = widget.setup, ws = j.works(day);
    if (ws.isEmpty) return;
    var w = ws.where((x) => x['item'] == work).firstOrNull;
    if (w == null) {
      w = ws.first;
      work = '${w['item']}';
    }
    final ls = [for (final l in (j.data(w)['layers'] as List? ?? const []).whereType<Map>()) '${l['key']}'];
    if (!ls.contains(layer)) layer = ls.isEmpty ? '' : ls.first;
    final ss = j.sidesFor(w), m = '${j.data(w)['unit']}' == 'm';
    if (!ss.contains(side)) side = m && ss.isNotEmpty ? ss.first : '';
  }

  Future<void> _save() async {
    setState(() {
      busy = true;
      err = '';
    });
    final o = widget.old;
    try {
      final r = await engCall(context, {
        'action': 'rfiSave', if (o != null) 'no': o['no'], if (o != null) 'ver': o['ver'],
        'day': day, 'work': work, 'layer': layer, 'side': side, 'from': from.text.trim(), 'to': to.text.trim(), 'qty': qty.text.trim(), 'note': note.text.trim(),
      });
      if (!mounted) return;
      toast(context, tr(o == null ? 'Asked: {0}.' : 'Changed: {0}.').replaceAll('{0}', '${(r['rfi'] as Map?)?['no'] ?? ''}'));
      Navigator.pop(context, true);
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
    final j = widget.setup, ws = j.works(day), w = ws.where((x) => x['item'] == work).firstOrNull, m = w == null || '${j.data(w)['unit']}' == 'm';
    final layers = [for (final l in (j.data(w)['layers'] as List? ?? const []).whereType<Map>()) l];
    return Scaffold(
      backgroundColor: C.bg,
      appBar: toneBar(Tone.engineering, title: Text(widget.old == null ? 'Ask RFI' : '${tr('Change')} ${widget.old!['no']}', style: const TextStyle(fontWeight: FontWeight.w700))),
      body: ListView(key: const Key('erf-form'), padding: const EdgeInsets.fromLTRB(Sp.edge, 10, Sp.edge, 30), children: [
        if (ws.isEmpty) const InfoLine('No work is given to you – the Super Admin gives the works.', bad: true, help: false),
        DateField(key: const Key('erf-day'), label: 'Day the work was finished', value: day, clear: false, last: DateTime.tryParse(j.today), onChanged: (v) => setState(() {
              day = v;
              _fit();
            })),
        const SizedBox(height: 8),
        PickField(key: const Key('erf-work'), label: 'Work', value: work, items: [for (final x in ws) '${x['item']}'], labels: {for (final x in ws) '${x['item']}': '${j.data(x)['name']}'}, onChanged: (v) => setState(() {
              work = v;
              _fit();
            })),
        if (layers.isNotEmpty)
          PickField(key: const Key('erf-layer'), label: 'Layer', value: layer, items: [for (final l in layers) '${l['key']}'], labels: {for (final l in layers) '${l['key']}': '${l['name']}${l['mm'] != null ? ' (${l['mm']} mm)' : ''}'}, onChanged: (v) => setState(() => layer = v)),
        if (w != null)
          PickField(key: const Key('erf-side'), label: 'Side', value: side, items: j.sidesFor(w), blank: m ? null : '–', labels: const {'Both': 'Both (LHS + RHS)'}, onChanged: (v) => setState(() => side = v)),
        if (m) ...[
          TextBox(key: const Key('erf-from'), label: 'Chainage from', hint: '8+000', controller: from),
          TextBox(key: const Key('erf-to'), label: 'To', hint: '8+500', controller: to),
        ] else
          TextBox(key: const Key('erf-qty'), label: 'Quantity', controller: qty, kb: const TextInputType.numberWithOptions(decimal: true)),
        TextBox(key: const Key('erf-note'), label: 'Note', controller: note),
        if (err.isNotEmpty) InfoLine(err, bad: true),
        const SizedBox(height: 14),
        FilledButton(key: const Key('erf-save'), onPressed: busy || ws.isEmpty ? null : _save, child: Text(busy ? 'Saving…' : widget.old == null ? 'Ask RFI' : 'Save')),
      ]),
    );
  }
}

/// The IE's answer, recorded by the Engineering Admin / the Super Admin
class _RfiDecide extends StatefulWidget {
  const _RfiDecide({required this.setup, required this.rfi});
  final EngSetup setup;
  final Map<String, dynamic> rfi;
  @override
  State<_RfiDecide> createState() => _RfiDecideState();
}

class _RfiDecideState extends State<_RfiDecide> {
  final name = TextEditingController(), ref = TextEditingController(), remark = TextEditingController();
  String status = 'Approved', day = '', err = '';
  bool busy = false;

  @override
  void initState() {
    super.initState();
    day = widget.setup.today;
  }

  Future<void> _save() async {
    setState(() {
      busy = true;
      err = '';
    });
    final x = widget.rfi;
    try {
      await engCall(context, {'action': 'rfiDecide', 'no': x['no'], 'ver': x['ver'], 'status': status, 'ie_day': day, 'ie_name': name.text.trim(), 'ie_ref': ref.text.trim(), 'ie_remark': remark.text.trim()});
      if (!mounted) return;
      toast(context, '${x['no']}: ${tr(status)}.');
      Navigator.pop(context, true);
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
    final x = widget.rfi, j = widget.setup, d = '${x['day']}';
    return AlertDialog(
      title: const Text("The IE's answer"),
      scrollable: true,
      content: Column(key: const Key('erf-decide'), mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('${x['no']} · ${j.workName('${x['work']}', d)} ${x['ch_from'] != null ? '${engCh(x['ch_from'])} – ${engCh(x['ch_to'])}' : ''}', style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        PickField(key: const Key('erd-st'), label: 'The IE', value: status, items: const ['Approved', 'Rejected'], onChanged: (v) => setState(() => status = v)),
        const SizedBox(height: 6),
        DateField(key: const Key('erd-day'), label: 'On', value: day, clear: false, first: DateTime.tryParse(d), last: DateTime.tryParse(j.today), onChanged: (v) => setState(() => day = v)),
        TextBox(key: const Key('erd-name'), label: "IE's name", controller: name),
        TextBox(key: const Key('erd-ref'), label: 'RFI / letter no.', controller: ref),
        TextBox(key: const Key('erd-rem'), label: 'Remark (why – when rejected)', controller: remark),
        if (err.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(err, style: const TextStyle(color: C.red))),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(key: const Key('erd-save'), onPressed: busy ? null : _save, child: Text(busy ? 'Saving…' : 'Save')),
      ],
    );
  }
}

/* ---------------- HINDRANCES ---------------- */
class EngHindScreen extends StatefulWidget {
  const EngHindScreen({super.key, required this.setup});
  final EngSetup setup;
  @override
  State<EngHindScreen> createState() => _EngHindScreenState();
}

class _EngHindScreenState extends State<EngHindScreen> {
  Map<String, dynamic>? data;
  String err = '';
  bool loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      err = '';
    });
    try {
      final t = widget.setup.today, r = await engCall(context, {'action': 'hindList', 'from': dateKey(parseKey(t).subtract(const Duration(days: 89))), 'to': t});
      if (!mounted) return;
      setState(() {
        data = r;
        loading = false;
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

  Future<void> _form([Map<String, dynamic>? old]) async {
    final kinds = [for (final k in (data?['kinds'] as List? ?? const [])) '$k'];
    final done = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => EngHindForm(setup: widget.setup, old: old, kinds: kinds)));
    if (done == true && mounted) _load();
  }

  Widget _tile(String label, String v) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: softShadow()),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 12, color: C.muted)), Text(v, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800))]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final j = widget.setup, r = data, rows = [for (final x in (r?['rows'] as List? ?? const []).whereType<Map>()) x.cast<String, dynamic>()];
    final missing = '${r?['missing'] ?? ''}';
    return Scaffold(
      backgroundColor: C.bg,
      appBar: toneBar(Tone.engineering, title: const Text('Hindrances', style: TextStyle(fontWeight: FontWeight.w700)), actions: withAsk()),
      floatingActionButton: r != null && missing.isEmpty ? FloatingActionButton.extended(key: const Key('ehd-new'), onPressed: () => _form(), icon: const Icon(Icons.add_rounded), label: const Text('Add hindrance')) : null,
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(key: const Key('ehd-list'), padding: const EdgeInsets.fromLTRB(Sp.edge, 8, Sp.edge, 100), children: [
          const Text('What stopped the work, where and for how many days – the evidence for an extension of time (EOT). The last 90 days.', style: TextStyle(fontSize: 13, color: C.muted)),
          if (err.isNotEmpty) InfoLine(err, bad: true),
          if (missing.isNotEmpty) InfoLine(missing, bad: true),
          if (loading) const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator())),
          if (!loading && r != null) ...[
            const SizedBox(height: 10),
            Row(children: [_tile(tr('Hindrances'), '${rows.length}'), const SizedBox(width: 8), _tile(tr('Still on'), '${r['open'] ?? 0}'), const SizedBox(width: 8), _tile(tr('Days'), '${rows.fold<num>(0, (a, h) => a + _n(h['days']))}')]),
            const SizedBox(height: 12),
            if (rows.isEmpty && missing.isEmpty) const EmptyState('No hindrance', 'Nothing stopped the work in the last 90 days.', pic: 'construction'),
            for (final h in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Press(
                  key: Key('ehd-row-${h['no']}'),
                  onTap: h['created_by'] == j.email || j.canView ? () => _form(h) : null,
                  padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Text('${h['no']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(width: 8),
                      Expanded(child: Text('${_day(h['from_day'])} – ${'${h['to_day'] ?? ''}'.isEmpty ? tr('still on') : _day(h['to_day'])}', style: const TextStyle(fontSize: 13, color: C.muted))),
                      Pill(tr('{0} days').replaceAll('{0}', '${h['days'] ?? 0}'), color: '${h['to_day'] ?? ''}'.isEmpty ? C.red : C.muted, bg: '${h['to_day'] ?? ''}'.isEmpty ? C.redSoft : C.line),
                    ]),
                    const SizedBox(height: 6),
                    Text('${h['kind']}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    Text([
                      h['ch_from'] != null ? '${engCh(h['ch_from'])} – ${engCh(h['ch_to'])}' : tr('whole road'),
                      '${h['side'] ?? ''}'.isEmpty ? tr('every side') : '${h['side']}',
                      (h['works'] as List? ?? const []).isEmpty ? tr('every work') : [for (final w in (h['works'] as List)) j.workName('$w', '${h['from_day']}')].join(', '),
                    ].join(' · '), style: const TextStyle(fontSize: 13)),
                    if ('${h['detail'] ?? ''}'.isNotEmpty) Text('${h['detail']}', style: const TextStyle(fontSize: 12.5, color: C.muted)),
                    if ('${h['letter'] ?? ''}'.isNotEmpty) Text('${tr('Letter')}: ${h['letter']}', style: const TextStyle(fontSize: 12.5, color: C.muted)),
                  ]),
                ),
              ),
            if ((r['works'] as List? ?? const []).isNotEmpty) ...[
              const SizedBox(height: 6),
              const SectionTitle('Days of hindrance by work', mr: 'कामनिहाय अडथळ्याचे दिवस'),
              for (final w in (r['works'] as List).whereType<Map>())
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(children: [
                    Expanded(child: Text(w['work'] == '*' ? tr('Every work') : '${w['name']}', style: const TextStyle(fontWeight: FontWeight.w600))),
                    Text(tr('{0} days').replaceAll('{0}', '${w['days']}'), style: const TextStyle(fontWeight: FontWeight.w800)),
                  ]),
                ),
            ],
          ],
        ]),
      ),
    );
  }
}

/// Add a hindrance (or change / end one): from, to (empty = still on), the stretch, side, the works it stops, what it is, letter
class EngHindForm extends StatefulWidget {
  const EngHindForm({super.key, required this.setup, this.old, this.kinds = const []});
  final EngSetup setup;
  final Map<String, dynamic>? old;
  final List<String> kinds;
  @override
  State<EngHindForm> createState() => _EngHindFormState();
}

class _EngHindFormState extends State<EngHindForm> {
  final cf = TextEditingController(), ct = TextEditingController(), kind = TextEditingController(), detail = TextEditingController(), letter = TextEditingController();
  String from = '', to = '', side = '', err = '';
  final works = <String>{};
  bool busy = false;

  @override
  void initState() {
    super.initState();
    final o = widget.old;
    from = o == null ? widget.setup.today : '${o['from_day']}';
    if (o != null) {
      to = '${o['to_day'] ?? ''}';
      side = '${o['side'] ?? ''}';
      if (o['ch_from'] != null) {
        cf.text = engCh(o['ch_from']);
        ct.text = engCh(o['ch_to']);
      }
      kind.text = '${o['kind'] ?? ''}';
      detail.text = '${o['detail'] ?? ''}';
      letter.text = '${o['letter'] ?? ''}';
      works.addAll([for (final w in (o['works'] as List? ?? const [])) '$w']);
    }
  }

  Future<void> _save() async {
    setState(() {
      busy = true;
      err = '';
    });
    final o = widget.old;
    try {
      final r = await engCall(context, {
        'action': 'hindSave', if (o != null) 'no': o['no'], if (o != null) 'ver': o['ver'],
        'from_day': from, 'to_day': to, 'ch_from': cf.text.trim(), 'ch_to': ct.text.trim(), 'side': side, 'works': works.toList(), 'kind': kind.text.trim(), 'detail': detail.text.trim(), 'letter': letter.text.trim(),
      });
      if (!mounted) return;
      toast(context, tr(o == null ? 'Added: {0}.' : 'Changed: {0}.').replaceAll('{0}', '${(r['hindrance'] as Map?)?['no'] ?? ''}'));
      Navigator.pop(context, true);
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
    final j = widget.setup, all = j.works(j.today, all: true), sides = [...j.roadSides, 'Both'];
    return Scaffold(
      backgroundColor: C.bg,
      appBar: toneBar(Tone.engineering, title: Text(widget.old == null ? 'Add hindrance' : '${tr('Change')} ${widget.old!['no']}', style: const TextStyle(fontWeight: FontWeight.w700))),
      body: ListView(key: const Key('ehd-form'), padding: const EdgeInsets.fromLTRB(Sp.edge, 10, Sp.edge, 30), children: [
        Row(children: [
          Expanded(child: DateField(key: const Key('ehd-from'), label: 'From', value: from, clear: false, last: DateTime.tryParse(j.today), onChanged: (v) => setState(() => from = v))),
          const SizedBox(width: 8),
          Expanded(child: DateField(key: const Key('ehd-to'), label: 'To (empty = still on)', value: to, last: DateTime.tryParse(j.today), onChanged: (v) => setState(() => to = v))),
        ]),
        const SizedBox(height: 4),
        TextBox(key: const Key('ehd-kind'), label: 'What is it?', hint: 'e.g. land not handed over, utility shifting, rain', controller: kind, options: widget.kinds),
        TextBox(key: const Key('ehd-cf'), label: 'Chainage from (empty = whole road)', hint: '8+000', controller: cf),
        TextBox(key: const Key('ehd-ct'), label: 'To', hint: '9+000', controller: ct),
        PickField(key: const Key('ehd-side'), label: 'Side', value: side, items: sides, blank: tr('Every side'), labels: const {'Both': 'Both (LHS + RHS)'}, onChanged: (v) => setState(() => side = v)),
        const SizedBox(height: 10),
        const Text('Works it stops (none ticked = every work)', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final w in all)
            FilterChip(key: Key('ehd-w-${w['item']}'), label: Text('${j.data(w)['name']}'), selected: works.contains('${w['item']}'), onSelected: (v) => setState(() => v ? works.add('${w['item']}') : works.remove('${w['item']}'))),
        ]),
        TextBox(key: const Key('ehd-det'), label: 'Detail', controller: detail),
        TextBox(key: const Key('ehd-let'), label: 'Letter no.', controller: letter),
        if (err.isNotEmpty) InfoLine(err, bad: true),
        const SizedBox(height: 14),
        FilledButton(key: const Key('ehd-save'), onPressed: busy ? null : _save, child: Text(busy ? 'Saving…' : 'Save')),
      ]),
    );
  }
}

/* ---------------- PPC (the Admin and the Super Admin) ---------------- */
class EngPpcScreen extends StatefulWidget {
  const EngPpcScreen({super.key, required this.setup});
  final EngSetup setup;
  @override
  State<EngPpcScreen> createState() => _EngPpcScreenState();
}

class _EngPpcScreenState extends State<EngPpcScreen> {
  Map<String, dynamic>? data;
  String err = '';
  bool loading = true, last = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      err = '';
    });
    final t = parseKey(widget.setup.today), first = last ? DateTime(t.year, t.month - 1, 1) : DateTime(t.year, t.month, 1), end = last ? DateTime(t.year, t.month, 0) : t;
    try {
      final r = await engCall(context, {'action': 'perf', 'from': dateKey(first), 'to': dateKey(end)});
      if (!mounted) return;
      setState(() {
        data = r;
        loading = false;
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

  Widget _bar(String label, Map ppc) {
    final p = ppc['pct'] is num ? (ppc['pct'] as num).toDouble() : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
          Text(p == null ? '–' : '${p.round()}%', style: const TextStyle(fontWeight: FontWeight.w800)),
          Text(p == null ? '' : '  ${ppc['done']} / ${ppc['lines']}', style: const TextStyle(fontSize: 12, color: C.muted)),
        ]),
        const SizedBox(height: 4),
        ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: (p ?? 0) / 100, minHeight: 9, backgroundColor: C.line, color: C.blue)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = data, ppc = (r?['ppc'] as Map?) ?? const {}, pct = ppc['pct'];
    return Scaffold(
      backgroundColor: C.bg,
      appBar: toneBar(Tone.engineering, title: const Text('PPC – plan done', style: TextStyle(fontWeight: FontWeight.w700)), actions: withAsk()),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(key: const Key('eppc'), padding: const EdgeInsets.fromLTRB(Sp.edge, 8, Sp.edge, 40), children: [
          Wrap(spacing: 8, children: [
            ChoiceChip(key: const Key('eppc-this'), label: const Text('This month'), selected: !last, onSelected: (_) {
              setState(() => last = false);
              _load();
            }),
            ChoiceChip(key: const Key('eppc-last'), label: const Text('Last month'), selected: last, onSelected: (_) {
              setState(() => last = true);
              _load();
            }),
          ]),
          if (err.isNotEmpty) InfoLine(err, bad: true),
          if (loading) const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator())),
          if (!loading && r != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: softShadow()),
              child: Row(children: [
                Text(pct is num ? '$pct%' : '–', key: const Key('eppc-pct'), style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800, color: C.blue)),
                const SizedBox(width: 14),
                Expanded(child: Text(pct is num ? tr('{0} of {1} plan lines done as planned').replaceAll('{0}', '${ppc['done']}').replaceAll('{1}', '${ppc['lines']}') : tr('No plan lines reported yet.'), style: const TextStyle(fontSize: 14))),
              ]),
            ),
            const SizedBox(height: 16),
            const SectionTitle('Week by week', mr: 'आठवडानिहाय'),
            for (final w in (r['weeks'] as List? ?? const []).whereType<Map>()) _bar('${_day(w['from'])} – ${_day(w['to'])}', w),
            const SizedBox(height: 8),
            const SectionTitle('Person by person', mr: 'व्यक्तीनिहाय'),
            for (final p in (r['people'] as List? ?? const []).whereType<Map>()) if (p['ppc'] is Map && _n((p['ppc'] as Map)['lines']) > 0) _bar('${p['name']}', p['ppc'] as Map),
            const SizedBox(height: 8),
            const SectionTitle('Reasons for the work left', mr: 'काम राहण्याची कारणे'),
            if ((r['reasons'] as List? ?? const []).isEmpty) const Text('No reasons – nothing was left.', style: TextStyle(color: C.muted)),
            for (final x in (r['reasons'] as List? ?? const []).whereType<Map>())
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Pill('×${x['times']}', color: C.amber, bg: C.amberSoft),
                  const SizedBox(width: 10),
                  Expanded(child: Text('${x['text']}${(x['people'] as List? ?? const []).isEmpty ? '' : ' · ${(x['people'] as List).join(', ')}'}', style: const TextStyle(fontSize: 14))),
                ]),
              ),
          ],
        ]),
      ),
    );
  }
}

/* ---------------- MEASUREMENT BOOK (3.95.0) ---------------- */
const _kMbSt = [('', 'All'), ('Measured', 'Measured – to check'), ('Sent back', 'Sent back'), ('Check-measured', 'Check-measured')];
String _f3(Object? v) => fmtNum(_n(v), maxDecimals: 3);
String _mbQtyOf(Object? t) => [for (final x in (t as List? ?? const []).whereType<Map>()) '${_f3(x['qty'])} ${x['unit']}'].join(' + ').ifEmpty('–');
(Color, Color) _mbTag(String st) => switch (st) { 'Check-measured' => (C.greenDark, C.greenSoft), 'Sent back' => (C.red, C.redSoft), _ => (C.amber, C.amberSoft) };

/// the server's rule (rcl-engineering lib/rules.js mbQty) – here only to show the figure while it is typed; the server works it out again
({num qty, String unit, String how}) engMbQty(String unit, Object? len, num? w, num? mm, Object? rep) {
  num r3(num v) => (v * 1000).round() / 1000;
  if (unit != 'm' || len == null) return (qty: r3(_n(rep)), unit: unit, how: 'reported');
  final l = _n(len);
  if ((w ?? 0) > 0 && (mm ?? 0) > 0) return (qty: r3(l * w! * mm! / 1000), unit: 'cum', how: 'LxWxT');
  if ((w ?? 0) > 0) return (qty: r3(l * w!), unit: 'sq m', how: 'LxW');
  return (qty: r3(l), unit: 'm', how: 'L');
}

/// how a line's quantity was worked out – every figure shown (the web's mbHow)
String engMbHow(String how, Object? len, Object? w, Object? mm) => switch (how) {
      'reported' => tr('the reported quantity'),
      'LxWxT' => '${_f3(len)} m × ${_f3(w)} m × ${_f3(_n(mm) / 1000)} m (${fmtNum(_n(mm), maxDecimals: 1)} mm)',
      'LxW' => '${_f3(len)} m × ${_f3(w)} m (${tr('the layer has no thickness')})',
      _ => '${_f3(len)} m (${tr('no width set')})',
    };

extension on String {
  String ifEmpty(String v) => isEmpty ? v : this;
}

class EngMbScreen extends StatefulWidget {
  const EngMbScreen({super.key, required this.setup});
  final EngSetup setup;
  @override
  State<EngMbScreen> createState() => _EngMbScreenState();
}

class _EngMbScreenState extends State<EngMbScreen> {
  String tab = 'list', st = '', err = '', missing = '', aFrom = '', aTo = '';
  Map<String, dynamic>? list, abs;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    aTo = widget.setup.today;
    aFrom = aTo.length >= 8 ? '${aTo.substring(0, 8)}01' : aTo;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      err = '';
    });
    try {
      final r = tab == 'abs'
          ? await engCall(context, {'action': 'mbAbstract', 'from': aFrom, 'to': aTo})
          : await engCall(context, {'action': 'mbList', if (st.isNotEmpty) 'status': st});
      if (!mounted) return;
      setState(() {
        if (tab == 'abs') {
          abs = r;
        } else {
          list = r;
        }
        missing = '${r['missing'] ?? ''}';
        loading = false;
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

  Future<void> _open(Object? no) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => EngMbView(setup: widget.setup, no: '$no')));
    if (mounted) _load();
  }

  Future<void> _new() async {
    final no = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => EngMbForm(setup: widget.setup)));
    if (no != null && mounted) await _open(no);
  }

  Widget _row(Map<String, dynamic> x) {
    final (c, bg) = _mbTag('${x['status']}');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Press(
        key: Key('emb-row-${x['no']}'),
        onTap: () => _open(x['no']),
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('${x['no']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5))),
            Pill(x['status'] == 'Measured' ? tr('Measured – to check') : tr('${x['status']}'), color: c, bg: bg),
          ]),
          Text('${tr('Measured on')} ${_day(x['mb_day'])}', style: const TextStyle(color: C.muted, fontSize: 13)),
          const SizedBox(height: 4),
          Text('${x['name'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          Text(_mbQtyOf(x['totals']), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
          Text('${tr('Reports of')} ${_day(x['from_day'])} – ${_day(x['to_day'])} · ${x['lines'] ?? 0} ${tr('lines')}', style: const TextStyle(fontSize: 12.5, color: C.muted)),
          Text('${tr('Measured by')} ${x['measured_name'] ?? ''}${'${x['checked_name'] ?? ''}'.isNotEmpty ? ' · ${tr('check-measured by')} ${x['checked_name']} ${_day(x['chk_day'])}' : ''}', style: const TextStyle(fontSize: 12.5, color: C.muted)),
          if (x['status'] == 'Sent back' && '${x['back_why'] ?? ''}'.isNotEmpty) Text('${tr('Sent back by')} ${x['back_name'] ?? ''}: ${x['back_why']}', style: const TextStyle(fontSize: 12.5, color: C.red)),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = [for (final x in (list?['rows'] as List? ?? const []).whereType<Map>()) x.cast<String, dynamic>()];
    final ab = [for (final x in (abs?['rows'] as List? ?? const []).whereType<Map>()) x.cast<String, dynamic>()];
    final waiting = [for (final x in (abs?['waiting'] as List? ?? const []).whereType<Map>()) x];
    return Scaffold(
      backgroundColor: C.bg,
      appBar: toneBar(Tone.engineering, title: const TwoLang('Measurement Book', 'मोजमाप पुस्तक (MB)', size: 18, weight: FontWeight.w700, color: Colors.white), actions: withAsk()),
      floatingActionButton: tab == 'list' && missing.isEmpty ? FloatingActionButton.extended(key: const Key('emb-new'), onPressed: _new, icon: const Icon(Icons.add_rounded), label: const Text('New MB page')) : null,
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(key: const Key('emb-list'), padding: const EdgeInsets.fromLTRB(Sp.edge, 8, Sp.edge, 100), children: [
          const Text('The quantity of a finished layer, worked out from the reports (chainage × width × thickness): measured, check-measured by another, then the abstract for the RA bill.', style: TextStyle(fontSize: 13, color: C.muted)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            ChoiceChip(key: const Key('emb-t-list'), label: const Text('MB pages'), selected: tab == 'list', onSelected: (_) {
              setState(() => tab = 'list');
              _load();
            }),
            ChoiceChip(key: const Key('emb-t-abs'), label: const Text('Abstract for the RA bill'), selected: tab == 'abs', onSelected: (_) {
              setState(() => tab = 'abs');
              _load();
            }),
          ]),
          const SizedBox(height: 8),
          if (tab == 'list')
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final t in _kMbSt)
                ChoiceChip(key: Key('emb-st-${t.$1}'), label: Text(t.$2), selected: st == t.$1, onSelected: (_) {
                  setState(() => st = t.$1);
                  _load();
                }),
            ]),
          if (tab == 'abs') ...[
            Row(children: [
              Expanded(child: DateField(key: const Key('emb-a-from'), label: 'This period – from', value: aFrom, clear: false, onChanged: (v) => setState(() => aFrom = v))),
              const SizedBox(width: 8),
              Expanded(child: DateField(key: const Key('emb-a-to'), label: 'To', value: aTo, clear: false, onChanged: (v) => setState(() => aTo = v))),
            ]),
            const SizedBox(height: 8),
            FilledButton.tonal(key: const Key('emb-a-show'), onPressed: _load, child: const Text('Show')),
          ],
          const SizedBox(height: 10),
          if (missing.isNotEmpty) InfoLine(missing, bad: true),
          if (err.isNotEmpty) InfoLine(err, bad: true),
          if (loading) const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator())),
          if (!loading && tab == 'list') ...[
            if (list != null && rows.isEmpty && missing.isEmpty) const EmptyState('No MB page here', 'Make one with "New MB page".', pic: 'clipboard'),
            for (final x in rows) _row(x),
          ],
          if (!loading && tab == 'abs' && abs != null) ...[
            Text(tr('Check-measured quantities – by the date of the MB page; only check-measured pages count.'), style: const TextStyle(fontSize: 12.5, color: C.muted)),
            const SizedBox(height: 8),
            if (ab.isEmpty && missing.isEmpty) const EmptyState('Nothing check-measured', 'A check-measured MB page shows here.', pic: 'clipboard'),
            for (final x in ab)
              Container(
                key: Key('emb-ab-${x['work']}-${x['layer']}'),
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: softShadow()),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${x['name'] ?? x['work']}${'${x['layerName'] ?? ''}'.isNotEmpty ? ' · ${x['layerName']}' : ''}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  const SizedBox(height: 6),
                  Row(children: [
                    for (final (k, v) in [(tr('Up to the previous period'), x['prev']), (tr('This period'), x['now']), (tr('Cumulative'), x['cum'])])
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(k, style: const TextStyle(fontSize: 11.5, color: C.muted)),
                          Text('${_f3(v)} ${x['unit'] ?? ''}', style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
                        ]),
                      ),
                  ]),
                  if ((x['pages'] as List? ?? const []).isNotEmpty) Text('${tr('MB pages of this period')}: ${(x['pages'] as List).join(', ')}', style: const TextStyle(fontSize: 12.5, color: C.muted)),
                ]),
              ),
            if (waiting.isNotEmpty)
              Text('${tr('Not check-measured yet – not counted')}: ${waiting.map((w) => '${w['no']} (${w['status']})').join(', ')}', style: const TextStyle(fontSize: 12.5, color: C.amber)),
          ],
        ]),
      ),
    );
  }
}

/// One MB page: its lines (each quantity and how it was worked out), measured by / check-measured by, every change; Change,
/// Check-measured (another Admin / the Super Admin – never one's own), Send back (why)
class EngMbView extends StatefulWidget {
  const EngMbView({super.key, required this.setup, required this.no});
  final EngSetup setup;
  final String no;
  @override
  State<EngMbView> createState() => _EngMbViewState();
}

class _EngMbViewState extends State<EngMbView> {
  Map<String, dynamic>? data;
  String err = '';
  bool loading = true, busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      err = '';
    });
    try {
      final r = await engCall(context, {'action': 'mbGet', 'no': widget.no});
      if (!mounted) return;
      setState(() {
        data = r;
        loading = false;
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

  Future<void> _do(Map<String, dynamic> body, String done) async {
    setState(() => busy = true);
    try {
      await engCall(context, body);
      if (!mounted) return;
      toast(context, done);
      setState(() => busy = false);
      _load();
    } catch (e) {
      if (mounted) {
        setState(() => busy = false);
        toast(context, errText(e), bad: true);
        if (e is ApiError && e.code == 'changed') _load();
      }
    }
  }

  Future<void> _check(Map<String, dynamic> p) async {
    final j = widget.setup, rem = TextEditingController();
    var day = j.today;
    final ok = await popDialog<bool>(
      context: context,
      builder: (dc) => StatefulBuilder(
        builder: (dc, set) => AlertDialog(
          title: Text('${tr('Check-measured')} – ${p['no']}'),
          scrollable: true,
          content: Column(key: const Key('emb-check'), mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(tr('Once check-measured the page is locked – its quantity goes into the abstract for the RA bill.'), style: const TextStyle(fontSize: 13.5, color: C.muted)),
            const SizedBox(height: 10),
            DateField(key: const Key('emb-chk-day'), label: 'Check-measured on', value: day, clear: false, first: DateTime.tryParse('${p['mb_day']}'), last: DateTime.tryParse(j.today), onChanged: (v) => set(() => day = v)),
            TextBox(key: const Key('emb-chk-rem'), label: 'Remark', controller: rem),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dc, false), child: const Text('Cancel')),
            FilledButton(key: const Key('emb-chk-ok'), style: FilledButton.styleFrom(minimumSize: const Size(110, 46)), onPressed: () => Navigator.pop(dc, true), child: const Text('Check-measured')),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    await _do({'action': 'mbCheck', 'no': p['no'], 'ver': p['ver'], 'chk_day': day, 'remark': rem.text.trim()}, '${p['no']}: ${tr('check-measured – locked.')}');
  }

  Future<void> _back(Map<String, dynamic> p) async {
    final why = await askNote(context, '${tr('Send back')} – ${p['no']}', label: 'Why is it sent back?', ok: 'Send back', danger: true, neededMsg: 'Write the reason (a few words).');
    if (why == null || !mounted) return;
    await _do({'action': 'mbBack', 'no': p['no'], 'ver': p['ver'], 'why': why}, '${p['no']}: ${tr('sent back.')}');
  }

  Future<void> _change(Map<String, dynamic> p) async {
    final no = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => EngMbForm(setup: widget.setup, no: '${p['no']}')));
    if (no != null && mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final j = widget.setup, r = data, p = ((r?['mb'] as Map?) ?? const {}).cast<String, dynamic>();
    final locked = p['status'] == 'Check-measured', mine = p['measured_by'] == j.email;
    final mayChange = !locked && (mine || j.role == 'super'), mayCheck = p['status'] == 'Measured' && !mine;
    final lines = [for (final l in (p['lines'] as List? ?? const []).whereType<Map>()) l.cast<String, dynamic>()];
    final (c, bg) = _mbTag('${p['status']}');
    return Scaffold(
      backgroundColor: C.bg,
      appBar: toneBar(Tone.engineering, title: Text(widget.no, style: const TextStyle(fontWeight: FontWeight.w700)), actions: withAsk([IconButton(tooltip: tr('Refresh'), onPressed: _load, icon: const Icon(Icons.refresh_rounded))])),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(key: const Key('emb-view'), padding: const EdgeInsets.fromLTRB(Sp.edge, 8, Sp.edge, 40), children: [
          if (err.isNotEmpty) InfoLine(err, bad: true),
          if (loading) const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator())),
          if (!loading && r != null) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: softShadow()),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text('${r['name'] ?? ''}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
                  Pill('${p['status'] == 'Measured' ? tr('Measured – to check') : tr('${p['status']}')}${locked ? ' · ${tr('locked')}' : ''}', color: c, bg: bg),
                ]),
                const SizedBox(height: 4),
                Text(_mbQtyOf(r['totals']), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                Text('${tr('Measured on')} ${_day(p['mb_day'])} · ${tr('from the reports of')} ${_day(p['from_day'])} – ${_day(p['to_day'])}', style: const TextStyle(fontSize: 12.5, color: C.muted)),
                Text('${tr('Measured by')} ${p['measured_name'] ?? ''}${'${p['chk_day'] ?? ''}'.isNotEmpty ? ' · ${tr('check-measured by')} ${p['checked_name'] ?? ''} ${_day(p['chk_day'])}${'${p['chk_remark'] ?? ''}'.isNotEmpty ? ' – ${p['chk_remark']}' : ''}' : ''}',
                    style: const TextStyle(fontSize: 12.5, color: C.muted)),
                if (p['status'] == 'Sent back') Padding(padding: const EdgeInsets.only(top: 6), child: InfoLine('${tr('Sent back by')} ${p['back_name'] ?? ''}: ${p['back_why'] ?? ''}', bad: true, help: false)),
                if (p['status'] == 'Measured' && mine) Text(tr('You measured it – another Admin or the Super Admin check-measures it (never one\'s own).'), style: const TextStyle(fontSize: 12.5, color: C.muted)),
                if ('${p['note'] ?? ''}'.isNotEmpty) Text('${tr('Note')}: ${p['note']}', style: const TextStyle(fontSize: 13.5)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  if (mayChange)
                    OutlinedButton(key: const Key('emb-chg'), style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)), onPressed: busy ? null : () => _change(p), child: Text(p['status'] == 'Sent back' ? 'Correct and measure again' : 'Change')),
                  if (mayCheck) ...[
                    FilledButton(key: const Key('emb-ok'), style: FilledButton.styleFrom(minimumSize: const Size(0, 44)), onPressed: busy ? null : () => _check(p), child: const Text('Check-measured')),
                    TextButton(key: const Key('emb-back'), onPressed: busy ? null : () => _back(p), child: const Text('Send back', style: TextStyle(color: C.red))),
                  ],
                ]),
              ]),
            ),
            const SizedBox(height: 10),
            for (final l in lines) _MbLineCard(l: l),
            if ((p['history'] as List? ?? const []).isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(tr('Every change (✎)'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              for (final e in (p['history'] as List).whereType<Map>())
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('✎ ${tr('${e['what']}')} · ${e['name'] ?? e['by'] ?? ''} · ${whenText('${e['at'] ?? ''}')}${'${e['why'] ?? ''}'.isNotEmpty ? ' – ${e['why']}' : ''}${'${e['remark'] ?? ''}'.isNotEmpty ? ' – ${e['remark']}' : ''}',
                      style: const TextStyle(fontSize: 12.5, color: C.muted)),
                ),
            ],
            const SizedBox(height: 10),
            Text(tr('The printed MB page: on the web (Engineering → Measurement Book → Print).'), style: const TextStyle(fontSize: 12.5, color: C.muted)),
          ],
        ]),
      ),
    );
  }
}

/// one line of an MB page as kept: the day and the person's report, side, chainage, the quantity and how it was worked out, the IE's RFI
class _MbLineCard extends StatelessWidget {
  const _MbLineCard({required this.l});
  final Map<String, dynamic> l;
  @override
  Widget build(BuildContext context) {
    final no = l['appr'] == 'no', rfi = [for (final x in (l['rfi'] as List? ?? const [])) '$x'];
    return Container(
      key: Key('emb-ln-${l['ln'] ?? l['key']}'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: softShadow()),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('${'${l['side'] ?? ''}'.isEmpty ? '' : '${l['side']} · '}${l['from'] != null ? '${engCh(l['from'])} – ${engCh(l['to'])}' : ''}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5))),
          Text('${_f3(l['qty'])} ${l['unit'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
        ]),
        Text(engMbHow('${l['how']}', l['len'], l['w'] ?? l['w_m'], l['mm'] ?? l['mm_m']), style: const TextStyle(fontSize: 12.5, color: C.muted)),
        Text('${_day(l['day'])} · ${l['name'] ?? ''}${l['outside'] == true ? ' · ${tr('outside the plan')}' : ''}', style: const TextStyle(fontSize: 12.5, color: C.muted)),
        if (rfi.isNotEmpty) Text('RFI: ${rfi.join(', ')}', style: const TextStyle(fontSize: 12.5, color: C.greenDark, fontWeight: FontWeight.w600)),
        if (no && rfi.isEmpty) Text(tr('Not approved by the IE'), style: const TextStyle(fontSize: 12.5, color: C.red, fontWeight: FontWeight.w600)),
        if ('${l['remark'] ?? ''}'.isNotEmpty) Text('${l['remark']}', style: const TextStyle(fontSize: 12.5)),
        if ('${l['skip'] ?? ''}'.isNotEmpty) Text('${tr('Measured without the IE\'s approval (Super Admin)')}: ${l['skip']}', style: const TextStyle(fontSize: 12.5, color: C.amber)),
      ]),
    );
  }
}

/// A new MB page (work, layer, side, the days of the reports → the lines open to measure) or a page changed / corrected: each line's
/// measured width and thickness (a remark when it differs from the masters), the MB date and a note
class EngMbForm extends StatefulWidget {
  const EngMbForm({super.key, required this.setup, this.no});
  final EngSetup setup;
  final String? no;
  @override
  State<EngMbForm> createState() => _EngMbFormState();
}

class _EngMbFormState extends State<EngMbForm> {
  final note = TextEditingController();
  final on = <String, bool>{};
  final w = <String, TextEditingController>{}, mm = <String, TextEditingController>{}, rem = <String, TextEditingController>{}, skip = <String, TextEditingController>{};
  String work = '', layer = '', side = '', from = '', to = '', mbDay = '', err = '';
  Map<String, dynamic>? offer;
  int ver = 0;
  bool busy = false, finding = false;

  @override
  void initState() {
    super.initState();
    final j = widget.setup;
    to = j.today;
    from = dateKey(parseKey(j.today).subtract(const Duration(days: 6)));
    mbDay = j.today;
    final ws = j.works(to, all: true);
    if (ws.isNotEmpty) work = '${ws.first['item']}';
    _fitLayer();
    if (widget.no != null) WidgetsBinding.instance.addPostFrameCallback((_) => _find());
  }

  void _fitLayer() {
    final j = widget.setup, wk = j.workOn(work, to) ?? j.workOn(work, j.today);
    final ls = [for (final l in (j.data(wk)['layers'] as List? ?? const []).whereType<Map>()) '${l['key']}'];
    if (!ls.contains(layer)) layer = ls.isEmpty ? '' : ls.first;
  }

  TextEditingController _c(Map<String, TextEditingController> m, String k, Object? v) => m.putIfAbsent(k, () => TextEditingController(text: v == null ? '' : '$v'));

  Future<void> _find() async {
    if (widget.no == null && from.compareTo(to) > 0) {
      toast(context, tr('Pick the days of the reports – "from" on or before "to".'), bad: true);
      return;
    }
    setState(() {
      finding = true;
      err = '';
    });
    try {
      final r = await engCall(context, widget.no != null ? {'action': 'mbOffer', 'no': widget.no} : {'action': 'mbOffer', 'work': work, 'layer': layer, 'side': side, 'from': from, 'to': to});
      if (!mounted) return;
      final sup = widget.setup.role == 'super';
      setState(() {
        offer = r;
        ver = _n(r['ver']).toInt();
        if (widget.no != null) {
          mbDay = '${r['mb_day'] ?? mbDay}';
          note.text = '${r['note'] ?? ''}';
        }
        on.clear();
        for (final l in (r['lines'] as List? ?? const []).whereType<Map>()) {
          final k = '${l['key']}', no = l['appr'] == 'no';
          on[k] = (!no || sup) && (widget.no != null ? l['inPage'] == true : !no);
          _c(w, k, l['inPage'] == true ? l['w'] : l['w_m']);
          _c(mm, k, l['inPage'] == true ? l['mm'] : l['mm_m']);
          _c(rem, k, l['remark']);
          _c(skip, k, l['skip']);
        }
        finding = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          finding = false;
          err = errText(e);
        });
      }
    }
  }

  Future<void> _save() async {
    final r = offer!;
    final lines = [
      for (final l in (r['lines'] as List? ?? const []).whereType<Map>())
        if (on['${l['key']}'] == true) {'key': l['key'], 'w': w['${l['key']}']?.text.trim() ?? '', 'mm': mm['${l['key']}']?.text.trim() ?? '', 'remark': rem['${l['key']}']?.text.trim() ?? '', 'skip': skip['${l['key']}']?.text.trim() ?? ''},
    ];
    setState(() {
      busy = true;
      err = '';
    });
    try {
      final x = await engCall(context, {
        'action': 'mbSave',
        if (widget.no != null) ...{'no': widget.no, 'ver': ver} else ...{'work': r['work'], 'layer': r['layer'], 'from': r['from'], 'to': r['to']},
        'mb_day': mbDay, 'note': note.text.trim(), 'lines': lines,
      });
      if (!mounted) return;
      final no = '${(x['mb'] as Map?)?['no'] ?? ''}';
      toast(context, '${tr('Measured')}: $no – ${tr('another Admin or the Super Admin check-measures it.')}');
      Navigator.pop(context, no);
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          err = errText(e);
        });
        if (e is ApiError && e.code == 'changed') _find();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final j = widget.setup, sup = j.role == 'super', r = offer, ws = j.works(to, all: true);
    final wk = j.workOn(work, to) ?? j.workOn(work, j.today), layers = [for (final l in (j.data(wk)['layers'] as List? ?? const []).whereType<Map>()) l];
    final lines = [for (final l in (r?['lines'] as List? ?? const []).whereType<Map>()) l.cast<String, dynamic>()];
    final rule = (r?['rule'] as Map?)?.cast<String, dynamic>();
    final tot = <String, num>{};
    var n = 0;
    for (final l in lines) {
      final k = '${l['key']}';
      if (on[k] != true) continue;
      final q = l['how'] == 'reported' ? (qty: _n(l['qty']), unit: '${l['unit']}', how: 'reported') : engMbQty('m', l['len'], asNum(w[k]?.text) ?? _n(l['w_m']), asNum(mm[k]?.text) ?? _n(l['mm_m']), l['qty']);
      tot[q.unit] = (tot[q.unit] ?? 0) + q.qty;
      n++;
    }
    final skipped = [for (final x in (r?['skipped'] as List? ?? const []).whereType<Map>()) x];
    final gone = (r?['gone'] as List? ?? const []);
    return Scaffold(
      backgroundColor: C.bg,
      appBar: toneBar(Tone.engineering, title: Text(widget.no == null ? 'New MB page' : '${tr('Change')} ${widget.no}', style: const TextStyle(fontWeight: FontWeight.w700))),
      body: ListView(key: const Key('emb-form'), padding: const EdgeInsets.fromLTRB(Sp.edge, 10, Sp.edge, 30), children: [
        if (widget.no == null) ...[
          PickField(key: const Key('emb-work'), label: 'Work', value: work, items: [for (final x in ws) '${x['item']}'], labels: {for (final x in ws) '${x['item']}': '${j.data(x)['name']}'}, onChanged: (v) => setState(() {
                work = v;
                _fitLayer();
                offer = null;
              })),
          if (layers.isNotEmpty)
            PickField(key: const Key('emb-layer'), label: 'Layer', value: layer, items: [for (final l in layers) '${l['key']}'], labels: {for (final l in layers) '${l['key']}': '${l['name']}${l['mm'] != null ? ' (${l['mm']} mm)' : ''}'}, onChanged: (v) => setState(() {
                  layer = v;
                  offer = null;
                })),
          PickField(key: const Key('emb-side'), label: 'Side', value: side, items: j.roadSides, blank: 'Every side', onChanged: (v) => setState(() {
                side = v;
                offer = null;
              })),
          Row(children: [
            Expanded(child: DateField(key: const Key('emb-from'), label: 'Reports from', value: from, clear: false, last: DateTime.tryParse(j.today), onChanged: (v) => setState(() {
                  from = v;
                  offer = null;
                }))),
            const SizedBox(width: 8),
            Expanded(child: DateField(key: const Key('emb-to'), label: 'Reports to', value: to, clear: false, last: DateTime.tryParse(j.today), onChanged: (v) => setState(() {
                  to = v;
                  _fitLayer();
                  offer = null;
                }))),
          ]),
          const SizedBox(height: 8),
          FilledButton.tonal(key: const Key('emb-find'), onPressed: finding ? null : _find, child: Text(finding ? 'Finding…' : 'Find the work not measured')),
        ],
        if (err.isNotEmpty) InfoLine(err, bad: true),
        if (finding && widget.no != null) const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator())),
        if (r != null) ...[
          const SizedBox(height: 10),
          Text('${r['name'] ?? ''} · ${tr('reports of')} ${_day(r['from'])} – ${_day(r['to'])} · ${lines.length} ${tr('lines open to measure')}', style: const TextStyle(fontWeight: FontWeight.w700)),
          if (skipped.any((x) => x['why'] == 'in the MB')) Text('${skipped.where((x) => x['why'] == 'in the MB').length} ${tr('already in the MB (never measured twice)')}', style: const TextStyle(fontSize: 12.5, color: C.muted)),
          if (skipped.any((x) => x['why'] == 'reported twice')) Text('${skipped.where((x) => x['why'] == 'reported twice').length} ${tr('reported twice (the earlier report is offered)')}', style: const TextStyle(fontSize: 12.5, color: C.muted)),
          if (rule != null && rule['on'] == true)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: InfoLine(
                  '${tr('RFI rule on from {0}: a stretch not approved by the IE is not finished – it is not measured').replaceAll('{0}', _day(rule['from']))}${sup ? ' (${tr('the Super Admin may, with a reason')})' : ''}.',
                  icon: Icons.verified_user_outlined,
                  help: false),
            ),
          if (gone.isNotEmpty) InfoLine(tr('{0} line(s) of this page are not in the reports any more – they are taken out when it is saved.').replaceAll('{0}', '${gone.length}'), bad: true, help: false),
          if (lines.isEmpty) const EmptyState('Nothing to measure', 'Nothing of this work and layer reported done in these days is left to measure.', pic: 'clipboard'),
          const SizedBox(height: 8),
          for (final l in lines) _line(l, sup),
          const SizedBox(height: 6),
          DateField(key: const Key('emb-day'), label: 'Date of the MB page (measured on)', value: mbDay, clear: false, last: DateTime.tryParse(j.today), onChanged: (v) => setState(() => mbDay = v)),
          TextBox(key: const Key('emb-note'), label: 'Note', controller: note),
          const SizedBox(height: 8),
          Text(n > 0 ? '$n ${tr('lines ticked')} · ${tot.entries.map((e) => '${_f3(e.value)} ${e.key}').join(' + ')}' : tr('Nothing ticked'), key: const Key('emb-tot'), style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          FilledButton(key: const Key('emb-save'), onPressed: busy || n == 0 ? null : _save, child: Text(busy ? 'Saving…' : 'Save as Measured')),
        ],
      ]),
    );
  }

  Widget _line(Map<String, dynamic> l, bool sup) {
    final k = '${l['key']}', no = l['appr'] == 'no', may = !no || sup, calc = l['how'] != 'reported', rfi = [for (final x in (l['rfi'] as List? ?? const [])) '$x'];
    final q = calc ? engMbQty('m', l['len'], asNum(w[k]?.text) ?? _n(l['w_m']), asNum(mm[k]?.text) ?? _n(l['mm_m']), l['qty']) : (qty: _n(l['qty']), unit: '${l['unit']}', how: 'reported');
    return Opacity(
      opacity: on[k] == true ? 1 : .6,
      child: Container(
        key: Key('emb-l-$k'),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: softShadow(), border: on[k] == true ? Border.all(color: C.green, width: 2) : null),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          InkWell(
            onTap: may ? () => setState(() => on[k] = !(on[k] ?? false)) : null,
            child: Row(children: [
              Icon(on[k] == true ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded, color: may ? (on[k] == true ? C.green : C.faint) : C.line),
              const SizedBox(width: 8),
              Expanded(child: Text('${'${l['side'] ?? ''}'.isEmpty ? '' : '${l['side']} · '}${l['from'] != null ? '${engCh(l['from'])} – ${engCh(l['to'])}' : ''}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5))),
              Text('${_f3(q.qty)} ${q.unit}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
            ]),
          ),
          Text(engMbHow(q.how, l['len'], asNum(w[k]?.text) ?? l['w_m'], asNum(mm[k]?.text) ?? l['mm_m']), style: const TextStyle(fontSize: 12.5, color: C.muted)),
          Text('${_day(l['day'])} · ${l['name'] ?? ''}${l['outside'] == true ? ' · ${tr('outside the plan')}' : ''}${l['inPage'] == true ? ' · ${tr('in this page')}' : ''}', style: const TextStyle(fontSize: 12.5, color: C.muted)),
          if (rfi.isNotEmpty) Text('RFI: ${rfi.join(', ')}', style: const TextStyle(fontSize: 12.5, color: C.greenDark, fontWeight: FontWeight.w600)),
          if (no) Text(sup ? tr('Not approved by the IE – the Super Admin may measure it with a reason') : tr('Not approved by the IE – not finished, not measured'), style: const TextStyle(fontSize: 12.5, color: C.red, fontWeight: FontWeight.w600)),
          if (on[k] == true) ...[
            if (calc) ...[
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextBox(key: Key('emb-w-$k'), label: 'Width m', controller: w[k]!, kb: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(() {}))),
                const SizedBox(width: 8),
                Expanded(child: TextBox(key: Key('emb-mm-$k'), label: 'Thickness mm', controller: mm[k]!, kb: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(() {}))),
              ]),
              Text('${tr('masters')}: ${l['w_m'] ?? '–'} m · ${l['mm_m'] ?? '–'} mm', style: const TextStyle(fontSize: 12, color: C.muted)),
            ],
            const SizedBox(height: 8),
            TextBox(key: Key('emb-rem-$k'), label: 'Remark (when it differs from the masters)', controller: rem[k]!),
            if (no && sup) TextBox(key: Key('emb-skip-$k'), label: 'Why measured without the IE\'s approval? *', controller: skip[k]!),
          ],
        ]),
      ),
    );
  }
}

