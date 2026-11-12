/* THE FACE FOR ATTENDANCE – the camera screens (3.111.0, rcl-hr step 9). See core/face.dart for what is asked and why.
 *   FaceKit.kit.enrol  – the registration, once: he agrees, then five pictures (front, one side, the other, up / down, the other)
 *   FaceKit.kit.check  – every attendance: the face straight, the eyes closed for a moment, open again – that picture is the
 *                        proof photo of the punch
 * The camera takes a picture about twice a second and Google's ML Kit (on the phone) says where the head is and whether the
 * eyes are open; nothing is sent anywhere from here. WHO it is: the HR server, from the pictures this screen gives back.
 * A test sets its own FaceKit – no camera there. */
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/material.dart' as m show Text;
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../core/attend.dart' show smallJpg;
import '../core/face.dart';
import '../ui/t.dart';

String _t(String en, String mr) => Lang.i.pair(en, mr);

class FaceKit {
  static FaceKit kit = FaceKit();

  /// The five pictures of the registration (pose → JPEG), or null when he went back.
  Future<Map<String, Uint8List>?> enrol(BuildContext context) => Navigator.of(context).push<Map<String, Uint8List>>(MaterialPageRoute(builder: (_) => const FaceCamScreen(enrol: true)));

  /// The proof photo of a punch, taken after the blink – or null when he went back.
  Future<Uint8List?> check(BuildContext context, {String stamp = ''}) async {
    final r = await Navigator.of(context).push<Map<String, Uint8List>>(MaterialPageRoute(builder: (_) => FaceCamScreen(enrol: false, stamp: stamp)));
    return r?['front'];
  }
}

/// What ML Kit saw, as the rules read it: the biggest face; a second face counts only when it is of real size.
FaceLook lookOf(List<Face> faces) {
  if (faces.isEmpty) return const FaceLook(faces: 0);
  double area(Face f) => f.boundingBox.width * f.boundingBox.height;
  final list = [...faces]..sort((a, b) => area(b).compareTo(area(a)));
  final f = list.first, n = 1 + list.skip(1).where((x) => area(x) > area(f) * .35).length;
  return FaceLook(faces: n, yaw: f.headEulerAngleY ?? 0, pitch: f.headEulerAngleX ?? 0, leftEye: f.leftEyeOpenProbability ?? -1, rightEye: f.rightEyeOpenProbability ?? -1);
}

class FaceCamScreen extends StatefulWidget {
  const FaceCamScreen({super.key, required this.enrol, this.stamp = ''});
  final bool enrol;
  final String stamp;
  @override
  State<FaceCamScreen> createState() => _FaceCamScreenState();
}

class _FaceCamScreenState extends State<FaceCamScreen> {
  CameraController? cam;
  FaceDetector? det;
  final en = FaceEnrolSteps(), bl = FaceBlinkSteps();
  final shots = <String, Uint8List>{};
  String err = '', hint = '';
  bool agreed = false, stop = false, good = false;
  int faults = 0;

  @override
  void initState() {
    super.initState();
    agreed = !widget.enrol; // the registration starts when he has agreed
    if (agreed) _open();
  }

  @override
  void dispose() {
    stop = true;
    cam?.dispose();
    det?.close();
    super.dispose();
  }

  Future<void> _open() async {
    try {
      final all = await availableCameras();
      if (all.isEmpty) throw StateError('none');
      final lens = all.firstWhere((c) => c.lensDirection == CameraLensDirection.front, orElse: () => all.first);
      final c = CameraController(lens, ResolutionPreset.medium, enableAudio: false);
      await c.initialize();
      try {
        await c.setFlashMode(FlashMode.off);
      } catch (_) {/* a front camera without a flash */}
      if (!mounted) {
        await c.dispose();
        return;
      }
      det = FaceDetector(options: FaceDetectorOptions(enableClassification: true, performanceMode: FaceDetectorMode.accurate, minFaceSize: .2));
      setState(() => cam = c);
      unawaited(_loop());
    } catch (_) {
      if (mounted) setState(() => err = _t('The camera could not be opened – allow the camera for the app (Settings › Apps › RCL ERP › Permissions).', 'Camera उघडला नाही – app ला camera ची परवानगी द्या (Settings › Apps › RCL ERP › Permissions).'));
    }
  }

  bool get _done => widget.enrol ? en.done : bl.done;

  // a picture about twice a second, until every step is taken
  Future<void> _loop() async {
    while (mounted && !stop && !_done) {
      final c = cam, d = det;
      if (c == null || d == null) return;
      try {
        final x = await c.takePicture();
        final look = lookOf(await d.processImage(InputImage.fromFilePath(x.path)));
        final was = widget.enrol ? en.step : bl.step, took = widget.enrol ? en.take(look) : bl.take(look);
        if (took && (widget.enrol || bl.done)) {
          final jpg = smallJpg(await x.readAsBytes());
          if (jpg != null) shots[widget.enrol ? kFacePoses[was] : 'front'] = jpg;
        }
        try {
          await File(x.path).delete();
        } catch (_) {/* the phone clears its own cache */}
        faults = 0;
        if (!mounted) return;
        final h = took ? ('', '') : faceHint(look, eyes: !widget.enrol);
        setState(() {
          hint = _t(h.$1, h.$2);
          good = took;
          err = '';
        });
      } catch (_) {
        if (++faults >= 6 && mounted) setState(() => err = _t('The camera does not give a picture – go back and try again.', 'Camera चित्र देत नाही – मागे जाऊन पुन्हा करा.'));
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    if (mounted && _done && shots.length == (widget.enrol ? kFacePoses.length : 1)) Navigator.of(context).pop(Map<String, Uint8List>.of(shots));
  }

  @override
  Widget build(BuildContext context) {
    final ask = widget.enrol ? en.ask : bl.ask, step = widget.enrol ? en.step : bl.step;
    final names = widget.enrol ? const [('Front', 'समोर'), ('Side', 'बाजू'), ('Other side', 'दुसरी बाजू'), ('Up / down', 'वर / खाली'), ('Other way', 'उलट')] : const [('Straight', 'सरळ'), ('Eyes closed', 'डोळे मिटा'), ('Eyes open', 'डोळे उघडा')];
    Widget chip(int i) {
      final on = i == step, was = i < step;
      return Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 2),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: was ? const Color(0xFF35C98A) : on ? Colors.white : Colors.white.withValues(alpha: .12), borderRadius: BorderRadius.circular(12)),
          child: FittedBox(fit: BoxFit.scaleDown, child: Text(names[i].$1, mr: names[i].$2, maxLines: 1, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: was ? const Color(0xFF06301C) : on ? const Color(0xFF0F1F3D) : Colors.white70))),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF141B2E),
      appBar: AppBar(backgroundColor: const Color(0xFF141B2E), foregroundColor: Colors.white, elevation: 0, title: Text(widget.enrol ? 'Register your face' : 'Your face', mr: widget.enrol ? 'चेहरा नोंदवा' : 'तुमचा चेहरा', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700))),
      body: !agreed
          ? _agree()
          : Column(children: [
              if (widget.stamp.isNotEmpty) Padding(padding: const EdgeInsets.fromLTRB(24, 0, 24, 6), child: m.Text(widget.stamp, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 12.5))),
              Expanded(
                child: Center(
                  child: cam == null
                      ? (err.isEmpty ? const CircularProgressIndicator(color: Colors.white) : Padding(padding: const EdgeInsets.all(24), child: m.Text(err, key: const Key('face-err'), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.4))))
                      : Container(
                          width: 230,
                          height: 300,
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(borderRadius: const BorderRadius.all(Radius.elliptical(115, 150)), border: Border.all(color: good ? const Color(0xFF35C98A) : Colors.white54, width: 4)),
                          child: FittedBox(fit: BoxFit.cover, child: SizedBox(width: 230, height: 230 * (cam!.value.aspectRatio > 1 ? cam!.value.aspectRatio : 1 / cam!.value.aspectRatio), child: CameraPreview(cam!))),
                        ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 6, 24, 0),
                child: Text(ask.$1, mr: ask.$2, key: const Key('face-ask'), textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Montserrat', fontSize: 21, fontWeight: FontWeight.w800, color: Colors.white, height: 1.25)),
              ),
              SizedBox(
                height: 44,
                child: Padding(padding: const EdgeInsets.fromLTRB(24, 6, 24, 0), child: m.Text(cam != null && err.isNotEmpty ? err : hint, key: const Key('face-hint'), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFFFFD98A), fontSize: 13, height: 1.3))),
              ),
              Padding(padding: const EdgeInsets.fromLTRB(20, 4, 20, 10), child: Row(children: [for (var i = 0; i < names.length; i++) chip(i)])),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: .1), borderRadius: BorderRadius.circular(14)),
                  child: Text('No cap, helmet, mask or dark glasses. Stand in the light. Only you – nobody else in the picture.', mr: 'टोपी, helmet, mask किंवा काळा चष्मा नको. उजेडात उभे राहा. फक्त तुम्ही – दुसरे कोणी नको.', style: const TextStyle(color: Colors.white, fontSize: 12.5, height: 1.4)),
                ),
              ),
            ]),
    );
  }

  // before the registration: what is kept and why – he agrees himself
  Widget _agree() => ListView(key: const Key('face-agree'), padding: const EdgeInsets.fromLTRB(22, 10, 22, 30), children: [
        const Icon(Icons.face_retouching_natural_rounded, size: 72, color: Colors.white70),
        const SizedBox(height: 14),
        Text('Your face is registered once, for your attendance.', mr: 'तुमचा चेहरा हजेरीसाठी एकदाच नोंदवला जातो.', textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Montserrat', fontSize: 19, fontWeight: FontWeight.w800, color: Colors.white, height: 1.3)),
        const SizedBox(height: 14),
        for (final l in const [
          ('Five pictures are taken: from the front, to each side, up and down.', 'पाच photo काढले जातात: समोरून, दोन्ही बाजूंनी, वर आणि खाली.'),
          ('They are kept by the HR office of your company, in its private store. Your face is compared with them at every attendance.', 'ते तुमच्या company च्या HR office कडे, खाजगी जागेत राहतात. प्रत्येक हजेरीला तुमचा चेहरा त्यांच्याशी जुळवला जातो.'),
          ('They are used for attendance only. Only the HR Admin can reset them.', 'ते फक्त हजेरीसाठी वापरले जातात. फक्त HR Admin ते रद्द करू शकतो.'),
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Padding(padding: EdgeInsets.only(top: 3, right: 10), child: Icon(Icons.check_circle_rounded, size: 18, color: Color(0xFF35C98A))),
              Expanded(child: Text(l.$1, mr: l.$2, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4))),
            ]),
          ),
        const SizedBox(height: 16),
        SizedBox(
          height: 52,
          child: FilledButton(
            key: const Key('face-start'),
            style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF0F1F3D), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            onPressed: () {
              setState(() => agreed = true);
              _open();
            },
            child: Text('I agree – register my face', mr: 'मला मान्य आहे – माझा चेहरा नोंदवा', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F1F3D))),
          ),
        ),
      ]);
}
