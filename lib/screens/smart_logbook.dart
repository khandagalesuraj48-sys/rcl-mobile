/* (3.132.0, Mechanical update-263) THE SMART LOG BOOK – the driver's own screens (the plan approved 15/16-11-2026; his pictures
 * "SLB 1 – Start of the day", "SLB 2 – Duty, close, handover" and "Home – Log Book only"). The same server as the web (Mechanical
 * /api/rpc, the vl… actions), the same checks and access: a person with Log Book (Edit).
 *   1. Smart Log Book – no vehicle with him: Scan the QR on the vehicle / Photo of the number plate / Pick it; a vehicle handed to him
 *      (Accept / Refuse); what the supervisor asks about; his last shift.
 *   2. Take a vehicle – the vehicle read, "In the Asset Master"; Take this vehicle (vlTake – ONE vehicle a driver, ONE driver a vehicle).
 *   3. Opening – ONE dashboard photo a day: the phone reads it (live, or the photo), the AI only when the phone is not sure; Confirm
 *      (vlOpen – a second one is not made).
 *   4. On duty – the vehicle since when, the opening, the GPS (core/vl_gps.dart), Hand over / Close the shift.
 *   5. Close the shift – the meter photo + the work said aloud (the phone hears it – and records it where the phone gives both the
 *      microphone: the voice kept 60 days, core/vl_voice.dart – the AI writes it, he corrects it) → the usual Log
 *      Book entry (saveLogRows – the same checks and approval), then vlClose (once per phone action – its number). No network: both
 *      kept on this phone and sent by themselves (as every entry).
 *   6. Hand over – the reading now (photo) and the other driver (free / busy); he accepts on his own phone. No Log Book row.
 * MyVehicleCard – Home's "My vehicle" card (the same size as the Diesel card it swipes with). */
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';      // ignore: unnecessary_import

import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/imports.dart' show findMachine;
import '../core/ocr.dart';
import '../core/ocr_read.dart';
import '../core/photo.dart';
import '../core/plate.dart';
import '../core/plate_read.dart';
import '../core/qr_scan.dart';
import '../core/scan_rules.dart';
import '../core/session.dart';
import '../core/vl_gps.dart';
import '../core/vl_voice.dart';
import '../core/voice.dart';
import '../ui/ask_bot.dart';
import '../ui/scope.dart';
import '../ui/t.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'forms.dart' show MachinePicker, dieselHistoryOf;
import 'label_scan.dart' show QrScanScreen;
import 'logbook.dart' show LogBookScreen;
import 'scan.dart';

const _purple = Color(0xFF6D2FD0), _purpleDeep = Color(0xFF5521B5), _purpleSoft = Color(0xFFEFE7FB);

/// (3.132.1, asked 17-11-2026: "apan jas tharwale tashi log book entry app madhe" – "Log Book = Smart Log Book") the site's Smart Log Book
/// is on (its step 1zo run – Home's vlMe answered); set by Home at each reading. Off: the Log Book button opens the Log Book as before.
bool slbSiteOn = false;

/// The app's "Log Book" (Home's tile, Entries, the start page): a person with Log Book – Edit (the Admin too) at a site where the Smart
/// Log Book is on → the Smart Log Book (its "Old Log Book entry" opens the Log Book as before – many machinery at once, the list, pending);
/// anybody else → the Log Book as before.
Future<void> openLogBook(BuildContext context) {
  final s = SessionScope.read(context);
  return Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => slbSiteOn && s.canEdit('Log Book') ? const SmartLogBookScreen() : const LogBookScreen()));
}

/// 'yyyy-MM-ddTHH:mm' (the site's time) → "08:01 AM"
String slbTime(Object? a) {
  final m = RegExp(r'^\d{4}-\d\d-\d\dT(\d\d):(\d\d)').firstMatch('${a ?? ''}');
  if (m == null) return '';
  final h = int.parse(m.group(1)!);
  return '${(h % 12 == 0 ? 12 : h % 12).toString().padLeft(2, '0')}:${m.group(2)} ${h < 12 ? 'AM' : 'PM'}';
}

/// How long since 'yyyy-MM-ddTHH:mm' (the site's time = India): "3 h 41 m"
String slbSince(Object? a, DateTime now) {
  final t = DateTime.tryParse('${a ?? ''}:00+05:30');
  if (t == null) return '';
  final m = math.max(0, now.toUtc().difference(t.toUtc()).inMinutes);
  return m < 60 ? '$m m' : '${m ~/ 60} h ${m % 60} m';
}

String _read(Map? o) => [if (asNum(o?['km']) != null) '${fmtNum(asNum(o?['km']))} km', if (asNum(o?['hr']) != null) '${fmtNum(asNum(o?['hr']))} hr'].join(' · ');

Map<String, dynamic>? _map(Object? v) => v is Map ? v.cast<String, dynamic>() : null;

/// The purple top of the Smart Log Book's screens (his pictures): back, a white tile with its picture, the title and a line under it.
PreferredSizeWidget slbBar(BuildContext context, String title, String sub, {String pic = 'notebook'}) => PreferredSize(
      preferredSize: const Size.fromHeight(92),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF8A4BE8), _purpleDeep]),
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(26)),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 8, 10),
            child: Row(children: [
              IconButton(key: const Key('slb-back'), tooltip: tr('Back'), onPressed: () => Navigator.maybePop(context), icon: const Icon(Icons.arrow_back_rounded, color: Colors.white)),
              Container(width: 46, height: 46, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)), alignment: Alignment.center, child: Pic(pic, size: 30)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: Colors.white)),
                  Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: Color(0xE6FFFFFF))),
                ]),
              ),
              ...withAsk(),
            ]),
          ),
        ),
      ),
    );

Widget _box(Widget child, {Key? key, Color color = Colors.white, EdgeInsets? pad}) => Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 12),
      padding: pad ?? const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20), boxShadow: color == Colors.white ? softShadow(.05) : null),
      child: child,
    );

Widget _bigBtn(String key, String en, String mr, IconData icon, VoidCallback? onTap, {Color color = C.green}) => SizedBox(
      height: 56,
      child: FilledButton(
        key: Key(key),
        style: FilledButton.styleFrom(backgroundColor: color, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)), padding: const EdgeInsets.symmetric(horizontal: 14)),
        onPressed: onTap,
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon),
          const SizedBox(width: 8),
          Flexible(child: Text(bi(en, mr), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
        ]),
      ),
    );

/// A button's icon and words in one line, never wider than its place (a long Marathi label ends with …)
Widget _iconText(IconData icon, String text, {double size = 15, FontWeight weight = FontWeight.w700}) => Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 20),
      const SizedBox(width: 6),
      Flexible(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: size, fontWeight: weight))),
    ]);

// =====================================================================================================================================
//  A READING OF THE VEHICLE: its photo (the phone reads it; the AI only when the phone is not sure) and the numbers he may correct
// =====================================================================================================================================
class _Reading extends ChangeNotifier {
  _Reading(this.m) {
    km.addListener(notifyListeners);      // (a number typed: the work of the shift beside it at once)
    hr.addListener(notifyListeners);
  }
  final Machine m;
  final km = TextEditingController(), hr = TextEditingController();
  Uint8List? jpg;
  Map<String, dynamic>? photo; // the photo kept in the store: {sha, p, mime, size} (uploadAttachment)
  String how = 'typed', ocr = '', ai = '', check = '', err = '', said = '';
  bool busy = false;
  String get unit => '${m.m['unit'] ?? ''}';
  bool get wantKm => hasKm(unit);
  bool get wantHr => hasHr(unit);
  bool get any => wantKm || wantHr;
  num? get kmV => asNum(km.text);
  num? get hrV => asNum(hr.text);
  String? missing() => wantKm && kmV == null ? 'Enter the KM reading of ${m.id}.' : wantHr && hrV == null ? 'Enter the hour meter reading (Hrs) of ${m.id}.' : null;
  Map<String, dynamic> get out => {'km': wantKm ? kmV : null, 'hr': wantHr ? hrV : null, 'photo': photo, 'ocr': ocr, 'ai': ai, 'how': how};

  @override
  void dispose() {
    km.dispose();
    hr.dispose();
    super.dispose();
  }

  void _put(num? v, String by, {bool hours = false}) {
    if (v == null) return;
    final c = hours || !wantKm ? hr : km;
    c.text = fmtNum(v).replaceAll(',', '');
    how = by;
    if (by == 'ai') {
      ai = '$v';
    } else {
      ocr = '$v';
    }
  }

  LastReading? _last(Map? h, String key) {
    final v = h?[key];
    final n = v is Map ? asNum(v['value']) : null;
    return n == null ? null : LastReading(n.toDouble(), '${v['date'] ?? ''}');
  }

  Future<void> shoot(BuildContext context, String label) async {
    if (busy) return;
    final s = SessionScope.read(context);
    busy = true;
    err = '';
    said = '';
    notifyListeners();
    try {
      final h = any ? await dieselHistoryOf(s, m.id, s.today) : null;
      final lk = _last(h, 'lastKm'), lh = _last(h, 'lastHr');
      TakenPhoto? p;
      double? live;
      var liveCheck = '';
      if (canOcr && any) {
        // the app's own camera reads the meter live and takes the photo by itself (scan.dart – as the Diesel Issue)
        if (!context.mounted) return;
        final sc = await scanPhoto(context,
            title: '${tr(label)} – ${m.id}',
            hint: tr("Keep the meter's digits inside the box."),
            unit: wantKm ? 'km' : 'hr',
            read: (lines) {
              final r = meterFrom(lines, wantKm: wantKm, wantHr: wantHr && !wantKm, lastKm: lk, lastHr: lh, today: s.today);
              return ScanRead(wantKm ? r.km : r.hr, sure: (wantKm ? lk : lh) != null, check: r.check);
            });
        if (sc == null) return;
        if (sc.failed || sc.file == null) {
          p = await cameraShot(label, m.id);
        } else {
          p = await photoFrom(sc.file!, label, m.id);
          live = sc.value;
          liveCheck = sc.check;
        }
      } else {
        p = await cameraShot(label, m.id);
      }
      if (p == null) return;
      final shot = p;
      jpg = shot.jpg;
      photo = null;
      check = liveCheck;
      notifyListeners();
      if (live != null) {
        _put(live, 'live');
        said = bi('Read on the phone', 'फोनने वाचले');
      } else if (any && canOcr) {
        try {
          final lines = await sevenOnPhoto(await ocrLines(path: shot.raw, jpg: shot.jpg), path: shot.raw, jpg: shot.jpg);
          final r = meterFrom(lines, wantKm: wantKm, wantHr: wantHr && !wantKm, lastKm: lk, lastHr: lh, today: s.today);
          final v = wantKm ? r.km : r.hr;
          if (v != null && ((wantKm ? lk : lh) != null)) {
            _put(v, 'phone');
            check = r.check;
            said = bi('Read on the phone', 'फोनने वाचले');
          }
        } catch (_) {/* the AI tries */}
      }
      notifyListeners();
      // the phone is not sure (or cannot read here): the AI – once
      if (any && (wantKm ? km.text : hr.text).trim().isEmpty) {
        try {
          final r = ((await s.api.call('getMeterReading', [{'kind': 'dash', 'data': await smallCopy(shot.jpg), 'no': m.id}])) as Map).cast<String, dynamic>();
          if (r['off'] != true) {
            if (wantKm) _put(asNum(r['km']), 'ai');
            if (wantHr && (wantKm || hr.text.trim().isEmpty)) _put(asNum(r['hr']), 'ai', hours: true);
            if ('${r['check'] ?? ''}'.isNotEmpty) check = '${r['check']}';
            if ((wantKm ? km.text : hr.text).trim().isNotEmpty) said = bi('Read by the AI – check it', 'AI ने वाचले – तपासा');
          }
        } catch (_) {/* typed by him */}
      }
      if (any && (wantKm ? km.text : hr.text).trim().isEmpty) said = bi('Not read – type the reading', 'वाचता आले नाही – रीडिंग टाका');
      notifyListeners();
      // the photo kept in the private store (the same as a Log Book entry's attachments)
      final r = ((await s.api.call('uploadAttachment', [{'data': shot.dataUrl, 'name': '${label.toLowerCase().replaceAll(' ', '_')}_${m.id}.jpg'}])) as Map).cast<String, dynamic>();
      photo = {'sha': '${r['sha'] ?? ''}', 'p': '${r['path'] ?? ''}', 'mime': '${r['mime'] ?? 'image/jpeg'}', 'size': r['size'] ?? 0};
    } catch (e) {
      err = e is PhotoProblem ? e.message : (e is ApiError && e.noConnection ? bi('No network – the photo is not sent; the reading goes without it.', 'नेटवर्क नाही – फोटो गेला नाही; रीडिंग त्याशिवाय जाईल.') : errText(e));
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}

class _ReadingView extends StatelessWidget {
  const _ReadingView({required this.rd, required this.label, required this.mr, this.note = ''});
  final _Reading rd;
  final String label, mr, note;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: rd,
        builder: (context, _) => _box(
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  key: const Key('slb-photo'),
                  width: 120,
                  height: 86,
                  color: const Color(0xFF1E2329),
                  alignment: Alignment.center,
                  child: rd.jpg == null ? const Icon(Icons.photo_camera_outlined, color: Colors.white70, size: 34) : Image.memory(rd.jpg!, width: 120, height: 86, fit: BoxFit.cover, gaplessPlayback: true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(bi(label, mr), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: C.muted)),
                  const SizedBox(height: 6),
                  OutlinedButton(
                    key: const Key('slb-shoot'),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12)),
                    onPressed: rd.busy ? null : () => rd.shoot(context, label),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      rd.busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(rd.jpg == null ? Icons.photo_camera_rounded : Icons.refresh_rounded, size: 18),
                      const SizedBox(width: 6),
                      Flexible(child: Text(rd.jpg == null ? bi('Take the photo', 'फोटो काढा') : bi('Retake', 'पुन्हा'), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ]),
                  ),
                  if (rd.said.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(rd.said, key: const Key('slb-said'), style: const TextStyle(fontSize: 12.5, color: C.purple, fontWeight: FontWeight.w600))),
                ]),
              ),
            ]),
            if (rd.wantKm || rd.wantHr) const SizedBox(height: 12),
            if (rd.wantKm)
              TextField(
                key: const Key('slb-km'),
                controller: rd.km,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                decoration: InputDecoration(labelText: tr('KM reading'), suffixText: 'km', border: const OutlineInputBorder()),
              ),
            if (rd.wantKm && rd.wantHr) const SizedBox(height: 10),
            if (rd.wantHr)
              TextField(
                key: const Key('slb-hr'),
                controller: rd.hr,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                decoration: InputDecoration(labelText: tr('Hour meter (Hrs)'), suffixText: 'hr', border: const OutlineInputBorder()),
              ),
            if (!rd.any) Text(bi('This vehicle has no meter reading – the photo is enough.', 'या गाडीला meter reading नाही – फोटो पुरेसा.'), style: const TextStyle(fontSize: 13, color: C.muted)),
            if (rd.check.isNotEmpty) InfoLine('Check: ${rd.check}', bad: true, help: false),
            if (note.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(note, key: const Key('slb-note'), style: const TextStyle(fontSize: 13, color: C.greenDark, fontWeight: FontWeight.w600))),
            if (rd.err.isNotEmpty) InfoLine(rd.err, bad: true, help: false),
          ]),
        ),
      );
}

// =====================================================================================================================================
//  1 · THE SMART LOG BOOK (the driver's own screen)
// =====================================================================================================================================
class SmartLogBookScreen extends StatefulWidget {
  const SmartLogBookScreen({super.key, this.start = ''});

  /// Home's buttons: 'qr' / 'plate' / 'pick' (take a vehicle), 'open' (the opening), 'close', 'hand' – done once it has loaded
  final String start;
  @override
  State<SmartLogBookScreen> createState() => _SmartLogBookScreenState();
}

class _SmartLogBookScreenState extends State<SmartLogBookScreen> {
  Map<String, dynamic>? me;
  String err = '';
  bool loading = true, _started = false;
  _Reading? open;
  bool opening = false;
  String openErr = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    VlGps.i.addListener(_gps);
  }

  void _gps() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    VlGps.i.removeListener(_gps);
    open?.dispose();
    super.dispose();
  }

  Map<String, dynamic>? get _sess => _map(me?['session']);

  Future<void> _load() async {
    final s = SessionScope.read(context);
    setState(() {
      loading = me == null;
      err = '';
    });
    try {
      final r = ((await s.api.call('vlMe')) as Map).cast<String, dynamic>();
      if (!mounted) return;
      final ss = _map(r['session']);
      if (ss != null) {
        unawaited(VlGps.i.start(s.api, '${ss['id']}', '${ss['no']}'));
      } else if (VlGps.i.on) {
        unawaited(VlGps.i.stop());
      }
      setState(() {
        me = r;
        loading = false;
        final m = ss == null ? null : s.machine('${ss['no']}');
        if (ss != null && r['opening'] == null && m != null && (open == null || open!.m.id != m.id)) {
          open?.dispose();
          open = _Reading(m);
        }
      });
      if (!_started && widget.start.isNotEmpty) {
        _started = true;
        await _act(widget.start);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        err = errText(e);
      });
    }
  }

  Future<void> _act(String a) async {
    final ss = _sess;
    if (ss == null) {
      if (a == 'qr') return _scanQr();
      if (a == 'plate') return _plate();
      if (a == 'pick') return _pick();
      return;
    }
    if (a == 'close' && me?['opening'] != null) return _close();
    if (a == 'hand') return _hand();
  }

  Machine? _find(String id) {
    final s = SessionScope.read(context);
    final f = findMachine([for (final m in s.machines) m.m], id);
    return f == null ? null : s.machine('${f['id']}');
  }

  Future<void> _scanQr() async {
    String? text;
    try {
      text = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const QrScanScreen()));
    } catch (_) {
      if (mounted) toast(context, 'The label could not be read on this phone.', bad: true);
      return;
    }
    if (text == null || text.isEmpty || !mounted) return;
    final id = labelMachine(text), m = id.isEmpty ? null : _find(id);
    if (m == null) {
      toast(context, id.isEmpty ? 'This QR code is not a machinery label of the ERP.' : 'The machinery of this label ($id) is not in the Master.', bad: true);
      return;
    }
    await _take(m, 'qr', '');
  }

  Future<void> _plate() async {
    String? text;
    try {
      text = await readPlatePhoto();
    } catch (_) {
      if (mounted) toast(context, 'The camera could not be opened – pick the vehicle.', bad: true);
      return;
    }
    if (text == null || !mounted) return;
    final s = SessionScope.read(context);
    final found = plateMatches(text, s.machines.where((m) => m.onSite(s.today)).toList());
    if (found.isEmpty) {
      toast(context, bi('The number on this photo is not in the Asset Master – pick the vehicle.', 'फोटोवरचा नंबर Asset Master मध्ये नाही – गाडी निवडा.'), bad: true);
      return _pick();
    }
    final m = found.length == 1 ? found.first : await showModalBottomSheet<Machine>(context: context, isScrollControlled: true, useSafeArea: true, builder: (_) => MachinePicker(date: s.today, only: found));
    if (m == null || !mounted) return;
    await _take(m, 'plate', text.split(RegExp(r'[\r\n]+')).firstWhere((l) => l.trim().isNotEmpty, orElse: () => ''));
  }

  Future<void> _pick() async {
    final s = SessionScope.read(context);
    final m = await showModalBottomSheet<Machine>(context: context, isScrollControlled: true, useSafeArea: true, builder: (_) => MachinePicker(date: s.today));
    if (m != null && mounted) await _take(m, 'pick', '');
  }

  Future<void> _take(Machine m, String how, String seen) async {
    final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => TakeVehicleScreen(m: m, how: how, seen: seen)));
    if (ok == true && mounted) await _load();
  }

  Future<void> _confirmOpening() async {
    final rd = open, ss = _sess;
    if (rd == null || ss == null || opening) return;
    final miss = rd.missing();
    if (miss != null) {
      setState(() => openErr = miss);
      return;
    }
    if (rd.jpg == null && !await ask(context, 'No photo?', bi('The opening is kept without its photo.', 'फोटोशिवाय opening ठेवायचे?'), yes: 'Keep it')) return;
    setState(() {
      opening = true;
      openErr = '';
    });
    final s = SessionScope.read(context);
    try {
      final r = ((await s.api.call('vlOpen', [{'session': '${ss['id']}', ...rd.out}])) as Map).cast<String, dynamic>();
      if (!mounted) return;
      HapticFeedback.lightImpact();
      final c = '${r['check'] ?? ''}';
      toast(context, r['already'] == true ? bi('The opening of today was already given.', 'आजचे opening आधीच दिले आहे.') : (c.isEmpty ? bi('Opening kept – on duty.', 'Opening जतन – काम सुरू.') : 'Opening kept – check: $c'), bad: c.isNotEmpty);
      await _load();
    } catch (e) {
      if (mounted) setState(() => openErr = errText(e));
    } finally {
      if (mounted) setState(() => opening = false);
    }
  }

  Future<void> _close() async {
    final ss = _sess, s = SessionScope.read(context), m = ss == null ? null : s.machine('${ss['no']}');
    if (ss == null || m == null) return;
    final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => CloseShiftScreen(m: m, session: ss, opening: _map(me?['opening']), myName: '${_map(me?['me'])?['name'] ?? s.name}')));
    if (ok == true && mounted) await _load();
  }

  Future<void> _hand() async {
    final ss = _sess, s = SessionScope.read(context), m = ss == null ? null : s.machine('${ss['no']}');
    if (ss == null || m == null) return;
    final people = [for (final p in (me?['people'] as List? ?? const [])) if (p is Map) p.cast<String, dynamic>()];
    final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => HandoverScreen(m: m, session: ss, people: people)));
    if (ok == true && mounted) await _load();
  }

  Future<void> _answer(String id, bool yes, String no, {bool back = false}) async {
    final s = SessionScope.read(context);
    if (!yes && !await ask(context, back ? 'Take $no back?' : 'Refuse $no?', back ? bi('The handover is cancelled – the vehicle stays with you.', 'Handover रद्द – गाडी तुमच्याकडेच.') : bi('The vehicle stays with the driver who gave it.', 'गाडी देणाऱ्याकडेच राहील.'), yes: back ? 'Take back' : 'Refuse')) return;
    try {
      await s.api.call('vlHandAnswer', [{'id': id, 'yes': yes}]);
      if (!mounted) return;
      toast(context, yes ? bi('$no is with you now.', '$no आता तुमच्याकडे आहे.') : (back ? bi('Taken back – $no stays with you.', 'परत घेतली – $no तुमच्याकडेच.') : bi('Refused.', 'नाकारले.')));
      await _load();
    } catch (e) {
      if (mounted) toast(context, errText(e), bad: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context), ss = _sess, op = _map(me?['opening']);
    final title = ss == null ? 'Smart Log Book' : (op == null ? 'Opening' : 'On duty');
    final sub = ss == null ? '${bi('Smart Log Book', 'स्मार्ट लॉगबुक')} · ${s.siteName}' : '${ss['no']} · ${showDate('${ss['shiftDate'] ?? s.today}')} · ${tr('${ss['shift'] ?? ''}')}';
    return Scaffold(
      backgroundColor: C.bg,
      appBar: slbBar(context, tr(title), sub),
      body: RefreshIndicator(
        color: _purple,
        onRefresh: _load,
        child: ListView(key: const Key('slb-list'), padding: const EdgeInsets.fromLTRB(Sp.edge, 16, Sp.edge, 28), children: [
          if (loading) ...const [Shimmer(height: 110), SizedBox(height: 12), Shimmer(height: 80)]
          else if (err.isNotEmpty) ...[
            InfoLine(err, bad: true),
            const SizedBox(height: 12),
            OutlinedButton(key: const Key('slb-again'), onPressed: _load, child: Text(bi('Try again', 'पुन्हा'))),
          ] else if (ss == null)
            ..._free(s)
          else if (op == null)
            ..._openView(ss)
          else
            ..._duty(s, ss, op),
          // (3.132.1) the Log Book as before: an entry of many machinery at once, the list, what is pending
          const SizedBox(height: 14),
          Center(
            child: TextButton(
              key: const Key('slb-old'),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const LogBookScreen())),
              child: _iconText(Icons.list_alt_rounded, bi('Old Log Book entry (many machinery, the list)', 'जुनी Log Book नोंद (अनेक गाड्या, यादी)'), size: 14),
            ),
          ),
        ]),
      ),
    );
  }

  // ---- 1. no vehicle with him
  List<Widget> _free(Session s) {
    final first = s.name.split(' ').first, inn = [for (final x in (me?['handoverIn'] as List? ?? const [])) if (x is Map) x], asks = [for (final x in (me?['asks'] as List? ?? const [])) if (x is Map) x];
    final last = _map(me?['last']), h = s.clock().hour;
    return [
      _box(
        key: const Key('slb-hello'),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${h < 12 ? 'Good morning' : h < 17 ? 'Good afternoon' : 'Good evening'}, $first', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          Text(bi('No vehicle with you now', 'आज तुमच्याकडे अजून गाडी नाही'), style: const TextStyle(fontSize: 13.5, color: C.muted)),
          const SizedBox(height: 8),
          const Pill('No vehicle with you now', color: C.amber, bg: C.amberSoft),
        ]),
      ),
      for (final x in inn)
        _box(
          key: Key('slb-in-${x['id']}'),
          color: _purpleSoft,
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(bi('${x['from']} hands ${x['no']} over to you', '${x['from']} तुम्हाला ${x['no']} देत आहेत'), style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
            if (_read(x).isNotEmpty) Text('${bi('Reading', 'रीडिंग')} ${_read(x)} · ${slbTime(x['at'])}', style: const TextStyle(fontSize: 13, color: C.muted)),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: FilledButton(key: Key('slb-accept-${x['id']}'), style: FilledButton.styleFrom(backgroundColor: C.green, minimumSize: const Size(0, 46)), onPressed: () => _answer('${x['id']}', true, '${x['no']}'), child: Text(bi('Accept', 'स्वीकारा')))),
              const SizedBox(width: 10),
              Expanded(child: OutlinedButton(key: Key('slb-refuse-${x['id']}'), style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46)), onPressed: () => _answer('${x['id']}', false, '${x['no']}'), child: Text(bi('Refuse', 'नाकारा')))),
            ]),
          ]),
        ),
      _choice('slb-qr', 'Scan the QR on the vehicle', 'गाडीवरचा QR scan करा', Icons.qr_code_scanner_rounded, const [Color(0xFF2F9A66), Color(0xFF1E6B47)], _scanQr),
      _choice('slb-plate', 'Photo of the number plate', 'नंबर प्लेटचा फोटो काढा', Icons.photo_camera_rounded, const [Color(0xFF2F6FD6), Color(0xFF1E4FA8)], _plate),
      Align(
        alignment: Alignment.center,
        child: TextButton(key: const Key('slb-pick'), onPressed: _pick, child: _iconText(Icons.list_rounded, bi('Pick it from the list', 'यादीतून निवडा'), size: 14)),
      ),
      _box(
        color: C.blueSoft,
        Text(bi('The vehicle you take stays with you until you close the shift or hand it over.', 'गाडी तुम्ही shift बंद करेपर्यंत किंवा दुसऱ्याला देईपर्यंत तुमच्याकडे राहते.'), style: const TextStyle(fontSize: 13.5, color: C.blue, height: 1.35)),
      ),
      if (asks.isNotEmpty) ...[
        Padding(padding: const EdgeInsets.fromLTRB(2, 4, 0, 8), child: TwoLang('Asked about', 'विचारले आहे', size: 16, weight: FontWeight.w800)),
        for (final a in asks)
          _box(
            key: Key('slb-ask-${a['id']}'),
            color: C.amberSoft,
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${a['date'] == null || '${a['date']}'.isEmpty ? '' : '${showDate('${a['date']}')} '}${tr('${a['shift'] ?? ''}')} – ${a['kind']} · ${a['no']}', style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
              if ('${a['note'] ?? ''}'.isNotEmpty) Text('${a['note']}', style: const TextStyle(fontSize: 13, color: C.muted)),
              Text(bi('Tell your supervisor – he puts it right.', 'तुमच्या supervisor ला सांगा – तो दुरुस्त करेल.'), style: const TextStyle(fontSize: 12.5, color: C.amber, fontWeight: FontWeight.w600)),
            ]),
          ),
      ],
      if (last != null)
        _box(
          key: const Key('slb-last'),
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(bi('Your last shift', 'मागची shift'), style: const TextStyle(fontSize: 13, color: C.muted, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Row(children: [
              Expanded(child: Text('${showDate('${last['date'] ?? ''}')} · ${tr('${last['shift'] ?? ''}')}', style: const TextStyle(fontSize: 14))),
              Text('${last['no']}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
            ]),
            if ('${last['text'] ?? ''}'.isNotEmpty) Text('${last['text']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: C.muted)),
          ]),
        ),
    ];
  }

  Widget _choice(String key, String en, String mr, IconData icon, List<Color> g, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: Key(key),
            borderRadius: BorderRadius.circular(22),
            onTap: () {
              HapticFeedback.selectionClick();
              onTap();
            },
            child: Ink(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
              decoration: BoxDecoration(gradient: LinearGradient(colors: g), borderRadius: BorderRadius.circular(22)),
              child: Row(children: [
                Container(width: 52, height: 52, decoration: BoxDecoration(color: Colors.white.withValues(alpha: .18), borderRadius: BorderRadius.circular(16)), child: Icon(icon, color: Colors.white, size: 30)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(en, style: const TextStyle(fontSize: 17.5, fontWeight: FontWeight.w800, color: Colors.white)),
                    Text(mr, style: const TextStyle(fontSize: 13, color: Color(0xE6FFFFFF))),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      );

  // ---- 3. the opening of today
  List<Widget> _openView(Map<String, dynamic> ss) {
    final rd = open;
    return [
      _steps(1),
      if (rd == null) InfoLine('${ss['no']} is not in the Asset Master of this phone – pull down to read it again.', bad: true)
      else ...[
        _ReadingView(rd: rd, label: 'Opening', mr: 'सुरुवातीचे रीडिंग'),
        Text(bi('One photo a day: the phone reads it first; the AI only when the phone is not sure.', 'दिवसात एकच फोटो: आधी फोन वाचतो; खात्री नसेल तरच AI.'), style: const TextStyle(fontSize: 12.5, color: C.muted)),
        if (openErr.isNotEmpty) InfoLine(openErr, bad: true),
        const SizedBox(height: 16),
        _bigBtn('slb-confirm', 'Confirm the opening', 'Opening नक्की करा', Icons.check_rounded, opening ? null : _confirmOpening),
      ],
      const SizedBox(height: 10),
      Center(child: TextButton(key: const Key('slb-hand0'), onPressed: _hand, child: _iconText(Icons.swap_horiz_rounded, bi('Hand over to another driver', 'दुसऱ्याला द्या'), size: 14))),
    ];
  }

  Widget _steps(int at) {
    const st = [('Vehicle', 'गाडी'), ('Opening', 'सुरुवात'), ('On duty', 'काम'), ('Closing', 'बंद')];
    return _box(
      key: const Key('slb-steps'),
      Row(children: [
        for (final (i, x) in st.indexed)
          Expanded(
            child: Column(children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(shape: BoxShape.circle, color: i < at ? C.green : (i == at ? Colors.white : C.slateSoft), border: Border.all(color: i == at ? _purple : Colors.transparent, width: 2)),
                alignment: Alignment.center,
                child: i < at ? const Icon(Icons.check_rounded, color: Colors.white, size: 18) : Text('${i + 1}', style: TextStyle(fontWeight: FontWeight.w800, color: i == at ? _purple : C.faint)),
              ),
              const SizedBox(height: 4),
              Text(x.$1, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: i < at ? C.greenDark : (i == at ? _purple : C.faint))),
              Text(x.$2, style: const TextStyle(fontSize: 11, color: C.muted)),
            ]),
          ),
      ]),
    );
  }

  // ---- 4. on duty
  List<Widget> _duty(Session s, Map<String, dynamic> ss, Map<String, dynamic> op) {
    final g = _map(ss['gps']) ?? const {}, out = [for (final x in (me?['handoverOut'] as List? ?? const [])) if (x is Map) x];
    final gs = VlGps.i.state, live = VlGps.i.session == '${ss['id']}' && gs == 'on';
    final gpsKm = asNum(g['km']) ?? 0;
    final sent = VlGps.i.sentAt;
    return [
      Container(
        key: const Key('slb-ongoing'),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: BoxDecoration(color: const Color(0xFF26282C), borderRadius: BorderRadius.circular(16)),
        child: Text('📍 ${bi('Sketchline – on duty with ${ss['no']} · location shared', 'Sketchline – ${ss['no']} सोबत काम सुरू · location दिले जाते')}', style: const TextStyle(fontSize: 13, color: Colors.white)),
      ),
      _box(
        key: const Key('slb-duty'),
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Container(width: 56, height: 56, decoration: BoxDecoration(color: C.blueSoft, borderRadius: BorderRadius.circular(16)), alignment: Alignment.center, child: const Pic('delivery_truck', size: 38)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${ss['no']}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                Text('${bi('With you since', 'तुमच्याकडे')} ${slbTime(ss['since'])} · ${slbSince(ss['since'], s.clock())}', style: const TextStyle(fontSize: 13.5, color: C.muted)),
              ]),
            ),
          ]),
          const Divider(height: 22),
          _kv(bi('Opening', 'सुरुवात'), _read(op)),
          _kv(bi('GPS so far', 'GPS आतापर्यंत'), '${fmtNum(gpsKm)} km'),
          const SizedBox(height: 4),
          Row(children: [
            Icon(Icons.circle, size: 12, color: live ? C.green : C.red),
            const SizedBox(width: 6),
            Flexible(
              child: Text(live ? bi('GPS on – live', 'GPS चालू') : gs == 'no-permission' ? bi('Location not allowed – allow it', 'Location ची परवानगी द्या') : bi('GPS off – switch it on', 'GPS बंद – चालू करा'),
                  key: const Key('slb-gps'), maxLines: 2, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: live ? C.greenDark : C.red)),
            ),
            if (sent != null) Flexible(child: Text('  · ${bi('sent', 'पाठवले')} ${slbSince(_isoLocal(sent), s.clock())} ${bi('ago', 'आधी')}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: C.muted))),
          ]),
        ]),
      ),
      for (final x in out)
        _box(
          key: Key('slb-out-${x['id']}'),
          color: C.amberSoft,
          Row(children: [
            Expanded(child: Text(bi('Waiting for ${x['to']} to accept ${x['no']}', '${x['to']} ने ${x['no']} स्वीकारायची वाट'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
            TextButton(key: Key('slb-back-${x['id']}'), onPressed: () => _answer('${x['id']}', false, '${x['no']}', back: true), child: Text(bi('Take back', 'परत घ्या'))),
          ]),
        ),
      const SizedBox(height: 8),
      SizedBox(
        height: 54,
        child: OutlinedButton(
          key: const Key('slb-hand'),
          style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)), backgroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12)),
          onPressed: _hand,
          child: _iconText(Icons.swap_horiz_rounded, bi('Hand over to another driver', 'दुसऱ्याला द्या'), size: 15.5),
        ),
      ),
      const SizedBox(height: 12),
      _bigBtn('slb-close', 'Close the shift', 'shift बंद करा', Icons.stop_rounded, _close),
    ];
  }
}

String _isoLocal(DateTime t) {
  final x = t.toUtc().add(const Duration(hours: 5, minutes: 30));
  String two(int v) => v.toString().padLeft(2, '0');
  return '${x.year}-${two(x.month)}-${two(x.day)}T${two(x.hour)}:${two(x.minute)}';
}

Widget _kv(String k, String v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Expanded(child: Text(k, style: const TextStyle(fontSize: 14, color: C.muted))),
        Text(v.isEmpty ? '–' : v, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
      ]),
    );

// =====================================================================================================================================
//  2 · TAKE A VEHICLE
// =====================================================================================================================================
class TakeVehicleScreen extends StatefulWidget {
  const TakeVehicleScreen({super.key, required this.m, required this.how, this.seen = ''});
  final Machine m;
  final String how, seen;
  @override
  State<TakeVehicleScreen> createState() => _TakeVehicleScreenState();
}

class _TakeVehicleScreenState extends State<TakeVehicleScreen> {
  bool busy = false;
  String err = '';

  Future<void> _go() async {
    final s = SessionScope.read(context);
    setState(() {
      busy = true;
      err = '';
    });
    try {
      final r = ((await s.api.call('vlTake', [{'no': widget.m.id, 'how': widget.how}])) as Map).cast<String, dynamic>();
      final ss = _map(r['session']);
      if (ss != null) unawaited(VlGps.i.start(s.api, '${ss['id']}', '${ss['no']}'));
      if (!mounted) return;
      HapticFeedback.lightImpact();
      toast(context, bi('${widget.m.id} is with you – now its opening photo.', '${widget.m.id} तुमच्याकडे – आता opening फोटो.'));
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          err = errText(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.m, s = SessionScope.of(context), on = m.onSite(s.today);
    final sub = [m.type, if (m.ownership.isNotEmpty) m.ownership, if ('${m.m['unit'] ?? ''}'.isNotEmpty) 'measured by ${m.m['unit']}'].where((x) => x.isNotEmpty).join(' · ');
    return Scaffold(
      backgroundColor: C.bg,
      appBar: slbBar(context, tr('Take a vehicle'), bi('Take a vehicle', 'गाडी घ्या'), pic: 'delivery_truck'),
      body: ListView(padding: const EdgeInsets.fromLTRB(Sp.edge, 16, Sp.edge, 28), children: [
        if (widget.seen.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 16),
            decoration: BoxDecoration(color: const Color(0xFF26282C), borderRadius: BorderRadius.circular(22)),
            alignment: Alignment.center,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF4ADE80), width: 3)),
              child: Text(widget.seen, key: const Key('take-seen'), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
            ),
          ),
        _box(
          key: const Key('take-card'),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.how == 'qr' ? bi('Read on the QR label', 'QR label वर वाचले') : widget.how == 'plate' ? bi('Read on the plate', 'प्लेटवर वाचले') : bi('Picked', 'निवडले'), style: const TextStyle(fontSize: 13, color: C.muted, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(children: [
              Container(width: 60, height: 60, decoration: BoxDecoration(color: C.blueSoft, borderRadius: BorderRadius.circular(16)), alignment: Alignment.center, child: const Pic('delivery_truck', size: 40)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(m.id, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800)),
                  if (sub.isNotEmpty) Text(sub, style: const TextStyle(fontSize: 13.5, color: C.muted)),
                ]),
              ),
            ]),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 6, children: [
              const Pill('In the Asset Master', icon: Icons.check_rounded),
              if (!on) const Pill('Not on this site today', color: C.red, bg: C.redSoft, icon: Icons.close_rounded),
            ]),
          ]),
        ),
        Center(child: TextButton(key: const Key('take-other'), onPressed: () => Navigator.pop(context, false), child: Text(bi('Not this vehicle? Change it', 'ही गाडी नाही? बदला'), maxLines: 2, textAlign: TextAlign.center))),
        if (err.isNotEmpty) InfoLine(err, bad: true),
        const SizedBox(height: 16),
        _bigBtn('take-go', 'Take this vehicle', 'गाडी घ्या', Icons.check_rounded, busy || !on ? null : _go),
      ]),
    );
  }
}

// =====================================================================================================================================
//  5 · CLOSE THE SHIFT – the meter photo, the work said aloud → the Log Book entry, then the vehicle leaves him
// =====================================================================================================================================
class CloseShiftScreen extends StatefulWidget {
  const CloseShiftScreen({super.key, required this.m, required this.session, this.opening, this.myName = ''});
  final Machine m;
  final Map<String, dynamic> session;
  final Map<String, dynamic>? opening;
  final String myName;
  @override
  State<CloseShiftScreen> createState() => _CloseShiftScreenState();
}

class _CloseShiftScreenState extends State<CloseShiftScreen> {
  late final _Reading rd = _Reading(widget.m)..addListener(_changed);
  final heard = TextEditingController(), text = TextEditingController(), work = TextEditingController(), trips = TextEditingController(), chFrom = TextEditingController(), chTo = TextEditingController();
  Map<String, dynamic>? pre;
  String err = '', aiText = '';
  bool busy = false, listening = false, writing = false;
  /// (his answer "दोन्ही एकत्र") the voice recorded while the phone listened – sent with the closing (core/vl_voice.dart)
  Uint8List? voice;
  final String opId = 'VC-${DateTime.now().microsecondsSinceEpoch}-${math.Random().nextInt(1 << 30)}';

  String get shiftDate => '${widget.session['shiftDate'] ?? ''}'.isEmpty ? SessionScope.read(context).today : '${widget.session['shiftDate']}';
  String get shift => '${widget.session['shift'] ?? ''}'.isEmpty ? 'Full Day' : '${widget.session['shift']}';

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prefill());
  }

  @override
  void dispose() {
    rd.removeListener(_changed);
    rd.dispose();
    for (final c in [heard, text, work, trips, chFrom, chTo]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _prefill() async {
    final s = SessionScope.read(context);
    try {
      final r = ((await s.api.call('getLogRowPrefill', [widget.m.id, shiftDate, shift, {'add': 1}])) as Map).cast<String, dynamic>();
      if (mounted) setState(() => pre = r);
    } catch (_) {/* the opening of the day is used */}
  }

  String get way => widget.m.logWay('${pre?['lastMode'] ?? ''}');

  /// The Start of this shift: the day's opening (the first shift of the day), else the Log Book's (the shift before it)
  num? _start(bool hours) {
    final op = widget.opening;
    final first = op != null && '${op['date'] ?? ''}' == shiftDate && shift != 'Night';
    final v = (op != null && first) ? asNum(op[hours ? 'hr' : 'km']) : null;
    return v ?? asNum(pre?[hours ? 'openingHr' : 'openingKm']) ?? asNum(op?[hours ? 'hr' : 'km']);
  }

  String get _work {
    final k = rd.wantKm && rd.kmV != null && _start(false) != null ? rd.kmV! - _start(false)! : null;
    final h = rd.wantHr && rd.hrV != null && _start(true) != null ? rd.hrV! - _start(true)! : null;
    return [if (k != null) '${fmtNum(k)} km', if (h != null) '${fmtNum(h)} hr'].join(' · ');
  }

  bool get _bad {
    final k = rd.wantKm && rd.kmV != null && _start(false) != null && rd.kmV! < _start(false)!;
    final h = rd.wantHr && rd.hrV != null && _start(true) != null && rd.hrV! < _start(true)!;
    return k || h;
  }

  Future<void> _listen() async {
    if (listening) {
      await stopListening();
      return;
    }
    setState(() => listening = true);
    final keep = SessionScope.read(context).api.keep, rec = await VlVoice.i.allowed(keep);
    if (rec) await VlVoice.i.start();      // (the same words recorded while the phone listens – where the phone gives both the microphone)
    try {
      final lang = const ['mr', 'hi', 'en'].contains(Lang.i.code) ? Lang.i.code : 'mr';
      final w = await listenOnce(lang, (x) {
        if (mounted) setState(() => heard.text = x);
      });
      final v = rec ? await VlVoice.i.stop() : null;
      if (v != null) voice = v;
      if (!mounted) return;
      if (w.trim().isNotEmpty) {
        heard.text = w.trim();
        await _write();
      } else if (v != null && heard.text.trim().isEmpty) {
        // this phone gave the microphone only to the recording: the voice is kept; from now on it only listens
        await VlVoice.i.notBoth(keep);
        if (mounted) toast(context, bi('Nothing was heard – press the mic again and say the work, or type it.', 'काहीच ऐकू आले नाही – mic पुन्हा दाबा आणि काम सांगा, किंवा टाइप करा.'));
      }
    } catch (e) {
      if (rec) await VlVoice.i.stop();
      if (mounted) toast(context, bi('The phone could not listen – type the work.', 'फोन ऐकू शकला नाही – काम टाइप करा.'), bad: true);
    } finally {
      if (mounted) setState(() => listening = false);
    }
  }

  Future<void> _write() async {
    final said = heard.text.trim();
    if (said.isEmpty || writing) return;
    final s = SessionScope.read(context);
    setState(() => writing = true);
    try {
      final r = ((await s.api.call('vlAiText', [{'heard': said}])) as Map).cast<String, dynamic>();
      if (!mounted) return;
      if (r['off'] == true) {
        if (text.text.trim().isEmpty) text.text = said;
        return;
      }
      setState(() {
        aiText = '${r['text'] ?? ''}';
        text.text = aiText.isEmpty ? said : aiText;
        if ('${r['work'] ?? ''}'.isNotEmpty) work.text = '${r['work']}';
        if (asNum(r['trips']) != null) trips.text = fmtNum(asNum(r['trips']));
        final ch = '${r['chainage'] ?? ''}'.split(RegExp(r'\s+(?:to|–|-)\s+'));
        if (ch.length == 2) {
          chFrom.text = ch[0].trim();
          chTo.text = ch[1].trim();
        }
      });
    } catch (e) {
      if (mounted && text.text.trim().isEmpty) text.text = said;
    } finally {
      if (mounted) setState(() => writing = false);
    }
  }

  Future<void> _save() async {
    final s = SessionScope.read(context), m = widget.m;
    final miss = rd.missing();
    if (miss != null) {
      setState(() => err = miss);
      return;
    }
    if (rd.busy) {
      setState(() => err = bi('The photo is still being read – wait a moment.', 'फोटो वाचला जात आहे – थांबा.'));
      return;
    }
    if (_bad && !await ask(context, 'Less than the start?', bi('The closing reading is less than the start of this shift (${_read({'km': _start(false), 'hr': _start(true)})}). Save it anyway?', 'Closing reading सुरुवातीपेक्षा कमी आहे. तरी save करायचे?'), yes: 'Save anyway')) return;
    if (!mounted) return;
    setState(() {
      busy = true;
      err = '';
    });
    final w = way, logOk = const ['KM', 'Hrs', 'KM + Hrs', 'Trip'].contains(w);
    final row = <String, dynamic>{
      'date': shiftDate, 'shift': shift, 'no': m.id, 'mode': w,
      'openingKm': hasKm(w) ? (_start(false) ?? '') : '', 'closingKm': hasKm(w) ? (rd.kmV ?? '') : '',
      'openingHr': hasHr(w) ? (_start(true) ?? '') : '', 'closingHr': hasHr(w) ? (rd.hrV ?? '') : '',
      'trip': w == 'Trip' ? (asNum(trips.text) ?? '') : '',
      'chFrom': chFrom.text.trim(), 'chTo': chTo.text.trim(),
      'work': (work.text.trim().isNotEmpty ? work.text.trim() : text.text.trim()),
      'remark': text.text.trim(),
      'driver': widget.myName,
      if (rd.photo != null && '${rd.photo!['sha']}'.isNotEmpty) 'attachments': [{'sha': rd.photo!['sha']}],
    };
    var logRow = '', kept = false;
    try {
      if (logOk) {
        try {
          final res = ((await s.api.call('saveLogRows', [{'rows': [row]}], true)) as Map).cast<String, dynamic>();
          if (res['ok'] == false) {
            final errs = (res['errors'] as List? ?? []).whereType<Map>().map((x) => '${x['msg'] ?? ''}'.replaceFirst(RegExp(r'^Error:\s*'), '')).where((x) => x.isNotEmpty).toList();
            if (mounted) {
              setState(() {
                busy = false;
                err = 'Nothing saved – ${errs.isEmpty ? 'check the entry' : errs.join('\n')}';
              });
            }
            return;
          }
          logRow = '${m.id}|$shiftDate|$shift';
        } catch (e) {
          if (isSent(e)) {
            logRow = 'sent for approval';
          } else if (mounted && e is ApiError && await offerKeep(context, e)) {
            await s.keepEntry('saveLogRows', [{'rows': [row]}], e.rid, '${tr('Log Book')} · ${showDate(shiftDate)} · ${m.id} · ${tr(shift)}');
            logRow = 'kept on the phone';
            kept = true;
          } else {
            rethrow;
          }
        }
      }
      // the voice (kept 60 days): sent first – no network or a refusal: the closing goes without it (the words are kept)
      Map<String, dynamic>? audio;
      if (voice != null && !kept) {
        try {
          final r = await s.api.call('vlVoice', [{'data': 'data:audio/mp4;base64,${base64Encode(voice!)}'}]);
          if (r is Map && '${r['p'] ?? ''}'.isNotEmpty) audio = r.cast<String, dynamic>();
        } catch (_) {}
      }
      final x = <String, dynamic>{
        'session': '${widget.session['id']}', 'opId': opId, ...rd.out, 'heard': heard.text.trim(), 'aiText': aiText, 'text': text.text.trim(),
        if (audio != null) 'audio': audio,
        'trips': asNum(trips.text), 'chainage': [chFrom.text.trim(), chTo.text.trim()].where((v) => v.isNotEmpty).join(' to '), 'work': work.text.trim(),
        'logRow': logRow, 'date': shiftDate, 'shift': shift,
      };
      try {
        await s.api.call('vlClose', [x], true);
      } on ApiError catch (e) {
        if (!(e.noConnection && e.rid.isNotEmpty)) rethrow;
        await s.keepEntry('vlClose', [x], e.rid, '${bi('Smart Log Book closing', 'Smart Log Book – shift बंद')} · ${m.id}');
        kept = true;
      }
      await VlGps.i.stop();
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      toast(context, kept ? Api.keptMsg : (logOk ? bi('Shift closed – the Log Book entry is saved.', 'Shift बंद – Log Book नोंद जतन झाली.') : bi('Shift closed. This vehicle\'s Log Book is not by KM / Hrs / Trip – make its entry in Log Book.', 'Shift बंद. या गाडीची Log Book नोंद Log Book मध्ये करा.')));
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          err = errText(e);
        });
      }
    }
  }

  Widget _field(String key, TextEditingController c, String label, {int lines = 1, TextInputType? kb}) => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: TextField(key: Key(key), controller: c, minLines: lines, maxLines: lines == 1 ? 1 : lines + 2, keyboardType: kb, decoration: InputDecoration(labelText: tr(label), border: const OutlineInputBorder(), isDense: true)),
      );

  @override
  Widget build(BuildContext context) {
    final m = widget.m, wk = _work;
    return Scaffold(
      backgroundColor: C.bg,
      appBar: slbBar(context, tr('Close the shift'), 'Closing · ${m.id} · ${tr(shift)}'),
      body: ListView(key: const Key('close-list'), padding: const EdgeInsets.fromLTRB(Sp.edge, 16, Sp.edge, 28), children: [
        _ReadingView(rd: rd, label: 'Closing', mr: 'बंद रीडिंग', note: wk.isEmpty ? '' : '${bi('Work', 'काम')} $wk${_bad ? '' : ' ✓'}'),
        Text(bi("Tell today's work", 'आजचे काम सांगा'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Row(children: [
          GestureDetector(
            key: const Key('close-mic'),
            onTap: _listen,
            child: Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: listening ? const [Color(0xFFEF4444), Color(0xFFB91C1C)] : const [Color(0xFFF97316), Color(0xFFDC2626)]), boxShadow: [BoxShadow(color: const Color(0xFFDC2626).withValues(alpha: .3), blurRadius: listening ? 18 : 8, spreadRadius: listening ? 4 : 0)]),
              child: Icon(listening ? Icons.stop_rounded : Icons.mic_rounded, color: Colors.white, size: 36),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(child: Text(listening ? bi('Listening… say the work, the trips, the chainage', 'ऐकत आहे… काम, trips, chainage सांगा') : bi('Press and say the work (Marathi, Hindi or English)', 'दाबा आणि काम सांगा (मराठी, हिंदी किंवा इंग्रजी)'), style: const TextStyle(fontSize: 13.5, color: C.muted))),
        ]),
        _field('close-heard', heard, 'Heard', lines: 2),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(key: const Key('close-ai'), onPressed: writing ? null : _write, child: _iconText(writing ? Icons.hourglass_top_rounded : Icons.auto_awesome_rounded, bi('Write it with AI', 'AI ने लिहा'), size: 14)),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          decoration: BoxDecoration(color: _purpleSoft, borderRadius: BorderRadius.circular(18)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _field('close-text', text, 'Written by the AI – change it if needed', lines: 2),
            _field('close-work', work, 'Work'),
            // the trips alone, the two chainages side by side – each wide enough for "12+400"
            _field('close-trips', trips, 'Trips', kb: TextInputType.number),
            Row(children: [
              Expanded(child: _field('close-chfrom', chFrom, 'Chainage from')),
              const SizedBox(width: 8),
              Expanded(child: _field('close-chto', chTo, 'Chainage to')),
            ]),
          ]),
        ),
        if (!const ['KM', 'Hrs', 'KM + Hrs', 'Trip'].contains(way) && pre != null)
          InfoLine(bi('This vehicle\'s Log Book is by $way – after closing, make its entry in Log Book.', 'या गाडीची Log Book $way ने आहे – closing नंतर Log Book मध्ये नोंद करा.'), help: false),
        if (err.isNotEmpty) InfoLine(err, bad: true),
        const SizedBox(height: 16),
        _bigBtn('close-save', 'Save closing – Log Book', 'सेव्ह', Icons.check_rounded, busy ? null : _save),
      ]),
    );
  }
}

// =====================================================================================================================================
//  6 · HAND OVER – the reading now and the other driver; he accepts on his own phone
// =====================================================================================================================================
class HandoverScreen extends StatefulWidget {
  const HandoverScreen({super.key, required this.m, required this.session, required this.people});
  final Machine m;
  final Map<String, dynamic> session;
  final List<Map<String, dynamic>> people;
  @override
  State<HandoverScreen> createState() => _HandoverScreenState();
}

class _HandoverScreenState extends State<HandoverScreen> {
  late final _Reading rd = _Reading(widget.m);
  String to = '', err = '';
  bool busy = false;
  final String opId = 'VH-${DateTime.now().microsecondsSinceEpoch}-${math.Random().nextInt(1 << 30)}';

  @override
  void dispose() {
    rd.dispose();
    super.dispose();
  }

  Future<void> _go() async {
    final s = SessionScope.read(context);
    final miss = rd.missing();
    if (miss != null || to.isEmpty) {
      setState(() => err = miss ?? bi('Pick the driver.', 'driver निवडा.'));
      return;
    }
    setState(() {
      busy = true;
      err = '';
    });
    try {
      await s.api.call('vlHandover', [{'session': '${widget.session['id']}', 'opId': opId, 'to': to, ...rd.out}]);
      if (!mounted) return;
      final p = widget.people.firstWhere((x) => x['email'] == to, orElse: () => const {});
      toast(context, bi('Sent to ${p['name'] ?? to} – the vehicle is his when he accepts.', '${p['name'] ?? to} ला पाठवले – त्याने स्वीकारल्यावर गाडी त्याची.'));
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          err = errText(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.m, pick = widget.people.firstWhere((x) => x['email'] == to, orElse: () => const {});
    return Scaffold(
      backgroundColor: C.bg,
      appBar: slbBar(context, tr('Hand over'), '${bi('Hand over', 'गाडी सोपवा')} · ${m.id}', pic: 'left-right_arrow'),
      body: ListView(key: const Key('hand-list'), padding: const EdgeInsets.fromLTRB(Sp.edge, 16, Sp.edge, 28), children: [
        _ReadingView(rd: rd, label: 'Reading now', mr: 'आत्ताचे रीडिंग'),
        Text(bi('To which driver', 'कोणाला'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        if (widget.people.isEmpty) Text(bi('No other driver on this site has Log Book (Edit).', 'या site वर दुसऱ्या कोणाला Log Book (Edit) नाही.'), style: const TextStyle(color: C.muted)),
        for (final p in widget.people)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Press(
              key: Key('hand-to-${p['email']}'),
              onTap: '${p['has'] ?? ''}'.isNotEmpty ? null : () => setState(() => to = '${p['email']}'),
              radius: 18,
              border: to == p['email'] ? C.green : null,
              color: to == p['email'] ? const Color(0xFFF1FBF5) : Colors.white,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Row(children: [
                CircleAvatar(backgroundColor: _purpleSoft, child: Text('${p['name']}'.isEmpty ? '?' : '${p['name']}'.substring(0, 1).toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w800, color: _purple))),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${p['name']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    Text('${p['has'] ?? ''}'.isEmpty ? bi('Free now', 'आत्ता मोकळा') : '${bi('Has', 'कडे')} ${p['has']}', style: const TextStyle(fontSize: 13, color: C.muted)),
                  ]),
                ),
                if ('${p['has'] ?? ''}'.isNotEmpty) const Pill('busy', color: C.amber, bg: C.amberSoft) else if (to == p['email']) const Icon(Icons.check_circle_rounded, color: C.green),
              ]),
            ),
          ),
        _box(
          color: C.amberSoft,
          Text(bi('${pick['name'] ?? 'He'} accepts on his own phone – then the vehicle is his. No Log Book row now: the shift is closed by whoever has it at the end.', 'तो स्वतःच्या फोनवर स्वीकारतो – मग गाडी त्याची. आत्ता Log Book नोंद नाही.'), style: const TextStyle(fontSize: 13.5, color: C.amber, height: 1.35)),
        ),
        if (err.isNotEmpty) InfoLine(err, bad: true),
        const SizedBox(height: 12),
        _bigBtn('hand-go', to.isEmpty ? 'Hand over' : 'Hand over to ${pick['name'] ?? ''}', 'सोपवा', Icons.swap_horiz_rounded, busy ? null : _go, color: C.blue),
      ]),
    );
  }
}

// =====================================================================================================================================
//  HOME: "My vehicle" – the same size as the Diesel card it swipes with
// =====================================================================================================================================
class MyVehicleCard extends StatelessWidget {
  const MyVehicleCard({super.key, required this.me, required this.onDone, this.height});
  final Map<String, dynamic> me;
  final VoidCallback onDone;
  final double? height;

  Future<void> _go(BuildContext context, String start) async {
    HapticFeedback.selectionClick();
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SmartLogBookScreen(start: start)));
    onDone();
  }

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context), ss = _map(me['session']), op = _map(me['opening']), inn = (me['handoverIn'] as List? ?? const []).length;
    final m = ss == null ? null : s.machine('${ss['no']}');
    final g = _map(ss?['gps']) ?? const {};
    final live = VlGps.i.on && VlGps.i.state == 'on';
    Widget btn(String key, String en, String mr, IconData ic, String start, bool white) => Expanded(
          child: Material(
            color: white ? Colors.white : Colors.white.withValues(alpha: .16),
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              key: Key(key),
              borderRadius: BorderRadius.circular(18),
              onTap: () => _go(context, start),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(ic, size: 18, color: white ? _purple : Colors.white),
                    const SizedBox(width: 4),
                    Flexible(child: Text(en, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: white ? _purpleDeep : Colors.white))),
                  ]),
                  Text(mr, maxLines: 1, style: TextStyle(fontSize: 11.5, color: white ? _purple : const Color(0xE6FFFFFF))),
                ]),
              ),
            ),
          ),
        );
    return Container(
      key: const Key('home-myveh'),
      height: height,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF8A4BE8), _purpleDeep]),
        boxShadow: [BoxShadow(color: _purple.withValues(alpha: .3), blurRadius: 22, offset: const Offset(0, 10))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        InkWell(
          key: const Key('home-myveh-go'),
          onTap: () => _go(context, ''),
          child: Row(children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: .12), border: Border.all(color: Colors.white.withValues(alpha: .45), width: 1.5)),
              alignment: Alignment.center,
              child: const Pic('delivery_truck', size: 34),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(ss == null ? bi('My vehicle', 'माझी गाडी') : '${bi('My vehicle', 'माझी गाडी')} · ${tr(op == null ? 'Opening' : 'On duty')}', style: const TextStyle(fontSize: 13.5, color: Color(0xE6FFFFFF), fontWeight: FontWeight.w600)),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(ss == null ? tr('No vehicle yet') : '${ss['no']}', key: const Key('home-myveh-no'), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white, height: 1.15)),
                ),
                Text(
                    ss == null
                        ? (inn > 0 ? bi('A vehicle is handed to you – accept it', 'तुम्हाला गाडी दिली आहे – स्वीकारा') : bi('No vehicle taken today', 'आज अजून गाडी घेतली नाही'))
                        : [if (m != null && m.type.isNotEmpty) m.type, '${tr('since')} ${slbTime(ss['since'])}', '${tr('${ss['shift'] ?? ''}')} ${tr('shift')}'].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: Color(0xE6FFFFFF))),
              ]),
            ),
          ]),
        ),
        if (ss != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('● ${live ? bi('GPS on – live', 'GPS चालू') : bi('GPS off', 'GPS बंद')}${op == null ? '' : '    ${tr('Opening')} ${_read(op)}'}${asNum(g['km']) != null && asNum(g['km'])! > 0 ? '    ${fmtNum(asNum(g['km']))} km' : ''}',
                maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        const SizedBox(height: 10),
        Row(children: [
          if (ss == null) ...[
            btn('home-myveh-qr', inn > 0 ? 'Accept' : 'Scan the QR', inn > 0 ? 'स्वीकारा' : 'गाडीवरचा QR', inn > 0 ? Icons.check_rounded : Icons.qr_code_scanner_rounded, inn > 0 ? '' : 'qr', true),
            const SizedBox(width: 10),
            btn('home-myveh-plate', 'Number plate', 'प्लेटचा फोटो', Icons.photo_camera_rounded, 'plate', false),
          ] else if (op == null) ...[
            btn('home-myveh-open', 'Opening photo', 'आजचा opening', Icons.photo_camera_rounded, '', true),
            const SizedBox(width: 10),
            btn('home-myveh-hand', 'Hand over', 'दुसऱ्याला द्या', Icons.swap_horiz_rounded, 'hand', false),
          ] else ...[
            btn('home-myveh-close', 'Close the shift', 'shift बंद करा', Icons.stop_rounded, 'close', true),
            const SizedBox(width: 10),
            btn('home-myveh-hand', 'Hand over', 'दुसऱ्याला द्या', Icons.swap_horiz_rounded, 'hand', false),
          ],
        ]),
      ]),
    );
  }
}
