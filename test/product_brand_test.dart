// (3.124.0, asked 14-11-2026) THE PRODUCT IS "SKETCHLINE" (3.125.0: one word) – its name, line and logo in one place; the client (Rachana) beside it.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rcl_mobile/core/product_brand.dart';
import 'package:rcl_mobile/ui/brand.dart';

void main() {
  tearDown(ProductBrand.i.reset);

  test('the Portal\'s Branding: the name, the line and the logo are taken, kept on the phone and shown at the next opening; nothing there or no network: as it is', () async {
    final dir = Directory.systemTemp.createTempSync('brand');
    addTearDown(() => dir.deleteSync(recursive: true));
    final png = Uint8List.fromList([0x89, 0x50, 0x4e, 0x47, 1, 2, 3]);
    var answer = <String, Object>{'name': 'Acme ERP', 'first': 'Acme', 'second': 'ERP', 'line': 'Roads', 'logo': '1731580000000', 'photo': ''};
    final asked = <String>[];
    final web = MockClient((q) async {
      asked.add(q.url.toString());
      if (q.url.queryParameters['img'] == 'logo') return http.Response.bytes(png, 200, headers: {'content-type': 'image/png'});
      if (q.url.queryParameters['img'] == 'co-RCL') return http.Response.bytes(png, 200, headers: {'content-type': 'image/png'});
      if (q.url.queryParameters.containsKey('img')) return http.Response('{"error":"No such picture."}', 404, headers: {'content-type': 'application/json'});
      return http.Response(jsonEncode(answer), 200, headers: {'content-type': 'application/json'});
    });
    final b = ProductBrand.i;
    expect([b.name, b.line, b.logo], ['Sketchline', 'Integrated Construction Management', null]);
    await b.open(dir);
    var told = 0;
    void on() => told++;
    b.addListener(on);
    addTearDown(() => b.removeListener(on));
    await b.refresh('https://portal.test/portal/', client: web);
    expect([b.name, b.line, b.logo], ['Acme ERP', 'Roads', png]);
    expect(asked, ['https://portal.test/portal/api/brand', 'https://portal.test/portal/api/brand?img=logo&v=1731580000000']);
    expect(told, 1);
    // asked again with nothing changed: nothing is fetched again, nobody is told
    await b.refresh('https://portal.test/portal', client: web);
    expect([asked.length, told], [3, 1]);
    // a client's logo: by its company's id, asked once; a wrong id is never asked
    expect(b.client('RCL'), null);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(b.client('RCL'), png);
    expect(b.client('../x'), null);
    expect(asked.where((u) => u.contains('co-')).length, 1);
    // the next opening (a new start of the app): what was kept is there before the Portal answers
    b.reset();
    await b.open(dir);
    expect([b.name, b.line, b.logo], ['Acme ERP', 'Roads', png]);
    // no network, a broken answer, an empty name: what is shown stays
    await b.refresh('https://portal.test/portal', client: MockClient((q) async => throw const SocketException('no network')));
    await b.refresh('https://portal.test/portal', client: MockClient((q) async => http.Response('<html>', 200)));
    await b.refresh('https://portal.test/portal', client: MockClient((q) async => http.Response('{"first":""}', 200)));
    expect(b.name, 'Acme ERP');
    // the logo taken away in the Portal: the built-in lion again
    answer = {'first': 'Acme', 'second': '', 'line': '', 'logo': '', 'photo': ''};
    await b.refresh('https://portal.test/portal', client: web);
    expect([b.name, b.line, b.logo], ['Acme', '', null]);
  });

  test('a name is text: control characters out, cut to its length; a stamp is digits only', () {
    final b = ProductBrand.i;
    expect(b.take({'first': '  Sketch\nline  ', 'second': 'x' * 40, 'line': 'L'}), true);
    expect([b.first, b.second.length, b.line], ['Sketch line', 24, 'L']);
    expect(b.take({'first': ' '}), false);
  });

  test('one place for the product: the name, its line, its logo (the file is there and in the build)', () {
    expect(Product.name, 'Sketchline');
    expect(Product.line, 'Integrated Construction Management');
    expect(File(Product.logo).existsSync(), true);
    expect(File('pubspec.yaml').readAsStringSync(), contains('- assets/brand/sketchline_lion.png'));
  });

  test('the phone shows the new name: Android, the iPhone, the tool that makes the platform folders', () {
    expect(File('android/app/src/main/AndroidManifest.xml').readAsStringSync(), contains('android:label="Sketchline"'));
    expect(File('ios/Runner/Info.plist').readAsStringSync(), contains('<string>Sketchline</string>'));
    final tool = File('tool/patch_platforms.py').readAsStringSync();
    expect(tool, contains('android:label="Sketchline"'));
    expect(tool, isNot(contains('android:label="RCL ' 'ERP"')));
  });

  test('the screens take the product from that one place; (3.127.0) Home shows only the client\'s own mark and name, the ≡ menu the product; the app\'s id is unchanged', () {
    final home = File('lib/screens/home.dart').readAsStringSync(), login = File('lib/screens/login.dart').readAsStringSync(), splash = File('lib/screens/splash.dart').readAsStringSync();
    for (final src in [home, login, splash, File('lib/screens/me.dart').readAsStringSync()]) {
      expect(src, isNot(contains("'RCL " "ERP'")), reason: 'the old name');
    }
    expect('ProductMark('.allMatches(home).length, 0, reason: '(3.127.0) "home screen la only client name and logo"');
    expect('ClientMark('.allMatches(home).length, 2, reason: 'the client: the top of Home and its bar when scrolled');
    expect('ProductBlock('.allMatches(home).length, 1, reason: 'the ≡ menu: the lion, the name, its line');
    expect(login, contains('ProductMark(size: 44'));
    expect(splash, contains('Product.first.toUpperCase()'));
    expect(File('android/app/build.gradle.kts').existsSync() ? File('android/app/build.gradle.kts').readAsStringSync() : File('android/app/build.gradle').readAsStringSync(), contains('in.rachana.rcl'));
  });
}
