/* PURCHASE – the app's own screen (3.72.0) of the Purchase module (rcl-purchase, the Purchase Department – one for every site):
 * Home → Purchase. Its Dashboard as the web's: the sites where he has Purchase (the site open now marked) and his role there. Its
 * own sign-in (a ticket of the Portal for 'purchase', used once – api.purOpen); nothing is saved from here. The purchase work
 * comes page by page on the web – each with its own screen here in the same piece of work. */
import 'package:flutter/material.dart' hide Text;

import '../ui/ask_bot.dart';
import '../ui/scope.dart';
import '../ui/t.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

Future<void> openPurchase(BuildContext context) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const PurchaseScreen()));

/// His role in Purchase as the web names it.
String purRole(String r) => switch (r) { 'super' => 'Super Admin', 'admin' => 'Purchase Admin', 'user' => 'Purchase User', _ => '' };

class PurchaseScreen extends StatefulWidget {
  const PurchaseScreen({super.key});
  @override
  State<PurchaseScreen> createState() => _PurchaseScreenState();
}

class _PurchaseScreenState extends State<PurchaseScreen> {
  Map<String, dynamic>? me;
  String err = '';
  bool loading = true, started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (started) return;
    started = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    final s = SessionScope.read(context), site = s.site, m = site?.module('purchase');
    setState(() {
      loading = true;
      err = '';
    });
    try {
      if (site == null || m == null) throw StateError('none');
      final j = await s.api.purOpen(site.code, m.url);
      if (mounted) {
        setState(() {
          me = j;
          loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          err = e is StateError ? 'You have no Purchase on this site – the Super Admin gives it in the Portal.' : errText(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context), u = (me?['user'] as Map?) ?? const {}, role = purRole('${u['role'] ?? ''}');
    final open = '${me?['site'] ?? s.site?.code ?? ''}';
    final sites = [for (final x in (me?['sites'] as List? ?? const []).whereType<Map>()) x];
    if (me != null && sites.isEmpty) sites.add({'code': open, 'name': me?['siteName'] ?? open});
    return Scaffold(
      appBar: AppBar(
        title: const TwoLang('Purchase', 'खरेदी', size: 20, weight: FontWeight.w700),
        actions: withAsk([IconButton(tooltip: tr('Refresh'), onPressed: _start, icon: const Icon(Icons.refresh_rounded))]),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _start,
              child: ListView(key: const Key('pur-dash'), padding: const EdgeInsets.fromLTRB(16, 10, 16, 40), children: [
                if (err.isNotEmpty) InfoLine(err, bad: true),
                if (me != null) ...[
                  Text('${u['name'] ?? s.name} · $role · ${me?['siteName'] ?? s.siteName}', style: const TextStyle(fontSize: 12.5, color: C.muted)),
                  const SizedBox(height: 10),
                  const TwoLang('Purchase Department', 'खरेदी विभाग', size: 18, weight: FontWeight.w800),
                  const SizedBox(height: 4),
                  Text(bi('One Purchase for every site – the sites of today and every new one.', 'सर्व sites साठी एकच खरेदी विभाग.'), style: const TextStyle(fontSize: 13.5, color: C.muted, height: 1.35)),
                  const SizedBox(height: 14),
                  Container(
                    key: const Key('pur-count'),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: C.blueSoft, borderRadius: BorderRadius.circular(18)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(bi('Your sites with Purchase', 'Purchase असलेल्या तुमच्या sites'), style: const TextStyle(fontSize: 13, color: C.muted, fontWeight: FontWeight.w600)),
                      Text('${sites.length}', style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: C.blue)),
                      Text(role, style: const TextStyle(fontSize: 12.5, color: C.muted)),
                    ]),
                  ),
                  const SizedBox(height: 10),
                  for (final x in sites)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        key: Key('pur-site-${x['code']}'),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.line)),
                        child: Row(children: [
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('${x['name'] ?? x['code']}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                              Text('${x['code']}', style: const TextStyle(fontSize: 12.5, color: C.muted)),
                            ]),
                          ),
                          if ('${x['code']}' == open) const Pill('Open now'),
                        ]),
                      ),
                    ),
                  const SizedBox(height: 6),
                  Text(bi('A new site shows here by itself once the Super Admin gives you Purchase on it (Portal → Users & Access).', 'नवीन site ला Purchase दिले की ती इथे आपोआप दिसेल.'),
                      style: const TextStyle(fontSize: 13, color: C.muted, height: 1.35)),
                ],
              ]),
            ),
    );
  }
}
