/* THE LOOK OF THE APP'S OWN SCREENS (sign-in, opening, sites) – asked 14-10-2026: "login page interesting banaw, animations de,
 * clean UI sobat beautiful pn watel". A deep green sky with soft lights drifting slowly, a road at the bottom whose middle
 * line runs (a construction company's road), and the RCL mark. When the phone asks for less motion, nothing moves. */
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

/// The moving green background (the lights and the road). [child] is drawn over it.
class Backdrop extends StatefulWidget {
  const Backdrop({super.key, required this.child, this.road = true});
  final Widget child;
  final bool road;
  @override
  State<Backdrop> createState() => _BackdropState();
}

class _BackdropState extends State<Backdrop> with SingleTickerProviderStateMixin {
  late final AnimationController _t = AnimationController(vsync: this, duration: const Duration(seconds: 16));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _t.stop();
    } else if (!_t.isAnimating) {
      _t.repeat();
    }
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(fit: StackFit.expand, children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF0B3D1C), C.greenDark, Color(0xFF2E7D32), Color(0xFF1E6B4E)], stops: [0, .38, .72, 1]),
          ),
        ),
        RepaintBoundary(child: AnimatedBuilder(animation: _t, builder: (_, __) => CustomPaint(painter: _Sky(_t.value, widget.road)))),
        widget.child,
      ]);
}

class _Sky extends CustomPainter {
  _Sky(this.t, this.road);
  final double t;
  final bool road;

  @override
  void paint(Canvas canvas, Size s) {
    final a = t * 2 * math.pi;
    // soft lights drifting
    void glow(double x, double y, double r, Color c) {
      final o = Offset(x * s.width, y * s.height);
      canvas.drawCircle(o, r * s.width, Paint()..shader = RadialGradient(colors: [c, c.withValues(alpha: 0)]).createShader(Rect.fromCircle(center: o, radius: r * s.width)));
    }

    glow(.18 + .08 * math.sin(a), .16 + .05 * math.cos(a), .62, const Color(0x5566BB6A));
    glow(.92 + .06 * math.cos(a + 1), .34 + .06 * math.sin(a + 1), .55, const Color(0x4426A69A));
    glow(.45 + .1 * math.sin(a + 2.4), .62 + .04 * math.cos(a + 2), .5, const Color(0x33FFD54F));
    // fine lines like a site plan
    final grid = Paint()
      ..color = Colors.white.withValues(alpha: .045)
      ..strokeWidth = 1;
    for (double x = -s.height; x < s.width; x += 46) {
      canvas.drawLine(Offset(x + (t * 46), 0), Offset(x + s.height + (t * 46), s.height), grid);
    }
    if (!road) return;
    // the road at the bottom, its middle line running
    final top = s.height * .86;
    final path = Path()
      ..moveTo(0, s.height)
      ..lineTo(0, top + 18)
      ..quadraticBezierTo(s.width * .5, top - 18, s.width, top + 18)
      ..lineTo(s.width, s.height)
      ..close();
    canvas.drawPath(path, Paint()..color = const Color(0x55102A17));
    final dash = Paint()
      ..color = const Color(0xCCFFD54F)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final y = top + (s.height - top) * .55;
    const step = 46.0;
    for (double x = -step + (t * step * 8) % step; x < s.width + step; x += step) {
      canvas.drawLine(Offset(x, y), Offset(x + 20, y), dash);
    }
  }

  @override
  bool shouldRepaint(_Sky o) => o.t != t || o.road != road;
}

/// The RCL mark: a white tile with RCL in green.
class Mark extends StatelessWidget {
  const Mark({super.key, this.size = 84});
  final double size;
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(size * .3),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .25), blurRadius: size * .35, offset: Offset(0, size * .12))],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('RCL', style: TextStyle(fontSize: size * .33, fontWeight: FontWeight.w800, color: C.greenDark, letterSpacing: 1.5, height: 1)),
          SizedBox(height: size * .05),
          Container(width: size * .42, height: size * .055, decoration: BoxDecoration(color: const Color(0xFFFFB300), borderRadius: BorderRadius.circular(9))),
        ]),
      );
}

/// Something that comes in a little after the screen opens: it rises and becomes clear ([at] = 0…1 of the opening).
class Arrive extends StatelessWidget {
  const Arrive({super.key, required this.anim, required this.at, required this.child, this.rise = 26, this.scale = false});
  final Animation<double> anim;
  final double at, rise;
  final bool scale;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final c = CurvedAnimation(parent: anim, curve: Interval(at, math.min(1, at + .45), curve: scale ? Curves.elasticOut : Curves.easeOutCubic));
    final f = CurvedAnimation(parent: anim, curve: Interval(at, math.min(1, at + .3), curve: Curves.easeOut));
    return AnimatedBuilder(
      animation: anim,
      child: child,
      builder: (_, ch) => Opacity(
        opacity: f.value.clamp(0, 1),
        child: scale ? Transform.scale(scale: .6 + .4 * c.value, child: ch) : Transform.translate(offset: Offset(0, rise * (1 - c.value)), child: ch),
      ),
    );
  }
}
