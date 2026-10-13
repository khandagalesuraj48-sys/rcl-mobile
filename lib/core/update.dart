/* UPDATE FROM INSIDE THE APP (asked 13-10-2026): the app asks the Portal for its newest version.
 *   Android – the new app file (APK) is kept in a PRIVATE store of the Portal (Supabase Storage); the Portal gives a signed
 *             person a link that works for 10 minutes. The app downloads it, checks its fingerprint (SHA-256) and hands it
 *             to Android's installer – which installs it only if it is signed with the SAME key as the app on the phone.
 *   iPhone  – Apple lets an app be updated only through the App Store / TestFlight: the app opens that page. */
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:ota_update/ota_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

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

/// A newer version than the one on this phone, or null (also when it cannot be asked – the app works on).
Future<AppUpdate?> checkUpdate(Api api) async {
  try {
    final info = await PackageInfo.fromPlatform();
    final cur = int.tryParse(info.buildNumber) ?? 0;
    final j = await api.latestApp(Platform.isIOS ? 'ios' : 'android');
    final b = j['build'];
    if (j['none'] == true || b is! num || b <= cur) return null;
    return AppUpdate(build: b.toInt(), version: (j['version'] ?? '').toString(), notes: (j['notes'] ?? '').toString(), url: (j['url'] ?? '').toString(), sha256: (j['sha256'] ?? '').toString(), store: (j['store'] ?? '').toString());
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
