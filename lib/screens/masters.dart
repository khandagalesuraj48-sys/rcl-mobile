/* MACHINERY (Home → Machinery) – the web's "Master" group in the app's own screens (3.4.0): Asset Master, Vendor Master,
 * Vendor BOQ, Vehicle Compliance and Log Book Format, each by his access (as the web's menu: Master, Vendor Master, Vendor BOQ,
 * Vehicle Compliance; Log Book Format = Master). */
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';

import '../core/session.dart';
import '../ui/scope.dart';
import '../ui/t.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'boq.dart';
import 'compliance.dart';
import 'lb_formats.dart';
import 'machinery.dart';
import 'vendors.dart';
import '../ui/ask_bot.dart';

class MasterPage {
  const MasterPage(this.en, this.mr, this.sub, this.pic, this.perm, this.color, this.open);
  final String en, mr, sub, pic, perm;
  final Color color;
  final Future<void> Function(BuildContext) open;
}

final kMasterPages = [
  MasterPage('Asset Master', 'ॲसेट मास्टर', 'Every machinery: works on, standards, vendor, status, papers', 'tractor', 'Master', C.greenSoft, openAssetMaster),
  MasterPage('Vendor Master', 'व्हेंडर मास्टर', 'Owners of the assets: GST, PAN, bank', 'office_building', 'Vendor Master', C.blueSoft, openVendors),
  MasterPage('Vendor BOQ', 'व्हेंडर BOQ', 'Rate contracts, amendments, rate check', 'receipt', 'Vendor BOQ', C.purpleSoft, (c) => openBoq(c)),
  MasterPage('Vehicle Compliance', 'वाहन कागदपत्रे', 'Tax, PUC, Permit, Fitness, Insurance – renew', 'shield', 'Vehicle Compliance', C.amberSoft, openCompliance),
  MasterPage('Log Book Format', 'लॉगबुक फॉरमॅट', 'The print format of each machinery\'s Log Book', 'notebook', 'Master', C.slateSoft, openLbFormats),
];

List<MasterPage> mastersOf(Session s) => kMasterPages.where((p) => s.canSee(p.perm)).toList();

Future<void> openMasters(BuildContext context) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const MastersScreen()));

class MastersScreen extends StatelessWidget {
  const MastersScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    final list = mastersOf(s);
    return Scaffold(
      appBar: AppBar(actions: withAsk(), title: const TwoLang('Machinery', 'यंत्रे', size: 20, weight: FontWeight.w700)),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 30), children: [
        Padding(padding: const EdgeInsets.fromLTRB(4, 0, 4, 14), child: Text(s.siteName, style: const TextStyle(fontSize: 15, color: C.muted, fontWeight: FontWeight.w600))),
        if (list.isEmpty) const EmptyState('Nothing here for you yet', 'Ask the Admin for access to Master.', pic: 'tractor'),
        for (final p in list)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Press(
              key: Key('mp-${p.en}'),
              onTap: () {
                HapticFeedback.selectionClick();
                p.open(context);
              },
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                Container(width: 62, height: 62, decoration: BoxDecoration(color: p.color, borderRadius: BorderRadius.circular(18)), alignment: Alignment.center, child: Pic(p.pic, size: 44)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    TwoLang(p.en, p.mr, size: 17, weight: FontWeight.w700),
                    const SizedBox(height: 2),
                    Text(p.sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: C.muted)),
                  ]),
                ),
                const Icon(Icons.chevron_right_rounded, color: C.faint),
              ]),
            ),
          ),
      ]),
    );
  }
}
