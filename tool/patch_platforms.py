#!/usr/bin/env python3
"""Run ONCE by the build (GitHub Actions) right after `flutter create` made android/ and ios/: the app's own settings.
   Android: the app's name, internet, "install the update" (ota_update: its file provider and install receiver), Java desugaring
   (ota_update 7), and the release signing from key.properties (kept only in the private store – never in git).
   iOS: the app's name. Every change is checked: a template that looks different stops the build with a clear message."""
import os, re, sys

def edit(path, fn):
    with open(path, encoding='utf-8') as f: s = f.read()
    t = fn(s)
    if t == s: print('unchanged: ' + path)
    with open(path, 'w', encoding='utf-8') as f: f.write(t)

def need(cond, what):
    if not cond: sys.exit('patch_platforms: ' + what)

MAN = 'android/app/src/main/AndroidManifest.xml'
def manifest(s):
    perms = ['android.permission.INTERNET', 'android.permission.REQUEST_INSTALL_PACKAGES']
    add = ''.join('    <uses-permission android:name="%s"/>\n' % p for p in perms if p not in s)
    s = re.sub(r'(<manifest[^>]*>\n)', lambda m: m.group(1) + add, s, count=1)
    s = re.sub(r'android:label="[^"]*"', 'android:label="RCL ERP"', s, count=1)
    if 'OtaUpdateFileProvider' not in s:
        block = ('        <provider android:name="sk.fourq.otaupdate.OtaUpdateFileProvider"\n'
                 '            android:authorities="${applicationId}.ota_update_provider"\n'
                 '            android:exported="false" android:grantUriPermissions="true">\n'
                 '            <meta-data android:name="android.support.FILE_PROVIDER_PATHS" android:resource="@xml/filepaths"/>\n'
                 '        </provider>\n'
                 '        <receiver android:name="sk.fourq.otaupdate.InstallResultReceiver" android:exported="false">\n'
                 '            <intent-filter><action android:name="${applicationId}.ACTION_INSTALL_COMPLETE"/></intent-filter>\n'
                 '        </receiver>\n')
        need('</application>' in s, 'no </application> in the manifest')
        s = s.replace('</application>', block + '    </application>', 1)
    return s

def gradle(s):
    need('android {' in s, 'app/build.gradle.kts has no "android {"')
    if 'import java.util.Properties' not in s:
        s = ('import java.util.Properties\nimport java.io.FileInputStream\n\n'
             'val keyProps = Properties().apply { val f = rootProject.file("key.properties"); if (f.exists()) FileInputStream(f).use { load(it) } }\n\n') + s
    if 'isCoreLibraryDesugaringEnabled' not in s:
        s2 = re.sub(r'(compileOptions\s*\{)', r'\1\n        isCoreLibraryDesugaringEnabled = true', s, count=1)
        need(s2 != s, 'no compileOptions block'); s = s2
    if 'signingConfigs {' not in s:
        sc = ('    signingConfigs {\n        create("release") {\n            if (keyProps.isNotEmpty()) {\n'
              '                keyAlias = keyProps["keyAlias"] as String\n                keyPassword = keyProps["keyPassword"] as String\n'
              '                storeFile = rootProject.file(keyProps["storeFile"] as String)\n                storePassword = keyProps["storePassword"] as String\n'
              '            }\n        }\n    }\n\n    buildTypes {')
        s2 = s.replace('    buildTypes {', sc, 1); need(s2 != s, 'no buildTypes block'); s = s2
        s2 = re.sub(r'signingConfig = signingConfigs\.getByName\("debug"\)', 'signingConfig = if (keyProps.isNotEmpty()) signingConfigs.getByName("release") else signingConfigs.getByName("debug")', s, count=1)
        need(s2 != s, 'no debug signingConfig line in release'); s = s2
    if 'desugar_jdk_libs' not in s:
        s += '\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}\n'
    return s

def plist(s):
    if '<key>CFBundleDisplayName</key>' in s:
        return re.sub(r'(<key>CFBundleDisplayName</key>\s*<string>)[^<]*(</string>)', r'\1RCL ERP\2', s, count=1)
    return s.replace('<dict>', '<dict>\n\t<key>CFBundleDisplayName</key>\n\t<string>RCL ERP</string>', 1)

edit(MAN, manifest)
os.makedirs('android/app/src/main/res/xml', exist_ok=True)
with open('android/app/src/main/res/xml/filepaths.xml', 'w') as f:
    f.write('<?xml version="1.0" encoding="utf-8"?>\n<paths>\n    <files-path name="internal_apk_storage" path="ota_update/"/>\n</paths>\n')
need(os.path.exists('android/app/build.gradle.kts'), 'android/app/build.gradle.kts is missing (an older Groovy template?)')
edit('android/app/build.gradle.kts', gradle)
if os.path.exists('ios/Runner/Info.plist'): edit('ios/Runner/Info.plist', plist)
# flutter create adds a sample test for its counter app – not this app
w = 'test/widget_test.dart'
if os.path.exists(w) and 'MyApp' in open(w).read(): os.remove(w)
print('patched')
