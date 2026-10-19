/* ENTRIES – (3.1.8, asked 15-10-2026: "side la ek mekache te nko eka khali ek ashi list … jyala jo access aahe tyala tech
 * disel") first a list, one under the other, of the pages of entries he may open: 1. Diesel Issue 2. Diesel Inward 3. Transfer
 * 4. Log Book. A tap opens that page: a strip of the last days, the day's count and litres, search and a filter by place, a card
 * per entry with its picture, and "New Entry" for those who may add (picture 2, 14-10-2026). Back = the list again. */
import 'package:flutter/material.dart' hide Text;

import '../core/format.dart';
import '../core/kinds.dart';
import '../core/session.dart';
import '../ui/scope.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'diesel_photos.dart';
import 'entry_more.dart';
import 'forms.dart';
import 'logbook.dart';
import 'super_delete.dart';
import '../ui/t.dart';
import '../ui/help.dart' show showGuide;

class EntriesTab extends StatefulWidget {
  const EntriesTab({super.key, this.kind = '', this.open = 0});
  final String kind;

  /// Home asked to open [kind] (counted, so the same page can be asked again after going back to the list).
  final int open;
  @override
  State<EntriesTab> createState() => _EntriesTabState();
}

/// Kept while the app is open: a day already seen shows at once (then it is read again).
final _entriesCache = <String, List<Map<String, dynamic>>>{};

class _EntriesTabState extends State<EntriesTab> {
  String kind = '', day = '', q = '', place = '';
  bool loading = false;
  String err = '';
  List<Map<String, dynamic>> rows = [];
  int seq = 0;

  @override
  void didUpdateWidget(covariant EntriesTab old) {
    super.didUpdateWidget(old);
    if (widget.kind.isNotEmpty && (widget.kind != old.kind || widget.open != old.open)) {
      kind = widget.kind;
      _load();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final s = SessionScope.read(context);
    if (day.isEmpty) day = s.today.isNotEmpty ? s.today : dateKey(DateTime.now());
    if (kind.isEmpty && widget.kind.isNotEmpty && !_opened) {
      _opened = true;
      kind = widget.kind;
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
  }

  Session? _ls;
  // (3.1.7) live: an entry added or changed elsewhere (the web, another phone, an approval) – the list loads again by itself
  void _live() {
    if (mounted && kind.isNotEmpty && (_ls?.lastChanged.any((g) => g == 'stock' || g == 'master' || g == 'flow') ?? true)) _load();
  }

  @override
  void dispose() {
    _ls?.dataTick.removeListener(_live);
    super.dispose();
  }

  Future<void> _load() async {
    final s = SessionScope.read(context), k = kindOf(kind), my = ++seq, ck = '${s.site?.code}|$kind|$day';
    _ls ??= s..dataTick.addListener(_live);
    setState(() {
      rows = _entriesCache[ck] ?? [];
      loading = rows.isEmpty;
      err = '';
    });
    try {
      final r = (await s.api.call(k.list, [{'from': day, 'to': day, 'all': true}]) as Map).cast<String, dynamic>();
      if (my != seq || !mounted) return;
      if (r['stock'] != null) s.setStock(r['stock']);
      setState(() {
        rows = (r['rows'] as List? ?? []).whereType<Map>().map((m) => m.cast<String, dynamic>()).toList();
        _entriesCache[ck] = rows;
        loading = false;
      });
    } catch (e) {
      if (my != seq || !mounted) return;
      setState(() {
        err = errText(e);
        loading = false;
      });
    }
  }

  Future<void> _pickDate() async {
    final s = SessionScope.read(context);
    final last = s.today.isNotEmpty ? parseKey(s.today) : DateTime.now();
    final d = await showDatePicker(context: context, initialDate: parseKey(day), firstDate: DateTime(2024), lastDate: last);
    if (d != null) {
      day = dateKey(d);
      _load();
    }
  }

  String _placeOf(Map<String, dynamic> r) => (r['source'] ?? r['location'] ?? r['from'] ?? '').toString();

  List<Map<String, dynamic>> get _shown {
    final words = q.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    return rows.where((r) {
      if (place.isNotEmpty && _placeOf(r) != place && (r['to'] ?? '') != place) return false;
      if (words.isEmpty) return true;
      final t = r.values.map((v) => '$v').join(' ').toLowerCase();
      return words.every(t.contains);
    }).toList();
  }

  Future<void> _filter() async {
    final s = SessionScope.read(context);
    final v = await showModalBottomSheet<String>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Padding(padding: EdgeInsets.fromLTRB(20, 0, 20, 8), child: Align(alignment: Alignment.centerLeft, child: TwoLang('Filter by place', 'ठिकाणानुसार', size: 19, weight: FontWeight.w700))),
          for (final l in ['', ...s.locations])
            ListTile(
              leading: Icon(place == l ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: C.green),
              title: Text(l.isEmpty ? 'All places' : l, style: const TextStyle(fontWeight: FontWeight.w600)),
              onTap: () => Navigator.pop(c, l),
            ),
          const SizedBox(height: 12),
        ]),
      ),
    );
    if (v != null) setState(() => place = v);
  }

  bool _opened = false;

  /// (3.1.8) the list of his pages of entries, one under the other
  Widget _menu(Session s) {
    final items = <(String, String, String, Color, Color, VoidCallback)>[
      for (final k in kKinds.where((k) => s.canSee(k.module)))
        (k.en, k.mr, k.pic, k.color, k.soft, () {
          setState(() {
            kind = k.key;
            rows = [];
          });
          _load();
        }),
      if (s.canSee('Log Book')) ('Log Book', 'लॉग बुक', 'notebook', C.blue, C.blueSoft, () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const LogBookScreen()))),
    ];
    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 30), children: [
          const Padding(padding: EdgeInsets.fromLTRB(4, 0, 4, 4), child: TwoLang('Your entries', 'तुमच्या एन्ट्री', size: 28, weight: FontWeight.w800)),
          Padding(padding: const EdgeInsets.fromLTRB(4, 0, 4, 16), child: Text(s.siteName, style: const TextStyle(fontSize: 15, color: C.muted, fontWeight: FontWeight.w600))),
          if (items.isEmpty) const EmptyState('No pages of entries', 'Ask the Admin for access to Diesel Issue, Inward, Transfer or Log Book.', pic: 'locked_with_key'),
          for (final (i, x) in items.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Press(
                key: Key('entries-${x.$1}'),
                onTap: x.$6,
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  Container(width: 62, height: 62, decoration: BoxDecoration(color: x.$5, borderRadius: BorderRadius.circular(18)), alignment: Alignment.center, child: Pic(x.$3, size: 44)),
                  const SizedBox(width: 14),
                  Text('${i + 1}.', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: x.$4)),
                  const SizedBox(width: 8),
                  Expanded(child: TwoLang(x.$1, x.$2, size: 17, weight: FontWeight.w700)),
                  const Icon(Icons.chevron_right_rounded, color: C.faint),
                ]),
              ),
            ),
        ]),
      ),
    );
  }

  Future<void> _add() async {
    if (await newEntry(context, kindOf(kind))) _load();
  }

  /// (3.11.0) The rest of the web's page: all dates & Export, multiple entries, Import from Excel, Download template.
  Future<void> _more(String v) async {
    final k = kindOf(kind);
    switch (v) {
      case 'find':
        await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => EntryFindScreen(kind: k)));
      case 'many':
        await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => k.key == 'issue' ? const IssueManyScreen() : const TransferManyScreen()));
      case 'import':
        await importEntries(context, k);
      case 'template':
        await downloadTemplate(context, k);
        return;
      case 'guide':
        await showGuide(context, k.key == 'issue' ? 'diesel' : k.key); // (3.16.0) the web's "?" of the page
        return;
      case 'sdel':      // (3.25.0, Mechanical update-134) the Super Admin deletes entries and brings them back
        await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SuperDeleteScreen()));
    }
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    if (kind.isEmpty || !s.canSee(kindOf(kind).module)) return _menu(s);
    final k = kindOf(kind);
    final list = _shown;
    final total = list.fold<num>(0, (a, r) => a + (asNum(r['qty']) ?? 0));
    final today = s.today.isNotEmpty ? parseKey(s.today) : DateTime.now();
    final days = [for (var i = 0; i < 14; i++) today.subtract(Duration(days: i))];
    return Scaffold(
      floatingActionButton: s.canEdit(k.module)
          ? FloatingActionButton.extended(
              onPressed: _add,
              backgroundColor: k.color,
              foregroundColor: Colors.white,
              elevation: 3,
              shape: const StadiumBorder(),
              icon: const Icon(Icons.add_rounded, size: 26),
              label: const Text('New Entry', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            )
          : null,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: C.green,
          onRefresh: _load,
          child: CustomScrollView(slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 12, 6),
                child: Row(children: [
                  IconButton(tooltip: tr('All entries'), icon: const Icon(Icons.arrow_back_rounded), onPressed: () => setState(() => kind = '')),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(k.en, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                      Text(s.siteName, style: const TextStyle(fontSize: 15, color: C.muted, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                  IconButton.filledTonal(
                    tooltip: tr('Pick a date'),
                    style: IconButton.styleFrom(backgroundColor: C.greenSoft, foregroundColor: C.greenDark, fixedSize: const Size(50, 50)),
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_month_rounded),
                  ),
                  PopupMenuButton<String>(
                    key: const Key('en-more'),
                    tooltip: tr('More'),
                    icon: const Icon(Icons.more_vert_rounded),
                    onSelected: _more,
                    itemBuilder: (_) => [
                      PopupMenuItem(key: const Key('en-guide'), value: 'guide', child: Text('About this page')),
                      PopupMenuItem(key: const Key('en-find'), value: 'find', child: Text('All dates & Export')),
                      if (s.superAdmin && k.key == 'issue') PopupMenuItem(key: const Key('en-sdel'), value: 'sdel', child: Text('Delete entries – Super Admin')),
                      if (s.canEdit(k.module) && k.key != 'inward') PopupMenuItem(key: const Key('en-many'), value: 'many', child: Text('Multiple entries')),
                      if (s.canEdit(k.module)) PopupMenuItem(key: const Key('en-import'), value: 'import', child: Text('Import from Excel')),
                      if (s.canEdit(k.module)) PopupMenuItem(key: const Key('en-template'), value: 'template', child: Text('Download template')),
                    ],
                  ),
                ]),
              ),
            ),
            // the days
            SliverToBoxAdapter(
              child: SizedBox(
                height: 86,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                  itemCount: days.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final d = days[i], key = dateKey(d), on = key == day;
                    return GestureDetector(
                      onTap: () {
                        setState(() => day = key);
                        _load();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 58,
                        decoration: BoxDecoration(color: on ? k.color : Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: on ? k.color : C.line)),
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Text(weekDays[d.weekday - 1], style: TextStyle(fontSize: 13, color: on ? Colors.white : C.muted, fontWeight: FontWeight.w500)),
                          Text('${d.day}', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700, color: on ? Colors.white : C.ink)),
                        ]),
                      ),
                    );
                  },
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: Row(children: [
                  Expanded(child: Text('${showDate(day)}, ${weekDays[parseKey(day).weekday - 1]}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700))),
                  if (!loading) Text('${list.length} ${list.length == 1 ? 'entry' : 'entries'} · ${fmtNum(total)} L', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: k.color)),
                ]),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(children: [
                  Expanded(
                    child: TextField(
                      onChanged: (v) => setState(() => q = v),
                      decoration: InputDecoration(hintText: tr(kind == 'issue' ? 'Search vehicle, operator, issue ID…' : 'Search…'), prefixIcon: const Icon(Icons.search_rounded), contentPadding: const EdgeInsets.symmetric(vertical: 14)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Press(
                    onTap: _filter,
                    radius: 18,
                    shadow: false,
                    border: place.isEmpty ? C.line : k.color,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    child: Row(children: [
                      Icon(Icons.filter_alt_outlined, color: place.isEmpty ? C.ink : k.color),
                      const SizedBox(width: 6),
                      Text(place.isEmpty ? 'Filter' : place, style: TextStyle(fontWeight: FontWeight.w600, color: place.isEmpty ? C.ink : k.color)),
                    ]),
                  ),
                ]),
              ),
            ),
            if (loading)
              SliverList.separated(itemCount: 4, separatorBuilder: (_, __) => const SizedBox(height: 10), itemBuilder: (_, __) => const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Shimmer(height: 104)))
            else if (err.isNotEmpty)
              SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.all(16), child: InfoLine(err, bad: true)))
            else if (list.isEmpty)
              SliverToBoxAdapter(
                child: EmptyState(rows.isEmpty ? 'No ${k.en.toLowerCase()} on this day' : 'Nothing matches', rows.isEmpty ? 'Pick another day, or add a new entry.' : 'Change the search or the filter.', pic: k.pic,
                    action: rows.isEmpty && s.canEdit(k.module) ? 'New Entry' : null, onAction: _add),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 110),
                sliver: SliverList.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => EntryCard(kind: k, r: list[i], onChanged: _load),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

/// One entry as a card (picture 2).
class EntryCard extends StatelessWidget {
  const EntryCard({super.key, required this.kind, required this.r, this.onChanged, this.note = ''});
  final Kind kind;
  final Map<String, dynamic> r;

  /// (3.11.0) a small line under the litres (the list of all dates: the date, its % of the total)
  final String note;

  /// After a change or a delete (the list loads again).
  final VoidCallback? onChanged;

  String get _title => switch (kind.key) {
        'issue' => (r['no'] ?? '').toString(),
        'inward' => (r['pump'] ?? '').toString().isEmpty ? (r['open'] == true ? 'Opening stock' : 'Diesel received') : r['pump'].toString(),
        _ => '${r['from'] ?? ''} › ${r['to'] ?? ''}',
      };

  String get _pic => kind.key == 'issue' ? picOfType('${r['type'] ?? ''}') : kind.pic;

  List<(IconData, String)> get _lines => switch (kind.key) {
        'issue' => [
            (Icons.receipt_long_outlined, '${r['id'] ?? ''}'),
            (Icons.local_shipping_outlined, [r['type'], r['source']].where((e) => '${e ?? ''}'.isNotEmpty).join('  |  ')),
            if ('${r['driver'] ?? ''}'.isNotEmpty) (Icons.person_outline_rounded, 'Operator: ${r['driver']}'),
          ],
        'inward' => [
            (Icons.receipt_long_outlined, '${r['id'] ?? ''}'),
            (Icons.place_outlined, 'Received at ${r['location'] ?? ''}'),
            if ('${r['billNo'] ?? ''}'.isNotEmpty) (Icons.description_outlined, 'Bill ${r['billNo']}${'${r['billDate'] ?? ''}'.isNotEmpty ? ' · ${showDate('${r['billDate']}')}' : ''}'),
          ],
        _ => [
            (Icons.receipt_long_outlined, '${r['id'] ?? ''}'),
            if ('${r['remark'] ?? ''}'.isNotEmpty) (Icons.notes_rounded, '${r['remark']}'),
          ],
      };

  @override
  Widget build(BuildContext context) => Press(
        onTap: () => _details(context),
        padding: const EdgeInsets.all(12),
        child: note.isEmpty ? _main() : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _main(),
          Padding(padding: const EdgeInsets.only(top: 6, left: 4), child: Text(note, style: const TextStyle(fontSize: 13, color: C.muted, fontWeight: FontWeight.w600))),
        ]),
      );

  Widget _main() => Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Container(width: 74, height: 74, decoration: BoxDecoration(color: kind.soft.withValues(alpha: .6), borderRadius: BorderRadius.circular(18)), alignment: Alignment.center, child: Pic(_pic, size: 56)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              for (final l in _lines)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(children: [
                    Icon(l.$1, size: 15, color: C.faint),
                    const SizedBox(width: 6),
                    Expanded(child: Text(l.$2, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5, color: C.muted))),
                  ]),
                ),
            ]),
          ),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Pill('${fmtNum(asNum(r['qty']))} L', color: kind.color, bg: kind.soft, big: true),
            const SizedBox(height: 8),
            if ('${r['shift'] ?? ''}'.isNotEmpty) Text('${r['shift']} shift', style: const TextStyle(fontSize: 12.5, color: C.muted)),
            if (kind.key == 'inward' && asNum(r['amount']) != null) Text('₹ ${fmtNum(asNum(r['amount']))}', style: const TextStyle(fontSize: 12.5, color: C.muted)),
          ]),
        ]);

  void _details(BuildContext context) {
    final rowsOf = <(String, String)>[
      ('Entry', '${r['id'] ?? ''}'),
      ('Date', '${showDate('${r['date'] ?? ''}')}${'${r['shift'] ?? ''}'.isNotEmpty ? ' · ${r['shift']} shift' : ''}'),
      if (kind.key == 'issue') ...[
        ('Machinery', '${r['no'] ?? ''}'),
        ('Type / Owner', [r['type'], r['owner']].where((e) => '${e ?? ''}'.isNotEmpty).join(' · ')),
        ('Diesel from', '${r['source'] ?? ''}'),
        ('Reading', [asNum(r['kmReading']) != null ? '${fmtNum(asNum(r['kmReading']))} km' : '', asNum(r['hrReading']) != null ? '${fmtNum(asNum(r['hrReading']))} hr' : '', '${r['meter'] ?? ''}'].where((e) => e.isNotEmpty).join(' · ')),
        ('Operator', '${r['driver'] ?? ''}'),
        ('Photos', (asNum(r['ph']) ?? 0) > 0 ? '${fmtNum(asNum(r['ph']))} of 4' : ''),
        ('Stock after', asNum(r['balance']) != null ? '${fmtNum(asNum(r['balance']))} L' : ''),
      ],
      if (kind.key == 'inward') ...[
        ('Pump', '${r['pump'] ?? ''}'),
        ('Received at', '${r['location'] ?? ''}'),
        ('Rate', asNum(r['rate']) != null ? '₹ ${fmtNum(asNum(r['rate']))} / L' : ''),
        ('Amount', asNum(r['amount']) != null ? '₹ ${fmtNum(asNum(r['amount']))}' : ''),
        ('Bill', [r['billNo'], showDate('${r['billDate'] ?? ''}')].where((e) => '${e ?? ''}'.isNotEmpty).join(' · ')),
        ('Bill copy', (asNum(r['ph']) ?? 0) == 1 ? '1 photo' : (asNum(r['ph']) ?? 0) > 1 ? '${fmtNum(asNum(r['ph']))} photos' : ''),      // (3.1.13, update-120)
      ],
      if (kind.key == 'transfer') ...[('From', '${r['from'] ?? ''}'), ('To', '${r['to'] ?? ''}')],
      ('Litres', '${fmtNum(asNum(r['qty']))} L'),
      ('Remark', '${r['remark'] ?? ''}'),
      ('Entered by', [r['enteredBy'], if ('${r['updatedBy'] ?? ''}'.isNotEmpty) 'changed by ${r['updatedBy']}'].where((e) => '${e ?? ''}'.isNotEmpty).join(' · ')),
    ].where((x) => x.$2.trim().isNotEmpty).toList();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 60, height: 60, decoration: BoxDecoration(color: kind.soft, borderRadius: BorderRadius.circular(18)), alignment: Alignment.center, child: Pic(_pic, size: 46)),
              const SizedBox(width: 14),
              Expanded(child: TwoLang(_title, kind.en, size: 20, weight: FontWeight.w700)),
              Pill('${fmtNum(asNum(r['qty']))} L', color: kind.color, bg: kind.soft, big: true),
            ]),
            const SizedBox(height: 16),
            for (final x in rowsOf)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(width: 120, child: Text(x.$1, style: const TextStyle(color: C.muted, fontSize: 14))),
                  Expanded(child: Text(x.$2, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5))),
                ]),
              ),
            // (3.14.0) the photos of a fill – the web's 📷 in its list (phView)
            if (kind.key == 'issue' && (asNum(r['ph']) ?? 0) > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: OutlinedButton.icon(key: const Key('ed-photos'), onPressed: () => openDieselPhotos(context, '${r['id']}'), icon: const Icon(Icons.photo_library_outlined), label: Text('See the photos (${fmtNum(asNum(r['ph']))})')),
              ),
            // (14-10-2026) an entry of a submitted bill: the Super Admin changes it; anybody else sends the change for his approval
            if (r['lk'] != null) InfoLine(SessionScope.read(context).superAdmin ? 'This entry is in a saved bill – you are the Super Admin: your change is saved; the difference comes in the next bill.' : bi('This entry is in a saved bill – a change goes to the Super Admin for approval.', 'बिलमध्ये आहे – बदल Super Admin च्या मंजुरीने.'), icon: Icons.lock_outline_rounded),
            if (SessionScope.read(context).canEdit(kind.module) && r['open'] != true) ...[
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(foregroundColor: C.red, side: const BorderSide(color: C.redSoft)),
                    onPressed: () async {
                      final s = SessionScope.read(context);
                      if (!await ask(c, 'Delete ${r['id']}?', '$_title – ${fmtNum(asNum(r['qty']))} L, ${showDate('${r['date'] ?? ''}')}. ${bi('This cannot be undone.', 'हे परत आणता येणार नाही.')}', yes: 'Delete', danger: true)) return;
                      try {
                        await s.api.call(deleteOf(kind.key), [r['id']], true);
                        if (c.mounted) Navigator.pop(c);
                        if (context.mounted) toast(context, '${r['id']} deleted.');
                        onChanged?.call();
                      } catch (e) {
                        if (c.mounted) toast(c, errText(e), bad: true);
                      }
                    },
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('Delete'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: kind.color, minimumSize: const Size.fromHeight(52)),
                    onPressed: () async {
                      Navigator.pop(c);
                      if (await changeEntry(context, kind, r)) onChanged?.call();
                    },
                    icon: const Icon(Icons.edit_rounded),
                    label: const Text('Change'),
                  ),
                ),
              ]),
            ],
          ]),
        ),
      ),
    );
  }
}
