// (3.96.0 – his brief of 10-11-2026 "Enterprise UI Animation & Micro-Interaction Upgrade", and "modual click madhe animations ahwet zoom in
// out che") THE APP'S MOTION, in one place. Visual only: nothing here decides what a button does, when a request goes or what it answers –
// a question is answered the moment it is pressed, its closing plays after. Off with the phone's "remove animations" (disableAnimations).
//  - every question / Delete box (ask, askNote, askLines, askChanges and the other boxes): SCALE POP – in from 72 % with a small overshoot,
//    out with a short fade and scale-down;
//  - every new screen: ZOOM in / out on Android (the opening screen zooms in, the one behind zooms out – back: the other way); the iPhone
//    keeps its own slide with the swipe back from the edge.
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
const appPageTransitions = PageTransitionsTheme(builders: {
  TargetPlatform.android: ZoomPageTransitionsBuilder(),
  TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
  TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
  TargetPlatform.windows: ZoomPageTransitionsBuilder(),
  TargetPlatform.linux: ZoomPageTransitionsBuilder(),
  TargetPlatform.fuchsia: ZoomPageTransitionsBuilder(),
});

/// A box over the screen – as [showDialog] (the same [builder], the same answer, a tap outside closes it unless [barrierDismissible] is
/// false), with the SCALE POP: in from 72 % with a small overshoot and a fade, out with a fade and a slight scale-down.
Future<T?> popDialog<T>({required BuildContext context, required WidgetBuilder builder, bool barrierDismissible = true}) {
  final still = Mo.still(context);
  // the themes around the asking screen go with the box (as showDialog does)
  final themes = InheritedTheme.capture(from: context, to: Navigator.of(context, rootNavigator: true).context);
  return showGeneralDialog<T>(
    context: context,
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
  );
}
