/* (3.37.0, asked 25-10-2026: the approved "RCL ERP Premium Splash Screen") The app's first screen – while the sign-in kept on this
 * phone is checked and a site is opened (Gate: Stage.starting / Stage.opening). Dark navy, the photo of the PQC road (the finished
 * concrete on the left, the paving on the right), the Rachana mark on its white tile, "RCL ERP" (RCL red, ERP white), its red line,
 * INTEGRATED CONSTRUCTION MANAGEMENT, and at the bottom "Preparing your workspace..." with the bar. The bar is the REAL state of the
 * opening (Session.boot – the kept sign-in read, the sites from the Portal, the site's ticket, the site's lists), never a made-up
 * figure. The logo, the words and the bar are drawn here (sharp on every screen); only the road is a picture. Sizes follow the
 * width of the approved design (852 × 1846) – [s] below – so a small phone, a large one and a tablet look the same;
 * the top and the bottom keep clear of the status bar and the navigation bar. Nothing here signs in, opens or saves. */
import 'dart:math' as math;

import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';

import '../ui/t.dart';

/// The colours of the approved design.
class SplashC {
  static const navy = Color(0xFF022646); // the sky at the top
  static const navyDeep = Color(0xFF06111C); // the band at the bottom
  static const red = Color(0xFFD91818); // the line under the title
  static const redTop = Color(0xFFE21B24), redBottom = Color(0xFFB5080F); // "RCL"
  static const barFrom = Color(0xFFD90A16), barTo = Color(0xFFF25750); // the bar
  static const track = Color(0xFF515861);
}

/// The photo of the road (852 × 990) and where its sun and its bottom worker are – they are put where the design has them.
const kSplashRoad = 'assets/splash/pqc_road.webp';
const _roadAspect = 852 / 990, _sunAt = .126, _sunOnScreen = .363;

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key, required this.progress});

  /// How far the opening is (0 – 1), from Session.boot.
  final double progress;

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light, // (as the opening screen before: light icons on the dark screen)
        child: Scaffold(
          backgroundColor: SplashC.navy,
          body: LayoutBuilder(builder: (context, box) {
            final mq = MediaQuery.of(context);
            final w = box.maxWidth, h = box.maxHeight, pad = mq.padding;
            // the width the design is drawn for: the phone's width; on a wide screen (a tablet held across) the design's
            // own shape (852 × 1846) at this height – never smaller than 300 so a phone held across still reads
            final s = math.min(w, math.max(h * 852 / 1846, math.min(w, 300.0)));
            // the road: the whole width of the photo (as the design – its finished road on the left, the paver and the worker on the
            // right), its sun at 36 % of the height; a short wide screen: at least half the height
            final rh = math.max(w * 1.02 / _roadAspect, h * .5), rw = rh * _roadAspect, rt = h * _sunOnScreen - rh * _sunAt;
            final logoTop = math.max(h * .099, pad.top + s * .03);
            final barBottom = math.max(s * .149, pad.bottom + 16);
            return Stack(fit: StackFit.expand, children: [
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [SplashC.navy, Color(0xFF0B2643), SplashC.navyDeep], stops: [0, .45, 1]),
                ),
              ),
              Positioned.fill(child: CustomPaint(painter: _Glow(Offset(w * .1, rt + rh * _sunAt), s))),
              Positioned(left: (w - rw) / 2, top: rt, width: rw, height: rh, child: const _Road()),
              Positioned.fill(child: CustomPaint(painter: _Decor(s))),
              Positioned(
                top: logoTop,
                left: 0,
                right: 0,
                child: _Brand(s: s),
              ),
              Positioned(left: s * .12 + (w - s) / 2, right: s * .122 + (w - s) / 2, bottom: barBottom, child: _Progress(s: s, value: progress)),
            ]);
          }),
        ),
      );
}

/// The photo – its top and its bottom fade out (they are see-through there, so the navy and the sunset's light behind it go on
/// into the photo without a line); it comes in softly when it is read (the screen never waits for it).
class _Road extends StatelessWidget {
  const _Road();
  @override
  Widget build(BuildContext context) => ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (r) => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x00000000), Color(0x73000000), Color(0xD9000000), Color(0xFF000000), Color(0xFF000000), Color(0x00000000)],
          stops: [0, .045, .1, .15, .87, 1],
        ).createShader(r),
        child: Image.asset(
          kSplashRoad,
          key: const Key('splash-road'),
          fit: BoxFit.fill,
          filterQuality: FilterQuality.medium,
          gaplessPlayback: true,
          excludeFromSemantics: true,
          frameBuilder: (context, child, frame, sync) => sync
              ? child
              : AnimatedOpacity(opacity: frame == null ? 0 : 1, duration: const Duration(milliseconds: 260), curve: Curves.easeOut, child: child),
        ),
      );
}

/// The sunset's warm light over the navy above the photo's own sky – so the sky goes from the navy into the photo without a line.
class _Glow extends CustomPainter {
  _Glow(this.sun, this.s);
  final Offset sun;
  final double s;
  @override
  void paint(Canvas canvas, Size size) {
    final r = s * .85;
    canvas.save();
    canvas.translate(sun.dx, sun.dy);
    canvas.scale(1.7, 1);
    canvas.drawCircle(
        Offset.zero,
        r,
        Paint()
          ..shader = const RadialGradient(colors: [Color(0x8CC9784A), Color(0x26704A55), Color(0x00022646)], stops: [0, .45, 1])
              .createShader(Rect.fromCircle(center: Offset.zero, radius: r)));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_Glow o) => o.sun != sun || o.s != s;
}

/// The mark on its white tile, "RCL ERP", the red line and the words under it.
class _Brand extends StatelessWidget {
  const _Brand({required this.s});
  final double s;
  @override
  Widget build(BuildContext context) {
    final tile = s * .218, title = s * .11;
    return MediaQuery.withNoTextScaling( // (the design's sizes: "Size of the text" in Settings is for the app's screens)
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          key: const Key('splash-logo'),
          width: tile,
          height: tile,
          padding: EdgeInsets.all(tile * .16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(tile * .19),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .35), blurRadius: tile * .16, offset: Offset(0, tile * .05))],
          ),
          child: Image.asset('assets/brand/rachana_mark.png', fit: BoxFit.contain, filterQuality: FilterQuality.medium, semanticLabel: 'Rachana'),
        ),
        SizedBox(height: s * .014),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(key: const Key('splash-title'), mainAxisSize: MainAxisSize.min, children: [
            ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (r) => const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [SplashC.redTop, SplashC.redBottom]).createShader(r),
              child: Text('RCL', style: _title(title, Colors.white)),
            ),
            Text(' ERP', style: _title(title, Colors.white)),
          ]),
        ),
        SizedBox(height: s * .008),
        Container(width: s * .082, height: math.max(2.0, s * .0042), decoration: BoxDecoration(color: SplashC.red, borderRadius: BorderRadius.circular(2))),
        SizedBox(height: s * .02),
        SizedBox(
          width: s * .66,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text('INTEGRATED CONSTRUCTION MANAGEMENT',
                key: const Key('splash-sub'),
                maxLines: 1,
                style: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.w400, fontSize: s * .02, height: 1, letterSpacing: s * .02 * .3, color: const Color(0xF2F8F8F8))),
          ),
        ),
      ]),
    );
  }

  static TextStyle _title(double size, Color c) => TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.w800, fontSize: size, height: 1, letterSpacing: -size * .005, color: c);
}

/// "Preparing your workspace..." with how far the opening is, and the bar – moving smoothly to each real step.
class _Progress extends StatelessWidget {
  const _Progress({required this.s, required this.value});
  final double s, value;
  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.of(context).disableAnimations;
    final fs = (s * .0285).clamp(11.0, 16.0);
    final style = TextStyle(fontFamily: 'Rubik', fontFamilyFallback: const ['NotoDeva'], fontSize: fs, height: 1.2, color: const Color(0xEBFFFFFF), fontWeight: FontWeight.w400);
    return MediaQuery.withNoTextScaling(
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: value.clamp(0.0, 1.0)),
        duration: still ? Duration.zero : const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
        builder: (context, v, _) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Text('Preparing your workspace...', mr: 'तुमचे workspace तयार होत आहे...', key: const Key('splash-label'), maxLines: 1, overflow: TextOverflow.ellipsis, style: style)),
            const SizedBox(width: 12),
            Text('${(v * 100).round()}%', key: const Key('splash-pct'), style: style.copyWith(color: Colors.white)),
          ]),
          SizedBox(height: s * .024),
          SizedBox(height: math.max(5.0, s * .0153), child: CustomPaint(painter: _Bar(v))),
        ]),
      ),
    );
  }
}

class _Bar extends CustomPainter {
  _Bar(this.v);
  final double v;
  @override
  void paint(Canvas canvas, Size size) {
    final r = Radius.circular(size.height / 2);
    canvas.drawRRect(RRect.fromRectAndRadius(Offset.zero & size, r), Paint()..color = SplashC.track);
    if (v <= 0) return;
    final fill = Rect.fromLTWH(0, 0, math.max(size.height, size.width * v), size.height);
    canvas.drawRRect(RRect.fromRectAndRadius(fill, r),
        Paint()..shader = const LinearGradient(colors: [SplashC.barFrom, SplashC.barTo]).createShader(fill));
  }

  @override
  bool shouldRepaint(_Bar o) => o.v != v;
}

/// The red tile at the top left with its fine outline, and at the bottom the dark band with its light line and the red streaks.
class _Decor extends CustomPainter {
  _Decor(this.s);
  final double s;

  /// A rounded square turned 45° – its right corner at [right], its middle at the height [cy], [half] from the middle to that
  /// corner. Drawn turned: [paint]'s shader runs in the square's own frame (left → right = the screen's top left → bottom right).
  void _diamond(Canvas canvas, double right, double cy, double half, double radius, Paint paint) {
    final d = half + radius * (math.sqrt2 - 1), side = d * math.sqrt2;
    canvas.save();
    canvas.translate(right - half, cy);
    canvas.rotate(math.pi / 4);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: side, height: side), Radius.circular(radius)), paint);
    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    // the top left: the red tile – dark inside, bright along its right and lower edges – and its fine outline fading away
    final redSide = (s * .30 + s * .047 * (math.sqrt2 - 1)) * math.sqrt2;
    _diamond(canvas, s * .178, s * .209, s * .30, s * .047,
        Paint()..shader = const LinearGradient(colors: [Color(0xFF3C1630), Color(0xFF8E1927), Color(0xFFD3262C)], stops: [.15, .6, 1]).createShader(Rect.fromCenter(center: Offset.zero, width: redSide, height: redSide)));
    final lineSide = (s * .345 + s * .07 * (math.sqrt2 - 1)) * math.sqrt2;
    _diamond(canvas, s * .226, s * .225, s * .345, s * .07,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.0, s * .0022)
          ..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x80FFFFFF), Color(0x66FFFFFF), Color(0x00FFFFFF)], stops: [0, .35, .85])
              .createShader(Rect.fromCenter(center: Offset.zero, width: lineSide, height: lineSide)));

    // the bottom: the road darkens, then the band under its curved edge
    canvas.drawRect(
        Rect.fromLTWH(0, h - s * .62, w, s * .62),
        Paint()
          ..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x0006111C), Color(0x9906111C)])
              .createShader(Rect.fromLTWH(0, h - s * .62, w, s * .62)));
    final a = Offset(0, h - s * .418), c = Offset(w * .235, h - s * .195), b = Offset(w, h - s * .171);
    final edge = Path()
      ..moveTo(a.dx, a.dy)
      ..quadraticBezierTo(c.dx, c.dy, b.dx, b.dy);
    final band = Path.from(edge)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(
        band,
        Paint()
          ..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xA606111C), Color(0xF206111C), SplashC.navyDeep], stops: [0, .45, 1])
              .createShader(Rect.fromLTWH(0, a.dy, w, h - a.dy)));
    canvas.drawPath(
        edge,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.0, s * .0018)
          ..shader = const LinearGradient(colors: [Color(0x80FFFFFF), Color(0x4DFFFFFF), Color(0x1AFFFFFF)]).createShader(Rect.fromLTWH(0, 0, w, h)));

    // the red streaks at the bottom left (a glow under a fine line)
    void streak(Offset from, Offset ctrl, Offset to, double width, double alpha) {
      final p = Path()
        ..moveTo(from.dx, from.dy)
        ..quadraticBezierTo(ctrl.dx, ctrl.dy, to.dx, to.dy);
      final area = Rect.fromPoints(from, to);
      final fade = LinearGradient(colors: [const Color(0xFFFF2A2A).withValues(alpha: alpha * .7), const Color(0xFFFF2A2A).withValues(alpha: alpha), const Color(0x00FF2A2A)], stops: const [0, .35, 1]);
      canvas.drawPath(
          p,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = width * 4
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, width * 3)
            ..shader = fade.createShader(area));
      canvas.drawPath(
          p,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = width
            ..shader = fade.createShader(area));
    }

    streak(Offset(0, h - s * .353), Offset(w * .13, h - s * .30), Offset(w * .32, h - s * .24), math.max(1.2, s * .0035), 1);
    streak(Offset(0, h - s * .148), Offset(w * .2, h - s * .085), Offset(w * .46, h + s * .004), math.max(1.0, s * .0025), .6);
  }

  @override
  bool shouldRepaint(_Decor o) => o.s != s;
}
