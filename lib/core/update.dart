/* UPDATE FROM INSIDE THE APP: the app looks at the newest GitHub Release of its repository (asked 14-10-2026: "git release
 * madhe apk theun de"). The release carries the APK and, in its notes, its build number and fingerprint (SHA-256):
 *   <!-- rcl:{"build":102,"version":"1.0.1","sha256":"…"} -->
 *   Android – the app downloads the APK, checks the fingerprint and hands it to Android's installer – which installs it only
 *             if it is signed with the SAME key as the app on the phone (the key never leaves the private store).
 *             (3.19.1, asked 17-10-2026: "android warti app updet krtana khup slow hote te speed up kr") the release also has
 *             one APK per processor ("rcl-erp-<v>-<b>.arm64-v8a.apk", its fingerprint in "apk"): a phone downloads only its
 *             own – about half of the file for every phone; a release without it: that file, as before.
 *   Windows – (3.19.0) the app downloads the setup (RCL-ERP-Setup-….exe), checks its fingerprint ("win") and runs it: the
 *             setup closes the app, puts the new version in its place and opens it again (windows/installer.iss).
 *   iPhone  – Apple lets an app be updated only through the App Store / TestFlight (not yet set up).
 * (3.24.0, asked 19-10-2026: "jewa app la update detos n tya madhe kay new ale he 3 language madhe dakhaw … next time update pasun")
 * The update's question shows what is new in it in English, मराठी and हिंदी – the release's notes between <!-- rcl-new --> and
 * <!-- /rcl-new --> (.github/workflows/release.yml); a release without them: its name, as before. */
import 'dart:convert';
import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:http/http.dart' as http;
import 'package:ota_update/ota_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import 'api.dart';
import 'device.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import '../ui/t.dart';

class AppUpdate {
  AppUpdate({required this.build, required this.version, this.notes = '', this.url = '', this.sha256 = '', this.store = ''});
  final int build;
  final String version, notes, url, sha256, store;
}

Future<String> appVersion() async {
  try {
    final p = await PackageInfo.fromPlatform();
    return '${p.version} (${p.buildNumber})';
  } catch (_) {
    return '';
  }
}

/// (3.19.1) The processor this app runs on – its own file of the release; '' = not known (the file for every phone).
String Function() appAbi = () => switch (Abi.current()) { Abi.androidArm64 => 'arm64-v8a', Abi.androidArm => 'armeabi-v7a', _ => '' };

/// The ends of the one-processor files – never taken as the file for every phone.
const kAbiFiles = ['.arm64-v8a.apk', '.armeabi-v7a.apk', '.x86_64.apk'];

/// The update in a GitHub Release (its JSON from the GitHub API), when it is newer than [currentBuild] – else null.
/// [computer]: the Windows setup (.exe, fingerprint "win") instead of the Android app (.apk, fingerprint "sha256").
AppUpdate? parseRelease(Map<String, dynamic> j, int currentBuild, {bool computer = false}) {
  final m = RegExp(r'<!-- rcl:(\{.*?\}) -->').firstMatch((j['body'] ?? '').toString());
  if (m == null || j['draft'] == true || j['prerelease'] == true) return null;
  Map<String, dynamic> meta;
  try {
    meta = (jsonDecode(m.group(1)!) as Map).cast<String, dynamic>();
  } catch (_) {
    return null;
  }
  final b = meta['build'], sha = (meta[computer ? 'win' : 'sha256'] ?? '').toString();
  if (b is! num || b <= currentBuild || !RegExp(r'^[0-9a-f]{64}$').hasMatch(sha)) return null;
  final assets = (j['assets'] as List? ?? []).whereType<Map>().toList();
  String name(Map a) => (a['name'] ?? '').toString().toLowerCase();
  String link(Map a) => (a['browser_download_url'] ?? '').toString();
  final build = b.toInt();
  AppUpdate made(String url, String fingerprint) => AppUpdate(build: build, version: (meta['version'] ?? '').toString(), notes: releaseNotes(j), url: url, sha256: fingerprint);
  // (3.19.1) a phone: its own processor's file, when the release has it
  final abi = computer ? '' : appAbi(), own = meta['apk'];
  if (abi.isNotEmpty && own is Map) {
    final osha = (own[abi] ?? '').toString(), f = assets.firstWhere((a) => name(a).endsWith('.$abi.apk'), orElse: () => {});
    if (RegExp(r'^[0-9a-f]{64}$').hasMatch(osha) && link(f).startsWith('https://github.com/')) return made(link(f), osha);
  }
  final ext = computer ? '.exe' : '.apk';
  final file = assets.firstWhere((a) => name(a).endsWith(ext) && !kAbiFiles.any(name(a).endsWith), orElse: () => {});
  final url = link(file);
  if (!url.startsWith('https://github.com/')) return null;
  return made(url, sha);
}

/// (3.24.0) What is new in the release (English, मराठी, हिंदी – as written); a release without it: its name.
String releaseNotes(Map<String, dynamic> j) {
  final m = RegExp(r'<!-- rcl-new -->([\s\S]*?)<!-- /rcl-new -->').firstMatch((j['body'] ?? '').toString());
  final t = (m?.group(1) ?? '').replaceAll('\r', '').trim();
  return t.isNotEmpty ? t : (j['name'] ?? '').toString();
}

/// A newer version than the one on this phone, or null (also when it cannot be asked – the app works on).
Future<AppUpdate?> checkUpdate(Api api) async {
  if (Platform.isIOS) return null; // (the App Store / TestFlight – later)
  try {
    final info = await PackageInfo.fromPlatform();
    final r = await http.get(Uri.parse(kReleasesApi), headers: {'Accept': 'application/vnd.github+json'}).timeout(const Duration(seconds: 15));
    if (r.statusCode != 200) return null;
    return parseRelease((jsonDecode(utf8.decode(r.bodyBytes)) as Map).cast<String, dynamic>(), int.tryParse(info.buildNumber) ?? 0, computer: onComputer);
  } catch (_) {
    return null;
  }
}

Future<void> runUpdate(BuildContext context, AppUpdate u) async {
  if (Platform.isIOS) {
    if (u.store.isNotEmpty) await launchUrl(Uri.parse(u.store), mode: LaunchMode.externalApplication);
    return;
  }
  if (onComputer) return _updateComputer(context, u);
  final ok = await ask(context, 'Update to ${u.version}?', bi('The app downloads the new version and Android asks you to install it.', 'नवीन version download होईल; Android install विचारेल.', '\n\n'), plain: u.notes, yes: 'Update');
  if (!ok || !context.mounted) return;
  final progress = ValueNotifier<String>('Starting…');
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (c) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text('Updating'),
      content: ValueListenableBuilder<String>(
        valueListenable: progress,
        builder: (_, v, __) => Column(mainAxisSize: MainAxisSize.min, children: [
          LinearProgressIndicator(value: double.tryParse(v) == null ? null : double.parse(v) / 100, color: C.green),
          const SizedBox(height: 12),
          Text(double.tryParse(v) == null ? v : 'Downloading… $v%'),
        ]),
      ),
    ),
  );
  void close(String? msg) {
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    if (msg != null) toast(context, msg, bad: true);
  }

  try {
    OtaUpdate().execute(u.url, destinationFilename: 'rcl-erp-${u.version}.apk', sha256checksum: u.sha256.isEmpty ? null : u.sha256).listen(
      (e) {
        switch (e.status) {
          case OtaStatus.DOWNLOADING:
            progress.value = e.value ?? '';
          case OtaStatus.INSTALLING:
          case OtaStatus.INSTALLATION_DONE:
            close(null);
          case OtaStatus.CHECKSUM_ERROR:
            close('The download was not complete or not genuine – nothing was installed. Try again.');
          case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
            close('Allow "Install unknown apps" for RCL ERP in Android settings, then try again.');
          case OtaStatus.CANCELED:
            close(null);
          default:
            close('The update could not be finished (${e.status.name}). Try again.');
        }
      },
      onError: (_) => close('The update could not be downloaded – check the internet and try again.'),
    );
  } catch (_) {
    close('The update could not be started – try again.');
  }
}

/* ---------- (3.19.0) THE WINDOWS UPDATE ---------- */

/// Why the update stopped – said to the person as it is.
class UpdateProblem implements Exception {
  const UpdateProblem(this.message);
  final String message;
  @override
  String toString() => message;
}

/// (a test) where the setup is downloaded from.
http.Client Function() updateClient = http.Client.new;

/// Runs the downloaded setup and closes the app ((a test) its own: nothing is run).
Future<void> Function(String setup) startSetup = _startSetup;

Future<void> _startSetup(String setup) async {
  // /SILENT: only its progress is shown; /CLOSEAPPLICATIONS: this app is closed if it is still open; at the end the setup opens
  // the new version (installer.iss, [Run])
  await Process.start(setup, const ['/SILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/CLOSEAPPLICATIONS'], mode: ProcessStartMode.detached);
  await Future<void>.delayed(const Duration(milliseconds: 300));
  exit(0);
}

class _Digest implements Sink<Digest> {
  Digest? value;
  @override
  void add(Digest data) => value = data;
  @override
  void close() {}
}

/// Downloads the setup of [u] into [dir] (an older one there is taken out) and checks its fingerprint; gives its path.
/// [done]: the percent downloaded.
Future<String> downloadSetup(AppUpdate u, Directory dir, void Function(int percent) done) async {
  final c = updateClient();
  try {
    final r = await c.send(http.Request('GET', Uri.parse(u.url))).timeout(const Duration(seconds: 30));
    if (r.statusCode != 200) throw const UpdateProblem('The update could not be downloaded – check the internet and try again.');
    await dir.create(recursive: true);
    for (final e in dir.listSync()) {
      try {
        if (e is File) e.deleteSync();
      } catch (_) {}
    }
    final f = File('${dir.path}${Platform.pathSeparator}RCL-ERP-Setup-${u.version}-${u.build}.exe');
    final out = f.openWrite(), dig = _Digest(), hash = sha256.startChunkedConversion(dig);
    final total = r.contentLength ?? 0;
    var got = 0, last = -1;
    try {
      await for (final part in r.stream.timeout(const Duration(seconds: 60))) {
        out.add(part);
        hash.add(part);
        got += part.length;
        final p = total > 0 ? got * 100 ~/ total : -1;
        if (p >= 0 && p != last) done(last = p);
      }
    } finally {
      await out.close();
    }
    hash.close();
    if (dig.value?.toString() != u.sha256.toLowerCase()) {
      try {
        await f.delete();
      } catch (_) {}
      throw const UpdateProblem('The download was not complete or not genuine – nothing was installed. Try again.');
    }
    return f.path;
  } finally {
    c.close();
  }
}

Future<void> _updateComputer(BuildContext context, AppUpdate u) async {
  final ok = await ask(context, 'Update to ${u.version}?',
      bi('The app downloads the new version, closes, installs it and opens again (about a minute).', 'नवीन version download होईल; app बंद होऊन install होईल आणि पुन्हा उघडेल (सुमारे 1 मिनिट).', '\n\n'),
      plain: u.notes, yes: 'Update');
  if (!ok || !context.mounted) return;
  final progress = ValueNotifier<String>('Starting…');
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (c) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text('Updating'),
      content: ValueListenableBuilder<String>(
        valueListenable: progress,
        builder: (_, v, __) => Column(mainAxisSize: MainAxisSize.min, children: [
          LinearProgressIndicator(value: double.tryParse(v) == null ? null : double.parse(v) / 100, color: C.green),
          const SizedBox(height: 12),
          Text(double.tryParse(v) == null ? v : 'Downloading… $v%'),
        ]),
      ),
    ),
  );
  void close(String? msg) {
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    if (msg != null) toast(context, msg, bad: true);
  }

  try {
    final setup = await downloadSetup(u, Directory('${Directory.systemTemp.path}${Platform.pathSeparator}rcl_update'), (p) => progress.value = '$p');
    progress.value = 'Installing – the app closes and opens again…';
    await startSetup(setup);
    close(null);
  } on UpdateProblem catch (e) {
    close(e.message);
  } catch (_) {
    close('The update could not be downloaded – check the internet and try again.');
  }
}
