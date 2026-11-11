/* THE ADVERTISE CORNER on Home (3.100.0, asked 11-11-2026): "Rachana Media & Celebration Hub … he aple advertise corner asel";
 * "auto play haway fkt sound mute asel but unmute krta yeil ani ya animations mule … app speed kami nako"; "he weg wegle as watu
 * naye". The posts are set by the Super Admin in the Portal (its /api/ads: where, the size, the period, the days, the hours);
 * the Portal gives this phone only the posts of the site open that show NOW. Here they are only shown:
 *  – asked after Home is drawn, never with Home's own figures; no post (or no answer) = nothing on Home, as before;
 *  – one image or video at a time; a video plays by itself, MUTED, only while Home is the tab seen and the app is in front;
 *  – asked again when he comes back to Home after 10 minutes (a post's hours begin and end; a file's link works one hour);
 *  – a "Full screen" post opens once over Home (✕ closes it); a "Card" post shows as a Banner in this version. */
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../core/session.dart';
import 'scope.dart';
import 'theme.dart';

class AdPost {
  AdPost(Map m)
      : id = '${m['id'] ?? ''}',
        title = '${m['title'] ?? ''}',
        video = m['media'] == 'video',
        size = '${m['size'] ?? 'strip'}',
        seconds = m['seconds'] is num ? (m['seconds'] as num).toInt().clamp(3, 60) : 6,
        url = '${m['url'] ?? ''}',
        poster = '${m['poster'] ?? ''}';
  final String id, title, size, url, poster;
  final bool video;
  final int seconds;
}

/// The height of a post's place on Home.
double adHeight(String size) => size == 'strip' ? 96 : 164;

class AdCorner extends StatefulWidget {
  const AdCorner({super.key, required this.active});

  /// Home is the tab on the screen.
  final bool active;
  @override
  State<AdCorner> createState() => _AdCornerState();
}

class _AdCornerState extends State<AdCorner> with WidgetsBindingObserver {
  List<AdPost> posts = const [], full = const [];
  int i = 0;
  bool muted = true, front = true, asked = false, busy = false;
  DateTime? at;
  Timer? turn;
  String sig = '';
  static final Set<String> _fullSeen = {};      // a "Full screen" post: once while the app is open

  bool get playing => widget.active && front;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!asked) {
      asked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());      // after Home is drawn
    }
  }

  @override
  void didUpdateWidget(AdCorner old) {
    super.didUpdateWidget(old);
    if (widget.active != old.active) {
      if (widget.active && (at == null || DateTime.now().difference(at!) > const Duration(minutes: 10))) _load();
      _again();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState st) {
    final f = st == AppLifecycleState.resumed;
    if (f == front || !mounted) return;
    setState(() => front = f);
    _again();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    turn?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (busy || !mounted) return;
    final Session s = SessionScope.of(context);
    final site = s.api.site ?? '';
    if (site.isEmpty || !s.api.hasPortal) return;
    busy = true;
    at = DateTime.now();
    try {
      final r = await s.api.ads({'action': 'live', 'platform': 'app', 'site': site});
      final all = [for (final m in (r['posts'] as List? ?? const []).whereType<Map>()) AdPost(m)].where((p) => p.url.startsWith('https://') || p.url.startsWith('http://127.0.0.1')).toList();
      if (!mounted) return;
      final now = all.map((p) => '${p.id}${p.size}${p.seconds}').join('|');
      setState(() {
        posts = all.where((p) => p.size != 'full').toList();
        full = all.where((p) => p.size == 'full').toList();
        if (now != sig) i = 0;
        sig = now;
      });
      _again();
      _showFull();
    } catch (_) {
      // no posts this time: Home is as before (nothing is said)
    } finally {
      busy = false;
    }
  }

  // the turn of the next one: an image after its seconds; a video when it ends (or after its seconds, when that is sooner)
  void _again() {
    turn?.cancel();
    if (!mounted || !playing || posts.length < 2) return;
    turn = Timer(Duration(seconds: posts[i % posts.length].seconds), _next);
  }

  void _next() {
    if (!mounted || posts.isEmpty) return;
    setState(() => i = (i + 1) % posts.length);
    _again();
  }

  void _showFull() {
    if (!mounted || !playing) return;
    final p = full.where((x) => !_fullSeen.contains(x.id)).firstOrNull;
    if (p == null) return;
    _fullSeen.add(p.id);
    showGeneralDialog<void>(
      context: context,
      barrierColor: Colors.black,
      pageBuilder: (c, _, __) => Material(
        color: Colors.black,
        child: SafeArea(
          child: Stack(fit: StackFit.expand, children: [
            _AdMedia(key: ValueKey('full-${p.id}'), post: p, playing: true, muted: true, fit: BoxFit.contain, soundButton: true, onDone: () {}),
            Positioned(right: 8, top: 8, child: IconButton(key: const Key('ad-full-close'), tooltip: 'Close', onPressed: () => Navigator.of(c).pop(), icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28))),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) return const SizedBox.shrink();
    final p = posts[i % posts.length];
    final still = MediaQuery.of(context).disableAnimations;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Sp.edge, 12, Sp.edge, 0),
      child: AnimatedContainer(
        key: const Key('ad-corner'),
        duration: Duration(milliseconds: still ? 0 : 300),
        curve: Curves.easeOut,
        height: adHeight(p.size),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: C.greenDeep, borderRadius: BorderRadius.circular(22), boxShadow: softShadow()),
        child: GestureDetector(
          onHorizontalDragEnd: posts.length < 2
              ? null
              : (d) {
                  final v = d.primaryVelocity ?? 0;
                  if (v.abs() < 80) return;
                  setState(() => i = (i + (v < 0 ? 1 : posts.length - 1)) % posts.length);
                  _again();
                },
          child: Stack(fit: StackFit.expand, children: [
            AnimatedSwitcher(
              duration: Duration(milliseconds: still ? 0 : 450),
              child: _AdMedia(key: ValueKey('ad-${p.id}'), post: p, playing: playing, muted: muted, fit: BoxFit.cover, soundButton: false, onDone: () { if (posts.length > 1) _next(); }),
            ),
            if (p.video)
              Positioned(
                right: 8,
                top: 8,
                child: Material(
                  color: Colors.black45,
                  shape: const CircleBorder(),
                  child: InkWell(
                    key: const Key('ad-mute'),
                    customBorder: const CircleBorder(),
                    onTap: () => setState(() => muted = !muted),
                    child: Padding(padding: const EdgeInsets.all(7), child: Icon(muted ? Icons.volume_off_rounded : Icons.volume_up_rounded, color: Colors.white, size: 18)),
                  ),
                ),
              ),
            if (posts.length > 1)
              Positioned(
                left: 0,
                right: 0,
                bottom: 8,
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  for (var k = 0; k < posts.length; k++)
                    AnimatedContainer(duration: const Duration(milliseconds: 200), margin: const EdgeInsets.symmetric(horizontal: 2.5), width: k == i % posts.length ? 16 : 6, height: 5, decoration: BoxDecoration(color: k == i % posts.length ? Colors.white : Colors.white54, borderRadius: BorderRadius.circular(3))),
                ]),
              ),
          ]),
        ),
      ),
    );
  }
}

/// One post's image or video. A video: by itself, muted unless he turned the sound on, only while [playing]; where the phone
/// cannot play it (or its file does not come) its still picture stays.
class _AdMedia extends StatefulWidget {
  const _AdMedia({super.key, required this.post, required this.playing, required this.muted, required this.fit, required this.soundButton, required this.onDone});
  final AdPost post;
  final bool playing, muted, soundButton;
  final BoxFit fit;
  final VoidCallback onDone;
  @override
  State<_AdMedia> createState() => _AdMediaState();
}

class _AdMediaState extends State<_AdMedia> {
  VideoPlayerController? v;
  bool ready = false, done = false;
  late bool muted = widget.muted;

  @override
  void initState() {
    super.initState();
    if (widget.post.video) _start();
  }

  Future<void> _start() async {
    try {
      final c = VideoPlayerController.networkUrl(Uri.parse(widget.post.url));
      v = c;
      await c.initialize();
      if (!mounted) return;
      await c.setVolume(muted ? 0 : 1);
      c.addListener(_watch);
      setState(() => ready = true);
      if (widget.playing) await c.play();
    } catch (_) {
      // this phone cannot play it: the still picture stays
    }
  }

  void _watch() {
    final c = v;
    if (c == null || done) return;
    final x = c.value;
    if (x.isInitialized && x.duration > Duration.zero && x.position >= x.duration) {
      done = true;
      widget.onDone();
      // alone: from its start again
      if (mounted && widget.playing) {
        done = false;
        c.seekTo(Duration.zero).then((_) => c.play()).catchError((_) {});
      }
    }
  }

  @override
  void didUpdateWidget(_AdMedia old) {
    super.didUpdateWidget(old);
    final c = v;
    if (c == null || !ready) return;
    if (widget.muted != old.muted) {
      muted = widget.muted;
      c.setVolume(muted ? 0 : 1);
    }
    if (widget.playing != old.playing) widget.playing ? c.play() : c.pause();
  }

  @override
  void dispose() {
    v?.removeListener(_watch);
    v?.dispose();
    super.dispose();
  }

  Widget _picture(String url) => url.isEmpty
      ? const SizedBox.expand()
      : Image.network(url, fit: widget.fit, gaplessPlayback: true, filterQuality: FilterQuality.medium, semanticLabel: widget.post.title, errorBuilder: (_, __, ___) => const SizedBox.expand());

  @override
  Widget build(BuildContext context) {
    final p = widget.post;
    if (!p.video) return SizedBox.expand(child: _picture(p.url));
    final c = v;
    return Stack(fit: StackFit.expand, children: [
      _picture(p.poster),
      if (c != null && ready)
        FittedBox(fit: widget.fit, clipBehavior: Clip.hardEdge, child: SizedBox(width: c.value.size.width, height: c.value.size.height, child: VideoPlayer(c))),
      if (widget.soundButton && c != null && ready)
        Positioned(
          right: 12,
          bottom: 16,
          child: IconButton(
            tooltip: muted ? 'Sound on' : 'Sound off',
            style: IconButton.styleFrom(backgroundColor: Colors.black45),
            onPressed: () {
              setState(() => muted = !muted);
              c.setVolume(muted ? 0 : 1);
            },
            icon: Icon(muted ? Icons.volume_off_rounded : Icons.volume_up_rounded, color: Colors.white),
          ),
        ),
    ]);
  }
}
