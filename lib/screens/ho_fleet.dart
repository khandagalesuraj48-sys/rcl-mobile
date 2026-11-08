/* (3.87.0, asked 08-11-2026: "RCL ERP – Premium Mobile App Redesign" Parts 1–3, with his picture; his answer: the new Home "fakt
 * HO") HO'S HOME – MY FLEET: the cars of HO (its Asset Master, on site this month) as the main part of Home –
 *   – each car: its PHOTO ALONE (the photo the Super Admin / Admin set – the same photos as the web and the Portal, never another
 *     copy; nothing is written on the photo), its NUMBER under the photo, make and model, kind, fuel, KM now, Active / Inactive;
 *   – All / each kind (chips), a list (as his picture) or a grid of two;
 *   – a tap: the car's Vehicle Details (car_detail.dart).
 * The figures and the photos are the server's (getCardDash of this month – the Dashboard's access, as the web); a person without the
 * Dashboard sees his site's cars with their pictures of a car. The photos' links renew by themselves (core/car_photos.dart). */
import 'package:flutter/material.dart' hide Text;

import '../core/car_photos.dart';
import '../core/format.dart';
import '../core/session.dart';
import '../core/veh_alerts.dart';
import '../ui/scope.dart';
import '../ui/t.dart';
import '../ui/theme.dart';
import 'car_detail.dart';
import 'veh_alerts.dart' show vehAlertPill;

/// HO's cars on Home: on the site today or at some day of this month; the Active first, then by number.
List<Machine> hoFleet(Session s) {
  final to = s.today.isNotEmpty ? s.today : dateKey(DateTime.now()), from = '${to.substring(0, 8)}01';
  final l = s.machines.where((m) => m.onSite(to) || m.onSite(from)).toList();
  l.sort((a, b) => a.active == b.active ? a.id.compareTo(b.id) : (a.active ? -1 : 1));
  return l;
}

class HoFleet extends StatefulWidget {
  const HoFleet({super.key, required this.tick});

  /// Home's loads (opened, pulled down, a change by someone else): each one reads the cars' figures again
  final int tick;
  @override
  State<HoFleet> createState() => _HoFleetState();
}

class _HoFleetState extends State<HoFleet> {
  /// list (as his picture) or grid – kept while the app is open
  static bool grid = false;
  String kind = '';
  Map<String, Map<String, dynamic>> byNo = {};
  int _seq = 0;

  @override
  void initState() {
    super.initState();
    CarPhotos.i.addListener(_changed);
    VehAlerts.i.addListener(_changed);      // (3.88.0) the cars' alerts
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void didUpdateWidget(HoFleet old) {
    super.didUpdateWidget(old);
    if (old.tick != widget.tick) _load();
  }

  @override
  void dispose() {
    CarPhotos.i.removeListener(_changed);
    VehAlerts.i.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    final s = SessionScope.read(context), my = ++_seq;
    if (!s.canSee('Dashboard')) return;
    final to = s.today.isNotEmpty ? s.today : dateKey(DateTime.now());
    try {
      final r = (await s.api.call('getCardDash', [{'from': '${to.substring(0, 8)}01', 'to': to}]) as Map).cast<String, dynamic>();
      if (!mounted || my != _seq) return;
      final cars = [for (final c in (r['cars'] as List? ?? const []).whereType<Map>()) c.cast<String, dynamic>()];
      if (r['cards'] != null) s.setCards(r['cards']);      // (the cards' balances above, fresh too)
      CarPhotos.i.putAll(cars);
      setState(() => byNo = {for (final c in cars) '${c['no']}': c});
    } catch (_) {/* the cars still show, without their figures; Home's own line says when the network is gone */}
  }

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context), all = hoFleet(s);
    final kinds = <String, int>{};
    for (final m in all) {
      final k = m.type.isEmpty ? 'Other' : m.type;
      kinds[k] = (kinds[k] ?? 0) + 1;
    }
    if (kind.isNotEmpty && !kinds.containsKey(kind)) kind = '';
    final list = [for (final m in all) if (kind.isEmpty || (m.type.isEmpty ? 'Other' : m.type) == kind) m];
    return Column(key: const Key('ho-fleet'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(child: Text('${tr('My Fleet')} (${all.length})', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.line)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            for (final v in const [(false, Icons.view_agenda_rounded, 'List'), (true, Icons.grid_view_rounded, 'Gallery')])
              Material(
                color: grid == v.$1 ? C.green : Colors.transparent,
                borderRadius: BorderRadius.circular(11),
                child: InkWell(
                  key: Key(v.$1 ? 'hf-view-grid' : 'hf-view-list'),
                  borderRadius: BorderRadius.circular(11),
                  onTap: () => setState(() => grid = v.$1),
                  child: Tooltip(message: tr(v.$3), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), child: Icon(v.$2, size: 19, color: grid == v.$1 ? Colors.white : C.muted))),
                ),
              ),
          ]),
        ),
      ]),
      const SizedBox(height: 10),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          _chip('', '${tr('All')} (${all.length})'),
          for (final k in kinds.entries) _chip(k.key, '${tr(k.key)} (${k.value})'),
        ]),
      ),
      const SizedBox(height: 10),
      if (all.isEmpty)
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
          child: Text('No car in this site\'s Asset Master yet.', style: const TextStyle(color: C.muted)),
        )
      else if (grid)
        LayoutBuilder(builder: (_, bc) {
          final w = (bc.maxWidth - 10) / 2;
          return Wrap(spacing: 10, runSpacing: 10, children: [for (final m in list) SizedBox(width: w, child: _FleetTile(m: m, x: byNo[m.id], onTap: () => openVehicle(context, m.id)))]);
        })
      else
        for (final m in list) Padding(padding: const EdgeInsets.only(bottom: 10), child: _FleetRow(m: m, x: byNo[m.id], onTap: () => openVehicle(context, m.id))),
    ]);
  }

  Widget _chip(String k, String label) {
    final on = kind == k;
    return Padding(
      padding: const EdgeInsets.only(right: 7),
      child: Material(
        color: on ? C.green : Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          key: Key('hf-kind-${k.isEmpty ? 'all' : k}'),
          borderRadius: BorderRadius.circular(20),
          onTap: () => setState(() => kind = k),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: on ? C.green : C.line)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (k.isNotEmpty) ...[Icon(carIcon(k), size: 16, color: on ? Colors.white : C.muted), const SizedBox(width: 5)],
              Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: on ? Colors.white : C.ink)),
            ]),
          ),
        ),
      ),
    );
  }
}

/// its make: the Asset Master's, else the one the server gave with its figures
String _make(Machine m, Map<String, dynamic>? x) {
  final a = '${m.m['make'] ?? ''}'.trim();
  return a.isNotEmpty ? a : '${x?['make'] ?? ''}'.trim();
}
String _kmNow(Map<String, dynamic>? x) => asNum(x?['kmNow']) != null ? '${fmtNum(asNum(x!['kmNow']))} km' : '–';

Widget _status(Machine m, Map<String, dynamic>? x) {
  final off = '${x?['status'] ?? m.status}' == 'Inactive';
  return Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(Icons.circle, size: 8, color: off ? C.red : C.green),
    const SizedBox(width: 4),
    Text(off ? 'Inactive' : 'Active', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: off ? C.red : C.greenDark)),
  ]);
}

/// (3.88.0, Mechanical update-213) a car's alerts under it – the first [max], then "+ n more"
List<Widget> _alerts(String no, int max) {
  final l = VehAlerts.i.of(no);
  if (l.isEmpty) return const [];
  return [
    const SizedBox(height: 6),
    Wrap(key: Key('hf-va-$no'), children: [
      for (final a in l.take(max)) vehAlertPill(a, size: 11),
      if (l.length > max) Padding(padding: const EdgeInsets.only(top: 3), child: Text('+${l.length - max} ${tr('more')}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: C.red))),
    ]),
  ];
}

Widget _line(IconData ic, String t) => Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Row(children: [
        Icon(ic, size: 16, color: C.greenDark),
        const SizedBox(width: 6),
        Expanded(child: Text(t, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: C.ink))),
      ]),
    );

/// A car in the list: the photo on the left with the number under it; make, model, kind, fuel, KM now, status on the right.
class _FleetRow extends StatelessWidget {
  const _FleetRow({required this.m, required this.x, required this.onTap});
  final Machine m;
  final Map<String, dynamic>? x;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final mk = _make(m, x);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      elevation: 0,
      child: InkWell(
        key: Key('hf-car-${m.id}'),
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
              width: 150,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                ClipRRect(borderRadius: BorderRadius.circular(14), child: AspectRatio(aspectRatio: 4 / 3, child: CarPic(m.id, type: m.type, words: false))),
                const SizedBox(height: 7),
                FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(m.id, key: Key('hf-no-${m.id}'), style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, letterSpacing: .3))),
              ]),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (mk.isNotEmpty) Text(mk, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                if (m.name.isNotEmpty) Text(m.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: mk.isEmpty ? 15 : 14, fontWeight: mk.isEmpty ? FontWeight.w800 : FontWeight.w600, color: mk.isEmpty ? C.ink : C.muted)),
                if (m.type.isNotEmpty) _line(carIcon(m.type), m.type),
                _line(Icons.local_gas_station_rounded, m.fuel),
                _line(Icons.speed_rounded, _kmNow(x)),
                const SizedBox(height: 6),
                _status(m, x),
                ..._alerts(m.id, 2),
              ]),
            ),
            const Padding(padding: EdgeInsets.only(top: 34), child: Icon(Icons.chevron_right_rounded, color: C.faint)),
          ]),
        ),
      ),
    );
  }
}

/// A car in the grid: the photo, then its number, make · model, fuel and KM now, status.
class _FleetTile extends StatelessWidget {
  const _FleetTile({required this.m, required this.x, required this.onTap});
  final Machine m;
  final Map<String, dynamic>? x;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final mm = [_make(m, x), m.name].where((v) => v.isNotEmpty).join(' · ');
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('hf-car-${m.id}'),
        onTap: onTap,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          AspectRatio(aspectRatio: 4 / 3, child: CarPic(m.id, type: m.type, words: false)),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(m.id, key: Key('hf-no-${m.id}'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: .3))),
              if (mm.isNotEmpty) Text(mm, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: C.muted)),
              const SizedBox(height: 4),
              Text('${m.fuel} · ${_kmNow(x)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5)),
              const SizedBox(height: 4),
              _status(m, x),
              ..._alerts(m.id, 1),
            ]),
          ),
        ]),
      ),
    );
  }
}
