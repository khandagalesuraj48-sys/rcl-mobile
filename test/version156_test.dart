/* (Mechanical update-156) every edit screen of the app sends the version it opened – as the web page does: Diesel Issue (since
 * update-145), Inward, Transfer, Payments, Asset Master (one, many, delete), Vendor BOQ, Vendor Master. Changed by someone else
 * meanwhile → the server refuses it with who changed it; nothing is saved. Checked here in the app's own code (the server's
 * check is in Mechanical's unit tests and its rig tests). */
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String src(String f) => File('lib/screens/$f').readAsStringSync();
  test('each edit and delete carries the version it opened', () {
    final want = <String, List<String>>{
      'forms.dart': ["if (ed != null && '\${ed!['ver'] ?? ''}'.isNotEmpty) d['ver'] = '\${ed!['ver']}';"],
      'entries.dart': ["await s.api.call(deleteOf(kind.key), [r['id'], if ('\${r['ver'] ?? ''}'.isNotEmpty) '\${r['ver']}'], true);"],
      'bill_money.dart': ["editVer = '\${p['ver'] ?? ''}';", "if (editId.isNotEmpty && editVer.isNotEmpty) 'ver': editVer", "s.api.call('deletePayment', [p['id'], if ('\${p['ver'] ?? ''}'.isNotEmpty) '\${p['ver']}']"],
      'machine_form.dart': ["m['ver'] = '\${before!['ver']}';"],
      'machinery.dart': ["s.api.call('deleteMaster', [id, force, ver]", "s.api.call('editMasterMany', [list.map((m) => m['id']).toList(), ch, vers]", "s.api.call('deleteMasterMany', [ids, false, vers]", "s.api.call('deleteMasterMany', [ids, true, vers]"],
      'boq.dart': ["body['ver'] = '\${b!['ver'] ?? ''}';", "s.api.call('deleteBoq', ['\${b['id']}', '\${b['ver'] ?? ''}']"],
      'vendors.dart': ["if (saved) body['ver'] = '\${v?['ver'] ?? ''}';", "s.api.call('deleteVendor', ['\${v['name']}', '\${v['ver'] ?? ''}']"],
    };
    want.forEach((f, ks) {
      final s = src(f);
      for (final k in ks) {
        expect(s.contains(k), isTrue, reason: '$f: $k');
      }
    });
    // the edit forms keep the version they were opened with (not the list's of now): the payment form clears it with the form
    expect(src('bill_money.dart').contains("editId = '';\n      editVer = '';"), isTrue);
  });
}
