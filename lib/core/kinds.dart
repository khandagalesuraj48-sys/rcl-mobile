import 'package:flutter/material.dart';

import '../ui/theme.dart';

/// The three diesel entries of the app – each with the access column of Mechanical it follows.
class Kind {
  const Kind(this.key, this.module, this.en, this.mr, this.color, this.soft, this.icon, this.pic, this.list, this.save);
  final String key, module, en, mr, pic;
  final Color color, soft;
  final IconData icon;
  final String list, save; // the actions of Mechanical
}

const kKinds = [
  Kind('issue', 'Diesel Issue', 'Diesel Issue', 'डिझेल देणे', C.green, C.greenSoft, Icons.local_gas_station_rounded, 'fuel_pump', 'getDieselIssues', 'saveDieselIssue'),
  Kind('inward', 'Diesel Inward', 'Diesel Inward', 'डिझेल आले', C.blue, C.blueSoft, Icons.download_rounded, 'inbox_tray', 'getInwards', 'saveInward'),
  Kind('transfer', 'Diesel Transfer', 'Transfer', 'डिझेल पाठवले', C.purple, C.purpleSoft, Icons.swap_horiz_rounded, 'left-right_arrow', 'getTransfers', 'saveTransfer'),
];

Kind kindOf(String key) => kKinds.firstWhere((k) => k.key == key, orElse: () => kKinds.first);

/// (3.1.10, with Mechanical update-117: every site its own diesel places, set by the Super Admin in the Portal) the Marathi word
/// under a diesel place on Home. The first site's Dispenser / VTR Store keep their words; 18B's Camp Pump is the pump and its two
/// dispensers, named by their numbers (MH12ZE1739, MH12WJ1381), are dispensers – before, every other place said "store".
String placeMr(String name) {
  final n = name.toLowerCase(), k = n.replaceAll(RegExp(r'[^a-z0-9]'), '');
  if (n.contains('dispenser')) return 'डिस्पेन्सर';
  if (n.contains('store')) return 'स्टोअर';
  if (n.contains('pump')) return 'पंप';
  if (RegExp(r'^[a-z]{2}\d{1,2}[a-z]{0,3}\d{3,4}$').hasMatch(k)) return 'डिस्पेन्सर';      // a vehicle number: a dispenser on a vehicle
  return 'डिझेल जागा';
}

/// The 3D picture for a machinery, from its type (an excavator, a tipper, a car …).
String picOfType(String type) {
  final t = type.toLowerCase();
  if (RegExp(r'excavat|poclain|pc ?\d|hydra|crane|sany|kobelco|tata hitachi').hasMatch(t)) return 'building_construction';
  if (RegExp(r'tipper|dumper|hyva|truck|lorry|trailer|tanker|transit|tm\b|mixer').hasMatch(t)) return 'articulated_lorry';
  if (RegExp(r'jcb|backhoe|loader|tractor|roller|grader|dozer|paver|compactor').hasMatch(t)) return 'tractor';
  if (RegExp(r'bolero|jeep|scorpio|car|suv|innova|ertiga').hasMatch(t)) return 'sport_utility_vehicle';
  if (RegExp(r'pickup|pick-up|pick up|camper|tempo|ace').hasMatch(t)) return 'pickup_truck';
  if (RegExp(r'bus|van').hasMatch(t)) return 'bus';
  if (RegExp(r'bike|motor ?cycle|splendor|scooter').hasMatch(t)) return 'motorcycle';
  if (RegExp(r'dg|generator|kva|pump|compressor|plant|batching|crusher').hasMatch(t)) return 'oil_drum';
  return 'delivery_truck';
}
