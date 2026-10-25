/* (3.34.0, Mechanical update-153) THE ATTACHMENTS OF A LOG BOOK ENTRY – the app's own screens for the web's attachment box:
 *   AttachStrip   – in the Log Book entry (new or changed): the files as tiles, "📷 Camera", "🖼 Gallery", "📄 PDF"; a tile opens
 *                   the file; ✎ corrects a photo not sent yet; × takes a file out (a file kept by the server stays there – nothing
 *                   is deleted). The files are sent when the entry is saved (logbook.dart).
 *   AttViewer     – the files big, one by one (a PDF opens in the phone's PDF reader from its 15-minute link).
 *   AttEditor     – the correction of a photo: ⟲ ⟳, straighten, the four corners, ✂ suggested cut (shown – used on "Use this"),
 *                   Whole photo, Reset; Original quality; Use the original file.
 *   CaptureScreen – "Scan with Mobile": the web's QR code read by the app's scanner → the same person, the same site; the photos
 *                   taken here are sent and show on the computer, which saves them with the entry (capClaim / uploadAttachment /
 *                   capAdd – the web's actions). */
import 'dart:io' show Platform;
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api.dart';
import '../core/attach.dart';
import '../core/device.dart';
import '../core/format.dart';
import '../ui/scope.dart';
import '../ui/t.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import '../core/applock.dart';

/// The site's number of attachments of one entry (Settings → Rules of the site; 10 unless set).
int attMaxOf(Map<String, dynamic> rules) {
  final n = (rules['attachMax'] as num?)?.toInt() ?? 10;
  return n < 1 || n > 20 ? 10 : n;
}

/// The files the person picks: the camera (one photo), the gallery (several) or the phone's files (PDFs) – a test sets its own.
Future<List<({String name, Uint8List bytes})>> Function(String how, int room) pickAttFiles = _pickFiles;

Future<List<({String name, Uint8List bytes})>> _pickFiles(String how, int room) async {
  if (room < 1) return [];
  if (how == 'pdf') {
    final r = await AppLock.whileOutside(() => FilePicker.pickFiles(type: FileType.custom, allowedExtensions: const ['pdf'], allowMultiple: true, withData: true));
    if (r == null) return [];
    return [for (final f in r.files.take(room)) if (f.bytes != null) (name: f.name, bytes: f.bytes!)];
  }
  var camera = how == 'camera';
  if (onComputer) camera = false;
  if (camera && Platform.isAndroid) {
    final st = await Permission.camera.request();
    if (!st.isGranted) throw ApiError('Allow the camera for RCL ERP (Settings › Apps › RCL ERP › Permissions), then try again.');
  }
  final picker = ImagePicker();
  final List<XFile> xs;
  if (camera) {
    final x = await AppLock.whileOutside(() => picker.pickImage(source: ImageSource.camera, preferredCameraDevice: CameraDevice.rear));
    xs = [if (x != null) x];
  } else if (room == 1) {
    final x = await AppLock.whileOutside(() => picker.pickImage(source: ImageSource.gallery));
    xs = [if (x != null) x];
  } else {
    xs = await AppLock.whileOutside(() => picker.pickMultiImage(limit: room));
  }
  return [for (final x in xs.take(room)) (name: x.name, bytes: await x.readAsBytes())];
}

/// Tiles of the files + the buttons that add them. [files] is changed in place; [onChanged] after every change.
class AttachStrip extends StatefulWidget {
  const AttachStrip({super.key, required this.files, required this.max, required this.onChanged, this.enabled = true});
  final List<AttFile> files;
  final int max;
  final VoidCallback onChanged;
  final bool enabled;
  @override
  State<AttachStrip> createState() => _AttachStripState();
}

class _AttachStripState extends State<AttachStrip> {
  String msg = '';
  bool bad = false;
  List<AttFile> get fs => widget.files;

  void _say(String t, {bool isBad = false}) => setState(() {
        msg = t;
        bad = isBad;
      });

  Future<void> _add(String how) async {
    final room = widget.max - fs.length;
    if (room <= 0) {
      _say('An entry keeps at most ${widget.max} attachments – remove one first.', isBad: true);
      return;
    }
    List<({String name, Uint8List bytes})> got;
    try {
      got = await pickAttFiles(how, room);
    } catch (e) {
      _say(errText(e), isBad: true);
      return;
    }
    for (final g in got.take(room)) {
      final f = AttFile(name: g.name, state: 'make', src: g.bytes, mime: attSniff(g.bytes).isEmpty ? 'image/jpeg' : attSniff(g.bytes));
      if (attSniff(g.bytes).isEmpty) {
        _say('“${g.name}” is not a photo or a PDF – left out.', isBad: true);
        continue;
      }
      setState(() => fs.add(f));
      widget.onChanged();
      try {
        await attMake(f);
      } catch (e) {
        f.state = 'err';
        f.err = errText(e);
      }
      if (!mounted) return;
      if (f.sha.isNotEmpty && fs.any((x) => !identical(x, f) && x.sha == f.sha)) {
        fs.remove(f);
        _say('“${f.name}” is already attached – it is not added twice.');
      }
      setState(() {});
      widget.onChanged();
    }
  }

  Future<void> _fix(AttFile f) async {
    final ed = await Navigator.of(context).push<AttEdit>(MaterialPageRoute(builder: (_) => AttEditor(file: f)));
    if (ed == null || !mounted) return;
    setState(() {
      f.ed = ed;
      f.state = 'make';
    });
    try {
      await attMake(f);
    } catch (e) {
      f.state = 'err';
      f.err = errText(e);
    }
    if (!mounted) return;
    if (f.sha.isNotEmpty && fs.any((x) => !identical(x, f) && x.sha == f.sha)) {
      fs.remove(f);
      _say('This photo is already attached – it is not added twice.');
    }
    setState(() {});
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final full = fs.length >= widget.max, on = widget.enabled;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(child: Text(fs.isEmpty ? 'None yet – optional.' : '${fs.length} of ${widget.max} · ${attSize(fs.fold<int>(0, (a, x) => a + x.size))}', key: const Key('att-count'), style: const TextStyle(fontSize: 12.5, color: C.muted))),
      ]),
      if (fs.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Wrap(spacing: 10, runSpacing: 10, children: [for (final (i, f) in fs.indexed) _tile(i, f)]),
        ),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        OutlinedButton.icon(key: const Key('att-cam'), onPressed: on && !full ? () => _add('camera') : null, icon: const Icon(Icons.photo_camera_rounded, size: 18), label: const Text('Camera')),
        OutlinedButton.icon(key: const Key('att-gal'), onPressed: on && !full ? () => _add('gallery') : null, icon: const Icon(Icons.photo_library_rounded, size: 18), label: const Text('Gallery')),
        OutlinedButton.icon(key: const Key('att-pdf'), onPressed: on && !full ? () => _add('pdf') : null, icon: const Icon(Icons.picture_as_pdf_rounded, size: 18), label: const Text('PDF')),
      ]),
      if (msg.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(msg, key: const Key('att-msg'), style: TextStyle(fontSize: 12.5, color: bad ? C.red : C.muted))),
    ]);
  }

  Widget _tile(int i, AttFile f) {
    final busy = f.state == 'make' || f.state == 'send';
    final thumb = f.pdf
        ? Container(color: C.redSoft, alignment: Alignment.center, child: const Text('PDF', style: TextStyle(fontWeight: FontWeight.w800, color: C.red, fontSize: 18)))
        : f.bytes != null
            ? Image.memory(f.bytes!, fit: BoxFit.cover, gaplessPlayback: true)
            : f.url.isNotEmpty
                ? Image.network(f.url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.image_outlined, color: C.muted))
                : const Icon(Icons.image_outlined, color: C.muted);
    return SizedBox(
      key: Key('att-tile-$i'),
      width: 96,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Stack(children: [
          GestureDetector(
            onTap: busy ? null : () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => AttViewer(files: fs, start: i))),
            child: Container(
              width: 96,
              height: 82,
              decoration: BoxDecoration(color: C.slateSoft, borderRadius: BorderRadius.circular(10), border: Border.all(color: f.state == 'err' ? C.red : f.state == 'ok' ? C.greenChip : C.line, width: 1.5)),
              clipBehavior: Clip.antiAlias,
              child: busy ? const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5))) : thumb,
            ),
          ),
          if (f.state == 'ok' || f.state == 'err')
            Positioned(left: 4, top: 4, child: CircleAvatar(radius: 10, backgroundColor: Colors.white, child: Text(f.state == 'ok' ? '✓' : '!', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: f.state == 'ok' ? C.green : C.red)))),
          if (widget.enabled && !busy)
            Positioned(
              right: 2,
              top: 2,
              child: InkWell(
                key: Key('att-rm-$i'),
                onTap: () {
                  setState(() => fs.remove(f));
                  if (f.sent) _say('Taken out of this entry when it is saved (the file itself is kept – nothing is deleted).');
                  widget.onChanged();
                },
                child: const CircleAvatar(radius: 12, backgroundColor: Color(0xB8101828), child: Icon(Icons.close_rounded, size: 15, color: Colors.white)),
              ),
            ),
          if (widget.enabled && !busy && !f.pdf && f.src != null && (f.state == 'new' || f.state == 'err'))
            Positioned(
              right: 30,
              top: 2,
              child: InkWell(key: Key('att-fix-$i'), onTap: () => _fix(f), child: const CircleAvatar(radius: 12, backgroundColor: Color(0xB8101828), child: Icon(Icons.edit_rounded, size: 14, color: Colors.white))),
            ),
        ]),
        const SizedBox(height: 3),
        Text(f.name.isEmpty ? (kAttKinds[f.mime] ?? 'file') : f.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: C.muted)),
        if (f.err.isNotEmpty) Text(f.err, maxLines: 3, style: const TextStyle(fontSize: 11, color: C.red)),
        if (f.note.isNotEmpty) Text(f.note, maxLines: 3, style: const TextStyle(fontSize: 11, color: C.amber)),
      ]),
    );
  }
}

/// The files big, one by one.
class AttViewer extends StatefulWidget {
  const AttViewer({super.key, required this.files, this.start = 0, this.title = 'Attachments'});
  final List<AttFile> files;
  final int start;
  final String title;
  @override
  State<AttViewer> createState() => _AttViewerState();
}

class _AttViewerState extends State<AttViewer> {
  late int i = widget.start;
  late final PageController pc = PageController(initialPage: widget.start);

  @override
  void dispose() {
    pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.files[i];
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white, title: Text('${i + 1} / ${widget.files.length} · ${f.name.isEmpty ? (kAttKinds[f.mime] ?? 'file') : f.name}${f.by.isNotEmpty ? ' · ${f.by}' : ''}', maxLines: 2, style: const TextStyle(fontSize: 14.5))),
      body: PageView.builder(
        key: const Key('att-view'),
        controller: pc,
        itemCount: widget.files.length,
        onPageChanged: (k) => setState(() => i = k),
        itemBuilder: (_, k) {
          final x = widget.files[k];
          if (x.pdf) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.picture_as_pdf_rounded, color: Colors.white, size: 72),
                const SizedBox(height: 10),
                Text(x.name, style: const TextStyle(color: Colors.white)),
                const SizedBox(height: 14),
                if (x.url.isNotEmpty)
                  FilledButton.icon(onPressed: () => launchUrl(Uri.parse(x.url), mode: LaunchMode.externalApplication), icon: const Icon(Icons.open_in_new_rounded), label: const Text('Open the PDF'))
                else
                  Text('Sent with the entry when it is saved.', style: const TextStyle(color: Colors.white70)),
              ]),
            );
          }
          final Widget pic = x.bytes != null
              ? Image.memory(x.bytes!)
              : x.url.isNotEmpty
                  ? Image.network(x.url, errorBuilder: (_, __, ___) => Text('The picture could not be opened.', style: const TextStyle(color: Colors.white)))
                  : Text('The picture could not be opened.', style: const TextStyle(color: Colors.white));
          return Center(child: InteractiveViewer(maxScale: 6, child: pic));
        },
      ),
    );
  }
}

/// The correction of a photo – returns it (null = Cancel).
class AttEditor extends StatefulWidget {
  const AttEditor({super.key, required this.file});
  final AttFile file;
  @override
  State<AttEditor> createState() => _AttEditorState();
}

class _AttEditorState extends State<AttEditor> {
  late int rot = widget.file.ed.rot;
  late double ang = widget.file.ed.ang;
  late List<List<double>> q = [for (final p in widget.file.ed.q ?? kAttFull) [p[0], p[1]]];
  late bool hq = widget.file.ed.hq, orig = widget.file.ed.orig;
  Uint8List? prev;
  int pw = 1, ph = 1;
  String msg = '';
  bool reading = true;

  @override
  void initState() {
    super.initState();
    _preview();
  }

  Future<void> _preview() async {
    setState(() => reading = true);
    try {
      final r = await attCompute(attPreview, <String, Object?>{'src': widget.file.src!, 'rot': rot, 'ang': ang});
      if (!mounted) return;
      setState(() {
        prev = r['jpg'] as Uint8List;
        pw = r['w'] as int;
        ph = r['h'] as int;
        reading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          reading = false;
          msg = errText(e);
        });
      }
    }
  }

  void _turn(int by) {
    rot = ((rot + by) % 360 + 360) % 360;
    q = [for (final p in kAttFull) [p[0], p[1]]];
    _preview();
  }

  Future<void> _suggest() async {
    final p = prev;
    if (p == null) return;
    final s = await attCompute(attSuggest, p);
    if (!mounted) return;
    setState(() {
      if (s != null) {
        q = s;
        msg = 'Suggested cut shown – move a corner if needed, then press "Use this" (or "Whole photo").';
      } else {
        msg = 'No clear edge of a paper was found – drag the corners yourself.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Correct the photo', style: const TextStyle(fontWeight: FontWeight.w700))),
      body: ListView(padding: const EdgeInsets.fromLTRB(14, 8, 14, 20), children: [
        Text('Drag the 4 corners to the edges of the paper (a photo taken at an angle becomes straight).', style: const TextStyle(fontSize: 13, color: C.muted)),
        const SizedBox(height: 10),
        AspectRatio(
          aspectRatio: pw / ph,
          child: LayoutBuilder(builder: (c, box) {
            final w = box.maxWidth, h = box.maxHeight;
            if (prev == null) return Container(color: C.slateSoft, alignment: Alignment.center, child: reading ? const CircularProgressIndicator() : Text(msg));
            return Opacity(
              opacity: orig ? .5 : 1,
              child: Stack(clipBehavior: Clip.none, children: [
                Positioned.fill(child: Image.memory(prev!, fit: BoxFit.fill, gaplessPlayback: true)),
                if (!orig) Positioned.fill(child: CustomPaint(painter: _QuadPainter(q))),
                if (!orig)
                  for (var k = 0; k < 4; k++)
                    Positioned(
                      left: q[k][0] * w - 16,
                      top: q[k][1] * h - 16,
                      child: GestureDetector(
                        key: Key('att-h$k'),
                        onPanUpdate: (d) => setState(() {
                          q[k] = [(q[k][0] + d.delta.dx / w).clamp(0.0, 1.0).toDouble(), (q[k][1] + d.delta.dy / h).clamp(0.0, 1.0).toDouble()];
                          msg = '';
                        }),
                        child: Container(width: 32, height: 32, decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: C.blue, width: 3), boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 4)])),
                      ),
                    ),
              ]),
            );
          }),
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          OutlinedButton(key: const Key('att-l'), onPressed: orig ? null : () => _turn(-90), child: const Text('⟲')),
          OutlinedButton(key: const Key('att-r'), onPressed: orig ? null : () => _turn(90), child: const Text('⟳')),
          OutlinedButton.icon(key: const Key('att-auto'), onPressed: orig || prev == null ? null : _suggest, icon: const Icon(Icons.content_cut_rounded, size: 18), label: const Text('Suggest cut')),
          OutlinedButton(key: const Key('att-full'), onPressed: orig ? null : () => setState(() => q = [for (final p in kAttFull) [p[0], p[1]]]), child: const Text('Whole photo')),
          OutlinedButton(
              key: const Key('att-reset'),
              onPressed: () {
                setState(() {
                  ang = 0;
                  hq = false;
                  orig = false;
                  msg = '';
                });
                _turn(-rot);
              },
              child: const Text('Reset')),
        ]),
        Row(children: [
          Text('Straighten', style: const TextStyle(fontSize: 13)),
          Expanded(
            child: Slider(
              key: const Key('att-ang'),
              min: -15,
              max: 15,
              divisions: 60,
              value: ang.clamp(-15.0, 15.0).toDouble(),
              label: '${ang > 0 ? '+' : ''}${fmtNum(ang)}°',
              onChanged: orig ? null : (v) => setState(() => ang = v),
              onChangeEnd: (_) => _preview(),
            ),
          ),
          Text('${ang > 0 ? '+' : ''}${fmtNum(ang)}°', style: const TextStyle(fontSize: 13)),
        ]),
        SwitchListTile(key: const Key('att-hq'), contentPadding: EdgeInsets.zero, value: hq, onChanged: orig ? null : (v) => setState(() => hq = v), title: const Text('Original quality (sharper, bigger file)')),
        SwitchListTile(
            key: const Key('att-orig'),
            contentPadding: EdgeInsets.zero,
            value: orig,
            onChanged: (v) => setState(() {
                  orig = v;
                  msg = v ? 'The file is sent exactly as it is (up to 3 MB) – turning and cutting are not used.' : '';
                }),
            title: const Text('Use the original file as it is (no correction)')),
        if (msg.isNotEmpty) Text(msg, key: const Key('att-emsg'), style: const TextStyle(fontSize: 12.5, color: C.blue)),
      ]),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel'))),
            const SizedBox(width: 10),
            Expanded(
                child: FilledButton(
                    key: const Key('att-yes'),
                    onPressed: () => Navigator.pop(context, AttEdit(rot: rot, ang: ang, q: attIsFull(q) ? null : q, hq: hq, orig: orig)),
                    child: const Text('Use this'))),
          ]),
        ),
      ),
    );
  }
}

class _QuadPainter extends CustomPainter {
  _QuadPainter(this.q);
  final List<List<double>> q;
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..moveTo(q[0][0] * size.width, q[0][1] * size.height);
    for (final p in q.skip(1)) {
      path.lineTo(p[0] * size.width, p[1] * size.height);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = const Color(0x221E63D6));
    canvas.drawPath(path, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = C.blue);
  }

  @override
  bool shouldRepaint(_QuadPainter old) => true;
}

/// "Scan with Mobile" – the computer's QR code read by the app's scanner ([code] = <id>.<token>).
class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key, required this.code});
  final String code;
  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  Map<String, dynamic>? s0;
  String err = '', msg = '', phone = '';
  bool busy = false, claiming = true;
  int sent = 0;
  final List<AttFile> files = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _claim());
  }

  Future<String> _phoneId() async {
    final s = SessionScope.read(context);
    var id = await s.api.keep.read('cap_phone') ?? '';
    if (!RegExp(r'^[A-Za-z0-9-]{8,40}$').hasMatch(id)) {
      final r = math.Random.secure();
      id = 'p-${List.generate(24, (_) => r.nextInt(16).toRadixString(16)).join()}';
      await s.api.keep.write('cap_phone', id);
    }
    return id;
  }

  Future<void> _claim() async {
    final s = SessionScope.read(context);
    try {
      phone = await _phoneId();
      final r = ((await s.api.call('capClaim', [{'code': widget.code, 'phone': phone}])) as Map).cast<String, dynamic>();
      if (!mounted) return;
      setState(() {
        s0 = r;
        claiming = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          err = errText(e);
          claiming = false;
        });
      }
    }
  }

  int get _max => ((s0?['max'] as num?) ?? 10).toInt();
  int get _have => ((s0?['have'] as num?) ?? 0).toInt();

  Future<void> _send() async {
    final s = SessionScope.read(context);
    if (!files.any((f) => f.state == 'new' || f.state == 'err')) {
      setState(() => msg = files.isEmpty ? 'Take a photo first.' : 'Everything is sent ✓ – save the entry on the computer.');
      return;
    }
    setState(() {
      busy = true;
      msg = '';
    });
    final before = files.where((f) => f.state == 'ok').map((f) => f.sha).toSet();
    final bad = await attSendAll(s.api, files, () {
      if (mounted) setState(() {});
    });
    final fresh = [for (final f in files) if (f.state == 'ok' && !before.contains(f.sha)) f.sha];
    try {
      if (fresh.isNotEmpty) {
        final r = ((await s.api.call('capAdd', [{'code': widget.code, 'phone': phone, 'shas': fresh}])) as Map).cast<String, dynamic>();
        sent += fresh.length;
        s0?['have'] = r['have'];
      }
      if (!mounted) return;
      setState(() {
        busy = false;
        msg = bad.isNotEmpty ? bad : '$sent sent ✓ – they show on the computer. Save the entry there.';
      });
    } catch (e) {
      for (final f in files.where((x) => fresh.contains(x.sha))) {
        f.state = 'err';
        f.err = errText(e);
      }
      if (mounted) {
        setState(() {
          busy = false;
          msg = errText(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = '${s0?['label'] ?? ''}';
    return Scaffold(
      appBar: AppBar(title: TwoLang('Scan with Mobile', 'मोबाइलने स्कॅन', size: 18, weight: FontWeight.w700)),
      body: claiming
          ? const Center(child: CircularProgressIndicator())
          : ListView(key: const Key('cap-list'), padding: const EdgeInsets.fromLTRB(16, 10, 16, 24), children: [
              if (err.isNotEmpty) ...[
                InfoLine(err, bad: true),
                const SizedBox(height: 10),
                Text('On the computer press "Scan with Mobile" again for a new QR code, and scan it here (signed in as the same person, at the same site).', style: const TextStyle(color: C.muted)),
              ] else ...[
                Text('Photos for the computer', style: const TextStyle(fontSize: 12.5, color: C.muted, fontWeight: FontWeight.w600)),
                Text(label.isEmpty ? 'Log Book entry' : label, key: const Key('cap-label'), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('Take the photos and press Send – they show on the computer, which saves them with the entry.', style: const TextStyle(fontSize: 13, color: C.muted)),
                const SizedBox(height: 12),
                AttachStrip(files: files, max: math.max(0, _max - _have) + files.where((f) => f.state == 'ok').length, enabled: !busy, onChanged: () => setState(() {})),
                const SizedBox(height: 14),
                FilledButton.icon(
                  key: const Key('cap-send'),
                  onPressed: busy ? null : _send,
                  icon: busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)) : const Icon(Icons.send_rounded),
                  label: Text(busy ? 'Sending…' : 'Send to the computer'),
                ),
                if (msg.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Text(msg, key: const Key('cap-msg'), style: TextStyle(color: msg.contains('✓') ? C.green : C.red, fontWeight: FontWeight.w600))),
              ],
            ]),
    );
  }
}
