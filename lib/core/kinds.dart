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
