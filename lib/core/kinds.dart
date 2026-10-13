import 'package:flutter/material.dart';

import '../ui/theme.dart';

/// The three diesel entries of the app – each with the access column of Mechanical it follows.
class Kind {
  const Kind(this.key, this.module, this.en, this.mr, this.color, this.soft, this.icon, this.list, this.save);
  final String key, module, en, mr;
  final Color color, soft;
  final IconData icon;
  final String list, save; // the actions of Mechanical
}

const kKinds = [
  Kind('issue', 'Diesel Issue', 'Diesel Issue', 'डिझेल देणे', C.green, C.greenSoft, Icons.local_gas_station_rounded, 'getDieselIssues', 'saveDieselIssue'),
  Kind('inward', 'Diesel Inward', 'Diesel Inward', 'डिझेल आले', C.blue, C.blueSoft, Icons.download_rounded, 'getInwards', 'saveInward'),
  Kind('transfer', 'Diesel Transfer', 'Transfer', 'डिझेल पाठवले', C.purple, C.purpleSoft, Icons.swap_horiz_rounded, 'getTransfers', 'saveTransfer'),
];

Kind kindOf(String key) => kKinds.firstWhere((k) => k.key == key, orElse: () => kKinds.first);
