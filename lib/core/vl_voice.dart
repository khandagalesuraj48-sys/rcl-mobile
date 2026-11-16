/* (3.132.0, Mechanical update-263 – his answer of 16-11-2026: "दोन्ही एकत्र"; the plan's "आवाज 60 दिवस") THE VOICE OF A CLOSING:
 * while the phone listens to the work said aloud (speech_to_text – as before), the same words are recorded (package record: AAC in
 * .m4a, one channel, 32 kbps – about 240 KB a minute; at most 2 MB). The file goes with the closing (vlVoice → vlClose's audio) and
 * the server removes it after 60 days.
 *   Some phones do not give the microphone to both at once:
 *     – the recording comes out silent → it is let go; the words and the texts are kept as before;
 *     – the LISTENING heard nothing while the recording has the voice → this phone is noted ("not both") and from then on only listens
 *       (the voice of that time is still kept; the driver presses the mic again or types).
 *   An iPhone only listens: its listening is not put at risk (a recording there would share the same sound session). */
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'api.dart';

class VlVoice {
  VlVoice._();
  static final i = VlVoice._();

  /// (a test) no microphone on a test computer – what [stop] gives instead (null: nothing recorded)
  @visibleForTesting
  static Uint8List? Function()? fake;
  static const kNotBoth = 'vl_voice_not_both';

  AudioRecorder? _r;
  String? _path;
  double _loud = -160;
  Timer? _amp;
  bool _on = false;

  /// May this phone record while it listens? (Android; not marked "not both")
  Future<bool> allowed(Keep keep) async {
    if (fake != null) return (await keep.read(kNotBoth)) != '1';
    if (!Platform.isAndroid) return false;
    try {
      return (await keep.read(kNotBoth)) != '1';
    } catch (_) {
      return true;
    }
  }

  /// This phone gave the microphone only to the recording: from now on it only listens.
  Future<void> notBoth(Keep keep) async {
    try {
      await keep.write(kNotBoth, '1');
    } catch (_) {}
  }

  Future<void> start() async {
    if (_on) return;
    _on = true;
    if (fake != null) return;
    try {
      final r = _r ??= AudioRecorder();
      if (!await r.hasPermission()) {
        _on = false;
        return;
      }
      final d = await getTemporaryDirectory();
      _path = '${d.path}/vl_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      _loud = -160;
      await r.start(const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 32000, sampleRate: 16000, numChannels: 1), path: _path!);
      _amp = Timer.periodic(const Duration(milliseconds: 400), (_) async {
        try {
          final a = await r.getAmplitude();
          if (a.current > _loud) _loud = a.current;
        } catch (_) {}
      });
    } catch (_) {
      _path = null;
      _on = false;
    }
  }

  /// The recording – null when there was none, it was silent (the listening had the microphone) or it is too big.
  Future<Uint8List?> stop() async {
    if (!_on) return null;
    _on = false;
    if (fake != null) return fake!();
    _amp?.cancel();
    _amp = null;
    final r = _r, p = _path;
    _path = null;
    if (r == null || p == null) return null;
    try {
      final out = await r.stop();
      final f = File(out ?? p);
      if (!await f.exists()) return null;
      final b = await f.readAsBytes();
      try {
        await f.delete();
      } catch (_) {}
      if (b.length < 2000 || b.length > 2 * 1024 * 1024 || _loud < -50) return null;      // silent / nothing / too big
      return b;
    } catch (_) {
      return null;
    }
  }
}
