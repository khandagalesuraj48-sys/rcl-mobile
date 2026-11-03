/* (3.83.0, asked 03-11-2026 with the preview he OK'd: "notification gooey drop madhe a gooey drop falls from the top then melts
 * and spread into a toast") THE APP'S MESSAGES AS A GOOEY DROP – every short message of the app (toast(), the call's notices, the
 * phone-lock warning): at the top of the screen a drop falls (stretched, squashed when it lands), melts and spreads into the
 * message – two beads run to its ends –, then the words come in; at the end it gathers back into a drop that goes up. The web's
 * message does the same (Mechanical update-209). The colours and how long a message stays are as before.
 * One at a time: a new message takes the place of the one on the screen. Only its action ("Help" …) can be pressed – every other
 * tap goes through to the screen under it. "Reduce motion" on the phone: the message only fades in and out. */
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Text;

import 't.dart';

OverlayEntry? _gooEntry;

/// Shows [text] as a gooey drop at the top for [stay] (then it goes, in about half a second). [action] – a word to press
/// ("Help") that calls [onAction] and takes the message away.
void gooToast(BuildContext context, String text,
    {Color color = const Color(0xFF18221C), Duration stay = const Duration(seconds: 3), String? action, Color actionColor = Colors.white, VoidCallback? onAction}) {
  if (!context.mounted) return;
  // a context under the app's Navigator – or the Navigator's own (the call's notices, the phone-lock warning: its key)
  var ov = Overlay.maybeOf(context, rootOverlay: true);
  if (ov == null && context is StatefulElement && context.state is NavigatorState) ov = (context.state as NavigatorState).overlay;
  if (ov == null) return;
  gooClear();
  late final OverlayEntry e;
  e = OverlayEntry(
    builder: (_) => _Goo(
      key: UniqueKey(),
      text: text,
      color: color,
      stay: stay,
      action: action,
      actionColor: actionColor,
      onAction: onAction,
      onDone: () {
        if (identical(_gooEntry, e)) _gooEntry = null;
        if (e.mounted) e.remove();
      },
    ),
  );
  _gooEntry = e;
  ov.insert(e);
}

/// Takes the message on the screen away at once.
void gooClear() {
  final e = _gooEntry;
  _gooEntry = null;
  if (e != null && e.mounted) e.remove();
}

class _Goo extends StatefulWidget {
  const _Goo({super.key, required this.text, required this.color, required this.stay, required this.onDone, this.action, this.actionColor = Colors.white, this.onAction});
  final String text;
  final Color color, actionColor;
  final Duration stay;
  final String? action;
  final VoidCallback? onAction;
  final VoidCallback onDone;
  @override
  State<_Goo> createState() => _GooState();
}

class _GooState extends State<_Goo> with SingleTickerProviderStateMixin {
  // the parts in milliseconds: it falls, it spreads, (the message stays), it gathers and goes up
  static const _fall = 420, _spread = 460, _gone = 560;
  late final AnimationController _c;
  final _lab = GlobalKey();
  late final int _total;

  @override
  void initState() {
    super.initState();
    // the words are shown from when it has spread until it gathers – as long as the message stayed before
    _total = _fall + 260 + widget.stay.inMilliseconds + _gone;
    _c = AnimationController(vsync: this, duration: Duration(milliseconds: _total))
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) widget.onDone();
      })
      ..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  static double _seg(double ms, num from, num len) => ((ms - from) / len).clamp(0.0, 1.0).toDouble();

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context), top = mq.padding.top + 10, still = mq.disableAnimations;
    final label = Semantics(
      liveRegion: true,
      container: true,
      child: ConstrainedBox(
        key: _lab,
        constraints: BoxConstraints(minHeight: 46, maxWidth: mq.size.width - 40),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 11, 20, 11),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            // the words let a tap through to the screen under them (only the action is pressed)
            Flexible(child: IgnorePointer(child: Text(widget.text, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600, height: 1.3)))),
            if (widget.action != null) ...[
              const SizedBox(width: 12),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  widget.onDone();
                  widget.onAction?.call();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(widget.action!, style: TextStyle(color: widget.actionColor, fontSize: 14, fontWeight: FontWeight.w800, decoration: TextDecoration.underline, decorationColor: widget.actionColor)),
                ),
              ),
            ],
          ]),
        ),
      ),
    );
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final ms = _c.value * _total, out = _total - _gone.toDouble();
          final box = _lab.currentContext?.size, w = box?.width ?? 120, h = box?.height ?? 46;
          // how much the words are there: in after it has spread, out when it starts to gather
          final tx = still ? (ms < 200 ? ms / 200 : (ms > _total - 200 ? (_total - ms) / 200 : 1.0)) : (_seg(ms, _fall + 260, 220) * (1 - _seg(ms, out, 140)));
          return Stack(children: [
            if (!still)
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: top + h + 40,
                child: IgnorePointer(
                  child: ImageFiltered(
                    imageFilter: ui.ImageFilter.compose(
                      outer: const ColorFilter.matrix(<double>[1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 19, -2040]),
                      inner: ui.ImageFilter.blur(sigmaX: 7, sigmaY: 7),
                    ),
                    child: CustomPaint(painter: _GooPaint(ms: ms, top: top, w: w, h: h, color: widget.color, fall: _fall, spread: _spread, out: out, gone: _gone)),
                  ),
                ),
              ),
            Positioned(
              top: top,
              left: 0,
              right: 0,
              child: Center(
                child: IgnorePointer(
                  ignoring: tx < .5,
                  child: Opacity(
                    opacity: tx.clamp(0.0, 1.0),
                    child: still ? DecoratedBox(decoration: BoxDecoration(color: widget.color, borderRadius: BorderRadius.circular(23)), child: label) : label,
                  ),
                ),
              ),
            ),
          ]);
        },
      ),
    );
  }
}

/// The drop, the message's shape and the two beads – drawn sharp; the blur and the edge made sharp again (ImageFiltered above)
/// make the shapes that touch flow into one.
class _GooPaint extends CustomPainter {
  _GooPaint({required this.ms, required this.top, required this.w, required this.h, required this.color, required this.fall, required this.spread, required this.out, required this.gone});
  final double ms, top, w, h, out;
  final int fall, spread, gone;
  final Color color;

  static double _seg(double ms, num from, num len) => ((ms - from) / len).clamp(0.0, 1.0).toDouble();

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color;
    final cx = size.width / 2, cy = top + h / 2;
    void oval(double x, double y, double ww, double hh) {
      if (ww > .5 && hh > .5) canvas.drawOval(Rect.fromCenter(center: Offset(x, y), width: ww, height: hh), p);
    }

    void pill(double ww, double hh) {
      if (ww > .5 && hh > .5) canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx, cy), width: ww, height: hh), Radius.circular(hh < 46 ? hh / 2 : 23)), p);
    }

    // 1. it falls: stretched on the way, squashed when it lands
    if (ms < fall) {
      final u = _seg(ms, 0, fall), y = -34 + (cy + 4 + 34) * Curves.easeInCubic.transform(u.clamp(0.0, .78) / .78);
      final squash = _seg(u, .78, .22);
      oval(cx, y, 34 * (.82 + .53 * squash), 34 * (1.22 - .5 * squash));
      return;
    }
    // 2. it melts and spreads into the message; the drop sinks into it, two beads run to its ends
    final s = _seg(ms, fall, spread);
    if (ms < out) {
      final e = Curves.easeOutCubic.transform(s), over = s < .7 ? Curves.easeOut.transform(s / .7) * 1.05 : 1.05 - .05 * _seg(s, .7, .3);
      pill(34 + (w - 34) * over, 30 + (h - 30) * e);
      final d = 1 - _seg(s, 0, .6);
      oval(cx, cy + 4, 34 * 1.35 * d, 34 * .72 * d);
      if (s < 1) {
        final run = Curves.easeOutCubic.transform(_seg(s, 0, .75)) * (w / 2 - 10), r = 16 * (s < .75 ? 1.0 : 1 - _seg(s, .75, .25) * .6) * (s < .99 ? 1 : 0);
        oval(cx - run, cy, r, r);
        oval(cx + run, cy, r, r);
      }
      return;
    }
    // 3. it gathers back into a drop and goes up
    final g = _seg(ms, out, gone * .55), up = _seg(ms, out + gone * .5, gone * .5);
    if (up <= 0) {
      final k = Curves.easeInCubic.transform(g);
      pill(w + (30 - w) * k, h + (30 - h) * k);
    } else {
      oval(cx, cy - (cy + 60) * Curves.easeInCubic.transform(up), 30 * (1 - .25 * up), 30 * (1 + .3 * up));
    }
  }

  @override
  bool shouldRepaint(_GooPaint o) => o.ms != ms || o.w != w || o.h != h || o.color != color || o.top != top;
}
