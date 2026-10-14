/* REPORTS – the reports of the web he may open (Dashboard, Daily Inward & Issue, Monthly Diesel Issue, Monthly Diesel &
 * Average). Each opens inside the app, on its page; Excel and Print there go to the phone (share sheet, Android printing). */
import 'package:flutter/material.dart';

import '../ui/scope.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import '../web/web_host.dart';
import 'home.dart';

class ReportsTab extends StatelessWidget {
  const ReportsTab({super.key});
  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    final list = reportsOf(s);
    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 30), children: [
          const Padding(padding: EdgeInsets.fromLTRB(4, 0, 4, 4), child: TwoLang('Reports', 'रिपोर्ट्स', size: 28, weight: FontWeight.w800)),
          Padding(padding: const EdgeInsets.fromLTRB(4, 0, 4, 16), child: Text(s.siteName, style: const TextStyle(fontSize: 15, color: C.muted, fontWeight: FontWeight.w600))),
          if (list.isEmpty) const EmptyState('No reports for you yet', 'Ask the Admin for access to Reports or Dashboard.', pic: 'bar_chart'),
          for (final r in list)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Press(
                onTap: () => openWeb(context, r.$1, r.$3, pic: r.$4),
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  Container(width: 62, height: 62, decoration: BoxDecoration(color: C.blueSoft, borderRadius: BorderRadius.circular(18)), alignment: Alignment.center, child: Pic(r.$4, size: 44)),
                  const SizedBox(width: 14),
                  Expanded(child: TwoLang(r.$1, r.$2, size: 17, weight: FontWeight.w700)),
                  const Icon(Icons.chevron_right_rounded, color: C.faint),
                ]),
              ),
            ),
          if (list.isNotEmpty) const Padding(padding: EdgeInsets.fromLTRB(4, 6, 4, 0), child: Text('Excel and Print in a report open on the phone – share, keep or print (PDF).', style: TextStyle(fontSize: 13, color: C.muted))),
        ]),
      ),
    );
  }
}
