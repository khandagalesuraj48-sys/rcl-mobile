/* THE CREST (3.154.0 – the picture he sent back on 21-11-2026: "ha mi photo dilay … he lau"; the login he chose: "login p1 choose
 * krel mi ekdam perfect aahe"): the product's lion in a round gold ring with its glow, on the fine gold lines of a survey sheet
 * (level lines, and an eddy of them beside the lion), and the gold wave that closes the scene. Drawn here – sharp on every
 * screen, no picture but the lion itself. The opening screen (screens/splash.dart) and the sign-in (screens/login.dart) are made
 * of these three. Nothing here reads or saves anything. */
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/product_brand.dart';
import 'brand.dart' show Product;

const kCrestGold = Color(0xFFE6B94E), kCrestGoldDeep = Color(0xFFC9960A), kCrestGoldPale = Color(0xFFF7DE8E);
const kCrestGoldFill = LinearGradient(colors: [kCrestGoldDeep, kCrestGoldPale]);

/// The lion in its gold ring. [size]: the ring's width; [dark]: on a dark page (a warm glow) or a light one (a soft shade).
class CrestLion extends StatelessWidget {
  const CrestLion({super.key, required this.size, required this.dark});
  final double size;
  final bool dark;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: ProductBrand.i,
        builder: (_, __) {
          final b = ProductBrand.i.logo;
          return Container(
            width: size,
            height: size,
            padding: EdgeInsets.all(math.max(2.0, size * .02)),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [kCrestGoldPale, kCrestGold, kCrestGoldDeep]),
              boxShadow: dark
                  ? [BoxShadow(color: kCrestGold.withValues(alpha: .28), blurRadius: size * .32, spreadRadius: size * .03)]
                  : [BoxShadow(color: const Color(0x40624A10), blurRadius: size * .22, offset: Offset(0, size * .1)), BoxShadow(color: kCrestGold.withValues(alpha: .3), blurRadius: size * .2)],
            ),
            child: ClipOval(
              child: ColoredBox(
                color: Colors.black,
                child: b == null
                    ? Image.asset(Product.logo, fit: BoxFit.cover, filterQuality: FilterQuality.medium, semanticLabel: Product.name)
                    : Image.memory(b, fit: BoxFit.cover, filterQuality: FilterQuality.medium, gaplessPlayback: true, semanticLabel: Product.name, errorBuilder: (_, __, ___) => Image.asset(Product.logo, fit: BoxFit.cover)),
              ),
            ),
          );
        },
      );
}

/// The survey sheet: level lines across [area] (the top of it down to [depth] of its height) and the eddy round [eddy] – the
/// rings round the lion ([ring]: the lion's width) and the closed lines beside it.
class CrestLines extends CustomPainter {
  CrestLines({required this.eddy, required this.ring, required this.color, this.depth = .62});
  final Offset eddy;
  final double ring, depth;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height * depth, step = math.max(26.0, w * .082);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = color;
    // the level lines: each a little different from the one above it; they fade towards the bottom
    var i = 0;
    for (var y = step * .35; y < h; y += step, i++) {
      final path = Path()..moveTo(-4, y);
      for (var x = 0.0; x <= w + 8; x += 8) {
        final t = x / w;
        path.lineTo(x, y + math.sin(t * math.pi * 2.1 + i * .9) * step * .34 + math.sin(t * math.pi * 4.6 + i * 1.7) * step * .16);
      }
      canvas.drawPath(path, p..color = color.withValues(alpha: color.a * (1 - .75 * y / h)));
    }
    p.color = color;
    // the rings round the lion: three open arcs
    for (final (k, r) in [ring * .6, ring * .76, ring * .95].indexed) {
      canvas.drawArc(Rect.fromCircle(center: eddy, radius: r), -math.pi * (.95 - k * .22), math.pi * (1.25 + k * .2), false, p..color = color.withValues(alpha: color.a * (1 - k * .25)));
    }
    // the closed lines beside it (a hill on the sheet)
    final hill = eddy + Offset(ring * .68, ring * .1);
    for (var k = 1; k <= 6; k++) {
      final rx = ring * .11 * k, ry = ring * .07 * k;
      canvas.save();
      canvas.translate(hill.dx + k * ring * .012, hill.dy - k * ring * .01);
      canvas.rotate(-.22);
      canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2), p..color = color.withValues(alpha: color.a * (1 - k * .11)));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(CrestLines o) => o.eddy != eddy || o.ring != ring || o.color != color || o.depth != depth;
}

/// The wave: where the shape drawn by [crestWave] runs, for a box of [size] whose wave stands [rise] high.
Path crestWave(Size size, double top, double rise) => Path()
  ..moveTo(0, top + rise * .55)
  ..cubicTo(size.width * .22, top - rise * .35, size.width * .42, top + rise * .1, size.width * .62, top + rise * .72)
  ..cubicTo(size.width * .78, top + rise * 1.2, size.width * .9, top + rise * .7, size.width, top);

/// The gold wave over a band of [fill] that goes down to the bottom of the box: a bright line, and a fainter second one under it.
class CrestWave extends CustomPainter {
  CrestWave({required this.top, required this.rise, required this.fill, this.second = true, this.broad = false});
  final double top, rise;
  final Color fill;

  /// the faint second line
  final bool second;

  /// [broad]: a broad band of gold along the wave (the sign-in), not a fine line
  final bool broad;

  @override
  void paint(Canvas canvas, Size size) {
    final wave = crestWave(size, top, rise);
    if (broad) {
      final upper = crestWave(size, top - rise * .5, rise);
      canvas.drawPath(
          Path.from(upper)
            ..lineTo(size.width, size.height)
            ..lineTo(0, size.height)
            ..close(),
          Paint()..color = const Color(0xFF8A7A5A));
      canvas.drawPath(
          upper,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color = kCrestGold.withValues(alpha: .5));
    }
    canvas.drawPath(
        Path.from(wave)
          ..lineTo(size.width, size.height)
          ..lineTo(0, size.height)
          ..close(),
        Paint()..color = fill);
    if (second && !broad) {
      canvas.drawPath(
          crestWave(size, top + rise * .55, rise * .8),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = kCrestGold.withValues(alpha: .32));
    }
    canvas.drawPath(
        wave,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = broad ? 2.4 : 1.8
          ..shader = const LinearGradient(colors: [kCrestGoldDeep, kCrestGoldPale, kCrestGold, kCrestGoldDeep], stops: [0, .35, .7, 1]).createShader(Offset.zero & size));
  }

  @override
  bool shouldRepaint(CrestWave o) => o.top != top || o.rise != rise || o.fill != fill || o.second != second || o.broad != broad;
}
