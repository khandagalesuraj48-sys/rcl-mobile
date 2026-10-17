/* (3.14.0) A MACHINERY LABEL SCANNED IN THE APP – the web's QR labels (Asset Master → QR labels) hold the Mechanical link with the
 * machinery (…/?m=MH-25-AJ-8511). On the web a scan opens the page and asks what to do for it (qrArrive); in the app the label is
 * scanned and the same question follows. (3.18.2) The scanner is the app's own live camera (screens/label_scan.dart) – this file
 * reads what a label says. */

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
