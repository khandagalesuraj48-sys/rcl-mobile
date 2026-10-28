/* VENDOR MASTER – the app's own screens (3.4.0), the same as the web's Vendors page: every owner of an asset is a vendor (Own =
 * Rachana Construction Limited); the list (search Vendor / GST / PAN, Details: not filled / complete), "+ New vendor", "Save all
 * owners as vendors", each vendor's assets, mobile, GST, PAN, bank, BOQs and how complete its details are; the form (Vendor Name –
 * a rename moves everything of the vendor, asked first –, Mobile, Email, Aadhaar, GST registered / GST Number – its check letter,
 * State and the PAN inside it –, PAN, Bank, Branch, Account, IFSC – the bank and branch looked up –, Address, Remark), Delete
 * details. Server: getVendors, saveVendor, deleteVendor, vendorsFromOwners.
 * (3.57.0, Mechanical update-181) a Material Supplier (made by the Store's import of its old inward register): marked by its name, the
 * Type filter (All / Machinery & billing / Material suppliers (Store)), the count; its type in the form – where this site keeps it.
 * (3.59.0, Mechanical update-184, asked 28-10-2026: "new vendor banwanatana sadhya ekach aahe vendor name tr tith company name as banaw ani
 * ajun ek fild kr owner name … vendor che attachment add option de … adhar pan gst … udyam bank details … kadhi pn mi bgu shaku print or
 * download kru shaku") the Company Name (the vendor's name, as before) and its Owner Name; its DOCUMENTS – Aadhaar, PAN, GST certificate,
 * Udyam, Bank details (cheque / passbook), Other – each a PDF or a photo (vendorDoc, kept once in the private store, as a bill's files),
 * saved with the vendor; from the list its documents (getVendorDocs) – each opened, printed or downloaded (saved / shared). Where this
 * site's database keeps them (getBoqs vdocsOn – step 1zj); otherwise the form says what to run and the vendor is saved as before. */
import 'dart:convert';

import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/attach.dart';
import '../core/format.dart' show showDate;
import '../core/masters.dart';
import '../core/session.dart' show Session;
import '../ui/outputs.dart' show shareFile;
import '../web/print_view.dart' show PrintView;
import 'attach_box.dart' show AttachStrip, AttViewer;
import '../ui/fields.dart';
import '../ui/scope.dart';
import '../ui/t.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'boq.dart';
import 'machinery.dart' show toneOf, softOf;
import '../ui/help.dart' show GuideButton;
import '../ui/ask_bot.dart';

Future<void> openVendors(BuildContext context) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const VendorMasterScreen()));

/// (3.59.0, Mechanical update-184) the kinds of a vendor's documents (the server's VENDOR_DOC_KINDS_) and their names (the web's V_DOC_KINDS)
const kVendorDocKinds = [('Aadhaar', 'Aadhaar'), ('PAN', 'PAN'), ('GST', 'GST certificate'), ('Udyam', 'Udyam'), ('Bank', 'Bank details (cheque / passbook)'), ('Other', 'Other')];

/// a kind's name ('Bank' → 'Bank details (cheque / passbook)')
String vendorDocKind(Object? k) => kVendorDocKinds.firstWhere((x) => x.$1 == '$k', orElse: () => ('Other', 'Other')).$2;

/// what the server says of a vendor's documents: their count
int vendorDocCount(Map v) => (v['docs'] is List ? v['docs'] as List : const []).length;

/// (3.59.0) a vendor's documents from the list – the web's 📎: opened, printed, downloaded (the links work for 15 minutes)
Future<void> openVendorDocs(BuildContext context, String name) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => VendorDocsScreen(name: name)));

class VendorMasterScreen extends StatefulWidget {
  const VendorMasterScreen({super.key, this.find = ''});

  /// (3.14.0) opened by the search with this name in the search box (the web's gsOpenVendor)
  final String find;
  @override
  State<VendorMasterScreen> createState() => _VendorMasterScreenState();
}

class _VendorMasterScreenState extends State<VendorMasterScreen> {
  List<Map<String, dynamic>> all = [];
  bool loading = true;
  String err = '', q = '', st = '', ty = '', busy = '';
  late final qc = TextEditingController(text: widget.find);
  /// (3.59.0) this site keeps a vendor's Owner Name and documents (getBoqs vdocsOn – step 1zj)
  bool docsOn = false, _flagsAsked = false;

  @override
  void dispose() {
    qc.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    q = widget.find;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load({bool quiet = false}) async {
    final s = SessionScope.read(context);
    if (!quiet) setState(() => loading = true);
    try {
      final r = await s.api.call('getVendors');
      if (!mounted) return;
      setState(() {
        all = [for (final v in (r as List? ?? const []).whereType<Map>()) v.cast<String, dynamic>()];
        loading = false;
        err = '';
      });
      if (!_flagsAsked) _flags(s);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        err = errText(e);
      });
    }
  }

  /// (3.59.0) whether this site keeps the Owner Name and the documents – as the web's page knows it (getBoqs vdocsOn)
  Future<void> _flags(Session s) async {
    _flagsAsked = true;
    try {
      final r = await s.api.call('getBoqs') as Map;
      if (mounted) setState(() => docsOn = r['vdocsOn'] == true);
    } catch (_) {
      _flagsAsked = false;      // (asked again with the next reading)
    }
  }

  void _take(dynamic vendors) {
    if (vendors is List) all = [for (final v in vendors.whereType<Map>()) v.cast<String, dynamic>()];
  }

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    final can = s.canEdit('Vendor Master');
    final list = vendorsShown(all, q, st, ty: ty), nMat = all.where((v) => v['type'] == kMatSup).length;
    final unsaved = [for (final v in all) if (v['saved'] != true) '${v['name']}'];
    return Scaffold(
      appBar: AppBar(
        title: const TwoLang('Vendor Master', 'व्हेंडर मास्टर', size: 20, weight: FontWeight.w700),
        actions: withAsk([const GuideButton('vendors'), 
          if (can) IconButton(key: const Key('v-new'), tooltip: tr('+ New vendor'), onPressed: () => _open(null), icon: const Icon(Icons.person_add_alt_1_rounded)),
          IconButton(tooltip: tr('Refresh'), onPressed: loading ? null : _load, icon: const Icon(Icons.refresh_rounded)),
        ]),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
          Text('Every owner of an asset is a vendor (Own = Rachana Construction Limited). Fill the details once; assets are linked by the Vendor name.', style: const TextStyle(fontSize: 13, color: C.muted, height: 1.35)),
          const SizedBox(height: 10),
          TextField(key: const Key('v-search'), controller: qc, onChanged: (v) => setState(() => q = v), decoration: InputDecoration(hintText: tr('Vendor, GST, PAN'), prefixIcon: const Icon(Icons.search_rounded), contentPadding: const EdgeInsets.symmetric(vertical: 12))),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            for (final x in const [('', 'All'), ('missing', 'Not filled / incomplete'), ('done', 'Complete')]) ChoiceChip(key: Key('vf-${x.$1.isEmpty ? 'all' : x.$1}'), selected: st == x.$1, onSelected: (_) => setState(() => st = x.$1), label: Text(x.$2)),
          ]),
          const SizedBox(height: 4),
          Wrap(spacing: 8, children: [
            for (final x in const [('', 'All'), ('bill', 'Machinery & billing'), ('mat', 'Material suppliers (Store)')]) ChoiceChip(key: Key('vt-${x.$1.isEmpty ? 'all' : x.$1}'), selected: ty == x.$1, onSelected: (_) => setState(() => ty = x.$1), label: Text(x.$2)),
          ]),
          const SizedBox(height: 6),
          Text('Vendors: ${list.length} · details complete: ${all.where((v) => v['complete'] == true).length} of ${all.length}${nMat > 0 ? ' · material suppliers: $nMat' : ''}', key: const Key('v-sum'), style: const TextStyle(fontSize: 13, color: C.muted)),
          if (unsaved.isNotEmpty && can)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: OutlinedButton.icon(key: const Key('v-mkall'), onPressed: busy.isEmpty ? () => _mkAll(unsaved) : null, icon: const Icon(Icons.group_add_rounded), label: Text('Save all ${unsaved.length} owners as vendors')),
            ),
          if (err.isNotEmpty) InfoLine(err, bad: true),
          const SizedBox(height: 10),
          if (loading && all.isEmpty)
            ...List.generate(3, (_) => const Padding(padding: EdgeInsets.only(bottom: 10), child: Shimmer(height: 120)))
          else if (list.isEmpty)
            EmptyState('No vendors yet – press "+ New vendor".', '', pic: 'office_building')
          else
            for (final v in list) Padding(padding: const EdgeInsets.only(bottom: 10), child: _card(v, can)),
        ]),
      ),
    );
  }

  Widget _card(Map<String, dynamic> v, bool can) {
    final ms = machinesOfVendor(v), stt = vendorState(v), name = '${v['name']}';
    final gst = '${v['gst'] ?? ''}'.isNotEmpty ? '${v['gst']}' : (v['saved'] == true && v['gstReg'] != 'Yes' ? 'Not registered' : '–');
    return Press(
      key: Key('v-$name'),
      onTap: () => _open(v),
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(name, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800))),
          Pill(stt.$1, color: toneOf(stt.$2), bg: softOf(stt.$2)),
        ]),
        if (v['type'] == kMatSup) Padding(padding: const EdgeInsets.only(top: 4), child: Pill('Material Supplier', key: Key('vms-$name'), color: C.slate, bg: C.slateSoft)),
        if ('${v['ownership'] ?? ''}'.isNotEmpty) Text('${v['ownership']}', style: const TextStyle(fontSize: 13, color: C.muted)),
        const SizedBox(height: 6),
        Text('${ms.length} asset${ms.length == 1 ? '' : 's'}${ms.isEmpty ? '' : ': ${ms.take(3).map((m) => m['id']).join(', ')}${ms.length > 3 ? '…' : ''}'}', style: const TextStyle(fontSize: 13.5)),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [
          Pill('Mobile: ${'${v['phone'] ?? ''}'.isEmpty ? '–' : v['phone']}', color: C.slate, bg: C.slateSoft),
          Pill('GST: $gst', color: C.slate, bg: C.slateSoft),
          Pill('PAN: ${'${v['pan'] ?? ''}'.isEmpty ? '–' : v['pan']}', color: C.slate, bg: C.slateSoft),
          Pill('Bank: ${bankText(v)}', color: C.slate, bg: C.slateSoft),
          Pill('BOQs: ${v['boqs'] ?? 0}', color: C.blue, bg: C.blueSoft),
        ]),
        if (vendorDocCount(v) > 0)      // (3.59.0) its documents – to see, print, download
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: TextButton.icon(key: Key('vdocs-$name'), onPressed: () => openVendorDocs(context, name), icon: const Icon(Icons.attach_file_rounded, size: 18), label: Text('Documents (${vendorDocCount(v)})')),
          ),
        if (can) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 4, children: [
            TextButton.icon(key: Key('ve-$name'), onPressed: () => _open(v), icon: const Icon(Icons.edit_rounded, size: 18), label: Text(v['saved'] == true ? 'Edit' : 'Fill details')),
            TextButton.icon(key: Key('vb-$name'), onPressed: () => _boq(v), icon: const Icon(Icons.description_outlined, size: 18), label: Text((v['boqs'] ?? 0) == 0 ? 'Make BOQ' : 'BOQs')),
            if (v['saved'] == true) TextButton.icon(key: Key('vd-$name'), style: TextButton.styleFrom(foregroundColor: C.red), onPressed: () => _delete(v), icon: const Icon(Icons.delete_outline_rounded, size: 18), label: Text('Delete')),
          ]),
        ],
      ]),
    );
  }

  Future<void> _boq(Map<String, dynamic> v) async {
    await openBoq(context, vendor: '${v['name']}', newIfNone: true);
    if (mounted) _load(quiet: true);
  }

  Future<void> _open(Map<String, dynamic>? v) async {
    final s = SessionScope.read(context);
    if (v != null && !s.canEdit('Vendor Master')) {
      await _view(v);
      return;
    }
    final res = await Navigator.of(context).push<dynamic>(MaterialPageRoute(builder: (_) => VendorFormScreen(vendor: v, typeOn: all.any((x) => x['type'] == kMatSup), docsOn: docsOn)));
    if (res is List && mounted) setState(() => _take(res));
    if (mounted) _load(quiet: true);
  }

  Future<void> _view(Map<String, dynamic> v) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (c) => SizedBox(
          height: MediaQuery.of(c).size.height * .8,
          child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('${v['name']}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            for (final x in [
              ('Owner Name', v['owner']),      // (3.59.0)
              ('Ownership', v['ownership']), ('Mobile Number', v['phone']), ('Email', v['email']), ('GST registered?', v['gstReg']), ('GST Number', v['gst']), ('PAN Number', v['pan']),
              ('Bank Name', v['bank']), ('Branch', v['branch']), ('Account Number', bankText(v) == '–' ? '' : bankText(v)), ('IFSC Code', v['ifsc']), ('Address', v['address']), ('Remark', v['remark']),
              if (v['type'] == kMatSup) ('Vendor type', 'Material Supplier (Store)'),
            ])
              InfoRow(x.$1, '${x.$2 ?? ''}'),
            if (vendorDocCount(v) > 0) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(key: const Key('vview-docs'), onPressed: () => openVendorDocs(c, '${v['name']}'), icon: const Icon(Icons.attach_file_rounded), label: Text('Documents (${vendorDocCount(v)})')),
            ],
            const SizedBox(height: 8),
            FormHead('Assets'),
            Text(machinesOfVendor(v).isEmpty ? 'No assets yet – in Asset Master pick this vendor for its machinery.' : machinesOfVendor(v).map((m) => '${m['id']} (${m['ownership']})').join(', ')),
          ])),
        ),
      );

  Future<void> _mkAll(List<String> names) async {
    final s = SessionScope.read(context);
    if (!await askLines(context, 'Save ${names.length} owners as vendors?', names, note: 'Name only – fill GST / PAN / bank later with Edit.', yes: 'Save all')) return;
    setState(() => busy = 'mk');
    try {
      final res = (await s.api.call('vendorsFromOwners', [names], true) as Map).cast<String, dynamic>();
      if (!mounted) return;
      setState(() => _take(res['vendors']));
      toast(context, '${res['count']} vendors saved.');
    } catch (e) {
      if (mounted) toast(context, tr(errText(e)), bad: true);
    } finally {
      if (mounted) setState(() => busy = '');
    }
  }

  Future<void> _delete(Map<String, dynamic> v) async {
    final s = SessionScope.read(context);
    if (!await ask(context, 'Delete vendor ${v['name']}?', 'A vendor that still has assets in Asset Master, or BOQs, cannot be deleted – give the assets another vendor / delete the BOQs first.', yes: 'Delete', danger: true)) return;
    try {
      await s.api.call('deleteVendor', ['${v['name']}', '${v['ver'] ?? ''}'], true); // (update-156) the version shown
      if (!mounted) return;
      toast(context, 'Vendor details deleted.');
      _load(quiet: true);
    } catch (e) {
      if (mounted) toast(context, tr(errText(e)), bad: true);
    }
  }
}

/* ---------------- the form ---------------- */
class VendorFormScreen extends StatefulWidget {
  const VendorFormScreen({super.key, this.vendor, this.typeOn = false, this.docsOn = false});
  final Map<String, dynamic>? vendor;

  /// (3.59.0) this site keeps the Owner Name and the documents (step 1zj)
  final bool docsOn;

  /// (3.57.0) this site keeps a vendor's type (a material supplier is there): the type is in the form
  final bool typeOn;
  @override
  State<VendorFormScreen> createState() => _VendorFormScreenState();
}

class _VendorFormScreenState extends State<VendorFormScreen> {
  static const keys = ['name', 'owner', 'phone', 'email', 'aadhaar', 'gst', 'pan', 'bank', 'branch', 'account', 'ifsc', 'address', 'remark'];
  /// (3.59.0) its documents by kind (a file kept before: its record; one added here: its bytes, sent with "Save vendor")
  late final docs = <String, List<AttFile>>{
    for (final k in kVendorDocKinds) k.$1: [for (final x in (widget.vendor?['docs'] as List? ?? const []).whereType<Map>()) if (vendorDocKindOf(x['kind']) == k.$1 && '${x['sha'] ?? ''}'.isNotEmpty) AttFile.kept(x)],
  };
  bool get ownerShown => widget.docsOn || '${widget.vendor?['owner'] ?? ''}'.isNotEmpty;
  late final t = <String, TextEditingController>{for (final k in keys) k: TextEditingController(text: '${widget.vendor?[k] ?? ''}')};
  late String gstReg = widget.vendor?['gstReg'] == 'Yes' ? 'Yes' : 'No';
  late String vtype = widget.vendor?['type'] == kMatSup ? kMatSup : '';
  bool get typeShown => widget.typeOn || widget.vendor?['type'] == kMatSup;
  String gstHint = '', ifscHint = '';
  bool gstBad = false, ifscBad = false, panAuto = false, bankAuto = false, busy = false;
  String err = '', ifscAsked = '';
  int _ifscSeq = 0;

  Map<String, dynamic>? get v => widget.vendor;
  bool get isNew => v == null;
  bool get saved => v?['saved'] == true;

  @override
  void initState() {
    super.initState();
    if (saved && docs.values.any((l) => l.isNotEmpty)) WidgetsBinding.instance.addPostFrameCallback((_) => _links());
  }

  /// (3.59.0) the kept documents' links (for View) – as the web's form asks getVendorDocs
  Future<void> _links() async {
    try {
      final r = (await SessionScope.read(context).api.call('getVendorDocs', ['${v!['name']}']) as Map).cast<String, dynamic>();
      if (!mounted) return;
      final by = {for (final x in (r['docs'] as List? ?? const []).whereType<Map>()) '${x['sha']}': x};
      setState(() {
        for (final l in docs.values) {
          for (final f in l) {
            final x = by[f.sha];
            if (x != null && f.bytes == null) {
              f.url = '${x['url'] ?? ''}';
              f.p = '${x['p'] ?? f.p}';
            }
          }
        }
      });
    } catch (_) {/* View then says it could not open them */}
  }

  @override
  void dispose() {
    for (final c in t.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// (3.59.0) one kind's documents changed: the attachments' box of that kind (camera, gallery, PDF; a photo corrected) – up to 10
  Future<void> _docKind(String kind) async {
    final got = await Navigator.of(context).push<List<AttFile>>(MaterialPageRoute(builder: (_) => _DocKindScreen(title: vendorDocKind(kind), sub: t['name']!.text.trim().isEmpty ? 'New vendor' : t['name']!.text.trim(), files: [...docs[kind]!])));
    if (got != null && mounted) setState(() => docs[kind] = got);
  }

  Widget _docRow(String kind, String label, bool can) {
    final l = docs[kind]!, n = l.length;
    return Container(
      key: Key('vfd-$kind'),
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.line)),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          Text(n > 0 ? '$n file(s)' : 'none', key: Key('vfd-n-$kind'), style: const TextStyle(fontSize: 12.5, color: C.muted)),
        ])),
        if (n > 0) TextButton(key: Key('vfd-v-$kind'), onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => AttViewer(files: l, title: label))), child: Text('View')),
        if (widget.docsOn && can) TextButton(key: Key('vfd-a-$kind'), onPressed: busy ? null : () => _docKind(kind), child: Text(n > 0 ? 'Add / change' : 'Add')),
      ]),
    );
  }

  void _gst() {
    final r = gstRead(t['gst']!.text);
    if (r == null) {
      setState(() {
        gstHint = t['gst']!.text.trim().isEmpty ? '' : 'Type all 15 characters';
        gstBad = false;
      });
      return;
    }
    if (r.bad.isNotEmpty) {
      setState(() {
        gstHint = r.bad;
        gstBad = true;
      });
      return;
    }
    if (t['gst']!.text != r.gst) t['gst']!.text = r.gst;
    var filled = false;
    if (t['pan']!.text.trim().isEmpty || panAuto) {
      t['pan']!.text = r.pan;
      panAuto = true;
      filled = true;
    }
    final differs = t['pan']!.text.trim().toUpperCase() != r.pan;
    setState(() {
      gstHint = '✔ ${r.state} (${r.code})${r.kind.isNotEmpty ? ' · ${r.kind}' : ''}${filled ? ' · PAN ${r.pan} filled in' : differs ? ' · the PAN typed (${t['pan']!.text.trim().toUpperCase()}) is not the PAN of this GST number (${r.pan})' : ''}';
      gstBad = differs;
    });
  }

  Future<void> _ifsc() async {
    final code = t['ifsc']!.text.toUpperCase().replaceAll(RegExp(r'\s'), '');
    if (code.isNotEmpty && code == ifscAsked) return;
    final seq = ++_ifscSeq;
    ifscAsked = '';
    void hint(String h, [bool bad = false]) => setState(() {
          ifscHint = h;
          ifscBad = bad;
        });
    if (code.isEmpty) {
      hint('');
      return;
    }
    if (code.length != 11) {
      hint('Type all 11 characters');
      return;
    }
    if (!RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$').hasMatch(code)) {
      hint('IFSC "$code" is not in the right format (4 letters, 0, 6 characters).', true);
      return;
    }
    if (t['ifsc']!.text != code) t['ifsc']!.text = code;
    ifscAsked = code;
    hint('Looking up the bank…');
    final d = await SessionScope.read(context).api.ifsc(code);
    if (!mounted || seq != _ifscSeq) return;
    if (d != null && '${d['BANK'] ?? ''}'.isNotEmpty) {
      t['bank']!.text = '${d['BANK']}'.trim();
      t['branch']!.text = '${d['BRANCH'] ?? ''}'.trim();
      bankAuto = true;
      hint('✔ ${t['bank']!.text} – ${t['branch']!.text}${[d['CITY'], d['STATE']].where((x) => '${x ?? ''}'.isNotEmpty).map((x) => ', $x').join()} · bank and branch filled in');
    } else if (d?['missing'] == true) {
      hint('This IFSC is not in the list of bank branches – check it against the cheque / passbook.', true);
    } else {
      hint('The bank could not be looked up now (no connection to the IFSC list) – type the bank and branch.');
    }
  }

  Future<void> _save() async {
    final s = SessionScope.read(context);
    String g(String k) => t[k]!.text.trim();
    final was = !isNew ? '${v!['name'] ?? ''}' : '', renaming = was.isNotEmpty && g('name') != was;
    if (renaming) {
      if (g('name').isEmpty) {
        setState(() => err = "Enter the Company Name (the vendor's name).");
        return;
      }
      final nA = machinesOfVendor(v!).length;
      if (!await askLines(context, 'Rename this vendor?', ['$was → ${g('name')}', 'Everything of this vendor follows to the new name: ${nA > 0 ? '$nA asset(s) in Asset Master, ' : ''}its BOQs, bills, payments, debit notes, and the owner / "Debit to" on Log Book entries and diesel issues.'],
          note: 'Bills and debit notes already submitted keep the name printed on their papers; they stay in this vendor\'s ledger.', yes: 'Rename')) {
        return;
      }
    }
    setState(() {
      busy = true;
      err = '';
    });
    try {
      // (3.59.0) the documents added here sent first (vendorDoc – kept once in the private store), then saved with the vendor
      if (widget.docsOn) {
        final bad = await attSendAll(s.api, [for (final l in docs.values) ...l], () { if (mounted) setState(() {}); }, action: 'vendorDoc');
        if (bad.isNotEmpty) {
          if (mounted) setState(() => err = bad);
          return;
        }
      }
      final body = {
        'oldName': renaming ? was : '', 'name': g('name'), 'gstReg': gstReg, 'gst': g('gst'), 'gstPct': '${v?['gstPct'] ?? ''}', 'pan': g('pan'), 'tds': '${v?['tds'] ?? ''}', 'bank': g('bank'),
        'branch': g('branch'), 'account': g('account'), 'ifsc': g('ifsc'), 'phone': g('phone'), 'address': g('address'), 'remark': g('remark'), 'aadhaar': g('aadhaar'), 'email': g('email'),
        if (typeShown) 'type': vtype, // (3.57.0) only when shown – the server keeps it as it is otherwise
        // (3.59.0) the Owner Name and the documents – only where the site keeps them (the server keeps them as they are otherwise)
        if (widget.docsOn) ...{'owner': g('owner'), 'docs': [for (final k in kVendorDocKinds) for (final f in docs[k.$1]!) {'sha': f.sha, 'kind': k.$1}]},
      };
      if (saved) body['ver'] = '${v?['ver'] ?? ''}'; // (update-156) the version it had when it was opened
      final res = (await s.api.call('saveVendor', [body, saved ? 'edit' : 'add'], true) as Map).cast<String, dynamic>();
      if (!mounted) return;
      final r = res['renamed'];
      HapticFeedback.lightImpact();
      toast(context, r is Map ? 'Vendor renamed: ${r['from']} → ${r['to']}${'${r['text'] ?? ''}'.isNotEmpty ? ' (${r['text']} moved with it)' : ''}' : 'Vendor saved: ${res['name']}');
      if (r is Map) {
        try {
          await s.loadInit(); // the machinery now has the new name as its vendor
          s.setMaster([for (final m in s.machines) m.m]);
        } catch (_) {/* the live sync brings it */}
      }
      if (mounted) Navigator.of(context).pop(res['vendors']);
    } catch (e) {
      if (mounted) setState(() => err = errText(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ms = v == null ? const <Map<String, dynamic>>[] : machinesOfVendor(v!), can = SessionScope.of(context).canEdit('Vendor Master');
    Widget gap() => const SizedBox(height: 10);
    Widget hint(String h, bool bad) {
      if (h.isEmpty) return const SizedBox.shrink();
      final ok = h.startsWith('✔ ');
      return Padding(
        padding: const EdgeInsets.fromLTRB(6, 4, 6, 0),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (ok) const Padding(padding: EdgeInsets.only(right: 4, top: 1), child: Icon(Icons.check_circle_rounded, size: 16, color: C.greenDark)),
          Expanded(child: Text(ok ? h.substring(2) : h, style: TextStyle(fontSize: 12.5, color: bad ? C.red : C.greenDark, height: 1.3))),
        ]),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(isNew ? 'New vendor' : '${saved ? 'Vendor details – ' : 'Fill vendor details – '}${v!['name']}', maxLines: 1, overflow: TextOverflow.ellipsis), actions: withAsk([const GuideButton('vendors')])),
      body: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 28), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(ms.isNotEmpty ? '${ms.length} asset(s): ${ms.map((m) => '${m['id']} (${m['ownership']})').join(', ')}' : 'No assets yet – in Asset Master pick this vendor for its machinery.', style: const TextStyle(fontSize: 13, color: C.muted, height: 1.35)),
        const SizedBox(height: 12),
        // (3.59.0, Mechanical update-184, "vendor name tr tith company name as banaw ani ajun ek fild kr owner name")
        TextBox(key: const Key('vf-name'), label: 'Company Name *', controller: t['name']!, hint: "the vendor's company / firm name"),
        if (!isNew) Padding(padding: const EdgeInsets.fromLTRB(6, 4, 6, 0), child: Text('Changing the name renames this vendor everywhere: its assets, BOQs, bills, payments, debit notes and Log Book entries follow to the new name.', style: const TextStyle(fontSize: 12, color: C.faint))),
        gap(),
        if (ownerShown) ...[
          TextBox(key: const Key('vf-owner'), label: 'Owner Name', controller: t['owner']!, enabled: widget.docsOn),
          gap(),
        ],
        TextBox(key: const Key('vf-phone'), label: 'Mobile Number', controller: t['phone']!, kb: TextInputType.phone),
        gap(),
        TextBox(key: const Key('vf-email'), label: 'Email', controller: t['email']!, kb: TextInputType.emailAddress),
        gap(),
        TextBox(key: const Key('vf-aadhaar'), label: 'Aadhaar Number', controller: t['aadhaar']!, kb: TextInputType.number, hint: '12 digits'),
        gap(),
        PickField(key: const Key('vf-gstreg'), label: 'GST registered?', value: gstReg, items: const ['No', 'Yes'], onChanged: (x) => setState(() => gstReg = x)),
        if (gstReg == 'Yes') ...[
          gap(),
          TextBox(key: const Key('vf-gst'), label: 'GST Number', controller: t['gst']!, upper: true, hint: '27ABCDE1234F1Z5', onChanged: (x) {
            if (x.replaceAll(RegExp(r'\s'), '').length >= 15) {
              _gst();
            } else if (gstHint.isNotEmpty) {
              setState(() => gstHint = '');
            }
          }),
          hint(gstHint, gstBad),
        ],
        gap(),
        TextBox(key: const Key('vf-pan'), label: 'PAN Number', controller: t['pan']!, upper: true, hint: 'ABCDE1234F', onChanged: (_) => panAuto = false),
        gap(),
        TextBox(key: const Key('vf-ifsc'), label: 'IFSC Code', controller: t['ifsc']!, upper: true, hint: 'SBIN0001234', onChanged: (x) {
          if (x.replaceAll(RegExp(r'\s'), '').length >= 11) {
            _ifsc();
          } else if (ifscHint.isNotEmpty) {
            setState(() => ifscHint = '');
          }
        }),
        hint(ifscHint, ifscBad),
        gap(),
        TextBox(key: const Key('vf-bank'), label: 'Bank Name', controller: t['bank']!, onChanged: (_) => bankAuto = false),
        gap(),
        TextBox(key: const Key('vf-branch'), label: 'Branch', controller: t['branch']!, onChanged: (_) => bankAuto = false),
        gap(),
        TextBox(key: const Key('vf-account'), label: 'Account Number', controller: t['account']!, kb: TextInputType.number),
        gap(),
        TextBox(key: const Key('vf-address'), label: 'Address', controller: t['address']!, maxLines: 2),
        gap(),
        TextBox(key: const Key('vf-remark'), label: 'Remark', controller: t['remark']!),
        if (typeShown) ...[
          gap(),
          PickField(key: const Key('vf-type'), label: 'Vendor type', value: vtype, blank: 'Machinery / billing vendor', items: const [kMatSup], labels: const {kMatSup: 'Material Supplier (Store)'}, onChanged: (x) => setState(() => vtype = x)),
        ],
        // (3.59.0) the documents: a row a kind – its files, View, Add / change; kept when "Save vendor" is pressed
        FormHead('Documents', sub: '(PDF or photo – seen, printed and downloaded from the vendor at any time; kept when you press Save vendor)'),
        if (!widget.docsOn)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('The Owner Name and the documents cannot be kept yet at this site – the Admin runs sql/supabase_step1zj_vendor_papers.sql once in Supabase → SQL Editor (in every site).', key: const Key('vf-docs-note'), style: const TextStyle(fontSize: 12.5, color: C.muted, height: 1.35)),
          ),
        for (final k in kVendorDocKinds) _docRow(k.$1, k.$2, can),
        if (err.isNotEmpty) InfoLine(err, bad: true),
        const SizedBox(height: 16),
        FilledButton(key: const Key('vf-save'), onPressed: busy ? null : _save, child: Text(busy ? 'Saving…' : 'Save vendor')),
      ])),
    );
  }
}

/// a document's kind as the server keeps it (an unknown one: Other)
String vendorDocKindOf(Object? k) => kVendorDocKinds.any((x) => x.$1 == '$k') ? '$k' : 'Other';

/// (3.59.0) one kind of a vendor's documents: its files (camera, gallery, PDF – a photo corrected; × takes a file out), up to 10 – the
/// web's attachments' box of that kind; Done brings them back to the form (they are kept when the vendor is saved)
class _DocKindScreen extends StatefulWidget {
  const _DocKindScreen({required this.title, required this.sub, required this.files});
  final String title, sub;
  final List<AttFile> files;
  @override
  State<_DocKindScreen> createState() => _DocKindScreenState();
}

class _DocKindScreenState extends State<_DocKindScreen> {
  late final files = widget.files;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text('${widget.title} – ${widget.sub}', maxLines: 1, overflow: TextOverflow.ellipsis)),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
            child: FilledButton.icon(key: const Key('vfk-done'), style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)), onPressed: () => Navigator.pop(context, files), icon: const Icon(Icons.check_rounded), label: Text('Done')),
          ),
        ),
        body: ListView(padding: const EdgeInsets.fromLTRB(16, 10, 16, 20), children: [
          Text('A PDF or a photo – up to 10. They are kept when you press Save vendor.', style: const TextStyle(fontSize: 12.5, color: C.muted, height: 1.35)),
          const SizedBox(height: 10),
          AttachStrip(files: files, max: 10, onChanged: () => setState(() {})),
        ]),
      );
}

/// (3.59.0) A VENDOR'S DOCUMENTS – the web's 📎 window: the Owner Name; each kind with its files; each file Open, Print (a photo: the
/// phone's printing; a PDF: opened in the phone's PDF reader, printed there – as the web opens it in a tab), Download (saved / shared).
/// The links work for 15 minutes (getVendorDocs – the same action and access as the web).
class VendorDocsScreen extends StatefulWidget {
  const VendorDocsScreen({super.key, required this.name});
  final String name;
  @override
  State<VendorDocsScreen> createState() => _VendorDocsScreenState();
}

class _VendorDocsScreenState extends State<VendorDocsScreen> {
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
      final r = (await SessionScope.read(context).api.call('getVendorDocs', [widget.name]) as Map).cast<String, dynamic>();
      if (mounted) setState(() => d = r);
    } catch (e) {
      if (mounted) setState(() => err = errText(e));
    }
  }

  Future<void> _do(String what, Map x) async {
    final s = SessionScope.read(context), url = '${x['url'] ?? ''}', pdf = x['mime'] == 'application/pdf';
    final name = '${x['name'] ?? ''}'.isNotEmpty ? '${x['name']}' : '${x['kind']}${pdf ? '.pdf' : '.jpg'}';
    if (what == 'open' && !pdf) {
      await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => AttViewer(files: [AttFile.kept(x)], title: '${vendorDocKind(x['kind'])} – ${d?['name'] ?? widget.name}')));
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
    final dd = d, list = [for (final x in (dd?['docs'] as List? ?? const []).whereType<Map>()) x];
    return Scaffold(
      appBar: AppBar(title: Text('Documents – ${dd?['name'] ?? widget.name}', maxLines: 1, overflow: TextOverflow.ellipsis), actions: [IconButton(tooltip: tr('Refresh'), onPressed: _load, icon: const Icon(Icons.refresh_rounded))]),
      body: ListView(key: const Key('vdv-list'), padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
        if (err.isNotEmpty) InfoLine(err, bad: true),
        if (dd == null && err.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
        if (dd != null) ...[
          if ('${dd['owner'] ?? ''}'.isNotEmpty) InfoRow('Owner Name', '${dd['owner']}', bold: true),
          if (list.isEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: Text('No document of this vendor yet – open it with Edit and add them.', style: const TextStyle(color: C.muted))),
          for (final k in kVendorDocKinds)
            if (list.any((x) => vendorDocKindOf(x['kind']) == k.$1)) ...[
              FormHead(k.$2),
              for (final x in list.where((x) => vendorDocKindOf(x['kind']) == k.$1)) _file(x),
            ],
          const SizedBox(height: 12),
          Text('The links work for 15 minutes – open this again after that.', style: const TextStyle(fontSize: 12.5, color: C.muted)),
        ],
      ]),
    );
  }

  Widget _file(Map x) {
    final pdf = x['mime'] == 'application/pdf', sha = '${x['sha']}', at = '${x['at'] ?? ''}';
    Widget act(String what, String label, IconData i) => TextButton.icon(
          key: Key('vdv-$what-$sha'),
          onPressed: busy.isNotEmpty || '${x['url'] ?? ''}'.isEmpty ? null : () => _do(what, x),
          icon: busy == '$sha$what' ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(i, size: 18),
          label: Text(label),
        );
    return Container(
      key: Key('vdv-$sha'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 4),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.line)),
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
