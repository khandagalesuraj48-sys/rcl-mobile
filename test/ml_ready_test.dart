// (3.146.0) the camera's readers from Google Play services: "not fetched yet" is told as it is – every other fault as before
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rcl_mobile/core/ml_ready.dart';

void main() {
  test('a reader Play services has not fetched yet is known by its words', () {
    for (final m in [
      'Waiting for the text optional module to be downloaded. Please wait.',
      'Waiting for the face module to be downloaded. Please wait.',
      'MlKitException: Waiting for the barcode UI module to be downloaded.',
      'The optional module is not available yet',
    ]) {
      expect(mlWaiting(PlatformException(code: 'error', message: m)), isTrue, reason: m);
    }
    for (final m in ['Camera is closed', 'InputImage format not supported', 'No face', 'Failed to open file']) {
      expect(mlWaiting(PlatformException(code: 'error', message: m)), isFalse, reason: m);
    }
    expect(mlWaitText.$1, contains('Google Play services'));
    expect(mlWaitText.$2, contains('Google Play services'));
  });

  test('the bundled ML Kit is swapped for Play services\' – in the build, the scanner and the manifest', () {
    final root = File('android/build.gradle.kts').readAsStringSync(), app = File('android/app/build.gradle.kts').readAsStringSync();
    expect(root, contains('substitute(module("com.google.mlkit:text-recognition")).using(module("com.google.android.gms:play-services-mlkit-text-recognition'));
    expect(root, contains('substitute(module("com.google.mlkit:face-detection")).using(module("com.google.android.gms:play-services-mlkit-face-detection'));
    expect(File('android/gradle.properties').readAsStringSync(), contains('dev.steenbakker.mobile_scanner.useUnbundled=true'));
    expect(File('android/app/src/main/AndroidManifest.xml').readAsStringSync(), contains('android:name="com.google.mlkit.vision.DEPENDENCIES" android:value="ocr,face,barcode"'));
    expect(app, contains('play-services-mlkit-barcode-scanning'));
    expect(File('android/app/src/main/kotlin/in/rachana/rcl/rcl_mobile/MainActivity.kt').readAsStringSync(), contains('MlReady.ask(applicationContext)'));
  });
}
