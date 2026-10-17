/* A FILE THE WEB MADE (Excel, CSV, a snapshot): kept in the app's own folder and offered to the phone – open it in Excel /
 * Sheets, send it on WhatsApp / mail, or keep it in Files / Drive (Android's share sheet).
 * (3.19.0) On a computer (Windows): saved in Downloads, as the web's download, and opened (Excel, the PDF viewer …). */
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/device.dart';

/// A file name that is safe on the phone (no folder signs, not empty, not too long).
String safeFileName(String name) {
  var n = name.replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1f]'), '_').trim();
  n = n.replaceAll(RegExp(r'^\.+'), '');
  if (n.isEmpty) n = 'RCL_file';
  if (n.length > 120) {
    final dot = n.lastIndexOf('.');
    final ext = dot > 0 && n.length - dot <= 8 ? n.substring(dot) : '';
    n = n.substring(0, 120 - ext.length) + ext;
  }
  return n;
}

/// The file's type from its name when the web gave none.
String mimeOf(String name, String given) {
  final g = given.split(';').first.trim().toLowerCase();
  if (g.isNotEmpty && g != 'application/octet-stream') return g;
  final n = name.toLowerCase();
  if (n.endsWith('.xlsx')) return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
  if (n.endsWith('.csv')) return 'text/csv';
  if (n.endsWith('.pdf')) return 'application/pdf';
  if (n.endsWith('.png')) return 'image/png';
  if (n.endsWith('.jpg') || n.endsWith('.jpeg')) return 'image/jpeg';
  return 'application/octet-stream';
}

/// Writes the file (base64 from the web) and opens the phone's share sheet for it. Returns the file.
Future<File> saveAndShare(String name, String mime, String base64Data) => handOver(base64Decode(base64Data), name, mime);

/// (3.19.0) A file the app made, given to the person: on a phone the share sheet; on a computer saved in Downloads and opened.
/// Gives the file.
Future<File> handOver(Uint8List bytes, String name, String mime) async {
  final n = safeFileName(name);
  if (onComputer) {
    final dl = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
    final f = freeFile(dl.path, n);
    await f.writeAsBytes(bytes, flush: true);
    await launchUrl(Uri.file(f.path));
    return f;
  }
  final dir = Directory('${(await getTemporaryDirectory()).path}/rcl_files');
  await dir.create(recursive: true);
  final f = File('${dir.path}/$n');
  await f.writeAsBytes(bytes, flush: true);
  await SharePlus.instance.share(ShareParams(files: [XFile(f.path, mimeType: mimeOf(n, mime), name: n)], title: n));
  return f;
}

/// (3.19.0) A file in [dir] not there yet – "name.xlsx", else "name (2).xlsx", "name (3).xlsx" … (as a browser's download).
File freeFile(String dir, String name) {
  final dot = name.lastIndexOf('.');
  final base = dot > 0 ? name.substring(0, dot) : name, ext = dot > 0 ? name.substring(dot) : '';
  final sep = Platform.pathSeparator;
  var f = File('$dir$sep$name');
  for (var i = 2; f.existsSync() && i < 1000; i++) {
    f = File('$dir$sep$base ($i)$ext');
  }
  return f;
}
