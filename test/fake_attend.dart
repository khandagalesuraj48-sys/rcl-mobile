// (3.103.0) The phone's own part of HR attendance for the tests: its number, Developer Options, its counter since switch-on, where
// it is, its clock and its files (kept in memory).
import 'dart:typed_data';

import 'package:rcl_mobile/core/attend.dart';

class FakeAttendKit extends AttendKit {
  bool dev = false, mocked = false;
  double lat = 18.52, lng = 73.8567, acc = 12;
  int? counter = 5000000;
  int clock = DateTime.utc(2026, 10, 14, 5).millisecondsSinceEpoch; // 10:30 in India
  String phone = 'and-test-phone-1';
  final files = <String, Object>{};

  @override
  Future<Map<String, String>> info() async => {'id': phone, 'model': 'Test Phone', 'os': 'Android 15'};
  @override
  Future<bool> devOptions() async => dev;

  /// (3.117.0) the phone's location switched on / off; how often the app asked to switch it on
  bool gps = true;
  int gpsAsked = 0;
  @override
  Future<bool> gpsOn() async => gps;
  @override
  Future<bool> gpsTurnOn() async {
    gpsAsked++;
    gps = true;
    return true;
  }
  @override
  Future<int?> elapsed() async => counter;
  @override
  Future<AttendFix> where() async => AttendFix(lat, lng, acc, mocked: mocked);
  @override
  int now() => clock;
  @override
  Future<String?> readText(String name) async => files[name] is String ? files[name] as String : null;
  @override
  Future<void> writeText(String name, String v) async {
    files[name] = v;
  }
  @override
  Future<Uint8List?> readBytes(String name) async => files[name] is Uint8List ? files[name] as Uint8List : null;
  @override
  Future<void> writeBytes(String name, Uint8List b) async {
    files[name] = b;
  }
  @override
  Future<void> delete(String name) async {
    files.remove(name);
  }
  @override
  Future<List<String>> names() async => files.keys.toList();
}
