/* A FILE FROM THE PHONE (3.11.0) – an Excel / CSV file to import, picked from the phone's files (Downloads, Drive, WhatsApp …),
 * as the web's "Import from Excel" opens the computer's files (.xlsx, .xls, .csv). A test sets [pickSheetFile] to its own. */
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// The name and the bytes of the file picked (null = nothing picked).
Future<({String name, Uint8List bytes})?> Function() pickSheetFile = _pick;

Future<({String name, Uint8List bytes})?> _pick() async {
  final f = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: const ['xlsx', 'xls', 'csv']);
  if (f == null) return null;
  return (name: f.name, bytes: await f.readAsBytes());
}
