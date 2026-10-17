/* THE PAGE TO OPEN AFTER SIGN-IN (3.14.0) – the web's Settings → "Page to open after sign-in" (pref "start"): kept with his
 * account, so the web and the app use the same choice. The value is the web page's name (diesel, log, master …); here each of
 * them opens the app's own screen for it. Only the pages he may open are offered (the web's TAB_MODULE; Users and Activity Log for
 * the Admin; Approvals for everybody, as in the app's Me). '' = the Dashboard (as usual) – in the app: Home. */
import 'package:flutter/material.dart';

import '../core/session.dart';
import 'admin.dart';
import 'approvals.dart';
import 'billing.dart';
import 'boq.dart';
import 'breakdown.dart';
import 'compliance.dart';
import 'lb_formats.dart';
import 'log_edit.dart';
import 'logbook.dart';
import 'machinery.dart';
import 'report_screen.dart';
import 'tank_check.dart';
import 'vendors.dart';

/// (web page, its name, the access it follows – '' = the Admin's page)
const kStartPages = <(String, String, String)>[
  ('diesel', 'Diesel Issue', 'Diesel Issue'),
  ('inward', 'Diesel Inward', 'Diesel Inward'),
  ('transfer', 'Diesel Transfer', 'Diesel Transfer'),
  ('log', 'Log Book', 'Log Book'),
  ('logedit', 'Edit Log Book', 'Log Book'),
  ('tankcheck', 'Tank Check', 'Log Book'),
  ('brk', 'Breakdown', 'Breakdown'),
  ('master', 'Asset Master', 'Master'),
  ('vendors', 'Vendor Master', 'Vendor Master'),
  ('boq', 'Vendor BOQ', 'Vendor BOQ'),
  ('comp', 'Vehicle Compliance', 'Vehicle Compliance'),
  ('lbf', 'Log Book Format', 'Master'),
  ('bill', 'Machinery Billing', 'Machinery Billing'),
  ('bills', 'RCL Drive – saved bills and debit notes', 'Saved Bills'),
  ('breg', 'Bill Summary', 'Bill Summary'),
  ('pay', 'Machinery Payments', 'Machinery Payments'),
  ('vled', 'Vendor Ledger', 'Vendor Ledger'),
  ('vout', 'Vendor Outstanding', 'Vendor Outstanding'),
  ('rdaily', 'Daily Diesel Inward & Issue Summary', 'Reports'),
  ('rmonthly', 'Monthly Diesel Issue Report', 'Reports'),
  ('ravg', 'Monthly Diesel & Average Report', 'Reports'),
  ('users', 'Users & Access', ''),
  ('activity', 'Activity Log', ''),
  ('approvals', 'Approvals', ''),
];

/// The start pages he may pick (the web lists the pages of his menu).
List<(String, String, String)> startPagesFor(Session s) => [
      for (final p in kStartPages)
        if (p.$1 == 'approvals' || (p.$3.isEmpty ? s.admin : s.canSee(p.$3))) p, // Approvals: for everybody (what waits for him, what he sent)
    ];

/// Opens his start page after the sign-in. [entries] shows the Entries tab of a diesel page (issue / inward / transfer).
Future<void> openStartPage(BuildContext context, Session s, String page, {required void Function(String kind) entries}) async {
  if (page.isEmpty || !startPagesFor(s).any((p) => p.$1 == page)) return;
  switch (page) {
    case 'diesel':
      entries('issue');
    case 'inward':
      entries('inward');
    case 'transfer':
      entries('transfer');
    case 'log':
      await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const LogBookScreen()));
    case 'logedit':
      await openLogEdit(context);
    case 'tankcheck':
      await openTankCheck(context);
    case 'brk':
      await openBreakdown(context);
    case 'master':
      await openAssetMaster(context);
    case 'vendors':
      await openVendors(context);
    case 'boq':
      await openBoq(context);
    case 'comp':
      await openCompliance(context);
    case 'lbf':
      await openLbFormats(context);
    case 'bill' || 'bills' || 'breg' || 'pay' || 'vled' || 'vout':
      openBillPage(context, kStartPages.firstWhere((p) => p.$1 == page).$3);
    case 'rdaily' || 'rmonthly' || 'ravg':
      final d = reportOfPage(page);
      if (d != null) await openReport(context, d);
    case 'users':
      await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const UsersScreen()));
    case 'activity':
      await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ActivityScreen()));
    case 'approvals':
      await openApprovals(context);
  }
}
