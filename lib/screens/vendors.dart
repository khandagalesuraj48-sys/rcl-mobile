/* VENDOR MASTER – the app's own screens (3.4.0), the same as the web's Vendors page: every owner of an asset is a vendor (Own =
 * Rachana Construction Limited); the list (search Vendor / GST / PAN, Details: not filled / complete), "+ New vendor", "Save all
 * owners as vendors", each vendor's assets, mobile, GST, PAN, bank, BOQs and how complete its details are; the form (Vendor Name –
 * a rename moves everything of the vendor, asked first –, Mobile, Email, Aadhaar, GST registered / GST Number – its check letter,
 * State and the PAN inside it –, PAN, Bank, Branch, Account, IFSC – the bank and branch looked up –, Address, Remark), Delete
 * details. Server: getVendors, saveVendor, deleteVendor, vendorsFromOwners.
 * (3.57.0, Mechanical update-181) a Material Supplier (made by the Store's import of its old inward register): marked by its name, the
 * Type filter (All / Machinery & billing / Material suppliers (Store)), the count; its type in the form – where this site keeps it. */
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';

import '../core/masters.dart';
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
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        err = errText(e);
      });
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
    final res = await Navigator.of(context).push<dynamic>(MaterialPageRoute(builder: (_) => VendorFormScreen(vendor: v, typeOn: all.any((x) => x['type'] == kMatSup))));
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
              ('Ownership', v['ownership']), ('Mobile Number', v['phone']), ('Email', v['email']), ('GST registered?', v['gstReg']), ('GST Number', v['gst']), ('PAN Number', v['pan']),
              ('Bank Name', v['bank']), ('Branch', v['branch']), ('Account Number', bankText(v) == '–' ? '' : bankText(v)), ('IFSC Code', v['ifsc']), ('Address', v['address']), ('Remark', v['remark']),
              if (v['type'] == kMatSup) ('Vendor type', 'Material Supplier (Store)'),
            ])
              InfoRow(x.$1, '${x.$2 ?? ''}'),
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
  const VendorFormScreen({super.key, this.vendor, this.typeOn = false});
  final Map<String, dynamic>? vendor;

  /// (3.57.0) this site keeps a vendor's type (a material supplier is there): the type is in the form
  final bool typeOn;
  @override
  State<VendorFormScreen> createState() => _VendorFormScreenState();
}

class _VendorFormScreenState extends State<VendorFormScreen> {
  static const keys = ['name', 'phone', 'email', 'aadhaar', 'gst', 'pan', 'bank', 'branch', 'account', 'ifsc', 'address', 'remark'];
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
  void dispose() {
    for (final c in t.values) {
      c.dispose();
    }
    super.dispose();
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
        setState(() => err = 'Enter the Vendor Name.');
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
      final body = {
        'oldName': renaming ? was : '', 'name': g('name'), 'gstReg': gstReg, 'gst': g('gst'), 'gstPct': '${v?['gstPct'] ?? ''}', 'pan': g('pan'), 'tds': '${v?['tds'] ?? ''}', 'bank': g('bank'),
        'branch': g('branch'), 'account': g('account'), 'ifsc': g('ifsc'), 'phone': g('phone'), 'address': g('address'), 'remark': g('remark'), 'aadhaar': g('aadhaar'), 'email': g('email'),
        if (typeShown) 'type': vtype, // (3.57.0) only when shown – the server keeps it as it is otherwise
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
    final ms = v == null ? const <Map<String, dynamic>>[] : machinesOfVendor(v!);
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
        TextBox(key: const Key('vf-name'), label: 'Vendor Name *', controller: t['name']!),
        if (!isNew) Padding(padding: const EdgeInsets.fromLTRB(6, 4, 6, 0), child: Text('Changing the name renames this vendor everywhere: its assets, BOQs, bills, payments, debit notes and Log Book entries follow to the new name.', style: const TextStyle(fontSize: 12, color: C.faint))),
        gap(),
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
        if (err.isNotEmpty) InfoLine(err, bad: true),
        const SizedBox(height: 16),
        FilledButton(key: const Key('vf-save'), onPressed: busy ? null : _save, child: Text(busy ? 'Saving…' : 'Save vendor')),
      ])),
    );
  }
}
