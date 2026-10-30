/* (SP build – LOCAL TEST RIG until the owner approves it) THE NEW STORE & PURCHASE FORMATS – the app's OWN screens for all 21 formats
 * (S02 – S15, the Central Item Master, P01 – P10), drawn from the module's spec (POST <module>/api/sp spec – the same fields, states,
 * checks and access as the web's; never a web view). One screen for the formats of a module:
 *   • the formats he may open (Edit / View, or decisions only) → a list (search, state, "waiting for me", pages of 50) → a document:
 *     a header card, the items as cards with "+ Item", the route, the files (camera / gallery; their malware-scan state), the history,
 *     and a fixed bottom bar with the actions the server allows him now;
 *   • every typed box gets the 🎙 by itself (ui/voice_box.dart); nothing is worked out here as final – the server answers with it;
 *   • OFFLINE (D-43): a draft stays on the phone; a Save / Submit without network waits "Pending" in the queue (core/sp_queue.dart)
 *     with its save-once key and goes when the network is back; a decision or a stock posting needs the network;
 *   • the Vendor Master is VIEW-ONLY on the phone (D-29). */
import 'dart:convert';

import 'package:flutter/material.dart' hide Text;

import '../core/api.dart';
import '../core/draft.dart';
import '../core/lang.dart';
import '../core/sp_queue.dart';
import '../ui/fields.dart';
import '../ui/scope.dart';
import '../ui/t.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

Future<void> openSpForms(BuildContext context, String mod) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SpHub(mod: mod)));

/// A date as the site reads it: 2026-10-30 → 30-10-2026; a time of the server → 30-10-2026 15:30 (this phone's time).
String spDmy(Object? v) {
  final t = '${v ?? ''}';
  if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(t)) return t.split('-').reversed.join('-');
  final d = DateTime.tryParse(t);
  if (d == null || !t.contains('T')) return t;
  final l = d.toLocal(), two = (int n) => n.toString().padLeft(2, '0');
  return '${two(l.day)}-${two(l.month)}-${l.year} ${two(l.hour)}:${two(l.minute)}';
}

String _rid() {
  final t = DateTime.now().microsecondsSinceEpoch.toRadixString(36), r = (Object().hashCode ^ t.hashCode).toRadixString(36);
  return 'app-$t-$r';
}

String _uuid() {
  final h = DateTime.now().microsecondsSinceEpoch.toRadixString(16).padLeft(16, '0'), r = (identityHashCode(Object()) * 2654435761).toRadixString(16).padLeft(16, '0');
  final x = (h + r + '0123456789abcdef').substring(0, 32);
  return '${x.substring(0, 8)}-${x.substring(8, 12)}-4${x.substring(13, 16)}-8${x.substring(17, 20)}-${x.substring(20, 32)}';
}

/// What a format screen needs: the module, its address, the site, the call.
class SpCtx {
  SpCtx(this.mod, this.site, this.url, this.api, this.email, this.keep);
  final String mod, site, url, email;
  final Api api;
  final Keep keep;
  Future<Map<String, dynamic>> call(String action, Map<String, dynamic> body) => api.sp(mod, site, url, {'action': action, ...body});
  SpQueue get queue => SpQueue(keep, mod, site, email);
}

class SpHub extends StatefulWidget {
  const SpHub({super.key, required this.mod});
  final String mod;
  @override
  State<SpHub> createState() => _SpHubState();
}

class _SpHubState extends State<SpHub> {
  SpCtx? c;
  Map<String, dynamic>? spec;
  List<Map<String, dynamic>> queue = [];
  String err = '';
  bool loading = true, started = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (started) return;
    started = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    final s = SessionScope.read(context), site = s.site, m = site?.module(widget.mod);
    setState(() {
      loading = true;
      err = '';
    });
    try {
      if (site == null || m == null) throw StateError('none');
      c = SpCtx(widget.mod, site.code, m.url, s.api, s.email, s.api.keep);
      final q = c!.queue;
      final f = await q.flush((b) => c!.call(b['action'] as String, b..remove('action')));
      final j = await c!.call('spec', {});
      queue = await q.all();
      if (mounted) {
        setState(() {
          spec = j;
          loading = false;
          if (f.sent + f.failed + f.conflict > 0) err = 'Sent from the queue: ${f.sent}${f.failed > 0 ? ' · failed ${f.failed}' : ''}${f.conflict > 0 ? ' · changed meanwhile ${f.conflict}' : ''}';
        });
      }
    } catch (e) {
      queue = c == null ? [] : await c!.queue.all();
      if (mounted) {
        setState(() {
          loading = false;
          err = e is StateError ? 'This module is not given to you on this site – the Super Admin gives it in the Portal.' : errText(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fs = [for (final f in (spec?['formats'] as List? ?? const []).whereType<Map>()) f.cast<String, dynamic>()].where((f) => f['access'] != 'None' || f['decide'] == true).toList();
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final f in fs) {
      (groups['${f['group'] ?? ''}'] ??= []).add(f);
    }
    return Scaffold(
      appBar: AppBar(title: TwoLang(widget.mod == 'purchase' ? 'Purchase formats' : 'Store formats', widget.mod == 'purchase' ? 'खरेदी फॉर्म' : 'स्टोअर फॉर्म', size: 19, weight: FontWeight.w700),
          actions: [IconButton(tooltip: tr('Refresh'), onPressed: _start, icon: const Icon(Icons.refresh_rounded))]),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _start,
              child: ListView(key: const Key('sp-hub'), padding: const EdgeInsets.fromLTRB(16, 10, 16, 40), children: [
                if (err.isNotEmpty) InfoLine(err, bad: !err.startsWith('Sent')),
                if (spec != null) Text('${spec?['site']} · ${(spec?['me'] as Map?)?['email'] ?? ''}${((spec?['me'] as Map?)?['roles'] as List? ?? const []).isEmpty ? '' : ' · ${((spec?['me'] as Map)['roles'] as List).join(', ')}'}', style: const TextStyle(fontSize: 12.5, color: C.muted)),
                if (queue.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  SectionTitle('Waiting on this phone', mr: 'फोनवर थांबलेले'),
                  for (final x in queue)
                    Card(child: ListTile(key: Key('spq-${x['rid']}'), dense: true, title: Text('${x['kind']} · ${x['action']} ${x['title'] ?? ''}'), subtitle: Text('${x['state']}${x['error'] != null ? ' – ${x['error']}' : ''}'), trailing: x['state'] == 'Pending' ? const Icon(Icons.cloud_upload_outlined, color: C.amber) : null)),
                ],
                if (spec != null && fs.isEmpty) const EmptyState('No format is given to you here', 'The Super Admin gives the formats in the Portal (Users & Access → Pages).'),
                for (final g in groups.keys) ...[
                  const SizedBox(height: 12),
                  SectionTitle(g.isEmpty ? 'Formats' : g),
                  for (final f in groups[g]!)
                    Card(
                      child: ListTile(
                        key: Key('sp-f-${f['kind']}'),
                        title: Text('${f['kind']} · ${f['name']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(f['access'] == 'None' ? 'Decisions only' : f['viewOnlyPhone'] == true ? 'View only on the phone' : '${f['access']}', style: const TextStyle(fontSize: 12, color: C.muted)),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SpList(c: c!, f: f))).then((_) => _start()),
                      ),
                    ),
                ],
              ]),
            ),
    );
  }
}

class SpList extends StatefulWidget {
  const SpList({super.key, required this.c, required this.f});
  final SpCtx c;
  final Map<String, dynamic> f;
  @override
  State<SpList> createState() => _SpListState();
}

class _SpListState extends State<SpList> {
  List<Map<String, dynamic>> rows = [];
  bool more = false, loading = true, waiting = false;
  int page = 0;
  String q = '', status = '', err = '';
  final qc = TextEditingController();
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final r = await widget.c.call('list', {'kind': widget.f['kind'], 'q': q, 'status': status, 'waiting': waiting ? 1 : null, 'page': page});
      rows = [for (final x in (r['rows'] as List? ?? const []).whereType<Map>()) x.cast<String, dynamic>()];
      more = r['more'] == true;
      err = '';
    } catch (e) {
      err = errText(e);
    }
    if (mounted) setState(() => loading = false);
  }

  bool get canNew => widget.f['access'] == 'Edit' && widget.f['viewOnlyPhone'] != true && (widget.f['noCreate'] ?? '') == '';      // (made by the system only: no New)
  @override
  Widget build(BuildContext context) {
    final f = widget.f, states = [for (final s in (f['states'] as List? ?? const [])) '$s'];
    return Scaffold(
      appBar: AppBar(title: Text('${f['short'] ?? f['name']}')),
      floatingActionButton: canNew ? FloatingActionButton.extended(key: const Key('sp-new'), onPressed: () => _open(null), icon: const Icon(Icons.add_rounded), label: const Text('New')) : null,
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(key: Key('sp-list-${f['kind']}'), padding: const EdgeInsets.fromLTRB(16, 10, 16, 90), children: [
          TextBox(label: 'Search number / item / party', controller: qc, onChanged: (v) => q = v),
          Row(children: [
            Expanded(child: PickField(label: 'State', value: status, items: states, blank: 'Every state', onChanged: (v) { status = v; page = 0; _load(); })),
            if (f['decide'] == true) ...[const SizedBox(width: 8), FilterChip(key: const Key('sp-wait'), label: const Text('Waiting for me'), selected: waiting, onSelected: (v) { waiting = v; page = 0; _load(); })],
            IconButton(onPressed: () { page = 0; _load(); }, icon: const Icon(Icons.search_rounded)),
          ]),
          if (err.isNotEmpty) InfoLine(err, bad: true),
          if (loading) const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator())),
          if (!loading && rows.isEmpty && err.isEmpty) EmptyState(waiting ? 'Nothing waits for you' : 'Nothing here yet', canNew ? 'Press "New".' : ''),
          for (final r in rows)
            Card(
              child: ListTile(
                key: Key('sp-row-${r['id']}'),
                title: Text('${r['no']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text([r['name'] ?? r['party'] ?? '', spDmy(r['date']), if (r['waitingFor'] != null) 'waits: ${r['waitingFor']}'].where((x) => '$x'.isNotEmpty).join(' · '), maxLines: 2),
                trailing: Pill('${r['status']}', color: C.blue, bg: C.blueSoft),
                onTap: () => _open('${r['id']}'),
              ),
            ),
          if (page > 0 || more)
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              if (page > 0) TextButton(onPressed: () { page--; _load(); }, child: const Text('‹ Earlier')),
              if (more) TextButton(onPressed: () { page++; _load(); }, child: const Text('Next ›')),
            ]),
        ]),
      ),
    );
  }

  Future<void> _open(String? id) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SpDoc(c: widget.c, f: widget.f, id: id)));
    _load();
  }
}

class SpDoc extends StatefulWidget {
  const SpDoc({super.key, required this.c, required this.f, this.id});
  final SpCtx c;
  final Map<String, dynamic> f;
  final String? id;
  @override
  State<SpDoc> createState() => _SpDocState();
}

class _SpDocState extends State<SpDoc> {
  Map<String, dynamic>? d;
  Map<String, dynamic> data = {};
  List<Map<String, dynamic>> lines = [];
  final ctl = <String, TextEditingController>{};
  String err = '', newId = '';
  bool loading = true, busy = false;
  final pending = <String, String>{};      // (the save-once key of an action, kept until the server answers)
  late final Draft draft = Draft(widget.c.keep, 'sp|${widget.c.mod}|${widget.c.site}|${widget.f['kind']}|${widget.id ?? 'new'}');
  List<Map<String, dynamic>> get head => [for (final x in (widget.f['head'] as List? ?? const []).whereType<Map>()) x.cast<String, dynamic>()];
  List<Map<String, dynamic>> get cols => [for (final x in (((widget.f['lines'] as Map?)?['cols']) as List? ?? const []).whereType<Map>()) x.cast<String, dynamic>()];
  List<String> get can => [for (final x in (d?['can'] as List? ?? (widget.f['access'] == 'Edit' && widget.f['viewOnlyPhone'] != true ? ['save', 'submit'] : const []))) '$x'];
  bool get editable => can.contains('save') && widget.f['viewOnlyPhone'] != true;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    draft.close();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      if (widget.id != null) d = await widget.c.call('get', {'kind': widget.f['kind'], 'id': widget.id});
      data = {...((d?['data'] as Map?) ?? const {}).cast<String, dynamic>()};
      lines = [for (final x in (d?['lines'] as List? ?? const []).whereType<Map>()) x.cast<String, dynamic>()];
      final kept = await draft.read();
      if (kept != null && editable) {
        data = {...data, ...((kept['data'] as Map?) ?? const {}).cast<String, dynamic>()};
        if (kept['lines'] is List) lines = [for (final x in (kept['lines'] as List).whereType<Map>()) x.cast<String, dynamic>()];
        err = 'Half-filled entry brought back (kept on this phone).';
      }
      if (widget.id == null && lines.isEmpty && widget.f['lines'] != null) lines = [{}];
      for (final h in head) {
        if (data[h['key']] == null && h['def'] != null) data['${h['key']}'] = h['def'];
        if (data[h['key']] == null && h['type'] == 'date' && h['key'] == 'date') data['date'] = DateTime.now().toIso8601String().substring(0, 10);
      }
    } catch (e) {
      err = errText(e);
    }
    if (mounted) setState(() => loading = false);
  }

  void _keep() => draft.put(editable ? {'data': data, 'lines': lines} : null);
  bool shown(Map<String, dynamic> fd) {
    final sh = fd['show'] as Map?;
    if (sh == null) return true;
    return [for (final x in (sh['in'] as List? ?? const [])) '$x'].contains('${data[sh['key']] ?? ''}');
  }

  TextEditingController _c(String key, Object? v) => ctl.putIfAbsent(key, () => TextEditingController(text: v == null ? '' : '$v'));
  Widget field(Map<String, dynamic> fd, Map<String, dynamic> target, String at) {
    final k = '${fd['key']}', t = '${fd['type'] ?? 'text'}', v = target[k], ro = fd['ro'] == true || !editable;
    final label = '${fd['label']}${fd['req'] == true || fd['req'] == 'always' ? ' *' : ''}';
    if (t == 'json') return InfoRow(label, _json(k, v));
    if (ro) return InfoRow(label, v == null ? '–' : v is bool ? (v ? 'Yes' : 'No') : v is List ? v.join(', ') : t == 'date' || t == 'time' ? spDmy(v) : '$v');
    if (t == 'select') return PickField(label: label, value: '${v ?? ''}', items: [for (final o in (fd['options'] as List? ?? const [])) '$o'], blank: '', onChanged: (x) => setState(() { target[k] = x; _keep(); }));
    if (t == 'bool') return SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(label), value: v == true || v == 'true', onChanged: (x) => setState(() { target[k] = x; _keep(); }));
    if (t == 'date') return DateField(label: label, value: '${v ?? ''}', onChanged: (x) => setState(() { target[k] = x; _keep(); }));
    final kb = ['qty', 'rate', 'amt', 'pct'].contains(t) ? const TextInputType.numberWithOptions(decimal: true, signed: true) : t == 'int' ? TextInputType.number : t == 'phone' ? TextInputType.phone : t == 'email' ? TextInputType.emailAddress : t == 'textarea' ? TextInputType.multiline : TextInputType.text;
    return TextBox(key: Key('sp-$at-$k'), label: label, controller: _c('$at|$k', v), kb: kb, maxLines: t == 'textarea' ? 3 : 1, upper: ['gstin', 'pan', 'ifsc'].contains(t), onChanged: (x) { target[k] = x; _keep(); });
  }

  String _json(String k, Object? v) {
    if (v == null) return '–';
    if (k == 'reading' && v is Map) {
      if (v['found'] != true) return '${v['warn'] ?? 'No reading'}';
      final parts = [if (v['km'] != null) 'KM ${v['km']}', if (v['hrs'] != null) 'Hrs ${v['hrs']}'];
      return '${parts.isEmpty ? '${v['unit']} – no KM / Hrs' : parts.join(' · ')} – ${spDmy(v['date'])} ${v['shift'] ?? ''} (main Log Book)${v['warn'] != null ? '\n⚠ ${v['warn']}' : ''}';
    }
    return v is Map || v is List ? const JsonEncoder.withIndent(' ').convert(v) : '$v';
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.f, route = d?['route'] as Map?;
    // (D-29) a format that is VIEW-ONLY on the phone (the Vendor Master): no button at all
    final acts = f['viewOnlyPhone'] == true ? <(String, String, bool)>[] : <(String, String, bool)>[
      if (can.contains('save')) ('save', f['master'] == true ? 'Save' : 'Save draft', false),
      if (can.contains('submit') && f['route'] == true) ('submit', 'Submit', true),
      if (can.contains('decide')) ...[('approve', 'Approve', true), ('send_back', 'Send back', false), ('reject', 'Reject', false)],
      for (final a in (f['actions'] as List? ?? const []).whereType<Map>()) if (can.contains(a['key'])) ('x:${a['key']}', '${a['label']}', false),
      if (can.contains('cancel')) ('cancel', 'Cancel', false),
    ];
    return Scaffold(
      appBar: AppBar(title: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(d == null ? 'New ${f['short'] ?? f['name']}' : '${d?['no']}')), /* (the whole number – made smaller, never cut) */ actions: [if (d != null) Padding(padding: const EdgeInsets.only(right: 10), child: Center(child: Pill('${d?['status']}', color: C.blue, bg: C.blueSoft)))]),
      bottomNavigationBar: acts.isEmpty || loading
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
                child: Wrap(spacing: 8, runSpacing: 6, alignment: WrapAlignment.end, children: [
                  for (final a in acts)
                    a.$3
                        ? FilledButton(key: Key('sp-act-${a.$1}'), onPressed: busy ? null : () => _act(a.$1), child: Text(a.$2))
                        : OutlinedButton(key: Key('sp-act-${a.$1}'), onPressed: busy ? null : () => _act(a.$1), child: Text(a.$2)),
                ]),
              ),
            ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(key: const Key('sp-doc'), padding: const EdgeInsets.fromLTRB(16, 10, 16, 40), children: [
              if (err.isNotEmpty) InfoLine(err, bad: !err.startsWith('Half')),
              if (d?['why'] != null && !can.contains('decide')) InfoLine('${d?['why']}', icon: Icons.info_outline_rounded),
              if (route != null)
                Wrap(spacing: 6, runSpacing: 4, children: [
                  for (final (i, st) in (route['steps'] as List? ?? const []).whereType<Map>().indexed) Pill('${st['name']} · ${st['who']}', color: i == route['at'] && '${d?['status']}'.startsWith('Waiting') ? C.blue : C.muted, bg: i < (route['at'] as num? ?? 0) ? C.greenSoft : C.blueSoft),
                  if (route['failClosed'] == true) const InfoLine('No route is set for this format yet – it goes to the highest authority until the Super Admin sets one.', icon: Icons.alt_route_rounded),
                ]),
              Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [for (final fd in head) if (shown(fd)) Padding(padding: const EdgeInsets.only(bottom: 8), child: field(fd, data, 'h'))]))),
              if (f['lines'] != null) ...[
                SectionTitle('${(f['lines'] as Map)['title'] ?? 'Lines'}'),
                for (final (i, l) in lines.indexed)
                  Card(
                    key: Key('sp-line-$i'),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 6, 6, 8),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [Text('Line ${i + 1}${l['item_name'] != null || l['name'] != null ? ' · ${l['item_name'] ?? l['name']}' : ''}', style: const TextStyle(fontWeight: FontWeight.w600)), const Spacer(), if (editable) IconButton(tooltip: tr('Remove'), onPressed: () => setState(() { lines.removeAt(i); _keep(); }), icon: const Icon(Icons.close_rounded, color: C.orange))]),
                        for (final fd in cols) Padding(padding: const EdgeInsets.only(bottom: 6, right: 6), child: field(fd, l, 'l$i')),
                      ]),
                    ),
                  ),
                if (editable) Align(alignment: Alignment.centerLeft, child: TextButton.icon(key: const Key('sp-add-line'), onPressed: () => setState(() { lines.add({}); _keep(); }), icon: const Icon(Icons.add_rounded), label: const Text('Item'))),
              ],
              if (d != null) ...[
                SectionTitle('Attachments', mr: 'फाईल'),
                for (final x in (d?['files'] as List? ?? const []).whereType<Map>()) if (x['removed_at'] == null && x['replaced_by'] == null) ListTile(dense: true, leading: Icon(x['state'] == 'Clean' ? Icons.verified_rounded : Icons.gpp_maybe_rounded, color: x['state'] == 'Clean' ? C.green : C.orange), title: Text('${x['name']}'), subtitle: Text('${x['state']}${x['why'] != null ? ' – ${x['why']}' : ''}')),
                SectionTitle('History', mr: 'इतिहास'),
                for (final a in (d?['acts'] as List? ?? const []).whereType<Map>()) ListTile(dense: true, title: Text('${a['action']}${a['step'] != null ? ' · ${a['step']}' : ''} → ${a['to_status']}'), subtitle: Text('${a['name'] ?? a['by']} · ${spDmy(a['at'])}${a['reason'] != null ? '\n${a['reason']}' : ''}')),
              ],
            ]),
    );
  }

  Future<void> _act(String what) async {
    final f = widget.f, kind = '${f['kind']}';
    var action = what;
    final body = <String, dynamic>{'kind': kind};
    if (d != null) body.addAll({'id': d!['id'], 'version': d!['version']});
    if (what == 'save' || what == 'submit') {
      body['data'] = data;
      body['lines'] = lines.where((l) => l.values.any((v) => v != null && '$v'.isNotEmpty)).toList();
      if (d == null) {
        newId = newId.isEmpty ? _uuid() : newId;
        body.addAll({'new': true, 'id': newId});
      }
    } else if (what == 'approve' || what == 'send_back' || what == 'reject') {
      action = 'decide';
      body['decision'] = what;
      if (what != 'approve') {
        final r = await askNote(context, what == 'reject' ? 'Reject – why?' : 'Send back – why?');
        if (r == null) return;
        body['reason'] = r;
      } else if (!await ask(context, 'Approve ${d?['no'] ?? ''}?', 'You decide on version ${d?['version']} as you see it now.')) {
        return;
      }
    } else if (what == 'cancel') {
      final r = await askNote(context, 'Cancel – why?');
      if (r == null) return;
      body['reason'] = r;
    } else if (what.startsWith('x:')) {
      action = what.substring(2);
      final a = (f['actions'] as List).whereType<Map>().firstWhere((x) => x['key'] == action);
      final input = <String, dynamic>{};
      for (final fd in (a['input'] as List? ?? const []).whereType<Map>()) {
        final v = await askNote(context, '${fd['label']}');
        if (v == null) return;
        input['${fd['key']}'] = v;
      }
      body['input'] = input;
    }
    final key = '$action:${body['id'] ?? 'new'}';
    body['rid'] = pending[key] ??= _rid();
    setState(() => busy = true);
    try {
      final r = await widget.c.call(action, body);
      pending.remove(key);
      await draft.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${r['no'] ?? ''} – ${r['status'] ?? 'done'}${r['repeat'] == true ? ' (it was done already)' : ''}')));
      if (d == null && r['id'] != null) {
        Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => SpDoc(c: widget.c, f: widget.f, id: '${r['id']}')));
        return;
      }
      await _load();
    } on ApiError catch (e) {
      // no network: a Save / Submit waits on the phone (Pending) with its key; a decision or a posting needs the network
      if (e.code == 'net' && SpQueue.queued.contains(action)) {
        await widget.c.queue.add(action, {...body, 'title': d?['no'] ?? 'new'});
        if (mounted) setState(() => err = 'No network – kept on this phone ("Pending"); it is sent when the network is back.');
      } else {
        if (e.status == 409 || e.status == 400 || e.status == 403) pending.remove(key);
        if (mounted) setState(() => err = e.message);
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
}
