import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/kinds.dart';
import '../core/session.dart';
import '../core/update.dart';
import '../ui/scope.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'forms.dart';
import 'me.dart';

/// HOME: the stock now, today's issue, and a big tile for each entry the person may open (only those).
class HomeTab extends StatefulWidget {
  const HomeTab({super.key, this.update, required this.onOpenList});
  final AppUpdate? update;
  final ValueChanged<String> onOpenList;
  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  num? todayIssued;
  int todayEntries = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _today());
  }

  Future<void> _today() async {
    final s = SessionScope.read(context);
    if (!s.canSee('Diesel Issue') || s.today.isEmpty) return;
    try {
      final r = (await s.api.call('getDieselIssues', [{'from': s.today, 'to': s.today}]) as Map);
      if (!mounted) return;
      setState(() {
        todayIssued = asNum(r['totalQty']);
        todayEntries = (r['count'] as num?)?.toInt() ?? 0;
      });
    } catch (_) {/* the tiles still work */}
  }

  Future<void> _refresh() async {
    final s = SessionScope.read(context);
    try {
      await s.loadInit();
    } catch (e) {
      if (mounted) toast(context, errText(e), bad: true);
    }
    await _today();
  }

  Future<void> _tile(Kind k) async {
    final s = SessionScope.read(context);
    if (!s.canEdit(k.module)) {
      widget.onOpenList(k.key); // View only: the list
      return;
    }
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => EntryForm(kind: k)));
    if (saved == true) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    final kinds = kKinds.where((k) => s.canSee(k.module)).toList();
    final first = s.name.split(' ').first;
    return SafeArea(
      child: RefreshIndicator(
        color: C.green,
        onRefresh: _refresh,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 10, 16, 24), children: [
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Namaskar${first.isNotEmpty ? ', $first' : ''}', style: Theme.of(context).textTheme.headlineMedium),
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: s.sites.length > 1 ? () => pickSite(context) : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(s.siteName, style: const TextStyle(fontSize: 14.5, color: C.muted, fontWeight: FontWeight.w500)),
                      if (s.sites.length > 1) const Icon(Icons.expand_more_rounded, size: 20, color: C.muted),
                    ]),
                  ),
                ),
              ]),
            ),
            IconButton(tooltip: 'Refresh', onPressed: _refresh, icon: const Icon(Icons.refresh_rounded)),
          ]),
          if (widget.update != null) _UpdateStrip(update: widget.update!),
          const SizedBox(height: 12),
          _StockCard(s: s, todayIssued: todayIssued, todayEntries: todayEntries),
          const SizedBox(height: 14),
          if (kinds.isEmpty) const InfoLine('Diesel pages are not given to you on this site – ask the Admin.', bad: true),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.25,
            children: [for (final k in kinds) _Tile(k: k, view: !s.canEdit(k.module), onTap: () => _tile(k))],
          ),
        ]),
      ),
    );
  }
}

class _StockCard extends StatelessWidget {
  const _StockCard({required this.s, this.todayIssued, this.todayEntries = 0});
  final Session s;
  final num? todayIssued;
  final int todayEntries;
  @override
  Widget build(BuildContext context) {
    final locs = s.stockByLoc.entries.where((e) => e.value != 0 || s.stockByLoc.length <= 3).toList();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: C.greenSoft, borderRadius: BorderRadius.circular(28)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 58, height: 58, decoration: const BoxDecoration(color: C.green, shape: BoxShape.circle), child: const Icon(Icons.local_gas_station_rounded, color: Colors.white, size: 30)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.stockTotal == null ? '–' : '${fmtNum(s.stockTotal)} L', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700, height: 1.1)),
              const Text('diesel in stock now · आत्ताचा साठा', style: TextStyle(fontSize: 13.5, color: Color(0xFF3E5A42))),
            ]),
          ),
        ]),
        if (locs.length > 1) ...[
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final e in locs)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: .7), borderRadius: BorderRadius.circular(14)),
                child: Text('${e.key}  ${fmtNum(e.value)} L', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ),
          ]),
        ],
        if (todayIssued != null) ...[
          const SizedBox(height: 12),
          Text('Issued today ${fmtNum(todayIssued)} L · $todayEntries ${todayEntries == 1 ? 'entry' : 'entries'}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: C.greenDark)),
        ],
      ]),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.k, required this.onTap, this.view = false});
  final Kind k;
  final VoidCallback onTap;
  final bool view;
  @override
  Widget build(BuildContext context) => Material(
        color: k.color,
        borderRadius: BorderRadius.circular(28),
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Row(children: [Icon(k.icon, color: Colors.white, size: 34), const Spacer(), if (view) const Icon(Icons.visibility_outlined, color: Colors.white70, size: 18)]),
              TwoLang(k.en, k.mr, color: Colors.white),
            ]),
          ),
        ),
      );
}

class _UpdateStrip extends StatelessWidget {
  const _UpdateStrip({required this.update});
  final AppUpdate update;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Material(
          color: C.amberSoft,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => runUpdate(context, update),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                const Icon(Icons.system_update_rounded, color: C.amber),
                const SizedBox(width: 12),
                Expanded(child: Text('New version ${update.version} – tap to update · नवीन version', style: const TextStyle(fontWeight: FontWeight.w600, color: C.amber))),
                const Icon(Icons.chevron_right, color: C.amber),
              ]),
            ),
          ),
        ),
      );
}
