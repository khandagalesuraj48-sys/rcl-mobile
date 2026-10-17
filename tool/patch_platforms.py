#!/usr/bin/env python3
"""Run ONCE by the build (GitHub Actions) right after `flutter create` made android/ and ios/: the app's own settings.
   Android: the app's name, internet, "install the update" (ota_update: its file provider and install receiver), Java desugaring
   (ota_update 7), and the release signing from key.properties (kept only in the private store – never in git).
   App 2 (the web ERP inside the app): camera, location, microphone; the web view's file provider (a photo taken for a page);
   the camera app and https links visible to the app (Android 11+).
   iOS: the app's name; why it asks for the camera, location, microphone and photos. Every change is checked: a template that looks different stops the build with a clear message."""
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
    perms = ['android.permission.INTERNET', 'android.permission.REQUEST_INSTALL_PACKAGES', 'android.permission.CAMERA', 'android.permission.ACCESS_FINE_LOCATION',
             'android.permission.ACCESS_COARSE_LOCATION', 'android.permission.RECORD_AUDIO', 'android.permission.MODIFY_AUDIO_SETTINGS', 'android.permission.POST_NOTIFICATIONS',
             'android.permission.RECEIVE_BOOT_COMPLETED', 'android.permission.WAKE_LOCK']
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
    if 'InAppWebViewFileProvider' not in s:
        s = s.replace('</application>', '    <provider android:name="com.pichillilorenzo.flutter_inappwebview_android.InAppWebViewFileProvider"\n'
                      '            android:authorities="${applicationId}.flutter_inappwebview_android.fileprovider"\n'
                      '            android:exported="false" android:grantUriPermissions="true">\n'
                      '            <meta-data android:name="android.support.FILE_PROVIDER_PATHS" android:resource="@xml/provider_paths"/>\n'
                      '        </provider>\n    </application>', 1)
    if 'androidalarmmanager.AlarmService' not in s:      # (3.1.8) notifications with the app closed
        s = s.replace('</application>', '    <service android:name="dev.fluttercommunity.plus.androidalarmmanager.AlarmService" android:permission="android.permission.BIND_JOB_SERVICE" android:exported="false"/>\n'
                      '        <receiver android:name="dev.fluttercommunity.plus.androidalarmmanager.AlarmBroadcastReceiver" android:exported="false"/>\n'
                      '        <receiver android:name="dev.fluttercommunity.plus.androidalarmmanager.RebootBroadcastReceiver" android:enabled="false" android:exported="false">\n'
                      '            <intent-filter><action android:name="android.intent.action.BOOT_COMPLETED"/></intent-filter>\n'
                      '        </receiver>\n    </application>', 1)
    if 'android.speech.RecognitionService' not in s:      # (3.15.0) the assistant: the phone's listening and speaking services
        q = ('        <intent>\n            <action android:name="android.speech.RecognitionService"/>\n        </intent>\n'
             '        <intent>\n            <action android:name="android.intent.action.TTS_SERVICE"/>\n        </intent>\n')
        s = s.replace('    </queries>', q + '    </queries>', 1) if '</queries>' in s else s.replace('</manifest>', '    <queries>\n' + q + '    </queries>\n</manifest>', 1)
    if 'android.media.action.IMAGE_CAPTURE' not in s:
        q = ('        <intent>\n            <action android:name="android.media.action.IMAGE_CAPTURE"/>\n        </intent>\n'
             '        <intent>\n            <action android:name="android.intent.action.VIEW"/>\n            <data android:scheme="https"/>\n        </intent>\n')
        s = s.replace('    </queries>', q + '    </queries>', 1) if '</queries>' in s else s.replace('</manifest>', '    <queries>\n' + q + '    </queries>\n</manifest>', 1)
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

ROOT_KT = ('\n// (3.11.0) file_picker 11 (and 3.15.0 speech_to_text 7.5) leave their Kotlin code to AGP 9\'s built-in Kotlin, which this project\n'
           '// keeps off (android.builtInKotlin=false): their Kotlin is compiled with the Kotlin plugin, as the other plugins do.\n'
           'subprojects {\n    if (name == "file_picker" || name == "speech_to_text") {\n        pluginManager.withPlugin("com.android.library") {\n'
           '            if (!pluginManager.hasPlugin("org.jetbrains.kotlin.android")) pluginManager.apply("org.jetbrains.kotlin.android")\n        }\n    }\n}\n')
def root_gradle(s):
    if 'name == "file_picker")' in s:      # (3.15.0) an older patch: speech_to_text added to it
        return s.replace('name == "file_picker")', 'name == "file_picker" || name == "speech_to_text")')
    return s if 'name == "file_picker"' in s else s + ROOT_KT

USES = [('NSCameraUsageDescription', 'RCL ERP uses the camera for the photos of an entry (Diesel Issue and others).'),
        ('NSLocationWhenInUseUsageDescription', 'RCL ERP saves the place of every entry, as the web ERP does.'),
        ('NSMicrophoneUsageDescription', 'RCL ERP uses the microphone when you talk with the assistant and for a screen-share help call.'),
        ('NSPhotoLibraryUsageDescription', 'RCL ERP lets you choose a photo for an entry.'),
        ('NSSpeechRecognitionUsageDescription', 'RCL ERP turns what you say to the assistant into words (a question or an entry).')]
def plist(s):
    if '<key>CFBundleDisplayName</key>' in s:
        s = re.sub(r'(<key>CFBundleDisplayName</key>\s*<string>)[^<]*(</string>)', r'\1RCL ERP\2', s, count=1)
    else:
        s = s.replace('<dict>', '<dict>\n\t<key>CFBundleDisplayName</key>\n\t<string>RCL ERP</string>', 1)
    for k, v in USES:
        if '<key>%s</key>' % k not in s: s = s.replace('<dict>', '<dict>\n\t<key>%s</key>\n\t<string>%s</string>' % (k, v), 1)
    s = s.replace('RCL ERP uses the microphone for a screen-share help call.', dict(USES)['NSMicrophoneUsageDescription'])
    return s

edit(MAN, manifest)
os.makedirs('android/app/src/main/res/xml', exist_ok=True)
with open('android/app/src/main/res/xml/filepaths.xml', 'w') as f:
    f.write('<?xml version="1.0" encoding="utf-8"?>\n<paths>\n    <files-path name="internal_apk_storage" path="ota_update/"/>\n</paths>\n')
need(os.path.exists('android/app/build.gradle.kts'), 'android/app/build.gradle.kts is missing (an older Groovy template?)')
edit('android/app/build.gradle.kts', gradle)
if os.path.exists('android/build.gradle.kts'): edit('android/build.gradle.kts', root_gradle)
if os.path.exists('ios/Runner/Info.plist'): edit('ios/Runner/Info.plist', plist)
# flutter create adds a sample test for its counter app – not this app
w = 'test/widget_test.dart'
if os.path.exists(w) and 'MyApp' in open(w).read(): os.remove(w)
print('patched')
