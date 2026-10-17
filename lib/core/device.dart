/* (3.19.0, asked 17-10-2026: "windows and ios app banaw direct app ya windows war chaltil browser open krnechi garaj nahi updet pn
 * in app ch yeil") THE COMPUTER APP (Windows): the same app – the same screens, sign-in, server actions, checks and access as
 * on the phone. What only a phone has is not offered on a computer: the QR scanner and the number plate read (the phone's live
 * camera and ML Kit). A photo is chosen from a file, as the web does on a computer; a file the app makes is saved in Downloads
 * and opened, as the web's download; the update is the Windows setup of the newest release (update.dart). */
import 'dart:io' show Platform;

/// (a test) the app as on a computer (true) or on a phone (false); null: as it really is.
bool? computerForTest;

/// The app runs on a Windows computer.
bool get onComputer => computerForTest ?? Platform.isWindows;
