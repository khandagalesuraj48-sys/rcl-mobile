/* ATTENDANCE ON HOME (3.105.0 – his words of 12-11-2026: "je user ERP use kartat tyana attendance pn yach app madhun lawaychi
 * aahe … simple easy to use"; approved: the strip, and "te slide kel ki new page open hoil attendance mark che"): for a person
 * who has HR on the site, a thin strip under the site's name – the sun slid across (or a tap) opens the attendance page, where
 * the place, the phone and the selfie are. The strip says where his day stands: dawn "slide to mark IN", day "on duty" with
 * the hours since IN, dusk "attendance done".
 * What it shows is what THIS phone last read from the HR server and kept (core/attend.dart AttendStore – attendance is tied to
 * one phone, so the phone knows its own punches): no question is asked of the server here, Home is not kept waiting. A kept
 * answer of another day counts as "not marked yet". Read again when he comes back from the page.
 * (3.121.0) the wide band became a small tile in Home's top row, left of Scan.
 * (3.174.0, his words of 27-11-2026: "vehicles and Hr … ethe attendance mark krne sathi option de … jyala access asel tya site madhe
 * disel 3 site cha asel konti hi site open keli tri attendace option asel te dable ki lagech slefi sathi camera open click kel
 * attendace lavli baki terms check krun … hr madhe jaun sagle krt basaych nahi"; the approved design "LION – Quick attendance & clean
 * modules", boards 1–5) THE SITE HOME'S CARD in place of that tile (Vehicle's Home keeps only vehicle things): on the site home of
 * EVERY site of a person who has HR on any of his sites (his HR site – screens/attendance.dart hrSite). "Mark IN" / "Mark OUT" opens
 * the one-press marking of HR itself (AttendanceScreen quick + auto): his place is read, the selfie camera opens by itself, the punch
 * goes with every check of HR's (work place, his one phone, Developer Options, the network, the face where the site asks, the
 * server's day) – nothing of it is new or skipped; what stops it is said there. OUT asks "Do you really want to punch out?" first,
 * as HR's dial. */
import 'dart:async';

import 'package:flutter/material.dart' hide Text;
import 'package:flutter/material.dart' as m show Text;
import 'package:flutter/services.dart' show HapticFeedback;

import '../core/attend.dart';
import '../core/hr_track.dart';
import '../screens/attendance.dart';
import '../screens/hr_shell.dart';
import 'attend_look.dart';
import 'hr_skin.dart';
import 'scope.dart';
import 't.dart';

/// The site home's colours (screens/module_home.dart ModC – the same values).
const _navy = Color(0xFF0F1E3D), _goldPale = Color(0xFFE9D9A6), _goldInk = Color(0xFF8A6A12), _goldSoft = Color(0xFFFBF4DF);
const _muted = Color(0xFF5B6475), _green = Color(0xFF1F7A4D), _greenInk = Color(0xFF17603D), _pill = Color(0xFFEEF1F7);

class SiteAttendCard extends StatefulWidget {
  const SiteAttendCard({super.key, required this.onHr, this.paused = false, this.onPay});

  /// Attendance done for today: his HR pages (the month, leave …).
  final VoidCallback onHr;

  /// HR's subscription is paused at this site (the Portal): the button opens "Pay" – HR would only refuse the punch.
  final bool paused;
  final Future<void> Function()? onPay;
  @override
  State<SiteAttendCard> createState() => _SiteAttendCardState();
}

class _SiteAttendCardState extends State<SiteAttendCard> {
  Map<String, dynamic>? last;
  String who = '';
  bool opening = false;
  Timer? minute;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final s = SessionScope.of(context), w = hrModule(s) == null ? '' : '${s.email}|${hrSite(s)?.code ?? ''}'; // (3.141.0) his HR site – from any of his sites
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
      // (3.149.0, rcl-hr step 20) on duty by what this phone knows (the app opened again): his location for HR goes on if it was
      // on when the app was closed – nothing is asked of the server here
      final s = SessionScope.read(context);
      if (!HrTrack.i.on) unawaited(HrTrack.i.resume((b) => hrAsk(s, b)));
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

  Map get _shift => last?['shift'] is Map && '${last?['day'] ?? ''}' == indiaDay(AttendKit.kit.now()) ? last!['shift'] as Map : const {};

  /// Mark IN / OUT: OUT is asked once; then HR's one-press marking – the place, the selfie, the punch.
  Future<void> _mark() async {
    if (opening) return;
    HapticFeedback.selectionClick();
    if (widget.paused && widget.onPay != null) {
      await widget.onPay!();
      return;
    }
    opening = true;
    final next = _next;
    if (next == 'out' && !await askPunchOut(context, punches: _today, shift: _shift, nowMs: AttendKit.kit.now())) {
      opening = false;
      return;
    }
    if (!mounted) {
      opening = false;
      return;
    }
    await Navigator.of(context).push(hrRoute<void>(AttendanceScreen(quick: true, auto: true, want: next)));
    opening = false;
    if (mounted) _read();
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
    final dawn = sky == Sky.dawn, day = sky == Sky.day, done = !dawn && !day;
    final since = day ? sinceText(tin, DateTime.fromMillisecondsSinceEpoch(AttendKit.kit.now())) : '';
    final a = '${_shift['start'] ?? ''}', b = '${_shift['end'] ?? ''}';
    final shift = a.isEmpty || b.isEmpty ? '' : '$a–$b';
    final title = dawn ? const Text('Attendance', mr: 'हजेरी', key: Key('att-title'), style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _navy)) : null;
    final Widget sub;
    if (widget.paused) {
      sub = const Text('HR is paused – pay to open it', mr: 'HR बंद आहे – उघडण्यासाठी पैसे भरा', key: Key('att-sub'), style: TextStyle(fontSize: 13, color: _muted));
    } else if (dawn) {
      sub = const Text('Not marked yet today', mr: 'आज अजून हजेरी लावलेली नाही', key: Key('att-sub'), style: TextStyle(fontSize: 13, color: _muted));
    } else if (day) {
      sub = Row(key: const Key('att-sub'), children: [
        const Text('On duty', mr: 'कामावर', style: TextStyle(fontSize: 13, color: _muted)),
        if (since.isNotEmpty) Flexible(child: m.Text(' · $since', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: _muted))),
      ]);
    } else {
      sub = m.Text(['IN $tin', if (tout.isNotEmpty) 'OUT $tout'].join(' – '), key: const Key('att-sub'), style: const TextStyle(fontSize: 13, color: _muted));
    }
    return Semantics(
      container: true,
      child: Container(
        key: const Key('att-card'),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [BoxShadow(color: Color(0x240F1E3D), blurRadius: 30, offset: Offset(0, 12))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: dawn ? _goldSoft : _green, borderRadius: BorderRadius.circular(dawn ? 16 : 24)),
              child: Icon(dawn ? Icons.schedule_rounded : Icons.check_rounded, size: 26, color: dawn ? _goldInk : Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                title ??
                    (day
                        ? Row(key: const Key('att-title'), children: [
                            const Text('IN marked', mr: 'IN लागले', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _greenInk)),
                            if (tin.isNotEmpty) m.Text(' · $tin', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _greenInk)),
                          ])
                        : const Text('Attendance done', mr: 'हजेरी पूर्ण', key: Key('att-title'), style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _greenInk))),
                const SizedBox(height: 2),
                sub,
              ]),
            ),
            if (dawn && shift.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: _pill, borderRadius: BorderRadius.circular(999)),
                child: m.Text(shift, key: const Key('att-shift'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _navy)),
              ),
            ],
          ]),
          const SizedBox(height: 14),
          if (done)
            SizedBox(
              height: 48,
              child: TextButton(
                key: const Key('att-hr'),
                onPressed: widget.onHr,
                style: TextButton.styleFrom(foregroundColor: _navy, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                child: const Text('Open HR', mr: 'HR उघडा', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _navy)),
              ),
            )
          else
            SizedBox(
              height: 58,
              child: Material(
                color: dawn ? _navy : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: dawn ? BorderSide.none : const BorderSide(color: _navy, width: 2)),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  key: const Key('att-go'),
                  onTap: _mark,
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.photo_camera_outlined, size: 24, color: dawn ? _goldPale : _navy),
                    const SizedBox(width: 10),
                    dawn
                        ? const Text('Mark IN', mr: 'हजेरी लावा', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white))
                        : const Text('Mark OUT', mr: 'OUT लावा', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _navy)),
                  ]),
                ),
              ),
            ),
          if (!done) ...[
            const SizedBox(height: 12),
            m.Text.rich(
              TextSpan(children: [
                const WidgetSpan(
                    alignment: PlaceholderAlignment.middle, child: Padding(padding: EdgeInsets.only(right: 6), child: Icon(Icons.check_rounded, size: 15, color: _green))),
                TextSpan(text: tr('Selfie, location and this phone are checked by themselves')),
              ]),
              key: const Key('att-checks'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12.5, height: 1.35, color: _muted),
            ),
          ],
        ]),
      ),
    );
  }
}
