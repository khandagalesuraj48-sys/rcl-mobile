/* (3.88.0, Mechanical update-213) VEHICLE ALERTS – the app's own screen (the web: Dashboard → ⚠ Vehicle alerts): every machinery
 * that needs a look – its papers, service, more diesel – and a fuel card below its amount. Opened from the bell and the Dashboard.
 * At a site on fuel cards (HO) a car opens its Vehicle Details. */
import 'package:flutter/material.dart' hide Text;

import '../core/format.dart';
import '../core/veh_alerts.dart';
import '../ui/scope.dart';
import '../ui/t.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'car_detail.dart' show carIcon, openVehicle;
import 'fuel_cards.dart' show rupees;

Future<void> openVehAlerts(BuildContext context) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const VehAlertsScreen()));

/// one alert as a pill (red: expired / overdue / bad; amber: due / more diesel)
Widget vehAlertPill(VehAlert a, {Key? key, double size = 12}) => Container(
      key: key,
      margin: const EdgeInsets.only(right: 5, bottom: 5),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: a.bad ? C.redSoft : C.amberSoft, borderRadius: BorderRadius.circular(9)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(a.k == 'paper' ? Icons.description_rounded : a.k == 'svc' ? Icons.build_rounded : Icons.local_gas_station_rounded, size: size + 2, color: a.bad ? C.red : C.amber),
        const SizedBox(width: 4),
        Flexible(child: Text(a.text, style: TextStyle(fontSize: size, fontWeight: FontWeight.w600, color: a.bad ? C.red : const Color(0xFF8A5A00)))),
      ]),
    );

class VehAlertsScreen extends StatefulWidget {
  const VehAlertsScreen({super.key});
  @override
  State<VehAlertsScreen> createState() => _VehAlertsScreenState();
}

class _VehAlertsScreenState extends State<VehAlertsScreen> {
  @override
  void initState() {
    super.initState();
    VehAlerts.i.addListener(_changed);
    WidgetsBinding.instance.addPostFrameCallback((_) => VehAlerts.i.load(SessionScope.read(context)));
  }

  @override
  void dispose() {
    VehAlerts.i.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context), v = VehAlerts.i, nos = v.cars.keys.toList()..sort();
    final counts = <(String, num)>[('papers', v.count['paper'] ?? 0), ('service', v.count['svc'] ?? 0), ('more diesel', v.count['avg'] ?? 0), ('fuel card low', v.count['card'] ?? 0)].where((x) => x.$2 > 0).toList();
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(title: Text('Vehicle alerts', style: const TextStyle(fontWeight: FontWeight.w700))),
      body: RefreshIndicator(
        color: C.green,
        onRefresh: () => v.load(s),
        child: ListView(key: const Key('va-list'), padding: const EdgeInsets.fromLTRB(16, 10, 16, 30), children: [
          if (!v.loaded) const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator())),
          if (v.loaded && v.n == 0) const EmptyState('No alert', 'Every paper, service, average and fuel card is fine.', pic: 'shield'),
          if (counts.isNotEmpty)
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final c in counts) Pill('${fmtNum(c.$2)} ${tr(c.$1)}', color: C.ink, bg: Colors.white),
            ]),
          for (final no in nos)
            Container(
              key: Key('va-car-$no'),
              margin: const EdgeInsets.only(top: 10),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: s.cardSite && s.canSee('Dashboard') ? () => openVehicle(context, no) : null,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 11, 10, 7),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(width: 38, height: 38, decoration: BoxDecoration(color: C.greenSoft, borderRadius: BorderRadius.circular(12)), child: Icon(carIcon(s.machine(no)?.type ?? ''), color: C.greenDark, size: 21)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(no, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 5),
                        Wrap(children: [for (final (i, a) in v.cars[no]!.indexed) vehAlertPill(a, key: Key('va-$no-$i'))]),
                      ]),
                    ),
                    if (s.cardSite && s.canSee('Dashboard')) const Icon(Icons.chevron_right_rounded, color: C.faint),
                  ]),
                ),
              ),
            ),
          for (final c in v.cards)
            Container(
              key: Key('va-card-${c['name']}'),
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
              child: Row(children: [
                Container(width: 38, height: 38, decoration: BoxDecoration(color: C.redSoft, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.credit_card_rounded, color: C.red, size: 21)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${c['name']}${'${c['last4'] ?? ''}'.isEmpty ? '' : ' ••${c['last4']}'}', style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
                    Text('${rupees(asNum(c['balance']))} – ${tr('below')} ${rupees(asNum(c['lowAt']))}', style: const TextStyle(fontSize: 13, color: C.red, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ]),
            ),
        ]),
      ),
    );
  }
}
