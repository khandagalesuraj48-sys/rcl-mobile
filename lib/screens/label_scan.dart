/* A MACHINERY LABEL SCANNED (3.14.0) – the web's qrArrive in the app's own screen: the label's machinery, then what to do for it –
 * Diesel Issue (the machinery already in the box), Log Book entry (not for a Debit Basis machinery), its diesel ledger. Only
 * what he may do is offered. The labels are made in Asset Master → ⋮ → QR labels.
 * (3.18.2, asked 17-10-2026: "QR scanner … tya war click keli ki camera open hotoy, scanner open hoyla hawa") the scan button
 * opens the app's OWN SCANNER – the camera's live picture with a square; a QR code in it is read at once, nothing to press (no
 * photo is taken and nothing is sent: the code is read on the phone, mobile_scanner / ML Kit); the torch for a dark place. */
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart' show MobileScanner, MobileScannerController, MobileScannerState, MobileScannerErrorCode, BarcodeFormat, DetectionSpeed, TorchState;

import '../core/imports.dart' show findMachine;
import '../core/kinds.dart';
import '../core/qr_scan.dart';
import '../core/report_defs.dart' show kDieselReports;
import '../ui/scope.dart';
import '../ui/t.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'forms.dart' show newEntry;
import 'logbook.dart' show LogForm;
import 'report_screen.dart' show openReport;

/// The scanner → the label → its machinery → the question. [onSaved]: a Diesel Issue was saved (Home reads its figures again).
Future<void> scanMachineLabel(BuildContext context, {VoidCallback? onSaved}) async {
  final s = SessionScope.read(context);
  String? text;
  try {
    text = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const QrScanScreen()));
  } catch (_) {
    if (context.mounted) toast(context, 'The label could not be read on this phone.', bad: true);
    return;
  }
  if (text == null || text.isEmpty || !context.mounted) return;
  final id = labelMachine(text);
  if (id.isEmpty) {
    toast(context, 'This QR code is not a machinery label of the ERP.', bad: true);
    return;
  }
  final f = findMachine([for (final m in s.machines) m.m], id);
  final m = f == null ? null : s.machine('${f['id']}');
  if (m == null) {
    toast(context, 'The machinery of this label ($id) is not in the Master.', bad: true);
    return;
  }
  final sub = <String>[];
  for (final x in [m.name.isNotEmpty && m.name != m.id ? m.name : '', m.type, m.owner]) {
    if (x.isNotEmpty && !sub.any((y) => y.toLowerCase() == x.toLowerCase())) sub.add(x);
  }
  final ledger = kDieselReports.where((d) => d.key == 'ledger').firstOrNull;
  final acts = <(String, String, IconData)>[
    if (s.canEdit('Diesel Issue')) ('diesel', 'Diesel Issue', Icons.local_gas_station_rounded),
    if (s.canEdit('Log Book') && !m.debit) ('log', 'Log Book entry', Icons.menu_book_rounded),
    if (ledger != null && s.canSee('Reports')) ('ledger', 'Its diesel ledger', Icons.receipt_long_rounded),
  ];
  final go = await showModalBottomSheet<String>(
    context: context,
    builder: (c) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Scanned label', style: const TextStyle(fontSize: 12.5, color: C.muted, fontWeight: FontWeight.w600)),
          Text(m.id, key: const Key('ql-no'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          if (sub.isNotEmpty) Text(sub.join(' · '), style: const TextStyle(fontSize: 14, color: C.muted)),
          const SizedBox(height: 14),
          if (acts.isEmpty) Text('You have no page to open for this machinery.', style: const TextStyle(color: C.muted)),
          for (final (i, a) in acts.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: i == 0
                  ? FilledButton.icon(key: Key('ql-${a.$1}'), onPressed: () => Navigator.pop(c, a.$1), icon: Icon(a.$3), label: Text(a.$2))
                  : OutlinedButton.icon(key: Key('ql-${a.$1}'), onPressed: () => Navigator.pop(c, a.$1), icon: Icon(a.$3), label: Text(a.$2)),
            ),
        ]),
      ),
    ),
  );
  if (go == null || !context.mounted) return;
  switch (go) {
    case 'diesel':
      if (await newEntry(context, kKinds.firstWhere((k) => k.key == 'issue'), no: m.id)) onSaved?.call();
    case 'log':
      await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => LogForm(date: s.today, no: m.id)));
    case 'ledger':
      await openReport(context, ledger!, no: m.id, run: true);
  }
}

/* ---------------- (3.18.2) the app's own scanner ---------------- */

/// The QR scanner: the back camera's live picture, a square to hold the label in; the first QR code seen is given back (closed:
/// null). The torch for a dark place. Nothing is pressed to read a code.
class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  /// (a test) the camera's place: a test puts its own picture there, which "sees" a code by calling [found].
  static Widget Function(void Function(String code) found)? cameraForTest;

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  MobileScannerController? cam;
  bool done = false;

  @override
  void initState() {
    super.initState();
    if (QrScanScreen.cameraForTest == null) cam = MobileScannerController(formats: const [BarcodeFormat.qrCode], detectionSpeed: DetectionSpeed.noDuplicates);
  }

  @override
  void dispose() {
    cam?.dispose();
    super.dispose();
  }

  /// A code seen: given back once (the camera keeps seeing it while the screen closes).
  void _found(String code) {
    if (done || code.trim().isEmpty || !mounted) return;
    done = true;
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop(code);
  }

  Widget _camera() {
    final test = QrScanScreen.cameraForTest;
    if (test != null) return test(_found);
    return MobileScanner(
      controller: cam,
      onDetect: (capture) {
        for (final b in capture.barcodes) {
          final v = b.rawValue ?? '';
          if (v.trim().isNotEmpty) {
            _found(v);
            return;
          }
        }
      },
      errorBuilder: (context, e) => _CamError(e.errorCode),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: const Text('Scan the machinery label', mr: 'मशीनचे QR label स्कॅन करा', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
          actions: [
            if (cam != null)
              ValueListenableBuilder<MobileScannerState>(
                valueListenable: cam!,
                builder: (context, st, _) => st.torchState == TorchState.unavailable
                    ? const SizedBox.shrink()
                    : IconButton(
                        key: const Key('qr-torch'),
                        tooltip: tr('Torch'),
                        icon: Icon(st.torchState == TorchState.on ? Icons.flash_on_rounded : Icons.flash_off_rounded, color: Colors.white),
                        onPressed: () async {
                          try {
                            await cam!.toggleTorch();
                          } catch (_) {}
                        },
                      ),
              ),
          ],
        ),
        body: Stack(fit: StackFit.expand, children: [
          _camera(),
          const IgnorePointer(child: CustomPaint(painter: _QrFrame())),
          Positioned(
            left: 24,
            right: 24,
            bottom: 36,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(color: Colors.black.withValues(alpha: .6), borderRadius: BorderRadius.circular(16)),
              child: const Text('Hold the QR label inside the square – it is read by itself.', mr: 'QR label चौकटीत धरा – तो आपोआप वाचला जातो.',
                  textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600, height: 1.35)),
            ),
          ),
        ]),
      );
}

/// The square in the middle: the rest of the picture darker, white corners.
class _QrFrame extends CustomPainter {
  const _QrFrame();
  @override
  void paint(Canvas canvas, Size size) {
    final side = (size.shortestSide * .7).clamp(180.0, 340.0).toDouble();
    final r = Rect.fromCenter(center: size.center(Offset.zero).translate(0, -24), width: side, height: side);
    final hole = RRect.fromRectAndRadius(r, const Radius.circular(22));
    canvas.drawPath(Path.combine(PathOperation.difference, Path()..addRect(Offset.zero & size), Path()..addRRect(hole)), Paint()..color = const Color(0x99000000));
    final p = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    const l = 36.0;
    for (final (c, dx, dy) in [(r.topLeft, 1.0, 1.0), (r.topRight, -1.0, 1.0), (r.bottomLeft, 1.0, -1.0), (r.bottomRight, -1.0, -1.0)]) {
      canvas.drawPath(
          Path()
            ..moveTo(c.dx, c.dy + dy * l)
            ..lineTo(c.dx, c.dy)
            ..lineTo(c.dx + dx * l, c.dy),
          p..strokeJoin = StrokeJoin.round);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// The camera could not be used: why, and what to do.
class _CamError extends StatelessWidget {
  const _CamError(this.code);
  final MobileScannerErrorCode code;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.no_photography_rounded, color: Colors.white70, size: 48),
            const SizedBox(height: 14),
            Text(
              switch (code) {
                MobileScannerErrorCode.permissionDenied => 'The camera is not allowed for the app. Allow it: phone Settings → Apps → RCL ERP → Permissions → Camera, then scan again.',
                MobileScannerErrorCode.unsupported => 'This phone has no camera the scanner can use.',
                _ => 'The camera could not be started – close this and scan again.',
              },
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 15.5, height: 1.4),
            ),
            const SizedBox(height: 18),
            OutlinedButton(
              key: const Key('qr-close'),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white54)),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ]),
        ),
      );
}
