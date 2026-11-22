/* (3.166.0, asked 22-11-2026 with the pictures and the video he approved: "otp fill hotana nantr te verification hotana mast ui
 * animation … otp takla auto verify sign in button dabayla lagu naye … app madhe pn") THE SIX BOXES OF A CODE: one real box under
 * them takes what is typed, pasted or filled by the keyboard (a code copied from WhatsApp), the six boxes only show it.
 *   typing   – each digit pops in; the box to type in next has the gold edge; the thin line under them grows with the digits
 *   checking – the six boxes run together into one bar and a light passes along it
 *   right    – the bar fills green from the left, the digits give way to a white ✓
 *   wrong    – red edges and red digits (the card shakes and empties them – login.dart)
 * With "reduce motion" on the phone: the same states, without the movement. */
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum CodeState { idle, checking, ok, bad }

/// The colours of the boxes – the sign-in's own, light or dark.
class CodeLook {
  const CodeLook({required this.card, required this.line, required this.ink, required this.focus, required this.bad, required this.badSoft});
  final Color card, line, ink, focus, bad, badSoft;
  static const good = Color(0xFF128C4A);
}

class CodeBoxes extends StatefulWidget {
  const CodeBoxes({super.key, required this.controller, required this.focusNode, required this.state, required this.look, this.fieldKey, this.length = 6});
  final TextEditingController controller;
  final FocusNode focusNode;
  final CodeState state;
  final CodeLook look;
  final Key? fieldKey;
  final int length;

  @override
  State<CodeBoxes> createState() => _CodeBoxesState();
}

class _CodeBoxesState extends State<CodeBoxes> with TickerProviderStateMixin {
  late final AnimationController _merge = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
  late final AnimationController _fill = AnimationController(vsync: this, duration: const Duration(milliseconds: 520));
  late final AnimationController _tick = AnimationController(vsync: this, duration: const Duration(milliseconds: 520));
  late final AnimationController _shine = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
  bool _still = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_redraw);
    widget.focusNode.addListener(_redraw);
  }

  void _redraw() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = MediaQuery.of(context).disableAnimations;
    _follow(widget.state, null);
  }

  @override
  void didUpdateWidget(CodeBoxes old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_redraw);
      widget.controller.addListener(_redraw);
    }
    if (old.focusNode != widget.focusNode) {
      old.focusNode.removeListener(_redraw);
      widget.focusNode.addListener(_redraw);
    }
    if (old.state != widget.state) _follow(widget.state, old.state);
  }

  /// The movement of a new state.
  void _follow(CodeState s, CodeState? was) {
    if (_still) {
      _merge.value = s == CodeState.checking || s == CodeState.ok ? 1 : 0;
      _fill.value = _tick.value = s == CodeState.ok ? 1 : 0;
      _shine.stop();
      return;
    }
    switch (s) {
      case CodeState.checking:
        _fill.value = _tick.value = 0;
        _merge.forward();
        _shine.repeat();
      case CodeState.ok:
        _merge.forward();
        _shine.stop();
        _fill.forward(from: 0).then((_) {
          if (mounted && widget.state == CodeState.ok) _tick.forward(from: 0);
        });
      case CodeState.idle:
      case CodeState.bad:
        _shine.stop();
        _fill.value = _tick.value = 0;
        if (was == CodeState.checking || was == CodeState.ok) {
          _merge.reverse();
        } else {
          _merge.value = 0;
        }
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_redraw);
    widget.focusNode.removeListener(_redraw);
    _merge.dispose();
    _fill.dispose();
    _tick.dispose();
    _shine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.look, n = widget.length, text = widget.controller.text, st = widget.state;
    final busy = st == CodeState.checking || st == CodeState.ok;
    return Semantics(
      container: true,
      label: '$n-digit code',
      child: SizedBox(
        height: 60,
        child: Stack(children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: Listenable.merge([_merge, _fill, _tick, _shine]),
              builder: (_, __) => LayoutBuilder(builder: (_, c) {
                final w = c.maxWidth, m = Curves.easeInOut.transform(_merge.value), gap = 10 * (1 - m), bw = (w - gap * (n - 1)) / n;
                final fill = Curves.easeOutCubic.transform(_fill.value), tick = _tick.value;
                final bad = st == CodeState.bad;
                final edge = bad ? l.bad : (busy ? CodeLook.good : l.line);
                return Stack(clipBehavior: Clip.none, children: [
                  // ---- the one bar the boxes become (its back, the green, the light) ----
                  // (each part keeps its own key: the bar coming in must not take a box's place – its digit would pop again)
                  if (m > 0)
                    Positioned.fill(
                      key: const ValueKey('bar'),
                      child: Opacity(
                        opacity: m,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Stack(children: [
                            Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(color: l.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: edge, width: 1.6)))),
                            Positioned(left: 0, top: 0, bottom: 0, width: w * fill, child: const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF17A35A), CodeLook.good])))),
                            if (st == CodeState.checking)
                              Positioned(
                                top: 0,
                                bottom: 0,
                                left: -w * .35 + _shine.value * w * 1.7,
                                width: w * .35,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(colors: [Colors.white.withValues(alpha: 0), CodeLook.good.withValues(alpha: .16), Colors.white.withValues(alpha: 0)]),
                                  ),
                                ),
                              ),
                          ]),
                        ),
                      ),
                    ),
                  // ---- the six boxes ----
                  for (var i = 0; i < n; i++)
                    Positioned(
                      key: ValueKey('box$i'),
                      left: i * (bw + gap),
                      top: 0,
                      bottom: 0,
                      width: bw,
                      child: _box(i, i < text.length ? text[i] : '', m, fill, tick, bw),
                    ),
                  // ---- the ✓ when it is right ----
                  if (tick > 0)
                    Center(
                      key: const ValueKey('tick'),
                      child: Transform.scale(
                        scale: Curves.elasticOut.transform(tick).clamp(0, 1.4).toDouble(),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 8, offset: Offset(0, 2))]),
                          child: const Icon(Icons.check_rounded, key: Key('code-ok'), color: CodeLook.good, size: 26),
                        ),
                      ),
                    ),
                ]);
              }),
            ),
          ),
          // ---- the one real box: what is typed, pasted or filled by the keyboard; it shows nothing itself ----
          Positioned.fill(
            child: Opacity(
              opacity: 0.011,
              child: TextField(
                key: widget.fieldKey,
                controller: widget.controller,
                focusNode: widget.focusNode,
                readOnly: busy,
                autofocus: false,
                showCursor: false,
                enableInteractiveSelection: false,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(n)],
                textInputAction: TextInputAction.done,
                style: const TextStyle(fontSize: 1, color: Colors.transparent, height: 1),
                decoration: const InputDecoration(border: InputBorder.none, counterText: '', contentPadding: EdgeInsets.symmetric(vertical: 24)),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  /// One box: its edge, its digit (popping in), and how far it has run into the bar.
  Widget _box(int i, String d, double m, double fill, double tick, double bw) {
    final l = widget.look, st = widget.state, n = widget.length;
    final here = st == CodeState.idle && widget.focusNode.hasFocus && i == math.min(widget.controller.text.length, n - 1);
    final bad = st == CodeState.bad;
    final edge = bad ? l.bad : (here ? l.focus : (d.isNotEmpty ? l.ink.withValues(alpha: .38) : l.line));
    // how much of this box the green has passed: its digit turns white there, and goes when the ✓ comes
    final mid = (i + .5) / n, under = fill >= mid;
    final ink = bad ? l.bad : (under ? Colors.white : l.ink);
    return Stack(fit: StackFit.expand, children: [
      if (m < 1)
        Opacity(
          opacity: 1 - m,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: bad ? l.badSoft : l.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: edge, width: here || bad ? 1.8 : 1.2),
              boxShadow: here ? [BoxShadow(color: l.focus.withValues(alpha: .25), blurRadius: 10)] : null,
            ),
          ),
        ),
      if (d.isNotEmpty)
        Center(
          child: Opacity(
            opacity: (1 - tick * 2).clamp(0, 1).toDouble(),
            child: _still
                ? _digit(d, ink)
                : TweenAnimationBuilder<double>(
                    key: ValueKey('$i:$d'),
                    tween: Tween(begin: .45, end: 1),
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutBack,
                    builder: (_, v, ch) => Transform.translate(offset: Offset(0, (1 - v) * 10), child: Transform.scale(scale: v, child: ch)),
                    child: _digit(d, ink),
                  ),
          ),
        )
      else if (here)
        Center(child: Container(width: 2, height: 24, decoration: BoxDecoration(color: l.focus, borderRadius: BorderRadius.circular(1)))),
    ]);
  }

  Widget _digit(String d, Color c) => Text(d, style: TextStyle(fontFamily: 'Montserrat', fontSize: 24, fontWeight: FontWeight.w800, color: c, height: 1));
}

/// The thin line under the boxes: it grows with the digits typed – green, red when the code was wrong.
class CodeTrack extends StatelessWidget {
  const CodeTrack({super.key, required this.count, required this.bad, required this.line, this.length = 6});
  final int count, length;
  final bool bad;
  final Color line;
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: SizedBox(
          height: 4,
          child: Stack(children: [
            Positioned.fill(child: ColoredBox(color: line)),
            AnimatedFractionallySizedBox(
              duration: MediaQuery.of(context).disableAnimations ? Duration.zero : const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              widthFactor: (count / length).clamp(0, 1).toDouble(),
              heightFactor: 1,
              alignment: Alignment.centerLeft,
              child: ColoredBox(color: bad ? const Color(0xFFE5484D) : CodeLook.good),
            ),
          ]),
        ),
      );
}
