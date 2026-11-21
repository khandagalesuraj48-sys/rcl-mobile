/* THE DIAL OF HOME, as he approved it on 20-11-2026 ("ok he design approved aahe"): his shift as a ring from its start to its end –
 *   – a small line for every HALF HOUR of the shift, the time written at every hour ("te circle round madhe je lines aahet tithe
 *     time asawet"); the first and the last are the shift's start and end;
 *   – gold from the start up to "now", a knob where "now" stands;
 *   – the disc in its middle marks: a LIVE digital clock of the server's time ("ek live watch asel digital je server la connect
 *     asel"), SIGN IN / SIGN OUT, "Tap to mark".
 * Only a drawing – nothing is counted here. Pearl by day, Midnight Gold by night (ui/hr_skin.dart). */
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'hr_skin.dart';

const _gold = Color(0xFFDDAD40);

class HomeDial extends StatelessWidget {
  const HomeDial({super.key, required this.size, required this.now, required this.start, required this.end, required this.clock, required this.big, required this.under, this.dim = false, this.tone});

  /// the side of the square it is drawn in (the hours stand round the ring)
  final double size;

  /// where "now" stands between the shift's start and its end, 0 to 1 (null: his shift is not known – no gold, no knob)
  final double? now;

  /// the shift's start and end, minutes of the day (null: not known – plain lines, no hours)
  final int? start, end;

  /// the live clock on the disc: the time NOW in milliseconds (the server's clock, kept going by the phone) – null: no clock
  final int Function()? clock;

  /// the big word of the disc and the small one under it
  final String big, under;

  /// it cannot be marked / today is done: no gold on the ring
  final bool dim;

  /// (3.158.0, asked 21-11-2026: "sign in kel ke red yeil sign out sathi ani sign in kraych asel tr green") what a touch of the disc
  /// does: 'in' – he signs in: a GREEN disc; 'out' – he signs out: a RED disc; null – nothing to mark: the plain disc
  final String? tone;

  @override
  Widget build(BuildContext context) {
    final s = sk, k = size / 310, disc = 136 * k;
    final List<Color>? fill = tone == 'in' ? const [Color(0xFF45DE8F), Color(0xFF1FB36B), Color(0xFF128A4E)] : tone == 'out' ? const [Color(0xFFFF7A6E), Color(0xFFE5392F), Color(0xFFB9221C)] : null;
    final on = fill != null; // a coloured disc: its words are white
    return SizedBox(
      width: size,
      height: size * .89,
      child: Stack(alignment: Alignment.topCenter, children: [
        Positioned(top: 0, left: 0, child: SizedBox(width: size, height: size, child: CustomPaint(painter: _HomeDialPaint(now: dim ? null : now, start: start, end: end, k: k, track: s.dark ? const Color(0xFF222A45) : const Color(0xFFEDF0F7), tick: s.dark ? const Color(0xFF3A4468) : const Color(0xFFC9D0E0), ink: s.ink, passed: s.link, faint: s.faint, knob: s.card)))),
        Positioned(
          top: size / 2 - disc / 2,
          child: Container(
            width: disc,
            height: disc,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(center: const Alignment(-.3, -.45), radius: .95, colors: fill ?? (s.dark ? const [Color(0xFF2C3A75), Color(0xFF1A2350), Color(0xFF101737)] : const [Colors.white, Color(0xFFEEF0FB), Color(0xFFD6DAF3)]), stops: const <double>[0, .5, 1]),
              border: on ? Border.all(color: Colors.white.withValues(alpha: .55), width: 2 * k) : s.dark ? Border.all(color: _gold.withValues(alpha: .6), width: 1.5) : null,
              boxShadow: [BoxShadow(color: on ? fill[1].withValues(alpha: .42) : s.dark ? const Color(0x8C000000) : const Color(0x2E3C468C), blurRadius: 30 * k, offset: Offset(0, 16 * k))],
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: disc * .09),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                if (clock != null)
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(width: 6, height: 6, decoration: BoxDecoration(color: on ? Colors.white : const Color(0xFF2FD07F), shape: BoxShape.circle, boxShadow: [BoxShadow(color: (on ? Colors.white : const Color(0xFF2FD07F)).withValues(alpha: .3), spreadRadius: 3)])),
                      const SizedBox(width: 6),
                      _Clock(ms: clock!, style: TextStyle(fontFamily: 'Montserrat', fontSize: 15 * k, fontWeight: FontWeight.w800, letterSpacing: .5, color: on ? Colors.white : s.link, height: 1.1, fontFeatures: const [FontFeature.tabularFigures()])),
                    ]),
                  ),
                SizedBox(height: 4 * k),
                FittedBox(fit: BoxFit.scaleDown, child: Text(big, maxLines: 1, style: TextStyle(fontFamily: 'Montserrat', fontSize: 19 * k, fontWeight: FontWeight.w800, letterSpacing: .3, color: on ? Colors.white : dim ? s.faint : s.ink, height: 1.15))),
                if (under.isNotEmpty) ...[
                  SizedBox(height: 3 * k),
                  FittedBox(fit: BoxFit.scaleDown, child: Text(under, maxLines: 1, style: TextStyle(fontSize: 10.5 * k, fontWeight: FontWeight.w600, color: on ? Colors.white.withValues(alpha: .92) : s.muted, height: 1.2))),
                ],
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

/// The live clock: India's time of [ms], said again every second.
class _Clock extends StatefulWidget {
  const _Clock({required this.ms, required this.style});
  final int Function() ms;
  final TextStyle style;
  @override
  State<_Clock> createState() => _ClockState();
}

class _ClockState extends State<_Clock> {
  Timer? tick;
  @override
  void initState() {
    super.initState();
    tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = DateTime.fromMillisecondsSinceEpoch(widget.ms() + 19800000, isUtc: true);
    String two(int v) => v.toString().padLeft(2, '0');
    return Text('${two(t.hour)}:${two(t.minute)}:${two(t.second)}', key: const Key('hh-clock'), maxLines: 1, style: widget.style);
  }
}

class _HomeDialPaint extends CustomPainter {
  _HomeDialPaint({required this.now, required this.start, required this.end, required this.k, required this.track, required this.tick, required this.ink, required this.passed, required this.faint, required this.knob});
  final double? now;
  final int? start, end;
  final double k;
  final Color track, tick, ink, passed, faint, knob;

  @override
  void paint(Canvas c, Size s) {
    final mid = s.center(Offset.zero), r = s.width / 2;
    const a0 = math.pi * .75, sweep = math.pi * 1.5;
    final a = start, b0 = end;
    // the shift in half hours (a night shift ends on the next day); not known: twenty plain lines
    final mins = a == null || b0 == null ? 0 : (b0 > a ? b0 - a : b0 + 1440 - a);
    final int n = mins <= 0 ? 20 : (mins / 30).round().clamp(2, 48).toInt();
    final every = n <= 24 ? 2 : 4; // the time at every hour; a very long shift: at every second hour
    final double f = (now ?? -1).clamp(-1.0, 1.0).toDouble();
    for (var i = 0; i <= n; i++) {
      final t = i / n, ang = a0 + sweep * t, d = Offset(math.cos(ang), math.sin(ang)), big = i % every == 0 || i == n, on = f >= 0 && t <= f + 1e-9;
      c.drawLine(
          mid + d * (r - 57 * k),
          mid + d * (r - (big ? 47 : 51) * k),
          Paint()
            ..color = on ? _gold : tick
            ..strokeWidth = (big ? 2.2 : 1.4) * k
            ..strokeCap = StrokeCap.round);
      if (!big || mins <= 0 || a == null) continue;
      // (the last hour before the end is left out when it would stand on the end's own time)
      if (i != n && n - i < every) continue;
      final m = (a + (i == n ? mins : i * 30)) % 1440, edge = i == 0 || i == n;
      final tp = TextPainter(
          text: TextSpan(text: '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}', style: TextStyle(fontFamily: 'Rubik', fontSize: (edge ? 11.5 : 9.5) * k, fontWeight: edge ? FontWeight.w700 : FontWeight.w600, color: edge ? ink : on ? passed : faint)),
          textDirection: TextDirection.ltr)
        ..layout();
      final p = mid + d * (r - 30 * k);
      tp.paint(c, Offset(p.dx - tp.width / 2, p.dy - tp.height / 2));
    }
    final rr = r - 69 * k, ring = Rect.fromCircle(center: mid, radius: rr);
    Paint line(Color col) => Paint()
      ..color = col
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10 * k
      ..strokeCap = StrokeCap.round;
    c.drawArc(ring, a0, sweep, false, line(track));
    if (f < 0) return;
    if (f > 0) c.drawArc(ring, a0, sweep * f, false, line(_gold));
    final at = mid + Offset(math.cos(a0 + sweep * f), math.sin(a0 + sweep * f)) * rr;
    c.drawCircle(at, 8.5 * k, Paint()..color = _gold);
    c.drawCircle(at, 5 * k, Paint()..color = knob);
  }

  @override
  bool shouldRepaint(covariant _HomeDialPaint o) => o.now != now || o.start != start || o.end != end || o.k != k || o.track != track || o.tick != tick || o.ink != ink || o.knob != knob;
}
