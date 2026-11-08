/* (3.87.0) CarDetailScreen is now HO's VEHICLE DETAILS (Overview, quick actions with the car chosen, Vehicle History – below); the
 * Dashboard's gallery writes nothing on a photo (its fuel, Inactive and "Add photo" under it).
 * (3.86.0, Mechanical update-212, asked 08-11-2026) HO'S CARS – the app's own screens (never the web's):
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
import '../core/kinds.dart';
import '../core/session.dart';
import '../ui/scope.dart';
import '../ui/t.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'forms.dart' show newEntry;
import 'fuel_cards.dart' show rupees;
import 'logbook.dart' show LogForm, TankerScreen;
import 'maintenance.dart' show MaintForm;

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
        // (3.87.0, asked 08-11-2026: "Never overlay registration numbers or other text on the vehicle photograph itself") the photo
        // alone; its fuel, Inactive and "Add photo" under it
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            AspectRatio(aspectRatio: 4 / 3, child: CarPic(no, type: '${c['type'] ?? ''}', words: false)),
            Padding(
              padding: const EdgeInsets.fromLTRB(11, 9, 11, 11),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(no, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5, letterSpacing: .3)),
                Text(mm.isEmpty ? '${c['type'] ?? ''}' : mm, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: C.muted)),
                const SizedBox(height: 4),
                Wrap(spacing: 5, runSpacing: 4, children: [
                  if ('${c['fuel'] ?? ''}'.isNotEmpty) _badge('${c['fuel']}'),
                  if ('${c['status'] ?? ''}' == 'Inactive') _badge('Inactive', color: C.red),
                ]),
                const SizedBox(height: 6),
                Row(children: [
                  Expanded(child: Text((asNum(c['qty']) ?? 0) > 0 ? '${fmtNum(asNum(c['qty']))} ${_u(c['unit'])}' : 'No fill', maxLines: 1, style: const TextStyle(fontSize: 12.5))),
                  Text((asNum(c['amount']) ?? 0) > 0 ? rupees(asNum(c['amount'])) : '–', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                ]),
                const SizedBox(height: 3),
                Text(last == null ? 'No fill yet' : 'Last fill ${showDate('${last['date']}')}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: C.muted)),
                if (noPhoto && onAdd != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: OutlinedButton.icon(
                      key: Key('cg-add-$no'),
                      onPressed: onAdd,
                      style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 10), minimumSize: const Size(0, 34), foregroundColor: C.greenDark),
                      icon: const Icon(Icons.photo_camera_rounded, size: 16),
                      label: Text('Add photo', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                    ),
                  ),
              ]),
            ),
          ]),
      ),
      ),
    );
  }

  static Widget _badge(String t, {Color color = C.ink}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(30), border: Border.all(color: C.line)),
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

/// (3.87.0) a car opened from HO's Home: this month
Future<void> openVehicle(BuildContext context, String no) {
  final to = _today(SessionScope.read(context));
  return openCar(context, no, '${to.substring(0, 8)}01', to);
}

String _today(Session s) => s.today.isNotEmpty ? s.today : dateKey(DateTime.now());
String _mm(Map<String, dynamic> m) => [m['make'], m['name']].where((v) => '${v ?? ''}'.isNotEmpty).join(' · ');
String _km(Object? v) => asNum(v) != null ? '${fmtNum(asNum(v))} km' : '–';

/* (3.87.0, asked 08-11-2026: "RCL ERP – Premium Mobile App Redesign" Part 3, with his picture) THE VEHICLE DETAILS of a car of HO:
 *   – its photo ALONE (nothing written on it); under it, for the Admin / Super Admin: Add / Change photo, Remove;
 *   – its number, make · model, Active / Inactive; Fuel, KM now, Engine Hrs (a machinery on hours) or its kind, its site;
 *   – Overview: the summary of the dates (fuel, running KM, average, ₹), the 4 quick actions – Diesel Issue, Log Book entry,
 *     Maintenance (each form opens with THIS car already chosen; each only for a person who may make it), Vehicle History; its
 *     key information; the recent activity. Then its fills, Log Book days and maintenance bills (as 3.86.0).
 *   The figures are the server's (getCarDetail – Dashboard access); a person without the Dashboard sees the car and the actions. */
class CarDetailScreen extends StatefulWidget {
  const CarDetailScreen({super.key, required this.no, required this.from, required this.to});
  final String no, from, to;
  @override
  State<CarDetailScreen> createState() => _CarDetailScreenState();
}

class _CarDetailScreenState extends State<CarDetailScreen> {
  Map<String, dynamic>? d;
  String err = '', tab = 'over';
  bool loading = false;

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
    if (!s.canSee('Dashboard')) return;      // (the server gives the figures only with the Dashboard)
    setState(() => loading = true);
    try {
      final r = (await s.api.call('getCarDetail', [{'no': widget.no, 'from': widget.from, 'to': widget.to}]) as Map).cast<String, dynamic>();
      if (!mounted) return;
      CarPhotos.i.put(widget.no, (r['car'] as Map?)?['photo']);
      setState(() {
        d = r;
        err = '';
        loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          err = errText(e);
          loading = false;
        });
      }
    }
  }

  /// the quick actions – each form opens with this car already chosen; after a save the figures are read again
  Future<void> _issue() async {
    if (await newEntry(context, kindOf('issue'), no: widget.no)) _load();
  }

  Future<void> _logEntry() async {
    final s = SessionScope.read(context), m = s.machine(widget.no);
    await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => m?.waterTanker == true ? TankerScreen(date: _today(s), no: widget.no) : LogForm(date: _today(s), no: widget.no)));
    if (mounted) _load();
  }

  Future<void> _maint() async {
    final s = SessionScope.read(context), to = _today(s);
    var works = <String>[], garages = <String>[];
    try {      // the words typed in earlier bills, suggested (as the Maintenance page)
      final r = (await s.api.call('getMaint', [{'from': '${to.substring(0, 8)}01', 'to': to, 'no': ''}]) as Map);
      works = [for (final w in (r['works'] as List? ?? const [])) '$w'];
      garages = [for (final g in (r['garages'] as List? ?? const [])) '$g'];
    } catch (_) {/* the form opens without suggestions */}
    if (!mounted) return;
    await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => MaintForm(no: widget.no, works: works, garages: garages)));
    if (mounted) _load();
  }

  void _history() => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => VehicleHistoryScreen(no: widget.no)));

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context), mc = s.machine(widget.no);
    final x = d, car = <String, dynamic>{'no': widget.no, ...?mc?.m, 'fuel': mc?.fuel ?? '', ...?((x?['car'] as Map?)?.cast<String, dynamic>())};
    final may = (x?['may'] as Map?) ?? const {};
    final hasPhoto = CarPhotos.i.of(widget.no) != null, dash = s.canSee('Dashboard');
    final inactive = '${car['status'] ?? ''}' == 'Inactive', hrs = mc != null && mc.modes.any(hasHr);
    final tiles = <(IconData, String, String)>[
      (Icons.local_gas_station_rounded, '${car['fuel'] ?? ''}'.isEmpty ? '–' : '${car['fuel']}', 'Fuel'),
      (Icons.speed_rounded, _km(car['kmNow']), 'KM now'),
      hrs ? (Icons.hourglass_bottom_rounded, '–', 'Engine Hrs') : (carIcon('${car['type'] ?? ''}'), '${car['type'] ?? ''}'.isEmpty ? '–' : '${car['type']}', 'Type'),
      (Icons.location_on_rounded, s.siteName, 'Base site'),
    ];
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.greenDeep,
        foregroundColor: Colors.white,
        leading: IconButton(key: const Key('car-back'), tooltip: tr('Back'), onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.arrow_back_rounded)),
        title: Text('Vehicle Details', style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
      ),
      body: RefreshIndicator(
        color: C.green,
        onRefresh: _load,
        child: ListView(key: const Key('car-detail'), padding: const EdgeInsets.fromLTRB(16, 14, 16, 32), children: [
          // the photo alone – nothing written on it
          ClipRRect(borderRadius: BorderRadius.circular(22), child: AspectRatio(aspectRatio: 16 / 10, child: CarPic(widget.no, type: '${car['type'] ?? ''}', full: true, dark: true))),
          if (may['photo'] == true)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                if (hasPhoto) OutlinedButton.icon(key: const Key('car-remove'), onPressed: () => removeCarPhoto(context, widget.no), style: OutlinedButton.styleFrom(foregroundColor: C.red, visualDensity: VisualDensity.compact, minimumSize: const Size(0, 40)), icon: const Icon(Icons.delete_outline_rounded, size: 18), label: Text('Remove')),
                if (hasPhoto) const SizedBox(width: 8),
                FilledButton.tonalIcon(key: const Key('car-photo'), onPressed: () => setCarPhoto(context, widget.no), style: FilledButton.styleFrom(visualDensity: VisualDensity.compact, minimumSize: const Size(0, 40)), icon: const Icon(Icons.photo_camera_rounded, size: 18), label: Text(hasPhoto ? 'Change photo' : 'Add photo')),
              ]),
            ),
          const SizedBox(height: 12),
          // the number, make · model, its status
          Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 6, offset: Offset(0, 2))]),
            child: Row(children: [
              Container(width: 50, height: 50, decoration: BoxDecoration(color: C.greenSoft, borderRadius: BorderRadius.circular(15)), child: Icon(carIcon('${car['type'] ?? ''}'), color: C.greenDark, size: 28)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(widget.no, key: const Key('car-no'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: .4))),
                  if (_mm(car).isNotEmpty) Text(_mm(car), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, color: C.muted)),
                ]),
              ),
              Container(
                key: const Key('car-status'),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: inactive ? C.redSoft : C.greenSoft, borderRadius: BorderRadius.circular(30)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.circle, size: 8, color: inactive ? C.red : C.green),
                  const SizedBox(width: 5),
                  Text(inactive ? 'Inactive' : 'Active', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: inactive ? C.red : C.greenDark)),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 10),
          Row(children: [
            for (final (i, t) in tiles.indexed) ...[
              if (i > 0) const SizedBox(width: 7),
              Expanded(
                child: Container(
                  key: Key('car-tile-$i'),
                  padding: const EdgeInsets.fromLTRB(6, 10, 6, 9),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                  child: Column(children: [
                    Icon(t.$1, color: C.greenDark, size: 22),
                    const SizedBox(height: 4),
                    FittedBox(fit: BoxFit.scaleDown, child: Text(t.$2, maxLines: 1, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700))),
                    Text(t.$3, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: C.muted)),
                  ]),
                ),
              ),
            ],
          ]),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final t in [('over', 'Overview'), if (dash) ...[('fuel', 'Fuel'), ('log', 'Log Book'), ('maint', 'Maintenance')]])
                Padding(padding: const EdgeInsets.only(right: 6), child: ChoiceChip(key: Key('cdt-${t.$1}'), selected: tab == t.$1, onSelected: (_) => setState(() => tab = t.$1), label: Text(t.$2))),
            ]),
          ),
          if (err.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: InfoLine(err, bad: true)),
          if (dash && x == null && err.isEmpty) const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator())),
          if (tab == 'over') ..._overview(s, x, car) else if (x != null) ...carRows(x, tab),
        ]),
      ),
    );
  }

  List<Widget> _overview(Session s, Map<String, dynamic>? x, Map<String, dynamic> car) {
    final sum = (x?['sum'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{}, u = _u(car['unit']);
    final month = widget.from.endsWith('-01') && widget.to.substring(0, 8) == widget.from.substring(0, 8);
    final acts = <(String, IconData, Color, Color, String, String, VoidCallback)>[
      if (s.canEdit('Diesel Issue')) ('issue', Icons.local_gas_station_rounded, C.green, C.greenSoft, 'Diesel Issue', 'Fill this car – card or Cash', _issue),
      if (s.canEdit('Log Book')) ('log', Icons.menu_book_rounded, C.purple, C.purpleSoft, 'Log Book Entry', 'Running KM, driver, work', _logEntry),
      if (s.canEdit('Maintenance')) ('maint', Icons.build_rounded, C.orange, C.orangeSoft, 'Maintenance', 'A bill – garage, parts, service', _maint),
      if (s.canSee('Dashboard')) ('hist', Icons.history_rounded, C.blue, C.blueSoft, 'Vehicle History', 'Fuel, Log Book, maintenance – any dates', _history),
    ];
    final info = <(String, String)>[
      ('Make / Model', _mm(car).isEmpty ? '–' : _mm(car)),
      ('Type', '${car['type'] ?? ''}'.isEmpty ? '–' : '${car['type']}'),
      ('Fuel', '${car['fuel'] ?? ''}'.isEmpty ? '–' : '${car['fuel']}'),
      ('Status', '${car['status'] ?? 'Active'}'),
      if ('${car['ownership'] ?? ''}'.isNotEmpty) ('Ownership', '${car['ownership']}${'${car['owner'] ?? ''}'.isNotEmpty ? ' · ${car['owner']}' : ''}'),
      if ('${car['activeFrom'] ?? ''}'.length >= 10) ('On site from', showDate('${car['activeFrom']}'.substring(0, 10))),
    ];
    Widget card(Widget child, {Key? key}) => Container(key: key, margin: const EdgeInsets.only(top: 12), padding: const EdgeInsets.fromLTRB(14, 12, 14, 12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)), child: child);
    final recent = x == null ? <(String, Widget)>[] : carHistory(x, 'all').take(4).toList();
    return [
      if (x != null)
        card(
          key: const Key('car-sum'),
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(month ? 'This month' : '${showDate(widget.from)} – ${showDate(widget.to)}', style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Row(children: [
              for (final (i, k) in <(IconData, Color, Color, String, String)>[
                (Icons.local_gas_station_rounded, C.red, C.redSoft, 'Fuel', (asNum(sum['qty']) ?? 0) > 0 ? '${fmtNum(asNum(sum['qty']))} $u' : '–'),
                (Icons.speed_rounded, C.green, C.greenSoft, 'Running', (asNum(sum['km']) ?? 0) > 0 ? '${fmtNum(asNum(sum['km']))} km' : '–'),
                (Icons.insights_rounded, C.purple, C.purpleSoft, 'Average', asNum(sum['avg']) != null ? '${fmtNum(asNum(sum['avg']))} km/$u' : '–'),
                (Icons.currency_rupee_rounded, C.amber, C.amberSoft, 'Fuel cost', (asNum(sum['amount']) ?? 0) > 0 ? rupees(asNum(sum['amount'])) : '–'),
              ].indexed) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(4, 9, 4, 9),
                    decoration: BoxDecoration(color: k.$3, borderRadius: BorderRadius.circular(14)),
                    child: Column(children: [
                      Icon(k.$1, color: k.$2, size: 21),
                      const SizedBox(height: 3),
                      Text(k.$4, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: C.muted)),
                      FittedBox(fit: BoxFit.scaleDown, child: Text(k.$5, maxLines: 1, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800))),
                    ]),
                  ),
                ),
              ],
            ]),
            const SizedBox(height: 8),
            Text('${tr('By card')} ${rupees(asNum(sum['card']))} · ${tr('Cash')} ${rupees(asNum(sum['cash']))} · ${tr('Fills')} ${fmtNum(asNum(sum['fills']) ?? 0)}', style: const TextStyle(fontSize: 12, color: C.muted)),
          ]),
        ),
      if (acts.isNotEmpty) ...[
        const SizedBox(height: 14),
        Text('Quick Actions', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        LayoutBuilder(builder: (_, bc) {
          final w = (bc.maxWidth - 8) / 2;
          return Wrap(spacing: 8, runSpacing: 8, children: [
            for (final a in acts)
              SizedBox(
                width: w,
                child: Material(
                  color: a.$4,
                  borderRadius: BorderRadius.circular(18),
                  child: InkWell(
                    key: Key('qa-${a.$1}'),
                    borderRadius: BorderRadius.circular(18),
                    onTap: a.$7,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 11, 6, 11),
                      child: Row(children: [
                        Container(width: 40, height: 40, decoration: BoxDecoration(color: Colors.white.withValues(alpha: .75), borderRadius: BorderRadius.circular(13)), child: Icon(a.$2, color: a.$3, size: 22)),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(a.$5, maxLines: 2, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, height: 1.15)),
                            const SizedBox(height: 2),
                            Text(a.$6, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: C.muted, height: 1.2)),
                          ]),
                        ),
                        Icon(Icons.chevron_right_rounded, color: a.$3, size: 20),
                      ]),
                    ),
                  ),
                ),
              ),
          ]);
        }),
      ],
      card(
        key: const Key('car-info'),
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Key Information', style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          for (final r in info)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(width: 120, child: Text(r.$1, style: const TextStyle(fontSize: 13, color: C.muted))),
                Expanded(child: Text(r.$2, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: r.$1 == 'Status' ? (r.$2 == 'Inactive' ? C.red : C.greenDark) : C.ink))),
              ]),
            ),
        ]),
      ),
      if (x != null)
        card(
          key: const Key('car-recent'),
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(child: Text('Recent Activity', style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800))),
              TextButton(key: const Key('car-all'), onPressed: _history, child: Text('View All', style: const TextStyle(fontWeight: FontWeight.w700, color: C.goldInk))),
            ]),
            if (recent.isEmpty) Padding(padding: const EdgeInsets.only(top: 4, bottom: 6), child: Text('No entry of this car in these dates.', style: const TextStyle(color: C.muted)))
            else for (final r in recent) r.$2,
          ]),
        ),
    ];
  }
}

Widget _row(Key k, IconData ic, Color tint, Color bg, String a, String b, {Widget? end}) => Container(
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

Widget _fillRow(Key k, Map<String, dynamic> f) => _row(k, Icons.local_gas_station_rounded, C.amber, C.amberSoft, '${fmtNum(asNum(f['qty']))} ${_u(f['unit'])} · ${rupees(asNum(f['amount']))}',
    '${showDate('${f['date']}')} · ${f['fuel']}${asNum(f['km']) != null ? ' · KM ${fmtNum(asNum(f['km']))}' : ''}',
    end: Pill('${f['paidBy']}', color: f['cash'] == true ? C.amber : C.blue, bg: f['cash'] == true ? C.amberSoft : C.blueSoft));

Widget _logRow(Key k, Map<String, dynamic> r) => _row(k, Icons.speed_rounded, C.green, C.greenSoft,
    '${asNum(r['okm']) != null ? fmtNum(asNum(r['okm'])) : '–'} → ${asNum(r['ckm']) != null ? fmtNum(asNum(r['ckm'])) : '–'} · ${fmtNum(asNum(r['km']) ?? 0)} km',
    [showDate('${r['date']}'), '${r['shift']}', if ('${r['driver'] ?? ''}'.isNotEmpty) '${r['driver']}'].join(' · '),
    end: Pill('Log Book', color: C.green, bg: C.greenSoft));

Widget _maintRow(Key k, Map<String, dynamic> m) => _row(k, Icons.build_rounded, C.slate, C.slateSoft, '${m['garage'] ?? '–'}${'${m['billNo'] ?? ''}'.isNotEmpty ? ' · ${m['billNo']}' : ''} · ${rupees(asNum(m['amount']))}',
    [showDate('${m['date']}'), if (asNum(m['km']) != null) 'KM ${fmtNum(asNum(m['km']))}', ((m['works'] as List?) ?? const []).join(', ')].where((v) => v.isNotEmpty).join(' · '),
    end: m['service'] == true ? Pill('Service', color: C.green, bg: C.greenSoft) : null);

List<Map<String, dynamic>> _list(Object? l) => [for (final f in (l as List? ?? const []).whereType<Map>()) f.cast<String, dynamic>()];

/// A car's rows of one kind (fuel / log / maint) – as 3.86.0.
List<Widget> carRows(Map<String, dynamic> x, String tab) {
  Widget none(String t) => Padding(padding: const EdgeInsets.only(top: 12), child: Text(t, style: const TextStyle(color: C.muted)));
  if (tab == 'fuel') {
    final l = _list(x['fills']);
    if (l.isEmpty) return [none('No fill of this car in these dates.')];
    return [for (final (i, f) in l.indexed) _fillRow(Key('cf-$i'), f)];
  }
  if (tab == 'log') {
    if (x['log'] == null) return [Padding(padding: const EdgeInsets.only(top: 10), child: InfoLine('You have no access to the Log Book – ask the Admin.', help: false))];
    final l = _list(x['log']);
    if (l.isEmpty) return [none('No Log Book day of this car in these dates.')];
    return [for (final (i, r) in l.indexed) _logRow(Key('cl-$i'), r)];
  }
  if (x['maint'] == null) return [Padding(padding: const EdgeInsets.only(top: 10), child: InfoLine('You have no access to Maintenance – ask the Admin.', help: false))];
  final l = _list(x['maint']);
  if (l.isEmpty) return [none('No maintenance bill of this car in these dates.')];
  return [for (final (i, m) in l.indexed) _maintRow(Key('cm-$i'), m)];
}

/// A car's entries of every kind (or one: fuel / log / maint), the newest first: (date, its row).
List<(String, Widget)> carHistory(Map<String, dynamic> x, String kind) {
  final out = <(String, String, Widget)>[
    if (kind == 'all' || kind == 'fuel') for (final (i, f) in _list(x['fills']).indexed) ('${f['date']}', 'c', _fillRow(Key('ha-f$i'), f)),
    if (kind == 'all' || kind == 'log') for (final (i, r) in _list(x['log']).indexed) ('${r['date']}', 'b', _logRow(Key('ha-l$i'), r)),
    if (kind == 'all' || kind == 'maint') for (final (i, m) in _list(x['maint']).indexed) ('${m['date']}', 'a', _maintRow(Key('ha-m$i'), m)),
  ];
  out.sort((a, b) => b.$1.compareTo(a.$1) != 0 ? b.$1.compareTo(a.$1) : b.$2.compareTo(a.$2));
  return [for (final o in out) (o.$1, o.$3)];
}

/// (3.87.0) VEHICLE HISTORY: a car's fills, Log Book days and maintenance bills of any dates, one list, the newest first – all, or
/// one kind. The server's getCarDetail (each kind only for a person who may see it).
class VehicleHistoryScreen extends StatefulWidget {
  const VehicleHistoryScreen({super.key, required this.no});
  final String no;
  @override
  State<VehicleHistoryScreen> createState() => _VehicleHistoryScreenState();
}

class _VehicleHistoryScreenState extends State<VehicleHistoryScreen> {
  Map<String, dynamic>? d;
  String err = '', kind = 'all';
  int months = 3;
  int _seq = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  /// the first day of the month [months] − 1 months before today's
  String _from(String to) {
    var y = int.parse(to.substring(0, 4)), m = int.parse(to.substring(5, 7)) - (months - 1);
    while (m < 1) {
      m += 12;
      y--;
    }
    return '${y.toString().padLeft(4, '0')}-${m.toString().padLeft(2, '0')}-01';
  }

  Future<void> _load() async {
    final s = SessionScope.read(context), to = _today(s), my = ++_seq;
    setState(() {
      d = null;
      err = '';
    });
    try {
      final r = (await s.api.call('getCarDetail', [{'no': widget.no, 'from': _from(to), 'to': to}]) as Map).cast<String, dynamic>();
      if (mounted && my == _seq) setState(() => d = r);
    } catch (e) {
      if (mounted && my == _seq) setState(() => err = errText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final x = d, rows = x == null ? const <(String, Widget)>[] : carHistory(x, kind);
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.greenDeep,
        foregroundColor: Colors.white,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Vehicle History', style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 18)),
          Text(widget.no, style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 12.5)),
        ]),
      ),
      body: ListView(key: const Key('vh-list'), padding: const EdgeInsets.fromLTRB(16, 12, 16, 30), children: [
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final p in const [(1, 'This month'), (3, '3 months'), (12, '12 months')])
            ChoiceChip(key: Key('vh-p-${p.$1}'), selected: months == p.$1, onSelected: (_) {
              setState(() => months = p.$1);
              _load();
            }, label: Text(p.$2)),
        ]),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final k in const [('all', 'All'), ('fuel', 'Fuel'), ('log', 'Log Book'), ('maint', 'Maintenance')])
            ChoiceChip(key: Key('vh-k-${k.$1}'), selected: kind == k.$1, onSelected: (_) => setState(() => kind = k.$1), label: Text(k.$2)),
        ]),
        if (x != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text('${showDate('${x['from']}')} – ${showDate('${x['to']}')}', style: const TextStyle(fontSize: 12, color: C.muted))),
        if (err.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: InfoLine(err, bad: true)),
        if (x == null && err.isEmpty) const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator())),
        if (x != null && kind == 'log' && x['log'] == null) Padding(padding: const EdgeInsets.only(top: 10), child: InfoLine('You have no access to the Log Book – ask the Admin.', help: false)),
        if (x != null && kind == 'maint' && x['maint'] == null) Padding(padding: const EdgeInsets.only(top: 10), child: InfoLine('You have no access to Maintenance – ask the Admin.', help: false)),
        if (x != null && rows.isEmpty && !((kind == 'log' && x['log'] == null) || (kind == 'maint' && x['maint'] == null)))
          Padding(padding: const EdgeInsets.only(top: 14), child: Text('No entry of this car in these dates.', style: const TextStyle(color: C.muted))),
        for (final r in rows) r.$2,
      ]),
    );
  }
}

/// The search of the gallery: a part of the number (letters and digits only), the make, the model, the kind.
bool carMatches(Map<String, dynamic> c, String q) {
  final w = q.trim().toLowerCase();
  if (w.isEmpty) return true;
  String key(Object? v) => '${v ?? ''}'.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  final k = key(q);
  return (k.isNotEmpty && key(c['no']).contains(k)) || [c['make'], c['name'], c['type']].any((v) => '${v ?? ''}'.toLowerCase().contains(w));
}
