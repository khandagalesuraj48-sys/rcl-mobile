// (3.96.0 – his brief of 10-11-2026 "Enterprise UI Animation & Micro-Interaction Upgrade", and "modual click madhe animations ahwet zoom in
// out che") THE APP'S MOTION, in one place. Visual only: nothing here decides what a button does, when a request goes or what it answers –
// a question is answered the moment it is pressed, its closing plays after. Off with the phone's "remove animations" (disableAnimations).
//  - every question / Delete box (ask, askNote, askLines, askChanges and the other boxes): SCALE POP – in from 72 % with a small overshoot,
//    out with a short fade and scale-down;
//  - every new screen: ZOOM in / out on Android (the opening screen zooms in, the one behind zooms out – back: the other way); the iPhone
//    keeps its own slide with the swipe back from the edge.
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

/// The times (his table: a box 220–350 ms, buttons 100–180 ms).
class Mo {
  static const boxIn = Duration(milliseconds: 260);
  static const boxOut = Duration(milliseconds: 170);
  static const pop = Curves.easeOutBack;
  static const out = Curves.easeIn;
  /// no movement when the phone asks for it (Settings → Accessibility → remove animations)
  static bool still(BuildContext context) => MediaQuery.maybeOf(context)?.disableAnimations ?? false;
}

/// The page transitions of the whole app (theme.dart): zoom on Android (and the others), the iPhone's own slide (its swipe back stays).
/// (3.122.0) Android and the computers: the new screen OPENS OUT OF THE PLACE THAT WAS TOUCHED ([RevealPageTransitionsBuilder]).
const appPageTransitions = PageTransitionsTheme(builders: {
  TargetPlatform.android: RevealPageTransitionsBuilder(),
  TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
  TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
  TargetPlatform.windows: RevealPageTransitionsBuilder(),
  TargetPlatform.linux: RevealPageTransitionsBuilder(),
  TargetPlatform.fuchsia: RevealPageTransitionsBuilder(),
});

/* ───────── (3.122.0, the two videos he approved on 14-11-2026: "mala aple app madhe every click la transitions hawet ui animations
 * hawet je clearly visible and feel denare astil … fkt animation transition he sagle banawt ahe baki kahi changes naahit") ─────────
 * MOTION ONLY – nothing here decides what a touch does, what is asked of a server or what a screen shows when it has come to rest.
 * Every piece ends by itself (nothing runs for ever) and stands still with the phone's "remove animations".
 *   TapSpot        – remembers where the screen was last touched (for the screen that opens out of that place)
 *   RevealPage…    – a new screen grows as a circle out of the touched place; the screen behind sinks back a little; Back: the other way
 *   Rise           – a part of a screen comes up into its place, one after the other (order)
 *   CountUp        – a number counts up to its value
 *   TabSlide       – the page of a tab slides in from the side of the tab that was chosen
 *   Turn           – a button's picture turns (the gold + becomes ×)
 *   Bounce         – a thing that is touched goes in a little and springs back (for the buttons that are not a Press) */

/// Where the screen was last touched. Put once around the whole app (main.dart).
class TapSpot extends StatelessWidget {
  const TapSpot({super.key, required this.child});
  final Widget child;
  static Offset? last;
  @override
  Widget build(BuildContext context) => Listener(behavior: HitTestBehavior.translucent, onPointerDown: (e) => last = e.position, child: child);
}

class RevealPageTransitionsBuilder extends PageTransitionsBuilder {
  const RevealPageTransitionsBuilder();
  static final _from = Expando<_Spot>();
  @override
  Widget buildTransitions<T>(PageRoute<T> route, BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    if (Mo.still(context)) return child;
    final spot = _from[route] ??= _Spot(TapSpot.last);
    return _Reveal(at: spot.at, animation: animation, secondary: secondaryAnimation, child: child);
  }
}

class _Spot {
  _Spot(this.at);
  final Offset? at;
}

class _Reveal extends StatelessWidget {
  const _Reveal({required this.at, required this.animation, required this.secondary, required this.child});
  final Offset? at;
  final Animation<double> animation, secondary;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context), o = at ?? size.center(Offset.zero);
    final align = Alignment(size.width <= 0 ? 0.0 : (o.dx / size.width * 2 - 1).clamp(-1.0, 1.0).toDouble(), size.height <= 0 ? 0.0 : (o.dy / size.height * 2 - 1).clamp(-1.0, 1.0).toDouble());
    return AnimatedBuilder(
      animation: Listenable.merge([animation, secondary]),
      child: child,
      builder: (c, w) {
        final a = Curves.easeOutCubic.transform(animation.value.clamp(0.0, 1.0).toDouble()), b = Curves.easeOut.transform(secondary.value.clamp(0.0, 1.0).toDouble());
        // ALWAYS the same shape of widgets (clip → scale → scale → the screen): were it to change when the motion ends, the screen
        // inside would be built anew and lose what it holds. At rest the clip is the whole screen and both scales are 1.
        return ClipPath(
          clipper: a >= 1 ? null : _Circle(o, a),
          child: Transform.scale(
            scale: .9 + .1 * a,
            alignment: align,
            child: Transform.scale(scale: 1 - .06 * b, child: w), // the screen behind the one that opens sinks back a little
          ),
        );
      },
    );
  }
}

class _Circle extends CustomClipper<Path> {
  _Circle(this.at, this.t);
  final Offset at;
  final double t;
  @override
  Path getClip(Size size) {
    double far(Offset p) => (p - at).distance;
    final r = [far(Offset.zero), far(Offset(size.width, 0)), far(Offset(0, size.height)), far(Offset(size.width, size.height))].reduce((x, y) => x > y ? x : y);
    return Path()..addOval(Rect.fromCircle(center: at, radius: 24 + (r - 24) * t));
  }

  @override
  bool shouldReclip(_Circle old) => old.t != t || old.at != at;
}

/// A part of a screen comes up into its place – a little later for each [order] (0, 1, 2 …). Once, when it is first shown.
class Rise extends StatefulWidget {
  const Rise({super.key, required this.child, this.order = 0, this.from = 26, this.flip = false});
  final Widget child;
  final int order;
  /// from how far below (logical pixels)
  final double from;
  /// turns in around its upright axis instead (a day of the month)
  final bool flip;
  @override
  State<Rise> createState() => _RiseState();
}

class _RiseState extends State<Rise> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _a;
  @override
  void initState() {
    super.initState();
    final wait = (widget.order.clamp(0, 14) * 55).toDouble(), all = wait + 460;
    _c = AnimationController(vsync: this, duration: Duration(milliseconds: all.round()));
    _a = CurvedAnimation(parent: _c, curve: Interval(wait / all, 1, curve: Curves.easeOutBack));
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (Mo.still(context)) return widget.child;
    return AnimatedBuilder(
      animation: _a,
      child: widget.child,
      builder: (c, w) {
        // (always the same shape of widgets – see _Reveal – so what is inside keeps what it holds)
        final v = _c.isCompleted ? 1.0 : _a.value, seen = v.clamp(0.0, 1.0).toDouble();
        final Widget moved = widget.flip
            ? Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, .0015)
                  ..rotateY((1 - seen) * 1.4),
                child: w)
            : Transform.translate(offset: Offset(0, widget.from * (1 - v)), child: Transform.scale(scale: .96 + .04 * seen, child: w));
        return Opacity(opacity: (seen * 1.6).clamp(0.0, 1.0).toDouble(), child: moved);
      },
    );
  }
}

/// A number that counts up to [value] (and on to a new value when it changes). [text] writes it (its commas, its unit).
class CountUp extends StatelessWidget {
  const CountUp({super.key, required this.value, required this.text, this.style, this.ms = 800, this.textKey});
  /// the key of the written number itself (what a test reads)
  final Key? textKey;
  final num value;
  final String Function(num v) text;
  final TextStyle? style;
  final int ms;
  @override
  Widget build(BuildContext context) {
    if (Mo.still(context)) return Text(text(value), key: textKey, maxLines: 1, style: style);
    final whole = value == value.roundToDouble();
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: Duration(milliseconds: ms),
      curve: Curves.easeOutCubic,
      builder: (c, v, _) => Text(key: textKey, text(v >= value || (value < 0 && v <= value) ? value : (whole ? v.round() : (v * 10).round() / 10)), maxLines: 1, style: style),
    );
  }
}

/// The page of a tab slides in from the side of the tab that was chosen: [index] is the tab's place, [child] the pages.
class TabSlide extends StatefulWidget {
  const TabSlide({super.key, required this.index, required this.child});
  final int index;
  final Widget child;
  @override
  State<TabSlide> createState() => _TabSlideState();
}

class _TabSlideState extends State<TabSlide> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 340), value: 1);
  double _side = 1;
  @override
  void didUpdateWidget(TabSlide old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index) {
      _side = widget.index > old.index ? 1 : -1;
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (Mo.still(context)) return widget.child;
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (c, w) {
        // (always the same shape of widgets, so the pages keep what they hold)
        final v = Curves.easeOutCubic.transform(_c.value);
        return Opacity(opacity: (.25 + .75 * v).clamp(0.0, 1.0).toDouble(), child: Transform.translate(offset: Offset(_side * 46 * (1 - v), 0), child: w));
      },
    );
  }
}

/// A button's picture turns while [on] (the gold + becomes ×).
class Turn extends StatelessWidget {
  const Turn({super.key, required this.on, required this.child, this.turns = .375});
  final bool on;
  final double turns;
  final Widget child;
  @override
  Widget build(BuildContext context) => AnimatedRotation(turns: on ? turns : 0, duration: Mo.still(context) ? Duration.zero : const Duration(milliseconds: 320), curve: Curves.easeOutBack, child: child);
}

/// A box over the screen – as [showDialog] (the same [builder], the same answer, a tap outside closes it unless [barrierDismissible] is
/// false), with the SCALE POP: in from 72 % with a small overshoot and a fade, out with a fade and a slight scale-down.
Future<T?> popDialog<T>({required BuildContext context, required WidgetBuilder builder, bool barrierDismissible = true}) {
  final still = Mo.still(context);
  final nav = Navigator.of(context, rootNavigator: true);
  // the themes around the asking screen go with the box (as showDialog does)
  final themes = InheritedTheme.capture(from: context, to: nav.context);
  return nav.push<T>(_PopRoute<T>(
    out: still ? Duration.zero : Mo.boxOut,
    barrierDismissible: barrierDismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black54,
    transitionDuration: still ? Duration.zero : Mo.boxIn,
    pageBuilder: (c, a1, a2) => themes.wrap(SafeArea(child: Builder(builder: builder))),
    transitionBuilder: (c, a, s, child) {
      if (still) return child;
      final grow = CurvedAnimation(parent: a, curve: Mo.pop, reverseCurve: Mo.out);
      return FadeTransition(
        opacity: CurvedAnimation(parent: a, curve: const Interval(0, .6, curve: Curves.easeOut), reverseCurve: Curves.easeIn),
        child: AnimatedBuilder(
          animation: grow,
          builder: (c, w) => Transform.scale(scale: a.status == AnimationStatus.reverse ? .94 + .06 * grow.value : .72 + .28 * grow.value, child: w),
          child: child,
        ),
      );
    },
  ));
}

/// showGeneralDialog's own route, with a shorter way out (the box goes faster than it comes, 170 ms – as showDialog's 150 ms).
class _PopRoute<T> extends RawDialogRoute<T> {
  _PopRoute({
    required this.out,
    required super.pageBuilder,
    required super.barrierDismissible,
    required super.barrierLabel,
    required super.barrierColor,
    required super.transitionDuration,
    required super.transitionBuilder,
  });
  final Duration out;
  @override
  Duration get reverseTransitionDuration => out;
}

/// A thing that is touched goes in a little and springs back. It only watches the finger – the touch itself goes on to the child.
class Bounce extends StatefulWidget {
  const Bounce({super.key, required this.child, this.to = .9});
  final Widget child;
  final double to;
  @override
  State<Bounce> createState() => _BounceState();
}

class _BounceState extends State<Bounce> {
  bool _down = false;
  void _set(bool v) {
    if (mounted && _down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    if (Mo.still(context)) return widget.child;
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(scale: _down ? widget.to : 1, duration: Duration(milliseconds: _down ? 90 : 300), curve: _down ? Curves.easeOut : Curves.easeOutBack, child: widget.child),
    );
  }
}
