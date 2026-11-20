// (3.103.0) HR attendance on the phone – the rules of core/attend.dart (the same arithmetic as rcl-hr's lib/geo.js).
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:rcl_mobile/core/api.dart' show MemoryKeep;
import 'package:rcl_mobile/core/attend.dart';
import 'package:rcl_mobile/core/hr_cache.dart';

import 'fake_attend.dart';

WorkPlace place(Map<String, Object?> j) => WorkPlace.fromJson({'id': 'p', 'name': 'P', ...j})!;

void main() {
  test('where a person is: a point with its metres, an area, along the road – inside, or how many metres outside', () {
    expect((geoDist(18.5, 73.8, 18.5009, 73.8) - 100.08).abs() < 0.5, true);
    final c = place({'shape': 'circle', 'lat': 18.5, 'lng': 73.8, 'radius_m': 100});
    expect([placeCheck(c, 18.5005, 73.8).inside, placeCheck(c, 18.5005, 73.8).distance], [true, 0]);
    final out = placeCheck(c, 18.502, 73.8);
    expect(out.inside, false);
    expect((out.distance - 122).abs() <= 1, true);
    final sq = place({'shape': 'polygon', 'points': [[18.5, 73.8], [18.5, 73.81], [18.51, 73.81], [18.51, 73.8]]});
    expect(placeCheck(sq, 18.505, 73.805).inside, true);
    final o2 = placeCheck(sq, 18.505, 73.811);
    expect(o2.inside, false);
    expect((o2.distance - 105).abs() <= 2, true);
    final road = place({'shape': 'corridor', 'radius_m': 50, 'points': [[18.5, 73.8], [18.5, 73.9]]});
    expect([placeCheck(road, 18.5003, 73.85).inside, placeCheck(road, 18.501, 73.85).inside, placeCheck(road, 18.5, 73.91).inside], [true, false, false]);
    expect(placeCheck(place({'shape': 'polygon', 'points': [[1, 1]]}), 1, 1).inside, false, reason: 'a broken place lets nobody in');
    final far = place({'id': 'far', 'shape': 'circle', 'lat': 19.0, 'lng': 73.8, 'radius_m': 100});
    expect(nearestPlace([far, c], 18.5001, 73.8)!.place.id, 'p');
    expect(nearestPlace([far, c], 18.9, 73.8)!.place.id, 'far', reason: 'outside both: the nearer edge');
    expect(nearestPlace([], 18.5, 73.8), null);
  });

  test('IN or OUT next; a punch number; the day and the time in India', () {
    KeptPunch k(String kind, String at) => KeptPunch(cid: newPunchId(), kind: kind, lat: 1, lng: 1, acc: 5, atDevice: at, place: 'P');
    expect([nextKind('in', []), nextKind('out', []), nextKind('', [])], ['in', 'out', 'in']);
    expect(nextKind('in', [k('in', '2026-10-14T04:00:00.000Z')]), 'out', reason: 'what is kept on the phone counts');
    expect(nextKind('out', [k('in', '2026-10-14T04:00:00.000Z'), k('out', '2026-10-14T05:00:00.000Z')]), 'in');
    final a = newPunchId(), b = newPunchId();
    expect(RegExp(r'^[0-9a-f]{24}$').hasMatch(a), true);
    expect(a == b, false);
    expect(indiaDay(DateTime.utc(2026, 10, 14, 19).millisecondsSinceEpoch), '2026-10-15');
    expect(indiaTime('2026-10-14T04:10:00.000Z'), '09:40');
  });

  test('what the server is sent: taken with the network – its own clock; kept – the phone\'s clocks go with it; never the Developer flags of now', () {
    final p = KeptPunch(cid: 'abcdefabcdefabcdefabcdef', kind: 'out', lat: 18.52, lng: 73.85, acc: 9, atDevice: '2026-10-14T04:10:00.000Z', place: 'Site office', elapsed: 6000, anchorServer: 1000, anchorElapsed: 5000, deviceId: 'and-x', model: 'M', os: 'Android 15');
    final live = p.body(live: true), later = p.body(live: false);
    expect([live['action'], live['client_id'], live['kind'], live['accuracy_m'], live['device']], ['punch', 'abcdefabcdefabcdefabcdef', 'out', 9, {'id': 'and-x', 'model': 'M', 'os': 'Android 15'}]);
    expect(live.containsKey('offline'), false);
    expect([later['offline'], later['anchor_server'], later['anchor_elapsed'], later['elapsed'], later['at_device']], [true, 1000, 5000, 6000, '2026-10-14T04:10:00.000Z']);
    final back = KeptPunch.fromJson(p.toJson())!;
    expect(back.body(live: false), later, reason: 'kept and read again: the same punch');
    expect(KeptPunch.fromJson({'cid': 'short'}), null);
  });

  test('(3.134.0, rcl-hr step 14) the server\'s seal of its time goes back with a kept punch; the phone\'s key goes when it is sent – never in the file', () async {
    final p = KeptPunch(cid: 'abcdefabcdefabcdefabcdef', kind: 'in', lat: 18.52, lng: 73.85, acc: 9, atDevice: '2026-10-14T04:10:00.000Z', place: 'Site office', elapsed: 6000, anchorServer: 1000, anchorElapsed: 5000, anchorSig: 'seal-1', deviceId: 'and-x');
    expect(p.body(live: false)['anchor_sig'], 'seal-1');
    expect(p.body(live: true).containsKey('anchor_sig'), false, reason: 'with the network the server\'s own clock counts');
    expect(KeptPunch.fromJson(p.toJson())!.body(live: false)['anchor_sig'], 'seal-1', reason: 'kept and read again');
    expect(KeptPunch(cid: 'abcdefabcdefabcdefabcdef', kind: 'in', lat: 1, lng: 1, acc: 1, atDevice: '', place: '').body(live: false).containsKey('anchor_sig'), false, reason: 'an old kept punch: as before');
    expect((p.body(live: true, key: 'k' * 43)['device'] as Map)['key'], 'k' * 43);
    expect((p.body(live: true)['device'] as Map).containsKey('key'), false);
    expect(p.toJson().values.any((v) => '$v'.contains('k' * 43)), false, reason: 'the key is never in the punch\'s file');
    final keep = MemoryKeep(), k1 = await attendKey(keep), k2 = await attendKey(keep);
    expect([k1.length, k1 == k2, keep.data[kAttendKey] == k1], [43, true, true], reason: 'made once, kept in the safe, the same after');
    expect(await attendKey(MemoryKeep()) == k1, false, reason: 'another phone: another key');
  });

  // (3.154.0, asked 21-11-2026: "hr app madhe pn cache data banwayla hawa … new update ala tr new lagech disel … old data disu deu nko")
  test('what the HR pages read is kept: shown at once the next time, the server\'s answer always takes its place; per person; gone from memory at sign-out', () async {
    final kit = FakeAttendKit();
    AttendKit.kit = kit;
    HrCache.who = 'a@rcl.test|S1';
    expect(HrCache.now('myMonth:2026-10'), isNull);
    expect(await HrCache.read('myMonth:2026-10'), isNull, reason: 'nothing kept yet');
    HrCache.put('myMonth:2026-10', {'today': '2026-10-14', 'total': {'paid': 9}});
    expect(HrCache.now('myMonth:2026-10')!['total'], {'paid': 9}, reason: 'at once, from memory');
    await Future<void>.delayed(Duration.zero);
    expect(kit.files.keys.where((k) => k.startsWith('hrc_')).length, 1, reason: 'and on the phone');
    // the server says something new: that is what is kept from now on
    HrCache.put('myMonth:2026-10', {'today': '2026-10-14', 'total': {'paid': 10}});
    expect((await HrCache.read('myMonth:2026-10'))!['total'], {'paid': 10});
    await Future<void>.delayed(Duration.zero);
    // another person on this phone: nothing of the first
    HrCache.who = 'b@rcl.test|S1';
    expect(HrCache.now('myMonth:2026-10'), isNull);
    expect(await HrCache.read('myMonth:2026-10'), isNull);
    // the first again (the app opened anew): read from the phone
    HrCache.who = 'a@rcl.test|S1';
    expect(HrCache.now('myMonth:2026-10'), isNull, reason: 'memory was cleared');
    expect((await HrCache.read('myMonth:2026-10'))!['total'], {'paid': 10});
    // signed out: nothing in memory, nothing shown without a person
    HrCache.clear();
    expect(HrCache.now('myMonth:2026-10'), isNull);
    expect(await HrCache.read('myMonth:2026-10'), isNull);
    HrCache.put('x', {'a': 1});
    expect(HrCache.now('x'), isNull, reason: 'nobody signed in: nothing is kept');
  });

  test('kept on the phone: written with its photo, read in the order taken, gone when sent; one person\'s are not another\'s', () async {
    final kit = FakeAttendKit();
    AttendKit.kit = kit;
    final st = AttendStore('a@rcl.test|S1'), other = AttendStore('b@rcl.test|S1');
    final jpg = Uint8List.fromList([1, 2, 3]);
    await st.add(KeptPunch(cid: 'bbbbbbbbbbbbbbbbbbbbbbbb', kind: 'out', lat: 1, lng: 1, acc: 5, atDevice: '2026-10-14T05:00:00.000Z', place: 'P'), jpg);
    await st.add(KeptPunch(cid: 'aaaaaaaaaaaaaaaaaaaaaaaa', kind: 'in', lat: 1, lng: 1, acc: 5, atDevice: '2026-10-14T04:00:00.000Z', place: 'P'), jpg);
    expect([for (final k in await st.kept()) k.kind], ['in', 'out']);
    expect(await other.kept(), isEmpty);
    expect(await st.photo('aaaaaaaaaaaaaaaaaaaaaaaa'), jpg);
    await st.remove('aaaaaaaaaaaaaaaaaaaaaaaa');
    expect([for (final k in await st.kept()) k.cid], ['bbbbbbbbbbbbbbbbbbbbbbbb']);
    expect(await st.photo('aaaaaaaaaaaaaaaaaaaaaaaa'), null);
    await st.keep({'now': 123, 'next': 'in'}, 77);
    final l = await st.last();
    expect([l!['now'], l['anchor_elapsed'], l['read_at']], [123, 77, kit.clock]);
    expect(await other.last(), null);
  });

  test('the selfie made small: the longer side 720, a JPEG; not a picture = nothing', () {
    final big = Uint8List.fromList(img.encodeJpg(img.Image(width: 1600, height: 1200)));
    final small = img.decodeJpg(smallJpg(big)!)!;
    expect([small.width, small.height], [720, 540]);
    final tall = img.decodeJpg(smallJpg(Uint8List.fromList(img.encodePng(img.Image(width: 300, height: 1440))))!)!;
    expect([tall.width, tall.height], [150, 720]);
    expect(smallJpg(Uint8List.fromList([1, 2, 3])), null);
  });

  // (3.135.0, rcl-hr step 15) a work place given to him for IN only / OUT only (a server of before: both)
  test('a work place for IN, OUT or both – kept with the day; a server of before means both', () {
    final both = place({'shape': 'circle', 'lat': 18.5, 'lng': 73.8, 'radius_m': 100});
    expect([both.canIn, both.canOut, both.may('in'), both.may('out')], [true, true, true, true]);
    final outOnly = place({'shape': 'circle', 'lat': 18.5, 'lng': 73.8, 'radius_m': 100, 'can_in': false, 'can_out': true});
    expect([outOnly.may('in'), outOnly.may('out')], [false, true]);
    final back = WorkPlace.fromJson(outOnly.toJson())!;
    expect([back.canIn, back.canOut], [false, true], reason: 'kept on the phone with the day (offline)');
  });
}
