/* A FILE FROM THE PHONE (3.11.0) – an Excel / CSV file to import, picked from the phone's files (Downloads, Drive, WhatsApp …),
 * as the web's "Import from Excel" opens the computer's files (.xlsx, .xls, .csv). A test sets [pickSheetFile] to its own. */
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import '../core/applock.dart';

/// The name and the bytes of the file picked (null = nothing picked).
Future<({String name, Uint8List bytes})?> Function() pickSheetFile = _pick;

Future<({String name, Uint8List bytes})?> _pick() async {
  final r = await AppLock.whileOutside(() => FilePicker.pickFiles(type: FileType.custom, allowedExtensions: const ['xlsx', 'xls', 'csv'], withData: true));
  if (r == null || r.files.isEmpty) return null;
  final f = r.files.single;
  final b = f.bytes ?? (f.path == null ? null : await File(f.path!).readAsBytes());
  return b == null ? null : (name: f.name, bytes: b);
}

/// (3.91.0, Mechanical update-216) a FASTag statement: a PDF, a photo or an Excel / CSV file. A test sets [pickStatementFile] to its own.
Future<({String name, Uint8List bytes})?> Function() pickStatementFile = _pickStatement;

Future<({String name, Uint8List bytes})?> _pickStatement() async {
  final r = await AppLock.whileOutside(() => FilePicker.pickFiles(type: FileType.custom, allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'xlsx', 'csv'], withData: true));
  if (r == null || r.files.isEmpty) return null;
  final f = r.files.single;
  final b = f.bytes ?? (f.path == null ? null : await File(f.path!).readAsBytes());
  return b == null ? null : (name: f.name, bytes: b);
}
