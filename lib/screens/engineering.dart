/* ENGINEERING – the app's own screens (3.93.0, with rcl-engineering "Engineering 2A", asked 09-11-2026: "aple app la banwayla chalu kr …
 * enginnering modual"). Home → Engineering: RFI (the IE's approval of a layer – asked here, the IE's answer recorded by the Engineering
 * Admin / Super Admin), Hindrances (the evidence for an extension of time) and PPC (plan lines done as planned – the Admin and the Super
 * Admin). The same actions, checks and access as the web page (POST <engineering>/api/eng – api.eng, the Portal's ticket for
 * 'engineering'). My work, the dashboard and the strip chart stay on the web, as before. */
import 'package:flutter/material.dart' hide Text;

import '../ui/ask_bot.dart';
import '../ui/fields.dart';
import '../ui/scope.dart';
import '../ui/t.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

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
      appBar: AppBar(title: const TwoLang('Engineering', 'अभियांत्रिकी', size: 20, weight: FontWeight.w700), actions: withAsk([IconButton(tooltip: tr('Refresh'), onPressed: _load, icon: const Icon(Icons.refresh_rounded))])),
      body: loading
          ? const Center(child: CircularProgressIndicator())
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
    final done = await showDialog<bool>(context: context, builder: (_) => _RfiDecide(setup: widget.setup, rfi: x));
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
      appBar: AppBar(title: const Text('RFI – layer approval', style: TextStyle(fontWeight: FontWeight.w700)), actions: withAsk()),
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
      appBar: AppBar(title: Text(widget.old == null ? 'Ask RFI' : '${tr('Change')} ${widget.old!['no']}', style: const TextStyle(fontWeight: FontWeight.w700))),
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
      appBar: AppBar(title: const Text('Hindrances', style: TextStyle(fontWeight: FontWeight.w700)), actions: withAsk()),
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
      appBar: AppBar(title: Text(widget.old == null ? 'Add hindrance' : '${tr('Change')} ${widget.old!['no']}', style: const TextStyle(fontWeight: FontWeight.w700))),
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
      appBar: AppBar(title: const Text('PPC – plan done', style: TextStyle(fontWeight: FontWeight.w700)), actions: withAsk()),
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
