/* (3.132.0, Mechanical update-263) THE SMART LOG BOOK'S OFFICE PAGES – the app's own screens of the web's three pages (asked 16-10-2026:
 * every page of the web is in the app as the app's OWN screens; the same server actions, checks and access – nothing of the web or
 * the server is changed for them):
 *   Driver Master (Machinery → Driver Master; access "Driver Master"): the drivers and operators – mobile, licence and its validity
 *     (expired / ending in 30 days marked), status, the e-mail of the phone sign-in, the vehicle with him now; add / change
 *     (getDriverMaster, saveDriver – the same driver is not made twice: the mobile / e-mail refused, the same name asked once more).
 *   Vehicle Allocation (Entries → Log Book; access "Vehicle Allocation"): who has which vehicle now, its opening and GPS, the free
 *     vehicles and drivers, what needs a look; Give / Release (with why – its closing is marked "missing", never made up) / Resolve
 *     (vlBoard every 30 seconds while it is seen; vlAssign, vlRelease, vlResolve).
 *   Live Tracking (Entries → Log Book; access "Live Tracking"): every vehicle on duty on the map (OpenStreetMap – flutter_map, no key),
 *     live / GPS off / not seen; the route of a day (vlLive every 20 seconds while it is seen; vlRoute). */
import 'dart:async';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/format.dart';
import '../ui/fields.dart';
import '../ui/scope.dart';
import '../ui/t.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'smart_logbook.dart' show slbBar, slbTime;

const _purple = Color(0xFF6D2FD0), _purpleSoft = Color(0xFFEFE7FB);

Future<void> openDriverMaster(BuildContext context) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const DriverMasterScreen()));
Future<void> openVehicleAllocation(BuildContext context) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const VehicleAllocationScreen()));
Future<void> openLiveTracking(BuildContext context) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const LiveTrackingScreen()));

// ---- the web's words (App.html slAt / slWhen / slMin / slHow / slKind)
List<Map<String, dynamic>> _maps(Object? v) => [for (final x in (v is List ? v : const [])) if (x is Map) x.cast<String, dynamic>()];
Map<String, dynamic> _map(Object? v) => v is Map ? v.cast<String, dynamic>() : <String, dynamic>{};
String _when(Object? a, String today) {
  final s = '${a ?? ''}';
  if (s.length < 16) return '';
  return '${s.substring(0, 10) == today ? '' : '${showDate(s.substring(0, 10))} '}${slbTime(s)}';
}

int? _minAgo(Object? a, DateTime now) {
  final t = DateTime.tryParse('${a ?? ''}:00+05:30');
  return t == null ? null : now.toUtc().difference(t.toUtc()).inMinutes;
}

String _min(int m) => m < 60 ? '$m min' : '${m ~/ 60} h ${m % 60} min';
const _how = {'qr': 'QR', 'plate': 'number plate', 'pick': 'picked', 'assign': 'given by the supervisor', 'handover': 'handed over'};
String _kind(Object? k) {
  final s = '${k ?? ''}';
  return s.isEmpty ? '' : s[0].toUpperCase() + s.substring(1);
}

String _read(Map? o) => [if (asNum(o?['km']) != null) '${fmtNum(asNum(o?['km']))} km', if (asNum(o?['hr']) != null) '${fmtNum(asNum(o?['hr']))} hr'].join(' · ');
String _nowWords(DateTime t) => 'Updated ${(t.hour % 12 == 0 ? 12 : t.hour % 12).toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')} ${t.hour < 12 ? 'AM' : 'PM'}';

Widget _card(Widget child, {Key? key, Color color = Colors.white, Color? border}) => Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(18), border: border == null ? null : Border.all(color: border, width: 1.4), boxShadow: color == Colors.white ? softShadow(.05) : null),
      child: child,
    );

Widget _head(String en, String mr, {String count = ''}) => Padding(
      padding: const EdgeInsets.fromLTRB(2, 14, 2, 8),
      child: Row(children: [
        Expanded(child: Text(en, mr: mr, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
        if (count.isNotEmpty) Text(count, style: const TextStyle(fontSize: 13, color: C.muted, fontWeight: FontWeight.w600)),
      ]),
    );

/// The colour of a vehicle's GPS: live (green), GPS off / not seen (red), no GPS yet (grey) – as the web's
(Color, Color) _tone(String state) => state == 'live' ? (C.greenDark, C.greenSoft) : (state == 'GPS off' || state.startsWith('not seen')) ? (C.red, C.redSoft) : (C.muted, C.slateSoft);

/// The GPS of a vehicle with a driver, as the web's cell: "Live" / "GPS off" / "Not seen 25 min" / "No GPS yet", then its km and last time
Widget _gpsLine(Map<String, dynamic> g, String today, DateTime now) {
  final at = '${g['at'] ?? ''}';
  if (at.isEmpty) return const Pill('No GPS yet', color: C.muted, bg: C.slateSoft, icon: Icons.location_off_outlined);
  final m = _minAgo(at, now) ?? 0, off = '${g['status']}' == 'off';
  final p = off ? const Pill('GPS off', color: C.red, bg: C.redSoft, icon: Icons.location_off_rounded) : m > 10 ? Pill('Not seen ${_min(m)}', color: C.red, bg: C.redSoft, icon: Icons.schedule_rounded) : const Pill('Live', icon: Icons.my_location_rounded);
  final km = asNum(g['km']) ?? 0;
  return Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
    p,
    Text('${km > 0 ? '${fmtNum(km)} km · ' : ''}${tr('last')} ${_when(at, today)}', style: const TextStyle(fontSize: 12.5, color: C.muted)),
  ]);
}

/// A reason asked before a release / a resolve (the web's slWhy): null = cancelled
Future<String?> _why(BuildContext context, String title, String message, String ok, String hint) => askNote(context, title,
    body: [Text(message, style: const TextStyle(fontSize: 14.5, height: 1.4))], label: 'Why / what was done', ok: ok, neededMsg: hint);

// =====================================================================================================================================
//  DRIVER MASTER
// =====================================================================================================================================
class DriverMasterScreen extends StatefulWidget {
  const DriverMasterScreen({super.key});
  @override
  State<DriverMasterScreen> createState() => _DriverMasterScreenState();
}

class _DriverMasterScreenState extends State<DriverMasterScreen> {
  List<Map<String, dynamic>> list = [];
  bool loading = true;
  String err = '', status = 'Active';      // (the web's list opens on Active too)
  final q = TextEditingController();

  @override
  void initState() {
    super.initState();
    q.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    q.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final s = SessionScope.read(context);
    setState(() {
      loading = true;
      err = '';
    });
    try {
      final d = _map(await s.api.call('getDriverMaster'));
      if (!mounted) return;
      setState(() {
        list = _maps(d['drivers']);
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        err = errText(e);
        loading = false;
      });
    }
  }

  /// "expired" / "12 days left" (30 days or less) – the web's dmExp
  Widget? _exp(Map d, String today) {
    final e = '${d['licenceExpiry'] ?? ''}';
    if (e.length != 10 || today.length != 10) return null;
    final n = parseKey(e).difference(parseKey(today)).inDays;
    if (n < 0) return const Pill('expired', color: C.red, bg: C.redSoft);
    if (n <= 30) return Pill('$n day${n == 1 ? '' : 's'} left', color: C.amber, bg: C.amberSoft);
    return null;
  }

  Future<void> _edit(Map<String, dynamic>? d) async {
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => DriverForm(driver: d)));
    if (saved == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context), ed = s.canEdit('Driver Master'), t = q.text.trim().toLowerCase();
    final shown = list.where((d) => (status.isEmpty || d['status'] == status) && (t.isEmpty || [d['name'], d['mobile'], d['licence'], d['email'], d['id']].any((v) => '${v ?? ''}'.toLowerCase().contains(t)))).toList();
    return Scaffold(
      appBar: slbBar(context, 'Driver Master', bi('Drivers and operators – mobile, licence, phone sign-in', 'Drivers आणि operators – mobile, licence'), pic: 'clipboard'),
      floatingActionButton: ed
          ? FloatingActionButton.extended(key: const Key('dm-add'), backgroundColor: _purple, foregroundColor: Colors.white, onPressed: () => _edit(null), icon: const Icon(Icons.person_add_alt_1_rounded), label: Text('Add driver', mr: 'Driver जोडा'))
          : null,
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(key: const Key('dm-list'), padding: const EdgeInsets.fromLTRB(16, 14, 16, 96), children: [
          TextField(key: const Key('dm-q'), controller: q, decoration: InputDecoration(prefixIcon: const Icon(Icons.search_rounded), hintText: tr('Search – name, mobile, licence, e-mail'))),
          const SizedBox(height: 10),
          Wrap(spacing: 8, children: [
            for (final (v, l) in const [('', 'All'), ('Active', 'Active'), ('Inactive', 'Inactive')])
              ChoiceChip(key: Key('dm-st-${v.isEmpty ? 'all' : v}'), label: Text(l), selected: status == v, onSelected: (_) => setState(() => status = v)),
          ]),
          Row(children: [
            Expanded(child: list.isEmpty ? const SizedBox.shrink() : Text('${shown.length == list.length ? '${list.length}' : '${shown.length} of ${list.length}'} driver${list.length == 1 ? '' : 's'}', key: const Key('dm-count'), style: const TextStyle(fontSize: 13, color: C.muted))),
            // (update-263) "Bring from HR": the Driver / Operator employees of this site in HR (HR only read)
            TextButton.icon(
              key: const Key('dm-hr'),
              onPressed: () async {
                await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const HrDriversScreen()));
                await _load();
              },
              icon: const Icon(Icons.badge_outlined, size: 20),
              label: Text('Bring from HR', mr: 'HR मधून आणा'),
            ),
          ]),
          const SizedBox(height: 8),
          if (loading && list.isEmpty) const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator())),
          if (err.isNotEmpty) InfoLine(err, bad: true),
          if (!loading && err.isEmpty && shown.isEmpty)
            EmptyState(list.isEmpty ? 'No driver yet' : 'No driver matches.', list.isEmpty && ed ? 'Add the first one with "Add driver".' : '', pic: 'clipboard'),
          for (final d in shown) _row(d, s.today, ed),
        ]),
      ),
    );
  }

  Widget _row(Map<String, dynamic> d, String today, bool ed) {
    final name = '${d['name'] ?? ''}', exp = _exp(d, today), on = '${d['status']}' == 'Active', has = '${d['has'] ?? ''}';
    return Padding(padding: const EdgeInsets.only(bottom: 10), child: Press(
      key: Key('dm-row-${d['id']}'),
      onTap: ed ? () => _edit(d) : null,
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CircleAvatar(radius: 22, backgroundColor: on ? _purpleSoft : C.slateSoft, child: Text(name.isEmpty ? '?' : name.substring(0, 1).toUpperCase(), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: on ? _purple : C.muted))),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800))),
              Pill(on ? 'Active' : 'Inactive', color: on ? C.greenDark : C.muted, bg: on ? C.greenSoft : C.slateSoft),
            ]),
            Text([d['id'], d['category'], if ('${d['mobile'] ?? ''}'.isNotEmpty) d['mobile']].join(' · '), style: const TextStyle(fontSize: 13, color: C.muted)),
            if ('${d['licence'] ?? ''}'.isNotEmpty || '${d['licenceExpiry'] ?? ''}'.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  Text('${tr('Licence')} ${'${d['licence'] ?? ''}'.isEmpty ? '–' : d['licence']}${'${d['licenceExpiry'] ?? ''}'.isEmpty ? '' : ' · ${tr('upto')} ${showDate('${d['licenceExpiry']}')}'}', style: const TextStyle(fontSize: 13)),
                  if (exp != null) exp,
                ]),
              ),
            if ('${d['email'] ?? ''}'.isNotEmpty) Text('📱 ${d['email']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: C.muted)),
            if (has.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Pill('${tr('Vehicle now')}: $has', color: _purple, bg: _purpleSoft, icon: Icons.local_shipping_rounded)),
          ]),
        ),
      ]),
    ));
  }
}

/// A new driver, or one changed (the web's Driver Master form – the same fields and the same server check)
class DriverForm extends StatefulWidget {
  const DriverForm({super.key, this.driver});
  final Map<String, dynamic>? driver;
  @override
  State<DriverForm> createState() => _DriverFormState();
}

class _DriverFormState extends State<DriverForm> {
  late final Map<String, dynamic> d = widget.driver ?? const {};
  late final name = TextEditingController(text: '${d['name'] ?? ''}'),
      mobile = TextEditingController(text: '${d['mobile'] ?? ''}'),
      licence = TextEditingController(text: '${d['licence'] ?? ''}'),
      email = TextEditingController(text: '${d['email'] ?? ''}'),
      remark = TextEditingController(text: '${d['remark'] ?? ''}');
  late String category = '${d['category'] ?? 'Driver'}', status = '${d['status'] ?? 'Active'}', expiry = '${d['licenceExpiry'] ?? ''}';
  bool busy = false, same = false;
  String err = '';

  @override
  void dispose() {
    for (final c in [name, mobile, licence, email, remark]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final s = SessionScope.read(context), id = '${d['id'] ?? ''}';
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      busy = true;
      err = '';
    });
    final x = {'id': id, 'sameName': same, 'name': name.text.trim(), 'mobile': mobile.text.trim(), 'category': category, 'licence': licence.text.trim(), 'licenceExpiry': expiry, 'status': status, 'email': email.text.trim(), 'remark': remark.text.trim()};
    try {
      final r = _map(await s.api.call('saveDriver', [x]));
      if (!mounted) return;
      toast(context, '${id.isEmpty ? 'Driver added' : 'Saved'} – ${x['name']} (${r['id'] ?? id}).');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      final m = errText(e);
      setState(() {
        busy = false;
        err = m;
        same = m.contains('press Save again');      // (a driver of the same name: the second Save says it is another person)
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = '${d['id'] ?? ''}';
    return Scaffold(
      appBar: slbBar(context, id.isEmpty ? 'New driver' : '${tr('Change')} ${d['name']}', id.isEmpty ? bi('Driver Master', 'ड्रायव्हर मास्टर') : '$id · ${tr('Driver Master')}', pic: 'clipboard'),
      body: ListView(key: const Key('dmf-list'), padding: const EdgeInsets.fromLTRB(16, 16, 16, 30), children: [
        _card(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TextField(key: const Key('dmf-name'), controller: name, textCapitalization: TextCapitalization.words, decoration: InputDecoration(labelText: tr('Name'))),
          const SizedBox(height: 10),
          TextField(key: const Key('dmf-mobile'), controller: mobile, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: tr('Mobile'), hintText: '10 digits')),
          const SizedBox(height: 10),
          PickField(key: const Key('dmf-category'), label: 'Category', value: category, items: const ['Driver', 'Operator'], onChanged: (v) => setState(() => category = v)),
        ])),
        _card(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TextField(key: const Key('dmf-licence'), controller: licence, textCapitalization: TextCapitalization.characters, decoration: InputDecoration(labelText: tr('Licence number'))),
          const SizedBox(height: 10),
          DateField(key: const Key('dmf-expiry'), label: 'Licence valid upto', value: expiry, onChanged: (v) => setState(() => expiry = v)),
        ])),
        _card(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TextField(key: const Key('dmf-email'), controller: email, keyboardType: TextInputType.emailAddress, decoration: InputDecoration(labelText: tr('Phone sign-in e-mail'), helperText: tr('Only for a driver who uses the phone (his Portal sign-in)'))),
          const SizedBox(height: 10),
          PickField(key: const Key('dmf-status'), label: 'Status', value: status, items: const ['Active', 'Inactive'], onChanged: (v) => setState(() => status = v)),
          const SizedBox(height: 10),
          TextField(key: const Key('dmf-remark'), controller: remark, decoration: InputDecoration(labelText: tr('Remark'))),
        ])),
        if (err.isNotEmpty) InfoLine(err, key: const Key('dmf-err'), bad: true),
      ]),
      // (the Save button stays at the bottom – a long message above it never hides it)
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SizedBox(
            height: 54,
            child: FilledButton.icon(
              key: const Key('dmf-save'),
              style: FilledButton.styleFrom(backgroundColor: C.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
              onPressed: busy ? null : _save,
              icon: busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.check_rounded),
              label: Text(id.isEmpty ? 'Save driver' : 'Save changes', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
        ),
      ),
    );
  }
}

/// (update-263) "Bring from HR": the Driver / Operator employees of this site in HR – Linked / the same person here (Link to him) / not here
/// (Add as new); a change in HR shown, never written over by itself (hrDriversToLink, linkHrDriver – the web's same panel)
class HrDriversScreen extends StatefulWidget {
  const HrDriversScreen({super.key});
  @override
  State<HrDriversScreen> createState() => _HrDriversScreenState();
}

class _HrDriversScreenState extends State<HrDriversScreen> {
  List<Map<String, dynamic>> list = [];
  bool loading = true, can = false;
  String err = '', busy = '', again = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final s = SessionScope.read(context);
    setState(() {
      loading = true;
      err = '';
    });
    try {
      final d = _map(await s.api.call('hrDriversToLink'));
      if (!mounted) return;
      setState(() {
        list = _maps(d['employees']);
        can = d['can'] == true;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        err = errText(e);
        loading = false;
      });
    }
  }

  Future<void> _do(Map<String, dynamic> e, String to) async {
    final s = SessionScope.read(context), hr = '${e['hr']}';
    setState(() => busy = hr);
    try {
      final r = _map(await s.api.call('linkHrDriver', [{'hr': hr, 'to': to, 'sameName': to.isEmpty && again == hr}]));
      if (!mounted) return;
      again = '';
      toast(context, r['again'] == true ? 'Already linked.' : r['linked'] == true ? 'Linked – ${r['id']} is that employee of HR.' : 'Added from HR – ${r['id']}.');
      await _load();
    } catch (er) {
      if (!mounted) return;
      final m = errText(er);
      again = m.contains('press Add again') ? hr : '';
      toast(context, m, bad: true);
    } finally {
      if (mounted) setState(() => busy = '');
    }
  }

  @override
  Widget build(BuildContext context) {
    const st = {'linked': ('Linked', C.greenDark, C.greenSoft), 'same': ('The same person here?', C.amber, C.amberSoft), 'new': ('Not here', C.muted, C.slateSoft)};
    return Scaffold(
      appBar: slbBar(context, 'Bring from HR', bi('Drivers and operators of this site in HR', 'HR मधले या site चे drivers'), pic: 'clipboard'),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(key: const Key('dmh-list'), padding: const EdgeInsets.fromLTRB(16, 14, 16, 30), children: [
          _card(color: _purpleSoft, Text('HR is only read – nothing is written there. "Link to him": the driver here is that employee (no second driver). A change in HR (name, mobile, left) is shown here – never written over by itself.',
              style: const TextStyle(fontSize: 13.5, height: 1.35, color: Color(0xFF4C1D95)))),
          if (loading && list.isEmpty) const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator())),
          if (err.isNotEmpty) InfoLine(err, bad: true),
          if (!loading && err.isEmpty && list.isEmpty) const EmptyState('No Driver / Operator of this site in HR.', '', pic: 'clipboard'),
          for (final e in list)
            Builder(builder: (_) {
              final (word, c, bg) = st['${e['state']}'] ?? st['new']!;
              final changed = (e['changed'] as List? ?? const []).map((x) => tr('$x')).join(', '), left = '${e['status']}' == 'left', hr = '${e['hr']}';
              return _card(
                key: Key('dmh-$hr'),
                Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    Expanded(child: Text('${e['name']}', style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800))),
                    Pill(word, color: c, bg: bg),
                  ]),
                  Text([e['code'], e['category'], if ('${e['mobile'] ?? ''}'.isNotEmpty) e['mobile'], left ? '${tr('Left')}${'${e['left'] ?? ''}'.isEmpty ? '' : ' ${showDate('${e['left']}')}'}' : _kind(e['status'])].join(' · '),
                      style: TextStyle(fontSize: 13, color: left ? C.red : C.muted)),
                  if ('${e['driver'] ?? ''}'.isNotEmpty) Text('${tr('Driver Master')}: ${e['driverName']} (${e['driver']})', style: const TextStyle(fontSize: 13)),
                  if (changed.isNotEmpty) Text('${tr('Changed in HR')}: $changed', style: const TextStyle(fontSize: 13, color: C.amber, fontWeight: FontWeight.w600)),
                  if (can && '${e['state']}' != 'linked')
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Wrap(spacing: 8, runSpacing: 6, children: [
                        if ('${e['state']}' == 'same')
                          FilledButton(key: Key('dmh-link-$hr'), style: FilledButton.styleFrom(backgroundColor: _purple, minimumSize: const Size(0, 40)), onPressed: busy.isNotEmpty ? null : () => _do(e, '${e['driver']}'), child: Text('Link to him', mr: 'त्याच्याशी जोडा')),
                        OutlinedButton(key: Key('dmh-add-$hr'), style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)), onPressed: busy.isNotEmpty ? null : () => _do(e, ''), child: Text('Add as new', mr: 'नवीन म्हणून आणा')),
                      ]),
                    ),
                ]),
              );
            }),
        ]),
      ),
    );
  }
}

// =====================================================================================================================================
//  VEHICLE ALLOCATION
// =====================================================================================================================================
class VehicleAllocationScreen extends StatefulWidget {
  const VehicleAllocationScreen({super.key});
  @override
  State<VehicleAllocationScreen> createState() => _VehicleAllocationScreenState();
}

class _VehicleAllocationScreenState extends State<VehicleAllocationScreen> {
  Map<String, dynamic>? d;
  String err = '', no = '', to = '', shift = '';
  bool giving = false;
  DateTime? at;
  Timer? _again;
  int _seq = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _again?.cancel();
    super.dispose();
  }

  /// read again every 30 seconds while this screen is the one seen (the web's vaaLoad)
  Future<void> _load({bool quiet = false}) async {
    final s = SessionScope.read(context), my = ++_seq;
    _again?.cancel();
    try {
      final r = _map(await s.api.call('vlBoard'));
      if (!mounted || my != _seq) return;
      setState(() {
        d = r;
        err = '';
        at = s.clock();
      });
    } catch (e) {
      if (!mounted) return;
      if (!quiet) setState(() => err = errText(e));
    }
    if (!mounted) return;
    _again = Timer(const Duration(seconds: 30), () {
      if (mounted && (ModalRoute.of(context)?.isCurrent ?? true)) _load(quiet: true);
    });
  }

  Future<void> _give() async {
    final s = SessionScope.read(context);
    if (no.isEmpty || to.isEmpty) {
      toast(context, 'Pick the vehicle and the driver.', bad: true);
      return;
    }
    setState(() => giving = true);
    try {
      final r = _map(await s.api.call('vlAssign', [{'no': no, 'to': to, 'shift': shift}]));
      if (!mounted) return;
      toast(context, '$no given to ${_map(r['session'])['driverName'] ?? to} – it shows on his phone.');
      setState(() {
        no = '';
        to = '';
      });
      await _load();
    } catch (e) {
      if (mounted) toast(context, errText(e), bad: true);
    } finally {
      if (mounted) setState(() => giving = false);
    }
  }

  Future<void> _release(Map<String, dynamic> x) async {
    final s = SessionScope.read(context), who = '${x['driverName'] ?? x['driver'] ?? ''}';
    final why = await _why(context, 'Release ${x['no']} from $who?', 'The vehicle becomes free. Its closing is marked "missing" (never made up from the next reading) – it waits in "Needs a look" until the Log Book entry is put right.', 'Release',
        'Write why the vehicle is released (e.g. the driver left without closing).');
    if (why == null || !mounted) return;
    try {
      await s.api.call('vlRelease', [{'id': x['id'], 'reason': why}]);
      if (!mounted) return;
      toast(context, '${x['no']} released – its closing is marked missing.');
      await _load();
    } catch (e) {
      if (mounted) toast(context, errText(e), bad: true);
    }
  }

  Future<void> _resolve(Map<String, dynamic> a) async {
    final s = SessionScope.read(context), title = '${_kind(a['kind'])} – ${a['no']}';
    final why = await _why(context, 'Resolve: $title', 'Write how it was put right.', 'Resolve', 'Write how it was put right (e.g. the Log Book entry was made from the paper).');
    if (why == null || !mounted) return;
    try {
      await s.api.call('vlResolve', [{'id': a['id'], 'reason': why}]);
      if (!mounted) return;
      toast(context, 'Resolved – $title.');
      await _load();
    } catch (e) {
      if (mounted) toast(context, errText(e), bad: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context), d = this.d, now = s.clock(), today = s.today, ed = s.canEdit('Vehicle Allocation');
    final open = _maps(d?['open']), free = _maps(d?['free']), people = _maps(d?['people']), asks = _maps(d?['asks']);
    final freePeople = people.where((p) => '${p['has'] ?? ''}'.isEmpty).toList(), look = asks.length + open.where((x) => x['long'] == true).length;
    return Scaffold(
      appBar: slbBar(context, 'Vehicle Allocation', at == null ? bi('Who has which vehicle now', 'कोणाकडे कोणती गाडी') : '${_nowWords(at!)} · ${tr('every 30 s')}', pic: 'articulated_lorry'),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(key: const Key('va-list'), padding: const EdgeInsets.fromLTRB(16, 14, 16, 30), children: [
          if (d == null && err.isEmpty) const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator())),
          if (err.isNotEmpty) InfoLine(err, bad: true),
          if (d != null) ...[
            Row(children: [
              for (final (i, k) in [(open.length, 'With a driver now', 'चालकाकडे'), (free.length, 'Vehicles free', 'मोकळ्या गाड्या'), (freePeople.length, 'Drivers free', 'मोकळे चालक'), (look, 'Needs a look', 'पाहायचे')].indexed) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    key: Key('va-kpi-$i'),
                    padding: const EdgeInsets.fromLTRB(8, 12, 8, 10),
                    decoration: BoxDecoration(color: i == 3 && k.$1 > 0 ? C.redSoft : Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: softShadow(.05)),
                    child: Column(children: [
                      Text('${k.$1}', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: i == 3 && k.$1 > 0 ? C.red : (i == 0 ? _purple : C.ink))),
                      Text(k.$2, mr: k.$3, maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: C.muted, height: 1.2)),
                    ]),
                  ),
                ),
              ],
            ]),
            _head('With a driver now', 'आत्ता चालकाकडे', count: '${open.length}'),
            if (open.isEmpty) _card(Text('No vehicle is with a driver now.', style: const TextStyle(color: C.muted))),
            for (final x in open) _openRow(x, today, now, ed),
            if (ed) ...[
              _head('Give a vehicle', 'गाडी द्या'),
              _card(
                key: const Key('va-give-box'),
                Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  PickField(key: const Key('va-no'), label: 'Vehicle', value: no, blank: '– pick –', items: [for (final m in free) '${m['no']}'], labels: {for (final m in free) '${m['no']}': [m['no'], if ('${m['type'] ?? ''}'.isNotEmpty) m['type']].join(' · ')}, onChanged: (v) => setState(() => no = v)),
                  const SizedBox(height: 10),
                  PickField(key: const Key('va-to'), label: 'Driver', value: to, blank: '– pick –', items: [for (final p in freePeople) '${p['email']}'], labels: {for (final p in freePeople) '${p['email']}': [p['name'], if ('${p['mobile'] ?? ''}'.isNotEmpty) p['mobile']].join(' · ')}, onChanged: (v) => setState(() => to = v)),
                  const SizedBox(height: 10),
                  PickField(key: const Key('va-shift'), label: 'Shift', value: shift, blank: tr('By the time now'), items: const ['Day', 'Night', 'Full Day'], onChanged: (v) => setState(() => shift = v)),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 50,
                    child: FilledButton.icon(
                      key: const Key('va-give'),
                      style: FilledButton.styleFrom(backgroundColor: _purple, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                      onPressed: giving ? null : _give,
                      icon: const Icon(Icons.key_rounded),
                      label: Text('Give the vehicle', mr: 'गाडी द्या', style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ]),
              ),
            ],
            _head('Needs a look', 'पाहायचे', count: asks.isEmpty ? '' : '${asks.length}'),
            if (asks.isEmpty) _card(Text('Nothing needs a look.', style: const TextStyle(color: C.muted))),
            for (final a in asks)
              _card(
                key: Key('va-ask-${a['id']}'),
                color: C.amberSoft,
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${_kind(a['kind'])} – ${a['no']}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                      Text([if ('${a['date'] ?? ''}'.isNotEmpty) showDate('${a['date']}'), a['shift'], a['who']].where((v) => '${v ?? ''}'.isNotEmpty).join(' · '), style: const TextStyle(fontSize: 13, color: C.muted)),
                      if ('${a['note'] ?? ''}'.isNotEmpty) Text('${a['note']}', style: const TextStyle(fontSize: 13)),
                    ]),
                  ),
                  if (ed) TextButton(key: Key('va-res-${a['id']}'), onPressed: () => _resolve(a), child: Text('Resolve', mr: 'सोडवा')),
                ]),
              ),
          ],
        ]),
      ),
    );
  }

  Widget _openRow(Map<String, dynamic> x, String today, DateTime now, bool ed) {
    final op = x['opening'] is Map ? _map(x['opening']) : null, long = x['long'] == true;
    return _card(
      key: Key('va-open-${x['id']}'),
      border: long ? C.red : null,
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(width: 46, height: 46, decoration: BoxDecoration(color: _purpleSoft, borderRadius: BorderRadius.circular(14)), alignment: Alignment.center, child: const Pic('delivery_truck', size: 32)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${x['no']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              Text([x['type'], x['name']].where((v) => '${v ?? ''}'.isNotEmpty).join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: C.muted)),
            ]),
          ),
          if (ed) OutlinedButton(key: Key('va-rel-${x['id']}'), style: OutlinedButton.styleFrom(foregroundColor: C.red, side: const BorderSide(color: C.red), minimumSize: const Size(0, 40), padding: const EdgeInsets.symmetric(horizontal: 14)), onPressed: () => _release(x), child: Text('Release', mr: 'सोडा')),
        ]),
        const SizedBox(height: 8),
        Text('👤 ${x['driverName'] ?? x['driver'] ?? ''}${'${x['shift'] ?? ''}'.isEmpty ? '' : ' · ${tr('${x['shift']}')}'}${'${x['shiftDate'] ?? ''}'.isEmpty ? '' : ' · ${showDate('${x['shiftDate']}')}'}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        Text('${tr('Since')} ${_when(x['since'], today)} · ${tr(_how['${x['how']}'] ?? '${x['how'] ?? ''}')}', style: const TextStyle(fontSize: 13, color: C.muted)),
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
          if (op != null)
            Pill('${tr('Opening')} ${_read(op)}${'${op['check'] ?? ''}'.isEmpty ? '' : ' ⚠'}', color: C.blue, bg: C.blueSoft, icon: Icons.speed_rounded)
          else
            const Pill('Opening not given yet', color: C.amber, bg: C.amberSoft, icon: Icons.hourglass_top_rounded),
          if (long) const Pill('Open over 16 h – closing missing?', color: C.red, bg: C.redSoft),
        ]),
        const SizedBox(height: 6),
        _gpsLine(_map(x['gps']), today, now),
      ]),
    );
  }
}

// =====================================================================================================================================
//  LIVE TRACKING
// =====================================================================================================================================
/// The map of the Live Tracking (OpenStreetMap through flutter_map – no key, no cost). [tiles] off in the tests (no internet there).
class SlbMap {
  @visibleForTesting
  static bool tiles = true;
}

class LiveTrackingScreen extends StatefulWidget {
  const LiveTrackingScreen({super.key});
  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen> {
  Map<String, dynamic>? d, route;
  String err = '', rNo = '', rDate = '', rNote = '';
  bool reading = false, ready = false, fit = true;
  Timer? _again;
  int _seq = 0;
  final mc = MapController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      rDate = SessionScope.read(context).today;
      _load();
    });
  }

  @override
  void dispose() {
    _again?.cancel();
    mc.dispose();
    super.dispose();
  }

  /// read again every 20 seconds while this screen is seen and no route is shown (the web's vtLoad)
  Future<void> _load({bool quiet = false}) async {
    final s = SessionScope.read(context), my = ++_seq;
    _again?.cancel();
    try {
      final r = _map(await s.api.call('vlLive'));
      if (!mounted || my != _seq) return;
      setState(() {
        d = r;
        err = '';
      });
      _fit();
    } catch (e) {
      if (!mounted) return;
      if (!quiet) setState(() => err = errText(e));
    }
    if (!mounted) return;
    _again = Timer(const Duration(seconds: 20), () {
      if (mounted && route == null && (ModalRoute.of(context)?.isCurrent ?? true)) _load(quiet: true);
    });
  }

  List<Map<String, dynamic>> get _vehicles => _maps(d?['vehicles']);
  List<Map<String, dynamic>> get _placed => _vehicles.where((v) => _map(v['gps'])['lat'] != null && _map(v['gps'])['lng'] != null).toList();
  LatLng _ll(Map g) => LatLng((asNum(g['lat']) ?? 0).toDouble(), (asNum(g['lng']) ?? 0).toDouble());

  /// the map shows every vehicle (the first time) or the whole route
  void _fit() {
    if (!ready) return;
    final pts = route != null ? [for (final p in (route!['points'] as List? ?? const [])) if (p is List && p.length > 1) LatLng((asNum(p[0]) ?? 0).toDouble(), (asNum(p[1]) ?? 0).toDouble())] : (fit ? [for (final v in _placed) _ll(_map(v['gps']))] : <LatLng>[]);
    if (pts.isEmpty) return;
    try {
      if (pts.length == 1) {
        mc.move(pts.first, 15);
      } else {
        mc.fitCamera(CameraFit.bounds(bounds: LatLngBounds.fromPoints(pts), padding: const EdgeInsets.all(44), maxZoom: route != null ? 16 : 15));
      }
      if (route == null) fit = false;
    } catch (_) {/* the map not drawn yet: the next reading fits it */}
  }

  void _focus(Map<String, dynamic> v) {
    HapticFeedback.selectionClick();
    setState(() => rNo = '${v['no']}');
    final g = _map(v['gps']);
    if (g['lat'] == null || route != null || !ready) return;
    try {
      mc.move(_ll(g), 15);
    } catch (_) {}
  }

  Future<void> _route() async {
    final s = SessionScope.read(context);
    if (rNo.isEmpty || rDate.isEmpty) {
      toast(context, 'Pick the vehicle and the date.', bad: true);
      return;
    }
    setState(() => reading = true);
    try {
      final r = _map(await s.api.call('vlRoute', [{'no': rNo, 'date': rDate}]));
      if (!mounted) return;
      final pts = r['points'] as List? ?? const [], ss = _maps(r['sessions']), off = _maps(r['off']);
      if (pts.isEmpty) {
        setState(() {
          route = null;
          rNote = 'No GPS point of $rNo on ${showDate(rDate)}${ss.isNotEmpty ? ' – the phone sent no place.' : ' – it was with no driver of the Smart Log Book.'}';
        });
        return;
      }
      _again?.cancel();
      final km = ss.fold<num>(0, (a, x) => a + (asNum(_map(x['gps'])['km']) ?? 0));
      setState(() {
        route = r;
        rNote = '$rNo · ${showDate(rDate)}: ${ss.map((x) => '${x['driverName'] ?? x['driver']} (${tr('${x['shift'] ?? ''}')})').join(', ')} · ${fmtNum((km * 10).round() / 10)} km by GPS · ${pts.length} points${off.isEmpty ? '' : ' · GPS off ${off.length} time${off.length == 1 ? '' : 's'}'}';
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _fit());
    } catch (e) {
      if (mounted) toast(context, errText(e), bad: true);
    } finally {
      if (mounted) setState(() => reading = false);
    }
  }

  void _back() {
    setState(() {
      route = null;
      rNote = '';
      fit = true;
    });
    _load();
  }

  Widget _pin(Map<String, dynamic> v) {
    final (c, _) = _tone('${v['state']}');
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(10), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .25), blurRadius: 4, offset: const Offset(0, 2))]),
        child: Text('${v['no']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Colors.white)),
      ),
      Container(width: 10, height: 10, margin: const EdgeInsets.only(top: 2), decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2))),
    ]);
  }

  Widget _mapView() {
    final r = route;
    final ll = r == null ? <LatLng>[] : [for (final p in (r['points'] as List? ?? const [])) if (p is List && p.length > 1) LatLng((asNum(p[0]) ?? 0).toDouble(), (asNum(p[1]) ?? 0).toDouble())];
    final off = r == null ? const <Map<String, dynamic>>[] : _maps(r['off']).where((o) => o['lat'] != null && o['lng'] != null).toList();
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(children: [
        FlutterMap(
          key: const Key('vt-map'),
          mapController: mc,
          options: MapOptions(
            initialCenter: const LatLng(19.0, 75.5),
            initialZoom: 7,
            backgroundColor: const Color(0xFFE8ECEA),
            interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
            onMapReady: () {
              ready = true;
              _fit();
            },
          ),
          children: [
            if (SlbMap.tiles) TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'in.rachana.rcl.rcl_mobile', maxZoom: 19),
            if (ll.length > 1) PolylineLayer(polylines: [Polyline(points: ll, color: const Color(0xFF6D28D9), strokeWidth: 4)]),
            if (ll.isNotEmpty)
              CircleLayer(circles: [
                for (final o in off) CircleMarker(point: _ll(o), radius: 6, color: const Color(0xFFF59E0B), borderColor: const Color(0xFFB45309), borderStrokeWidth: 2),
                CircleMarker(point: ll.first, radius: 7, color: const Color(0xFF15803D), borderColor: Colors.white, borderStrokeWidth: 2),
                CircleMarker(point: ll.last, radius: 7, color: const Color(0xFFB91C1C), borderColor: Colors.white, borderStrokeWidth: 2),
              ]),
            if (r == null) MarkerLayer(markers: [for (final v in _placed) Marker(point: _ll(_map(v['gps'])), width: 120, height: 42, alignment: Alignment.topCenter, child: GestureDetector(onTap: () => _focus(v), child: _pin(v)))]),
          ],
        ),
        Positioned(
          right: 6,
          bottom: 4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: .85), borderRadius: BorderRadius.circular(6)),
            child: const Text('© OpenStreetMap', style: TextStyle(fontSize: 10.5, color: C.muted)),
          ),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context), today = s.today, vs = _vehicles, h = MediaQuery.of(context).size.height;
    final nos = <String>{for (final v in vs) '${v['no']}', for (final m in s.machines) m.id}.where((x) => x.isNotEmpty).toList();
    return Scaffold(
      appBar: slbBar(context, 'Live Tracking', d == null ? bi('Every vehicle on duty on the map', 'काम सुरू असलेल्या गाड्या map वर') : '${_nowWords(DateTime.tryParse('${d!['at']}') ?? s.clock())} · ${tr('every 20 s')}', pic: 'round_pushpin'),
      body: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(12, 12, 12, 0), child: SizedBox(height: (h * .38).clamp(220.0, 420.0), child: _mapView())),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => route == null ? _load() : _route(),
            child: ListView(key: const Key('vt-list'), padding: const EdgeInsets.fromLTRB(16, 8, 16, 30), children: [
              if (err.isNotEmpty) InfoLine(err, bad: true),
              if (route == null && d != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(vs.isNotEmpty && _placed.isEmpty ? 'No vehicle has sent its place yet – the driver\'s phone sends it while the vehicle is with him.' : '"Live": the phone sent its place in the last 10 minutes.',
                      key: const Key('vt-note'), style: const TextStyle(fontSize: 12.5, color: C.muted)),
                ),
              if (route != null)
                _card(
                  key: const Key('vt-route-note'),
                  color: _purpleSoft,
                  Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Text(rNote, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF4C1D95))),
                    const SizedBox(height: 8),
                    Wrap(spacing: 12, runSpacing: 4, children: [
                      for (final (c, l) in const [(Color(0xFF15803D), 'Start'), (Color(0xFFB91C1C), 'End'), (Color(0xFFF59E0B), 'GPS off')])
                        Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 10, height: 10, decoration: BoxDecoration(color: c, shape: BoxShape.circle)), const SizedBox(width: 4), Text(l, style: const TextStyle(fontSize: 12.5))]),
                    ]),
                    Align(alignment: Alignment.centerRight, child: TextButton.icon(key: const Key('vt-live'), onPressed: _back, icon: const Icon(Icons.my_location_rounded), label: Text('Back to live', mr: 'Live वर परत'))),
                  ]),
                ),
              if (route == null) ...[
                _head('On duty now', 'आत्ता कामावर', count: d == null ? '' : '${vs.length}'),
                if (d != null && vs.isEmpty) _card(Text('No vehicle is with a driver now.', style: const TextStyle(color: C.muted))),
                for (final v in vs) _vehRow(v, today),
              ],
              _head('Route of a day', 'दिवसाचा route'),
              _card(
                key: const Key('vt-route-box'),
                Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  PickField(key: const Key('vt-no'), label: 'Vehicle', value: rNo, blank: '– pick –', items: nos, onChanged: (v) => setState(() => rNo = v)),
                  const SizedBox(height: 10),
                  DateField(key: const Key('vt-date'), label: 'Date', value: rDate, clear: false, last: parseKey(today.isEmpty ? dateKey(DateTime.now()) : today), onChanged: (v) => setState(() => rDate = v)),
                  if (route == null && rNote.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(rNote, key: const Key('vt-rnote'), style: const TextStyle(fontSize: 13, color: C.amber, fontWeight: FontWeight.w600))),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 48,
                    child: FilledButton.icon(
                      key: const Key('vt-route'),
                      style: FilledButton.styleFrom(backgroundColor: _purple, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                      onPressed: reading ? null : _route,
                      icon: reading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.route_rounded),
                      label: Text('Show the route', mr: 'Route दाखवा', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ]),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _vehRow(Map<String, dynamic> v, String today) {
    final g = _map(v['gps']), st = '${v['state'] ?? ''}', sp = asNum(g['speed']), km = asNum(g['km']) ?? 0;
    final (c, bg) = _tone(st);
    return Padding(padding: const EdgeInsets.only(bottom: 10), child: Press(
      key: Key('vt-veh-${v['no']}'),
      onTap: () => _focus(v),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${v['no']}', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: rNo == '${v['no']}' ? _purple : C.ink)),
            Text('${v['driverName'] ?? v['driver'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: C.muted)),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Pill(_kind(st), color: c, bg: bg),
          const SizedBox(height: 2),
          Text('${sp != null && st == 'live' ? '${fmtNum((sp * 3.6).round())} km/h · ' : ''}${km > 0 ? '${fmtNum(km)} km' : _when(v['since'], today)}', style: const TextStyle(fontSize: 12, color: C.muted)),
        ]),
      ]),
    ));
  }
}
