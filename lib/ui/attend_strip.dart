/* ATTENDANCE ON HOME (3.105.0 – his words of 12-11-2026: "je user ERP use kartat tyana attendance pn yach app madhun lawaychi
 * aahe … simple easy to use"; approved: the strip, and "te slide kel ki new page open hoil attendance mark che"): for a person
 * who has HR on the site, a thin strip under the site's name – the sun slid across (or a tap) opens the attendance page, where
 * the place, the phone and the selfie are. The strip says where his day stands: dawn "slide to mark IN", day "on duty" with
 * the hours since IN, dusk "attendance done".
 * What it shows is what THIS phone last read from the HR server and kept (core/attend.dart AttendStore – attendance is tied to
 * one phone, so the phone knows its own punches): no question is asked of the server here, Home is not kept waiting. A kept
 * answer of another day counts as "not marked yet". Read again when he comes back from the page. */
import 'dart:async';

import 'package:flutter/material.dart' hide Text;

import '../core/attend.dart';
import '../screens/attendance.dart';
import '../screens/hr_shell.dart';
import 'attend_look.dart';
import 'hr_skin.dart';
import 'scope.dart';
import 'widgets.dart';

class AttendStrip extends StatefulWidget {
  const AttendStrip({super.key});
  @override
  State<AttendStrip> createState() => _AttendStripState();
}

class _AttendStripState extends State<AttendStrip> {
  Map<String, dynamic>? last;
  String who = '';
  double drag = 0;
  bool opening = false;
  Timer? minute;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final s = SessionScope.of(context), w = hrModule(s) == null ? '' : '${s.email}|${s.site?.code ?? ''}';
    if (w == who) return;
    who = w;
    last = null;
    if (w.isNotEmpty) _read();
  }

  Future<void> _read() async {
    final w = who;
    if (w.isEmpty) return;
    final l = await AttendStore(w).last();
    if (!mounted || w != who) return;
    setState(() => last = l);
    // on duty: the hours since IN move on by themselves
    minute?.cancel();
    minute = null;
    if (_today.isNotEmpty && _next == 'out') {
      minute = Timer.periodic(const Duration(minutes: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  /// today's punches as this phone knows them (a kept answer of another day: none)
  List<Map> get _today {
    final l = last;
    if (l == null || '${l['day'] ?? ''}' != indiaDay(AttendKit.kit.now())) return const [];
    return [for (final x in (l['punches'] as List? ?? const []).whereType<Map>()) x];
  }

  String get _next => _today.isEmpty ? 'in' : ('${last?['next'] ?? 'in'}' == 'out' ? 'out' : 'in');

  Future<void> _open() async {
    if (opening) return;
    opening = true;
    await Navigator.of(context).push(hrRoute<void>(const HrShell(inErp: true))); // (3.115.0) the attendance app itself – the same pages as a person with attendance only
    opening = false;
    if (!mounted) return;
    setState(() => drag = 0);
    _read();
  }

  @override
  void dispose() {
    minute?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (who.isEmpty) return const SizedBox.shrink();
    final today = _today, next = _next, sky = skyOf(any: today.isNotEmpty, next: next);
    String time(String kind) {
      for (final p in today.reversed) {
        if (p['kind'] == kind) return '${p['time'] ?? ''}';
      }
      return '';
    }

    final tin = time('in'), tout = time('out'), since = sky == Sky.day ? sinceText(tin, DateTime.fromMillisecondsSinceEpoch(AttendKit.kit.now())) : '';
    final en = sky == Sky.dawn
        ? 'Slide to mark IN'
        : sky == Sky.day
            ? (since.isEmpty ? 'On duty' : 'On duty · $since')
            : 'Attendance done today';
    final mr = sky == Sky.dawn
        ? 'सरकवा – हजेरी लावा'
        : sky == Sky.day
            ? 'कामावर आहात · IN $tin'
            : (tin.isEmpty || tout.isEmpty ? 'आजची हजेरी पूर्ण' : 'आजची हजेरी पूर्ण · $tin – $tout');
    final right = sky == Sky.day; // on duty the sun stands on the right and is slid back
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: LayoutBuilder(builder: (context, box) {
        const h = 64.0, knob = 52.0, pad = 6.0;
        final double run = (box.maxWidth - knob - pad * 2).clamp(0.0, 2000.0).toDouble();
        void end() {
          if (drag > run * .5) {
            _open();
          } else {
            setState(() => drag = 0);
          }
        }

        return Semantics(
          button: true,
          label: en,
          child: GestureDetector(
            key: const Key('att-strip'),
            behavior: HitTestBehavior.opaque,
            onTap: _open,
            onHorizontalDragUpdate: (d) => setState(() => drag = (drag + (right ? -d.delta.dx : d.delta.dx)).clamp(0.0, run).toDouble()),
            onHorizontalDragEnd: (_) => end(),
            onHorizontalDragCancel: () => setState(() => drag = 0),
            child: Container(
              height: h,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(gradient: skyAcross(sky), borderRadius: BorderRadius.circular(h / 2), boxShadow: const [BoxShadow(color: Color(0x47141E3C), blurRadius: 16, offset: Offset(0, 8))]),
              child: Stack(children: [
                Positioned.fill(
                  child: Padding(
                    padding: EdgeInsets.only(left: right ? 20 : knob + pad + 14, right: right ? knob + pad + 14 : 16),
                    child: Align(alignment: Alignment.centerLeft, child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: TwoLang(en, mr, color: Colors.white, size: 15, weight: FontWeight.w700))),
                  ),
                ),
                Positioned(
                  top: (h - knob) / 2,
                  left: right ? null : pad + drag,
                  right: right ? pad + drag : null,
                  child: SunDisc(key: const Key('att-strip-knob'), size: knob, label: next == 'in' ? 'IN' : 'OUT', moon: sky == Sky.dusk),
                ),
              ]),
            ),
          ),
        );
      }),
    );
  }
}
