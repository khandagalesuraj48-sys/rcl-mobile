// (3.84.0) Share app (core/app_share.dart): the link of the app's own page – the latest version, always – and one line in each language.
import 'package:flutter_test/flutter_test.dart';
import 'package:rcl_mobile/core/app_share.dart';

void main() {
  test('the text: the app\'s page at the main address, what to do in मराठी / English / हिंदी; nothing about who shares', () {
    expect(kAppPage, 'https://oneclicksolution-erp.vercel.app/app');
    final t = appShareText();
    expect(t.split('\n').first, 'RCL ERP app – https://oneclicksolution-erp.vercel.app/app');
    expect(t, contains('Admin ने दिलेला email व password'));
    expect(t, contains('sign in with the email and password the Admin gave you'));
    expect(t, contains('Admin का दिया email और password'));
    expect(t, isNot(contains('@')), reason: 'no address of anybody in it');
  });
}
