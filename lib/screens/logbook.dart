/* LOG BOOK – the phone's own screens (asked 14-10-2026: "log book war click kel tr loading screen, errors, web UI … mobile UI
 * web peksha wegla, sagle web sarkhe 100% chalel"). The same server actions, checks and access as the web page:
 *   the day's entries (getLogBookList), the machinery still without a Log Book that day (logPending),
 *   a new entry – one machinery, one date + shift (getLogRowPrefill → saveLogRows): every way (KM, Hrs, KM + Hrs, Time with
 *   split timings and break, Trip, Day, Idle, Holiday, Breakdown, No reading with the estimate, a new meter), ½ day, the
 *   machinery's Log Book format (challan, particular, chainage, trips with time), Item-wise BOQ (pick or split), Debit to,
 *   opening diesel of a first entry;
 *   change an entry (getLogEntry → updateLogRow) and delete it (deleteLogRow) – a later entry follows by itself (server);
 *   a water tanker trip by trip (getTankerTrips / saveTankerTrips / deleteTankerTrip).
 * "One date – many machinery" and "One machinery – many dates" of the web: after a save, "Next machinery" (same date) or
 * "Next date" (same machinery) – the usual one first, as set in My settings. */
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/format.dart';
import '../core/kinds.dart';
import '../core/session.dart';
import '../ui/scope.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'forms.dart' show MachinePicker;

const kDayStatus = ['Idle', 'Holiday', 'Breakdown'];
const kLogShifts = ['Full Day', 'Day', 'Night'];

/// What a machinery's Log Book format asks for besides the readings (as the web: LB_FMT_NEEDS).
class FmtNeeds {
  const FmtNeeds({this.challan = false, this.part = false, this.noCh = false, this.tripTime = false, this.tripAll = false});
  final bool challan, part, noCh, tripTime, tripAll;
}

FmtNeeds needsOf(String f) => switch (f) {
      'B' => const FmtNeeds(tripAll: true),
      'C' => const FmtNeeds(noCh: true),
      'E' || 'F' || 'G' => const FmtNeeds(challan: true, part: true),
      'H' || 'I' => const FmtNeeds(challan: true, tripTime: true),
      _ => const FmtNeeds(),
    };

String itemKind(String basis) => basis == 'Per Hour' ? 'hr' : basis == 'Per KM' ? 'km' : basis == 'Per Trip' ? 'trip' : 'day';
const kItemWord = {'hr': 'hr', 'km': 'km', 'trip': 'trips'};

int? _min(String t) {
  final m = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(t);
  return m == null ? null : int.parse(m.group(1)!) * 60 + int.parse(m.group(2)!);
}

/// Hours of one From – To (a To not after its From runs past midnight).
num? slotHrs(String a, String b) {
  final x = _min(a), y = _min(b);
  if (x == null || y == null) return null;
  var d = y - x;
  if (d <= 0) d += 1440;
  return (d / 60 * 100).round() / 100;
}

/// Hours of all the From – To of an entry less the break (minutes) – as the web (slotsHrs).
num? slotsHrs(List<List<String>> sl, String brk) {
  if (sl.isEmpty) return null;
  var mins = 0;
  for (final x in sl) {
    final a = _min(x[0]), b = _min(x[1]);
    if (a == null || b == null) return null;
    var d = b - a;
    if (d <= 0) d += 1440;
    mins += d;
  }
  mins -= (num.tryParse(brk) ?? 0).clamp(0, 100000).toInt();
  return mins > 0 ? (mins / 60 * 100).round() / 100 : 0;
}

String _two(int n) => n.toString().padLeft(2, '0');

// =====================================================================================================================
//  THE DAY'S LOG BOOK
// =====================================================================================================================
class LogBookScreen extends StatefulWidget {
  const LogBookScreen({super.key});
  @override
  State<LogBookScreen> createState() => _LogBookScreenState();
}

/// Kept while the app is open: the Log Book opens at once with what it showed last (then it is read again).
final _logCache = <String, List<Map<String, dynamic>>>{};
Map<String, dynamic>? _pendCache;
DateTime? _pendAt;

class _LogBookScreenState extends State<LogBookScreen> {
  String day = '', q = '';
  bool loading = false;
  String err = '';
  List<Map<String, dynamic>> rows = [];
  int seq = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (day.isEmpty) {
      final s = SessionScope.read(context);
      day = s.today.isNotEmpty ? s.today : dateKey(DateTime.now());
      rows = _logCache['${s.site?.code}|$day'] ?? [];
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
  }

  Future<void> _load({bool pend = false}) async {
    final s = SessionScope.read(context), my = ++seq, key = '${s.site?.code}|$day';
    setState(() {
      loading = rows.isEmpty;
      err = '';
    });
    try {
      final jobs = <Future<void>>[
        s.api.call('getLogBookList', [{'from': day, 'to': day, 'all': true}]).then((r) {
          final list = ((r as Map)['rows'] as List? ?? []).whereType<Map>().map((m) => m.cast<String, dynamic>()).toList();
          list.sort((a, b) => '${a['no']}'.compareTo('${b['no']}'));
          _logCache[key] = list;
          if (my == seq) rows = list;
        }),
      ];
      if (pend || _pendCache == null || _pendAt == null || DateTime.now().difference(_pendAt!) > const Duration(minutes: 1)) {
        jobs.add(s.api.call('logPending').then((r) {
          _pendCache = (r as Map).cast<String, dynamic>();
          _pendAt = DateTime.now();
        }).catchError((_) {}));
      }
      await Future.wait(jobs);
      if (my != seq || !mounted) return;
      setState(() => loading = false);
    } catch (e) {
      if (my != seq || !mounted) return;
      setState(() {
        err = errText(e);
        loading = false;
      });
    }
  }

  List<String> get _pendingToday => [for (final x in (_pendCache?['items'] as List? ?? [])) if (x is List && x.length > 1 && '${x[1]}' == day) '${x[0]}']..sort();

  Future<void> _new({String no = ''}) async {
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => LogForm(date: day, no: no)));
    if (saved == true) _load(pend: true);
  }

  Future<void> _showPending() async {
    final s = SessionScope.read(context), list = _pendingToday;
    final pick = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (c) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(c).size.height * .75),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Align(alignment: Alignment.centerLeft, child: TwoLang('No Log Book yet – ${showDate(day)}', '${list.length} यंत्रांची नोंद बाकी', size: 18, weight: FontWeight.w700)),
            ),
            Flexible(
              child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), children: [
                for (final no in list)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Press(
                      onTap: s.canEdit('Log Book') ? () => Navigator.pop(c, no) : null,
                      radius: 16,
                      shadow: false,
                      padding: const EdgeInsets.all(10),
                      child: Row(children: [
                        Pic(picOfType(s.machine(no)?.type ?? ''), size: 34),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(no, style: const TextStyle(fontWeight: FontWeight.w700)),
                            Text([s.machine(no)?.type ?? '', s.machine(no)?.owner ?? ''].where((e) => e.isNotEmpty).join(' · '), style: const TextStyle(fontSize: 12.5, color: C.muted)),
                          ]),
                        ),
                        if (s.canEdit('Log Book')) const Pill('Add', icon: Icons.add_rounded),
                      ]),
                    ),
                  ),
              ]),
            ),
          ]),
        ),
      ),
    );
    if (pick != null && mounted) _new(no: pick);
  }

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    final today = s.today.isNotEmpty ? parseKey(s.today) : DateTime.now();
    final days = [for (var i = 0; i < 21; i++) today.subtract(Duration(days: i))];
    final words = q.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    // a water tanker's entry: one card per trip (as the web's list, update-105) – each with its own Change / Delete
    final view = [
      for (final r in rows)
        if (tripsOfRow(s, r) case final ts?)
          for (final (i, t) in ts.indexed) {...r, '_t': t, '_n': i + 1, if (i > 0) 'qty': null}
        else
          r
    ];
    final list = view.where((r) => words.isEmpty || words.every(r.values.map((v) => '$v').join(' ').toLowerCase().contains)).toList();
    final worked = rows.where((r) => !kDayStatus.contains('${r['mode'] ?? r['unit']}')).length;
    final pend = _pendingToday;
    final tankers = s.machines.any((m) => m.active && m.waterTanker);
    return Scaffold(
      floatingActionButton: s.canEdit('Log Book')
          ? FloatingActionButton.extended(
              onPressed: () => _new(),
              backgroundColor: C.blue,
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
              icon: const Icon(Icons.add_rounded, size: 26),
              label: const Text('New Entry', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            )
          : null,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: C.blue,
          onRefresh: () => _load(pend: true),
          child: CustomScrollView(slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(6, 6, 12, 4),
                child: Row(children: [
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_rounded)),
                  const Pic('notebook', size: 34),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Log Book', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                      Text(s.siteName, style: const TextStyle(fontSize: 14, color: C.muted, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                  if (tankers && s.canSee('Log Book'))
                    IconButton.filledTonal(
                      tooltip: 'Water tanker – trip by trip',
                      style: IconButton.styleFrom(backgroundColor: C.blueSoft, foregroundColor: C.blue, fixedSize: const Size(48, 48)),
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => TankerScreen(date: day))).then((_) => _load()),
                      icon: const Icon(Icons.water_drop_rounded),
                    ),
                  const SizedBox(width: 6),
                  IconButton.filledTonal(
                    tooltip: 'Pick a date',
                    style: IconButton.styleFrom(backgroundColor: C.blueSoft, foregroundColor: C.blue, fixedSize: const Size(48, 48)),
                    onPressed: () async {
                      final d = await showDatePicker(context: context, initialDate: parseKey(day), firstDate: DateTime(2024), lastDate: today);
                      if (d != null) {
                        setState(() {
                          day = dateKey(d);
                          rows = _logCache['${s.site?.code}|$day'] ?? [];
                        });
                        _load();
                      }
                    },
                    icon: const Icon(Icons.calendar_month_rounded),
                  ),
                ]),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 80,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                  itemCount: days.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final d = days[i], key = dateKey(d), on = key == day;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          day = key;
                          rows = _logCache['${s.site?.code}|$day'] ?? [];
                        });
                        _load();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 56,
                        decoration: BoxDecoration(color: on ? C.blue : Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: on ? C.blue : C.line)),
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Text(weekDays[d.weekday - 1], style: TextStyle(fontSize: 12.5, color: on ? Colors.white : C.muted)),
                          Text('${d.day}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: on ? Colors.white : C.ink)),
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
                  Text('${rows.length} ${rows.length == 1 ? 'entry' : 'entries'} · $worked worked', style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: C.blue)),
                ]),
              ),
            ),
            if (pend.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: Press(
                    onTap: _showPending,
                    color: C.amberSoft,
                    border: const Color(0xFFF3D9A4),
                    shadow: false,
                    padding: const EdgeInsets.all(12),
                    child: Row(children: [
                      const Icon(Icons.pending_actions_rounded, color: C.amber),
                      const SizedBox(width: 10),
                      Expanded(child: TwoLang('${pend.length} machinery without Log Book', 'नोंद बाकी – पाहा', size: 15, color: C.amber)),
                      const Icon(Icons.chevron_right_rounded, color: C.amber),
                    ]),
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(onChanged: (v) => setState(() => q = v), decoration: const InputDecoration(hintText: 'Search machinery, work, chainage…', prefixIcon: Icon(Icons.search_rounded), contentPadding: EdgeInsets.symmetric(vertical: 14))),
              ),
            ),
            if (loading)
              SliverList.separated(itemCount: 4, separatorBuilder: (_, __) => const SizedBox(height: 10), itemBuilder: (_, __) => const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Shimmer(height: 100)))
            else if (err.isNotEmpty)
              SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.all(16), child: InfoLine(err, bad: true)))
            else if (list.isEmpty)
              SliverToBoxAdapter(
                child: EmptyState(rows.isEmpty ? 'No Log Book entry on this day' : 'Nothing matches', rows.isEmpty ? 'Pick another day, or add a new entry.' : 'Change the search.', pic: 'notebook',
                    action: rows.isEmpty && s.canEdit('Log Book') ? 'New Entry' : null, onAction: () => _new()),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 110),
                sliver: SliverList.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => LogCard(r: list[i], onChanged: () => _load(pend: true)),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

/// What an entry measured, as one line: "60 km", "8 hr", "3 trips", "Idle" …
String workText(Map<String, dynamic> r) {
  final u = '${r['mode'] ?? r['unit'] ?? ''}';
  if (kDayStatus.contains(u)) return u;
  final parts = <String>[
    if (asNum(r['wkm']) != null) '${fmtNum(asNum(r['wkm']))} km',
    if (asNum(r['whr']) != null) '${fmtNum(asNum(r['whr']))} hr',
    if (u == 'Time' && asNum(r['tHrs']) != null && asNum(r['whr']) == null) '${fmtNum(asNum(r['tHrs']))} hr',
    if ((asNum(r['trip']) ?? 0) > 0) '${fmtNum(asNum(r['trip']))} trips',
    if (u == 'Day') 'worked',
  ];
  return parts.isEmpty ? u : parts.join(' · ');
}

/// The trips of a water tanker's entry (Log Book Format I), for the list: its saved trips; an older entry (made before trip by trip)
/// read the way the server reads it – its Trip count and challan nos, its time when it is one trip. null = not a tanker's trip entry.
List<Map<String, dynamic>>? tripsOfRow(Session s, Map<String, dynamic> r) {
  final m = s.machine('${r['no'] ?? ''}');
  if (m == null || !m.waterTanker || '${r['unit'] ?? r['mode'] ?? ''}' != 'Trip') return null;
  final tr = (r['itemWork'] as Map?)?['_trips'];
  if (tr is List && tr.isNotEmpty) {
    return [for (final t in tr.whereType<Map>()) {'c': '${t['c'] ?? ''}', 'a': '${t['a'] ?? ''}', 'b': '${t['b'] ?? ''}', 'ch': '${t['ch'] ?? ''}', 'u': '${t['u'] ?? ''}'}];
  }
  final n = ((asNum(r['trip']) ?? 0).round()).clamp(1, 999);
  final list = '${r['challan'] ?? ''}'.split(RegExp(r'\s*[,;]\s*')).where((x) => x.isNotEmpty).toList();
  final cnt = n > list.length ? n : list.length;
  final ch = '${r['chainage'] ?? ''}'.isNotEmpty ? '${r['chainage']}' : ['${r['chFrom'] ?? ''}', '${r['chTo'] ?? ''}'].where((x) => x.isNotEmpty).join(' – ');
  return [
    for (var i = 0; i < cnt; i++)
      {'c': i < list.length ? list[i] : '', 'a': cnt == 1 ? '${r['tStart'] ?? ''}' : '', 'b': cnt == 1 ? '${r['tEnd'] ?? ''}' : '', 'ch': ch, 'u': '${r['work'] ?? ''}', 'old': true},
  ];
}

class LogCard extends StatelessWidget {
  const LogCard({super.key, required this.r, this.onChanged});
  final Map<String, dynamic> r;
  final VoidCallback? onChanged;

  String get _way => '${r['mode'] ?? r['unit'] ?? ''}';

  String get _reads {
    String two(dynamic a, dynamic b, String u) => asNum(a) == null && asNum(b) == null ? '' : '${fmtNum(asNum(a))} – ${fmtNum(asNum(b))} $u';
    return [two(r['okm'], r['ckm'], 'km'), two(r['ohr'], r['chr'], 'hr'), if ('${r['tStart'] ?? ''}'.isNotEmpty) '${r['tStart']} – ${r['tEnd'] ?? ''}'].where((e) => e.isNotEmpty).join('   ');
  }

  Map<String, dynamic>? get _t => (r['_t'] as Map?)?.cast<String, dynamic>();

  /// One trip of a water tanker (update-105): its own card – trip no, challan, dispatch–unload, chainage, use for.
  Widget _tripCard(BuildContext context, Map<String, dynamic> t) {
    final time = '${t['a']}'.isNotEmpty ? '${t['a']} – ${t['b']}' : '';
    return Press(
      onTap: () => _tripDetails(context, t),
      padding: const EdgeInsets.all(12),
      child: Row(children: [
        Container(width: 64, height: 64, decoration: BoxDecoration(color: C.blueSoft.withValues(alpha: .7), borderRadius: BorderRadius.circular(18)), alignment: Alignment.center, child: Pic(picOfType('${r['type'] ?? ''}'), size: 48)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${r['no'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700)),
            Text('${t['c']}'.isNotEmpty ? 'Challan ${t['c']}' : 'No challan', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
            if (time.isNotEmpty) Text(time, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: C.blue)),
            if ('${t['ch']}${t['u']}'.isNotEmpty) Text([t['ch'], t['u']].where((e) => '$e'.isNotEmpty).join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: C.muted)),
            if (t['old'] == true) const Text('entered before trip by trip', style: TextStyle(fontSize: 12, color: C.muted)),
          ]),
        ),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Pill('Trip ${r['_n']}', color: C.blue, bg: C.blueSoft),
          const SizedBox(height: 6),
          Text('${r['shift'] ?? ''}', style: const TextStyle(fontSize: 12.5, color: C.muted)),
          if ((asNum(r['qty']) ?? 0) > 0) Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.local_gas_station_rounded, size: 14, color: C.green), Text(' ${fmtNum(asNum(r['qty']))} L', style: const TextStyle(fontSize: 12.5, color: C.green, fontWeight: FontWeight.w600))]),
        ]),
      ]),
    );
  }

  Future<void> _tripDetails(BuildContext context, Map<String, dynamic> t) async {
    final s = SessionScope.read(context);
    final rowsOf = <(String, String)>[
      ('Date', '${showDate('${r['date'] ?? ''}')} · ${r['shift'] ?? ''}'),
      ('Machinery', '${r['no'] ?? ''}'),
      ('Trip', '${r['_n']}${t['old'] == true ? '  (entered before trip by trip)' : ''}'),
      ('Challan', '${t['c']}'),
      ('Dispatch – Unload', '${t['a']}'.isEmpty ? '' : '${t['a']} – ${t['b']}'),
      ('Chainage', '${t['ch']}'),
      ('Use for', '${t['u']}'),
      ('Entered by', [r['enteredBy'], if ('${r['updatedBy'] ?? ''}'.isNotEmpty) 'changed by ${r['updatedBy']}'].where((e) => '${e ?? ''}'.isNotEmpty).join(' · ')),
    ].where((x) => x.$2.trim().isNotEmpty).toList();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (c) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 58, height: 58, decoration: BoxDecoration(color: C.blueSoft, borderRadius: BorderRadius.circular(18)), alignment: Alignment.center, child: Pic(picOfType('${r['type'] ?? ''}'), size: 44)),
              const SizedBox(width: 14),
              Expanded(child: TwoLang('${r['no'] ?? ''}', 'टँकर फेरी', size: 20, weight: FontWeight.w700)),
              Pill('Trip ${r['_n']}', color: C.blue, bg: C.blueSoft, big: true),
            ]),
            const SizedBox(height: 14),
            for (final x in rowsOf)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(width: 130, child: Text(x.$1, style: const TextStyle(color: C.muted, fontSize: 14))),
                  Expanded(child: Text(x.$2, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5))),
                ]),
              ),
            if (s.canEdit('Log Book')) ...[
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(foregroundColor: C.red, side: const BorderSide(color: C.redSoft)),
                    onPressed: () async {
                      Navigator.pop(c);
                      if (await deleteTrip(context, '${r['no']}', '${r['date']}', '${r['shift']}', r['_n'] as int, t)) onChanged?.call();
                    },
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('Delete'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: C.blue, minimumSize: const Size.fromHeight(52)),
                    onPressed: () async {
                      Navigator.pop(c);
                      await Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => TankerScreen(date: '${r['date']}', no: '${r['no']}', editShift: '${r['shift']}', editN: r['_n'] as int)));
                      onChanged?.call();
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

  @override
  Widget build(BuildContext context) {
    if (_t case final t?) return _tripCard(context, t);
    final st = kDayStatus.contains(_way);
    final color = st ? (_way == 'Idle' ? C.amber : C.red) : C.blue, soft = st ? (_way == 'Idle' ? C.amberSoft : C.redSoft) : C.blueSoft;
    return Press(
      onTap: () => _details(context),
      padding: const EdgeInsets.all(12),
      child: Row(children: [
        Container(width: 64, height: 64, decoration: BoxDecoration(color: soft.withValues(alpha: .7), borderRadius: BorderRadius.circular(18)), alignment: Alignment.center, child: Pic(picOfType('${r['type'] ?? ''}'), size: 48)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${r['no'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700)),
            Text([r['type'], r['owner']].where((e) => '${e ?? ''}'.isNotEmpty).join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: C.muted)),
            if (_reads.isNotEmpty) Text(_reads, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: C.muted)),
            if ('${r['work'] ?? ''}'.isNotEmpty || '${r['chFrom'] ?? ''}'.isNotEmpty)
              Text([if ('${r['chFrom'] ?? ''}'.isNotEmpty) 'Ch ${r['chFrom']}–${r['chTo'] ?? ''}', '${r['work'] ?? ''}'].where((e) => e.isNotEmpty).join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: C.muted)),
          ]),
        ),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Pill(workText(r), color: color, bg: soft),
          const SizedBox(height: 6),
          Text('${r['shift'] ?? ''}${r['half'] == true ? ' · ½' : ''}', style: const TextStyle(fontSize: 12.5, color: C.muted)),
          if ((asNum(r['qty']) ?? 0) > 0) Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.local_gas_station_rounded, size: 14, color: C.green), Text(' ${fmtNum(asNum(r['qty']))} L', style: const TextStyle(fontSize: 12.5, color: C.green, fontWeight: FontWeight.w600))]),
        ]),
      ]),
    );
  }

  Future<void> _details(BuildContext context) async {
    final s = SessionScope.read(context);
    final rowsOf = <(String, String)>[
      ('Date', '${showDate('${r['date'] ?? ''}')} · ${r['shift'] ?? ''}${r['half'] == true ? ' · ½ day' : ''}'),
      ('Machinery', '${r['no'] ?? ''}'),
      ('Type / Owner', [r['type'], r['owner']].where((e) => '${e ?? ''}'.isNotEmpty).join(' · ')),
      ('Measured by', _way),
      ('Readings', _reads),
      ('Work', workText(r)),
      ('Challan', '${r['challan'] ?? ''}'),
      ('Chainage', '${r['chFrom'] ?? ''}'.isEmpty ? '' : '${r['chFrom']} – ${r['chTo'] ?? ''}'),
      ('Work done', '${r['work'] ?? ''}'),
      ('Particular', '${r['remark'] ?? ''}'),
      ('Meter', '${r['meter'] ?? ''}'),
      ('Items', [for (final x in (r['itemQty'] as List? ?? []).whereType<Map>()) '${x['n']} ${fmtNum(asNum(x['q']))} ${kItemWord[x['k']] ?? ''}'].join(', ')),
      ('Debit to', '${r['debitTo'] ?? ''}'.isEmpty ? '' : '${r['debitTo']}${asNum(r['debitRate']) != null ? ' @ ₹${fmtNum(asNum(r['debitRate']))}' : ''}'),
      ('Diesel issued', (asNum(r['qty']) ?? 0) > 0 ? '${fmtNum(asNum(r['qty']))} L' : ''),
      ('Entered by', [r['enteredBy'], if ('${r['updatedBy'] ?? ''}'.isNotEmpty) 'changed by ${r['updatedBy']}'].where((e) => '${e ?? ''}'.isNotEmpty).join(' · ')),
    ].where((x) => x.$2.trim().isNotEmpty).toList();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (c) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 58, height: 58, decoration: BoxDecoration(color: C.blueSoft, borderRadius: BorderRadius.circular(18)), alignment: Alignment.center, child: Pic(picOfType('${r['type'] ?? ''}'), size: 44)),
              const SizedBox(width: 14),
              Expanded(child: TwoLang('${r['no'] ?? ''}', 'Log Book', size: 20, weight: FontWeight.w700)),
              Pill(workText(r), color: C.blue, bg: C.blueSoft, big: true),
            ]),
            const SizedBox(height: 14),
            for (final x in rowsOf)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(width: 118, child: Text(x.$1, style: const TextStyle(color: C.muted, fontSize: 14))),
                  Expanded(child: Text(x.$2, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5))),
                ]),
              ),
            if (s.canEdit('Log Book') && '${r['key'] ?? ''}'.isNotEmpty) ...[
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(foregroundColor: C.red, side: const BorderSide(color: C.redSoft)),
                    onPressed: () async {
                      Navigator.pop(c);
                      if (await deleteLog(context, '${r['key']}')) onChanged?.call();
                    },
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('Delete'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: C.blue, minimumSize: const Size.fromHeight(52)),
                    onPressed: () async {
                      Navigator.pop(c);
                      final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => LogForm(editKey: '${r['key']}')));
                      if (ok == true) onChanged?.call();
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

/// Deletes one trip of a water tanker (the other trips of its entry stay; the last trip takes its entry with it).
Future<bool> deleteTrip(BuildContext context, String no, String date, String shift, int n, Map<String, dynamic> t) async {
  final s = SessionScope.read(context);
  final what = '$no – ${showDate(date)} ($shift): trip $n${'${t['c']}'.isNotEmpty ? ', challan ${t['c']}' : ''}${'${t['a']}'.isNotEmpty ? ', ${t['a']}–${t['b']}' : ''}.';
  if (!await ask(context, 'Delete this trip?', '$what\n\nThe other trips of that entry stay. · बाकी फेऱ्या राहतील.', yes: 'Delete', danger: true)) return false;
  try {
    await s.api.call('deleteTankerTrip', [{'no': no, 'date': date, 'shift': shift, 'c': t['c']}], true);
    if (context.mounted) toast(context, 'Trip deleted.');
    return true;
  } catch (e) {
    if (context.mounted) toast(context, errText(e), bad: true);
    return false;
  }
}

/// Deletes a Log Book entry (as the web: the next entry then starts from the one before; a billed entry is locked).
Future<bool> deleteLog(BuildContext context, String key) async {
  final s = SessionScope.read(context);
  try {
    final e = ((await s.api.call('getLogEntry', [key])) as Map).cast<String, dynamic>();
    if (!context.mounted) return false;
    // (14-10-2026) an entry of a submitted bill: the Super Admin deletes it; anybody else may send the delete for his approval
    if (e['lock'] != null && !s.superAdmin &&
        !await ask(context, 'In a submitted bill', 'This entry is in a saved bill. You can delete it: on "Delete" it goes to the Super Admin for approval and is deleted only when he approves. · बिलमध्ये आहे – Super Admin च्या मंजुरीने.', yes: 'Go on')) {
      return false;
    }
    if (!context.mounted) return false;
    final km = hasKm('${e['unit']}'), hr = hasHr('${e['unit']}');
    String rd(dynamic k, dynamic h) => [if (km && asNum(k) != null) '${fmtNum(asNum(k))} km', if (hr && asNum(h) != null) '${fmtNum(asNum(h))} hr'].join(' / ');
    final next = e['next'] as Map?, prev = e['prev'] as Map?;
    final body = [
      '${e['no']} – ${showDate('${e['date']}')} (${e['shift']})',
      if (rd(e['okm'], e['ohr']).isNotEmpty) 'Start ${rd(e['okm'], e['ohr'])}  –  Close ${rd(e['ckm'], e['chr'])}',
      if (next != null) 'The next entry ${showDate('${next['date']}')} (${next['shift']}) will start from ${prev != null ? 'the Close of ${showDate('${prev['date']}')}' : 'its own Start'}; later entries update by themselves.',
      'This cannot be undone. · हे परत आणता येणार नाही.',
    ].join('\n\n');
    if (!await ask(context, 'Delete Log Book entry?', body, yes: 'Delete', danger: true)) return false;
    await s.api.call('deleteLogRow', [key], true);
    if (context.mounted) toast(context, 'Log Book entry deleted${next != null ? ' – later entries updated' : ''}.');
    return true;
  } catch (e) {
    if (context.mounted) toast(context, errText(e), bad: true);
    return false;
  }
}

// =====================================================================================================================
//  ONE ENTRY – new, or a change of a saved one
// =====================================================================================================================
class LogForm extends StatefulWidget {
  const LogForm({super.key, this.date = '', this.no = '', this.editKey = ''});
  final String date, no, editKey;
  @override
  State<LogForm> createState() => _LogFormState();
}

class _Item {
  _Item(this.name, this.basis, this.qty);
  final String name, basis, qty; // qty: 'rest' = gets what the others leave
  String get kind => itemKind(basis);
  bool get rest => qty == 'rest';
}

class _LogFormState extends State<LogForm> {
  String date = '', shift = 'Full Day', way = '';
  bool half = false, newMeter = false, busy = false, loadingP = false, savedOne = false;
  Machine? machine;
  Map<String, dynamic>? p; // the server's figures for this machinery, date and shift (or the saved entry when changing)
  String err = '', pErr = '';
  int pSeq = 0;
  final c = <String, TextEditingController>{};
  List<List<String>> slots = [
    ['', ''],
  ];
  final pick = <String, String>{}; // kind → item name / '_split' / ''
  String dayItem = '';

  bool get editing => widget.editKey.isNotEmpty;
  TextEditingController t(String k) => c.putIfAbsent(k, TextEditingController.new);
  String v(String k) => t(k).text.trim();
  num? n(String k) => asNum(v(k));
  List<_Item> get items => [for (final x in (p?['boqItems'] as List? ?? []).whereType<Map>()) _Item('${x['name']}', '${x['basis']}', '${x['qty']}')];
  FmtNeeds get needs => needsOf(machine?.lbFormat ?? 'A');
  bool get status => kDayStatus.contains(way);
  bool get off => way == kNoReading;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (date.isNotEmpty) return;
    final s = SessionScope.read(context);
    date = widget.date.isNotEmpty ? widget.date : (s.today.isNotEmpty ? s.today : dateKey(DateTime.now()));
    shift = s.myShift(kLogShifts); // (14-10-2026) his usual shift, else Day / Night by the time
    if (editing) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openEdit());
    } else if (widget.no.isNotEmpty) {
      machine = s.machine(widget.no);
      WidgetsBinding.instance.addPostFrameCallback((_) => _prefill());
    }
  }

  @override
  void dispose() {
    for (final x in c.values) {
      x.dispose();
    }
    super.dispose();
  }

  void _clearFigures() {
    for (final k in ['okm', 'ckm', 'ohr', 'chr', 'brk', 'trip', 'challan', 'part', 'estKm', 'estHr', 'meterNote', 'odsl']) {
      t(k).clear();
    }
    for (final k in c.keys.where((k) => k.startsWith('it:'))) {
      c[k]!.clear();
    }
    slots = [
      ['', ''],
    ];
    pick.clear();
    dayItem = '';
    newMeter = false;
  }

  /// The server's figures for the picked machinery, date and shift: Start readings, diesel issued, BOQ items, its average.
  Future<void> _prefill() async {
    final m = machine;
    if (m == null || editing) return;
    final s = SessionScope.read(context), my = ++pSeq;
    setState(() {
      loadingP = true;
      pErr = '';
    });
    try {
      final r = ((await s.api.call('getLogRowPrefill', [m.id, date, shift])) as Map).cast<String, dynamic>();
      if (my != pSeq || !mounted) return;
      setState(() {
        final changed = p == null || '${p!['machine']?['id']}' != m.id;
        p = r;
        loadingP = false;
        if (changed) {
          _clearFigures();
          way = m.wayAuto;
        }
        _startReadings();
      });
    } catch (e) {
      if (my != pSeq || !mounted) return;
      setState(() {
        loadingP = false;
        pErr = errText(e);
      });
    }
  }

  /// The Start comes from the previous entry (the server's answer); typed over, it is the person's.
  void _startReadings() {
    final r = p;
    if (r == null) return;
    if (hasKm(way) && v('okm').isEmpty && asNum(r['openingKm']) != null) t('okm').text = fmtNum(asNum(r['openingKm'])).replaceAll(',', '');
    if (hasHr(way) && v('ohr').isEmpty && asNum(r['openingHr']) != null) t('ohr').text = fmtNum(asNum(r['openingHr'])).replaceAll(',', '');
    if (off) {
      final a = (r['avgWork'] as Map?) ?? {};
      if (_canK && v('estKm').isEmpty && asNum(a['km']) != null) t('estKm').text = '${asNum(a['km'])!.round()}';
      if (_canH && v('estHr').isEmpty && asNum(a['hr']) != null) t('estHr').text = '${(asNum(a['hr'])! * 2).round() / 2}';
    }
  }

  bool get _canK => machine != null && machine!.modes.any(hasKm);
  bool get _canH => machine != null && machine!.modes.any(hasHr);

  /// A saved entry to change (getLogEntry): its values in the boxes; its machinery, date, shift and way stay.
  Future<void> _openEdit() async {
    final s = SessionScope.read(context);
    setState(() => loadingP = true);
    try {
      final e = ((await s.api.call('getLogEntry', [widget.editKey])) as Map).cast<String, dynamic>();
      if (!mounted) return;
      String g(String k) => '${e[k] ?? ''}';
      setState(() {
        p = e;
        loadingP = false;
        date = g('date');
        shift = g('shift');
        half = e['half'] == true;
        machine = s.machine(g('no'));
        way = g('unit');
        t('okm').text = g('okm');
        t('ckm').text = g('ckm');
        t('ohr').text = g('ohr');
        t('chr').text = g('chr');
        t('trip').text = g('trip');
        t('challan').text = g('challan');
        t('chFrom').text = g('chFrom');
        t('chTo').text = g('chTo');
        t('work').text = g('work').isNotEmpty ? g('work') : g('remark');
        t('debitTo').text = g('debitTo');
        t('debitRate').text = g('debitRate');
        t('odsl').text = g('odsl');
        if (off) {
          t('estKm').text = g('wkm');
          t('estHr').text = g('whr');
          t('meterNote').text = g('meter').replaceFirst(RegExp(r'^No reading – '), '');
        }
        if (way == 'Time') {
          final sp = RegExp(r'(\d{1,2}:\d{2})\s*-\s*(\d{1,2}:\d{2})').allMatches(g('tSlots')).map((m) => [m.group(1)!, m.group(2)!]).toList();
          slots = sp.isNotEmpty ? sp : [[g('tStart'), g('tEnd')]];
          // the Break box holds the break typed (a split's saved break also holds the gaps between its times)
          final brk = asNum(e['tBrk']);
          t('brk').text = brk == null ? '' : '${(brk - _gaps(slots)).clamp(0, 100000)}'.replaceAll(RegExp(r'\.0$'), '');
          if (t('brk').text == '0' && slots.length > 1) t('brk').clear();
        } else {
          slots = [[g('tStart'), g('tEnd')]];
        }
        final iw = (e['itemWork'] as Map?) ?? {};
        for (final it in items) {
          if (!it.rest && asNum(iw[it.name]) != null) t('it:${it.name}').text = '${asNum(iw[it.name])}';
        }
        dayItem = '${iw['_day'] ?? ''}';
        _pickFromTyped();
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          loadingP = false;
          pErr = errText(e);
        });
      }
    }
  }

  /// Minutes between the times of a split (as the web: slotsGap).
  int _gaps(List<List<String>> sl) {
    int? cur;
    int? first;
    var mins = 0;
    for (final x in sl) {
      final a = _min(x[0]), b = _min(x[1]);
      if (a == null || b == null) return 0;
      var d = b - a;
      if (d <= 0) d += 1440;
      var at = a;
      if (cur != null) {
        while (at < cur) {
          at += 1440;
        }
      }
      first ??= at;
      cur = at + d;
      mins += d;
    }
    return first == null ? 0 : (cur! - first) - mins;
  }

  // ---------- the totals of the entry ----------
  num? get workKm => hasKm(way) && n('ckm') != null && n('okm') != null ? ((n('ckm')! - n('okm')!) * 100).round() / 100 : (off ? n('estKm') : null);
  num? get workHr => hasHr(way) && n('chr') != null && n('ohr') != null ? ((n('chr')! - n('ohr')!) * 100).round() / 100 : (off ? n('estHr') : null);
  num? get timeHrs => way == 'Time' ? slotsHrs(slots, v('brk')) : null;
  num total(String kind) => switch (kind) {
        'hr' => (way == 'Time' ? timeHrs : workHr) ?? 0,
        'km' => workKm ?? 0,
        _ => way == 'Trip' || needs.tripAll ? (n('trip') ?? 0) : (asNum(p?['trip']) ?? 0),
      };

  // ---------- Item-wise BOQ (pick one work for the whole entry, or split it) ----------
  List<_Item> _of(String kind) => items.where((i) => i.kind == kind).toList();

  void _pickFromTyped() {
    for (final k in ['hr', 'km', 'trip']) {
      final its = _of(k);
      if (its.length < 2) continue;
      final typed = its.where((i) => !i.rest && (asNum(v('it:${i.name}')) ?? 0) > 0).toList();
      final tot = total(k);
      final rest = its.where((i) => i.rest).toList();
      pick[k] = typed.isEmpty ? (rest.isNotEmpty ? rest.first.name : '_split') : typed.length == 1 && tot > 0 && (asNum(v('it:${typed.first.name}'))! - tot).abs() < .005 ? typed.first.name : '_split';
    }
  }

  Map<String, dynamic>? _itemsOut() {
    if (items.isEmpty || way == 'Holiday' || way == 'Breakdown') return null;
    final o = <String, dynamic>{};
    for (final k in ['hr', 'km', 'trip']) {
      final its = _of(k);
      if (its.isEmpty || way == 'Idle') continue;
      final pk = pick[k] ?? '', tot = total(k);
      for (final it in its.where((i) => !i.rest)) {
        if (its.length > 1 && pk != '_split') {
          o[it.name] = pk == it.name && tot > 0 ? tot : '';
        } else {
          o[it.name] = asNum(v('it:${it.name}')) ?? '';
        }
      }
    }
    final days = _of('day');
    if (days.length > 1) o['_day'] = dayItem.isNotEmpty ? dayItem : days.first.name;
    return o;
  }

  String? _itemProblem() {
    if (items.isEmpty || way == 'Holiday' || way == 'Breakdown' || way == 'Idle') return null;
    for (final k in ['hr', 'km', 'trip']) {
      final its = _of(k);
      if (its.length > 1 && (pick[k] ?? '').isEmpty && !editing) return 'Pick the work of this entry (${its.map((i) => i.name).join(' / ')}) – or Split.';
      if (its.length > 1 && pick[k] == '_split') {
        final sum = its.where((i) => !i.rest).fold<num>(0, (a, i) => a + (asNum(v('it:${i.name}')) ?? 0));
        if (sum > total(k) + .005) return 'The works typed (${fmtNum(sum)} ${kItemWord[k]}) are more than the entry (${fmtNum(total(k))} ${kItemWord[k]}).';
      }
    }
    return null;
  }

  // ---------- pickers ----------
  Future<void> _pickDate() async {
    final s = SessionScope.read(context);
    final d = await showDatePicker(context: context, initialDate: parseKey(date), firstDate: DateTime(2024), lastDate: s.today.isNotEmpty ? parseKey(s.today) : DateTime.now());
    if (d == null) return;
    setState(() => date = dateKey(d));
    _prefill();
  }

  Future<void> _pickMachine() async {
    final m = await showModalBottomSheet<Machine>(context: context, isScrollControlled: true, useSafeArea: true, builder: (_) => const MachinePicker());
    if (m == null || !mounted) return;
    if (m.waterTanker) {
      toast(context, '${m.id} is a water tanker – its trips are entered in "Water tanker – trip by trip".', bad: true);
      return;
    }
    setState(() {
      machine = m;
      p = null;
      way = m.wayAuto;
      _clearFigures();
    });
    _prefill();
  }

  Future<void> _time(int i, int j) async {
    final cur = _min(slots[i][j]);
    final tm = await showTimePicker(context: context, initialTime: cur == null ? const TimeOfDay(hour: 8, minute: 0) : TimeOfDay(hour: cur ~/ 60, minute: cur % 60));
    if (tm != null) setState(() => slots[i][j] = '${_two(tm.hour)}:${_two(tm.minute)}');
  }

  // ---------- save ----------
  String? _check() {
    if (machine == null) return 'Pick the machinery.';
    if (p == null) return pErr.isNotEmpty ? pErr : 'Wait – the figures of this machinery are being read.';
    if (way.isEmpty) return 'Pick "Measured by" (KM / Hrs / Time / Trip / Day / Idle / Holiday / Breakdown).';
    if (hasKm(way) && v('ckm').isEmpty) return 'Enter the Close KM reading.';
    if (hasHr(way) && v('chr').isEmpty) return 'Enter the Close hour meter reading.';
    if ((workKm ?? 0) < 0 || (workHr ?? 0) < 0) return 'Close is less than Start.';
    if (way == 'Time' && slots.any((x) => x[0].isEmpty || x[1].isEmpty)) return 'Enter the From and To time${slots.length > 1 ? ' in every time line' : ''}.';
    if (way == 'Trip' && !((n('trip') ?? 0) > 0)) return 'Enter the number of trips.';
    if (off && v('meterNote').isEmpty) return 'Say why there is no reading (e.g. meter not working).';
    if (newMeter && v('meterNote').isEmpty) return 'Say why the meter is new (e.g. meter changed).';
    return _itemProblem();
  }

  num? _num(String k) => v(k).isEmpty ? null : asNum(v(k));

  Map<String, dynamic> _row() {
    final tripOn = way == 'Trip' || (needs.tripAll && !status);
    return {
      'date': date, 'shift': shift, 'half': half, 'no': machine!.id, 'mode': way,
      'openingKm': hasKm(way) ? (_num('okm') ?? '') : '', 'closingKm': hasKm(way) ? (_num('ckm') ?? '') : '',
      'openingHr': hasHr(way) ? (_num('ohr') ?? '') : '', 'closingHr': hasHr(way) ? (_num('chr') ?? '') : '',
      'tStart': way == 'Time' || (way == 'Trip' && needs.tripTime) ? slots.first[0] : '',
      'tEnd': way == 'Time' ? slots.last[1] : (way == 'Trip' && needs.tripTime ? slots.first[1] : ''),
      if (way == 'Time') 'tSlots': slots,
      'tBreak': way == 'Time' ? (_num('brk') ?? '') : '',
      'trip': tripOn ? (_num('trip') ?? '') : '',
      'challan': way.isNotEmpty && !status ? v('challan') : '',
      'remark': v('part'),
      'openingDiesel': p?['first'] == true ? (_num('odsl') ?? '') : '',
      'chFrom': v('chFrom'), 'chTo': v('chTo'), 'work': v('work'), 'debitTo': v('debitTo'), 'debitRate': v('debitRate'),
      'estKm': off ? v('estKm') : '', 'estHr': off ? v('estHr') : '', 'meterNote': off || newMeter ? v('meterNote') : '', 'meter': newMeter ? 'new' : '',
      if (_itemsOut() != null) 'items': _itemsOut(),
    };
  }

  Map<String, dynamic> _change() {
    final km = hasKm(way), hr = hasHr(way);
    return {
      'openingKm': km ? (_num('okm') ?? '') : '', 'closingKm': km ? (_num('ckm') ?? '') : '', 'openingHr': hr ? (_num('ohr') ?? '') : '', 'closingHr': hr ? (_num('chr') ?? '') : '',
      'openingDiesel': p?['first'] == true ? (_num('odsl') ?? '') : '',
      'chFrom': v('chFrom'), 'chTo': v('chTo'), 'work': v('work'), 'debitTo': v('debitTo'), 'debitRate': v('debitRate'),
      if (off) ...{'estKm': v('estKm'), 'estHr': v('estHr'), 'meterNote': v('meterNote')},
      'tStart': way == 'Time' ? slots.first[0] : '', 'tEnd': way == 'Time' ? slots.last[1] : '',
      if (way == 'Time') 'tSlots': slots,
      'tTimes': way == 'Time' ? slots.map((x) => '${x[0]} – ${x[1]}').join(', ') : '',
      'tBreak': way == 'Time' ? v('brk') : '', 'trip': way == 'Trip' ? v('trip') : '', 'challan': status ? '' : v('challan'),
      if (_itemsOut() != null) 'items': _itemsOut(),
    };
  }

  Future<void> _save() async {
    final bad = _check();
    if (bad != null) {
      setState(() => err = bad);
      HapticFeedback.mediumImpact();
      return;
    }
    final s = SessionScope.read(context);
    FocusScope.of(context).unfocus();
    setState(() {
      busy = true;
      err = '';
    });
    try {
      if (editing) {
        await s.api.call('updateLogRow', [widget.editKey, _change()], true);
        if (!mounted) return;
        toast(context, 'Log Book of ${machine?.id} (${showDate(date)}) updated. · बदल जतन झाला.');
        Navigator.pop(context, true);
        return;
      }
      final res = ((await s.api.call('saveLogRows', [{'rows': [_row()]}], true)) as Map).cast<String, dynamic>();
      if (!mounted) return;
      if (res['ok'] == false) {
        final errs = (res['errors'] as List? ?? []).whereType<Map>().map((x) => '${x['msg'] ?? ''}'.replaceFirst(RegExp(r'^Error:\s*'), '')).where((x) => x.isNotEmpty).toList();
        setState(() {
          busy = false;
          err = 'Nothing saved – ${errs.isEmpty ? 'check the entry' : errs.join('\n')}';
        });
        return;
      }
      savedOne = true;
      _pendAt = null;
      HapticFeedback.lightImpact();
      setState(() => busy = false);
      await _savedSheet();
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          err = errText(e);
        });
      }
    }
  }

  Future<void> _savedSheet() async {
    final s = SessionScope.read(context), byMachine = s.pref('lbMode') == 'mach', m = machine!;
    final next = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: false,
      builder: (c) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 26, 22, 26),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 520),
              curve: Curves.elasticOut,
              builder: (_, x, ch) => Transform.scale(scale: x, child: ch),
              child: Container(width: 74, height: 74, decoration: const BoxDecoration(color: C.blueSoft, shape: BoxShape.circle), child: const Icon(Icons.check_rounded, color: C.blue, size: 44)),
            ),
          ),
          const SizedBox(height: 12),
          const TwoLang('Log Book saved', 'नोंद झाली', size: 21, weight: FontWeight.w700, align: CrossAxisAlignment.center),
          const SizedBox(height: 6),
          Text('${m.id} · ${showDate(date)} · $shift · ${workText({'mode': way, 'wkm': workKm, 'whr': way == 'Time' ? timeHrs : workHr, 'trip': n('trip')})}', textAlign: TextAlign.center, style: const TextStyle(color: C.muted, fontWeight: FontWeight.w500)),
          const SizedBox(height: 20),
          for (final o in byMachine ? ['date', 'machine'] : ['machine', 'date'])
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: o == 'machine'
                  ? FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: C.blue, minimumSize: const Size.fromHeight(52)), onPressed: () => Navigator.pop(c, 'machine'), icon: const Icon(Icons.add_rounded), label: Text('Next machinery – ${showDate(date)}'))
                  : OutlinedButton.icon(onPressed: () => Navigator.pop(c, 'date'), icon: const Icon(Icons.skip_next_rounded), label: Text('Next date – ${m.id}')),
            ),
          TextButton(onPressed: () => Navigator.pop(c, 'done'), child: const Text('Done')),
        ]),
      ),
    );
    if (!mounted) return;
    if (next == 'machine') {
      setState(() {
        machine = null;
        p = null;
        way = '';
        half = false;
        _clearFigures();
        for (final k in ['chFrom', 'chTo', 'work', 'debitTo', 'debitRate']) {
          t(k).clear();
        }
      });
    } else if (next == 'date') {
      // one machinery: next shift / next date (as the web)
      final today = s.today.isNotEmpty ? s.today : dateKey(DateTime.now());
      var d = date, sh = shift;
      if (shift == 'Day') {
        sh = 'Night';
      } else {
        d = dateKey(parseKey(date).add(const Duration(days: 1)));
        if (shift == 'Night') sh = 'Day';
      }
      if (d.compareTo(today) > 0) {
        toast(context, 'Log Book can be filled only up to today (${showDate(today)}).', bad: true);
        Navigator.pop(context, true);
        return;
      }
      setState(() {
        date = d;
        shift = sh;
        half = false;
        p = null;
        _clearFigures();
        for (final k in ['work', 'debitTo', 'debitRate']) {
          t(k).clear();
        }
      });
      _prefill();
    } else {
      Navigator.pop(context, true);
    }
  }

  // ---------- the screen ----------
  Widget _label(String en, [String mr = '']) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 8, left: 2),
        child: Row(children: [
          Text(en, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          if (mr.isNotEmpty) Text('  $mr', style: const TextStyle(fontFamily: 'NotoDeva', fontSize: 12.5, color: C.muted)),
        ]),
      );

  Widget _chips(List<String> items, String value, ValueChanged<String> onPick, {bool enabled = true}) => Wrap(spacing: 8, runSpacing: 8, children: [
        for (final it in items)
          ChoiceChip(
            label: Text(it),
            selected: it == value,
            onSelected: enabled ? (_) => onPick(it) : null,
            showCheckmark: false,
            labelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: it == value ? Colors.white : C.ink),
            selectedColor: kDayStatus.contains(it) ? (it == 'Idle' ? C.amber : C.red) : C.blue,
            disabledColor: it == value ? C.blue : C.bg,
            backgroundColor: Colors.white,
            side: BorderSide(color: it == value ? Colors.transparent : C.line),
            shape: const StadiumBorder(),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          ),
      ]);

  Widget _num2(String a, String la, String b, String lb, {String unit = ''}) => Row(children: [
        Expanded(child: TextField(controller: t(a), keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(() {}), decoration: InputDecoration(labelText: la, suffixText: unit))),
        const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Icon(Icons.arrow_forward_rounded, color: C.faint)),
        Expanded(child: TextField(controller: t(b), keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(() {}), decoration: InputDecoration(labelText: lb, suffixText: unit))),
      ]);

  Widget _field(String k, String hint, {TextInputType? kb, IconData? icon}) => TextField(controller: t(k), keyboardType: kb, onChanged: (_) => setState(() {}), decoration: InputDecoration(hintText: hint, prefixIcon: icon == null ? null : Icon(icon)));

  Widget _timeBox(int i, int j) => Expanded(
        child: Press(
          onTap: () => _time(i, j),
          radius: 16,
          shadow: false,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Row(children: [
            Icon(j == 0 ? Icons.play_circle_outline_rounded : Icons.stop_circle_outlined, color: C.blue, size: 20),
            const SizedBox(width: 8),
            Text(slots[i][j].isEmpty ? (j == 0 ? 'From' : 'To') : slots[i][j], style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: slots[i][j].isEmpty ? C.faint : C.ink)),
          ]),
        ),
      );

  Widget _items() {
    if (items.isEmpty || way.isEmpty || way == 'Holiday' || way == 'Breakdown') return const SizedBox.shrink();
    final out = <Widget>[];
    if (way != 'Idle') {
      for (final k in ['hr', 'km', 'trip']) {
        final its = _of(k);
        if (its.isEmpty) continue;
        final pk = pick[k] ?? '';
        if (its.length > 1) {
          out.add(Padding(padding: const EdgeInsets.only(bottom: 6), child: Text('Work (${kItemWord[k]}) – ${fmtNum(total(k))} ${kItemWord[k]}', style: const TextStyle(fontSize: 13, color: C.muted))));
          out.add(_chips([...its.map((i) => i.name), 'Split'], pk == '_split' ? 'Split' : pk, (x) => setState(() => pick[k] = x == 'Split' ? '_split' : x), enabled: true));
        }
        if (its.length == 1 || pk == '_split') {
          for (final it in its.where((i) => !i.rest)) {
            out.add(Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TextField(controller: t('it:${it.name}'), keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(() {}), decoration: InputDecoration(labelText: it.name, suffixText: kItemWord[k])),
            ));
          }
          final rest = its.where((i) => i.rest).toList();
          if (rest.isNotEmpty && pk == '_split') {
            final typed = its.where((i) => !i.rest).fold<num>(0, (a, i) => a + (asNum(v('it:${i.name}')) ?? 0));
            out.add(Padding(padding: const EdgeInsets.only(top: 6), child: Text('${rest.first.name}: ${fmtNum((total(k) - typed).clamp(0, 1e9))} ${kItemWord[k]} (the rest)', style: const TextStyle(fontSize: 13, color: C.muted))));
          }
        }
        out.add(const SizedBox(height: 10));
      }
    }
    final days = _of('day');
    if (days.length > 1) {
      out.add(const Text('Day item', style: TextStyle(fontSize: 13, color: C.muted)));
      out.add(const SizedBox(height: 6));
      out.add(_chips(days.map((i) => i.name).toList(), dayItem.isNotEmpty ? dayItem : days.first.name, (x) => setState(() => dayItem = x)));
    }
    if (out.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [_label('Items (BOQ)', 'कामे'), ...out]);
  }

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    final m = machine;
    final fmt = needs;
    final ways = m == null ? <String>[] : [...m.modes, ...kDayStatus, if (m.modes.any((w) => hasKm(w) || hasHr(w))) kNoReading];
    final canNewMeter = !editing && p != null && !off && (hasKm(way) || hasHr(way)) && !((hasKm(way) && p!['firstKm'] == true) || (hasHr(way) && !hasKm(way) && p!['firstHr'] == true));
    final multiRows = editing && (p?['itemParts'] as List?) != null && (p!['itemParts'] as List).length > 1;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, savedOne);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => Navigator.pop(context, savedOne)),
          titleSpacing: 0,
          title: Row(children: [
            const Pic('notebook', size: 30),
            const SizedBox(width: 10),
            Expanded(child: TwoLang(editing ? 'Change Log Book' : 'New Log Book entry', 'लॉगबुक नोंद', size: 19, weight: FontWeight.w700)),
          ]),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 130),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (editing && loadingP && p == null) ...[const SizedBox(height: 20), const Shimmer(height: 300)],
            if (!editing || p != null) ...[
              _label('Date', 'तारीख'),
              Press(
                onTap: editing ? null : _pickDate,
                radius: 18,
                shadow: false,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(children: [
                  const Icon(Icons.calendar_month_rounded, color: C.blue),
                  const SizedBox(width: 12),
                  Expanded(child: Text(showDate(date), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
                  if (date == s.today) const Pill('Today', color: C.blue, bg: C.blueSoft),
                ]),
              ),
              _label('Shift', 'पाळी'),
              Row(children: [
                Expanded(
                  child: _chips(kLogShifts, shift, (x) {
                    setState(() => shift = x);
                    _prefill();
                  }, enabled: !editing),
                ),
                FilterChip(
                  label: const Text('½ day'),
                  selected: half,
                  onSelected: editing ? null : (x) => setState(() => half = x),
                  selectedColor: C.blueSoft,
                  checkmarkColor: C.blue,
                  shape: const StadiumBorder(),
                  side: const BorderSide(color: C.line),
                ),
              ]),
              _label('Machinery', 'यंत्र'),
              Press(
                onTap: editing ? null : _pickMachine,
                radius: 18,
                shadow: false,
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  Container(width: 52, height: 52, decoration: BoxDecoration(color: C.blueSoft, borderRadius: BorderRadius.circular(16)), alignment: Alignment.center, child: m == null ? const Icon(Icons.search_rounded, color: C.blue) : Pic(picOfType(m.type), size: 40)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: m == null
                        ? const TwoLang('Pick the machinery', 'यंत्र निवडा', color: C.muted)
                        : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(m.id, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                            Text([m.type, m.owner, if (m.lbFormat != 'A') 'Format ${m.lbFormat}'].where((e) => e.isNotEmpty).join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: C.muted, fontSize: 13)),
                          ]),
                  ),
                  if (!editing) const Icon(Icons.unfold_more_rounded, color: C.muted),
                ]),
              ),
              if (loadingP) const Padding(padding: EdgeInsets.only(top: 10), child: LinearProgressIndicator(minHeight: 3, color: C.blue, backgroundColor: C.blueSoft)),
              if (pErr.isNotEmpty) InfoLine(pErr, bad: true),
              if (p != null && !editing) ...[
                if ('${p!['problem'] ?? ''}'.isNotEmpty) InfoLine('${p!['problem']}', bad: true),
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: C.blueSoft.withValues(alpha: .6), borderRadius: BorderRadius.circular(16)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(p!['first'] == true ? 'First entry of this machinery' : 'Last entry: ${showDate('${p!['lastDate'] ?? ''}')} (${p!['lastShift'] ?? ''})', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: C.blue)),
                    Text('Diesel issued this ${shift == 'Full Day' ? 'date' : 'shift'}: ${fmtNum(asNum(p!['diesel']) ?? 0)} L${'${p!['dieselText'] ?? ''}'.isNotEmpty ? ' (${p!['dieselText']})' : ''}', style: const TextStyle(fontSize: 13, color: C.blue)),
                  ]),
                ),
              ],
              if (m != null && (p != null)) ...[
                _label('Measured by', 'मोजणी'),
                _chips(ways, way, (x) {
                  setState(() {
                    way = x;
                    if (x == kNoReading) newMeter = false;
                    _startReadings();
                  });
                }, enabled: !editing),
              ],
              if (multiRows) const InfoLine('This shift has a row for each work – change its readings and works on the web (Edit Log Book).', icon: Icons.info_outline_rounded),
              // ---------- the figures of the way picked ----------
              if (way.isNotEmpty && !multiRows) ...[
                if (hasKm(way)) ...[_label('KM reading', 'KM'), _num2('okm', 'Start', 'ckm', 'Close', unit: 'km'), if (workKm != null) _work('${fmtNum(workKm)} km')],
                if (hasHr(way)) ...[_label('Hour meter', 'तास'), _num2('ohr', 'Start', 'chr', 'Close', unit: 'hr'), if (workHr != null) _work('${fmtNum(workHr)} hr')],
                if (canNewMeter)
                  CheckboxListTile(
                    value: newMeter,
                    onChanged: (x) => setState(() {
                      newMeter = x == true;
                      if (newMeter) {
                        t('okm').clear();
                        t('ohr').clear();
                      } else {
                        _startReadings();
                      }
                    }),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text('A NEW meter was fitted – its Start is typed here', style: TextStyle(fontSize: 14)),
                  ),
                if (way == 'Time') ...[
                  _label('Time', 'वेळ'),
                  for (var i = 0; i < slots.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(children: [
                        _timeBox(i, 0),
                        const SizedBox(width: 8),
                        _timeBox(i, 1),
                        SizedBox(width: 56, child: Text(slotHrs(slots[i][0], slots[i][1]) == null ? '' : '${fmtNum(slotHrs(slots[i][0], slots[i][1]))} hr', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700, color: C.blue))),
                        if (slots.length > 1) IconButton(onPressed: () => setState(() => slots.removeAt(i)), icon: const Icon(Icons.close_rounded, color: C.red)),
                      ]),
                    ),
                  Row(children: [
                    TextButton.icon(
                      onPressed: () {
                        if (slots.last.any((x) => x.isEmpty)) {
                          toast(context, 'Fill the From and To above first, then add the next time.', bad: true);
                          return;
                        }
                        setState(() => slots.add(['', '']));
                      },
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add time (worked in parts)'),
                    ),
                    const Spacer(),
                    SizedBox(width: 120, child: TextField(controller: t('brk'), keyboardType: TextInputType.number, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Break', suffixText: 'min'))),
                  ]),
                  if (timeHrs != null) _work('${fmtNum(timeHrs)} hr in all'),
                ],
                if (way == 'Trip' || (fmt.tripAll && !status)) ...[_label('Trips', 'फेऱ्या'), _field('trip', 'Number of trips', kb: TextInputType.number, icon: Icons.repeat_rounded)],
                if (way == 'Trip' && fmt.tripTime) ...[
                  _label('In / Out time', 'वेळ'),
                  Row(children: [_timeBox(0, 0), const SizedBox(width: 8), _timeBox(0, 1)]),
                ],
                if (!status && (fmt.challan || way == 'Trip')) ...[_label('Challan No', 'चलन'), _field('challan', 'Challan No', icon: Icons.receipt_outlined)],
                if (fmt.part && !status) ...[_label('Particular', 'तपशील'), _field('part', 'Particular')],
                if (way == 'Day') const InfoLine('Worked – the day is counted (nothing to type).', icon: Icons.check_circle_outline_rounded),
                if (status) InfoLine(way == 'Idle' ? 'Idle – no work (paid or not is chosen in the bill).' : '$way – not paid.', icon: Icons.info_outline_rounded, bad: way != 'Idle'),
                if (off) ...[
                  _label('Estimated work of the day', 'अंदाजे काम'),
                  Row(children: [
                    if (_canK) Expanded(child: TextField(controller: t('estKm'), keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'est. km', suffixText: 'km'))),
                    if (_canK && _canH) const SizedBox(width: 10),
                    if (_canH) Expanded(child: TextField(controller: t('estHr'), keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'est. hr', suffixText: 'hr'))),
                  ]),
                  if (p?['avgWork'] is Map)
                    Padding(
                      padding: const EdgeInsets.only(top: 6, left: 2),
                      child: Text(
                          (p!['avgWork'] as Map)['src'] == 'own'
                              ? 'Proposed: its own average.'
                              : (p!['avgWork'] as Map)['src'] == 'type'
                                  ? 'No entry yet – proposed: the average of other ${machine?.type ?? 'machinery of its type'}.'
                                  : 'No history – type the work of the day.',
                          style: const TextStyle(fontSize: 12.5, color: C.muted)),
                    ),
                ],
                if (off || newMeter) ...[_label(off ? 'Why no reading?' : 'Why a new meter?', 'कारण'), _field('meterNote', off ? 'e.g. meter not working' : 'e.g. meter changed')],
                if (p?['first'] == true) ...[_label('Opening diesel (first entry)', 'सुरुवातीचे डिझेल'), _field('odsl', 'Litres in the tank at the start', kb: const TextInputType.numberWithOptions(decimal: true), icon: Icons.local_gas_station_outlined)],
                _items(),
                if (!fmt.noCh) ...[
                  _label('Chainage', 'चेनेज'),
                  Row(children: [Expanded(child: _field('chFrom', 'From')), const SizedBox(width: 10), Expanded(child: _field('chTo', 'To'))]),
                ],
                _label('Work done', 'केलेले काम'),
                _field('work', 'Work done', icon: Icons.construction_rounded),
                _label('Debit to (party) – if charged to someone', 'डेबिट'),
                Row(children: [
                  Expanded(flex: 3, child: _field('debitTo', 'Party (leave empty if none)')),
                  const SizedBox(width: 10),
                  Expanded(flex: 2, child: TextField(controller: t('debitRate'), keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(hintText: 'Rate', prefixText: '₹ '))),
                ]),
              ],
              if (err.isNotEmpty) InfoLine(err, bad: true),
            ],
          ]),
        ),
        bottomNavigationBar: SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            decoration: BoxDecoration(color: C.bg, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .05), blurRadius: 12, offset: const Offset(0, -4))]),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: C.blue),
              onPressed: busy || multiRows ? null : _save,
              icon: busy ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white)) : const Icon(Icons.check_circle_rounded),
              label: Text(busy ? 'Saving…' : editing ? 'Save the change' : 'Save Log Book'),
            ),
          ),
        ),
      ),
    );
  }

  Widget _work(String text) => Padding(
        padding: const EdgeInsets.only(top: 8, left: 2),
        child: Row(children: [const Icon(Icons.trending_up_rounded, size: 18, color: C.blue), const SizedBox(width: 6), Text('Work: $text', style: const TextStyle(fontWeight: FontWeight.w700, color: C.blue))]),
      );
}

// =====================================================================================================================
//  WATER TANKER – TRIP BY TRIP (Log Book Format I)
// =====================================================================================================================
class TankerScreen extends StatefulWidget {
  const TankerScreen({super.key, required this.date, this.no = '', this.editShift = '', this.editN = 0});
  final String date, no, editShift;
  final int editN; // a saved trip to change at once (from the Log Book list)
  @override
  State<TankerScreen> createState() => _TankerScreenState();
}

class _Trip {
  final c = TextEditingController(), ch = TextEditingController(), u = TextEditingController();
  String a = '', b = '';
  void dispose() {
    c.dispose();
    ch.dispose();
    u.dispose();
  }
}

class _TankerScreenState extends State<TankerScreen> {
  String date = '', shift = 'Day', info = '', err = '';
  Machine? tanker;
  Map<String, dynamic>? got; // getTankerTrips
  final trips = <_Trip>[_Trip()];
  bool busy = false;
  Map? editing; // (update-105) the saved trip being changed – its shift and n

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (date.isEmpty) {
      date = widget.date;
      shift = SessionScope.read(context).myShift(const ['Day', 'Night']); // (14-10-2026) Day / Night by the time; a saved trip opened to change keeps its own
      if (widget.no.isNotEmpty) {
        tanker = SessionScope.read(context).machine(widget.no);
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          await _load();
          if (!mounted || widget.editN <= 0) return;
          final t = (got?['trips'] as List? ?? []).whereType<Map>().where((x) => x['shift'] == widget.editShift && asNum(x['n']) == widget.editN).firstOrNull;
          if (t != null) _edit(t);
        });
      }
    }
  }

  /// A saved trip into the box above, to be changed (its shift too); Save changes only that trip.
  void _edit(Map t) {
    for (final x in trips) {
      x.dispose();
    }
    final n = _Trip();
    n.c.text = '${t['c'] ?? ''}';
    n.ch.text = '${t['ch'] ?? ''}';
    n.u.text = '${t['u'] ?? ''}';
    n.a = '${t['a'] ?? ''}';
    n.b = '${t['b'] ?? ''}';
    setState(() {
      editing = t;
      shift = t['shift'] == 'Night' ? 'Night' : 'Day';
      trips
        ..clear()
        ..add(n);
      err = '';
    });
  }

  void _editEnd() {
    for (final x in trips) {
      x.dispose();
    }
    setState(() {
      editing = null;
      trips
        ..clear()
        ..add(_Trip());
    });
  }

  @override
  void dispose() {
    for (final x in trips) {
      x.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final m = tanker;
    if (m == null) return;
    final s = SessionScope.read(context);
    try {
      final r = ((await s.api.call('getTankerTrips', [m.id, date])) as Map).cast<String, dynamic>();
      if (!mounted) return;
      setState(() {
        got = r;
        info = ['Agency: ${(r['machine'] as Map?)?['owner'] ?? '–'}', '${r['problem'] ?? ''}', '${r['other'] ?? ''}'].where((e) => e.isNotEmpty).join('  |  ');
      });
    } catch (e) {
      if (mounted) setState(() => info = errText(e));
    }
  }

  Future<void> _time(_Trip t, bool first) async {
    final tm = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (tm != null) setState(() => first ? t.a = '${_two(tm.hour)}:${_two(tm.minute)}' : t.b = '${_two(tm.hour)}:${_two(tm.minute)}');
  }

  Future<void> _save() async {
    final s = SessionScope.read(context), m = tanker;
    if (m == null) {
      setState(() => err = 'Pick the water tanker.');
      return;
    }
    final list = trips.where((t) => t.c.text.trim().isNotEmpty || t.a.isNotEmpty || t.b.isNotEmpty).toList();
    if (list.isEmpty) {
      setState(() => err = 'Type at least one trip.');
      return;
    }
    for (var i = 0; i < list.length; i++) {
      final t = list[i];
      if (t.c.text.trim().isEmpty || t.a.isEmpty || t.b.isEmpty) {
        setState(() => err = 'Trip ${i + 1}: enter the Challan No, the Dispatch and the Unload time.');
        return;
      }
      if (t.a == t.b) {
        setState(() => err = 'Trip ${i + 1}: the Dispatch and Unload time are the same.');
        return;
      }
    }
    setState(() {
      busy = true;
      err = '';
    });
    final ed = editing;
    if (ed != null) {
      final t = list.first;
      try {
        final r = ((await s.api.call('updateTankerTrip', [
          {'no': m.id, 'date': date, 'shift': ed['shift'], 'n': ed['n'], 'c': ed['c'], 'trip': {'c': t.c.text.trim(), 'a': t.a, 'b': t.b, 'ch': t.ch.text.trim(), 'u': t.u.text.trim()}, 'to': shift},
        ], true)) as Map).cast<String, dynamic>();
        if (!mounted) return;
        setState(() {
          got = r;
          busy = false;
        });
        _editEnd();
        toast(context, 'Trip changed – ${m.id}, ${showDate(date)} ($shift).');
      } catch (e) {
        if (mounted) {
          setState(() {
            busy = false;
            err = '${errText(e)}\nNothing was saved.';
          });
        }
      }
      return;
    }
    try {
      final r = ((await s.api.call('saveTankerTrips', [{'no': m.id, 'date': date, 'shift': shift, 'trips': [for (final t in list) {'c': t.c.text.trim(), 'a': t.a, 'b': t.b, 'ch': t.ch.text.trim(), 'u': t.u.text.trim()}]}], true)) as Map).cast<String, dynamic>();
      if (!mounted) return;
      for (final x in trips) {
        x.dispose();
      }
      setState(() {
        got = r;
        trips
          ..clear()
          ..add(_Trip());
        busy = false;
      });
      toast(context, '${r['added']} trip${r['added'] == 1 ? '' : 's'} saved – ${m.id}, ${showDate(date)} (${r['shift'] ?? shift}).');
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          err = '${errText(e)}\nNothing was saved.';
        });
      }
    }
  }

  Future<void> _delete(Map t) async {
    final s = SessionScope.read(context), m = tanker!;
    if (!await ask(context, 'Delete this trip?', '${m.id}, ${showDate(date)} (${t['shift']}): challan ${t['c']}${'${t['a']}'.isNotEmpty ? ', ${t['a']}–${t['b']}' : ''}.', yes: 'Delete', danger: true)) return;
    try {
      final r = ((await s.api.call('deleteTankerTrip', [{'no': m.id, 'date': date, 'shift': t['shift'], 'c': t['c']}], true)) as Map).cast<String, dynamic>();
      if (mounted) setState(() => got = r);
      if (editing != null && mounted) _editEnd();
    } catch (e) {
      if (mounted) toast(context, errText(e), bad: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    final tankers = s.machines.where((m) => m.active && m.waterTanker).toList();
    final saved = (got?['trips'] as List? ?? []).whereType<Map>().toList();
    final canEdit = s.canEdit('Log Book');
    return Scaffold(
      appBar: AppBar(titleSpacing: 0, title: const Row(children: [Pic('delivery_truck', size: 30), SizedBox(width: 10), Expanded(child: TwoLang('Water tanker – trips', 'टँकर – फेऱ्या', size: 19, weight: FontWeight.w700))])),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 120), children: [
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: Press(
              onTap: () async {
                final d = await showDatePicker(context: context, initialDate: parseKey(date), firstDate: DateTime(2024), lastDate: parseKey(s.today));
                if (d != null) {
                  setState(() => date = dateKey(d));
                  if (editing != null) _editEnd();
                  _load();
                }
              },
              radius: 16,
              shadow: false,
              padding: const EdgeInsets.all(14),
              child: Row(children: [const Icon(Icons.calendar_month_rounded, color: C.blue), const SizedBox(width: 10), Text(showDate(date), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16))]),
            ),
          ),
          const SizedBox(width: 10),
          SegmentedButton<String>(
            segments: const [ButtonSegment(value: 'Day', label: Text('Day')), ButtonSegment(value: 'Night', label: Text('Night'))],
            selected: {shift},
            onSelectionChanged: (x) => setState(() => shift = x.first),
            showSelectedIcon: false,
          ),
        ]),
        const SizedBox(height: 12),
        if (tankers.isEmpty) const InfoLine('No water tanker yet – set a tanker\'s Log Book format to "Format I – Water tanker" (Master → Log Book Format).', bad: true),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final m in tankers)
            ChoiceChip(
              label: Text(m.id),
              selected: tanker?.id == m.id,
              onSelected: (_) {
                setState(() {
                  tanker = m;
                  got = null;
                });
                if (editing != null) _editEnd();
                _load();
              },
              selectedColor: C.blue,
              labelStyle: TextStyle(color: tanker?.id == m.id ? Colors.white : C.ink, fontWeight: FontWeight.w600),
              showCheckmark: false,
              shape: const StadiumBorder(),
            ),
        ]),
        if (info.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Text(info, style: const TextStyle(color: C.muted))),
        if (tanker != null) ...[
          const SizedBox(height: 16),
          SectionTitle('Saved trips – ${showDate(date)}', mr: 'जतन फेऱ्या'),
          if (saved.isEmpty) const Text('No trip saved for this date yet.', style: TextStyle(color: C.muted)),
          for (final (i, t) in saved.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Press(
                shadow: false,
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  CircleAvatar(radius: 15, backgroundColor: C.blueSoft, child: Text('${i + 1}', style: const TextStyle(color: C.blue, fontWeight: FontWeight.w700, fontSize: 13))),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(['${t['c'] ?? ''}'.isNotEmpty ? 'Challan ${t['c']}' : 'No challan', if ('${t['a'] ?? ''}'.isNotEmpty) '${t['a']}–${t['b']}'].join(' · '), style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text([t['shift'], t['ch'], t['u'], if (t['old'] == 1 || t['old'] == true) 'entered before trip by trip'].where((e) => '${e ?? ''}'.isNotEmpty).join(' · '), style: const TextStyle(color: C.muted, fontSize: 13)),
                    ]),
                  ),
                  if (canEdit) IconButton(tooltip: 'Change', onPressed: () => _edit(t), icon: const Icon(Icons.edit_rounded, color: C.blue)),
                  if (canEdit) IconButton(tooltip: 'Delete', onPressed: () => _delete(t), icon: const Icon(Icons.delete_outline_rounded, color: C.red)),
                ]),
              ),
            ),
          if (saved.isNotEmpty)
            Text('Day trips: ${saved.where((t) => t['shift'] != 'Night').length} · Night trips: ${saved.where((t) => t['shift'] == 'Night').length} · Total: ${saved.length}', style: const TextStyle(fontWeight: FontWeight.w600, color: C.blue)),
          if (canEdit) ...[
            const SizedBox(height: 18),
            if (editing case final ed?)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
                decoration: BoxDecoration(color: C.amberSoft, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFF3D9A4))),
                child: Row(children: [
                  Expanded(child: Text('Changing trip ${ed['n']} of ${ed['shift']}${'${ed['c'] ?? ''}'.isNotEmpty ? ' – challan ${ed['c']}' : ''}', style: const TextStyle(fontWeight: FontWeight.w600))),
                  TextButton(onPressed: _editEnd, child: const Text('Cancel')),
                ]),
              )
            else
              const SectionTitle('New trips', mr: 'नवीन फेऱ्या'),
            for (final (i, t) in trips.indexed)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: C.line)),
                child: Column(children: [
                  Row(children: [
                    Text('Trip ${i + 1}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    const Spacer(),
                    if (trips.length > 1)
                      IconButton(
                        onPressed: () => setState(() {
                          trips.removeAt(i).dispose();
                        }),
                        icon: const Icon(Icons.close_rounded, color: C.red),
                      ),
                  ]),
                  const SizedBox(height: 8),
                  TextField(controller: t.c, decoration: const InputDecoration(labelText: 'Challan No')),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: OutlinedButton.icon(onPressed: () => _time(t, true), icon: const Icon(Icons.schedule_rounded), label: Text(t.a.isEmpty ? 'Dispatch' : t.a))),
                    const SizedBox(width: 8),
                    Expanded(child: OutlinedButton.icon(onPressed: () => _time(t, false), icon: const Icon(Icons.schedule_rounded), label: Text(t.b.isEmpty ? 'Unload' : t.b))),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: TextField(controller: t.ch, decoration: const InputDecoration(labelText: 'Chainage', hintText: 'e.g. 12+500'))),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(controller: t.u, decoration: const InputDecoration(labelText: 'Use for', hintText: 'e.g. Curing'))),
                  ]),
                ]),
              ),
            if (editing == null) TextButton.icon(onPressed: () => setState(() => trips.add(_Trip())), icon: const Icon(Icons.add_rounded), label: const Text('Add a trip')),
          ],
        ],
        if (err.isNotEmpty) InfoLine(err, bad: true),
      ]),
      bottomNavigationBar: canEdit && tanker != null
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: C.blue),
                  onPressed: busy ? null : _save,
                  icon: busy ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white)) : const Icon(Icons.check_circle_rounded),
                  label: Text(busy ? 'Saving…' : editing != null ? 'Save change' : 'Save trips'),
                ),
              ),
            )
          : null,
    );
  }
}
