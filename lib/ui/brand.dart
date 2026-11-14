/* THE LOOK OF THE APP'S OWN SCREENS – asked 14-10-2026: "login page interesting banaw, animations de, clean UI sobat beautiful pn
 * watel": the RCL mark, the logo, the picture at the top of Home and Me, things that come in softly. (3.39.0, asked 25-10-2026:
 * "old screen purn pn remove kr") the old moving green background of the opening, the lock, "No connection" and Which site is
 * gone – those screens are on the approved design now (screens/splash.dart: SplashScene, SplashBackdrop). */
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/product_brand.dart';

/* (3.124.0, asked 14-11-2026: "aple app ch name change kraych aahe ani logo pn – Sketchline Lion … RCL ha Sketchline cha client aasel,
 * login zale nantr Sketchline Lion ha logo pn asel ani client cha logo pn") THE PRODUCT AND ITS CLIENT. The app is the product
 * "Sketchline Lion" (its name, its line, its logo – here, in one place); Rachana Construction Limited is the client whose sites it
 * runs: after the sign-in both marks are shown – the product's lion and the client's own mark. What is printed (bills, reports, the
 * Log Book) stays the client's alone. */
class Product {
  /// (the name, the line and the logo as the Portal's "Branding" keeps them – core/product_brand.dart; the built-in ones until then)
  static String get first => ProductBrand.i.first;
  static String get second => ProductBrand.i.second;
  static String get name => ProductBrand.i.name;
  static String get line => ProductBrand.i.line;
  static const logo = 'assets/brand/sketchline_lion.png';
  static const gold = Color(0xFFE9B94A), goldDeep = Color(0xFFC28A1E);
}

/// The product's logo on its own black tile – the Portal's one when it has one, the built-in Sketchline lion otherwise.
class ProductMark extends StatelessWidget {
  const ProductMark({super.key, this.size = 84, this.radius});
  final double size;
  final double? radius;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: ProductBrand.i,
        builder: (_, __) {
          final b = ProductBrand.i.logo;
          return Container(
            width: size,
            height: size,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(radius ?? size * .28)),
            child: b == null
                ? Image.asset(Product.logo, fit: BoxFit.cover, filterQuality: FilterQuality.medium, semanticLabel: Product.name)
                : Image.memory(b, fit: BoxFit.cover, filterQuality: FilterQuality.medium, gaplessPlayback: true, semanticLabel: Product.name,
                    errorBuilder: (_, __, ___) => Image.asset(Product.logo, fit: BoxFit.cover)),
          );
        },
      );
}

/// The product's name (or, [line]: the line under it) as text – written again when the Portal's "Branding" changes it.
class ProductName extends StatelessWidget {
  const ProductName({super.key, this.style, this.line = false, this.prefix = '', this.suffix = ''});
  final TextStyle? style;
  final bool line;
  final String prefix, suffix;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: ProductBrand.i,
        builder: (_, __) => Text('$prefix${line ? Product.line : Product.name}$suffix', maxLines: 1, overflow: TextOverflow.ellipsis, style: style),
      );
}

/// The client company's own mark on a white tile, beside the product's: the logo the Portal keeps for the company ([companyId]),
/// the built-in Rachana "R" until there is one.
class ClientMark extends StatelessWidget {
  const ClientMark({super.key, required this.companyId, this.size = 40, this.radius = 12, this.pad = 6, this.border = true});
  final String companyId;
  final double size, radius, pad;
  final bool border;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: ProductBrand.i,
        builder: (_, __) {
          final b = ProductBrand.i.client(companyId);
          return Container(
            width: size,
            height: size,
            padding: EdgeInsets.all(pad),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(radius), border: border ? Border.all(color: const Color(0xFFECE6D9)) : null),
            child: b == null
                ? Image.asset('assets/brand/rachana_mark.png', fit: BoxFit.contain)
                : Image.memory(b, fit: BoxFit.contain, gaplessPlayback: true, errorBuilder: (_, __, ___) => Image.asset('assets/brand/rachana_mark.png', fit: BoxFit.contain)),
          );
        },
      );
}

/// The Rachana "R" on a white tile (the client company's own mark).
class Mark extends StatelessWidget {
  const Mark({super.key, this.size = 84});
  final double size;
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(size * .14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(size * .3),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .22), blurRadius: size * .35, offset: Offset(0, size * .12))],
        ),
        child: Image.asset('assets/brand/rachana_mark.png', fit: BoxFit.contain, filterQuality: FilterQuality.medium),
      );
}

/// The full "Rachana Construction Ltd." logo (see-through background – for a white surface).
class RachanaLogo extends StatelessWidget {
  const RachanaLogo({super.key, this.height = 52});
  final double height;
  @override
  Widget build(BuildContext context) => Image.asset('assets/brand/rachana_logo.png', height: height, fit: BoxFit.contain, filterQuality: FilterQuality.medium, semanticLabel: 'Rachana Construction Limited');
}

/// The picture at the top of Home and Me: a site at dawn – sky, hills, the road – with a crane, a lorry and a tractor (3D).
class HeroScene extends StatelessWidget {
  const HeroScene({super.key, required this.height, this.child, this.machines = true});
  final double height;
  final Widget? child;
  final bool machines;
  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        child: Stack(fit: StackFit.expand, children: [
          const CustomPaint(painter: _Scene()),
          if (machines) ...[
            Positioned(right: 6, bottom: height * .16, child: Image.asset('assets/icons3d/building_construction.png', height: height * .5)),
            Positioned(right: height * .42, bottom: height * .12, child: Image.asset('assets/icons3d/articulated_lorry.png', height: height * .27)),
            Positioned(right: height * .1, bottom: height * .05, child: Image.asset('assets/icons3d/tractor.png', height: height * .25)),
          ],
          if (child != null) child!,
        ]),
      );
}

class _Scene extends CustomPainter {
  const _Scene();
  @override
  void paint(Canvas c, Size s) {
    final r = Offset.zero & s;
    c.drawRect(r, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF0B4A24), Color(0xFF17803D), Color(0xFF6DBE7E)], stops: [0, .55, 1]).createShader(r));
    // the sun's glow
    final sun = Offset(s.width * .78, s.height * .3);
    c.drawCircle(sun, s.width * .5, Paint()..shader = RadialGradient(colors: [const Color(0x55FFE8A3), const Color(0x00FFE8A3)]).createShader(Rect.fromCircle(center: sun, radius: s.width * .5)));
    Path hill(double y0, double amp, double ph) {
      final p = Path()..moveTo(0, s.height);
      for (double x = 0; x <= s.width; x += 6) {
        p.lineTo(x, s.height * y0 - amp * s.height * (0.5 + 0.5 * math.sin(x / s.width * math.pi * 2.2 + ph)));
      }
      return p
        ..lineTo(s.width, s.height)
        ..close();
    }

    c.drawPath(hill(.62, .16, .6), Paint()..color = const Color(0x33FFFFFF));
    c.drawPath(hill(.74, .12, 2.4), Paint()..color = const Color(0x40114A26));
    c.drawPath(hill(.86, .08, 4.1), Paint()..color = const Color(0x660A3D1E));
    // fine diagonal lines like a site plan
    final g = Paint()
      ..color = Colors.white.withValues(alpha: .05)
      ..strokeWidth = 1;
    for (double x = -s.height; x < s.width; x += 34) {
      c.drawLine(Offset(x, 0), Offset(x + s.height, s.height), g);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter o) => false;
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
