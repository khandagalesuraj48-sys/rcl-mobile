/* THE DOCUMENTS GATE (20-11-2026, his decision: "jy user ni documents upload keleli nastil tyana compulsory aahe document upload
 * krne … app open krel direct document upload screen yeil … adhar card pan card bank details driving lience ani eduction … ek ek ki
 * mg submit hoil … nantr app jr upload zalel asel tr ti screen nahi yenar … sobat anek documents … edit delet"; and: all compulsory,
 * PAN / Driving licence / Education may be "Not available", Aadhaar and Bank never).
 *   A new employee uploads his FIVE papers before the app lets him in; the whole app waits until he submits. The server decides what
 *   is required (rcl-hr act_docgate: myGate / myDocNa / myDocDelete); the files are his own "My documents". Nothing of this is on the
 *   HR office's pages. Shown only to an employee whose required papers are not done – a non-employee / a site without HR never waits. */
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/material.dart' as m show Text;
import 'package:url_launcher/url_launcher.dart';

import '../ui/done_pop.dart' show donePop;
import '../ui/hr_skin.dart';
import '../ui/scope.dart';
import '../ui/t.dart';
import '../ui/widgets.dart' show errText;
import 'attach_box.dart' show pickAttFiles;
import 'attendance.dart' show hrModule;
import 'hr_me.dart' show docReady;
import 'hr_shell.dart' show hrAsk;

typedef HrAsk = Future<Map<String, dynamic>> Function(Map<String, dynamic> body);

/// At Stage.ready, before Home: if the employee's required papers are not done, the whole app waits on [DocGateScreen]. A person
/// who is not an employee, or a site with no HR, never waits; if HR cannot be reached, the app is NOT locked (it opens as usual).
class DocsGateHost extends StatefulWidget {
  const DocsGateHost({super.key, required this.child});
  final Widget child;
  @override
  State<DocsGateHost> createState() => _DocsGateHostState();
}

class _DocsGateHostState extends State<DocsGateHost> {
  bool _gate = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  Future<void> _check() async {
    if (!mounted) return;
    final s = SessionScope.read(context);
    if (hrModule(s) == null) return; // no HR on this site: no gate
    try {
      final r = await hrAsk(s, {'action': 'myGate'});
      if (mounted && r['required'] == true) setState(() => _gate = true);
    } catch (_) {/* HR not reached: do not lock the app */}
  }

  @override
  Widget build(BuildContext context) => _gate
      ? DocGateScreen(ask: (b) => hrAsk(SessionScope.read(context), b), onDone: () { if (mounted) setState(() => _gate = false); })
      : widget.child;
}

/// The five cards, the upload / "Not available" / edit-delete, and Submit. [ask] – the HR call of his sign-in; [onDone] – he has
/// submitted (every paper uploaded or "Not available"): the app opens.
class DocGateScreen extends StatefulWidget {
  const DocGateScreen({super.key, required this.ask, required this.onDone});
  final HrAsk ask;
  final VoidCallback onDone;
  @override
  State<DocGateScreen> createState() => _DocGateScreenState();
}

class _DocGateScreenState extends State<DocGateScreen> {
  Map<String, dynamic>? data;
  bool loading = true;
  String busy = '', err = '';

  static const _acc = Color(0xFFCE3B2F), _accSoft = Color(0xFFFBE8E5), _grn = Color(0xFF139150), _grnSoft = Color(0xFFE2F6EA);
  static const _ic = {
    'aadhaar': (Icons.badge_rounded, Color(0xFF3F5BD6), Color(0xFFEAEFFF)),
    'pan': (Icons.credit_card_rounded, Color(0xFFC9960A), Color(0xFFFBF2D8)),
    'bank_passbook': (Icons.account_balance_rounded, Color(0xFF0E8D7E), Color(0xFFDEF5F1)),
    'licence': (Icons.directions_car_rounded, Color(0xFF6B4FE6), Color(0xFFEDE8FF)),
    'education': (Icons.school_rounded, Color(0xFFD5527A), Color(0xFFFCE7EE)),
  };
  static const _hint = {'aadhaar': 'front & back', 'pan': '', 'bank_passbook': 'passbook / cancelled cheque', 'licence': 'front & back', 'education': 'degree / marksheet'};

  @override
  void initState() {
    super.initState();
    _load(first: true);
  }

  // [first] – the screen's very first load: if his papers are already done (he did them on the web), the gate closes at once. A later
  // load (after an upload / "Not available") never closes by itself – the gate waits for his Submit, even when the last paper is done.
  Future<void> _load({bool first = false}) async {
    try {
      final r = await widget.ask({'action': 'myGate'});
      if (!mounted) return;
      setState(() {
        data = r;
        loading = false;
        err = '';
      });
      if (first && r['required'] != true) widget.onDone(); // done elsewhere already
    } catch (e) {
      if (mounted) setState(() {
        loading = false;
        err = errText(e);
      });
    }
  }

  List<Map> get _docs => [for (final d in (data?['docs'] as List? ?? const []).whereType<Map>()) d];
  int get _done => _docs.where((d) => d['state'] == 'uploaded' || d['state'] == 'na').length;

  Future<void> _add(Map doc) async {
    if (busy.isNotEmpty) return;
    final key = '${doc['key']}';
    final how = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 2), child: Align(alignment: Alignment.centerLeft, child: Text('Add ${doc['name']}', mr: '${doc['name']} जोडा', style: TextStyle(fontFamily: 'Montserrat', fontSize: 17, fontWeight: FontWeight.w800, color: sk.ink)))),
          Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 8), child: Align(alignment: Alignment.centerLeft, child: Text('Pick one or more — photos or a PDF.', mr: 'एक किंवा अनेक निवडा — photos किंवा PDF.', style: TextStyle(fontSize: 12.5, color: sk.muted)))),
          ListTile(key: const Key('dg-camera'), leading: const Icon(Icons.photo_camera_rounded, color: _acc), title: const Text('Camera', mr: 'Camera'), subtitle: const Text('Take a photo now', mr: 'आता photo काढा'), onTap: () => Navigator.pop(c, 'camera')),
          ListTile(key: const Key('dg-gallery'), leading: const Icon(Icons.photo_library_rounded, color: Color(0xFF3F5BD6)), title: const Text('Photos', mr: 'Photos'), subtitle: const Text('Pick several at once', mr: 'एकत्र अनेक निवडा'), onTap: () => Navigator.pop(c, 'gallery')),
          ListTile(key: const Key('dg-pdf'), leading: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFFC85A3C)), title: const Text('PDF file', mr: 'PDF file'), subtitle: const Text('A scan or document', mr: 'scan किंवा document'), onTap: () => Navigator.pop(c, 'pdf')),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (how == null || !mounted) return;
    setState(() {
      busy = key;
      err = '';
    });
    try {
      final got = await pickAttFiles(how, 10);
      if (got.isEmpty) {
        if (mounted) setState(() => busy = '');
        return;
      }
      var n = 0;
      for (final g in got) {
        final f = docReady(g.name, g.bytes);
        if (f == null) continue;
        final u = await widget.ask({'action': 'myDocUploadUrl', 'kind': key, 'type': f.$2, 'bytes': f.$1.length});
        if (!mounted) return;
        await SessionScope.read(context).api.hrFile('${u['url']}', f.$1, f.$2);
        await widget.ask({'action': 'myDocAdd', 'kind': key, 'path': u['path'], 'bytes': f.$1.length});
        n++;
      }
      await _load();
      if (mounted && n > 0) donePop(context, _done == _docs.length ? _t('All documents are in — press Submit', 'सगळी कागदपत्रे झाली — Submit दाबा') : _t('Added', 'जोडले'));
    } catch (e) {
      if (mounted) setState(() => err = errText(e));
    } finally {
      if (mounted) setState(() => busy = '');
    }
  }

  Future<void> _na(Map doc) async {
    final ctrl = TextEditingController();
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('You don\'t have this?', mr: 'हे तुमच्याकडे नाही?', style: TextStyle(fontFamily: 'Montserrat', fontSize: 18, fontWeight: FontWeight.w800, color: sk.ink)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${doc['name']} will be marked "Not available". HR will see this — you can add it later.', mr: '${doc['name']} "उपलब्ध नाही" असे लागेल. HR ला दिसेल — नंतर जोडता येईल.', style: TextStyle(fontSize: 14, height: 1.4, color: sk.muted)),
          const SizedBox(height: 12),
          TextField(key: const Key('dg-na-reason'), controller: ctrl, maxLength: 120, decoration: InputDecoration(labelText: tr('Reason (short)'), border: const OutlineInputBorder(), counterText: '')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text('Back', mr: 'मागे')),
          FilledButton(key: const Key('dg-na-ok'), style: FilledButton.styleFrom(backgroundColor: sk.accent, foregroundColor: sk.onAccent), onPressed: () => Navigator.pop(c, true), child: Text('Mark not available', mr: 'उपलब्ध नाही')),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    setState(() {
      busy = '${doc['key']}';
      err = '';
    });
    try {
      await widget.ask({'action': 'myDocNa', 'kind': doc['key'], 'na': true, 'reason': ctrl.text.trim()});
      await _load();
    } catch (e) {
      if (mounted) setState(() => err = errText(e));
    } finally {
      if (mounted) setState(() => busy = '');
    }
  }

  Future<void> _undoNa(Map doc) async => _simple({'action': 'myDocNa', 'kind': doc['key'], 'na': false}, doc);
  Future<void> _delete(Map file, Map doc) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Remove this file?', mr: 'ही file काढायची?', style: TextStyle(fontFamily: 'Montserrat', fontSize: 17, fontWeight: FontWeight.w800, color: sk.ink)),
        content: Text('You can add it again.', mr: 'पुन्हा जोडता येईल.', style: TextStyle(fontSize: 14, color: sk.muted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text('Back', mr: 'मागे')),
          FilledButton(key: const Key('dg-del-ok'), style: FilledButton.styleFrom(backgroundColor: const Color(0xFFC0463B), foregroundColor: Colors.white), onPressed: () => Navigator.pop(c, true), child: Text('Remove', mr: 'काढा')),
        ],
      ),
    );
    if (yes == true) await _simple({'action': 'myDocDelete', 'doc': file['id']}, doc);
  }

  Future<void> _simple(Map<String, dynamic> body, Map doc) async {
    setState(() {
      busy = '${doc['key']}';
      err = '';
    });
    try {
      await widget.ask(body);
      await _load();
    } catch (e) {
      if (mounted) setState(() => err = errText(e));
    } finally {
      if (mounted) setState(() => busy = '');
    }
  }

  Future<void> _openFile(Map file) async {
    try {
      final j = await widget.ask({'action': 'myDocLink', 'doc': file['id']});
      await launchUrl(Uri.parse('${j['url']}'), mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) setState(() => err = errText(e));
    }
  }

  String _t(String en, String mr) => Lang.i.pair(en, mr);

  @override
  Widget build(BuildContext context) {
    final docs = _docs, ready = data?['submit_ready'] == true, left = docs.length - _done;
    return PopScope(
      canPop: false, // the whole app waits here
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F2EC),
        body: SafeArea(
          child: loading
              ? const Center(child: CircularProgressIndicator(color: _acc))
              : Column(children: [
                  Expanded(
                    child: ListView(key: const Key('dg-list'), padding: const EdgeInsets.fromLTRB(18, 14, 18, 8), children: [
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: _accSoft, borderRadius: BorderRadius.circular(999)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.lock_rounded, size: 14, color: _acc),
                            const SizedBox(width: 6),
                            Text('Required to continue', mr: 'पुढे जाण्यासाठी आवश्यक', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _acc)),
                          ]),
                        ),
                        const Spacer(),
                        InkWell(key: const Key('dg-signout'), onTap: () => SessionScope.read(context).signOut(), borderRadius: BorderRadius.circular(8), child: Padding(padding: const EdgeInsets.all(6), child: Text('Sign out', mr: 'Sign out', style: TextStyle(fontSize: 12.5, color: sk.muted)))),
                      ]),
                      const SizedBox(height: 10),
                      Text('Your documents', mr: 'तुमची कागदपत्रे', style: TextStyle(fontFamily: 'Montserrat', fontSize: 25, fontWeight: FontWeight.w800, letterSpacing: -.3, color: sk.ink)),
                      const SizedBox(height: 4),
                      Text('Upload these once to start. Aadhaar & Bank must be uploaded; for the others you may tap “I don’t have this”. You can add more than one file, and edit or delete any.',
                          mr: 'सुरू करण्यासाठी ही एकदा upload करा. Aadhaar व Bank upload करावीच; बाकीसाठी “माझ्याकडे नाही” दाबू शकता. अनेक files चालतात, बदलता/काढता येतात.',
                          style: TextStyle(fontSize: 12.6, height: 1.5, color: sk.muted)),
                      const SizedBox(height: 14),
                      Row(children: [
                        Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(9), child: LinearProgressIndicator(value: docs.isEmpty ? 0.0 : _done / docs.length, minHeight: 8, backgroundColor: const Color(0xFFE7E3DA), valueColor: const AlwaysStoppedAnimation(_grn)))),
                        const SizedBox(width: 10),
                        Text('$_done of ${docs.length} done', mr: '$_done / ${docs.length} झाले', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: sk.ink)),
                      ]),
                      const SizedBox(height: 14),
                      if (err.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(err, style: const TextStyle(color: _acc, fontSize: 13, fontWeight: FontWeight.w600))),
                      for (final d in docs) _card(d),
                    ]),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
                    decoration: const BoxDecoration(color: Color(0xFFF5F2EC), boxShadow: [BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, -4))]),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      if (!ready) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(_naWord(left), mr: _naWordMr(left), textAlign: TextAlign.center, style: const TextStyle(fontSize: 11.8, fontWeight: FontWeight.w700, color: _acc))),
                      SizedBox(
                        height: 54,
                        width: double.infinity,
                        child: FilledButton(
                          key: const Key('dg-submit'),
                          style: FilledButton.styleFrom(backgroundColor: ready ? _acc : const Color(0xFFE8D9D6), foregroundColor: ready ? Colors.white : const Color(0xFFB98C85), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                          onPressed: ready && busy.isEmpty ? widget.onDone : null,
                          child: Text('Submit', mr: 'Submit', style: const TextStyle(fontFamily: 'Montserrat', fontSize: 16, fontWeight: FontWeight.w800)),
                        ),
                      ),
                    ]),
                  ),
                ]),
        ),
      ),
    );
  }

  String _naWord(int left) => '$left more ${left == 1 ? 'document' : 'documents'} required before you can continue';
  String _naWordMr(int left) => 'पुढे जाण्यासाठी अजून $left कागदपत्रे बाकी';

  Widget _card(Map d) {
    final key = '${d['key']}', state = '${d['state']}', files = [for (final f in (d['files'] as List? ?? const []).whereType<Map>()) f];
    final ic = _ic[key] ?? (Icons.description_rounded, const Color(0xFF6B7280), const Color(0xFFEEF0F3));
    final working = busy == key;
    return Container(
      key: Key('dg-card-$key'),
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
      decoration: BoxDecoration(
        color: state == 'na' ? const Color(0xFFFAFAFB) : Colors.white,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: const Color(0xFFECEDF1)),
        boxShadow: state == 'na' ? null : const [BoxShadow(color: Color(0x0D141E37), blurRadius: 16, offset: Offset(0, 5))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 45, height: 45, decoration: BoxDecoration(color: state == 'na' ? const Color(0xFFEEEFF2) : ic.$3, borderRadius: BorderRadius.circular(14)), child: Icon(ic.$1, size: 23, color: state == 'na' ? const Color(0xFFAEB4C0) : ic.$2)),
          const SizedBox(width: 13),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text('${d['name']}', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: state == 'na' ? const Color(0xFF98A0AE) : sk.ink)),
              const SizedBox(height: 3),
              Text(_sub(state, files.length, key), mr: _subMr(state, files.length, key), style: TextStyle(fontSize: 11.6, fontWeight: FontWeight.w600, color: state == 'rejected' ? _acc : state == 'pending' && (key == 'aadhaar' || key == 'bank_passbook') ? const Color(0xFFB07A12) : sk.muted)),
            ]),
          ),
          const SizedBox(width: 8),
          if (working) const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: _acc))
          else if (state == 'uploaded') Container(width: 26, height: 26, decoration: const BoxDecoration(color: _grnSoft, shape: BoxShape.circle), child: const Icon(Icons.check_rounded, size: 16, color: _grn))
          else if (state == 'na') _naTag()
          else _uploadBtn(d),
        ]),
        // uploaded files – edit / delete
        if (state == 'uploaded' && files.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final f in files) _fileChip(f, d),
            _addMore(d),
          ]),
        ],
        // a paper that may be "Not available"
        if ((state == 'pending' || state == 'rejected') && d['allow_na'] == true && !working) ...[
          const SizedBox(height: 6),
          Align(alignment: Alignment.centerLeft, child: TextButton(key: Key('dg-na-$key'), style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap), onPressed: () => _na(d), child: Text('I don’t have this', mr: 'माझ्याकडे नाही', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: sk.muted, decoration: TextDecoration.underline)))),
        ],
        // "Not available" chosen – undo
        if (state == 'na' && !working) ...[
          const SizedBox(height: 6),
          Align(alignment: Alignment.centerLeft, child: TextButton(key: Key('dg-undo-$key'), style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap), onPressed: () => _undoNa(d), child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.undo_rounded, size: 14, color: Color(0xFF8A92A3)), const SizedBox(width: 4), Text('Undo / upload instead', mr: 'Undo / upload करा', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: sk.muted))]))),
        ],
      ]),
    );
  }

  // a plain tappable pill, not a Material button – a Material button in a Row's trailing (non-flex) slot is given an unbounded width
  Widget _uploadBtn(Map d) => InkWell(
        key: Key('dg-add-${d['key']}'),
        onTap: () => _add(d),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: _acc, width: 1.6)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.upload_rounded, size: 17, color: _acc),
            const SizedBox(width: 6),
            Text('${d['state']}' == 'rejected' ? _t('Attach again', 'पुन्हा जोडा') : _t('Upload', 'Upload'), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _acc)),
          ]),
        ),
      );

  Widget _naTag() => Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7), decoration: BoxDecoration(color: const Color(0xFFEEF0F3), borderRadius: BorderRadius.circular(999)), child: const m.Text('N / A', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF7E8798))));

  // same key as the first-upload button (the two never show together – pending shows Upload, uploaded shows Add-more), so "add another file" is reachable by one key
  Widget _addMore(Map d) => InkWell(
        key: Key('dg-add-${d['key']}'),
        onTap: () => _add(d),
        borderRadius: BorderRadius.circular(10),
        child: Container(width: 54, height: 54, decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFCBB4AF), width: 1.6, style: BorderStyle.solid)), child: const Icon(Icons.add_rounded, color: _acc)),
      );

  Widget _fileChip(Map f, Map d) {
    final pdf = '${f['mime']}'.contains('pdf');
    return Stack(clipBehavior: Clip.none, children: [
      InkWell(
        onTap: () => _openFile(f),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: pdf ? const Color(0xFFFBEAE3) : const Color(0xFFEFF2F7), border: Border.all(color: const Color(0xFFE7E2D8))),
          child: Icon(pdf ? Icons.picture_as_pdf_rounded : Icons.image_rounded, color: pdf ? const Color(0xFFC85A3C) : const Color(0xFF5E6C86), size: 22),
        ),
      ),
      Positioned(
        top: -6,
        right: -6,
        child: InkWell(
          key: Key('dg-rm-${f['id']}'),
          onTap: () => _delete(f, d),
          customBorder: const CircleBorder(),
          child: Container(width: 22, height: 22, decoration: const BoxDecoration(color: Color(0xFFC0463B), shape: BoxShape.circle), child: const Icon(Icons.close_rounded, size: 13, color: Colors.white)),
        ),
      ),
    ]);
  }

  String _sub(String state, int n, String key) {
    if (state == 'uploaded') return 'Uploaded · $n file${n == 1 ? '' : 's'}';
    if (state == 'na') return 'Marked: not available';
    if (state == 'rejected') return 'Not accepted — attach again';
    final must = key == 'aadhaar' || key == 'bank_passbook';
    final h = _hint[key] ?? '';
    return (must ? 'Must upload' : 'Required') + (h.isEmpty ? '' : ' · $h');
  }

  String _subMr(String state, int n, String key) {
    if (state == 'uploaded') return 'Upload झाले · $n file';
    if (state == 'na') return 'उपलब्ध नाही';
    if (state == 'rejected') return 'स्वीकारले नाही — पुन्हा जोडा';
    return key == 'aadhaar' || key == 'bank_passbook' ? 'upload करावेच' : 'आवश्यक';
  }
}
