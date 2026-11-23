// (3.168.0) a photo the phone kept when it closed the app while the camera was open – given once, only to the screen it was for
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rcl_mobile/core/lost_photo.dart';

void main() {
  test('a kept photo goes only to the screen it was for, and only once', () async {
    expect(await LostPhoto.take('hrdoc:'), isNull, reason: 'nothing kept');
    LostPhoto.put('hrdoc:aadhaar:d9', 'a.jpg', Uint8List.fromList([1, 2, 3]));
    expect(await LostPhoto.take('other:'), isNull, reason: 'not for this screen – it stays');
    final g = await LostPhoto.take('hrdoc:');
    expect([g?.what, g?.name, g?.bytes.length], ['hrdoc:aadhaar:d9', 'a.jpg', 3]);
    expect(await LostPhoto.take('hrdoc:'), isNull, reason: 'given once');
  });

  test('without a keep (tests, a computer) nothing is written and the check finds nothing', () async {
    LostPhoto.keep = null;
    await LostPhoto.expect('hrdoc:pan:');
    await LostPhoto.done();
    await LostPhoto.check();
    expect(await LostPhoto.take('hrdoc:'), isNull);
  });
}
