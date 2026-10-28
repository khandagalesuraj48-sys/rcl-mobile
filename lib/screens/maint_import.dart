/* (3.53.0, Mechanical update-173) THE OLD MAINTENANCE LOG BOOK, IMPORTED AS IT IS – the app's own screen of the web's "Import the old
 * log book (Excel or PDF)" (the Admin): the file read as the web reads it (core/maint_import.dart) – an Excel, or a PDF / a photo read
 * by the AI page by page (readMaintLog, 2 pages a call – one when its answer was cut or slow); a card a sheet – its name in the file,
 * its machinery (Own, on the site – it can be changed; "– not imported –"), rows, bills, the file's total and the total as it will be
 * kept, the lines to look at; the names written in more than one way (maintImportNames – the Admin ticks; asked 28-10-2026: "यादी दाखव,
 * मी पाहून ✓ करेन"); Check (checkMaintImport – nothing saved), then Import (importMaint, one machinery at a time – a bill already
 * there is left out and listed). The same server actions, checks and access as the web. */
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart' hide Text;

import '../core/api.dart' show ApiError;
import '../core/format.dart';
import '../core/maint_import.dart';
import '../core/session.dart';
import '../ui/fields.dart';
import '../ui/scope.dart';
import '../ui/t.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

const _fieldName = {'party': 'Party Name', 'work': 'Particulars', 'uom': 'Uom'};

class MaintImportScreen extends StatefulWidget {
  const MaintImportScreen({super.key, required this.name, this.sheets = const [], this.file});
  final String name;
  final List<MliSheet> sheets;
  /// (28-10-2026) a PDF / a photo of the old log book – read by the AI here
  final Uint8List? file;
  @override
  State<MaintImportScreen> createState() => _MaintImportScreenState();
}

class _MaintImportScreenState extends State<MaintImportScreen> {
  bool busy = false, any = false, reading = false;
  String say = '', readErr = '';
  late List<MliSheet> sheets = [...widget.sheets];
  // the names (AI): null = not asked yet; 'busy' / 'off' / 'err' / 'done'
  String? fixState;
  String fixErr = '';
  List<MliFix> fixes = [];
  final _ctl = <TextEditingController>[];
  final _open = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    for (final c in _ctl) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _start() async {
    if (!mounted) return;
    if (widget.file != null) {
      setState(() {
        reading = true;
        readErr = '';
      });
      try {
        await _readAi();
      } catch (e) {
        readErr = errText(e);
      }
      if (!mounted) return;
      setState(() => reading = false);
      if (readErr.isNotEmpty) return;
    }
    await _names();
  }

  /// The web's mliReadAi: the pages one after the other, the tables as sheets
  Future<void> _readAi() async {
    final s = SessionScope.read(context), b = widget.file!, n = widget.name;
    final kind = RegExp(r'\.pdf$', caseSensitive: false).hasMatch(n) ? 'application/pdf' : RegExp(r'\.png$', caseSensitive: false).hasMatch(n) ? 'image/png' : 'image/jpeg';
    if (b.length > 3 * 1024 * 1024) throw ApiError('This log book file is too big (more than 3 MB) – give it in parts (a PDF of fewer pages).');
    final data = 'data:$kind;base64,${base64Encode(b)}', pdf = kind == 'application/pdf', tables = <Map>[];
    var from = 1, pages = 0;
    for (var guard = 0; guard < 500; guard++) {
      if (mounted) setState(() => say = pdf ? 'Reading with the AI… page $from${pages > 0 ? ' of $pages' : ''}' : 'Reading with the AI…');
      Map? r;
      if (pdf) {
        try {
          r = await s.api.call('readMaintLog', [{'data': data, 'from': from, 'n': 2}]) as Map;
        } catch (_) {
          r = null;      // (too slow: one page)
        }
      }
      if (r == null || r['again'] == true) r = await s.api.call('readMaintLog', [{'data': data, 'from': from, 'n': 1}]) as Map;
      if (r['off'] == true) throw ApiError('The AI is not set up – a PDF or a photo cannot be read now; import the Excel instead.');
      if (r['again'] == true) throw ApiError('The AI could not read page $from of the log book – try again, or give a PDF of fewer pages.');
      final got = (r['tables'] as List? ?? const []).whereType<Map>().toList();
      tables.addAll(got);
      final p = (asNum(r['pages']) ?? 0).toInt();
      if (p > 0) pages = p;
      final to = (asNum(r['to']) ?? from).toInt();
      if (!pdf || !(pages > 0 ? to < pages : got.isNotEmpty)) break;
      from = to + 1;
    }
    sheets = mliAiSheets(n, tables, [for (final m in s.machines) m.m], s.today);
    if (sheets.isEmpty) throw ApiError('The AI found no table of a log book in this file.');
  }

  /// The web's mliNames: every name of the file looked at by the AI – nothing ticked
  Future<void> _names() async {
    final s = SessionScope.read(context), o = mliNamesOf(sheets);
    setState(() {
      fixState = 'busy';
      fixes = [];
    });
    try {
      final r = await s.api.call('maintImportNames', [{for (final f in o.keys) f: [for (final e in o[f]!.entries) [e.key, e.value]]}]) as Map;
      if (r['off'] == true) {
        fixState = 'off';
      } else {
        fixes = [for (final z in (r['fixes'] as List? ?? const []).whereType<List>()) if (z.length >= 3) MliFix('${z[0]}', '${z[1]}', '${z[2]}', o['${z[0]}']?['${z[1]}'] ?? 0)];
        fixState = 'done';
      }
    } catch (e) {
      fixState = 'err';
      fixErr = errText(e);
    }
    for (final c in _ctl) {
      c.dispose();
    }
    _ctl
      ..clear()
      ..addAll([for (final z in fixes) TextEditingController(text: z.to)]);
    _fresh();
    if (mounted) setState(() {});
  }

  /// a name ticked or changed: the sheets are checked again
  void _fresh() {
    for (final x in sheets) {
      if (x.done == null) x.res = null;
    }
  }

  List<MliSheet> get _ready => [for (final x in sheets) if (x.no.isNotEmpty && x.done == null) x];

  void _twice() {
    final seen = <String>{};
    for (final x in sheets) {
      x.twice = x.no.isNotEmpty && seen.contains(x.no);
      if (x.no.isNotEmpty) seen.add(x.no);
    }
  }

  Future<void> _check() async {
    final s = SessionScope.read(context);
    setState(() => busy = true);
    for (final x in _ready) {
      if (x.twice) continue;
      try {
        x.res = (await s.api.call('checkMaintImport', [{'no': x.no, 'bills': mliBills(x, fixes)}]) as Map).cast<String, dynamic>();
        x.err = '';
      } catch (e) {
        x.res = null;
        x.err = errText(e);
      }
      if (mounted) setState(() {});
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> _import() async {
    final s = SessionScope.read(context);
    final todo = [for (final x in _ready) if (!x.twice && x.res != null && x.res!['ok'] == true) x];
    if (todo.isEmpty) return;
    if (!await askLines(context, 'Import the old log book?', [
      for (final x in todo) '${x.no}: ${x.res!['fresh']} bill(s), ₹${fmtNum(asNum(x.res!['total']))}',
      'Each machinery all of it or nothing; a bill already there is left out.',
    ], yes: 'Import')) return;
    setState(() => busy = true);
    var added = 0;
    for (final x in todo) {
      try {
        x.done = (await s.api.call('importMaint', [{'no': x.no, 'bills': mliBills(x, fixes)}], true) as Map).cast<String, dynamic>();
        added += (asNum(x.done!['added']) ?? 0).toInt();
        any = true;
      } on ApiError catch (e) {
        if (e.code == 'sent') {
          x.done = {'added': 0, 'same': 0, 'sent': e.message};      // (sent for verification – saved when it is approved)
        } else {
          x.err = errText(e);
        }
      } catch (e) {
        x.err = errText(e);
      }
      if (mounted) setState(() {});
    }
    if (!mounted) return;
    setState(() => busy = false);
    final sent = todo.where((x) => x.done?['sent'] != null).firstOrNull;
    toast(context, sent != null ? '${sent.done!['sent']}' : '$added bill(s) imported.');
  }

  /// What a sheet is now – the web's mliState, word for word
  (String, Color) _state(MliSheet x) {
    final d = x.done;
    if (d != null && d['sent'] != null) return ('${d['sent']}', C.greenDark);      // sent for verification
    if (d != null) {
      final first = '${d['first'] ?? ''}', last = '${d['last'] ?? ''}', n = asNum(d['added']) ?? 0;
      return ('✓ ${fmtNum(n)} bill(s) imported${n > 0 ? ' ($first${last != first ? ' – $last' : ''})' : ''}', C.greenDark);
    }
    if (x.no.isEmpty) return ('not imported', C.muted);
    if (x.twice) return ('Two sheets for ${x.no} – keep one.', C.red);
    if (x.err.isNotEmpty) return (x.err, C.red);
    final r = x.res;
    if (r == null) return x.bad.isNotEmpty ? ('${x.bad.length} row(s) without a date – ${x.bad.take(3).join('; ')}', C.red) : ('Press Check', C.muted);
    if (r['ok'] != true) {
      final errs = [for (final e in (r['errors'] as List? ?? const []).whereType<Map>().take(8)) '${e['rows']}: ${e['msg']}'];
      return ('✗ ${r['errorCount']} mistake(s) – nothing of this sheet is imported:\n${errs.join('\n')}', C.red);
    }
    final from = '${r['from'] ?? ''}', to = '${r['to'] ?? ''}';
    return ('✓ ${r['fresh']} new bill(s), ${r['lines']} line(s), ₹${fmtNum(asNum(r['total']))}${from.isNotEmpty ? ' (${showDate(from)} – ${showDate(to)})' : ''}', C.greenDark);
  }

  /// a line that does not add up, as the web says it
  static String warnText(Map w) => 'Line ${w['line']} (${w['work']}): ${w['k'] == 'qr' ? 'Qty × Rate = ₹${fmtNum(asNum(w['a']))}, Amount ₹${fmtNum(asNum(w['b']))}' : w['k'] == 'ag' ? 'Amount + GST = ₹${fmtNum(asNum(w['a']))}, Amount With GST ₹${fmtNum(asNum(w['b']))}' : 'GST ${fmtNum(asNum(w['a']))} % – not a usual rate'}';

  /// (28-10-2026, "duplicate entry import nahi honar ts to show pn krel") the bills left out: its rows, date, ₹ and the bill it is
  static List<String> sameLines(Map r) => [
        for (final z in (r['sameList'] as List? ?? const []).whereType<Map>())
          '${z['rows']} · ${showDate('${z['date']}')} · ₹${fmtNum(asNum(z['total']))} – ${'${z['id']}'.startsWith('(') ? 'twice in the file ${z['id']}' : 'already saved as ${z['id']}'}',
      ];

  /// a line that opens its list (the lines to look at, the bills left out)
  Widget _more(String key, String head, List<String> lines, {int more = 0}) {
    final open = _open.contains(key);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        InkWell(
          key: Key(key),
          onTap: () => setState(() => open ? _open.remove(key) : _open.add(key)),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              Icon(open ? Icons.expand_less_rounded : Icons.expand_more_rounded, size: 18, color: C.muted),
              const SizedBox(width: 4),
              Expanded(child: Text(head, style: const TextStyle(fontSize: 12.5, color: C.muted, fontWeight: FontWeight.w600))),
            ]),
          ),
        ),
        if (open) ...[
          for (final l in lines) Padding(padding: const EdgeInsets.only(left: 22, bottom: 3), child: Text('• $l', style: const TextStyle(fontSize: 12.5, height: 1.35))),
          if (more > 0) Padding(padding: const EdgeInsets.only(left: 22), child: Text('… and $more more', style: const TextStyle(fontSize: 12, color: C.muted))),
        ],
      ]),
    );
  }

  Widget _card(Session s, int i, MliSheet x, List<Map<String, dynamic>> own) {
    final (st, tone) = _state(x);
    final r = x.done ?? (x.res != null && x.res!['ok'] == true ? x.res : null), same = r == null ? 0 : (asNum(r['same']) ?? 0).toInt(), sl = r == null ? const <String>[] : sameLines(r);
    return Container(
      key: Key('mli-$i'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: C.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(x.sheet, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        if (x.label.isNotEmpty) Text('${tr('Name in the file')}: ${x.label}', style: const TextStyle(fontSize: 12.5, color: C.muted)),
        const SizedBox(height: 10),
        PickField(
          key: Key('mli-no-$i'),
          label: 'Machinery (Active, Own)',
          value: x.no,
          items: [for (final m in own) '${m['id']}'],      // (PickField puts the blank line first)
          blank: '– not imported –',
          labels: {for (final m in own) '${m['id']}': '${m['id']}${'${m['name'] ?? ''}'.isNotEmpty && m['name'] != m['id'] ? ' · ${m['name']}' : ''}'},
          enabled: !busy && x.done == null,
          onChanged: (v) => setState(() {
            x.no = v;
            x.res = null;
            x.err = '';
            _twice();
          }),
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 14, runSpacing: 4, children: [
          _fact('Rows', fmtNum(x.rows)),
          _fact('Bills', fmtNum(x.bills.length)),
          _fact('File total (₹)', fmtNum(x.fileTotal)),
          _fact('Total (₹)', fmtNum(x.total)),
        ]),
        const SizedBox(height: 8),
        Text(st, key: Key('mli-st-$i'), style: TextStyle(fontSize: 13, color: tone, fontWeight: FontWeight.w600, height: 1.35)),
        if (same > 0) _more('mli-same-$i', '$same bill(s) already there – left out', sl, more: same - sl.length),
        if (x.warn.isNotEmpty) _more('mli-warn-$i', '${x.warn.length} line(s) to look at – imported as they are', [for (final w in x.warn) warnText(w)]),
      ]),
    );
  }

  Widget _fact(String k, String v) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(k, style: const TextStyle(fontSize: 11.5, color: C.muted)),
        Text(v, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
      ]);

  /// (28-10-2026) the names written in more than one way – ticked by the Admin, "Becomes" can be typed
  Widget _namesCard() {
    final st = fixState;
    Widget line(String t, Color c) => Padding(padding: const EdgeInsets.only(top: 4), child: Text(t, key: const Key('mlf-state'), style: TextStyle(fontSize: 13, color: c, height: 1.35)));
    void tickAll(bool on) => setState(() {
          for (final z in fixes) {
            z.on = on && z.to.trim().isNotEmpty;
          }
          _fresh();
        });
    return Container(
      key: const Key('mlf'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: C.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Names written in more than one way (AI)', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
        if (st == 'busy') line('The AI is looking at every name of the file…', C.muted),
        if (st == 'off') line('The AI is not set up – the names stay as in the file.', C.muted),
        if (st == 'err') line(fixErr, C.red),
        if (st == 'done' && fixes.isEmpty) line('✓ The AI found no name written in more than one way.', C.greenDark),
        if (st == 'done' && fixes.isNotEmpty) ...[
          line('Tick what is to be changed (you may type another name in "Becomes") – the bills are checked and imported with the ticked names; the rest stay as in the file.', C.muted),
          for (final (i, z) in fixes.indexed)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Checkbox(
                  key: Key('mlf-$i'),
                  value: z.on,
                  onChanged: busy
                      ? null
                      : (v) => setState(() {
                            z.on = v == true && z.to.trim().isNotEmpty;
                            _fresh();
                          }),
                ),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Text('${tr(_fieldName[z.f] ?? z.f)}: ${z.from}', key: Key('mlf-from-$i'), style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),      // (the box's label above it, not over the name)
                    TextField(
                      key: Key('mlt-$i'),
                      controller: _ctl[i],
                      enabled: !busy,
                      maxLength: z.f == 'uom' ? 12 : z.f == 'party' ? 80 : 120,
                      decoration: InputDecoration(labelText: tr('Becomes'), counterText: '', isDense: true),
                      onChanged: (v) => setState(() {
                        z.to = v.replaceAll(RegExp(r'\s+'), ' ').trim();
                        if (z.to.isEmpty) z.on = false;
                        _fresh();
                      }),
                    ),
                    Text('${z.n} row(s)', style: const TextStyle(fontSize: 12, color: C.muted)),
                  ]),
                ),
              ]),
            ),
          Wrap(spacing: 8, children: [
            TextButton(key: const Key('mlf-all'), onPressed: busy ? null : () => tickAll(true), child: Text('Tick all')),
            TextButton(key: const Key('mlf-none'), onPressed: busy ? null : () => tickAll(false), child: Text('Untick all')),
          ]),
        ],
        if (st != null && st != 'busy') Align(alignment: Alignment.centerLeft, child: TextButton(key: const Key('mlf-again'), onPressed: busy ? null : _names, child: Text('Ask the AI again'))),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context), own = mliOwn([for (final m in s.machines) m.m], s.today);
    _twice();
    final ready = _ready, stop = busy || reading || fixState == 'busy';
    final okAll = ready.isNotEmpty && ready.every((x) => !x.twice && x.res != null && x.res!['ok'] == true);
    return PopScope(
      canPop: !(busy || reading),      // (not while it reads or imports)
      child: Scaffold(
        appBar: AppBar(title: const TwoLang('Import the old log book', 'जुनी log book import करा', size: 17, weight: FontWeight.w700)),
        body: ListView(key: const Key('mli-list'), padding: const EdgeInsets.fromLTRB(16, 10, 16, 20), children: [
          Text(reading || readErr.isNotEmpty ? widget.name : '${widget.name} – ${sheets.length} sheet(s)', key: const Key('mli-name'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          if (reading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Row(children: [
                const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)),
                const SizedBox(width: 12),
                Expanded(child: Text(say, key: const Key('mli-reading'), style: const TextStyle(fontSize: 14))),
              ]),
            ),
          if (readErr.isNotEmpty) ...[
            Text(readErr, key: const Key('mli-read-err'), style: const TextStyle(fontSize: 13.5, color: C.red, height: 1.35)),
            Align(alignment: Alignment.centerLeft, child: TextButton(key: const Key('mli-retry'), onPressed: _start, child: Text('Try again'))),
          ],
          if (!reading && readErr.isEmpty) ...[
            Text('Total (₹) = the lines with their GST as they will be kept; the file total is its "Amount With GST" (whole rupees in an old file).', style: const TextStyle(fontSize: 12.5, color: C.muted, height: 1.35)),
            const SizedBox(height: 10),
            if (fixState != null) _namesCard(),
            for (final (i, x) in sheets.indexed) _card(s, i, x, own),
          ],
        ]),
        // Check and Import always at hand (a file of many sheets is a long list)
        bottomNavigationBar: SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: C.line))),
            child: Row(children: [
              Expanded(child: OutlinedButton(key: const Key('mli-check'), onPressed: stop || ready.isEmpty ? null : _check, style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)), child: Text('Check'))),
              const SizedBox(width: 10),
              Expanded(child: FilledButton(key: const Key('mli-go'), onPressed: stop || !okAll ? null : _import, style: FilledButton.styleFrom(minimumSize: const Size(0, 48)), child: Text(busy ? 'Importing…' : 'Import'))),
            ]),
          ),
        ),
      ),
    );
  }
}
