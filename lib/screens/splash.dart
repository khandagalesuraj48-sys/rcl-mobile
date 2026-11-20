/* THE APP'S FIRST SCREEN – while the sign-in kept on this phone is checked and a site is opened (Gate: Stage.starting /
 * Stage.opening). (3.154.0, his choice of 21-11-2026 – the picture he sent back: "mala watat video nko lawayla … ha mi photo dilay
 * … he lau") THE CREST: the lion in its round gold ring on the fine gold lines of a survey sheet, the product's name, its gold
 * line, the line under it, "Build · Manage · Move Forward", the gold wave, and at the bottom "Preparing your workspace..." with
 * the gold bar and the version. No photo, no film, no red. LIGHT when the phone is light, DARK when it is dark.
 * The bar is the REAL state of the opening (Session.boot – the kept sign-in read, the sites from the Portal, the site's ticket,
 * the site's lists), never a made-up figure. Everything but the lion is drawn here (sharp on every screen). Sizes follow the
 * width of the design (852 × 1846) – [s] below – so a small phone, a large one and a tablet look the same; the top and the bottom
 * keep clear of the status bar and the navigation bar. Nothing here signs in, opens or saves. */
import 'dart:math' as math;

import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';

import '../core/product_brand.dart';
import '../core/update.dart' show appVersion;
import '../ui/brand.dart' show Product;
import '../ui/crest.dart';
import '../ui/t.dart';

/// The colours of the design.
class SplashC {
  static const navy = Color(0xFF0A0E22); // the top of the dark scene
  static const navyMid = Color(0xFF161B36), navyDeep = Color(0xFF16225A); // its middle and its bottom
  static const band = Color(0xFF0F1638); // under the wave
  static const ink = Color(0xFF14224F); // the name on the light scene
  static const cream = Color(0xFFFBF3DE), pearl = Color(0xFFEFF1FA), bandLight = Color(0xFFDFE2EC);
  static const track = Color(0xFF2B3354), trackLight = Color(0xFFC6CAD3);
}

/// The scene's own colours: dark or light.
class _Tone {
  const _Tone(this.dark);
  final bool dark;
  List<Color> get sky => dark ? const [SplashC.navy, SplashC.navyMid, SplashC.navyDeep] : const [SplashC.cream, Color(0xFFF4EDDD), SplashC.pearl];
  Color get band => dark ? SplashC.band : SplashC.bandLight;
  Color get lines => kCrestGold.withValues(alpha: dark ? .3 : .42);
  Color get name => dark ? Colors.white : SplashC.ink;
  Color get soft => dark ? const Color(0xFFB9C0D9) : const Color(0xFF5A6382);
  Color get faint => dark ? const Color(0xFF5E6788) : const Color(0xFFA9AFC2);
  Color get label => dark ? Colors.white : const Color(0xFF0F1830);
  Color get track => dark ? SplashC.track : SplashC.trackLight;
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key, required this.progress});

  /// How far the opening is (0 – 1), from Session.boot.
  final double progress;

  @override
  Widget build(BuildContext context) {
    // (3.154.0) light when the phone is light, dark when it is dark
    final dark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: dark ? SplashC.navy : SplashC.cream,
        body: SplashScene(dark: dark, bottom: (s) => _Progress(s: s, value: progress, tone: _Tone(dark))),
      ),
    );
  }
}

/// The scene of the design – the survey lines, the lion in its ring, the name and its words at the top, the gold wave – with
/// [bottom] at the bottom: the opening's bar (SplashScreen), "No connection" (main.dart Waiting). [room] = the height [bottom]
/// needs (0: the bar, placed as the design has it; more: a card – the lion and the name are then smaller, at the top); on a
/// screen too short for both (a phone held across) the words at the top give way and [bottom] scrolls – it is never cut, its
/// button (at its foot) always on the screen. [side]: its margin left and right (of the design's width). [dark]: a card's
/// scene is always the dark one (its card is dark glass).
class SplashScene extends StatelessWidget {
  const SplashScene({super.key, required this.bottom, this.room = 0, this.side = .12, this.dark = true});
  final Widget Function(double s) bottom;
  final double room, side;
  final bool dark;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final mq = MediaQuery.of(context), tone = _Tone(dark);
        final w = box.maxWidth, h = box.maxHeight, pad = mq.padding;
        // the width the design is drawn for: the phone's width; on a wide screen (a tablet held across) the design's
        // own shape (852 × 1846) at this height – never smaller than 300 so a phone held across still reads
        final s = math.min(w, math.max(h * 852 / 1846, math.min(w, 300.0)));
        final bar = room <= 0, below = bar ? math.max(s * .149, pad.bottom + 16) : math.max(s * .06, pad.bottom + 16);
        // the bar: the lion large, a fifth of the way down; a card: the lion small at the top (as the screen before)
        const words = .33; // the name, its line, the line under it and "Build · Manage · Move Forward" (of s)
        var logoTop = bar ? math.max(h * .17, pad.top + s * .03) : math.max(h * .099, pad.top + s * .03);
        var lion = s * (bar ? .36 : .2);
        final barTop = h - below - s * .15;
        if (bar && logoTop + lion + s * words > barTop - 8) {
          // a short screen: from the top, the lion as large as there is room for
          logoTop = pad.top + s * .03;
          lion = (barTop - 8 - logoTop - s * words).clamp(s * .12, s * .36);
        }
        final brandEnd = logoTop + (bar ? lion + s * words : s * .42), brand = bar || h - below - room >= brandEnd + 8;
        final rest = h - below - (brand ? brandEnd + 8 : pad.top + 12);
        final x = (w - s) / 2, eddy = Offset(w / 2, logoTop + lion / 2);
        return Stack(fit: StackFit.expand, children: [
          // (3.39.0, asked 25-10-2026: "app opening slow zal aahe") the still part of the screen is drawn ONCE and kept: the bar that
          // moves is its own layer – nothing else is drawn again on every frame
          RepaintBoundary(
            child: Stack(fit: StackFit.expand, children: [
              DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: tone.sky, stops: const [0, .42, 1]))),
              Positioned.fill(child: CustomPaint(painter: CrestLines(eddy: eddy, ring: brand ? lion : s * .3, color: tone.lines))),
              if (bar) Positioned.fill(child: CustomPaint(painter: CrestWave(top: h - below - s * .36, rise: s * .13, fill: tone.band))),
              if (brand) Positioned(top: logoTop, left: 0, right: 0, child: _Brand(s: s, lion: lion, tone: tone, full: bar)),
            ]),
          ),
          if (bar)
            Positioned(left: s * side + x, right: s * (side + .002) + x, bottom: below, child: bottom(s))
          else
            Positioned(
              left: s * side + x,
              right: s * side + x,
              bottom: below,
              child: ConstrainedBox(constraints: BoxConstraints(maxHeight: math.max(0.0, rest)), child: SingleChildScrollView(reverse: true, child: bottom(s))), // (its button stays on the screen)
            ),
          if (bar) Positioned(left: 0, right: 0, bottom: math.max(pad.bottom + 4, below - s * .1), child: _Version(s: s, color: tone.faint)),
        ]);
      });
}

/// (3.39.0) The dark glass card at the bottom of the scene ("No connection").
class SplashPanel extends StatelessWidget {
  const SplashPanel({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
        decoration: BoxDecoration(
          color: const Color(0xE60B1024),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0x4DE6B94E)),
          boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 24, offset: Offset(0, 8))],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
      );
}

/// (3.39.0) The button of the scene – (3.154.0) gold, as the design's bar.
class SplashButton extends StatelessWidget {
  const SplashButton({super.key, required this.label, required this.icon, required this.onPressed});
  final Widget label;
  final IconData icon;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: kCrestGold,
          foregroundColor: const Color(0xFF2A1D00),
          disabledBackgroundColor: const Color(0x66E6B94E),
          disabledForegroundColor: const Color(0xB32A1D00),
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontFamily: 'Rubik', fontFamilyFallback: ['NotoDeva'], fontSize: 17, fontWeight: FontWeight.w800), // (the app's own letters)
        ),
        onPressed: onPressed,
        icon: Icon(icon, size: 26),
        label: label,
      );
}

/// (3.39.0) The navy of the design behind a screen of its own (Which site), with the survey lines at its top.
class SplashBackdrop extends StatelessWidget {
  const SplashBackdrop({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final w = box.maxWidth, h = box.maxHeight, s = math.min(w, math.max(h * 852 / 1846, math.min(w, 300.0)));
        return Stack(fit: StackFit.expand, children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [SplashC.navy, SplashC.navyMid, SplashC.navyDeep], stops: [0, .42, 1]),
            ),
          ),
          Positioned.fill(child: RepaintBoundary(child: CustomPaint(painter: CrestLines(eddy: Offset(w * .82, h * .1), ring: s * .3, color: kCrestGold.withValues(alpha: .2), depth: .4)))),
          child,
        ]);
      });
}

/// The lion in its ring, the name, the gold line and the words under it.
class _Brand extends StatelessWidget {
  const _Brand({required this.s, required this.lion, required this.tone, required this.full});
  final double s, lion;
  final _Tone tone;

  /// the opening screen: everything; a card's scene: no "Build · Manage · Move Forward"
  final bool full;
  @override
  Widget build(BuildContext context) {
    final title = s * (full ? .105 : .095); // (3.125.0) the name is one word ("SKETCHLINE"): one line
    // (3.124.0) the name and the logo are the Portal's ("Branding"): written again when its answer comes while this screen is up
    return ListenableBuilder(listenable: ProductBrand.i, builder: (context, _) => MediaQuery.withNoTextScaling( // (the design's sizes: "Size of the text" in Settings is for the app's screens)
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        CrestLion(key: const Key('splash-logo'), size: lion, dark: tone.dark),
        SizedBox(height: s * (full ? .05 : .03)),
        SizedBox(
          width: s * .74,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(key: const Key('splash-title'), mainAxisSize: MainAxisSize.min, children: [
              // (his picture: the name in gold on the dark scene, in navy on the light one)
              if (tone.dark)
                ShaderMask(
                  blendMode: BlendMode.srcIn,
                  shaderCallback: (r) => const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [kCrestGoldPale, Product.gold, Product.goldDeep]).createShader(r),
                  child: Text(Product.first.toUpperCase(), style: _title(title, Colors.white)),
                )
              else
                Text(Product.first.toUpperCase(), style: _title(title, tone.name)),
              if (Product.second.isNotEmpty) Text(' ${Product.second.toUpperCase()}', style: _title(title, tone.name)), // (3.125.0) a second word only when the Portal's Branding has one
            ]),
          ),
        ),
        SizedBox(height: s * .026),
        Container(width: s * .13, height: math.max(2.0, s * .0055), decoration: BoxDecoration(gradient: kCrestGoldFill, borderRadius: BorderRadius.circular(2))),
        SizedBox(height: s * .03),
        SizedBox(
          width: s * .7,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(Product.line.toUpperCase(),
                key: const Key('splash-sub'),
                maxLines: 1,
                style: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.w800, fontSize: s * .026, height: 1, letterSpacing: s * .026 * .32, color: tone.name)),
          ),
        ),
        if (full) ...[
          SizedBox(height: s * .05),
          SizedBox(
            width: s * .7,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text('Build  •  Manage  •  Move Forward', key: const Key('splash-line'), maxLines: 1, style: TextStyle(fontFamily: 'Rubik', fontWeight: FontWeight.w600, fontSize: s * .03, height: 1, letterSpacing: s * .002, color: tone.soft)),
            ),
          ),
        ],
      ]),
    ));
  }

  static TextStyle _title(double size, Color c) => TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.w800, fontSize: size, height: 1, letterSpacing: size * .04, color: c);
}

/// "Version 3.154.0" under the bar (nothing until it is read).
class _Version extends StatefulWidget {
  const _Version({required this.s, required this.color});
  final double s;
  final Color color;
  @override
  State<_Version> createState() => _VersionState();
}

class _VersionState extends State<_Version> {
  String v = '';
  @override
  void initState() {
    super.initState();
    appVersion().then((x) {
      if (mounted && x.isNotEmpty) setState(() => v = x);
    });
  }

  @override
  Widget build(BuildContext context) => v.isEmpty
      ? const SizedBox.shrink()
      : MediaQuery.withNoTextScaling(child: Text('Version ${v.split(' ').first}', key: const Key('splash-version'), textAlign: TextAlign.center, maxLines: 1, style: TextStyle(fontFamily: 'Rubik', fontSize: (widget.s * .026).clamp(10.0, 14.0), color: widget.color)));
}

/// "Preparing your workspace..." with how far the opening is, and the bar – moving smoothly to each real step.
class _Progress extends StatelessWidget {
  const _Progress({required this.s, required this.value, required this.tone});
  final double s, value;
  final _Tone tone;
  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.of(context).disableAnimations;
    final fs = (s * .0305).clamp(11.0, 17.0);
    final style = TextStyle(fontFamily: 'Rubik', fontFamilyFallback: const ['NotoDeva'], fontSize: fs, height: 1.2, color: tone.label, fontWeight: FontWeight.w600);
    return MediaQuery.withNoTextScaling(
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: value.clamp(0.0, 1.0)),
        duration: still ? Duration.zero : const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
        builder: (context, v, _) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Text('Preparing your workspace...', mr: 'तुमचे workspace तयार होत आहे...', key: const Key('splash-label'), maxLines: 1, overflow: TextOverflow.ellipsis, style: style)),
            const SizedBox(width: 12),
            Text('${(v * 100).round()}%', key: const Key('splash-pct'), style: style.copyWith(fontWeight: FontWeight.w700)),
          ]),
          SizedBox(height: s * .024),
          SizedBox(height: math.max(5.0, s * .0153), child: CustomPaint(painter: _Bar(v, tone.track))),
        ]),
      ),
    );
  }
}

class _Bar extends CustomPainter {
  _Bar(this.v, this.track);
  final double v;
  final Color track;
  @override
  void paint(Canvas canvas, Size size) {
    final r = Radius.circular(size.height / 2);
    canvas.drawRRect(RRect.fromRectAndRadius(Offset.zero & size, r), Paint()..color = track);
    if (v <= 0) return;
    final fill = Rect.fromLTWH(0, 0, math.max(size.height, size.width * v), size.height);
    canvas.drawRRect(RRect.fromRectAndRadius(fill, r), Paint()..shader = kCrestGoldFill.createShader(fill));
  }

  @override
  bool shouldRepaint(_Bar o) => o.v != v || o.track != track;
}
