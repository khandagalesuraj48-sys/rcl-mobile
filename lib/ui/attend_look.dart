/* THE LOOK OF ATTENDANCE (3.105.0 – his approval of 12-11-2026: "design approval aahe warche 4 ani 5 ani je hajeri lawale nantr
 * che je pan aahe te ok aahe"): the sky says where the day stands, so it is understood without reading.
 *   dawn – attendance not marked yet (the rising sun: IN)     day  – on duty (the sun is up: OUT)
 *   dusk – today's attendance is done (the moon)              grey – it cannot be marked here / now
 * Only the look: what may be marked, where and by whom is decided where it always was (core/attend.dart and the HR server). */
import 'dart:math' as math;

import 'package:flutter/material.dart';

enum Sky { dawn, day, dusk, grey }

const _skies = <Sky, List<Color>>{
  Sky.dawn: [Color(0xFF1B1F4B), Color(0xFF7A3B6E), Color(0xFFF29E4C)],
  Sky.day: [Color(0xFF0B5FA5), Color(0xFF3FA9E0), Color(0xFF8FD3F4)],
  Sky.dusk: [Color(0xFF0A0B22), Color(0xFF2B2456), Color(0xFF5A3A6E)],
  Sky.grey: [Color(0xFF3B4257), Color(0xFF6A7289), Color(0xFF8B93A8)],
};

/// The sky from the top down (a page's head) and from left to right (the strip on Home).
LinearGradient skyDown(Sky s) => LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: _skies[s]!, stops: const <double>[0, .6, 1]);
LinearGradient skyAcross(Sky s) => LinearGradient(colors: _skies[s]!, stops: const <double>[0, .55, 1]);

/// The colour of a button that belongs to this sky.
Color skyInk(Sky s) => _skies[s]![s == Sky.day ? 0 : 1];

/// What the day says from the server's "next" and today's punches.
Sky skyOf({required bool any, required String next, bool stopped = false}) => stopped ? Sky.grey : !any ? Sky.dawn : next == 'out' ? Sky.day : Sky.dusk;

/// The sun (IN / OUT on it), the moon when the day is done, a pale disc when nothing can be marked; [tick] = done just now.
class SunDisc extends StatelessWidget {
  const SunDisc({super.key, required this.size, this.label = '', this.moon = false, this.dim = false, this.tick = false});
  final double size;
  final String label;
  final bool moon, dim, tick;
  @override
  Widget build(BuildContext context) {
    final colors = dim
        ? const [Color(0xFFE3E5EC), Color(0xFFC5C9D6), Color(0xFFAFB4C4)]
        : moon
            ? const [Color(0xFFFFFFFF), Color(0xFFDDE3F6), Color(0xFFC9D2F0)]
            : const [Color(0xFFFFF3B0), Color(0xFFFFC93C), Color(0xFFFF9A3C)];
    final ink = dim ? const Color(0xFF4A5068) : moon ? const Color(0xFF1A1C3A) : const Color(0xFF3A2000);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(center: const Alignment(-.3, -.4), radius: .9, colors: colors, stops: const <double>[0, .6, 1]),
        boxShadow: dim ? null : [BoxShadow(color: colors[1].withValues(alpha: .45), blurRadius: size * .3, spreadRadius: size * .05)],
      ),
      child: tick
          ? Icon(Icons.check_rounded, size: size * .62, color: ink)
          : label.isEmpty
              ? null
              : Text(label, maxLines: 1, style: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.w800, fontSize: size * .26, color: ink, height: 1)),
    );
  }
}

/// Where he stands against his work place – a drawing, not a map: the place as a ring, he as a dot (inside it, or outside with
/// the metres that are missing).
class PlaceRadar extends StatelessWidget {
  const PlaceRadar({super.key, required this.inside, required this.distance, required this.name});
  final bool inside;
  final int distance;
  final String name;
  @override
  Widget build(BuildContext context) => Container(
        height: 108,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: inside ? const Color(0xFFDCEBDD) : const Color(0xFFE6E8EE), borderRadius: BorderRadius.circular(18)),
        child: CustomPaint(
          painter: _Radar(inside, distance),
          child: Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 9, 12, 0),
              child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF27412F))),
            ),
          ),
        ),
      );
}

class _Radar extends CustomPainter {
  _Radar(this.inside, this.distance);
  final bool inside;
  final int distance;
  @override
  void paint(Canvas c, Size s) {
    final mid = Offset(s.width * .62, s.height * .54), r = s.height * .36;
    c.drawCircle(mid, r, Paint()..color = const Color(0xFF35C98A).withValues(alpha: .22));
    final edge = Paint()
      ..color = const Color(0xFF0F7A45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (var i = 0; i < 24; i += 2) {
      c.drawArc(Rect.fromCircle(center: mid, radius: r), i * math.pi / 12, math.pi / 12, false, edge);
    }
    if (inside) {
      final me = mid + Offset(-r * .28, r * .18);
      c.drawCircle(me, 13, Paint()..color = const Color(0xFF2F7BF6).withValues(alpha: .25));
      c.drawCircle(me, 7, Paint()..color = Colors.white);
      c.drawCircle(me, 5, Paint()..color = const Color(0xFF2F7BF6));
      return;
    }
    final me = Offset(s.width * .16, s.height * .74), to = mid + Offset(-r * .93, r * .36);
    final line = Paint()
      ..color = const Color(0xFFC22A1B)
      ..strokeWidth = 2;
    final step = (to - me) / 12;
    for (var i = 0; i < 12; i += 2) {
      c.drawLine(me + step * i.toDouble(), me + step * (i + 1).toDouble(), line);
    }
    c.drawCircle(me, 7, Paint()..color = Colors.white);
    c.drawCircle(me, 5, Paint()..color = const Color(0xFFC22A1B));
    final tp = TextPainter(text: TextSpan(text: '$distance m', style: const TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFFC22A1B))), textDirection: TextDirection.ltr)..layout();
    tp.paint(c, me + const Offset(12, -18));
  }

  @override
  bool shouldRepaint(covariant _Radar o) => o.inside != inside || o.distance != distance;
}

/// "3 h 28 m" since [hhmm] (HH:mm, India) by this phone's clock – shown only; nothing is counted with it. '' when it cannot be said.
String sinceText(String hhmm, DateTime now) {
  final m = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(hhmm);
  if (m == null) return '';
  final t = now.toUtc().add(const Duration(hours: 5, minutes: 30));
  final d = t.hour * 60 + t.minute - (int.parse(m.group(1)!) * 60 + int.parse(m.group(2)!));
  if (d < 0) return '';
  return '${d ~/ 60} h ${(d % 60).toString().padLeft(2, '0')} m';
}

// ---------------------------------------------------------------------------------------------------------------------------
// (3.114.0 – the two looks of the attendance app, his approval of 12-11-2026) GOLD FOR IN, RED FOR OUT.

const _goldDisc = [Color(0xFFFBE9A6), Color(0xFFDDAD40), Color(0xFFA8761A)];
const _redDisc = [Color(0xFFFF9C92), Color(0xFFE5484D), Color(0xFFA3211B)];
const _greyDisc = [Color(0xFFE3E5EC), Color(0xFFC5C9D6), Color(0xFFAFB4C4)];
const _moonDisc = [Color(0xFFFFFFFF), Color(0xFFDDE3F6), Color(0xFFC9D2F0)];

/// The round sign of a punch in the attendance app: gold – IN; red – OUT; silver – today is done; pale – it cannot be marked.
class MarkDisc extends StatelessWidget {
  const MarkDisc({super.key, required this.size, this.label = '', this.out = false, this.dim = false, this.done = false, this.tick = false, this.child});
  final double size;
  final String label;
  final bool out, dim, done, tick;

  /// what stands on the disc instead of [label] (the dial's three lines)
  final Widget? child;

  /// the colour of what is written on such a disc
  static Color inkOf({bool out = false, bool dim = false, bool done = false}) => dim ? const Color(0xFF4A5068) : done ? const Color(0xFF1A1C3A) : out ? Colors.white : const Color(0xFF2A1D00);

  @override
  Widget build(BuildContext context) {
    final colors = dim ? _greyDisc : done ? _moonDisc : out ? _redDisc : _goldDisc, ink = inkOf(out: out, dim: dim, done: done);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(center: const Alignment(-.35, -.45), radius: .95, colors: colors, stops: const <double>[0, .58, 1]),
        boxShadow: dim ? null : [BoxShadow(color: colors[1].withValues(alpha: .42), blurRadius: size * .26, spreadRadius: size * .02, offset: Offset(0, size * .08))],
      ),
      child: tick
          ? Icon(Icons.check_rounded, size: size * .62, color: ink)
          : child ?? (label.isEmpty ? null : Text(label, maxLines: 1, style: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.w800, fontSize: size * .26, color: ink, height: 1))),
    );
  }
}

/// THE DIAL of Home: the shift from its start to its end as a ring with small marks; a dot where "now" stands; once he is IN,
/// the ring is red from his IN to now. The disc in its middle marks: gold IN, red OUT. Only a drawing – nothing is counted here.
class ShiftDial extends StatelessWidget {
  const ShiftDial({super.key, required this.size, required this.now, this.from, required this.out, this.dim = false, this.done = false, required this.track, required this.tick, required this.top, required this.big, required this.under});
  final double size;

  /// where "now" stands between the shift's start and its end, 0 to 1 (null: his shift is not known – no dot)
  final double? now;

  /// where his IN stands (the red ring starts there)
  final double? from;
  final bool out, dim, done;
  final Color track, tick;
  final String top, big, under;

  @override
  Widget build(BuildContext context) {
    final ink = MarkDisc.inkOf(out: out, dim: dim, done: done), disc = size * .6;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(alignment: Alignment.center, children: [
        Positioned.fill(child: CustomPaint(painter: _DialPaint(now: now, from: from, out: out, off: dim || done, track: track, tick: tick))),
        MarkDisc(
          size: disc,
          out: out,
          dim: dim,
          done: done,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: disc * .1),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (top.isNotEmpty) FittedBox(fit: BoxFit.scaleDown, child: Text(top, maxLines: 1, style: TextStyle(fontSize: disc * .078, fontWeight: FontWeight.w700, letterSpacing: .8, color: ink.withValues(alpha: .82), height: 1.2))),
              FittedBox(fit: BoxFit.scaleDown, child: Text(big, maxLines: 1, style: TextStyle(fontFamily: 'Montserrat', fontSize: disc * .27, fontWeight: FontWeight.w800, color: ink, height: 1.1))),
              if (under.isNotEmpty) FittedBox(fit: BoxFit.scaleDown, child: Text(under, maxLines: 1, style: TextStyle(fontSize: disc * .088, fontWeight: FontWeight.w600, color: ink.withValues(alpha: .9), height: 1.25))),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _DialPaint extends CustomPainter {
  _DialPaint({required this.now, required this.from, required this.out, required this.off, required this.track, required this.tick});
  final double? now, from;
  final bool out, off;
  final Color track, tick;

  @override
  void paint(Canvas c, Size s) {
    final mid = s.center(Offset.zero), r = s.width / 2;
    const a0 = math.pi * .75, sweep = math.pi * 1.5;
    final marks = Paint()
      ..color = tick
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i <= 30; i++) {
      final a = a0 + sweep * i / 30, d = Offset(math.cos(a), math.sin(a));
      c.drawLine(mid + d * (r - (i % 5 == 0 ? 10 : 6)), mid + d * (r - 1), marks);
    }
    final rr = r - 21, ring = Rect.fromCircle(center: mid, radius: rr);
    Paint line(Color col) => Paint()
      ..color = col
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;
    c.drawArc(ring, a0, sweep, false, line(track));
    final n = now;
    if (n == null || off) return;
    final double f = n.clamp(0.0, 1.0).toDouble();
    final hue = out ? const Color(0xFFE5484D) : const Color(0xFFDDAD40);
    if (out) {
      final double b = (from ?? 0.0).clamp(0.0, f).toDouble();
      if (f > b) c.drawArc(ring, a0 + sweep * b, sweep * (f - b), false, line(hue));
    }
    final k = mid + Offset(math.cos(a0 + sweep * f), math.sin(a0 + sweep * f)) * rr;
    c.drawCircle(k, 8.5, Paint()..color = hue);
    c.drawCircle(k, 4.6, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _DialPaint o) => o.now != now || o.from != from || o.out != out || o.off != off || o.track != track || o.tick != tick;
}
