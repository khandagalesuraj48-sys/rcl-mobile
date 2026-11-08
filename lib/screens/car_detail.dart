/* (3.86.0, Mechanical update-212, asked 08-11-2026) HO'S CARS – the app's own screens (never the web's):
 *   – CarGalleryCard: a car on the Dashboard of a site on fuel cards – its photo (or a picture of a car / truck / machine), its
 *     fuel, number, make · model, the fuel filled and its ₹ in the dates, the last fill. A tap opens the car.
 *   – CarDetailScreen: the car – its photo over the top, number, make · model, fuel, kind, status, KM now; the fuel filled, its ₹ (by
 *     card / cash), the average, the fills; its fills, Log Book days and maintenance bills of the dates – each only for a person who
 *     may see them (the server gives them so – getCarDetail).
 *   – The Admin and the Super Admin: Add / Change photo (the camera or the gallery; a computer: a file) – made smaller here, shown
 *     first, saved by "Save photo"; Remove (asks first; its file stays in the store). The server checks who it is (carPhotoSet /
 *     carPhotoRemove). */
import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:flutter/material.dart' hide Text;
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/applock.dart';
import '../core/car_photos.dart';
import '../core/device.dart';
import '../core/format.dart';
import '../ui/scope.dart';
import '../ui/t.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'fuel_cards.dart' show rupees;

/// How the picture is taken / picked (tests put their own).
class CarPhotoPick {
  static Future<Uint8List?> Function(bool camera) pick = _pick;
  static Future<Uint8List?> _pick(bool camera) async {
    if (camera && Platform.isAndroid) {
      final st = await Permission.camera.request();
      if (!st.isGranted) throw CarPhotoProblem('Allow the camera for RCL ERP (Settings › Apps › RCL ERP › Permissions), then try again.');
    }
    final x = await AppLock.whileOutside(() => ImagePicker().pickImage(source: camera ? ImageSource.camera : ImageSource.gallery, maxWidth: 2400, maxHeight: 2400, imageQuality: 95, preferredCameraDevice: CameraDevice.rear));
    return x == null ? null : x.readAsBytes();
  }
}

String _u(Object? unit) => '$unit' == 'kg' ? 'kg' : 'L';

/// A picture for a car without a photo: a car, a truck / tipper or a machine (by its kind).
IconData carIcon(String type) {
  final t = type.toLowerCase();
  if (RegExp(r'truck|tipper|dumper|tanker|trailer|bus|hywa|hyva|tractor').hasMatch(t)) return Icons.local_shipping_rounded;
  if (RegExp(r'jcb|excavat|loader|roller|grader|paver|crane|dozer|machine|poclain|hydra|compactor|mixer').hasMatch(t)) return Icons.precision_manufacturing_rounded;
  return Icons.directions_car_filled_rounded;
}

/// A car's photo (small, or [full]) – from memory or by its link (renewed by itself); none: the car's icon, never a broken picture.
class CarPic extends StatefulWidget {
  const CarPic(this.no, {super.key, this.type = '', this.full = false, this.dark = false, this.words = true});
  final String no, type;
  final bool full, dark, words;
  @override
  State<CarPic> createState() => _CarPicState();
}

class _CarPicState extends State<CarPic> {
  Future<Uint8List?>? _f;
  String _mark = '';
  /// the last try did not open the picture: tried again when NEW links come (another link than the one that failed – never a loop)
  bool _failed = false;
  String _failedT = '';

  @override
  void initState() {
    super.initState();
    CarPhotos.i.addListener(_changed);
  }

  @override
  void dispose() {
    CarPhotos.i.removeListener(_changed);
    super.dispose();
  }

  @override
  void didUpdateWidget(CarPic old) {
    super.didUpdateWidget(old);
    if (old.no != widget.no || old.full != widget.full) {
      _mark = '';
      _f = null;
    }
  }

  void _changed() {
    if (!mounted) return;
    if (_failed && (CarPhotos.i.of(widget.no)?.t ?? '') != _failedT) {
      _failed = false;
      _f = null;
      setState(() {});
    } else if ((CarPhotos.i.of(widget.no)?.v ?? '') != _mark) {
      setState(() {});
    }
  }

  Widget _none(String w) => ColoredBox(
        color: widget.dark ? const Color(0xFF2B3A33) : const Color(0xFFEFEADF),
        child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(carIcon(widget.type), size: widget.full ? 72 : 40, color: widget.dark ? const Color(0xFF8FA399) : const Color(0xFFB9B19E)),
          if (widget.words && w.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2), child: Text(w, style: TextStyle(fontSize: widget.full ? 14 : 11.5, color: widget.dark ? const Color(0xFFC9D5CE) : const Color(0xFF9A9483)))),
        ])),
      );

  @override
  Widget build(BuildContext context) {
    final p = CarPhotos.i.of(widget.no);
    if (p == null) {
      _mark = '';
      _f = null;
      return _none('No photo yet');
    }
    if (p.v != _mark || _f == null) {
      _mark = p.v;
      _f = CarPhotos.i.picture(SessionScope.read(context), widget.no, full: widget.full);
    }
    return FutureBuilder<Uint8List?>(
      future: _f,
      builder: (_, snap) {
        if (snap.hasData && snap.data != null) return Image.memory(snap.data!, key: Key('car-pic-${widget.no}${widget.full ? '-f' : ''}'), fit: BoxFit.cover, gaplessPlayback: true, width: double.infinity, height: double.infinity);
        if (snap.hasError) {
          _failed = true;
          _failedT = CarPhotos.i.of(widget.no)?.t ?? '';
          return _none('Photo could not open');
        }
        return _none('');
      },
    );
  }
}

/// A car on the Dashboard (the gallery).
class CarGalleryCard extends StatelessWidget {
  const CarGalleryCard(this.c, {super.key, required this.onTap, this.onAdd});
  final Map<String, dynamic> c;
  final VoidCallback onTap;
  /// the Admin, a car without a photo: "Add photo" on its picture
  final VoidCallback? onAdd;
  @override
  Widget build(BuildContext context) {
    final no = '${c['no']}', mm = [c['make'], c['name']].where((x) => '${x ?? ''}'.isNotEmpty).join(' · '), last = c['last'] is Map ? (c['last'] as Map) : null;
    final noPhoto = CarPhotos.i.of(no) == null;      // (the Dashboard rebuilds when a photo changes)
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), boxShadow: const [BoxShadow(color: Color(0x14182219), blurRadius: 10, offset: Offset(0, 2))]),
      child: Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            AspectRatio(
              aspectRatio: 4 / 3,
              child: Stack(fit: StackFit.expand, children: [
                CarPic(no, type: '${c['type'] ?? ''}', words: !(noPhoto && onAdd != null)),
                Positioned(left: 8, top: 8, child: _badge('${c['fuel'] ?? ''}')),
                if ('${c['status'] ?? ''}' == 'Inactive') Positioned(right: 8, top: 8, child: _badge('Inactive', color: C.red)),
                if (noPhoto && onAdd != null)
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Material(
                      color: const Color(0xDD18221C),
                      borderRadius: BorderRadius.circular(30),
                      child: InkWell(
                        key: Key('cg-add-$no'),
                        borderRadius: BorderRadius.circular(30),
                        onTap: onAdd,
                        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.photo_camera_rounded, size: 14, color: Colors.white),
                          const SizedBox(width: 4),
                          Text('Add photo', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                        ])),
                      ),
                    ),
                  ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(11, 9, 11, 11),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(no, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5, letterSpacing: .3)),
                Text(mm.isEmpty ? '${c['type'] ?? ''}' : mm, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: C.muted)),
                const SizedBox(height: 6),
                Row(children: [
                  Expanded(child: Text((asNum(c['qty']) ?? 0) > 0 ? '${fmtNum(asNum(c['qty']))} ${_u(c['unit'])}' : 'No fill', maxLines: 1, style: const TextStyle(fontSize: 12.5))),
                  Text((asNum(c['amount']) ?? 0) > 0 ? rupees(asNum(c['amount'])) : '–', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                ]),
                const SizedBox(height: 3),
                Text(last == null ? 'No fill yet' : 'Last fill ${showDate('${last['date']}')}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: C.muted)),
              ]),
            ),
          ]),
      ),
      ),
    );
  }

  static Widget _badge(String t, {Color color = C.ink}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: const Color(0xEEFFFFFF), borderRadius: BorderRadius.circular(30)),
        child: Text(t, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
      );
}

/// The Admin / Super Admin: a car's photo – taken or picked, made smaller, shown first, saved. True = saved.
Future<bool> setCarPhoto(BuildContext context, String no) async {
  final s = SessionScope.read(context);
  final bool? camera = onComputer
      ? false
      : await showModalBottomSheet<bool>(
          context: context,
          showDragHandle: true,
          builder: (c) => SafeArea(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 8), child: Text('Photo – $no', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
              ListTile(key: const Key('cp-camera'), leading: const Icon(Icons.photo_camera_rounded, color: C.green), title: Text('Take a photo'), onTap: () => Navigator.pop(c, true)),
              ListTile(key: const Key('cp-gallery'), leading: const Icon(Icons.photo_library_rounded, color: C.blue), title: Text('Pick from the gallery'), onTap: () => Navigator.pop(c, false)),
              const SizedBox(height: 8),
            ]),
          ),
        );
  if (camera == null || !context.mounted) return false;
  final CarJpegs made;
  try {
    final raw = await CarPhotoPick.pick(camera);
    if (raw == null || !context.mounted) return false;
    made = await makeCarJpegs(raw);
  } catch (e) {
    if (context.mounted) toast(context, tr(e is CarPhotoProblem ? e.message : 'This picture cannot be read – pick another.'), bad: true);
    return false;
  }
  if (!context.mounted) return false;
  final was = CarPhotos.i.of(no)?.v ?? '';
  final saved = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) {
      var busy = false;
      return StatefulBuilder(builder: (c, setD) => PopScope(
          canPop: !busy,      // (no going back while it is being saved)
          child: AlertDialog(
            key: const Key('cp-preview'),
            title: Text(was.isEmpty ? 'Photo – $no' : 'Change photo – $no'),
            scrollable: true,
            content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              ClipRRect(borderRadius: BorderRadius.circular(14), child: AspectRatio(aspectRatio: 16 / 10, child: Image.memory(made.full, fit: BoxFit.cover))),
              const SizedBox(height: 10),
              Text('New photo – ${made.w} × ${made.h}, ${sizeText(made.full.length)}${made.from > made.full.length ? ' (made smaller here from ${sizeText(made.from)})' : ''}.',
                  style: const TextStyle(color: C.green, fontWeight: FontWeight.w600, fontSize: 13.5)),
              Text('Nothing is saved until you press Save photo.', style: const TextStyle(color: C.muted, fontSize: 12.5)),
              if (busy) const Padding(padding: EdgeInsets.only(top: 10), child: LinearProgressIndicator()),
            ]),
            actions: [
              TextButton(onPressed: busy ? null : () => Navigator.pop(c, false), child: Text('Cancel')),
              FilledButton(
                key: const Key('cp-save'),
                style: FilledButton.styleFrom(minimumSize: const Size(130, 46), backgroundColor: C.green),
                onPressed: busy
                    ? null
                    : () async {
                        setD(() => busy = true);
                        try {
                          final r = await s.api.call('carPhotoSet', [{'no': no, 'full': made.fullUrl, 'thumb': made.thumbUrl, 'was': was}], true);
                          final p = CarPhoto.of(r is Map ? r['photo'] : null);
                          if (p != null) CarPhotos.i.keepMade(p, made);
                          CarPhotos.i.put(no, r is Map ? r['photo'] : null);
                          if (c.mounted) Navigator.pop(c, true);
                        } catch (e) {
                          if (c.mounted) {
                            setD(() => busy = false);
                            toast(c, tr(errText(e)), bad: true);
                          }
                        }
                      },
                child: Text('Save photo'),
              ),
            ],
          )));
    },
  );
  if (saved == true && context.mounted) toast(context, tr('Photo saved – {0}.').replaceAll('{0}', no));
  return saved == true;
}

/// The Admin / Super Admin: a car's photo removed (asks first). True = removed.
Future<bool> removeCarPhoto(BuildContext context, String no) async {
  final s = SessionScope.read(context);
  final ok = await ask(context, tr('Remove the photo of {0}?').replaceAll('{0}', no), 'The car shows its picture icon again. The photo file itself stays kept in the site\'s private store (nothing there is deleted).', yes: 'Remove photo', danger: true);
  if (!ok || !context.mounted) return false;
  try {
    final r = await s.api.call('carPhotoRemove', [{'no': no, 'was': CarPhotos.i.of(no)?.v ?? ''}], true);
    CarPhotos.i.put(no, r is Map ? r['photo'] : null);
    if (context.mounted) toast(context, tr('Photo removed – {0}.').replaceAll('{0}', no));
    return true;
  } catch (e) {
    if (context.mounted) toast(context, tr(errText(e)), bad: true);
    return false;
  }
}

Future<void> openCar(BuildContext context, String no, String from, String to) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => CarDetailScreen(no: no, from: from, to: to)));

/// One car: its photo, its figures, its fills / Log Book / maintenance of the dates.
class CarDetailScreen extends StatefulWidget {
  const CarDetailScreen({super.key, required this.no, required this.from, required this.to});
  final String no, from, to;
  @override
  State<CarDetailScreen> createState() => _CarDetailScreenState();
}

class _CarDetailScreenState extends State<CarDetailScreen> {
  Map<String, dynamic>? d;
  String err = '', tab = 'fuel';

  @override
  void initState() {
    super.initState();
    CarPhotos.i.addListener(_changed);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    CarPhotos.i.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    final s = SessionScope.read(context);
    try {
      final r = (await s.api.call('getCarDetail', [{'no': widget.no, 'from': widget.from, 'to': widget.to}]) as Map).cast<String, dynamic>();
      if (!mounted) return;
      CarPhotos.i.put(widget.no, (r['car'] as Map?)?['photo']);
      setState(() {
        d = r;
        err = '';
      });
    } catch (e) {
      if (mounted) setState(() => err = errText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final x = d, car = (x?['car'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{'no': widget.no}, may = (x?['may'] as Map?) ?? const {};
    final hasPhoto = CarPhotos.i.of(widget.no) != null;
    final top = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: C.bg,
      body: ListView(key: const Key('car-detail'), padding: EdgeInsets.zero, children: [
        SizedBox(
          height: 270 + top,
          child: Stack(fit: StackFit.expand, children: [
            CarPic(widget.no, type: '${car['type'] ?? ''}', full: true, dark: true),
            Positioned(
              left: 14,
              top: top + 10,
              child: _round(Icons.arrow_back_rounded, tr('Back'), () => Navigator.of(context).maybePop(), const Key('car-back')),
            ),
            if (may['photo'] == true)
              Positioned(
                right: 14,
                bottom: 34,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (hasPhoto) _chip(const Key('car-remove'), Icons.delete_outline_rounded, 'Remove', C.red, () => removeCarPhoto(context, widget.no)),
                  if (hasPhoto) const SizedBox(width: 8),
                  _chip(const Key('car-photo'), Icons.photo_camera_rounded, hasPhoto ? 'Change photo' : 'Add photo', C.ink, () => setCarPhoto(context, widget.no)),
                ]),
              ),
          ]),
        ),
        Transform.translate(
          offset: const Offset(0, -22),
          child: Container(
            decoration: const BoxDecoration(color: C.bg, borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(widget.no, key: const Key('car-no'), style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800, letterSpacing: .4)),
              if (x != null && [car['make'], car['name']].any((v) => '${v ?? ''}'.isNotEmpty))
                Text([car['make'], car['name']].where((v) => '${v ?? ''}'.isNotEmpty).join(' · '), style: const TextStyle(fontSize: 13.5, color: C.muted)),
              if (err.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: InfoLine(err, bad: true)),
              if (x == null && err.isEmpty) const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator())),
              if (x != null) ..._body(x, car),
            ]),
          ),
        ),
      ]),
    );
  }

  List<Widget> _body(Map<String, dynamic> x, Map<String, dynamic> car) {
    final sum = (x['sum'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{}, u = _u(car['unit']);
    // (text, colour, a dot before it – the status)
    final tags = <(String, Color, bool)>[('${car['fuel'] ?? ''}', C.ink, false), if ('${car['type'] ?? ''}'.isNotEmpty) ('${car['type']}', C.ink, false),
      ('${car['status'] ?? 'Active'}', '${car['status']}' == 'Inactive' ? C.red : C.green, true), ('KM now ${asNum(car['kmNow']) != null ? fmtNum(asNum(car['kmNow'])) : '–'}', C.ink, false)];
    final kpi = <(String, String)>[('Fuel filled', (asNum(sum['qty']) ?? 0) > 0 ? '${fmtNum(asNum(sum['qty']))} $u' : '–'), ('Expense', (asNum(sum['amount']) ?? 0) > 0 ? rupees(asNum(sum['amount'])) : '–'),
      ('Average', asNum(sum['avg']) != null ? '${fmtNum(asNum(sum['avg']))} km/$u' : '–'), ('By card', rupees(asNum(sum['card']))), ('Cash', rupees(asNum(sum['cash']))), ('Fills', fmtNum(asNum(sum['fills']) ?? 0))];
    return [
      const SizedBox(height: 8),
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final t in tags)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30), border: Border.all(color: C.line)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (t.$3) ...[Icon(Icons.circle, size: 8, color: t.$2), const SizedBox(width: 4)],
              Text(t.$1, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: t.$2)),
            ]),
          ),
      ]),
      const SizedBox(height: 8),
      Text('${showDate('${x['from']}')} – ${showDate('${x['to']}')}', style: const TextStyle(fontSize: 12, color: C.muted)),
      const SizedBox(height: 10),
      LayoutBuilder(builder: (_, bc) {
        final w = (bc.maxWidth - 16) / 3;
        return Wrap(spacing: 8, runSpacing: 8, children: [
          for (final k in kpi)
            Container(
              width: w,
              padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 1))]),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(k.$1, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: C.muted)),
                FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(k.$2, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800))),
              ]),
            ),
        ]);
      }),
      const SizedBox(height: 14),
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final t in const [('fuel', 'Fuel'), ('log', 'Log Book'), ('maint', 'Maintenance')])
          ChoiceChip(key: Key('cdt-${t.$1}'), selected: tab == t.$1, onSelected: (_) => setState(() => tab = t.$1), label: Text(t.$2)),
      ]),
      const SizedBox(height: 4),
      ..._rows(x, car),
    ];
  }

  List<Widget> _rows(Map<String, dynamic> x, Map<String, dynamic> car) {
    Widget row(Key k, IconData ic, Color tint, Color bg, String a, String b, {Widget? end}) => Container(
          key: k,
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: Row(children: [
            Container(width: 34, height: 34, decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)), child: Icon(ic, size: 19, color: tint)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(a, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
              Text(b, style: const TextStyle(fontSize: 11.5, color: C.muted)),
            ])),
            if (end != null) ...[const SizedBox(width: 6), end],
          ]),
        );
    Widget none(String t) => Padding(padding: const EdgeInsets.only(top: 12), child: Text(t, style: const TextStyle(color: C.muted)));
    if (tab == 'fuel') {
      final l = [for (final f in (x['fills'] as List? ?? const []).whereType<Map>()) f.cast<String, dynamic>()];
      if (l.isEmpty) return [none('No fill of this car in these dates.')];
      return [
        for (final (i, f) in l.indexed)
          row(Key('cf-$i'), Icons.local_gas_station_rounded, C.amber, C.amberSoft, '${fmtNum(asNum(f['qty']))} ${_u(f['unit'])} · ${rupees(asNum(f['amount']))}',
              '${showDate('${f['date']}')} · ${f['fuel']}${asNum(f['km']) != null ? ' · KM ${fmtNum(asNum(f['km']))}' : ''}',
              end: Pill('${f['paidBy']}', color: f['cash'] == true ? C.amber : C.blue, bg: f['cash'] == true ? C.amberSoft : C.blueSoft)),
      ];
    }
    if (tab == 'log') {
      if (x['log'] == null) return [Padding(padding: const EdgeInsets.only(top: 10), child: InfoLine('You have no access to the Log Book – ask the Admin.', help: false))];
      final l = [for (final f in (x['log'] as List).whereType<Map>()) f.cast<String, dynamic>()];
      if (l.isEmpty) return [none('No Log Book day of this car in these dates.')];
      return [
        for (final (i, r) in l.indexed)
          row(Key('cl-$i'), Icons.speed_rounded, C.green, C.greenSoft,
              '${asNum(r['okm']) != null ? fmtNum(asNum(r['okm'])) : '–'} → ${asNum(r['ckm']) != null ? fmtNum(asNum(r['ckm'])) : '–'} · ${fmtNum(asNum(r['km']) ?? 0)} km',
              [showDate('${r['date']}'), '${r['shift']}', if ('${r['driver'] ?? ''}'.isNotEmpty) '${r['driver']}'].join(' · ')),
      ];
    }
    if (x['maint'] == null) return [Padding(padding: const EdgeInsets.only(top: 10), child: InfoLine('You have no access to Maintenance – ask the Admin.', help: false))];
    final l = [for (final f in (x['maint'] as List).whereType<Map>()) f.cast<String, dynamic>()];
    if (l.isEmpty) return [none('No maintenance bill of this car in these dates.')];
    return [
      for (final (i, m) in l.indexed)
        row(Key('cm-$i'), Icons.build_rounded, C.slate, C.slateSoft, '${m['garage'] ?? '–'}${'${m['billNo'] ?? ''}'.isNotEmpty ? ' · ${m['billNo']}' : ''} · ${rupees(asNum(m['amount']))}',
            [showDate('${m['date']}'), if (asNum(m['km']) != null) 'KM ${fmtNum(asNum(m['km']))}', ((m['works'] as List?) ?? const []).join(', ')].where((v) => v.isNotEmpty).join(' · '),
            end: m['service'] == true ? Pill('Service', color: C.green, bg: C.greenSoft) : null),
    ];
  }

  Widget _round(IconData ic, String tip, VoidCallback onTap, Key k) => Material(
        color: const Color(0xEEFFFFFF),
        shape: const CircleBorder(),
        child: IconButton(key: k, tooltip: tip, onPressed: onTap, icon: Icon(ic, color: C.ink)),
      );

  Widget _chip(Key k, IconData ic, String t, Color c, VoidCallback onTap) => Material(
        color: const Color(0xF2FFFFFF),
        borderRadius: BorderRadius.circular(30),
        child: InkWell(
          key: k,
          borderRadius: BorderRadius.circular(30),
          onTap: onTap,
          child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7), child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(ic, size: 16, color: c),
            const SizedBox(width: 5),
            Text(t, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: c)),
          ])),
        ),
      );
}

/// The search of the gallery: a part of the number (letters and digits only), the make, the model, the kind.
bool carMatches(Map<String, dynamic> c, String q) {
  final w = q.trim().toLowerCase();
  if (w.isEmpty) return true;
  String key(Object? v) => '${v ?? ''}'.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  final k = key(q);
  return (k.isNotEmpty && key(c['no']).contains(k)) || [c['make'], c['name'], c['type']].any((v) => '${v ?? ''}'.toLowerCase().contains(w));
}
