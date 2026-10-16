/* ASSET MASTER – the app's own screens (3.4.0, part 3 of "the whole web in the app"). The same list, filters and actions as the
 * web's Asset Master, the same server actions (saveMaster, saveMasterBulk, deleteMaster, editMasterMany, deleteMasterMany,
 * assignVendors, vendorsFromOwners, exportMaster) – the server checks and saves everything:
 *   – the list: search, Ownership / Type / Unit / Owner / Diesel Supply / Status, "on site" dates (at first: today), the vendor
 *     chips (all / not assigned / assigned), each machinery with its works, standards, vendor, status (and earlier periods),
 *     papers and who entered it;
 *   – one machinery: its details, Edit, Delete (it has entries: asked again);
 *   – several ticked: Assign vendor, Edit selected (a shared value filled in), Delete selected;
 *   – Add machinery, Add multiple machinery, Export to Excel, Print list, Asset list (date / month / period) – print. */
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';

import '../core/assets.dart';
import '../core/format.dart';
import '../core/imports.dart' show onSiteOn;
import '../core/lb_io.dart' show localeCmp;
import '../core/more_imports.dart' show masterImportRows, qrLabelsHtml, qrPrintHtml;
import '../core/session.dart';
import '../core/sheet_read.dart' show readSheets, SheetError;
import '../ui/fields.dart';
import '../ui/outputs.dart';
import '../ui/pick_file.dart';
import '../web/print_view.dart';
import '../ui/scope.dart';
import '../ui/t.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'forms.dart' show MachinePicker;
import 'machine_form.dart';
import '../ui/help.dart' show GuideButton;

Future<void> openAssetMaster(BuildContext context) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const AssetMasterScreen()));

/// The names of Vendor Master (the Vendor box of a machinery and "Assign vendor" pick from them).
Future<List<String>> vendorNames(Session s) async {
  try {
    final r = await s.api.call('getVendors');
    return {for (final v in (r as List? ?? const []).whereType<Map>()) '${v['name'] ?? ''}'}.where((n) => n.isNotEmpty).toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  } catch (_) {
    return [];
  }
}

List<String> uniqOf(Iterable<Machine> ms, String key) => {for (final m in ms) '${m.m[key] ?? ''}'.trim()}.where((x) => x.isNotEmpty).toList()..sort();

class AssetMasterScreen extends StatefulWidget {
  const AssetMasterScreen({super.key, this.find = ''});

  /// (3.14.0) opened by the search with this text in the search box (the web's gsMaster)
  final String find;
  @override
  State<AssetMasterScreen> createState() => _AssetMasterScreenState();
}

class _AssetMasterScreenState extends State<AssetMasterScreen> {
  final f = AssetFilter();
  final sel = <String>{};
  final q = TextEditingController();
  List<String> vendors = [];
  String busy = '';
  Session? _ls;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final s = SessionScope.read(context);
      _ls = s..dataTick.addListener(_live);
      setState(() {
        f.from = f.to = s.today; // (update-115, as the web) at first: the machinery on site today
        if (widget.find.isNotEmpty) {
          q.text = widget.find;
          f.q = widget.find;
        }
      });
      final v = await vendorNames(s);
      if (mounted) setState(() => vendors = v);
    });
  }

  @override
  void dispose() {
    _ls?.dataTick.removeListener(_live);
    q.dispose();
    super.dispose();
  }

  void _live() {
    if (mounted) setState(() {});
  }

  Future<void> _run(String key, Future<void> Function() job) async {
    if (busy.isNotEmpty) return;
    setState(() => busy = key);
    try {
      await job();
    } catch (e) {
      if (mounted) toast(context, tr(errText(e)), bad: true);
    } finally {
      if (mounted) setState(() => busy = '');
    }
  }

  List<Map<String, dynamic>> _all(Session s) => [for (final m in s.machines) m.m]..sort((a, b) => '${a['id']}'.toLowerCase().compareTo('${b['id']}'.toLowerCase()));

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    final all = _all(s);
    final base = all.where((m) => f.test(m, noVc: true)).toList();
    final rows = base.where((m) => f.vc.isEmpty || (f.vc == 'done' ? vendorAssigned(m) : !vendorAssigned(m))).toList();
    final can = s.canEdit('Master');
    final done = base.where(vendorAssigned).length;
    final miss = ownersNotVendors(base);
    sel.removeWhere((id) => !all.any((m) => m['id'] == id));
    return Scaffold(
      appBar: AppBar(
        title: const TwoLang('Asset Master', 'ॲसेट मास्टर', size: 20, weight: FontWeight.w700),
        actions: [const GuideButton('master'), 
          if (can) IconButton(key: const Key('m-add'), tooltip: tr('Add machinery'), onPressed: () => _form(null), icon: const Icon(Icons.add_circle_outline_rounded)),
          PopupMenuButton<String>(
            key: const Key('m-menu'),
            onSelected: _menu,
            itemBuilder: (_) => [
              if (can) PopupMenuItem(value: 'many', child: Text('Add multiple machinery')),
              if (can) PopupMenuItem(key: const Key('m-import'), value: 'import', child: Text('Import from Excel')),
              PopupMenuItem(value: 'xlsx', child: Text('Export to Excel')),
              PopupMenuItem(value: 'print', child: Text('Print list')),
              PopupMenuItem(value: 'alist', child: Text('Asset list (date / month) – print')),
              PopupMenuItem(key: const Key('m-qr'), value: 'qr', child: Text('QR labels')),
            ],
          ),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Row(children: [
            Expanded(
              child: TextField(
                key: const Key('m-search'),
                controller: q,
                onChanged: (v) => setState(() => f.q = v.trim()),
                decoration: InputDecoration(hintText: tr('Number, name, type or owner'), prefixIcon: const Icon(Icons.search_rounded), contentPadding: const EdgeInsets.symmetric(vertical: 12)),
              ),
            ),
            const SizedBox(width: 8),
            Badge(
              isLabelVisible: f.count > 0,
              label: Text('${f.count}'),
              child: IconButton.filledTonal(key: const Key('m-filters'), tooltip: tr('Filters'), onPressed: () => _filters(s), icon: const Icon(Icons.tune_rounded)),
            ),
          ]),
        ),
        SizedBox(
          height: 52,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.fromLTRB(16, 8, 16, 4), children: [
            _chip('', 'All', base.length),
            _chip('none', 'Vendor not assigned', base.length - done, tone: C.amber),
            _chip('done', 'Vendor assigned', done, tone: C.greenDark),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 2, 16, 4),
          child: Row(children: [
            Expanded(child: Text(f.summary(rows.length, all.length), key: const Key('m-sum'), style: const TextStyle(fontSize: 13, color: C.muted))),
            if (f.from.isNotEmpty || f.to.isNotEmpty)
              TextButton(key: const Key('m-alldates'), onPressed: () => setState(() => f.from = f.to = ''), child: Text('All dates')),
          ]),
        ),
        if (miss.isNotEmpty && s.canEdit('Vendor Master'))
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: OutlinedButton.icon(key: const Key('m-mkvend'), onPressed: () => _mkVendors(miss), icon: const Icon(Icons.person_add_alt_rounded), label: Text('Create ${miss.length} vendor${miss.length == 1 ? '' : 's'} from these Owner Names')),
          ),
        Expanded(
          child: rows.isEmpty
              ? ListView(children: [EmptyState(all.isEmpty ? 'No machinery yet.' : 'No machinery matches these filters.', all.isEmpty ? 'Add the first one with +.' : 'Change the filters or the dates.', pic: 'tractor')])
              : ListView.builder(
                  key: const Key('m-list'),
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: rows.length,
                  itemBuilder: (_, i) => Padding(padding: const EdgeInsets.only(bottom: 10), child: _card(s, rows[i], can)),
                ),
        ),
      ]),
      bottomNavigationBar: sel.isEmpty || !can ? null : _selBar(rows),
    );
  }

  Widget _chip(String vc, String label, int n, {Color tone = C.ink}) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          key: Key('vc-${vc.isEmpty ? 'all' : vc}'),
          selected: f.vc == vc,
          onSelected: (_) => setState(() => f.vc = vc),
          label: Row(mainAxisSize: MainAxisSize.min, children: [Text(label), const SizedBox(width: 6), Text('$n', style: TextStyle(fontWeight: FontWeight.w800, color: tone))]),
        ),
      );

  Widget _card(Session s, Map<String, dynamic> m, bool can) {
    final id = '${m['id']}', on = sel.contains(id), ds = docState(m, s.today);
    final inactive = m['status'] == 'Inactive';
    final sub = [if (m['no'] != null && '${m['no']}'.isNotEmpty && '${m['name'] ?? ''}'.isNotEmpty) '${m['name']}', '${m['type'] ?? ''}', '${m['make'] ?? ''}'].where((x) => x.isNotEmpty).join(' · ');
    final std = [if ((asNum(m['kmStd']) ?? 0) > 0) '${fmtNum(asNum(m['kmStd']))} KM/Ltr', if ((asNum(m['hrStd']) ?? 0) > 0) '${fmtNum(asNum(m['hrStd']))} Ltr/Hr', if ((asNum(m['tankCap']) ?? 0) > 0) 'Tank ${fmtNum(asNum(m['tankCap']))} L'];
    final early = earlierText(m);
    return Press(
      key: Key('m-$id'),
      onTap: () {
        if (sel.isNotEmpty && can) {
          HapticFeedback.selectionClick();
          setState(() => on ? sel.remove(id) : sel.add(id));
        } else {
          _details(s, m, can);
        }
      },
      border: on ? C.green : null,
      color: on ? C.greenSoft : Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onLongPress: can
            ? () {
                HapticFeedback.mediumImpact();
                setState(() => on ? sel.remove(id) : sel.add(id));
              }
            : null,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (can)
            SizedBox(
              width: 34,
              height: 34,
              child: Checkbox(key: Key('mt-$id'), value: on, onChanged: (v) => setState(() => v == true ? sel.add(id) : sel.remove(id))),
            ),
          if (can) const SizedBox(width: 6),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text(id, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800)),
                Pill(statusText(m), color: inactive ? C.red : C.greenDark, bg: inactive ? C.redSoft : C.greenSoft),
              ]),
              if (sub.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 3), child: Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5, color: C.muted))),
              if (early.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2), child: Text(early, style: const TextStyle(fontSize: 12, color: C.faint))),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: [
                if (worksOf(m).isNotEmpty) Pill(worksOf(m).join(', '), color: C.blue, bg: C.blueSoft),
                for (final x in std) Pill(x, color: C.slate, bg: C.slateSoft),
                if (ds.given > 0) Pill('Papers: ${ds.text}', color: toneOf(ds.tone), bg: softOf(ds.tone)),
              ]),
              const SizedBox(height: 8),
              Text(
                [if ('${m['owner'] ?? ''}'.isNotEmpty) '${m['owner']}' else 'Vendor not assigned', '${m['ownership'] ?? ''}', '${m['supply'] ?? ''}'].where((x) => x.isNotEmpty).join(' · '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: vendorAssigned(m) ? C.ink : C.amber),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _selBar(List<Map<String, dynamic>> rows) => SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .08), blurRadius: 12, offset: const Offset(0, -4))]),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Expanded(child: Text('${sel.length} selected', key: const Key('m-selcount'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
              TextButton(
                key: const Key('m-selall'),
                onPressed: () => setState(() {
                  final ids = rows.map((m) => '${m['id']}');
                  if (ids.every(sel.contains)) {
                    sel.removeAll(ids);
                  } else {
                    sel.addAll(ids);
                  }
                }),
                child: Text('Select all shown'),
              ),
              TextButton(key: const Key('m-selnone'), onPressed: () => setState(sel.clear), child: Text('Clear selection')),
            ]),
            Row(children: [
              Expanded(child: FilledButton(key: const Key('m-selassign'), style: FilledButton.styleFrom(minimumSize: const Size(0, 48)), onPressed: busy.isEmpty ? _assign : null, child: Text('Assign vendor'))),
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton(key: const Key('m-seledit'), style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)), onPressed: busy.isEmpty ? _editMany : null, child: Text('Edit selected'))),
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton(key: const Key('m-seldel'), style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48), foregroundColor: C.red), onPressed: busy.isEmpty ? _deleteMany : null, child: Text('Delete selected'))),
            ]),
          ]),
        ),
      );

  /* ---------------- one machinery ---------------- */
  Future<void> _details(Session s, Map<String, dynamic> m, bool can) async {
    final id = '${m['id']}', ds = docState(m, s.today);
    final act = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (c) => SizedBox(
        height: MediaQuery.of(c).size.height * .86,
        child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 24), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(id, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(statusText(m), style: TextStyle(fontWeight: FontWeight.w700, color: m['status'] == 'Inactive' ? C.red : C.greenDark)),
          if (earlierText(m).isNotEmpty) Text(earlierText(m), style: const TextStyle(fontSize: 12.5, color: C.muted)),
          const SizedBox(height: 10),
          InfoRow('Machinery Number', '${m['no'] ?? ''}'),
          InfoRow('Machinery Name', '${m['name'] ?? ''}'),
          InfoRow('Type of Machinery', '${m['type'] ?? ''}'),
          InfoRow('Make', '${m['make'] ?? ''}'),
          InfoRow('Works on', worksOf(m).isEmpty ? '${m['unit'] ?? ''}' : worksOf(m).join(', ')),
          InfoRow('KM/Ltr', (asNum(m['kmStd']) ?? 0) > 0 ? fmtNum(asNum(m['kmStd'])) : ''),
          InfoRow('Ltr/Hr', (asNum(m['hrStd']) ?? 0) > 0 ? fmtNum(asNum(m['hrStd'])) : ''),
          InfoRow('Tank (Ltr)', (asNum(m['tankCap']) ?? 0) > 0 ? fmtNum(asNum(m['tankCap'])) : ''),
          InfoRow('Vendor', '${m['owner'] ?? ''}'),
          InfoRow('Ownership', '${m['ownership'] ?? ''}'),
          InfoRow('Diesel (BOQ)', '${m['supply'] ?? ''}'),
          InfoRow('Engine Number', '${m['engineNo'] ?? ''}'),
          InfoRow('Chassis Number', '${m['chassisNo'] ?? ''}'),
          InfoRow('Engine Make (company)', '${m['engineMake'] ?? ''}'),
          const SizedBox(height: 6),
          FormHead('Papers – valid upto', sub: ds.given == 0 ? '' : ds.expired.isNotEmpty ? 'Expired: ${ds.expired.join(', ')}' : ds.due.isNotEmpty ? 'Due within 30 days: ${ds.due.join(', ')}' : 'All OK'),
          for (final d in kDocs) InfoRow(d.$2, docShow(m[d.$3]), tone: _docTone(m[d.$3], s.today)),
          const SizedBox(height: 6),
          InfoRow('Entered by', '${m['enteredBy'] ?? ''}${'${m['updatedBy'] ?? ''}'.isNotEmpty && m['updatedBy'] != m['enteredBy'] ? ' · edited: ${m['updatedBy']}' : ''}'),
          if (can) ...[
            const SizedBox(height: 18),
            FilledButton.icon(key: const Key('md-edit'), onPressed: () => Navigator.pop(c, 'edit'), icon: const Icon(Icons.edit_rounded), label: Text('Edit')),
            const SizedBox(height: 10),
            OutlinedButton.icon(key: const Key('md-del'), style: OutlinedButton.styleFrom(foregroundColor: C.red), onPressed: () => Navigator.pop(c, 'del'), icon: const Icon(Icons.delete_outline_rounded), label: Text('Delete')),
          ],
        ])),
      ),
    );
    if (!mounted) return;
    if (act == 'edit') await _form(s.machine(id));
    if (act == 'del') await _run('del', () => _delete(id, false));
  }

  Color _docTone(dynamic v, String today) {
    final x = '${v ?? ''}';
    if (!RegExp(r'^\d{4}-').hasMatch(x)) return C.ink;
    if (x.compareTo(today) < 0) return C.red;
    return x.compareTo(dateKey(parseKey(today).add(const Duration(days: 30)))) <= 0 ? C.amber : C.greenDark;
  }

  Future<void> _delete(String id, bool force) async {
    final s = SessionScope.read(context);
    if (!force && !await ask(context, 'Delete machinery?', 'Delete $id from Master? This cannot be undone.', yes: 'Delete', danger: true)) return;
    final res = (await s.api.call('deleteMaster', [id, force], true) as Map).cast<String, dynamic>();
    if (!mounted) return;
    if (res['warning'] != null) {
      if (await ask(context, 'This machinery has entries', '${res['warning']}', yes: 'Delete anyway', danger: true)) await _delete(id, true);
      return;
    }
    s.setMaster(res['master']);
    sel.remove(id);
    toast(context, '$id deleted from Master.');
  }

  Future<void> _form(Machine? m) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => MachineFormScreen(edit: m, vendors: vendors)));
    if (mounted) setState(() {});
  }

  /* ---------------- the menu ---------------- */
  Future<void> _menu(String k) async {
    final s = SessionScope.read(context);
    final rows = _all(s).where((m) => f.test(m)).toList();
    switch (k) {
      case 'many':
        await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => BulkMachineryScreen(vendors: vendors)));
        if (mounted) setState(() {});
      case 'xlsx':
        await _run('xlsx', () async {
          final d = (await s.api.call('exportMaster') as Map).cast<String, dynamic>();
          await shareDocXlsx(s, masterExportDoc(d, s.today), bare: true);
          if (mounted) toast(context, '${(d['rows'] as List? ?? const []).length} machinery exported.');
        });
      case 'print':
        if (rows.isEmpty) {
          toast(context, 'No assets in this list.', bad: true);
          return;
        }
        await printDoc(context, s, masterListDoc(rows, f.vc));
      case 'alist':
        await _assetList(s);
      case 'import':
        await _import(s);
      case 'qr':
        await _qr(s);
    }
  }

  /// (3.13.0) Import from Excel – the web's m_file: the file read (the tab "Master" or the first, the columns by their names),
  /// checked by the server (importMaster without saving), what it will do asked, then saved (importMaster, saving).
  Future<void> _import(Session s) async {
    final f = await pickSheetFile();
    if (f == null || !mounted) return;
    await _run('import', () async {
      List<Map<String, Object?>> rows;
      try {
        rows = masterImportRows(readSheets(f.bytes));
      } on SheetError catch (e) {
        if (mounted) toast(context, e.message, bad: true);
        return;
      } catch (_) {
        if (mounted) toast(context, 'Could not read the file.', bad: true);
        return;
      }
      final check = (await s.api.call('importMaster', [rows, false]) as Map).cast<String, dynamic>();
      if (!mounted) return;
      final errs = (check['errors'] as List? ?? const []).whereType<Map>().toList();
      if (errs.isNotEmpty) {
        await tellLines(context, 'Nothing imported', ['Fix the rows listed below in the file and import again.', for (final x in errs) 'Excel row ${x['row']}: ${x['msg']}']);
        return;
      }
      final adds = asNum(check['adds']) ?? 0, updates = asNum(check['updates']) ?? 0;
      if (adds == 0 && updates == 0) {
        toast(context, 'Nothing to import – the file matches Master (${check['same']} unchanged).');
        return;
      }
      if (!await askLines(context, 'Import this file?', ['New machinery: ${check['adds']}', 'Existing machinery that will be updated: ${check['updates']}', 'Unchanged: ${check['same']}'], yes: 'Import')) return;
      final res = (await s.api.call('importMaster', [rows, true], true) as Map).cast<String, dynamic>();
      if (!mounted) return;
      if ((res['errors'] as List? ?? const []).isNotEmpty) {
        toast(context, 'Nothing imported. Try again.', bad: true);
        return;
      }
      s.setMaster(res['master']);
      toast(context, 'Imported: ${res['adds']} new, ${res['updates']} updated.');
    });
  }

  /// (3.13.0) QR labels – the web's: a label with a QR code for the machinery (all on site today, or one), 12 on an A4 page.
  /// A scan with a phone opens Mechanical on that machinery (after sign-in): Diesel Issue or Log Book entry.
  Future<void> _qr(Session s) async {
    final all = [for (final m in s.machines) m.m].where((m) => onSiteOn(m, s.today)).toList();
    if (all.isEmpty) {
      toast(context, 'There is no active machinery.', bad: true);
      return;
    }
    final how = await showModalBottomSheet<String>(
      context: context,
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const TwoLang('QR labels', 'QR लेबल', size: 20, weight: FontWeight.w700),
            const SizedBox(height: 8),
            Text('A label with a QR code for the machinery – stick it where the driver / operator can reach it. A scan with a phone opens this app on that machinery (after sign-in): Diesel Issue or Log Book entry.', style: const TextStyle(fontSize: 14, height: 1.4)),
            const SizedBox(height: 6),
            Text('12 labels on an A4 page (portrait). Print on sticker paper, or on paper and laminate.', style: const TextStyle(fontSize: 13, color: C.muted)),
            const SizedBox(height: 16),
            FilledButton.icon(key: const Key('qr-all'), onPressed: () => Navigator.pop(c, 'all'), icon: const Icon(Icons.qr_code_2_rounded), label: Text('All ${all.length} active machinery')),
            const SizedBox(height: 10),
            OutlinedButton.icon(key: const Key('qr-one'), onPressed: () => Navigator.pop(c, 'one'), icon: const Icon(Icons.search_rounded), label: Text('One machinery')),
          ]),
        ),
      ),
    );
    if (how == null || !mounted) return;
    Map<String, dynamic>? m1;
    if (how == 'one') {
      final m = await showModalBottomSheet<Machine>(context: context, isScrollControlled: true, useSafeArea: true, builder: (_) => MachinePicker(only: s.machines));
      if (m == null || !mounted) return;
      m1 = m.m;
    }
    final list = [...(m1 != null ? [m1] : all)]..sort((a, b) => localeCmp('${a['id']}', '${b['id']}', numeric: true));
    final customer = '${s.org['customer'] ?? ''}';
    final title = 'QR labels – ${m1 != null ? m1['id'] : '${list.length} machinery'}';
    final html = qrPrintHtml(title, qrLabelsHtml(list, s.api.mechUrl, customer), customer);
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PrintView(html: html, title: title)));
  }

  Future<void> _assetList(Session s) async {
    final a = AssetListAsk()
      ..date = s.today
      ..month = s.today.substring(0, 7)
      ..from = '${s.today.substring(0, 8)}01'
      ..to = s.today;
    final go = await showModalBottomSheet<bool>(context: context, isScrollControlled: true, builder: (_) => _AssetListAskSheet(a: a));
    if (go != true || !mounted) return;
    final (from, to, problem) = a.range();
    if (problem.isNotEmpty) {
      toast(context, problem, bad: true);
      return;
    }
    await _run('alist', () async {
      Map<String, dynamic>? bd;
      if (s.canSee('Breakdown')) {
        try {
          bd = ((await s.api.call('getBreakdowns', [{'date': to}])) as Map).cast<String, dynamic>();
        } catch (_) {
          bd = null;
        }
      }
      if (!mounted) return;
      await printDoc(context, s, assetListDoc(_all(s), a, from, to, bd));
    });
  }

  Future<void> _filters(Session s) async {
    final ms = s.machines;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _FilterSheet(f: f, types: uniqOf(ms, 'type'), owners: uniqOf(ms, 'owner'), today: s.today),
    );
    if (mounted) setState(() {});
  }

  /* ---------------- several ---------------- */
  Future<void> _mkVendors(List<String> names) async {
    final s = SessionScope.read(context);
    if (!await askLines(context, 'Create ${names.length} vendors?', names,
        note: 'These Owner Names are on the assets but not yet in Vendor Master. They will be saved as vendors (name only – fill GST / PAN / bank later). Their assets then count as Vendor assigned.', yes: 'Create vendors')) {
      return;
    }
    await _run('mkvend', () async {
      final res = (await s.api.call('vendorsFromOwners', [names], true) as Map).cast<String, dynamic>();
      if (!mounted) return;
      setState(() => vendors = {for (final v in (res['vendors'] as List? ?? const []).whereType<Map>()) '${v['name']}'}.toList()..sort());
      toast(context, '${res['count']} vendors created.');
    });
  }

  List<Map<String, dynamic>> _picked() {
    final s = SessionScope.read(context);
    return [for (final id in sel) if (s.machine(id) != null) s.machine(id)!.m];
  }

  Future<void> _assign() async {
    final s = SessionScope.read(context), list = _picked();
    if (list.isEmpty) return;
    if (vendors.isEmpty) vendors = await vendorNames(s);
    if (!mounted) return;
    if (vendors.isEmpty) {
      toast(context, 'No vendors in Vendor Master yet – create them first (+ New vendor).', bad: true);
      return;
    }
    final items = await Navigator.of(context).push<List<Map<String, String>>>(MaterialPageRoute(builder: (_) => _AssignScreen(list: list, vendors: vendors)));
    if (items == null || !mounted) return;
    if (items.isEmpty) {
      toast(context, 'No vendor picked.', bad: true);
      return;
    }
    await _run('assign', () async {
      final res = (await s.api.call('assignVendors', [items], true) as Map).cast<String, dynamic>();
      if (!mounted) return;
      if (res['ok'] != true) {
        await tellLines(context, 'Nothing saved', [for (final e in (res['errors'] as List? ?? const [])) '$e']);
        return;
      }
      s.setMaster(res['master']);
      sel.clear();
      toast(context, 'Vendor assigned to ${res['count']} asset${res['count'] == 1 ? '' : 's'}.');
    });
  }

  Future<void> _editMany() async {
    final s = SessionScope.read(context), list = _picked();
    if (list.isEmpty) return;
    final ch = await Navigator.of(context).push<Map<String, String>>(MaterialPageRoute(
        builder: (_) => EditManyScreen(list: list, today: s.today, types: uniqOf(s.machines, 'type'), makes: uniqOf(s.machines, 'make'), vendors: vendors)));
    if (ch == null || !mounted) return;
    // (update-119) made Active again without the day it came back: they never left (asked first – else the days away count as on site)
    final wereOff = list.where((m) => m['status'] == 'Inactive' && '${m['inactiveFrom'] ?? ''}'.isNotEmpty).toList();
    if (ch['status'] == 'Active' && (ch['activeFrom'] ?? '').isEmpty && wereOff.isNotEmpty) {
      final ok = await askLines(context, 'They never left the site?', [for (final m in wereOff) '${m['id']} (inactive from ${showDate('${m['inactiveFrom']}'.substring(0, 10))})'],
          note: 'If they came back, press Cancel and put the day they came back in Active From – their time on site until they left is kept as an earlier period.\n"They never left": the Inactive was a mistake – every day counts as on site.', yes: 'They never left');
      if (!ok) return;
    }
    if (!mounted) return;
    if (ch.isEmpty) {
      toast(context, 'Nothing changed.');
      return;
    }
    await _run('editmany', () async {
      final res = (await s.api.call('editMasterMany', [list.map((m) => m['id']).toList(), ch], true) as Map).cast<String, dynamic>();
      if (!mounted) return;
      if (res['ok'] != true) {
        await tellLines(context, 'Nothing saved', [for (final e in (res['errors'] as List? ?? const []).whereType<Map>()) '${e['id']}: ${e['msg']}']);
        return;
      }
      s.setMaster(res['master']);
      sel.clear();
      toast(context, '${res['count']} machinery updated.');
    });
  }

  Future<void> _deleteMany() async {
    final s = SessionScope.read(context), ids = sel.toList();
    if (ids.isEmpty) return;
    if (!await askLines(context, 'Delete ${ids.length} machinery from Master?', [ids.take(30).join(', ') + (ids.length > 30 ? ' …' : '')], yes: 'Delete', danger: true)) return;
    await _run('delmany', () async {
      var res = (await s.api.call('deleteMasterMany', [ids, false], true) as Map).cast<String, dynamic>();
      if (res['ok'] != true && res['used'] is List) {
        if (!mounted) return;
        final used = (res['used'] as List).whereType<Map>().toList();
        if (!await askLines(context, '${used.length} of them already have entries', [for (final u in used) '${u['id']} – ${u['diesel']} Diesel Issue, ${u['log']} Log Book entries'],
            note: 'Their entries stay, but the machinery will be removed from Master.', yes: 'Delete anyway', danger: true)) {
          return;
        }
        res = (await s.api.call('deleteMasterMany', [ids, true], true) as Map).cast<String, dynamic>();
      }
      if (!mounted) return;
      s.setMaster(res['master']);
      sel.clear();
      toast(context, '${res['count']} machinery deleted.');
    });
  }
}

Color toneOf(String t) => switch (t) { 'bad' => C.red, 'warn' => C.amber, 'good' => C.greenDark, _ => C.slate };
Color softOf(String t) => switch (t) { 'bad' => C.redSoft, 'warn' => C.amberSoft, 'good' => C.greenSoft, _ => C.slateSoft };

/* ---------------- the filters ---------------- */
class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.f, required this.types, required this.owners, required this.today});
  final AssetFilter f;
  final List<String> types, owners;
  final String today;
  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late final type = TextEditingController(text: widget.f.type), owner = TextEditingController(text: widget.f.owner);
  @override
  void dispose() {
    type.dispose();
    owner.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.f;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * .82,
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 24), children: [
          Text('Filters', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          PickField(label: 'Ownership', value: f.own, items: kOwnerships, blank: 'All', onChanged: (v) => setState(() => f.own = v)),
          const SizedBox(height: 10),
          TextBox(label: 'Type', controller: type, options: widget.types, hint: 'All', onChanged: (v) => f.type = v.trim()),
          const SizedBox(height: 10),
          PickField(label: 'Unit', value: f.unit, items: kUnits, blank: 'All', onChanged: (v) => setState(() => f.unit = v)),
          const SizedBox(height: 10),
          TextBox(label: 'Owner', controller: owner, options: widget.owners, hint: 'All', onChanged: (v) => f.owner = v.trim()),
          const SizedBox(height: 10),
          PickField(label: 'Diesel Supply', value: f.supply, items: kSupplies, blank: 'All', onChanged: (v) => setState(() => f.supply = v)),
          const SizedBox(height: 10),
          PickField(label: 'Status', value: f.status, items: const ['Active', 'Inactive'], blank: 'All', onChanged: (v) => setState(() => f.status = v)),
          const SizedBox(height: 14),
          Text('Machinery on site on at least one day of these dates. Empty = all machinery, also the machinery that left.', style: const TextStyle(fontSize: 12.5, color: C.muted, height: 1.3)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: DateField(key: const Key('mf-from'), label: 'On site from', value: f.from, onChanged: (v) => setState(() => f.from = v))),
            const SizedBox(width: 8),
            Expanded(child: DateField(key: const Key('mf-to'), label: 'to', value: f.to, onChanged: (v) => setState(() => f.to = v))),
          ]),
          const SizedBox(height: 18),
          FilledButton(key: const Key('mf-show'), onPressed: () => Navigator.pop(context), child: Text('Show')),
          const SizedBox(height: 8),
          OutlinedButton(
            key: const Key('mf-clear'),
            onPressed: () {
              f.clear();
              Navigator.pop(context);
            },
            child: Text('Clear filters'),
          ),
        ]),
      ),
    );
  }
}

/* ---------------- Asset list: what to print ---------------- */
class _AssetListAskSheet extends StatefulWidget {
  const _AssetListAskSheet({required this.a});
  final AssetListAsk a;
  @override
  State<_AssetListAskSheet> createState() => _AssetListAskSheetState();
}

class _AssetListAskSheetState extends State<_AssetListAskSheet> {
  @override
  Widget build(BuildContext context) {
    final a = widget.a;
    Widget tick(String label, bool v, ValueChanged<bool> on) => CheckboxListTile(contentPadding: EdgeInsets.zero, dense: true, controlAffinity: ListTileControlAffinity.leading, value: v, onChanged: (x) => setState(() => on(x == true)), title: Text(label));
    return SizedBox(
      height: MediaQuery.of(context).size.height * .86,
      child: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 24), children: [
        Text('Asset list', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        PickField(label: 'List for', value: a.kind == 'date' ? 'One date' : a.kind == 'month' ? 'A month' : 'A period (from – to)', items: const ['One date', 'A month', 'A period (from – to)'], onChanged: (v) => setState(() => a.kind = v == 'One date' ? 'date' : v == 'A month' ? 'month' : 'period')),
        const SizedBox(height: 10),
        if (a.kind == 'date') DateField(label: 'Date', value: a.date, clear: false, onChanged: (v) => setState(() => a.date = v)),
        if (a.kind == 'month')
          Press(
            radius: 16,
            shadow: false,
            padding: const EdgeInsets.all(14),
            onTap: () async {
              final d = await showDatePicker(context: context, initialDate: DateTime(int.parse(a.month.substring(0, 4)), int.parse(a.month.substring(5, 7))), firstDate: DateTime(2015), lastDate: DateTime(2035), initialDatePickerMode: DatePickerMode.year);
              if (d != null) setState(() => a.month = dateKey(d).substring(0, 7));
            },
            child: Row(children: [const Icon(Icons.calendar_month_rounded, color: C.blue, size: 18), const SizedBox(width: 8), Text('Month: ${a.month.substring(5)}-${a.month.substring(0, 4)}', style: const TextStyle(fontWeight: FontWeight.w700))]),
          ),
        if (a.kind == 'period')
          Row(children: [
            Expanded(child: DateField(label: 'From', value: a.from, clear: false, onChanged: (v) => setState(() => a.from = v))),
            const SizedBox(width: 8),
            Expanded(child: DateField(label: 'To', value: a.to, clear: false, onChanged: (v) => setState(() => a.to = v))),
          ]),
        const SizedBox(height: 10),
        PickField(label: 'Ownership', value: a.own, items: kOwnerships, blank: 'All', onChanged: (v) => setState(() => a.own = v)),
        const SizedBox(height: 12),
        Text('Also print (tick what you need):', style: const TextStyle(fontWeight: FontWeight.w700)),
        tick('Standard Average', a.std, (v) => a.std = v),
        tick('Tax / PUC / Permit / Fitness / Insurance', a.papers, (v) => a.papers = v),
        tick('Make', a.make, (v) => a.make = v),
        tick('Engine Number', a.eng, (v) => a.eng = v),
        tick('Chassis Number', a.chs, (v) => a.chs = v),
        const SizedBox(height: 14),
        FilledButton(key: const Key('al-next'), onPressed: () => Navigator.pop(context, true), child: Text('Next')),
      ]),
    );
  }
}

/* ---------------- Assign vendor: each asset its vendor, "set all" fills every row ---------------- */
class _AssignScreen extends StatefulWidget {
  const _AssignScreen({required this.list, required this.vendors});
  final List<Map<String, dynamic>> list;
  final List<String> vendors;
  @override
  State<_AssignScreen> createState() => _AssignScreenState();
}

class _AssignScreenState extends State<_AssignScreen> {
  late final pick = {
    for (final m in widget.list) '${m['id']}': widget.vendors.firstWhere((n) => n.toUpperCase() == '${m['owner'] ?? ''}'.trim().toUpperCase(), orElse: () => ''),
  };
  String all = '';
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text('Assign vendor – ${widget.list.length} asset${widget.list.length == 1 ? '' : 's'}'), actions: [const GuideButton('master')]),
        body: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: PickField(key: const Key('as-all'), label: 'Set all rows to', value: all, items: widget.vendors, blank: '– pick –', onChanged: (v) => setState(() => all = v))),
            const SizedBox(width: 8),
            OutlinedButton(
              key: const Key('as-apply'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52)),
              onPressed: all.isEmpty ? null : () => setState(() => pick.updateAll((_, __) => all)),
              child: Text('Apply to all'),
            ),
          ]),
          const SizedBox(height: 12),
          for (final (i, m) in widget.list.indexed)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: C.line)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('${i + 1}. ${m['id']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
                Text([m['type'], m['ownership'], 'Owner Name now: ${'${m['owner'] ?? ''}'.isEmpty ? '–' : m['owner']}'].where((x) => '${x ?? ''}'.isNotEmpty).join(' · '), style: const TextStyle(fontSize: 13, color: C.muted)),
                const SizedBox(height: 8),
                PickField(key: Key('as-${m['id']}'), label: 'Vendor', value: pick['${m['id']}'] ?? '', items: widget.vendors, blank: '– pick –', onChanged: (v) => setState(() => pick['${m['id']}'] = v)),
              ]),
            ),
        ])),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: FilledButton(key: const Key('as-save'), onPressed: () => Navigator.pop(context, [for (final e in pick.entries) if (e.value.isNotEmpty) {'id': e.key, 'vendor': e.value}]), child: Text('Save')),
          ),
        ),
      );
}

/* ---------------- Edit selected: a value all share is filled in; "different" keeps each one's own ---------------- */
class EditManyScreen extends StatefulWidget {
  const EditManyScreen({super.key, required this.list, required this.today, required this.types, required this.makes, required this.vendors});
  final List<Map<String, dynamic>> list;
  final String today;
  final List<String> types, makes, vendors;
  @override
  State<EditManyScreen> createState() => _EditManyScreenState();
}

class _EditManyScreenState extends State<EditManyScreen> {
  late final common = meCommon(widget.list);
  late final typed = <String, String>{for (final f in kMeFields) f.key: common[f.key]!.same ? common[f.key]!.v : ''};
  late final ctl = <String, TextEditingController>{
    for (final f in kMeFields)
      if (f.kind == 'text' || f.kind == 'number') f.key: TextEditingController(text: typed[f.key]),
  };
  @override
  void dispose() {
    for (final c in ctl.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final one = widget.list.length == 1;
    Widget box(MeField f) {
      final c = common[f.key]!;
      final label = '${tr(f.label)}${c.same ? '' : ' – ${tr('different')}'}';
      switch (f.kind) {
        case 'pick':
          return PickField(key: Key('me-${f.key}'), label: label, value: typed[f.key]!, items: f.options, blank: c.same ? (c.v.isEmpty ? '–' : null) : '(different – keep each)', onChanged: (v) => setState(() => typed[f.key] = v));
        case 'date':
          return DateField(key: Key('me-${f.key}'), label: label, value: typed[f.key]!, last: parseKey(widget.today), onChanged: (v) => setState(() => typed[f.key] = v));
        default:
          final opts = f.key == 'type' ? widget.types : f.key == 'make' ? widget.makes : f.key == 'owner' ? widget.vendors : const <String>[];
          return TextBox(
            key: Key('me-${f.key}'),
            label: label,
            controller: ctl[f.key]!,
            options: opts,
            kb: f.kind == 'number' ? const TextInputType.numberWithOptions(decimal: true) : null,
            hint: c.same ? '' : 'Different – blank keeps each one\'s own',
            onChanged: (v) => typed[f.key] = v,
          );
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(one ? 'Edit ${widget.list.first['id']}' : 'Edit ${widget.list.length} machinery'), actions: [const GuideButton('master')]),
      body: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(
          one ? 'Change what you need for ${widget.list.first['id']}.' : 'The ${widget.list.length} selected machinery: a value they all share is filled in – change it for all. Boxes marked "different" keep each machinery\'s own value unless you type a new one.',
          style: const TextStyle(fontSize: 13.5, color: C.muted, height: 1.35),
        ),
        const SizedBox(height: 12),
        for (final f in kMeFields) Padding(padding: const EdgeInsets.only(bottom: 10), child: box(f)),
      ])),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton(key: const Key('me-save'), onPressed: () => Navigator.pop(context, meChanges(common, typed, widget.today)), child: Text('Save changes')),
        ),
      ),
    );
  }
}
