/* (3.14.0) A MACHINERY LABEL SCANNED IN THE APP – the web's QR labels (Asset Master → QR labels) hold the Mechanical link with the
 * machinery (…/?m=MH-25-AJ-8511). On the web a scan opens the page and asks what to do for it (qrArrive); in the app the camera
 * takes the label and the phone reads the code (Google ML Kit, on the phone; nothing sent) – then the same question. */
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:image_picker/image_picker.dart';

/// Takes a photo of a label and gives what its QR code says; null = no photo, '' = no code on it. A test sets its own.
Future<String?> Function() scanLabel = _scan;

Future<String?> _scan() async {
  final x = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 90, maxWidth: 1600);
  if (x == null) return null;
  final sc = BarcodeScanner(formats: [BarcodeFormat.qrCode]);
  try {
    final list = await sc.processImage(InputImage.fromFilePath(x.path));
    return list.isEmpty ? '' : (list.first.rawValue ?? '');
  } finally {
    await sc.close();
  }
}

/// The machinery of a label's link ('' = not one of the ERP's labels) – as the web reads ?m= (URLSearchParams).
String labelMachine(String text) {
  final u = Uri.tryParse(text.trim());
  if (u == null || !u.hasQuery) return '';
  try {
    return (u.queryParameters['m'] ?? '').trim();
  } catch (_) {
    return '';
  }
}
