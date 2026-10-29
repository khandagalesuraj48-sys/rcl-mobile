/* (3.67.0, 29-10-2026: "jithe jithe type krun entry hotat ata prynt app madhe kuth hi ani new kahi yenar asel jyat type krun entry krne
 * aahe tithe voice mick banaw user apla voice madhe bolel … text madhe add krel ok hindi english marathi"; his answers: the app AND the
 * website; words and numbers) SPEAK INTO A BOX – every box of the app at once, and every box added later, with nothing to add to it:
 *   • while a box where an entry is typed is in use and the keyboard is up (a text, a number, a phone; never a password, nor a box
 *     that is only shown), a 🎙 sits above the keyboard on the right;
 *   • pressed: the phone's own speech recognition (voice.dart – Google's on Android, Apple's on an iPhone) listens in मराठी, हिंदी or
 *     English – the chips while it listens; the one chosen is kept on the phone, else the app's language;
 *   • what was said goes into the box AS IF TYPED – the box's own rules (capitals, digits only, its length) and its screen's reaction
 *     (totals, checks) as for typing: a number box gets the NUMBER ("साडे तीन हजार" → 3500, "बारा पॉइंट पाच" → 12.5 – numwords.dart,
 *     the web's same rules), a phone box the digits said, a text box the words at the cursor. */
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../core/lang.dart';
import '../core/numwords.dart';
import '../core/voice.dart' as voice;
import 'scope.dart';
import 'theme.dart';
import 't.dart';

const kVoiceLang = 'voice_lang';
const _kLangs = [('mr', 'मराठी'), ('hi', 'हिंदी'), ('en', 'English')];
const _say = {
  'hear': {'mr': 'ऐकत आहे… बोला', 'hi': 'सुन रहा है… बोलिए', 'en': 'Listening… speak'},
  'none': {'mr': 'काहीच ऐकू आले नाही – 🎙 दाबून पुन्हा बोला.', 'hi': 'कुछ सुनाई नहीं दिया – 🎙 दबाकर फिर बोलिए।', 'en': 'Nothing was heard – press 🎙 and speak again.'},
  'nonum': {'mr': 'आकडा समजला नाही – पुन्हा बोला', 'hi': 'संख्या समझ नहीं आई – फिर बोलिए', 'en': 'No number understood – speak again'},
  'mic': {'mr': 'Microphone ला परवानगी नाही – Settings › Apps › RCL ERP › Permissions › Microphone.', 'hi': 'Microphone की अनुमति नहीं – Settings › Apps › RCL ERP › Permissions › Microphone।', 'en': 'The microphone is not allowed – Settings › Apps › RCL ERP › Permissions › Microphone.'},
  'cant': {'mr': 'हा device ऐकू शकत नाही.', 'hi': 'यह device सुन नहीं सकता।', 'en': 'This device cannot listen.'},
  'tip': {'mr': 'बोलून लिहा', 'hi': 'बोलकर लिखें', 'en': 'Speak to type'},
};

/// Over every screen of the app (main.dart's builder).
class VoiceLayer extends StatefulWidget {
  const VoiceLayer({super.key, required this.child});
  final Widget child;
  @override
  State<VoiceLayer> createState() => _VoiceLayerState();
}

class _VoiceLayerState extends State<VoiceLayer> {
  EditableTextState? box;
  bool live = false, bad = false;
  String heard = '', msg = '';

  /// the listening of now – one let go (another language picked) is not put in the box
  int _gen = 0;

  /// the language chosen here (kept on the phone); '' = the app's
  static String chosen = '';
  static bool _read = false, _cant = false;

  String get lang => chosen.isNotEmpty ? chosen : (Lang.i.code == 'hi' || Lang.i.code == 'en' ? Lang.i.code : 'mr');
  String _t(String k) => _say[k]?[lang] ?? _say[k]?['en'] ?? '';

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_focus);
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_focus);
    super.dispose();
  }

  // the box in use – one where an entry is typed (not a password, not one only shown)
  void _focus() {
    EditableTextState? st;
    try {
      st = FocusManager.instance.primaryFocus?.context?.findAncestorStateOfType<EditableTextState>();
    } catch (_) {
      st = null;
    }
    final nb = st != null && st.mounted && !st.widget.obscureText && !st.widget.readOnly ? st : null;
    if (identical(nb, box)) return;
    void apply() {
      if (!mounted) return;
      if (live && !identical(nb, box)) voice.stopListening();
      setState(() {
        box = nb;
        if (nb == null && !live) {
          msg = '';
          heard = '';
        }
      });
    }

    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) => apply());
    } else {
      apply();
    }
  }

  Future<void> _keepLang(String l) async {
    chosen = l;
    try {
      await SessionScope.read(context).api.keep.write(kVoiceLang, l);
    } catch (_) {/* kept for now only */}
  }

  Future<void> _readLang() async {
    if (_read) return;
    _read = true;
    try {
      final v = await SessionScope.read(context).api.keep.read(kVoiceLang) ?? '';
      if (_kLangs.any((x) => x.$1 == v)) chosen = v;
    } catch (_) {}
  }

  Future<void> _listen() async {
    final st = box;
    if (st == null) return;
    if (live) {
      await voice.stopListening();
      return;
    }
    await _readLang();
    if (!mounted) return;
    final g = ++_gen;
    setState(() {
      live = true;
      bad = false;
      heard = '';
      msg = _t('hear');
    });
    try {
      final words = await voice.listenOnce(lang, (w) {
        if (mounted && live && g == _gen) setState(() => heard = w);
      });
      if (!mounted || g != _gen) return;
      setState(() => live = false);
      _put(st, words);
    } on voice.VoiceError catch (e) {
      if (e.code == 'none') _cant = true;
      if (mounted && g == _gen) {
        setState(() {
          live = false;
          bad = true;
          msg = _t(e.code == 'mic' ? 'mic' : 'cant');
        });
      }
    } catch (_) {
      if (mounted && g == _gen) {
        setState(() {
          live = false;
          bad = true;
          msg = _t('none');
        });
      }
    }
  }

  // what was heard → the box, as typed (its formatters, its length, its onChanged)
  void _put(EditableTextState st, String words) {
    final t = words.trim();
    if (t.isEmpty) {
      setState(() {
        bad = true;
        msg = _t('none');
      });
      return;
    }
    if (!st.mounted) return;
    final kb = st.widget.keyboardType.index;
    final kind = kb == TextInputType.phone.index ? 'digits' : kb == TextInputType.number.index ? 'number' : 'text';
    final v = st.textEditingValue;
    String text;
    int at;
    if (kind == 'text') {
      final sel = v.selection.isValid ? v.selection : TextSelection.collapsed(offset: v.text.length);
      final before = v.text.substring(0, sel.start), ins = '${before.isNotEmpty && !RegExp(r'\s$').hasMatch(before) ? ' ' : ''}$t';
      text = before + ins + v.text.substring(sel.end);
      at = before.length + ins.length;
    } else {
      final n = spokenNumber(t, digits: kind == 'digits');
      if (n.isEmpty) {
        setState(() {
          bad = true;
          heard = t;
          msg = _t('nonum');
        });
        return;
      }
      text = n;
      at = n.length;
    }
    st.userUpdateTextEditingValue(TextEditingValue(text: text, selection: TextSelection.collapsed(offset: at)), SelectionChangedCause.keyboard);
    setState(() {
      msg = '';
      heard = '';
      bad = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final kb = MediaQuery.viewInsetsOf(context).bottom;
    final on = box != null && box!.mounted && kb > 0 && !_cant;
    return Stack(children: [
      widget.child,
      if (on)
        Positioned(
          right: 12,
          bottom: kb + 12,
          left: 12,
          child: TextFieldTapRegion(
            child: Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
              if (msg.isNotEmpty || live)
                Container(
                  key: const Key('voice-tip'),
                  constraints: const BoxConstraints(maxWidth: 360),
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
                  decoration: BoxDecoration(color: const Color(0xFF101828), borderRadius: BorderRadius.circular(12), boxShadow: const [BoxShadow(color: Color(0x40101828), blurRadius: 14, offset: Offset(0, 4))]),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text(live ? '🎙 ${_t('hear')}' : msg, key: const Key('voice-msg'), style: TextStyle(color: bad ? const Color(0xFFFDA29B) : Colors.white, fontSize: 13.5, fontWeight: FontWeight.w600)),
                    if (heard.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 3), child: Text('“$heard”', key: const Key('voice-heard'), style: const TextStyle(color: Color(0xFFE4E7EC), fontSize: 13))),
                    const SizedBox(height: 6),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      for (final l in _kLangs)
                        GestureDetector(
                          key: Key('voice-l-${l.$1}'),
                          onTap: () async {
                            final was = live;
                            _gen++; // (what the listening of before still hears: not put in)
                            if (was) await voice.stopListening();
                            await _keepLang(l.$1);
                            if (!mounted) return;
                            setState(() {
                              live = false;
                              msg = was ? '' : _t('tip');
                              bad = false;
                            });
                            if (was) _listen();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
                            decoration: BoxDecoration(color: l.$1 == lang ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(99), border: Border.all(color: l.$1 == lang ? Colors.white : const Color(0xFF475467))),
                            child: Text(l.$2, style: TextStyle(fontSize: 13, color: l.$1 == lang ? const Color(0xFF101828) : Colors.white, fontWeight: FontWeight.w600)),
                          ),
                        ),
                    ]),
                  ]),
                ),
              Semantics(
                button: true,
                label: _t('tip'),
                child: GestureDetector(
                  key: const Key('voice-mic'),
                  onTap: _listen,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: live ? C.red : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: live ? C.red : C.line),
                      boxShadow: const [BoxShadow(color: Color(0x33101828), blurRadius: 10, offset: Offset(0, 3))],
                    ),
                    child: Icon(live ? Icons.mic_rounded : Icons.mic_none_rounded, color: live ? Colors.white : C.blue, size: 26),
                  ),
                ),
              ),
            ]),
          ),
        ),
    ]);
  }
}
