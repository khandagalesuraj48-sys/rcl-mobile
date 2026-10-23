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
 * <!-- /rcl-new --> (.github/workflows/release.yml); a release without them: its name, as before.
 * (3.31.4, asked 23-10-2026: "app madhun baher al ki updet hoych band hot nantr app prt chalu krun prt sagle 0 pasun start hot tr as nko
 * … background la app updet chaluch asel ani complte al ki konte hi screen war aso mi install karaychi as ek pop up eil mi install
 * bolel ani install hoil") Android: the update is downloaded by Android's own Download Manager (UpdateKit.kt) – it goes on when the
 * app is left or closed, and is not started again from 0. When it is there and its fingerprint is right: "Install?" over whatever
 * screen of the app is open (or the notification "Update ready – tap to install" when the app is away – it opens the app, which
 * asks). "Later": asked again the next time the app is opened. A phone whose Download Manager cannot be used: as before. */
import 'dart:async';
import 'dart:convert';
import 'dart:ffi' show Abi;
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
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
  // (3.31.4) this update is already downloading (or there): no question, never again from 0
  if (bgUpdates()) {
    final s = await _bgState();
    if (!context.mounted) return;
    if (s != null && s.build == u.build && s.sha.toLowerCase() == u.sha256.toLowerCase() && (s.going || s.status == 'done')) {
      _bgLater = 0;
      await updateWatch();
      if (s.going && context.mounted) _bgDialog(context);
      return;
    }
  }
  final ok = await ask(
      context,
      'Update to ${u.version}?',
      bi('The update downloads in the background – keep working, or leave the app. When it is ready, the app asks you to install it.',
          'अपडेट मागे (background ला) डाउनलोड होईल – काम चालू ठेवा किंवा ॲपमधून बाहेर जा. तयार झाले की ॲप install विचारेल.', '\n\n'),
      plain: u.notes,
      yes: 'Update');
  if (!ok || !context.mounted) return;
  // (3.31.4) Android's Download Manager; a phone where it cannot be used: the download inside the app, as before
  final bg = await startBgUpdate(u);
  if (!context.mounted) return;
  if (bg != 'failed') {
    if (bg != 'done') _bgDialog(context);
    return;
  }
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

/* ---------- (3.31.4) THE UPDATE IN THE BACKGROUND (Android – UpdateKit.kt) ---------- */

/// A download of an update kept by Android's Download Manager. [status]: pending | running | paused | done | failed | gone.
class BgUpdate {
  const BgUpdate({required this.status, this.got = 0, this.total = -1, this.path = '', this.version = '', this.build = 0, this.sha = ''});
  final String status, path, version, sha;
  final int got, total, build;
  bool get going => status == 'pending' || status == 'running' || status == 'paused';
  int get percent => total > 0 ? (got * 100 ~/ total).clamp(0, 100).toInt() : -1;

  /// From the phone's answer; null = no download kept.
  static BgUpdate? of(Object? m) {
    if (m is! Map || m['id'] == null) return null;
    int n(Object? v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;
    return BgUpdate(status: '${m['status'] ?? 'gone'}', got: n(m['got']), total: m['total'] == null ? -1 : n(m['total']), path: '${m['path'] ?? ''}',
        version: '${m['version'] ?? ''}', build: n(m['build']), sha: '${m['sha'] ?? ''}');
  }
}

const _bgChannel = MethodChannel('rcl/update');

/// (a test) the phone's side (UpdateKit.kt)
Future<Object?> Function(String method, [Map<String, Object?>? args]) bgCall = (m, [a]) => _bgChannel.invokeMethod<Object?>(m, a);

/// (a test) the build of this app
Future<int> Function() appBuild = () async {
  try {
    return int.tryParse((await PackageInfo.fromPlatform()).buildNumber) ?? 0;
  } catch (_) {
    return 0;
  }
};

/// (a test) a file's fingerprint (SHA-256), worked out in the background
Future<String> Function(String path) fileSha = (p) => Isolate.run(() async => (await sha256.bind(File(p).openRead()).first).toString());

/// (main.dart) the screen open now – the box "Install?" comes over it, whatever it is
BuildContext? Function() updateContext = () => null;

/// (a test) this phone's updates go through the Download Manager (Android – not a computer)
bool Function() bgUpdates = () => Platform.isAndroid && !onComputer;

/// The background update now (the progress box listens to it); null = none.
final bgUpdateNow = ValueNotifier<BgUpdate?>(null);

Timer? _bgTimer;
bool _bgBusy = false, _bgAsking = false;
int _bgLater = 0; // the build put off with "Later" – asked again when the app is opened again
String _bgChecked = ''; // the file whose fingerprint was found right
DialogRoute<void>? _bgRoute; // the progress box

Future<BgUpdate?> _bgState() async {
  try {
    return BgUpdate.of(await bgCall('state'));
  } catch (_) {
    return null;
  }
}

Future<void> _bgForget() async {
  _bgChecked = '';
  try {
    await bgCall('forget');
  } catch (_) {/* nothing kept */}
}

void _bgStop() {
  _bgTimer?.cancel();
  _bgTimer = null;
}

void _bgClose() {
  final r = _bgRoute;
  _bgRoute = null;
  if (r != null && r.isActive) r.navigator?.removeRoute(r);
}

/// (a test) the watch stopped and forgotten
void resetBgUpdate() {
  _bgStop();
  _bgBusy = _bgAsking = false;
  _bgLater = 0;
  _bgChecked = '';
  _bgRoute = null;
  bgUpdateNow.value = null;
}

/// Starts the background download of [u] – or keeps the one already going (or done) for it: never again from 0.
/// → 'started' | 'going' | 'done' | 'failed' (the Download Manager cannot be used on this phone).
Future<String> startBgUpdate(AppUpdate u) async {
  if (!bgUpdates()) return 'failed';
  final s = await _bgState();
  if (s != null && s.build == u.build && s.sha.toLowerCase() == u.sha256.toLowerCase() && (s.going || s.status == 'done')) {
    _bgLater = 0;
    await updateWatch();
    return s.going ? 'going' : 'done';
  }
  try {
    await bgCall('start', {'url': u.url, 'file': 'rcl-erp-${u.version}-${u.build}.apk', 'version': u.version, 'build': u.build, 'sha': u.sha256.toLowerCase()});
  } catch (_) {
    return 'failed';
  }
  _bgLater = 0;
  _bgChecked = '';
  await updateWatch();
  return 'started';
}

/// Looks at the background update – when the app is opened or comes back ([opened]: "Later" is asked again), and every 2 s while it
/// downloads. Ready and right → "Install?" over the screen that is open; gone wrong → said once (Update starts it again).
Future<void> updateWatch({bool opened = false}) async {
  if (!bgUpdates() || _bgBusy) return;
  _bgBusy = true;
  try {
    if (opened) _bgLater = 0;
    final s = await _bgState();
    if (s == null) {
      _bgStop();
      _bgClose();
      bgUpdateNow.value = null;
      return;
    }
    if (s.build <= await appBuild()) {
      // installed (or an older one): its file goes
      _bgStop();
      _bgClose();
      bgUpdateNow.value = null;
      await _bgForget();
      return;
    }
    bgUpdateNow.value = s;
    if (s.going) {
      _bgTimer ??= Timer.periodic(const Duration(seconds: 2), (_) => updateWatch());
      return;
    }
    _bgStop();
    _bgClose();
    if (s.status == 'done') {
      unawaited(_bgOffer(s));
      return;
    }
    await _bgForget();
    bgUpdateNow.value = null;
    final ctx = updateContext();
    if (ctx != null && ctx.mounted) toast(ctx, tr('The update could not be downloaded – check the internet and try again.'), bad: true);
  } finally {
    _bgBusy = false;
  }
}

/// The download is there: its fingerprint checked (once), then "Install?" over the screen that is open.
Future<void> _bgOffer(BgUpdate s) async {
  if (_bgAsking || _bgLater == s.build) return;
  final ctx = updateContext();
  if (ctx == null || !ctx.mounted) return; // asked when a screen is there (the app opened again)
  _bgAsking = true;
  try {
    if (_bgChecked != s.path) {
      var got = '';
      try {
        got = await fileSha(s.path);
      } catch (_) {/* not readable: as not right */}
      if (got.toLowerCase() != s.sha.toLowerCase() || s.sha.isEmpty) {
        await _bgForget();
        bgUpdateNow.value = null;
        final c = updateContext();
        if (c != null && c.mounted) toast(c, tr('The download was not complete or not genuine – nothing was installed. Try again.'), bad: true);
        return;
      }
      _bgChecked = s.path;
    }
    try {
      await bgCall('clearNote');
    } catch (_) {/* no notification */}
    final c = updateContext();
    if (c == null || !c.mounted) return;
    final yes = await ask(c, 'Update ${s.version} is ready',
        bi('Install it now? Android asks once more – press Install there.', 'आता install करायचे? Android पुन्हा एकदा विचारेल – तिथे Install दाबा.', '\n\n'),
        yes: 'Install', no: 'Later');
    if (!yes) {
      _bgLater = s.build;
      return;
    }
    var r = '';
    try {
      r = '${await bgCall('install', {'path': s.path})}';
    } catch (_) {
      r = 'error';
    }
    final c2 = updateContext();
    if (c2 == null || !c2.mounted) return;
    if (r == 'permission') {
      toast(c2, bi('Allow "Install unknown apps" for RCL ERP, then come back – Install is asked again.', 'RCL ERP ला "Install unknown apps" परवानगी द्या आणि परत या – Install पुन्हा विचारले जाईल.'), bad: true);
    } else if (r == 'missing') {
      await _bgForget();
      bgUpdateNow.value = null;
      toast(c2, tr('The download was not complete or not genuine – nothing was installed. Try again.'), bad: true);
    } else if (r != 'ok') {
      toast(c2, tr('The update could not be finished ({0}). Try again.').replaceAll('{0}', r), bad: true);
    }
  } finally {
    _bgAsking = false;
  }
}

/// The progress of the background download – it may be closed: the download goes on ("Keep working").
void _bgDialog(BuildContext context) {
  _bgClose();
  final r = DialogRoute<void>(
    context: context,
    builder: (c) => AlertDialog(
      key: const Key('upd-bg'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text('Updating'),
      content: ValueListenableBuilder<BgUpdate?>(
        valueListenable: bgUpdateNow,
        builder: (_, s, __) {
          final p = s?.percent ?? -1;
          return Column(mainAxisSize: MainAxisSize.min, children: [
            LinearProgressIndicator(value: p < 0 ? null : p / 100, color: C.green),
            const SizedBox(height: 12),
            Text(p < 0 ? 'Starting…' : 'Downloading… $p%', key: const Key('upd-bg-pct')),
            const SizedBox(height: 10),
            Text(bi('It goes on in the background – you may close this or leave the app.', 'हे मागे (background ला) चालूच राहील – हे बंद करा किंवा ॲपमधून बाहेर जा.'),
                style: const TextStyle(fontSize: 13, color: C.muted)),
          ]);
        },
      ),
      actions: [TextButton(key: const Key('upd-bg-hide'), onPressed: () => Navigator.of(c).pop(), child: const Text('Keep working'))],
    ),
  );
  _bgRoute = r;
  Navigator.of(context, rootNavigator: true).push(r);
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
