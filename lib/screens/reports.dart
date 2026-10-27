/* REPORTS – the reports of the web he may open, by his access. (3.2.0) Each opens in the app's own screen (report_screen.dart):
 * the same filters and the same server report as the web; Excel and Print (PDF) made on the phone.
 * (3.31.0, asked 20-10-2026 with his picture) "This Month" / "Last Month"; the tabs Overview · Diesel · Machinery · Financial.
 * Overview (with Dashboard access) – the figures of the month from the server's own answers, nothing worked out anew:
 *   Diesel Consumed = issued to machinery (getDashboard total.qty), Diesel Cost = the inward bills (getDashboard inward.amount),
 *   Machinery Running = machinery that worked (logDashboard kpi.worked), Breakdowns = breakdowns that began (getBreakdowns);
 *   each against the same number of days just before (↑ / ↓ %); the diesel issued month by month (the last 7 months); the quick
 *   reports. The other tabs: his reports, one under the other. */
import 'dart:math' as math;

import 'package:flutter/material.dart' hide Text;

import '../core/dash.dart';
import '../core/format.dart';
import '../core/session.dart';
import '../ui/ask_bot.dart';
import '../ui/scope.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'billing.dart';
import 'dashboard.dart';
import 'home.dart';
import 'report_screen.dart';
import '../ui/t.dart';

const _diesel = {'dash', 'rdaily', 'rmonthly', 'ravg', 'rp-average', 'rp-ledger', 'rp-stock', 'rp-purchase', 'rp-watch', 'rp-tank', 'rp-compare'};
const _machinery = {'rp-mcost', 'rp-owner', 'rp-type'};

/// Opens one report of the list (its own screen).
void openReportOf(BuildContext context, String page) {
  final def = reportOfPage(page);
  const bill = {'breg': 'Bill Summary', 'vled': 'Vendor Ledger', 'vout': 'Vendor Outstanding'};
  if (page == 'dash') {
    openDashboard(context); // (3.5.0) the app's own Dashboard
  } else if (bill[page] != null) {
    openBillPage(context, bill[page]!); // (3.8.0) the app's own billing screens
  } else if (def != null) {
    openReport(context, def); // (3.18.0) every report is the app's own screen – no web page
  }
}

class ReportsTab extends StatefulWidget {
  const ReportsTab({super.key, this.active = true});

  /// (3.31.0) the tab is on the screen – the Overview's figures are read only then (not at every start of the app)
  final bool active;
  @override
  State<ReportsTab> createState() => _ReportsTabState();
}

class _Fig {
  _Fig(this.now, this.before, this.line);
  final num now;
  final num? before;
  final List<num> line;
}

class _ReportsTabState extends State<ReportsTab> {
  String tab = '';
  String range = 'month';
  bool loading = false;
  String err = '', loadedFor = '';
  _Fig? used, cost, running, breaks;
  List<(String, num)> months = [];
  int seq = 0;

  /// (3.44.0, update-163) the fuel of the Overview's diesel figures: '' on a site of one fuel (as before); else Diesel (or the first)
  String _fuel(Session s) => !s.multiFuel ? '' : s.siteFuels.contains('Diesel') ? 'Diesel' : s.siteFuels.first;

  /// The same number of days just before [from]..[to].
  (String, String) _before(String from, String to) {
    final a = parseKey(from), b = parseKey(to), days = b.difference(a).inDays + 1;
    return (dateKey(a.subtract(Duration(days: days))), dateKey(a.subtract(const Duration(days: 1))));
  }

  Future<void> _load() async {
    final s = SessionScope.read(context), my = ++seq;
    final today = s.today.isNotEmpty ? s.today : dateKey(DateTime.now());
    final (from, to) = dashRange(range, today);
    final (pf, pt) = _before(from, to);
    final t = parseKey(today);
    final m0 = DateTime(t.year, t.month - 6, 1);
    setState(() {
      loading = true;
      err = '';
      loadedFor = '$range|$today|${s.site?.code}';
    });
    Future<Map<String, dynamic>> ask(String fn, Map<String, dynamic> x) async => ((await s.api.call(fn, [x])) as Map).cast<String, dynamic>();
    // (3.44.0, update-163) a site with more than one fuel: the figures of ONE fuel (never added together)
    final fv = _fuel(s).isEmpty ? const <String, dynamic>{} : {'fuel': _fuel(s)};
    try {
      final r = await Future.wait([
        ask('getDashboard', {'from': from, 'to': to, ...fv}),
        ask('getDashboard', {'from': pf, 'to': pt, ...fv}),
        ask('getDashboard', {'from': dateKey(m0), 'to': today, ...fv}).catchError((_) => <String, dynamic>{}),
        if (s.canSee('Log Book') || s.canSee('Dashboard')) ask('logDashboard', {'from': from, 'to': to, 'vendor': '', 'ownerships': <String>[]}).catchError((_) => <String, dynamic>{}),
      ]);
      Map<String, dynamic>? bd;
      if (s.canSee('Breakdown')) {
        try {
          bd = await ask('getBreakdowns', {'date': to});
        } catch (_) {/* the card only */}
      }
      if (!mounted || my != seq) return;
      final d = r[0], p = r[1], trend = r[2];
      final ld = r.length > 3 ? r[3] : const <String, dynamic>{};
      num n(Map? m, String k) => asNum(m?[k]) ?? 0;
      final daily = mapsOf(d['daily']);
      final hist = mapsOf(bd?['history']);
      int began(String a, String b) => hist.where((x) => '${x['from']}'.compareTo(a) >= 0 && '${x['from']}'.compareTo(b) <= 0).length;
      final byMonth = <String, num>{};
      for (var i = 0; i < 7; i++) {
        final m = DateTime(m0.year, m0.month + i, 1);
        byMonth['${m.year}-${'${m.month}'.padLeft(2, '0')}'] = 0;
      }
      for (final x in mapsOf(trend['daily'])) {
        final k = '${x['date']}'.length >= 7 ? '${x['date']}'.substring(0, 7) : '';
        if (byMonth.containsKey(k)) byMonth[k] = byMonth[k]! + (asNum(x['qty']) ?? 0);
      }
      const names = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      setState(() {
        used = _Fig(n(d['total'] as Map?, 'qty'), n(p['total'] as Map?, 'qty'), [for (final x in daily) asNum(x['qty']) ?? 0]);
        cost = _Fig(n(d['inward'] as Map?, 'amount'), n(p['inward'] as Map?, 'amount'), [for (final x in daily) asNum(x['inQty']) ?? 0]);
        final k = ld['kpi'] as Map?, kp = ld['prev'] as Map?;
        running = k == null ? null : _Fig(n(k, 'worked'), kp == null ? null : n(kp, 'worked'), [for (final x in mapsOf(ld['daily'])) asNum(x['machines']) ?? 0]);
        breaks = bd == null ? null : _Fig(began(from, to), began(pf, pt), const []);
        months = [for (final e in byMonth.entries) (names[int.parse(e.key.substring(5)) - 1], e.value)];
        loading = false;
      });
    } catch (e) {
      if (!mounted || my != seq) return;
      setState(() {
        loading = false;
        err = errText(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    final list = reportsOf(s);
    final over = s.canSee('Dashboard');
    final groups = <String, List<(String, String, String, String)>>{
      'Diesel': [for (final r in list) if (_diesel.contains(r.$3)) r],
      'Machinery': [for (final r in list) if (_machinery.contains(r.$3)) r],
      'Financial': [for (final r in list) if (!_diesel.contains(r.$3) && !_machinery.contains(r.$3)) r],
    }..removeWhere((_, v) => v.isEmpty);
    final tabs = [if (over) 'Overview', ...groups.keys];
    final cur = tabs.contains(tab) ? tab : (tabs.isEmpty ? '' : tabs.first);
    if (widget.active && cur == 'Overview' && !loading && loadedFor != '$range|${s.today}|${s.site?.code}') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load();
      });
    }
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: C.green,
          onRefresh: () async {
            if (cur == 'Overview') await _load();
          },
          child: ListView(padding: const EdgeInsets.fromLTRB(Sp.edge, 8, Sp.edge, 30), children: [
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Reports', mr: 'रिपोर्ट्स', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                  Text(s.siteName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, color: C.muted, fontWeight: FontWeight.w500)),
                ]),
              ),
              if (cur == 'Overview')
                PopupMenuButton<String>(
                  key: const Key('rep-range'),
                  tooltip: tr('Month'),
                  onSelected: (v) {
                    setState(() => range = v);
                    _load();
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'month', child: Text('This Month')),
                    PopupMenuItem(value: 'lastmonth', child: Text('Last Month')),
                  ],
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: C.line)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.calendar_month_outlined, size: 17, color: C.greenDark),
                      const SizedBox(width: 6),
                      Text(range == 'month' ? 'This Month' : 'Last Month', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                    ]),
                  ),
                ),
              const SizedBox(width: 6),
              const AskBot(size: 40),
            ]),
            const SizedBox(height: 14),
            if (tabs.isEmpty) const EmptyState('No reports for you yet', 'Ask the Admin for access to Reports or Dashboard.', pic: 'bar_chart'),
            if (tabs.length > 1)
              Row(children: [
                // every tab on the screen at once – none cut at the right (a long Marathi word grows smaller, not cut)
                for (final (i, x) in tabs.indexed) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(
                    child: Material(
                      color: x == cur ? C.green : Colors.white,
                      shape: StadiumBorder(side: BorderSide(color: x == cur ? C.green : C.line)),
                      child: InkWell(
                        key: Key('rt-${x.toLowerCase()}'),
                        customBorder: const StadiumBorder(),
                        onTap: () => setState(() => tab = x),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                          child: Center(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(x, maxLines: 1, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: x == cur ? Colors.white : C.ink)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ]),
            if (tabs.length > 1) const SizedBox(height: 14),
            if (cur == 'Overview') ..._overview(s, list) else ...[
              for (final r in groups[cur] ?? const <(String, String, String, String)>[])
                Padding(
                  padding: const EdgeInsets.only(bottom: Sp.chips),
                  child: Press(
                    onTap: () => openReportOf(context, r.$3),
                    radius: 18,
                    padding: const EdgeInsets.all(12),
                    child: Row(children: [
                      Container(width: 52, height: 52, decoration: BoxDecoration(color: C.blueSoft, borderRadius: BorderRadius.circular(15)), alignment: Alignment.center, child: Pic(r.$4, size: 34)),
                      const SizedBox(width: 14),
                      Expanded(child: TwoLang(r.$1, r.$2, size: 16, weight: FontWeight.w700)),
                      const Icon(Icons.chevron_right_rounded, color: C.faint),
                    ]),
                  ),
                ),
              if (list.isNotEmpty) const Padding(padding: EdgeInsets.fromLTRB(4, 6, 4, 0), child: Text('Excel and Print in a report open on the phone – share, keep or print (PDF).', style: TextStyle(fontSize: 13, color: C.muted))),
            ],
          ]),
        ),
      ),
    );
  }

  List<Widget> _overview(Session s, List<(String, String, String, String)> list) {
    final has = {for (final r in list) r.$3};
    Widget fig(String key, String pic, Color soft, String label, String value, _Fig? f, {bool lessIsGood = false}) {
      final b = f?.before;
      final pct = (f != null && b != null && b > 0) ? (f.now - b) / b * 100 : null;
      final up = (pct ?? 0) >= 0;
      final good = lessIsGood ? !up : up;
      final tone = pct == null ? C.muted : (good ? const Color(0xFF249556) : C.red);
      return Container(
        key: Key(key),
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: C.line)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 32, height: 32, decoration: BoxDecoration(color: soft, borderRadius: BorderRadius.circular(10)), alignment: Alignment.center, child: Pic(pic, size: 21)),
          const SizedBox(width: 7),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(label, maxLines: 1, style: const TextStyle(fontSize: 11, color: C.muted))),
              FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(f == null ? (loading ? '…' : '–') : value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
              Row(children: [
                if (pct != null) ...[
                  Icon(up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, size: 13, color: tone),
                  Text('${fmtNum((pct.abs()).round())}%', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: tone)),
                ],
                const Spacer(),
                if ((f?.line.length ?? 0) > 1) SizedBox(width: 46, height: 16, child: CustomPaint(painter: _Spark(f!.line, tone))),
              ]),
            ]),
          ),
        ]),
      );
    }

    final hi = months.isEmpty ? -1 : months.indexWhere((m) => m.$2 == months.map((x) => x.$2).reduce(math.max));
    final quick = [
      if (has.contains('rp-stock')) ('rp-stock', 'Diesel Stock', 'fuel_pump', C.redSoft),
      if (has.contains('ravg')) ('ravg', 'Monthly Avg', 'bar_chart', C.blueSoft),
      if (has.contains('rp-mcost')) ('rp-mcost', 'Machinery Cost', 'tractor', C.greenSoft),
      if (s.canSee('Dashboard')) ('_log', 'Log Book', 'notebook', C.purpleSoft),
    ];
    return [
      if (err.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(tr(err), style: const TextStyle(color: C.red))),
      FuelScope(fuel: _fuel(s), child: Row(children: [
        Expanded(child: fig('ov-used', 'fuel_pump', C.redSoft, 'Diesel Consumed', '${fmtNum(used?.now)} L', used)),
        const SizedBox(width: Sp.chips),
        Expanded(child: fig('ov-cost', 'receipt', C.amberSoft, 'Diesel Cost', '₹${fmtNum(cost?.now)}', cost)),
      ])),
      const SizedBox(height: Sp.chips),
      Row(children: [
        Expanded(child: fig('ov-run', 'tractor', C.blueSoft, 'Machinery Running', fmtNum(running?.now), running)),
        if (s.canSee('Breakdown')) ...[
          const SizedBox(width: Sp.chips),
          Expanded(child: fig('ov-bd', 'wrench', C.redSoft, 'Breakdowns', fmtNum(breaks?.now), breaks, lessIsGood: true)),
        ],
      ]),
      const SizedBox(height: Sp.block),
      Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: C.line)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: FuelScope(fuel: _fuel(s), child: const Text('Diesel Consumption Trend', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)))),
            TextButton(
              key: const Key('ov-details'),
              onPressed: () => openDashboard(context),
              style: TextButton.styleFrom(foregroundColor: C.goldInk, padding: const EdgeInsets.symmetric(horizontal: 4), minimumSize: const Size(0, 32)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [Text('View Details', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: C.goldInk)), const Icon(Icons.arrow_forward_rounded, size: 16)]),
            ),
          ]),
          const SizedBox(height: 6),
          SizedBox(height: 150, child: months.isEmpty ? Center(child: loading ? const CircularProgressIndicator(strokeWidth: 2.5) : const Text('–')) : CustomPaint(key: const Key('ov-trend'), painter: _Bars(months, hi))),
        ]),
      ),
      if (quick.isNotEmpty) ...[
        const SizedBox(height: Sp.block),
        Row(children: [
          const Expanded(child: Text('Quick Reports', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
          TextButton(
            onPressed: () => setState(() => tab = 'Diesel'),
            style: TextButton.styleFrom(foregroundColor: C.goldInk, padding: const EdgeInsets.symmetric(horizontal: 4), minimumSize: const Size(0, 32)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [Text('View All', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: C.goldInk)), const Icon(Icons.arrow_forward_rounded, size: 16)]),
          ),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          for (final (i, q) in quick.indexed) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: Press(
                key: Key('quick-${q.$1}'),
                onTap: () {
                  if (q.$1 == '_log') {
                    openDashboard(context, tab: 1);
                  } else {
                    openReportOf(context, q.$1);
                  }
                },
                color: q.$4,
                border: q.$4,
                shadow: false,
                radius: 16,
                padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
                child: Column(children: [
                  Pic(q.$3, size: 30),
                  const SizedBox(height: 4),
                  SizedBox(height: 15, child: FittedBox(fit: BoxFit.scaleDown, child: Text(q.$2, maxLines: 1, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)))),
                ]),
              ),
            ),
          ],
        ]),
      ],
    ];
  }
}

/// A small line of the days (the figure's shape).
class _Spark extends CustomPainter {
  _Spark(this.v, this.c);
  final List<num> v;
  final Color c;
  @override
  void paint(Canvas canvas, Size size) {
    final hi = v.reduce(math.max).toDouble(), lo = v.reduce(math.min).toDouble(), span = hi - lo == 0 ? 1.0 : hi - lo;
    final path = Path();
    for (var i = 0; i < v.length; i++) {
      final x = size.width * i / (v.length - 1), y = size.height - (v[i] - lo) / span * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeJoin = StrokeJoin.round);
  }

  @override
  bool shouldRepaint(_Spark o) => o.v != v || o.c != c;
}

/// The diesel issued month by month: the lines of litres, a bar for each month, the highest with its litres.
class _Bars extends CustomPainter {
  _Bars(this.m, this.hi);
  final List<(String, num)> m;
  final int hi;
  @override
  void paint(Canvas canvas, Size size) {
    final top = m.map((x) => x.$2).fold<num>(0, math.max).toDouble();
    final step = _nice(top <= 0 ? 1.0 : top / 3);
    final maxV = step * 3;
    const left = 38.0, bottom = 18.0, topPad = 22.0;
    final h = size.height - bottom - topPad, w = size.width - left;
    TextPainter tp(String t, double fs, Color c, {FontWeight fw = FontWeight.w400}) =>
        TextPainter(text: TextSpan(text: t, style: TextStyle(fontFamily: 'Rubik', fontSize: fs, color: c, fontWeight: fw)), textDirection: TextDirection.ltr)..layout();
    final grid = Paint()
      ..color = C.line
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = topPad + h - h * i / 3;
      canvas.drawLine(Offset(left, y), Offset(size.width, y), grid);
      final t = tp(fmtNum(step * i), 9.5, C.muted);
      t.paint(canvas, Offset(left - 6 - t.width, y - t.height / 2));
    }
    final slot = w / m.length, bw = math.min(26.0, slot * .55);
    for (var i = 0; i < m.length; i++) {
      final v = m[i].$2.toDouble(), bh = maxV <= 0 ? 0.0 : h * v / maxV;
      final x = left + slot * i + (slot - bw) / 2, y = topPad + h - bh;
      final r = RRect.fromRectAndCorners(Rect.fromLTWH(x, y, bw, bh), topLeft: const Radius.circular(6), topRight: const Radius.circular(6));
      canvas.drawRRect(r, Paint()..color = i == hi ? C.green : const Color(0xFF61B689));
      final l = tp(m[i].$1, 9.5, C.muted);
      l.paint(canvas, Offset(left + slot * i + (slot - l.width) / 2, size.height - bottom + 4));
      if (i == hi && v > 0) {
        final t = tp('${fmtNum(v.round())} L', 9.5, Colors.white, fw: FontWeight.w700);
        final bx = Rect.fromCenter(center: Offset(x + bw / 2, y - 11), width: t.width + 10, height: t.height + 4);
        canvas.drawRRect(RRect.fromRectAndRadius(bx, const Radius.circular(6)), Paint()..color = C.greenDark);
        t.paint(canvas, Offset(bx.left + 5, bx.top + 2));
      }
    }
  }

  static double _nice(double v) {
    final p = math.pow(10, (math.log(v) / math.ln10).floor()).toDouble();
    for (final f in const [1.0, 2.0, 2.5, 5.0, 10.0]) {
      if (v <= f * p) return f * p;
    }
    return 10 * p;
  }

  @override
  bool shouldRepaint(_Bars o) => o.m != m || o.hi != hi;
}
