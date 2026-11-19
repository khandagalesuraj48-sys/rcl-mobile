/* (3.146.0, asked 19-11-2026: "app install hotana … khup time ghet aahe" – his answer: the app smaller, 79 → ~50 MB) THE CAMERA'S
 * READERS COME FROM GOOGLE PLAY SERVICES: text reading (number plate, meter), face finding (attendance) and the QR scanner are no
 * longer packed in the app. Play services fetches each once per phone (asked when the app opens – MlReady.kt). Until it is there,
 * ML Kit's reading fails with "Waiting for the … module to be downloaded" – then the person is told to keep the internet on and
 * try again in a minute, instead of "the camera does not work". */

/// The reading failed only because Google Play services has not fetched its part on this phone yet.
bool mlWaiting(Object e) =>
    RegExp(r'waiting for .*download|to be downloaded|optional module|module (is )?not (yet )?(available|installed)|MlKitException.*(UNAVAILABLE|code 14)',
            caseSensitive: false)
        .hasMatch('$e');

/// What the person is told then (English, Marathi).
const mlWaitText = (
  'The phone is getting the camera reading ready from Google Play services (only once) – keep the internet on and try again in a minute.',
  'फोन Google Play services कडून camera वाचन तयार करत आहे (फक्त एकदाच) – internet चालू ठेवा आणि एका मिनिटाने पुन्हा करा.',
);
