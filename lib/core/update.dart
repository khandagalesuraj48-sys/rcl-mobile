/* UPDATE FROM INSIDE THE APP: the app looks at the newest GitHub Release of its repository (asked 14-10-2026: "git release
 * madhe apk theun de"). The release carries the APK and, in its notes, its build number and fingerprint (SHA-256):
 *   <!-- rcl:{"build":102,"version":"1.0.1","sha256":"…"} -->
 *   Android – the app downloads the APK, checks the fingerprint and hands it to Android's installer – which installs it only
 *             if it is signed with the SAME key as the app on the phone (the key never leaves the private store).
 *   iPhone  – Apple lets an app be updated only through the App Store / TestFlight (not yet set up). */
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:ota_update/ota_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import 'api.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

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

/// The update in a GitHub Release (its JSON from the GitHub API), when it is newer than [currentBuild] – else null.
AppUpdate? parseRelease(Map<String, dynamic> j, int currentBuild) {
  final m = RegExp(r'<!-- rcl:(\{.*?\}) -->').firstMatch((j['body'] ?? '').toString());
  if (m == null || j['draft'] == true || j['prerelease'] == true) return null;
  Map<String, dynamic> meta;
  try {
    meta = (jsonDecode(m.group(1)!) as Map).cast<String, dynamic>();
  } catch (_) {
    return null;
  }
  final b = meta['build'], sha = (meta['sha256'] ?? '').toString();
  if (b is! num || b <= currentBuild || !RegExp(r'^[0-9a-f]{64}$').hasMatch(sha)) return null;
  final apk = (j['assets'] as List? ?? []).whereType<Map>().firstWhere((a) => (a['name'] ?? '').toString().endsWith('.apk'), orElse: () => {});
  final url = (apk['browser_download_url'] ?? '').toString();
  if (!url.startsWith('https://github.com/')) return null;
  return AppUpdate(build: b.toInt(), version: (meta['version'] ?? '').toString(), notes: (j['name'] ?? '').toString(), url: url, sha256: sha);
}

/// A newer version than the one on this phone, or null (also when it cannot be asked – the app works on).
Future<AppUpdate?> checkUpdate(Api api) async {
  if (Platform.isIOS) return null; // (the App Store / TestFlight – later)
  try {
    final info = await PackageInfo.fromPlatform();
    final r = await http.get(Uri.parse(kReleasesApi), headers: {'Accept': 'application/vnd.github+json'}).timeout(const Duration(seconds: 15));
    if (r.statusCode != 200) return null;
    return parseRelease((jsonDecode(utf8.decode(r.bodyBytes)) as Map).cast<String, dynamic>(), int.tryParse(info.buildNumber) ?? 0);
  } catch (_) {
    return null;
  }
}

Future<void> runUpdate(BuildContext context, AppUpdate u) async {
  if (Platform.isIOS) {
    if (u.store.isNotEmpty) await launchUrl(Uri.parse(u.store), mode: LaunchMode.externalApplication);
    return;
  }
  final ok = await ask(context, 'Update to ${u.version}?', [if (u.notes.isNotEmpty) u.notes, 'The app downloads the new version and Android asks you to install it.', 'नवीन version download होईल; Android install विचारेल.'].join('\n\n'), yes: 'Update');
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
