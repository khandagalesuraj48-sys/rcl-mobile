// (3.111.0) the face for attendance – the phone's rules, without a camera
import 'package:flutter_test/flutter_test.dart';
import 'package:rcl_mobile/core/face.dart';

FaceLook look({int n = 1, double yaw = 0, double pitch = 0, double eyes = 1}) => FaceLook(faces: n, yaw: yaw, pitch: pitch, leftEye: eyes, rightEye: eyes);

void main() {
  test('the registration: front, one side, the OTHER side, up or down, the OTHER of them – a photo held still passes only the first', () {
    final e = FaceEnrolSteps();
    expect(e.take(look(yaw: 25)), false, reason: 'not straight yet');
    expect(e.take(look()), true);
    for (var i = 0; i < 5; i++) {
      expect(e.take(look()), false, reason: 'a still face never gets further');
    }
    expect(e.step, 1);
    expect(e.take(look(yaw: -25)), true);
    expect(e.take(look(yaw: -30)), false, reason: 'the same side again');
    expect(e.take(look(yaw: 22)), true);
    expect(e.take(look(yaw: 30, pitch: 20)), false, reason: 'the head still turned');
    expect(e.take(look(pitch: 15)), true);
    expect(e.take(look(pitch: 18)), false, reason: 'the same way again');
    expect(e.take(look(pitch: -14)), true);
    expect([e.done, e.step], [true, 5]);
    expect(e.take(look()), false);
  });

  test('which side comes first does not matter; two faces or none never count', () {
    final e = FaceEnrolSteps()..take(look());
    expect(e.take(look(n: 2, yaw: 25)), false);
    expect(e.take(look(n: 0)), false);
    expect(e.take(look(yaw: 25)), true);
    expect(e.take(look(yaw: -25)), true);
    expect(e.take(look(pitch: -15)), true);
    expect(e.take(look(pitch: 15)), true);
    expect(e.done, true);
  });

  test('(3.140.0) a turn is taken only inside its window – too far is refused on the phone (the server could not match it); what to change is said', () {
    final e = FaceEnrolSteps();
    expect(e.hint(look(yaw: 25)).$1, 'Look straight at the phone');
    expect(e.take(look()), true);
    expect(e.take(look(yaw: 40)), false, reason: 'turned too far: the whole face is not seen');
    expect(e.hint(look(yaw: 40)).$1, contains('A little less'));
    expect(e.take(look(yaw: 10)), false);
    expect(e.hint(look(yaw: 10)).$1, 'Turn a little more');
    expect(e.hint(look(yaw: 20, pitch: 25)).$1, contains('Keep your chin level'));
    expect(e.take(look(yaw: 20)), true);
    expect(e.hint(look(yaw: 22)).$1, 'The OTHER side', reason: 'the same side again: told which way');
    expect(e.take(look(yaw: 22)), false);
    expect(e.take(look(yaw: -45)), false);
    expect(e.hint(look(yaw: -45)).$2, contains('थोडे कमी'));
    expect(e.take(look(yaw: -16)), true, reason: 'a small turn is enough');
    expect(e.hint(look(yaw: 25, pitch: 15)).$1, contains('Face the phone'));
    expect(e.take(look(pitch: 30)), false);
    expect(e.hint(look(pitch: 30)).$1, contains('A little less'));
    expect(e.hint(look(pitch: 5)).$1, 'A little more');
    expect(e.take(look(pitch: 12)), true);
    expect(e.hint(look(pitch: 14)).$1, 'Now the OTHER way');
    expect(e.take(look(pitch: -11)), true);
    expect([e.done, e.hint(look()).$1], [true, '']);
    expect(FaceEnrolSteps().hint(look(n: 0)), ('', '', ''), reason: 'no face: faceHint says it');
    expect(FaceEnrolSteps().hint(look()), ('', '', ''), reason: 'right: nothing to change');
  });

  test('every attendance: straight with open eyes → closed → open again; a photo (eyes always open) never passes', () {
    final b = FaceBlinkSteps();
    expect(b.take(look(eyes: .1)), false, reason: 'eyes closed at the start');
    expect(b.take(look(yaw: 20)), false);
    expect(b.take(look()), true);
    for (var i = 0; i < 10; i++) {
      expect(b.take(look()), false, reason: 'no blink: stays');
    }
    expect(b.take(look(eyes: .45)), false, reason: 'half closed is not closed');
    expect(b.take(look(eyes: .1)), true);
    expect(b.take(look(eyes: .9, yaw: 25)), false, reason: 'open, but turned away: the proof photo is from the front');
    expect(b.take(look(eyes: .9)), true);
    expect(b.done, true);
    final c = FaceBlinkSteps();
    expect(c.take(const FaceLook(faces: 1)), false, reason: 'the eyes are not seen (dark glasses): no start');
  });

  test('what is said when a look is not taken', () {
    expect(faceHint(look(n: 0)).$1, contains('No face'));
    expect(faceHint(look(n: 2)).$1, contains('Only you'));
    expect(faceHint(const FaceLook(faces: 1), eyes: true).$1, contains('eyes are not seen'));
    expect(faceHint(const FaceLook(faces: 1)), ('', ''));
    expect(faceHint(look(), eyes: true), ('', ''));
    expect(kFacePoses, ['front', 'left', 'right', 'up', 'down']);
  });
}
