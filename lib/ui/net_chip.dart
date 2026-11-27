/* (3.171.0 patch 4 – SNI, his approval of 25-11-2026: "he sagle tu dilel screen pn ok aahet asch banaw") WHAT THE PERSON SEES OF THE
 * NETWORK – the approved pictures:
 *   picture 1 / 2 – [NetChip]: a small chip in the header (dot + the measured time); see-through on a coloured band;
 *   picture 3     – [showNetSheet]: a tap on it – every server measured apart, Android's check, the last change, "Check now";
 *   picture 4     – [NetHost]: one line under the header when it matters – slow (a request waiting over 5 s), reconnecting, our server
 *                   not answering, no internet; it goes by itself when the state is good again (× hides it until the next change).
 * Everything comes from core/net.dart (real requests only); nothing is shown before the first answer but "Checking". */
import 'dart:async';

import 'package:flutter/material.dart';

import '../core/net.dart';
import 'scope.dart';
import 'theme.dart';

/// The app's message bar (MaterialApp.scaffoldMessengerKey): the line under the header is shown through it, on whatever screen.
final netMessenger = GlobalKey<ScaffoldMessengerState>();

Color netColor(NetState s) => switch (s) {
      NetState.good => C.green,
      NetState.weak => C.amber,
      NetState.unstable || NetState.reconnecting => C.orange,
      NetState.serverDown => C.red,
      NetState.offline => const Color(0xFF667085),
      NetState.checking => const Color(0xFF98A2B3),
    };

/// The chip's words: "240 ms", "Weak · 1.8 s", "Unstable", "Reconnecting", "Server down", "Offline", "Checking".
String netChipText(NetMonitor m) {
  final s = m.state, mid = m.middleAll;
  return switch (s) {
    NetState.good => mid == null ? w3('Good', 'चांगले', 'अच्छा') : msText(mid),
    NetState.weak => '${w3('Weak', 'कमकुवत', 'कमज़ोर')}${mid == null ? '' : ' · ${msText(mid)}'}',
    NetState.unstable => w3('Unstable', 'अस्थिर', 'अस्थिर'),
    NetState.reconnecting => w3('Reconnecting', 'पुन्हा जोडत आहे', 'फिर से जुड़ रहा है'),
    NetState.serverDown => w3('Server down', 'Server बंद', 'Server बंद'),
    NetState.offline => w3('Offline', 'Internet नाही', 'Internet नहीं'),
    NetState.checking => w3('Checking', 'तपासत आहे', 'जाँच रहा है'),
  };
}

/// A turning ring (reconnecting / waiting).
class NetSpin extends StatefulWidget {
  const NetSpin({super.key, this.size = 12, required this.color, this.track});
  final double size;
  final Color color;
  final Color? track;
  @override
  State<NetSpin> createState() => _NetSpinState();
}

class _NetSpinState extends State<NetSpin> {
  @override
  Widget build(BuildContext context) => SizedBox(
        width: widget.size,
        height: widget.size,
        child: CircularProgressIndicator(strokeWidth: widget.size / 6, color: widget.color, backgroundColor: widget.track ?? widget.color.withValues(alpha: .25)),
      );
}

/// Picture 1 (option A): the indicator in the header – a tap opens the details. [dark]: on a coloured band (see-through, white words);
/// null = from the header's own icon colour.
class NetChip extends StatelessWidget {
  const NetChip({super.key, this.dark, this.pad = true});
  final bool? dark;

  /// false: no room above and below it (Home's greeting line) – the chip alone.
  final bool pad;

  @override
  Widget build(BuildContext context) {
    final onBand = dark ?? ((IconTheme.of(context).color ?? C.ink).computeLuminance() > .6);
    return ListenableBuilder(
      listenable: NetMonitor.i,
      builder: (context, _) {
        final m = NetMonitor.i, s = m.state, col = netColor(s);
        final lead = s == NetState.reconnecting
            ? NetSpin(size: 12, color: onBand ? Colors.white : C.orange)
            : Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: s == NetState.checking ? Colors.transparent : col,
                  shape: BoxShape.circle,
                  border: s == NetState.checking ? Border.all(color: onBand ? Colors.white70 : col, width: 1.6) : (onBand ? Border.all(color: Colors.white, width: 1.4) : null),
                ),
              );
        return Semantics(
          button: true,
          label: '${w3('Network', 'नेटवर्क', 'नेटवर्क')}: ${netChipText(m)}',
          child: GestureDetector(
            key: const Key('net-chip'),
            behavior: HitTestBehavior.opaque,
            onTap: () => showNetSheet(context),
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: pad ? 8 : 0),
              child: Container(
                height: 26,
                padding: const EdgeInsets.fromLTRB(9, 0, 10, 0),
                decoration: BoxDecoration(
                  color: onBand ? Colors.white.withValues(alpha: .16) : Colors.white,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: onBand ? Colors.white.withValues(alpha: .6) : const Color(0xFFE3DCCB)),
                  boxShadow: onBand ? null : const [BoxShadow(color: Color(0x1A18221C), blurRadius: 3, offset: Offset(0, 1))],
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  lead,
                  const SizedBox(width: 6),
                  Text(netChipText(m), maxLines: 1, style: TextStyle(fontFamily: 'Rubik', fontSize: 12.5, fontWeight: FontWeight.w500, height: 1, color: onBand ? Colors.white : C.ink)),
                ]),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Picture 3: the details.
Future<void> showNetSheet(BuildContext context) {
  String site = '';
  try {
    site = SessionScope.read(context).site?.code ?? '';
  } catch (_) {/* no session above (a test) */}
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (c) => NetSheet(site: site),
  );
}

class NetSheet extends StatefulWidget {
  const NetSheet({super.key, this.site = ''});
  final String site;
  @override
  State<NetSheet> createState() => _NetSheetState();
}

class _NetSheetState extends State<NetSheet> {
  bool _busy = false;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 5), (_) => NetMonitor.i.tick()); // the 2 minutes move on while it is open
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  String _hm(DateTime t) => MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(t));

  String _word(NetState s) => switch (s) {
        NetState.good => w3('Good', 'चांगले', 'अच्छा'),
        NetState.weak => w3('Weak', 'कमकुवत', 'कमज़ोर'),
        NetState.unstable => w3('Unstable', 'अस्थिर', 'अस्थिर'),
        NetState.reconnecting => w3('Reconnecting', 'पुन्हा जोडत आहे', 'फिर से जुड़ रहा है'),
        NetState.serverDown => w3('Server not reachable', 'Server पोहोचत नाही', 'Server तक नहीं पहुँच रहे'),
        NetState.offline => w3('No internet', 'Internet नाही', 'Internet नहीं'),
        NetState.checking => w3('Checking', 'तपासत आहे', 'जाँच रहा है'),
      };

  String _why(NetMonitor m) {
    final (s, who) = m.worst;
    final name = serverName(who, widget.site);
    final r = who.isEmpty ? const <NetMark>[] : m.recent(who);
    final fails = r.where((x) => !x.ok).length;
    return switch (s) {
      NetState.checking => w3('Nothing measured yet – it shows after the app\'s first answer.', 'अजून काहीही मोजलेले नाही – app ला पहिले उत्तर आल्यावर दिसेल.', 'अभी कुछ नहीं मापा – app के पहले जवाब के बाद दिखेगा।'),
      NetState.good || NetState.weak => w3('Measured from the app\'s own work – no test traffic.', 'App च्या स्वतःच्या कामावरून मोजले – वेगळी चाचणी नाही.', 'App के अपने काम से मापा – कोई अलग जाँच नहीं।'),
      NetState.unstable => w3('$fails of the last ${r.length} requests to $name failed.', '$name कडे गेलेल्या शेवटच्या ${r.length} पैकी $fails request अयशस्वी.', '$name को गए आख़िरी ${r.length} में से $fails request विफल।'),
      NetState.reconnecting => w3('A request to $name got no answer – checking the internet.', '$name ला गेलेल्या request ला उत्तर नाही – internet तपासत आहे.', '$name को गए request का जवाब नहीं – internet जाँच रहा है।'),
      NetState.serverDown => w3('Your internet works. $name is not answering ($fails of the last ${r.length}). The app asks again by itself.', 'तुमचे internet चालू आहे. $name उत्तर देत नाही (शेवटच्या ${r.length} पैकी $fails). App स्वतः पुन्हा विचारेल.', 'आपका internet चालू है। $name जवाब नहीं दे रहा (आख़िरी ${r.length} में से $fails)। App ख़ुद फिर पूछेगा।'),
      NetState.offline => w3('No internet – mobile data is off or has no signal. The app asks again by itself.', 'Internet नाही – mobile data बंद आहे किंवा signal नाही. App स्वतः पुन्हा विचारेल.', 'Internet नहीं – mobile data बंद है या signal नहीं। App ख़ुद फिर पूछेगा।'),
    };
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: NetMonitor.i,
        builder: (context, _) {
          final m = NetMonitor.i, s = m.state, mid = m.middleAll;
          final known = m.servers;
          final rows = <Widget>[
            for (final k in known) _server(m, k),
          ];
          final ch = m.changedAt, from = m.changedFrom;
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(w3('Network', 'नेटवर्क', 'नेटवर्क'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600))),
                  OutlinedButton(
                    key: const Key('net-check'),
                    style: OutlinedButton.styleFrom(foregroundColor: C.green, side: const BorderSide(color: Color(0xFFCFE3D8), width: 1.5), shape: const StadiumBorder()),
                    onPressed: _busy
                        ? null
                        : () async {
                            setState(() => _busy = true);
                            await NetMonitor.i.checkNow();
                            if (mounted) setState(() => _busy = false);
                          },
                    child: _busy ? const NetSpin(size: 14, color: C.green) : Text(w3('Check now', 'आत्ता तपासा', 'अभी जाँचें'), style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ]),
                const SizedBox(height: 14),
                Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  s == NetState.reconnecting
                      ? const NetSpin(size: 14, color: C.orange)
                      : Container(width: 12, height: 12, decoration: BoxDecoration(color: netColor(s), shape: BoxShape.circle)),
                  const SizedBox(width: 10),
                  Flexible(child: Text(_word(s), key: const Key('net-word'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600))),
                  if ((s == NetState.good || s == NetState.weak) && mid != null) ...[
                    const SizedBox(width: 10),
                    Text('${w3('middle time', 'मधला वेळ', 'बीच का समय')} ${msText(mid)}\n${w3('the last 2 minutes', 'शेवटची 2 मिनिटे', 'आख़िरी 2 मिनट')}', style: const TextStyle(fontSize: 13, color: C.slate, height: 1.3)),
                  ],
                ]),
                const SizedBox(height: 8),
                Text(_why(m), style: const TextStyle(fontSize: 12.5, color: C.slate, height: 1.4)),
                if (rows.isNotEmpty) ...[
                  _sec(w3('Servers', 'Servers', 'Servers')),
                  ...rows,
                ],
                _sec(w3('This phone', 'हा फोन', 'यह फ़ोन')),
                if (m.internetAt != null)
                  _row(
                    w3('Internet', 'Internet', 'Internet'),
                    m.internet == true ? w3('works', 'चालू', 'चालू') : w3('no answer', 'उत्तर नाही', 'जवाब नहीं'),
                    m.internet == true ? C.green : C.red,
                    '${w3('check', 'तपासणी', 'जाँच')} ${_hm(m.internetAt!)}${m.internetMs == null ? '' : ' · ${msText(m.internetMs!)}'}',
                  )
                else
                  _row(w3('Internet', 'Internet', 'Internet'), w3('not checked', 'तपासले नाही', 'नहीं जाँचा'), null, w3('only when a server fails', 'server अयशस्वी झाल्यावरच', 'server विफल होने पर ही')),
                if (ch != null && from != null && from != NetState.checking) _row(w3('Last change', 'शेवटचा बदल', 'आख़िरी बदलाव'), _hm(ch), null, '${_word(from)} → ${_word(s)}'),
              ]),
            ),
          );
        },
      );

  Widget _sec(String t) => Padding(padding: const EdgeInsets.fromLTRB(0, 16, 0, 4), child: Text(t, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: C.slate)));

  Widget _server(NetMonitor m, String k) {
    final r = m.recent(k), st = m.stateOf(k), mid = m.middleMs(k), fails = r.where((x) => !x.ok).length;
    final down = st == NetState.serverDown || st == NetState.offline || st == NetState.reconnecting;
    return _row(
      serverName(k, widget.site),
      down ? w3('no answer', 'उत्तर नाही', 'जवाब नहीं') : (mid == null ? '–' : msText(mid)),
      netColor(st),
      '${r.length - fails} ${w3('answers', 'उत्तरे', 'जवाब')} · $fails ${w3('failed', 'अयशस्वी', 'विफल')}',
      key: Key('net-server-$k'),
    );
  }

  Widget _row(String name, String value, Color? dot, String small, {Key? key}) => Container(
        key: key,
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF0EEE8)))),
        child: Row(children: [
          Expanded(child: Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
          SizedBox(
            width: 104,
            child: Row(children: [
              if (dot != null) ...[Container(width: 8, height: 8, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)), const SizedBox(width: 6)],
              Flexible(child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: dot == C.red ? C.red : C.ink))),
            ]),
          ),
          SizedBox(width: 120, child: Text(small, textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, color: Color(0xFF667085)))),
        ]),
      );
}

/// Picture 4: which line is shown under the header now ('' = none).
String netLineKind(NetMonitor m) {
  final s = m.state;
  if (s == NetState.offline) return 'offline';
  if (s == NetState.serverDown) return 'server';
  if (s == NetState.reconnecting) return 'reconnect';
  if (m.slowest != null) return 'slow';
  return '';
}

/// Picture 2, a header with no room (a form, a page whose title is long): the chip HANGS on the header's lower edge, on the right –
/// nothing is taken from the title. [NetPin] goes into the header (withAsk, hrHead): it takes no room; [NetHost] draws the chip where
/// the page's header ends (its Scaffold's app bar), only while that page is the one in front (a box or a sheet over it: not shown).
class NetPin extends StatefulWidget {
  const NetPin({super.key});
  @override
  State<NetPin> createState() => _NetPinState();
}

class _NetPinState extends State<NetPin> {
  // its page and whether it moves (the inherited widgets are read here, never while the chip looks for its place)
  ModalRoute<dynamic>? _route;
  bool _ticks = true;

  @override
  void initState() {
    super.initState();
    _NetPins.i.add(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
    _ticks = TickerMode.valuesOf(context).enabled;
    _NetPins.i.soon();
  }

  @override
  void dispose() {
    _NetPins.i.remove(this);
    super.dispose();
  }

  /// Where it hangs now: the right end of the header's lower edge (on the screen), or null – its page is not the one in front.
  Rect? where() {
    if (!mounted) return null;
    final r = _route;
    if (r != null && (!r.isCurrent || !r.isActive)) return null;
    if (!_ticks) return null;
    final sc = context.findAncestorStateOfType<ScaffoldState>(), h = sc?.appBarMaxHeight;
    if (sc == null || h == null) return null;
    final box = sc.context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    final o = box.localToGlobal(Offset.zero);
    return Rect.fromLTWH(o.dx, o.dy, box.size.width, h);
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _NetPins extends ChangeNotifier {
  static final _NetPins i = _NetPins();
  final List<_NetPinState> _all = [];
  bool _asked = false;

  /// Told after the frame – a pin comes or goes while the screen is being built.
  void soon() {
    if (_asked) return;
    _asked = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _asked = false;
      notifyListeners();
    });
  }

  void add(_NetPinState p) {
    _all.add(p);
    soon();
  }

  void remove(_NetPinState p) {
    _all.remove(p);
    soon();
  }

  /// The pin of the page in front (the newest one that is on the screen).
  Rect? get where {
    for (final p in _all.reversed) {
      final w = p.where();
      if (w != null) return w;
    }
    return null;
  }
}

class _NetHang extends StatefulWidget {
  const _NetHang();
  @override
  State<_NetHang> createState() => _NetHangState();
}

class _NetHangState extends State<_NetHang> {
  Timer? _t;
  Rect? _at;

  @override
  void initState() {
    super.initState();
    _NetPins.i.addListener(_look);
    // a page that moves in or out, a box that opens over it: looked at again a few times a second (only while a pin exists)
    _t = Timer.periodic(const Duration(milliseconds: 250), (_) => _look());
    WidgetsBinding.instance.addPostFrameCallback((_) => _look());
  }

  @override
  void dispose() {
    _NetPins.i.removeListener(_look);
    _t?.cancel();
    super.dispose();
  }

  void _look() {
    if (!mounted) return;
    final w = _NetPins.i._all.isEmpty ? null : _NetPins.i.where;
    if (w != _at) setState(() => _at = w);
  }

  @override
  Widget build(BuildContext context) {
    final w = _at;
    if (w == null) return const SizedBox.shrink();
    final full = MediaQuery.sizeOf(context).width;
    // (over the pages, outside their Material: its own see-through Material gives the words their style)
    return Positioned(right: full - w.right + 16, top: w.bottom - 13, child: const Material(type: MaterialType.transparency, child: NetChip(dark: false, pad: false)));
  }
}

/// Holds the network monitor's rhythm while the app is in front (every 5 s; nothing in the background) and shows the line of
/// picture 4 through [netMessenger].
class NetHost extends StatefulWidget {
  const NetHost({super.key, required this.child});
  final Widget child;
  @override
  State<NetHost> createState() => _NetHostState();
}

class _NetHostState extends State<NetHost> with WidgetsBindingObserver {
  Timer? _t;
  int _n = 0;
  String _shown = '', _closed = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    NetMonitor.i.addListener(_sync);
    _start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    NetMonitor.i.removeListener(_sync);
    _t?.cancel();
    super.dispose();
  }

  void _start() {
    if (!NetMonitor.i.on) return;
    _t?.cancel();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (++_n % 5 == 0) NetMonitor.i.tick();
      _sync();
    });
    NetMonitor.i.tick();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _start();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _t?.cancel();
      _t = null;
    }
  }

  void _sync() {
    if (!mounted || !NetMonitor.i.on) return;
    final k = netLineKind(NetMonitor.i);
    if (k != _closed) _closed = '';
    final want = k == _closed ? '' : k;
    if (want == _shown) return;
    final ms = netMessenger.currentState;
    if (ms == null) return;
    _shown = want;
    ms.clearMaterialBanners();
    if (want.isEmpty) return;
    ms.showMaterialBanner(_banner(want));
  }

  MaterialBanner _banner(String kind) {
    final (bg, fg, icon) = switch (kind) {
      'slow' => (const Color(0xFFFFF3DC), const Color(0xFF7A4A00), Icons.speed_rounded),
      'reconnect' => (const Color(0xFFFDEBE3), const Color(0xFF9A3A12), Icons.sync_rounded),
      'server' => (const Color(0xFFFDECEC), const Color(0xFF9F1D1D), Icons.dns_rounded),
      _ => (const Color(0xFFEEF0F3), const Color(0xFF344054), Icons.wifi_off_rounded),
    };
    final who = serverName(NetMonitor.i.worst.$2, _site());
    final (title, body) = switch (kind) {
      'slow' => (
          w3('Slow network – still waiting for the server', 'Network हळू – server च्या उत्तराची वाट', 'Network धीमा – server के जवाब का इंतज़ार'),
          w3('Do not press again – it goes on by itself.', 'पुन्हा दाबू नका – ते आपोआप चालू आहे.', 'फिर से न दबाएँ – यह अपने आप चल रहा है।')
        ),
      'reconnect' => (
          w3('No answer – trying again', 'उत्तर नाही – पुन्हा प्रयत्न', 'जवाब नहीं – फिर कोशिश'),
          w3('What you see was read before; it updates when the answer comes.', 'जे दिसत आहे ते आधी वाचलेले आहे; उत्तर आल्यावर बदलेल.', 'जो दिख रहा है वह पहले पढ़ा गया है; जवाब आने पर बदलेगा।')
        ),
      'server' => (
          w3('$who is not answering', '$who उत्तर देत नाही', '$who जवाब नहीं दे रहा'),
          w3('Your internet works. The app asks again by itself.', 'तुमचे internet चालू आहे. App स्वतः पुन्हा विचारेल.', 'आपका internet चालू है। App ख़ुद फिर पूछेगा।')
        ),
      _ => (
          w3('No internet', 'Internet नाही', 'Internet नहीं'),
          w3('Mobile data is off or has no signal. The app asks again by itself.', 'Mobile data बंद आहे किंवा signal नाही. App स्वतः पुन्हा विचारेल.', 'Mobile data बंद है या signal नहीं। App ख़ुद फिर पूछेगा।')
        ),
    };
    return MaterialBanner(
      key: Key('net-line-$kind'),
      backgroundColor: bg,
      dividerColor: Colors.transparent,
      elevation: 0,
      padding: const EdgeInsets.fromLTRB(16, 10, 4, 10),
      leading: kind == 'reconnect' ? NetSpin(size: 18, color: fg) : Icon(icon, color: fg, size: 20),
      leadingPadding: const EdgeInsets.only(right: 10),
      content: GestureDetector(
        onTap: () {
          final c = netMessenger.currentContext;
          if (c != null) showNetSheet(c);
        },
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: fg, height: 1.3)),
          Text(body, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: fg, height: 1.35)),
        ]),
      ),
      actions: [
        IconButton(
          key: const Key('net-line-close'),
          tooltip: w3('Hide', 'लपवा', 'छिपाएँ'),
          icon: Icon(Icons.close_rounded, color: fg, size: 18),
          onPressed: () {
            _closed = kind;
            _shown = '';
            netMessenger.currentState?.clearMaterialBanners();
          },
        ),
      ],
    );
  }

  String _site() {
    try {
      return SessionScope.read(context).site?.code ?? '';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) => Stack(fit: StackFit.expand, children: [widget.child, const _NetHang()]);
}

/// Picture 5: a page shown from what the phone read last says so, with the time – 'saved' (the server is being asked), 'live' (its
/// answer came: "Live · just now", then the line goes), 'stale' (the server did not answer: the copy stays, marked). '' = nothing.
/// The kind after a server's answer: 'live' only when a copy was shown before (a first opening shows no line).
String afterAnswer(String kind) => kind == 'saved' || kind == 'stale' ? 'live' : kind;

class SavedLine extends StatefulWidget {
  const SavedLine({super.key, required this.kind, this.at});
  final String kind;
  final DateTime? at;
  @override
  State<SavedLine> createState() => _SavedLineState();
}

class _SavedLineState extends State<SavedLine> {
  Timer? _t;
  bool _gone = false;

  @override
  void initState() {
    super.initState();
    _arm();
  }

  @override
  void didUpdateWidget(covariant SavedLine old) {
    super.didUpdateWidget(old);
    if (old.kind != widget.kind) {
      _gone = false;
      _arm();
    }
  }

  void _arm() {
    _t?.cancel();
    if (widget.kind == 'live') {
      _t = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _gone = true);
      });
    }
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final k = widget.kind, at = widget.at;
    Widget line = const SizedBox(width: double.infinity);
    if (k.isNotEmpty && !_gone) {
      final hm = at == null ? '' : MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(at));
      final saved = hm.isEmpty ? w3('Saved copy', 'जतन केलेली प्रत', 'सहेजी गई प्रति') : '${w3('Saved', 'जतन', 'सहेजा')} $hm';
      final (bg, fg, icon, words) = switch (k) {
        'live' => (const Color(0xFFE8F4EE), C.green, Icons.check_circle_outline_rounded, w3('Live · just now', 'Live · आत्ताच', 'Live · अभी')),
        'stale' => (const Color(0xFFFFF3DC), const Color(0xFF7A4A00), Icons.schedule_rounded, '$saved · ${w3('not live', 'live नाही', 'live नहीं')}'),
        _ => (const Color(0xFFF2F4F7), C.slate, Icons.schedule_rounded, '$saved · ${w3('refreshing…', 'नवीन आणत आहे…', 'नया ला रहा है…')}'),
      };
      line = Container(
        key: Key('saved-line-$k'),
        width: double.infinity,
        color: bg,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 7, 18, 7),
            child: Row(children: [
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: 7),
              Expanded(child: Text(words, maxLines: 2, style: TextStyle(fontFamily: 'Rubik', fontSize: 12.5, fontWeight: FontWeight.w500, color: fg, height: 1.25))),
            ]),
          ),
          if (k == 'saved') const SizedBox(height: 2, child: LinearProgressIndicator(minHeight: 2, color: C.green, backgroundColor: Color(0xFFE4E7EC))),
        ]),
      );
    }
    return AnimatedSize(duration: const Duration(milliseconds: 220), curve: Curves.easeOut, alignment: Alignment.topCenter, child: line);
  }
}
