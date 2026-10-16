/* THE ASSISTANT'S VOICE (3.15.0) – the web's aiSay / aiListen on the phone: an answer said aloud (🔊, and in a talk) and a question
 * heard (the microphone: "talk with the assistant – you speak, it answers aloud"), in मराठी, हिंदी or English. The phone's own
 * speech (Android / iPhone) does it: flutter_tts and speech_to_text. Both are replaceable (the tests have their own). */
import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'assistant.dart' show aiSpeakable, kAiSpeech;

/// The listening could not start or was refused – the words say why (in his language).
class VoiceError implements Exception {
  VoiceError(this.code);

  /// 'mic' (the microphone is not allowed), 'none' (this phone cannot listen).
  final String code;
}

FlutterTts? _tts;
SpeechToText? _stt;
bool _sttReady = false;

/// Says the start of [text] aloud in [lang] (the web's aiSay: aiSpeakable, the language's voice – Marathi falls back to a
/// Hindi voice when the phone has none – a little faster than usual); completes when it has been said.
Future<void> Function(String text, String lang) sayAloud = _say;

/// Stops what is being said.
Future<void> Function() stopSaying = _stopSay;

/// Listens once in [lang] and gives the words heard ('' = nothing was said); [heard] shows the words while he speaks.
Future<String> Function(String lang, void Function(String words) heard) listenOnce = _listen;

/// Stops the listening.
Future<void> Function() stopListening = _stopListen;

Future<void> _say(String text, String lang) async {
  final words = aiSpeakable(text, lang);
  if (words.isEmpty) return;
  try {
    final t = _tts ??= FlutterTts();
    var code = kAiSpeech[lang] ?? 'en-IN';
    if (lang == 'mr' && await t.isLanguageAvailable(code) != true) code = 'hi-IN';
    await t.setLanguage(code);
    await t.setSpeechRate(.52); // (the web: rate 1.05 of the usual)
    await t.awaitSpeakCompletion(true);
    await t.speak(words).timeout(const Duration(seconds: 60));
  } catch (_) {/* a phone that says nothing must not leave the talk hanging */}
}

Future<void> _stopSay() async {
  try {
    await _tts?.stop();
  } catch (_) {}
}

Completer<String>? _cur;
String _heard = '';
String? _why;

void _finish() {
  final c = _cur;
  if (c != null && !c.isCompleted) c.complete(_heard);
}

Future<String> _listen(String lang, void Function(String words) heard) async {
  final s = _stt ??= SpeechToText();
  if (!_sttReady) {
    _sttReady = await s.initialize(
      onStatus: (st) {
        if (st == 'done') _finish();
        if (st == 'notListening') Future.delayed(const Duration(milliseconds: 700), _finish); // (the last words may still come)
      },
      onError: (SpeechRecognitionError e) {
        if (e.errorMsg.contains('permission')) _why = 'mic';
        if (e.permanent) _finish();
      },
    );
    if (!_sttReady) throw VoiceError(await s.hasPermission ? 'none' : 'mic');
  }
  final c = _cur = Completer<String>();
  _heard = '';
  _why = null;
  await s.listen(
    onResult: (SpeechRecognitionResult r) {
      _heard = r.recognizedWords;
      heard(_heard);
      if (r.finalResult) _finish();
    },
    listenOptions: SpeechListenOptions(
      partialResults: true,
      cancelOnError: true,
      listenMode: ListenMode.dictation,
      localeId: (kAiSpeech[lang] ?? 'en-IN').replaceAll('-', '_'),
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
    ),
  );
  final words = await c.future.timeout(const Duration(seconds: 40), onTimeout: () => _heard);
  final why = _why;
  if (why != null && words.isEmpty) throw VoiceError(why);
  return words;
}

Future<void> _stopListen() async {
  try {
    await _stt?.cancel();
  } catch (_) {}
  _finish();
}
