/* ATTENDANCE ON HOME (3.105.0 – his words of 12-11-2026: "je user ERP use kartat tyana attendance pn yach app madhun lawaychi
 * aahe … simple easy to use"; approved: the strip, and "te slide kel ki new page open hoil attendance mark che"): for a person
 * who has HR on the site, a thin strip under the site's name – the sun slid across (or a tap) opens the attendance page, where
 * the place, the phone and the selfie are. The strip says where his day stands: dawn "slide to mark IN", day "on duty" with
 * the hours since IN, dusk "attendance done".
 * What it shows is what THIS phone last read from the HR server and kept (core/attend.dart AttendStore – attendance is tied to
 * one phone, so the phone knows its own punches): no question is asked of the server here, Home is not kept waiting. A kept
 * answer of another day counts as "not marked yet". Read again when he comes back from the page.
 * (3.121.0) the wide band became a small tile in Home's top row, left of Scan (see build). */
import 'dart:async';

import 'package:flutter/material.dart' hide Text;

import '../core/attend.dart';
import '../screens/attendance.dart';
import '../screens/hr_shell.dart';
import 'attend_look.dart';
import 'hr_skin.dart';
import 'scope.dart';
import 't.dart';
import 'theme.dart';
import 'widgets.dart';

class AttendStrip extends StatefulWidget {
  const AttendStrip({super.key});
  @override
  State<AttendStrip> createState() => _AttendStripState();
}

class _AttendStripState extends State<AttendStrip> {
  Map<String, dynamic>? last;
  String who = '';
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

    final tin = time('in'), tout = time('out');
    /* (3.121.0, his picture of 13-11-2026: "attendance che button etk moth aahe te redesign kruya … scanner che left bajula mark
     * attendance he button premium madhe banaw") a small tile beside Scan instead of the wide band:
     *   IN to mark – deep blue to violet with a gold edge, "Mark IN";  on duty – green, "Mark OUT" with the time of IN;
     *   done – a quiet white tile with both times. A tap opens the attendance app, as the band did. */
    final dawn = sky == Sky.dawn, day = sky == Sky.day;
    final en = dawn ? 'Mark IN' : day ? 'Mark OUT' : 'Done';
    final sub = dawn ? 'हजेरी लावा' : day ? (tin.isEmpty ? 'कामावर' : 'IN $tin') : (tin.isEmpty || tout.isEmpty ? 'हजेरी पूर्ण' : '$tin – $tout');
    final ink = dawn || day ? Colors.white : C.greenDark;
    final soft = dawn ? const Color(0xFFE9D9A6) : day ? const Color(0xFFD8F3E2) : C.muted;
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Semantics(
        button: true,
        label: en,
        child: GestureDetector(
          key: const Key('att-strip'),
          behavior: HitTestBehavior.opaque,
          onTap: _open,
          child: Container(
            width: 92,
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: dawn || day ? null : Colors.white,
              gradient: dawn
                  ? const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF1E2A5A), Color(0xFF4A2B6B), Color(0xFF6B3A7C)])
                  : day
                      ? const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF0F5C3C), Color(0xFF1F7A4D), Color(0xFF2E9C63)])
                      : null,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: dawn ? const Color(0xBFE8BE60) : day ? const Color(0x8CFFFFFF) : const Color(0xFFCFE8D9), width: 1.3),
              boxShadow: [BoxShadow(color: dawn ? const Color(0x523C286E) : day ? const Color(0x4D1F7A4D) : const Color(0x1A1E283C), blurRadius: 14, offset: const Offset(0, 6))],
            ),
            child: Stack(children: [
              Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  if (dawn) const Icon(Icons.fingerprint_rounded, color: Colors.white, size: 18) else if (!day) const Icon(Icons.check_rounded, color: C.greenDark, size: 17),
                  FittedBox(fit: BoxFit.scaleDown, child: Text(en, maxLines: 1, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: ink, height: 1.15))),
                  FittedBox(fit: BoxFit.scaleDown, child: Text(sub, maxLines: 1, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: soft, height: 1.2))),
                ]),
              ),
              if (dawn || day)
                Positioned(
                  top: 6,
                  right: 2,
                  child: Container(width: 7, height: 7, decoration: BoxDecoration(color: dawn ? const Color(0xFFF5B841) : const Color(0xFF7CF0A8), shape: BoxShape.circle)),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}
