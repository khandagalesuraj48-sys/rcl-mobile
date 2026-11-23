// (23-11-2026, pictures N6 / N7) FALCON from HR: which mess, how far, at it or not, and how FALCON is opened.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rcl_mobile/core/falcon_link.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final card = {
    'messes': [
      {'name': 'Far Mess', 'lat': 18.60, 'lng': 73.86, 'radius_m': 100, 'meal': {'meal': 'lunch', 'from': '12:00', 'to': '14:30', 'now': true}, 'dishes': ['Rice']},
      {'name': 'Camp Mess', 'lat': 18.5203, 'lng': 73.8567, 'radius_m': 100, 'meal': {'meal': 'lunch', 'from': '12:00', 'to': '14:30', 'now': true}, 'dishes': ['Dal', 'Rice']},
      {'name': 'No Place Mess', 'lat': null, 'lng': null, 'radius_m': null, 'meal': null, 'dishes': []},
    ],
  };
  test('the nearest mess with a place; at it inside its metres (the phone\'s own uncertainty up to 50 m)', () {
    final x = messNow(card, lat: 18.52, lng: 73.8567, acc: 12)!;
    expect([x.name, x.at, x.metres! < 50, x.meal, x.now, x.to], ['Camp Mess', true, true, 'lunch', true, '14:30']);
    final away = messNow(card, lat: 18.55, lng: 73.8567)!;
    expect([away.name, away.at, distText(away.metres!)], ['Camp Mess', false, '3.3 km']);
    expect(messNow(card, lat: 18.5212, lng: 73.8567, acc: 200)!.at, true, reason: '~100 m + at most 50 m of the phone\'s uncertainty');
    expect(messNow(card, lat: 18.5222, lng: 73.8567, acc: 200)!.at, false);
  });
  test('no place of his: the first mess, no distance; no mess / no card: nothing', () {
    final x = messNow(card)!;
    expect([x.name, x.metres, x.at], ['Far Mess', null, false]);
    expect(messNow(null), isNull);
    expect(messNow({'messes': []}), isNull);
    expect(distText(40), '40 m');
    expect(distText(12500), '13 km');
  });
  test('opening: HR\'s pass → FALCON\'s own app; not there → FALCON\'s web with the pass; a wrong answer is never opened', () async {
    const ch = MethodChannel('rcl/falcon');
    final good = 'v1.eyJjIjoiRTAwMDEyIn0.${'A' * 43}';
    var app = false;
    Uri? web;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(ch, (c) async => c.method == 'open' && app);
    addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(ch, null));
    Future<bool> launch(Uri u) async {
      web = u;
      return true;
    }

    app = true;
    expect(await FalconMess.open((b) async => {'pass': good, 'web': 'https://falcon.test'}, launch: launch), '');
    expect(web, isNull, reason: 'FALCON\'s app took it');
    app = false;
    expect(await FalconMess.open((b) async => {'pass': good, 'web': 'https://falcon.test'}, launch: launch), '');
    expect(web.toString(), 'https://falcon.test/#hrpass=${Uri.encodeComponent(good)}');
    web = null;
    expect(await FalconMess.open((b) async => {'pass': good, 'web': 'http://falcon.test'}, launch: launch), 'FALCON is not on this phone.');
    expect(await FalconMess.open((b) async => {'pass': 'nonsense', 'web': 'https://falcon.test'}, launch: launch), 'FALCON could not be opened – try again.');
    expect(web, isNull);
    expect(await FalconMess.open((b) async => throw Exception('Your mobile number is not in your HR record.'), launch: launch), 'Your mobile number is not in your HR record.');
  });
}
