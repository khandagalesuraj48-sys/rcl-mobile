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
import 'fuel_cards.dart' show FuelCardsScreen;
import 'maintenance.dart' show MaintScreen;
import 'logbook.dart';
import 'breakdown.dart';
import 'store.dart';
import 'search.dart';
import 'assistant.dart' show shellEntries, shellReports;
import '../ui/ask_bot.dart';
import 'super_delete.dart';
import '../ui/t.dart';
import '../ui/help.dart' show showGuide;
import '../ui/live.dart';

class EntriesTab extends StatefulWidget {
  const EntriesTab({super.key, this.kind = '', this.open = 0, this.active = true});
  final String kind;

  /// (update-155) Entries is the tab on the screen (the shell says so): only then it loads after others' changes
  final bool active;

  /// Home asked to open [kind] (counted, so the same page can be asked again after going back to the list).
  final int open;
  @override
  State<EntriesTab> createState() => _EntriesTabState();
}

/// (3.31.0) Back of the phone on the Entries tab: a diesel page goes back to the list (true = done here). Set by the tab itself.
bool Function()? entriesBack;

/// Kept while the app is open: a day already seen shows at once (then it is read again).
final _entriesCache = <String, List<Map<String, dynamic>>>{};
/// (3.48.0, the performance work) at most the last 24 lists (a page and a day) in memory – the oldest goes first (was: every one
/// opened)
void _entriesKeep(String key, List<Map<String, dynamic>> rows) {
  _entriesCache.remove(key);
  _entriesCache[key] = rows;
  while (_entriesCache.length > 24) {
    _entriesCache.remove(_entriesCache.keys.first);
  }
}
void _entriesForget() => _entriesCache.clear(); // (update-155) emptied at sign-out and at another site (Session.clearMemory)

class _EntriesTabState extends State<EntriesTab> with LiveWhenSeen<EntriesTab> {
  String kind = '', day = '', place = '';
  /// (3.48.0, the performance work – measured: each letter typed built the whole page again, its top, the days, the search box)
  /// the search: each letter draws again only the count of the day and the list
  final _q = ValueNotifier<String>('');
  String get q => _q.value;
  bool loading = false;
  String err = '';
  List<Map<String, dynamic>> rows = [];
  int seq = 0;

  /// (3.31.0) the page was opened from elsewhere (Home, the +, the assistant): Back goes back there, not to the list
  bool _direct = false;
  String group = '';

  bool _back() {
    if (kind.isEmpty) return false;
    final direct = _direct;
    setState(() {
      kind = '';
      _direct = false;
    });
    return !direct;
  }

  @override
  void initState() {
    super.initState();
    entriesBack = _back;
  }

  @override
  void didUpdateWidget(covariant EntriesTab old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) liveMaybe();
    if (widget.kind.isNotEmpty && (widget.kind != old.kind || widget.open != old.open)) {
      kind = widget.kind;
      _direct = true;
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
      _direct = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
  }

  Session? _ls;
  // (3.1.7) live: an entry added or changed elsewhere (the web, another phone, an approval) – the list loads again by itself
  // (update-155) only when the tab is seen – else when it is seen again (lib/ui/live.dart)
  void _live() {
    if (mounted && kind.isNotEmpty && (_ls?.lastChanged.any((g) => g == 'stock' || g == 'master' || g == 'flow') ?? true)) liveChanged();
  }

  @override
  bool get liveActive => widget.active;
  @override
  void liveReload() {
    if (kind.isNotEmpty) _load();
  }

  @override
  void dispose() {
    if (entriesBack == _back) entriesBack = null;
    _ls?.dataTick.removeListener(_live);
    _q.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final s = SessionScope.read(context), k = kindOf(kind), my = ++seq, ck = '${s.site?.code}|$kind|$day';
    _ls ??= s..dataTick.addListener(_live);
    Session.memoryClears.add(_entriesForget);
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
        _entriesKeep(ck, rows);
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
      // (3.38.0 – Mechanical update-159, asked 25-10-2026) a transfer: only those sent FROM the place, as the web's list
      if (place.isNotEmpty && _placeOf(r) != place) return false;
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

  /// (3.1.8) the list of his pages of entries, one under the other.
  /// (3.31.0, his picture) "Your Entries": the groups on top (All · Diesel · Machinery · Log Book · Store), each page a card with
  /// what it is for; the search of the app and the robot at the top.
  Widget _menu(Session s) {
    final tankers = s.canSee('Log Book') && s.machines.any((m) => m.onSite(s.today) && m.waterTanker);
    final subs = {'issue': s.cardSite ? 'Fill a car – by its card or Cash' : 'Issue diesel to machinery/vehicle', 'inward': 'Record diesel inward at site', 'transfer': 'Transfer between store/dispensers'};
    final items = <(String, String, String, String, Color, String, VoidCallback)>[
      // (3.45.0, Mechanical update-164) a site on fuel cards keeps no stock: no Inward, no Transfer – and its page Fuel Cards
      for (final k in kKinds.where((k) => s.canSee(k.module) && !(s.cardSite && k.key != 'issue')))
        (k.en, k.key == 'transfer' ? 'Diesel Transfer' : k.en, k.mr, subs[k.key] ?? '', k.soft, 'Diesel', () {
          setState(() {
            kind = k.key;
            _direct = false;
            rows = [];
          });
          _load();
        }),
      if (s.cardSite && s.canSee('Fuel Cards')) ('Fuel Cards', 'Fuel Cards', 'फ्युएल कार्ड', 'The cards, their balance, payments and statement', C.amberSoft, 'Diesel', () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const FuelCardsScreen()))),
      // (3.46.0, Mechanical update-165) the bills of the cars at a site on fuel cards – its page Maintenance
      if (s.cardSite && s.canSee('Maintenance')) ('Maintenance', 'Maintenance', 'मेंटेनन्स', 'The bills of the cars, their files, a car\'s log book', C.blueSoft, 'Diesel', () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const MaintScreen()))),
      if (s.canSee('Log Book')) ('Log Book', 'Log Book', 'लॉग बुक', 'Daily running & working hours', C.purpleSoft, 'Log Book', () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const LogBookScreen()))),
      if (s.canSee('Breakdown')) ('Breakdown', 'Breakdown', 'ब्रेकडाऊन', 'Machinery working / breakdown', C.orangeSoft, 'Machinery', () => openBreakdown(context)),
      if (tankers) ('Tanker Trips', 'Tanker Trips', 'टँकर फेऱ्या', 'Water tanker trips & challans', C.blueSoft, 'Log Book', () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => TankerScreen(date: s.today)))),
      if (s.hasModule('store')) ('Store', 'Store', 'स्टोअर', 'Items inward / outward', C.amberSoft, 'Store', () => openStore(context)),
    ];
    const pics = {'Log Book': 'notebook', 'Breakdown': 'wrench', 'Tanker Trips': 'delivery_truck', 'Store': 'package', 'Fuel Cards': 'ledger', 'Maintenance': 'wrench'};
    final groups = ['Diesel', 'Machinery', 'Log Book', 'Store'].where((g) => items.any((x) => x.$6 == g)).toList();
    final shown = group.isEmpty || !groups.contains(group) ? items : items.where((x) => x.$6 == group).toList();
    Widget chip(String g, String label) {
      final on = group == g;
      return ChoiceChip(
        key: Key('eg-${g.isEmpty ? 'all' : g}'),
        label: Text(label),
        selected: on,
        showCheckmark: false,
        onSelected: (_) => setState(() => group = g),
        selectedColor: C.green,
        labelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: on ? Colors.white : C.ink),
        side: BorderSide(color: on ? C.green : C.line),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(Sp.edge, 8, Sp.edge, 30), children: [
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Your Entries', mr: 'तुमच्या एन्ट्री', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                Text(s.siteName, style: const TextStyle(fontSize: 14, color: C.muted, fontWeight: FontWeight.w500)),
              ]),
            ),
            IconButton(
              key: const Key('entries-search'),
              tooltip: tr('Search'),
              style: IconButton.styleFrom(backgroundColor: Colors.white, side: const BorderSide(color: C.line), fixedSize: const Size(40, 40)),
              onPressed: () => openSearch(context, entries: shellEntries ?? (_) {}, reports: shellReports ?? () {}),
              icon: const Icon(Icons.search_rounded, size: 22),
            ),
            const SizedBox(width: 6),
            const AskBot(size: 40),
          ]),
          const SizedBox(height: 14),
          if (items.isEmpty) const EmptyState('No pages of entries', 'Ask the Admin for access to Diesel Issue, Inward, Transfer or Log Book.', pic: 'locked_with_key'),
          if (groups.length > 1)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                chip('', 'All'),
                for (final g in groups) ...[const SizedBox(width: 8), chip(g, g)],
              ]),
            ),
          if (groups.length > 1) const SizedBox(height: 14),
          for (final x in shown)
            Padding(
              padding: const EdgeInsets.only(bottom: Sp.chips),
              child: Press(
                key: Key('entries-${x.$1}'),
                onTap: x.$7,
                radius: 18,
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(color: x.$5, borderRadius: BorderRadius.circular(15)),
                    alignment: Alignment.center,
                    child: Pic(pics[x.$1] ?? kKinds.firstWhere((k) => k.en == x.$1, orElse: () => kKinds.first).pic, size: 34),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(x.$2, mr: x.$3, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      Text(x.$4, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: C.muted)),
                    ]),
                  ),
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
    if (kind.isEmpty || !s.canSee(kindOf(kind).module) || (s.cardSite && kind != 'issue')) return _menu(s);
    final k = kindOf(kind);
    // the entries shown (the search, the place) and the day's total of them – worked out again for each letter typed
    String totalOf(List<Map<String, dynamic>> list) {
      final total = list.fold<num>(0, (a, r) => a + (asNum(r['qty']) ?? 0));
      // (3.44.0, Mechanical update-163) a site with more than one fuel: the day's total of each fuel – never added together
      final byFuel = <String, num>{};
      if (s.multiFuel) {
        for (final r in list) {
          final f = s.placeFuel('${k.key == 'issue' ? r['source'] : k.key == 'inward' ? r['location'] : r['from']}');
          byFuel[f] = (byFuel[f] ?? 0) + (asNum(r['qty']) ?? 0);
        }
      }
      // (3.45.0, Mechanical update-164) a site on fuel cards: a fill's fuel is its car's; the ₹ of the day too
      if (s.cardSite && k.key == 'issue') {
        byFuel.clear();
        for (final r in list) {
          final f = s.machine('${r['no'] ?? ''}')?.fuel ?? 'Diesel';
          byFuel[f] = (byFuel[f] ?? 0) + (asNum(r['qty']) ?? 0);
        }
      }
      final rupees = s.cardSite && k.key == 'issue' ? ' · ₹ ${fmtNum(list.fold<num>(0, (a, r) => a + (asNum(r['amount']) ?? 0)))}' : '';
      return (s.multiFuel ? [for (final e in byFuel.entries) '${e.key} ${fmtNum(e.value)} ${e.key == 'CNG' ? 'kg' : 'L'}'].join(' · ') : '${fmtNum(total)} L') + rupees;
    }

    Widget searched(Widget Function(List<Map<String, dynamic>> list) of) => ValueListenableBuilder<String>(valueListenable: _q, builder: (_, __, ___) => of(_shown));
    final today = s.today.isNotEmpty ? parseKey(s.today) : DateTime.now();
    final days = [for (var i = 0; i < 14; i++) today.subtract(Duration(days: i))];
    return Scaffold(
      // (3.31.0) above the gold + of the bar
      floatingActionButton: s.canEdit(k.module)
          ? Padding(
              padding: const EdgeInsets.only(bottom: 30),
              child: FloatingActionButton.extended(
              onPressed: _add,
              backgroundColor: k.color,
              foregroundColor: Colors.white,
              elevation: 3,
              shape: const StadiumBorder(),
              icon: const Icon(Icons.add_rounded, size: 26),
              label: const Text('New Entry', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ))
          : null,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: C.green,
          onRefresh: _load,
          child: CustomScrollView(slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
                child: Row(children: [
                  IconButton(tooltip: tr('All entries'), icon: const Icon(Icons.arrow_back_rounded), onPressed: () => setState(() {
                        kind = '';
                        _direct = false;
                      })),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(k.en, maxLines: 1, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800))),
                      Text(s.siteName, style: const TextStyle(fontSize: 15, color: C.muted, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                  IconButton.filledTonal(
                    tooltip: tr('Pick a date'),
                    style: IconButton.styleFrom(backgroundColor: C.greenSoft, foregroundColor: C.greenDark, fixedSize: const Size(50, 50)),
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_month_rounded),
                  ),
                  const SizedBox(width: 6),
                  const AskBot(size: 40),
                  PopupMenuButton<String>(
                    key: const Key('en-more'),
                    tooltip: tr('More'),
                    icon: const Icon(Icons.more_vert_rounded),
                    onSelected: _more,
                    itemBuilder: (_) => [
                      PopupMenuItem(key: const Key('en-guide'), value: 'guide', child: Text('About this page')),
                      PopupMenuItem(key: const Key('en-find'), value: 'find', child: Text('All dates & Export')),
                      if (s.superAdmin && k.key == 'issue') PopupMenuItem(key: const Key('en-sdel'), value: 'sdel', child: Text('Delete entries – Super Admin')),
                      // (3.45.0) a site on fuel cards: one fill at a time (its card and ₹) – no many at once, no Excel
                      if (s.canEdit(k.module) && k.key != 'inward' && !s.cardSite) PopupMenuItem(key: const Key('en-many'), value: 'many', child: Text('Multiple entries')),
                      if (s.canEdit(k.module) && !s.cardSite) PopupMenuItem(key: const Key('en-import'), value: 'import', child: Text('Import from Excel')),
                      if (s.canEdit(k.module) && !s.cardSite) PopupMenuItem(key: const Key('en-template'), value: 'template', child: Text('Download template')),
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
                padding: const EdgeInsets.fromLTRB(Sp.edge, 8, Sp.edge, 8),
                child: Row(children: [
                  Expanded(child: Text('${showDate(day)}, ${weekDays[parseKey(day).weekday - 1]}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700))),
                  if (!loading)
                    Flexible(
                      child: searched((list) {
                        final totalText = totalOf(list);
                        return Text('${list.length} ${list.length == 1 ? 'entry' : 'entries'}${totalText.isEmpty ? '' : ' · $totalText'}', textAlign: TextAlign.right, style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: k.color));
                      }),
                    ),
                ]),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(children: [
                  Expanded(
                    child: TextField(
                      onChanged: (v) => _q.value = v,
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
            else
              searched((list) => list.isEmpty
                  ? SliverToBoxAdapter(
                      child: EmptyState(rows.isEmpty ? 'No ${k.en.toLowerCase()} on this day' : 'Nothing matches', rows.isEmpty ? 'Pick another day, or add a new entry.' : 'Change the search or the filter.', pic: k.pic,
                          action: rows.isEmpty && s.canEdit(k.module) ? 'New Entry' : null, onAction: _add),
                    )
                  : SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 2, 16, 110),
                      sliver: SliverList.separated(
                        itemCount: list.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => EntryCard(kind: k, r: list[i], onChanged: _load),
                      ),
                    )),
          ]),
        ),
      ),
    );
  }
}

/// (3.44.0, Mechanical update-163) the unit of an entry: kg at a CNG place, L at the others (the place: the issue's source, the
/// inward's location, the transfer's From)
String unitOfEntry(Session s, String kindKey, Map r) => s.cardSite && kindKey == 'issue'      // (3.45.0) a site on fuel cards: the car's fuel
    ? (s.machine('${r['no'] ?? ''}')?.fuel == 'CNG' ? 'kg' : 'L')
    : s.placeUnit('${kindKey == 'issue' ? r['source'] : kindKey == 'inward' ? r['location'] : r['from']}') == 'kg' ? 'kg' : 'L';

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
            (Icons.local_shipping_outlined, [r['type'], if (asNum(r['amount']) != null) 'Paid by ${r['source']}' else r['source']].where((e) => '${e ?? ''}'.isNotEmpty).join('  |  ')),
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
        child: note.isEmpty ? _main(_unit(context)) : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _main(_unit(context)),
          Padding(padding: const EdgeInsets.only(top: 6, left: 4), child: Text(note, style: const TextStyle(fontSize: 13, color: C.muted, fontWeight: FontWeight.w600))),
        ]),
      );

  /// (3.44.0, Mechanical update-163) kg for an entry of a CNG place, L for the others
  String _unit(BuildContext context) => unitOfEntry(SessionScope.read(context), kind.key, r);

  Widget _main(String u) => Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
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
            Pill('${fmtNum(asNum(r['qty']))} $u', color: kind.color, bg: kind.soft, big: true),
            const SizedBox(height: 8),
            if ('${r['shift'] ?? ''}'.isNotEmpty) Text('${r['shift']} shift', style: const TextStyle(fontSize: 12.5, color: C.muted)),
            if ((kind.key == 'inward' || kind.key == 'issue') && asNum(r['amount']) != null) Text('₹ ${fmtNum(asNum(r['amount']))}', style: const TextStyle(fontSize: 12.5, color: C.muted)),      // (3.45.0: a card / cash fill too)
          ]),
        ]);

  void _details(BuildContext context) {
    final u = _unit(context);
    final rowsOf = <(String, String)>[
      ('Entry', '${r['id'] ?? ''}'),
      ('Date', '${showDate('${r['date'] ?? ''}')}${'${r['shift'] ?? ''}'.isNotEmpty ? ' · ${r['shift']} shift' : ''}'),
      if (kind.key == 'issue') ...[
        ('Machinery', '${r['no'] ?? ''}'),
        ('Type / Owner', [r['type'], r['owner']].where((e) => '${e ?? ''}'.isNotEmpty).join(' · ')),
        (asNum(r['amount']) != null ? 'Paid by' : 'Diesel from', '${r['source'] ?? ''}'),
        ('Amount', asNum(r['amount']) != null ? '₹ ${fmtNum(asNum(r['amount']))}${asNum(r['rate']) != null ? ' (₹ ${fmtNum(asNum(r['rate']))} / $u)' : ''}' : ''),      // (3.45.0)
        ('Reading', [asNum(r['kmReading']) != null ? '${fmtNum(asNum(r['kmReading']))} km' : '', asNum(r['hrReading']) != null ? '${fmtNum(asNum(r['hrReading']))} hr' : '', '${r['meter'] ?? ''}'].where((e) => e.isNotEmpty).join(' · ')),
        ('Operator', '${r['driver'] ?? ''}'),
        ('Photos', (asNum(r['ph']) ?? 0) > 0 ? '${fmtNum(asNum(r['ph']))} of 4' : ''),
        ('Stock after', asNum(r['balance']) != null ? '${fmtNum(asNum(r['balance']))} $u' : ''),
      ],
      if (kind.key == 'inward') ...[
        ('Pump', '${r['pump'] ?? ''}'),
        ('Received at', '${r['location'] ?? ''}'),
        ('Rate', asNum(r['rate']) != null ? '₹ ${fmtNum(asNum(r['rate']))} / $u' : ''),
        ('Amount', asNum(r['amount']) != null ? '₹ ${fmtNum(asNum(r['amount']))}' : ''),
        ('Bill', [r['billNo'], showDate('${r['billDate'] ?? ''}')].where((e) => '${e ?? ''}'.isNotEmpty).join(' · ')),
        ('Bill copy', (asNum(r['ph']) ?? 0) == 1 ? '1 photo' : (asNum(r['ph']) ?? 0) > 1 ? '${fmtNum(asNum(r['ph']))} photos' : ''),      // (3.1.13, update-120)
      ],
      if (kind.key == 'transfer') ...[('From', '${r['from'] ?? ''}'), ('To', '${r['to'] ?? ''}')],
      (u == 'kg' ? 'Kg' : 'Litres', '${fmtNum(asNum(r['qty']))} $u'),
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
              Pill('${fmtNum(asNum(r['qty']))} $u', color: kind.color, bg: kind.soft, big: true),
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
            // (3.33.0 – Mechanical update-152) approved in verification: locked as well
            if (r['lk'] == null && r['ap'] is Map) InfoLine(SessionScope.read(context).superAdmin ? 'This entry was approved – you are the Super Admin: your change asks for the reason, kept with its history.' : bi('This entry was approved – a change goes to the Super Admin for approval.', 'Approve झालेली entry – बदल Super Admin च्या मंजुरीने.'), icon: Icons.verified_outlined),
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
                        await s.api.call(deleteOf(kind.key), [r['id'], if ('${r['ver'] ?? ''}'.isNotEmpty) '${r['ver']}'], true); // (Mechanical update-145; update-156: every kind)
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
