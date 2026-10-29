/* (3.67.0) SPEAK INTO A BOX – the 🎙 over every box of the app: shown while a box is in use and the keyboard is up (not a password,
 * not a box only shown); what is heard goes in AS IF TYPED (onChanged, the box's formatters); a number box gets the number; a phone
 * box the digits; the language chips (the listening of before not put in). The phone's listening is the tests' own. */
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rcl_mobile/core/voice.dart' as voice;
import 'package:rcl_mobile/ui/voice_box.dart';

void main() {
  testWidgets('the 🎙: a number box gets the number ("साडे तीन हजार" → 3500), a text box the words at the cursor, a phone box the digits; none in a password or a box only shown; none without the keyboard; the chips', (t) async {
    final l0 = voice.listenOnce, s0 = voice.stopListening;
    addTearDown(() {
      voice.listenOnce = l0;
      voice.stopListening = s0;
    });
    t.view.viewInsets = const FakeViewPadding(bottom: 900); // (the keyboard up)
    addTearDown(t.view.reset);
    final langs = <String>[], replies = <Object>[];
    Completer<String>? hold;
    voice.listenOnce = (lang, heard) async {
      langs.add(lang);
      final r = replies.removeAt(0);
      if (r is Completer<String>) {
        hold = r;
        heard('ऐक');
        return r.future;
      }
      heard('$r');
      return '$r';
    };
    voice.stopListening = () async {
      final h = hold;
      if (h != null && !h.isCompleted) h.complete('');
    };
    final num = TextEditingController(), txt = TextEditingController(), ph = TextEditingController(), pw = TextEditingController(), up = TextEditingController();
    final changed = <String>[];
    await t.pumpWidget(MaterialApp(
      builder: (c, child) => VoiceLayer(child: child!),
      home: Scaffold(
        body: ListView(children: [
          TextField(key: const Key('n'), controller: num, keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: changed.add),
          TextField(key: const Key('t'), controller: txt, onChanged: changed.add),
          TextField(key: const Key('ph'), controller: ph, keyboardType: TextInputType.phone),
          TextField(key: const Key('up'), controller: up, inputFormatters: [TextInputFormatter.withFunction((o, v) => v.copyWith(text: v.text.toUpperCase()))]),
          TextField(key: const Key('pw'), controller: pw, obscureText: true),
          const TextField(key: Key('ro'), readOnly: true),
        ]),
      ),
    ));
    Future<void> say(String box, Object words) async {
      replies.add(words);
      await t.tap(find.byKey(Key(box)));
      await t.pump();
      await t.tap(find.byKey(const Key('voice-mic')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 50));
    }

    expect(find.byKey(const Key('voice-mic')), findsNothing, reason: 'no box in use');
    await say('n', 'साडे तीन हजार');
    expect(num.text, '3500');
    expect(changed.last, '3500', reason: 'as typed: the box\'s onChanged');
    expect(langs.last, 'mr', reason: 'मराठी by itself (the app\'s language not chosen)');
    await say('n', 'बारा पॉइंट पाच लिटर');
    expect(num.text, '12.5', reason: 'a number box: the number, the whole box');
    await say('n', 'सिमेंट');
    expect(num.text, '12.5', reason: 'no number heard: the box as it was');
    expect(find.text('आकडा समजला नाही – पुन्हा बोला'), findsOneWidget);
    expect(find.text('“सिमेंट”'), findsOneWidget);
    await say('t', 'सिमेंट बॅग');
    expect(txt.text, 'सिमेंट बॅग');
    expect(changed.last, 'सिमेंट बॅग');
    await say('t', 'ACC कंपनी');
    expect(txt.text, 'सिमेंट बॅग ACC कंपनी', reason: 'at the cursor, after a space');
    await say('ph', 'नऊ आठ दोन शून्य एक');
    expect(ph.text, '98201', reason: 'a phone box: the digits said');
    await say('up', 'acc');
    expect(up.text, 'ACC', reason: 'the box\'s own rules (its formatter) as for typing');
    for (final k in ['pw', 'ro']) {
      await t.tap(find.byKey(Key(k)));
      await t.pump();
      expect(find.byKey(const Key('voice-mic')), findsNothing, reason: k);
    }
    // the chips: English pressed while it listens – listened again in English; what the first one heard is not put in
    replies.addAll([Completer<String>(), 'twenty five']);
    await t.tap(find.byKey(const Key('n')));
    await t.pump();
    await t.tap(find.byKey(const Key('voice-mic')));
    await t.pump();
    expect(find.byKey(const Key('voice-l-mr')), findsOneWidget);
    expect(find.text('🎙 ऐकत आहे… बोला'), findsOneWidget);
    await t.tap(find.byKey(const Key('voice-l-en')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
    expect(langs.sublist(langs.length - 2), ['mr', 'en']);
    expect(num.text, '25');
    // no keyboard: no 🎙 (a computer, the tests of the other screens)
    t.view.viewInsets = FakeViewPadding.zero;
    await t.pump();
    expect(find.byKey(const Key('voice-mic')), findsNothing);
  });
}
