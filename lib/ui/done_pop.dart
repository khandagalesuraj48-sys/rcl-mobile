/* (3.120.0, asked 13-11-2026: "je success full che pop up ahet te animation madhe yawet ani khali nahi centre la astil te")
 * A THING THAT WENT WELL IS SAID IN THE MIDDLE OF THE SCREEN, MOVING: a card comes up (a little spring), a gold ring draws itself
 * round the gold disc, the tick draws itself, one soft wave and a few sparks go out, the words come – and it goes by itself.
 * For the HR pages' "sent / attached / set" (a refusal or a fault stays the red message at the top – with its "Help").
 * One at a time. It never catches a tap: whatever is pressed goes to the screen under it. "Reduce motion" on the phone: it only
 * fades in and out, the ring and the tick are there at once. Only the look – nothing is decided here. */
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';

import 'goo_toast.dart';
import 'hr_skin.dart';
import 't.dart';

OverlayEntry? _doneEntry;

/// Says [title] (and [detail] under it) in the middle of the screen for [stay], then it goes.
void donePop(BuildContext context, String title, {String detail = '', Duration stay = const Duration(milliseconds: 2400)}) {
  if (!context.mounted) return;
  final ov = Overlay.maybeOf(context, rootOverlay: true);
  if (ov == null) {
    // no screen layer reachable from here: the message at the top, as before
    gooToast(context, detail.isEmpty ? title : '$title – $detail');
    return;
  }
  doneClear();
  late final OverlayEntry e;
  e = OverlayEntry(
    builder: (_) => _Done(
      key: UniqueKey(),
      title: title,
      detail: detail,
      stay: stay,
      onDone: () {
        if (identical(_doneEntry, e)) _doneEntry = null;
        if (e.mounted) e.remove();
      },
    ),
  );
  _doneEntry = e;
  ov.insert(e);
  HapticFeedback.lightImpact();
}

/// Takes the pop-up on the screen away at once.
void doneClear() {
  final e = _doneEntry;
  _doneEntry = null;
  if (e != null && e.mounted) e.remove();
}

class _Done extends StatefulWidget {
  const _Done({super.key, required this.title, required this.detail, required this.stay, required this.onDone});
  final String title, detail;
  final Duration stay;
  final VoidCallback onDone;
  @override
  State<_Done> createState() => _DoneState();
}

class _DoneState extends State<_Done> with SingleTickerProviderStateMixin {
  // the parts in milliseconds: it comes (card, ring, tick, wave), (it stays), it goes
  static const _in = 1000, _out = 240;
  late final AnimationController _c;
  late final int _total;

  @override
  void initState() {
    super.initState();
    _total = _in + widget.stay.inMilliseconds + _out;
    // preserve: its time is how long it is read – the phone's "remove animations" must not cut it to a blink
    _c = AnimationController(vsync: this, duration: Duration(milliseconds: _total), animationBehavior: AnimationBehavior.preserve)
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
    final still = MediaQuery.of(context).disableAnimations, s = skApp;
    final card = s.classic ? Colors.white : s.card, ink = s.classic ? const Color(0xFF0F1F3D) : s.ink, muted = s.classic ? const Color(0xFF59647E) : s.muted;
    return Positioned.fill(
      // nothing of it is pressed: every tap goes to the screen under it
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final ms = _c.value * _total, gone = _seg(ms, _total - _out, _out);
            final a = (_seg(ms, 0, 160) * (1 - gone)).clamp(0.0, 1.0).toDouble();
            final grow = still ? 1.0 : .85 + .15 * Curves.easeOutBack.transform(_seg(ms, 0, 360)) - .06 * gone;
            final ring = still ? 1.0 : Curves.easeOutCubic.transform(_seg(ms, 140, 320));
            final tick = still ? 1.0 : Curves.easeOutCubic.transform(_seg(ms, 400, 300));
            final wave = still ? 1.0 : _seg(ms, 420, 620);
            final words = still ? 1.0 : _seg(ms, 520, 220), more = still ? 1.0 : _seg(ms, 640, 220);
            final back = ColoredBox(color: Colors.black.withValues(alpha: (s.dark ? .5 : .3) * a), child: const SizedBox.expand());
            return Stack(children: [
              Positioned.fill(child: still || a <= 0 ? back : BackdropFilter(filter: ui.ImageFilter.blur(sigmaX: 5 * a, sigmaY: 5 * a), child: back)),
              Center(
                child: Opacity(
                  opacity: a,
                  child: Transform.scale(
                    scale: grow,
                    child: Semantics(
                      liveRegion: true,
                      container: true,
                      child: Container(
                        key: const Key('done-pop'),
                        width: 300,
                        padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
                        decoration: BoxDecoration(
                          color: card,
                          borderRadius: BorderRadius.circular(28),
                          border: s.cardLine == null ? null : Border.all(color: s.cardLine!),
                          boxShadow: const [BoxShadow(color: Color(0x33101830), blurRadius: 40, offset: Offset(0, 18))],
                        ),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          SizedBox(
                            width: 132,
                            height: 132,
                            child: CustomPaint(
                              painter: _TickPaint(ring: ring, wave: wave),
                              child: Center(
                                child: Container(
                                  width: 84,
                                  height: 84,
                                  decoration: const BoxDecoration(shape: BoxShape.circle, gradient: Sk.goldFill, boxShadow: [BoxShadow(color: Color(0x55DDAD40), blurRadius: 18, offset: Offset(0, 6))]),
                                  child: TickMark(done: tick),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Opacity(
                            opacity: words,
                            child: Transform.translate(
                              offset: Offset(0, 8 * (1 - words)),
                              child: Text(widget.title, textAlign: TextAlign.center, style: TextStyle(color: ink, fontSize: 20, fontWeight: FontWeight.w800, height: 1.25)),
                            ),
                          ),
                          if (widget.detail.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Opacity(
                                opacity: more,
                                child: Transform.translate(
                                  offset: Offset(0, 8 * (1 - more)),
                                  child: Text(widget.detail, textAlign: TextAlign.center, style: TextStyle(color: muted, fontSize: 14.5, fontWeight: FontWeight.w500, height: 1.35)),
                                ),
                              ),
                            ),
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
            ]);
          },
        ),
      ),
    );
  }
}

/// The ring round the disc, the one wave and the sparks – each by how far it has come (0 … 1). Drawn behind the disc.
class _TickPaint extends CustomPainter {
  _TickPaint({required this.ring, required this.wave});
  final double ring, wave;
  static const _gold = Color(0xFFDDAD40);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    // the wave and the sparks: once, going out and fading
    if (wave > 0 && wave < 1) {
      final fade = 1 - wave;
      canvas.drawCircle(c, 44 + 20 * wave, Paint()..color = _gold.withValues(alpha: .28 * fade));
      final dot = Paint()..color = _gold.withValues(alpha: .9 * fade);
      for (var i = 0; i < 8; i++) {
        final ang = i * math.pi / 4 + .35, far = 50 + 14 * Curves.easeOut.transform(wave);
        canvas.drawCircle(c + Offset(math.cos(ang), math.sin(ang)) * far, i.isEven ? 2.6 : 1.8, dot);
      }
    }
    // the ring draws itself from the top
    if (ring > 0) {
      canvas.drawArc(
          Rect.fromCircle(center: c, radius: 49),
          -math.pi / 2,
          2 * math.pi * ring,
          false,
          Paint()
            ..color = _gold
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..strokeCap = StrokeCap.round);
    }
  }

  @override
  bool shouldRepaint(_TickPaint old) => old.ring != ring || old.wave != wave;
}

/// The tick, drawing itself on the gold disc.
class TickMark extends StatelessWidget {
  const TickMark({super.key, required this.done});

  /// how far it is drawn (0 … 1)
  final double done;
  @override
  Widget build(BuildContext context) => CustomPaint(size: const Size(84, 84), painter: _MarkPaint(done));
}

class _MarkPaint extends CustomPainter {
  _MarkPaint(this.done);
  final double done;
  @override
  void paint(Canvas canvas, Size size) {
    if (done <= 0) return;
    final c = size.center(Offset.zero);
    final p = Path()
      ..moveTo(c.dx - 16, c.dy + 1)
      ..lineTo(c.dx - 5, c.dy + 12)
      ..lineTo(c.dx + 17, c.dy - 11);
    final pen = Paint()
      ..color = Sk.goldInk
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final m in p.computeMetrics()) {
      canvas.drawPath(m.extractPath(0, m.length * done), pen);
    }
  }

  @override
  bool shouldRepaint(_MarkPaint old) => old.done != done;
}
