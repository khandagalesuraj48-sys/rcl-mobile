// (3.124.0, asked 14-11-2026) THE PRODUCT IS "SKETCHLINE LION" – its name, line and logo in one place; the client (Rachana) beside it.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rcl_mobile/ui/brand.dart';

void main() {
  test('one place for the product: the name, its line, its logo (the file is there and in the build)', () {
    expect(Product.name, 'Sketchline Lion');
    expect(Product.line, 'Integrated Construction Management');
    expect(File(Product.logo).existsSync(), true);
    expect(File('pubspec.yaml').readAsStringSync(), contains('- assets/brand/sketchline_lion.png'));
  });

  test('the phone shows the new name: Android, the iPhone, the tool that makes the platform folders', () {
    expect(File('android/app/src/main/AndroidManifest.xml').readAsStringSync(), contains('android:label="Sketchline Lion"'));
    expect(File('ios/Runner/Info.plist').readAsStringSync(), contains('<string>Sketchline Lion</string>'));
    final tool = File('tool/patch_platforms.py').readAsStringSync();
    expect(tool, contains('android:label="Sketchline Lion"'));
    expect(tool, isNot(contains('android:label="RCL ERP"')));
  });

  test('the screens take the product from that one place; Home keeps the client\'s own mark beside the lion; the app\'s id is unchanged', () {
    final home = File('lib/screens/home.dart').readAsStringSync(), login = File('lib/screens/login.dart').readAsStringSync(), splash = File('lib/screens/splash.dart').readAsStringSync();
    for (final src in [home, login, splash, File('lib/screens/me.dart').readAsStringSync()]) {
      expect(src, isNot(contains("'RCL ERP'")));
    }
    expect('ProductMark('.allMatches(home).length, 3);
    expect("assets/brand/rachana_mark.png".allMatches(home).length, 3, reason: 'the client beside the product, in each of the three places');
    expect(login, contains('ProductMark(size: 44'));
    expect(splash, contains('Product.first.toUpperCase()'));
    expect(File('android/app/build.gradle.kts').existsSync() ? File('android/app/build.gradle.kts').readAsStringSync() : File('android/app/build.gradle').readAsStringSync(), contains('in.rachana.rcl'));
  });
}
