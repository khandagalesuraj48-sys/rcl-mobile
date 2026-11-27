// (23-11-2026, pictures N6 / N7) FALCON from HR: which mess, how far, at it or not, and how FALCON is opened.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rcl_mobile/core/api.dart';
import 'package:rcl_mobile/core/falcon_link.dart';
import 'package:rcl_mobile/core/session.dart';

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
    expect(messNow(card, lat: 18.5212, lng: 73.8567, acc: 80)!.at, true, reason: '~100 m + at most 50 m of the phone\'s uncertainty');
    expect(messNow(card, lat: 18.5222, lng: 73.8567, acc: 80)!.at, false);
  });
  // (3.171.0 patch 2, his word of 25-11-2026: "20 km lamb hoto but app sangat hote 5 km … ekdm perfect") a rough reading (the mobile
  // towers, no GPS yet – kilometres off) gives no distance and never "at the mess"
  test('only an exact reading (± 100 m) gives the distance; a rough one: the mess without a distance', () {
    expect(messExact, 100);
    final rough = messNow(card, lat: 18.5203, lng: 73.8567, acc: 3000)!;
    expect([rough.metres, rough.at], [null, false]);
    final edge = messNow(card, lat: 18.55, lng: 73.8567, acc: 100)!;
    expect(distText(edge.metres!), '3.3 km');
    expect(messNow(card, lat: 18.55, lng: 73.8567, acc: 101)!.metres, isNull);
  });
  // (3.171.0 patch 3, his word of 25-11-2026: FALCON said 5.9 km, Google Maps 12 km) by road when FALCON has it, else the straight line
  // said as one – in the app's language
  test('how far: by road when known, else "in a straight line" – English, मराठी, हिंदी; the two places go with it', () {
    expect(messFar(5900, 12034, ''), '12 km by road');
    expect(messFar(5900, null, ''), '5.9 km in a straight line');
    expect(messFar(5900, 12034, 'mr'), 'रस्त्याने 12 km');
    expect(messFar(5900, null, 'mr'), 'सरळ रेषेत 5.9 km');
    expect(messFar(5900, 12034, 'hi'), 'सड़क से 12 km');
    expect(messFar(5900, null, 'hi'), 'सीधी रेखा में 5.9 km');
    final x = messNow(card, lat: 18.55, lng: 73.8567, acc: 10)!;
    expect([x.messLat, x.messLng, x.myLat, x.myLng], [18.5203, 73.8567, 18.55, 73.8567]);
    expect(messNow(card)!.messLat, isNull, reason: 'no place of his: nothing to measure');
  });
  test('no place of his: the first mess, no distance; no mess / no card: nothing', () {
    final x = messNow(card)!;
    expect([x.name, x.metres, x.at], ['Far Mess', null, false]);
    expect(messNow(null), isNull);
    expect(messNow({'messes': []}), isNull);
    expect(distText(40), '40 m');
    expect(distText(12500), '13 km');
  });
  // (3.169.0) no card: why – shown to the Super Admin only (lib/ui/mess_card.dart)
  test('no card: why is kept – no mess at the site, or HR\'s own words when FALCON is not connected', () async {
    final s = Session(Api(portalUrl: 'https://erp.test/portal', keep: MemoryKeep()));
    expect(await FalconMess.card(s, (b) async => {'site': 'VTR', 'messes': []}, fresh: true), isNull);
    expect(FalconMess.why, contains('no mess of VTR'));
    expect(await FalconMess.card(s, (b) async => throw Exception('FALCON is not connected to HR yet (FALCON_URL and FALCON_HR_SECRET in Vercel).'), fresh: true), isNull);
    expect(FalconMess.why, 'FALCON is not connected to HR yet (FALCON_URL and FALCON_HR_SECRET in Vercel).');
    expect(await FalconMess.card(s, (b) async => card, fresh: true), isNotNull);
    expect(FalconMess.why, '', reason: 'the card is there');
    FalconMess.forget();
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
  // (3.171.0 patch 2, his choice of 25-11-2026) FALCON inside this app FIRST – also when FALCON's app is on the phone; made ready behind
  // the app: straight on its home, without asking HR for a pass
  test('opening: inside this app first (FALCON\'s app only where it cannot run inside); made ready: no pass is asked', () async {
    const ch = MethodChannel('rcl/falcon');
    final good = 'v1.eyJjIjoiRTAwMDEyIn0.${'A' * 43}';
    var appAsked = 0, passes = 0;
    final inside = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(ch, (c) async {
      appAsked++;
      return true;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(ch, null));
    Future<Map<String, dynamic>> ask(Map<String, dynamic> b) async {
      passes++;
      return {'pass': good, 'web': 'https://falcon.test'};
    }

    Future<bool> inApp(String p) async {
      inside.add(p);
      return true;
    }

    expect(await FalconMess.open(ask, inside: inApp, ready: () => false), '');
    expect([inside, passes, appAsked], [[good], 1, 0], reason: 'not ready: HR\'s pass, inside this app – not FALCON\'s app');
    expect(await FalconMess.open(ask, inside: inApp, ready: () => true), '');
    expect([inside.last, passes, appAsked], ['', 1, 0], reason: 'made ready: on its home, no pass asked');
    expect(await FalconMess.open(ask, inside: (p) async => false, ready: () => false), '');
    expect(appAsked, 1, reason: 'FALCON cannot run inside here: its own app');
    expect((await FalconMess.pass(ask))?.pass, good);
    expect(await FalconMess.pass((b) async => {'pass': 'nonsense'}), isNull);
  });
}
