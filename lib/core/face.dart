/* THE FACE FOR ATTENDANCE – the phone's part (3.111.0, rcl-hr step 9; asked 12-11-2026: "realtime face recogniz ani geofence he 2
 * ni haway yatle ek jari nahi zal attendence mark nahi honar … face first time register krawa lagel user la left right up down as
 * bghayla laun … nantr … employee saral face dakhwel ani match zala tr sign in" – and, chosen by him, a blink at every attendance).
 * WHO the face is, is decided by the HR server (it compares the picture with the registered face). The phone only sees to it
 * that a LIVING face is in front of the camera:
 *   registration – five pictures: from the front, the head turned to one side, to the other, up, down (a photo cannot turn)
 *   attendance   – the face straight, the eyes closed for a moment, opened again (a photo cannot do that); the picture taken
 *                  then is the proof photo of the punch
 * Google's ML Kit (on the phone, nothing sent anywhere) says only: how many faces, how the head is turned, are the eyes open.
 * It does not know anybody. The rules below are plain numbers so that they are tested without a camera. */

/// What one look of the camera showed.
class FaceLook {
  const FaceLook({required this.faces, this.yaw = 0, this.pitch = 0, this.leftEye = -1, this.rightEye = -1});
  final int faces;

  /// the head turned to a side / up-down, degrees (0 = straight)
  final double yaw, pitch;

  /// how open each eye is, 0 … 1 (−1 = the phone could not say)
  final double leftEye, rightEye;

  bool get one => faces == 1;
  bool get straight => one && yaw.abs() <= 12 && pitch.abs() <= 12;
  bool get eyesKnown => leftEye >= 0 && rightEye >= 0;
  bool get eyesOpen => eyesKnown && leftEye >= .6 && rightEye >= .6;
  bool get eyesClosed => eyesKnown && leftEye <= .3 && rightEye <= .3;
}

/// The five pictures of the registration, in the server's order.
const kFacePoses = ['front', 'left', 'right', 'up', 'down'];

/// THE REGISTRATION, step by step. "One side" and "the other side" (and up / down) are told by the sign the phone gives – which
/// side is which differs between phones, so the first turn decides and the second must be the opposite one.
class FaceEnrolSteps {
  int step = 0; // 0 front · 1 one side · 2 the other side · 3 up or down · 4 the other of them · 5 done
  double _side = 0, _tilt = 0;
  bool get done => step >= 5;

  /// (3.140.0, asked 18-11-2026: "other side madhe jast wel ghetey … face madhe user la problem alach nahi pahije") A TURN IS TAKEN
  /// ONLY INSIDE ITS WINDOW: enough to show that the head turns (a photo cannot), little enough that the whole face is still seen
  /// and matches the picture from the front on the HR server (a head turned too far: "no face" or "not the same face" there).
  /// Degrees, as the phone measures them.
  static const sideMin = 15.0, sideMax = 32.0, tiltMin = 10.0, tiltMax = 25.0, level = 20.0;

  /// What is asked now (English, Marathi).
  (String, String) get ask => switch (step) {
        0 => ('Look straight at the phone', 'Phone कडे सरळ बघा'),
        1 => ('Turn your head to one side', 'डोके एका बाजूला वळवा'),
        2 => ('Now to the other side', 'आता दुसऱ्या बाजूला'),
        3 => ('Lift your chin up – or look down', 'हनुवटी वर करा – किंवा खाली बघा'),
        4 => ('Now the other way', 'आता उलट बाजूला'),
        _ => ('Done', 'झाले'),
      };

  /// Does this look fill the step asked now? true = its picture is kept and the next step is asked.
  bool take(FaceLook f) {
    if (done || !f.one) return false;
    switch (step) {
      case 0:
        if (!f.straight) return false;
      case 1:
        if (!_sideOk(f)) return false;
        _side = f.yaw.sign;
      case 2:
        if (!_sideOk(f) || f.yaw.sign == _side) return false;
      case 3:
        if (!_tiltOk(f)) return false;
        _tilt = f.pitch.sign;
      case 4:
        if (!_tiltOk(f) || f.pitch.sign == _tilt) return false;
    }
    step++;
    return true;
  }

  bool _sideOk(FaceLook f) => f.yaw.abs() >= sideMin && f.yaw.abs() <= sideMax && f.pitch.abs() <= level;
  bool _tiltOk(FaceLook f) => f.pitch.abs() >= tiltMin && f.pitch.abs() <= tiltMax && f.yaw.abs() <= level;

  /// (3.140.0) WHAT TO CHANGE for the step asked now, said on the screen and aloud (English, Marathi, Hindi); ('', '', '') when
  /// the look is right, or when no face / two faces are seen (faceHint says that).
  (String, String, String) hint(FaceLook f) {
    const none = ('', '', '');
    if (done || !f.one) return none;
    final y = f.yaw.abs(), p = f.pitch.abs();
    switch (step) {
      case 0:
        if (!f.straight) return ('Look straight at the phone', 'फोनकडे सरळ बघा', 'फ़ोन की तरफ़ सीधे देखिए');
      case 1:
      case 2:
        if (p > level) return ('Keep your chin level – turn only to the side', 'हनुवटी सरळ ठेवा – फक्त बाजूला वळा', 'ठोड़ी सीधी रखिए – सिर्फ़ बगल में घुमाइए');
        if (step == 2 && y >= sideMin && f.yaw.sign == _side) return ('The OTHER side', 'दुसऱ्या बाजूला', 'दूसरी तरफ़');
        if (y < sideMin) return ('Turn a little more', 'थोडे अजून वळा', 'थोड़ा और घुमाइए');
        if (y > sideMax) return ('A little less – your whole face must be seen', 'थोडे कमी – पूर्ण चेहरा दिसला पाहिजे', 'थोड़ा कम – पूरा चेहरा दिखना चाहिए');
      case 3:
      case 4:
        if (y > level) return ('Face the phone – only up or down', 'phone कडे तोंड करा – फक्त वर किंवा खाली', 'फ़ोन की तरफ़ मुँह कीजिए – सिर्फ़ ऊपर या नीचे');
        if (step == 4 && p >= tiltMin && f.pitch.sign == _tilt) return ('Now the OTHER way', 'आता उलट बाजूला', 'अब उल्टी तरफ़');
        if (p < tiltMin) return ('A little more', 'थोडे अजून', 'थोड़ा और');
        if (p > tiltMax) return ('A little less – your whole face must be seen', 'थोडे कमी – पूर्ण चेहरा दिसला पाहिजे', 'थोड़ा कम – पूरा चेहरा दिखना चाहिए');
    }
    return none;
  }
}

/// EVERY ATTENDANCE: the face straight with open eyes → the eyes closed → open again, the face straight. The look that ends it
/// is the proof photo.
class FaceBlinkSteps {
  int step = 0; // 0 straight, eyes open · 1 eyes closed · 2 eyes open again, straight · 3 done
  bool get done => step >= 3;

  (String, String) get ask => switch (step) {
        0 => ('Look straight at the phone', 'Phone कडे सरळ बघा'),
        1 => ('Close your eyes for a moment', 'क्षणभर डोळे मिटा'),
        2 => ('Open your eyes', 'डोळे उघडा'),
        _ => ('Done', 'झाले'),
      };

  bool take(FaceLook f) {
    if (done || !f.one) return false;
    final ok = switch (step) { 0 => f.straight && f.eyesOpen, 1 => f.eyesClosed, _ => f.straight && f.eyesOpen };
    if (ok) step++;
    return ok;
  }
}

/// Why a look was not taken – said to the person (English, Marathi); ('', '') = nothing to say, keep going.
(String, String) faceHint(FaceLook f, {bool eyes = false}) {
  if (f.faces == 0) return ('No face is seen – hold the phone in front of your face, in the light', 'चेहरा दिसत नाही – phone चेहऱ्यासमोर धरा, उजेडात');
  if (f.faces > 1) return ('Only you – nobody else in the picture', 'फक्त तुम्ही – दुसरे कोणी नको');
  if (eyes && !f.eyesKnown) return ('Your eyes are not seen – take off dark glasses, come into the light', 'डोळे दिसत नाहीत – काळा चष्मा काढा, उजेडात या');
  return ('', '');
}

/// (3.117.0, his word of 13-11-2026: "application sound asel … kay karaych aahe te bolun sangel … ji languge user chi asel tya
/// madhe karan driver lokana samjat nahi") WHAT IS SAID ALOUD at a step – short, in his language: 'mr', 'hi', else English.
String faceSay(bool enrol, int step, String lang) {
  const blink = [
    ('Look straight at the phone', 'फोनकडे सरळ बघा', 'फ़ोन की तरफ़ सीधे देखिए'),
    ('Close your eyes', 'डोळे मिटा', 'आँखें बंद कीजिए'),
    ('Open your eyes', 'डोळे उघडा', 'आँखें खोलिए'),
  ];
  const reg = [
    ('Look straight at the phone', 'फोनकडे सरळ बघा', 'फ़ोन की तरफ़ सीधे देखिए'),
    ('Turn your head to one side', 'डोके एका बाजूला वळवा', 'सिर एक तरफ़ घुमाइए'),
    ('Now to the other side', 'आता दुसऱ्या बाजूला', 'अब दूसरी तरफ़'),
    ('Lift your chin up, or look down', 'हनुवटी वर करा, किंवा खाली बघा', 'ठोड़ी ऊपर कीजिए, या नीचे देखिए'),
    ('Now the other way', 'आता उलट बाजूला', 'अब उल्टी तरफ़'),
  ];
  final list = enrol ? reg : blink;
  if (step < 0 || step >= list.length) return lang == 'mr' ? 'झाले' : lang == 'hi' ? 'हो गया' : 'Done';
  final t = list[step];
  return lang == 'mr' ? t.$2 : lang == 'hi' ? t.$3 : t.$1;
}
