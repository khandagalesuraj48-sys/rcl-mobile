/* THE MESS ON HOME (23-11-2026, his decision: "falcon … hr madhe jodaych … erp sathi pn jas apan attendance sathi keley te ethe pn ek
 * asel"; pictures approved: "ho banaw"):
 *   [MessCard]  – N6: the HR Home's card under Leave · Regularization · Documents · Salary slip (the attendance app – and an ERP
 *                 person's attendance pages, which are the same).
 *   [MessStrip] – N7: the ERP Home's strip under the site and Mark IN – as attendance has its tile there.
 * Both: the nearest mess of his site, how far / "you are at the mess", the meal on now, today's dishes. A tap opens FALCON signed in
 * through HR (core/falcon_link.dart). Shown only to a person who has HR on his site and only when FALCON answers with a mess –
 * otherwise nothing at all (no empty box). */
import 'dart:async';

import 'package:flutter/material.dart' hide Text;
import 'package:flutter/material.dart' as m show Text;

import '../core/attend.dart';
import '../core/falcon_link.dart';
import '../screens/attendance.dart' show hrModule, hrSite;
import '../screens/falcon_inside.dart';
import '../screens/hr_shell.dart' show hrAsk;
import 'hr_skin.dart';
import 'scope.dart';
import 't.dart';
import 'theme.dart';
import 'widgets.dart';

const _saffron = Color(0xFFC2560E), _saffronSoft = Color(0xFFFFF4E6), _saffronLine = Color(0xFFE8B98A);

mixin _MessData<T extends StatefulWidget> on State<T> {
  Map<String, dynamic>? card;
  String who = '', why = '';
  bool opening = false;
  /// (3.170.0) HR is being asked for the card – the Super Admin sees "asking HR …" meanwhile
  bool asking = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final s = SessionScope.of(context), w = hrModule(s) == null ? '' : '${s.email}|${hrSite(s)?.code ?? ''}';
    if (w == who) return;
    who = w;
    card = null;
    if (w.isNotEmpty) unawaited(load());
  }

  Future<void> load({bool fresh = false}) async {
    final s = SessionScope.read(context);
    if (mounted) setState(() => asking = true);
    final c = await FalconMess.card(s, (b) => hrAsk(s, b), fresh: fresh);
    // (3.171.0 patch 2) the Mess is there: FALCON is made ready behind the app, so it opens at once (no screen of its own)
    if (c != null) unawaited(warmFalconInside(s.email, () async => (await FalconMess.pass((b) => hrAsk(s, b)))?.pass));
    if (mounted) {
      setState(() {
        asking = false;
        card = c;
        why = c == null ? FalconMess.why : '';
      });
    }
  }

  /// (3.169.0) no card: the Super Admin is told why (FALCON not connected / no mess at the site) – nobody else sees anything.
  /// (3.170.0, asked 23-11-2026: "kahich disat nahi yellow pn nahi" → "ho kr") while HR is asked he sees "asking HR …" at once, and an
  /// answer without words is said too – never an empty space for him.
  Widget nothing(BuildContext context, String key) {
    if (!SessionScope.of(context).superAdmin) return const SizedBox.shrink();
    final said = asking ? 'asking HR …' : why.isNotEmpty ? why : 'HR gave no card and said nothing – tap to ask again.';
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: GestureDetector(
        key: Key(key),
        behavior: HitTestBehavior.opaque,
        onTap: asking ? null : () => load(fresh: true),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(color: _saffronSoft, borderRadius: BorderRadius.circular(14), border: Border.all(color: _saffronLine)),
          child: Row(children: [
            const Icon(Icons.restaurant_rounded, size: 18, color: _saffron),
            const SizedBox(width: 10),
            Expanded(child: m.Text('Mess (FALCON) – Super Admin: $said', style: const TextStyle(fontSize: 12.5, color: C.ink))),
            asking
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: _saffron))
                : const Icon(Icons.refresh_rounded, size: 18, color: _saffron),
          ]),
        ),
      ),
    );
  }

  MessNow? get now {
    final f = AttendWhere.i.fresh(5 * 60 * 1000);
    return messNow(card, lat: f?.lat, lng: f?.lng, acc: f?.acc ?? 0);
  }

  Future<void> openFalcon() async {
    if (opening) return;
    setState(() => opening = true);
    final s = SessionScope.read(context);
    // (3.171.0 patch 2, his choice of 25-11-2026) FALCON inside this app (made ready behind it: straight on its home); else its app; else its web
    final err = await FalconMess.open((b) => hrAsk(s, b), inside: (pass) => openFalconInside(context, pass), ready: () => falconReadyFor(s.email));
    if (!mounted) return;
    setState(() => opening = false);
    if (err.isNotEmpty) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: m.Text(err)));
  }

  String placeLine(MessNow x) => x.metres == null ? x.name : x.at ? '${x.name} · ${distText(x.metres!)} · ${tr('you are at the mess')}' : '${x.name} · ${far(x)}';

  /// (3.171.0 patch 3) how far – by road when FALCON has it, else the straight line said as one
  String far(MessNow x) {
    final s = SessionScope.read(context);
    final road = x.myLat == null || x.messLat == null ? null : falconRoadMetres(s.email, x.myLat!, x.myLng!, x.messLat!, x.messLng!);
    return messFar(x.metres!, road, Lang.i.code);
  }

  void _roadCame() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    falconRoads.addListener(_roadCame);
  }

  @override
  void dispose() {
    falconRoads.removeListener(_roadCame);
    super.dispose();
  }
  String mealLine(MessNow x) => x.meal.isEmpty ? tr('Closed for today') : x.now ? '${tr(mealWord(x.meal))} ${tr('now')} · ${tr('till')} ${x.to}' : '${tr(mealWord(x.meal))} · ${tr('from')} ${x.from}';
}

/// N6 – the HR Home's Mess card.
class MessCard extends StatefulWidget {
  const MessCard({super.key});
  @override
  State<MessCard> createState() => _MessCardState();
}

class _MessCardState extends State<MessCard> with _MessData<MessCard> {
  @override
  void initState() {
    super.initState();
    AttendWhere.i.addListener(_moved);
  }

  void _moved() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    AttendWhere.i.removeListener(_moved);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final x = who.isEmpty ? null : now;
    if (x == null) return who.isEmpty ? const SizedBox.shrink() : nothing(context, 'hh-mess-why');
    final s = sk;
    final (Color c, Color soft) = s.tint(_saffron, _saffronSoft);
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Semantics(
        button: true,
        label: 'Mess',
        child: GestureDetector(
          key: const Key('hh-mess'),
          behavior: HitTestBehavior.opaque,
          onTap: openFalcon,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            decoration: s.box(radius: 22).copyWith(border: Border.all(color: s.classic ? _saffronLine : c.withValues(alpha: .55), width: 2)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(width: 40, height: 40, alignment: Alignment.center, decoration: BoxDecoration(color: _saffron, borderRadius: BorderRadius.circular(13)),
                    child: opening ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.restaurant_rounded, color: Colors.white, size: 21)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Text('Mess', mr: 'मेस', style: TextStyle(fontFamily: 'Montserrat', fontSize: 16, fontWeight: FontWeight.w800, color: s.ink)),
                      const SizedBox(width: 6),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2), decoration: BoxDecoration(color: soft, borderRadius: BorderRadius.circular(8)),
                          child: m.Text('FALCON', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c))),
                    ]),
                    m.Text(placeLine(x), key: const Key('hh-mess-place'), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: s.muted)),
                  ]),
                ),
                Icon(Icons.chevron_right_rounded, color: s.muted),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: soft, borderRadius: BorderRadius.circular(14)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(x.meal == 'dinner' ? Icons.nightlight_round : Icons.wb_sunny_rounded, size: 14, color: c),
                    const SizedBox(width: 5),
                    m.Text(mealLine(x), key: const Key('hh-mess-meal'), style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: c)),
                  ]),
                ),
                const SizedBox(width: 10),
                Expanded(child: m.Text(x.dishes.join(', '), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: s.muted))),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

/// N7 – the ERP Home's Mess strip (under the site and Mark IN).
class MessStrip extends StatefulWidget {
  const MessStrip({super.key, this.pad = const EdgeInsets.fromLTRB(10, 10, 0, 0)});

  /// (3.174.0) its place: under the site on Vehicle's Home of before; the site home gives its own
  final EdgeInsets pad;
  @override
  State<MessStrip> createState() => _MessStripState();
}

class _MessStripState extends State<MessStrip> with _MessData<MessStrip> {
  bool _asked = false;

  @override
  Future<void> load({bool fresh = false}) async {
    await super.load(fresh: fresh);
    // his place for "how far": the attendance's own reading, read once here when there is none young enough
    if (!_asked && card != null && AttendWhere.i.fresh(5 * 60 * 1000) == null) {
      _asked = true;
      await AttendWhere.i.read();
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final x = who.isEmpty ? null : now;
    if (x == null) return who.isEmpty ? const SizedBox.shrink() : nothing(context, 'home-mess-why');
    final sub = [if (x.metres != null) x.at ? '${x.name} · ${distText(x.metres!)}' : '${x.name} · ${far(x)}' else x.name, if (x.now) '${tr('till')} ${x.to}'].join(' · ');
    final title = x.meal.isEmpty ? '${tr('Mess')} · ${tr('closed for today')}' : '${tr('Mess')} · ${tr(mealWord(x.meal).toLowerCase())} ${x.now ? tr('now') : '${tr('from')} ${x.from}'}';
    return Padding(
      padding: widget.pad,
      child: Press(
        key: const Key('home-mess'),
        onTap: openFalcon,
        radius: 18,
        padding: EdgeInsets.zero,
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
          decoration: BoxDecoration(color: _saffronSoft, borderRadius: BorderRadius.circular(18), border: Border.all(color: _saffronLine, width: 2)),
          child: Row(children: [
            Container(width: 38, height: 38, alignment: Alignment.center, decoration: BoxDecoration(color: _saffron, borderRadius: BorderRadius.circular(12)),
                child: opening ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.restaurant_rounded, color: Colors.white, size: 20)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                m.Text(title, key: const Key('home-mess-title'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: C.ink)),
                m.Text(sub, key: const Key('home-mess-sub'), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: C.muted)),
              ]),
            ),
            const SizedBox(width: 8),
            Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: _saffron, borderRadius: BorderRadius.circular(12)),
                child: const Text('Order', mr: 'मागवा', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white))),
          ]),
        ),
      ),
    );
  }
}

