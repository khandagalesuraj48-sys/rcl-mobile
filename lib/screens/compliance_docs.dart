/* (3.79.0, Mechanical update-205) THE DOCUMENTS OF A MACHINERY IN VEHICLE COMPLIANCE – the app's own screens of the web's 📎 Documents
 * (asked 03-11-2026: "vehicle compliance madhe pratek vehicle ch document upload krta yaw asa haway rc book pn ok ani tya gadich tax
 * invoice pn ok ani … renewal wise asaw mhanje maghche document pn mala bghta yeil"):
 *   CmpDocsScreen  – its RC Book and Tax Invoice (the invoice of buying it – each one added is kept, the earlier ones stay) and each paper
 *                    with every renewal of the history and ITS files; each file Open / Print / Download (links for 15 minutes);
 *                    "+ Add RC Book" / "+ Add Tax Invoice" / "+ Add file" (Vehicle Compliance Edit).
 *   cmpPickFiles   – the files of a renewal (the renew of a paper): the attachments' strip, sent one by one (cmpDoc), their list back.
 * Files are only added – never taken out. Server: getCmpFiles, cmpDoc, cmpFiles (the web's same actions, checks and access). */
import 'dart:convert';

import 'package:flutter/material.dart' hide Text;
import 'package:url_launcher/url_launcher.dart';

import '../core/attach.dart';
import '../core/format.dart';
import '../ui/fields.dart';
import '../ui/outputs.dart' show shareFile;
import '../ui/scope.dart';
import '../ui/t.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import '../web/print_view.dart' show PrintView;
import 'attach_box.dart' show AttachStrip, AttViewer;
import 'bill_print.dart' show kSmallBtn;

const kCmpKeepDocs = ['RC Book', 'Tax Invoice'];
String _dv(Object? v) => v == 'NA' ? 'N/A' : v == 'LIFETIME' ? 'Lifetime' : '${v ?? ''}'.isEmpty ? '–' : showDate('$v');
List<Map<String, dynamic>> _maps(dynamic l) => [for (final x in (l as List? ?? const []).whereType<Map>()) x.cast<String, dynamic>()];

Future<void> openCmpDocs(BuildContext context, String no) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => CmpDocsScreen(no: no)));

/// The files of a renewal: picked, sent (cmpDoc), their list ([{sha}]) – an empty list = the date only; null = Cancel (nothing saved).
Future<List<Map<String, dynamic>>?> cmpPickFiles(BuildContext context, String title, String sub) async {
  final got = await Navigator.of(context).push<Map<String, dynamic>>(MaterialPageRoute(builder: (_) => _CmpFilesScreen(title: title, sub: sub)));
  return got == null ? null : [for (final x in (got['files'] as List? ?? const []).whereType<Map>()) x.cast<String, dynamic>()];
}

class _CmpFilesScreen extends StatefulWidget {
  const _CmpFilesScreen({required this.title, required this.sub, this.keep = false});
  final String title, sub;

  /// an RC Book / Tax Invoice added: its No, date and remark (optional) asked too
  final bool keep;
  @override
  State<_CmpFilesScreen> createState() => _CmpFilesScreenState();
}

class _CmpFilesScreenState extends State<_CmpFilesScreen> {
  final files = <AttFile>[];
  final no = TextEditingController(), rem = TextEditingController();
  String on = '', msg = '';
  bool busy = false;

  @override
  void dispose() {
    no.dispose();
    rem.dispose();
    super.dispose();
  }

  Future<void> _done() async {
    final s = SessionScope.read(context);
    if (widget.keep && files.isEmpty) {
      setState(() => msg = 'Add the PDF / photo first.');
      return;
    }
    setState(() {
      busy = true;
      msg = '';
    });
    final bad = await attSendAll(s.api, files, () { if (mounted) setState(() {}); }, action: 'cmpDoc');
    if (!mounted) return;
    setState(() => busy = false);
    if (bad.isNotEmpty) {
      setState(() => msg = bad);
      return;
    }
    Navigator.pop(context, <String, dynamic>{'files': [for (final f in files) f.ref], 'docNo': no.text.trim(), 'on': on, 'remark': rem.text.trim()});
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis)),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
            child: FilledButton.icon(key: const Key('cpf-done'), style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)), onPressed: busy ? null : _done,
                icon: busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.check_rounded), label: Text(busy ? 'Sending…' : widget.keep ? 'Save' : 'Done')),
          ),
        ),
        body: ListView(padding: const EdgeInsets.fromLTRB(16, 10, 16, 20), children: [
          Text(widget.sub, style: const TextStyle(fontSize: 12.5, color: C.muted, height: 1.35)),
          const SizedBox(height: 10),
          AttachStrip(files: files, max: 10, enabled: !busy, onChanged: () => setState(() {})),
          if (widget.keep) ...[
            const SizedBox(height: 12),
            TextBox(key: const Key('cpf-no'), label: widget.title.startsWith('RC Book') ? 'RC No (optional)' : 'Invoice No (optional)', controller: no),
            const SizedBox(height: 8),
            DateField(key: const Key('cpf-on'), label: 'Date (optional)', value: on, last: parseKey(SessionScope.read(context).today), onChanged: (v) => setState(() => on = v)),
            const SizedBox(height: 8),
            TextBox(key: const Key('cpf-rem'), label: 'Remark (optional)', controller: rem),
          ],
          if (msg.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: InfoLine(msg, bad: true)),
        ]),
      );
}

/// A machinery's documents – the web's 📎 Documents panel.
class CmpDocsScreen extends StatefulWidget {
  const CmpDocsScreen({super.key, required this.no});
  final String no;
  @override
  State<CmpDocsScreen> createState() => _CmpDocsScreenState();
}

class _CmpDocsScreenState extends State<CmpDocsScreen> {
  Map<String, dynamic>? d;
  String err = '', busy = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => err = '');
    try {
      final r = (await SessionScope.read(context).api.call('getCmpFiles', [{'no': widget.no}]) as Map).cast<String, dynamic>();
      if (mounted) setState(() => d = r);
    } catch (e) {
      if (mounted) setState(() => err = errText(e));
    }
  }

  /// "+ Add …": a new RC Book / Tax Invoice (id ''), a file to a line (id), or to the paper of its date now (a paper, id '')
  Future<void> _add(String doc, String id) async {
    final s = SessionScope.read(context), keep = kCmpKeepDocs.contains(doc) && id.isEmpty;
    final got = await Navigator.of(context).push<Map<String, dynamic>>(MaterialPageRoute(
        builder: (_) => _CmpFilesScreen(title: '$doc – ${widget.no}', sub: id.isNotEmpty ? 'Added to $id (its files stay).' : keep ? 'A new $doc – the earlier ones stay.' : 'With the $doc of its date now.', keep: keep)));
    if (got == null || !mounted) return;
    final files = (got['files'] as List? ?? const []);
    if (files.isEmpty) return;
    try {
      final r = (await s.api.call('cmpFiles', [{'no': widget.no, 'doc': doc, 'id': id, 'files': files, if (keep) ...{'docNo': got['docNo'], 'on': got['on'], 'remark': got['remark']}}], true) as Map).cast<String, dynamic>();
      if (!mounted) return;
      final n = (r['n'] as num?)?.toInt() ?? files.length;
      toast(context, '$n file${n == 1 ? '' : 's'} kept with the $doc of ${widget.no}.');
      await _load();
    } catch (e) {
      if (mounted) toast(context, tr(errText(e)), bad: true);
    }
  }

  Future<void> _do(String what, Map x, List<Map> all) async {
    final s = SessionScope.read(context), url = '${x['url'] ?? ''}', pdf = x['mime'] == 'application/pdf';
    final name = '${x['name'] ?? ''}'.isNotEmpty ? '${x['name']}' : (pdf ? 'document.pdf' : 'photo.jpg');
    if (what == 'open' && !pdf) {
      await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => AttViewer(files: [for (final y in all) AttFile.kept(y)], start: all.indexOf(x), title: widget.no)));
      return;
    }
    if (what != 'download' && pdf) {      // a PDF: the phone's PDF reader (printed from there)
      if (url.isEmpty || !await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)) {
        if (mounted) toast(context, 'The file could not be opened – open the documents again (the links work for 15 minutes).', bad: true);
      }
      return;
    }
    setState(() => busy = '${x['sha']}$what');
    try {
      final b = await s.api.fileBytes(url);
      if (!mounted) return;
      if (what == 'download') {
        await shareFile(b, name, '${x['mime'] ?? 'image/jpeg'}');
      } else {
        await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PrintView(html: '<!doctype html><title>${_esc(name)}</title><style>body{margin:0}img{max-width:100%;}</style><img src="data:${x['mime'] ?? 'image/jpeg'};base64,${base64Encode(b)}">', title: name)));
      }
    } catch (e) {
      if (mounted) toast(context, errText(e), bad: true);
    } finally {
      if (mounted) setState(() => busy = '');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context), dd = d, can = s.canEdit('Vehicle Compliance') && dd?['on'] == true;
    final rows = _maps(dd?['rows']);
    return Scaffold(
      appBar: AppBar(title: Text('Documents – ${widget.no}', maxLines: 1, overflow: TextOverflow.ellipsis), actions: [IconButton(tooltip: tr('Refresh'), onPressed: _load, icon: const Icon(Icons.refresh_rounded))]),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(key: const Key('cpd-list'), padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
          if (err.isNotEmpty) InfoLine(err, bad: true),
          if (dd == null && err.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
          if (dd != null) ...[
            Text([dd['type'], dd['ownership'], dd['owner']].where((x) => '${x ?? ''}'.isNotEmpty).join(' · '), style: const TextStyle(fontSize: 12.5, color: C.muted)),
            if (dd['on'] != true) Padding(padding: const EdgeInsets.only(top: 8), child: InfoLine('The documents cannot be kept yet at this site – the Admin runs sql/supabase_step1zl_compliance_files.sql once in Supabase → SQL Editor (in every site).', bad: true)),
            for (final k in kCmpKeepDocs) ...() {
              final l = rows.where((r) => r['doc'] == k).toList();
              return [
                _head(k, k == 'Tax Invoice' ? 'the invoice of buying the vehicle' : '', can ? _addBtn('cpd-add-$k', 'Add $k', () => _add(k, '')) : null),
                if (l.isEmpty) Text('Not added yet.', style: const TextStyle(color: C.muted)),
                for (final (i, r) in l.indexed) _line(r, '${i == 0 ? 'Latest' : 'Earlier'} – added ${_dv(r['on'])}', can),
              ];
            }(),
            for (final p in _maps(dd['papers'])) ...() {
              final name = '${p['name']}', now = '${p['v'] ?? ''}', l = rows.where((r) => r['doc'] == name).toList(), hasNow = now.isEmpty || l.any((r) => '${r['to']}' == now);
              return [
                _head(name, now.isEmpty ? 'not entered' : 'now: valid upto ${_dv(now)}', null),
                if (!hasNow)
                  _card(Key('cpd-now-$name'), [
                    Row(children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Valid upto ${_dv(now)}', style: const TextStyle(fontWeight: FontWeight.w800)),
                        Text('the date now – no renewal of it in the history', style: const TextStyle(fontSize: 12, color: C.muted)),
                      ])),
                      if (can) _addBtn('cpd-add-$name', 'Add file', () => _add(name, '')),
                    ]),
                  ]),
                if (l.isEmpty && hasNow) Text('No renewal in the history yet.', style: const TextStyle(color: C.muted)),
                for (final r in l) _line(r, 'Valid upto ${_dv(r['to'])}${r['source'] == 'Document' ? '' : ' (was ${_dv(r['from'])})'}', can, sub: '${r['source'] == 'Document' ? 'files added' : r['source'] == 'Renewal' ? 'renewed on' : '${r['source'] ?? ''}'} ${_dv(r['on'])}'),
              ];
            }(),
            const SizedBox(height: 12),
            Text('The links work for 15 minutes – open this again after that.', style: const TextStyle(fontSize: 12.5, color: C.muted)),
          ],
        ]),
      ),
    );
  }

  Widget _head(String t, String sub, Widget? btn) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 6),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            if (sub.isNotEmpty) Text(sub, style: const TextStyle(fontSize: 12.5, color: C.muted)),
          ])),
          if (btn != null) btn,
        ]),
      );

  Widget _addBtn(String key, String label, VoidCallback on) => OutlinedButton.icon(key: Key(key), style: kSmallBtn, onPressed: busy.isEmpty ? on : null, icon: const Icon(Icons.add_rounded), label: Text(label));

  Widget _card(Key key, List<Widget> kids) => Container(
        key: key,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 6),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.line)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: kids),
      );

  Widget _line(Map<String, dynamic> r, String head, bool can, {String sub = ''}) {
    final files = [for (final x in (r['files'] as List? ?? const []).whereType<Map>()) x];
    final meta = [if ('${r['docNo'] ?? ''}'.isNotEmpty) 'No ${r['docNo']}', if ('${r['amount'] ?? ''}'.isNotEmpty) '₹${fmtNum(asNum(r['amount']))}', if ('${r['remark'] ?? ''}'.isNotEmpty) '${r['remark']}', if ('${r['by'] ?? ''}'.isNotEmpty) 'by ${r['by']}', '${r['id']}'].join(' · ');
    return _card(Key('cpd-line-${r['id']}'), [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(head, style: const TextStyle(fontWeight: FontWeight.w800)),
          if (sub.isNotEmpty) Text(sub, style: const TextStyle(fontSize: 12, color: C.muted)),
          Text(meta, style: const TextStyle(fontSize: 12, color: C.muted)),
        ])),
        if (can) _addBtn('cpd-addto-${r['id']}', 'Add file', () => _add('${r['doc']}', '${r['id']}')),
      ]),
      if (files.isEmpty) Padding(padding: const EdgeInsets.only(top: 4, bottom: 4), child: Text('No file with this line.', style: const TextStyle(fontSize: 12.5, color: C.muted))),
      for (final x in files) _file(x, files),
    ]);
  }

  Widget _file(Map x, List<Map> all) {
    final pdf = x['mime'] == 'application/pdf', sha = '${x['sha']}', at = '${x['at'] ?? ''}';
    Widget act(String what, String label, IconData i) => TextButton.icon(
          key: Key('cpd-$what-$sha'),
          onPressed: busy.isNotEmpty || '${x['url'] ?? ''}'.isEmpty ? null : () => _do(what, x, all),
          icon: busy == '$sha$what' ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(i, size: 18),
          label: Text(label),
        );
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(pdf ? Icons.picture_as_pdf_rounded : Icons.image_rounded, color: pdf ? C.red : C.blue),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${x['name'] ?? ''}'.isEmpty ? (pdf ? 'PDF' : 'Photo') : '${x['name']}', style: const TextStyle(fontWeight: FontWeight.w700)),
            if ('${x['by'] ?? ''}'.isNotEmpty) Text('${x['by']}${at.length >= 10 ? ' · ${showDate(at.substring(0, 10))}' : ''}', style: const TextStyle(fontSize: 12, color: C.muted)),
          ])),
        ]),
        Wrap(children: [act('open', 'Open', Icons.open_in_new_rounded), act('print', 'Print', Icons.print_rounded), act('download', 'Download', Icons.download_rounded)]),
      ]),
    );
  }
}

String _esc(String v) => v.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');
