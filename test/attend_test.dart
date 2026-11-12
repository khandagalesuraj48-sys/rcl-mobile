// (3.103.0) HR attendance on the phone – the rules of core/attend.dart (the same arithmetic as rcl-hr's lib/geo.js).
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:rcl_mobile/core/attend.dart';

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
}
