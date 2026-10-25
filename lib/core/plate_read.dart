/* (3.1.8) The camera → the letters on the number plate, read ON THE PHONE (Google ML Kit text recognition; no internet, nothing
 * paid). Which machinery it is: plate.dart. */
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'applock.dart';

/// Takes a photo of the plate and gives its text; null = no photo taken.
Future<String?> readPlatePhoto() async {
  final x = await AppLock.whileOutside(() => ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 85, maxWidth: 1600));
  if (x == null) return null;
  final r = TextRecognizer(script: TextRecognitionScript.latin);
  try {
    final t = await r.processImage(InputImage.fromFilePath(x.path));
    return t.text;
  } finally {
    await r.close();
  }
}
