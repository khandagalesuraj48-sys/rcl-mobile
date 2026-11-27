/* (3.173.0, 27-11-2026) THE SITE HOME AND HR'S "PAY" – the approved design "LION – Modules & Subscription", boards 4, 5a and 5b.
 * His words: "ekach app asel lion wali tyache madhe tab astil modual che … VTR madhe gel ki ek mast greting ani ek unique ui madhe
 * modual distil jas ki Mechanical la name apan ata VEHICLE KRAYCH AAHE ANI HR … PRATEK SITE SATHI … SELCT MODUAL ASEL"; and for HR's
 * subscription: "PRATEK EMPLOYY KADHUN GHEYCHI KI TYA COMPNY KADHUN JEWDE USER AAHET TEWDECH GHEYCH" – set in the Portal.
 *   ModuleHome  a site with Vehicle (Mechanical), with HR or without: the greeting, the site (a tap: another site), his modules; the one
 *               tapped opens its own pages as before (Session.pickModule). HR's tile (where he has HR) says when its subscription is due /
 *               paused / on trial.
 *   PayScreen   HR's subscription: the company pays (5a – Bulk: the bill of one period, the users counted per site; only the
 *               company's HR admin pays) or each employee pays (5b – Single: his own plan). Each for a month or for N days (set in
 *               the Portal). Amounts only WITH the taxes – "Including all taxes", never the GST apart (his word: "payment page war gst
 *               he te dakhawayche nahi fkt line including all taxes"). "Pay" opens Razorpay's own page outside the app (a payment link
 *               of the Portal – api/pay), or – the demo – his UPI app with the amount and the remark (straight to the UPI ID set in the
 *               Portal; it opens HR only when the Super Admin marked it received). Back in the app it is read again. Nothing of a
 *               card, UPI or bank is seen by the app.
 *   PayGate     HR said "paused" (its answer 402): the PayScreen in place of HR's pages until it is paid. Nothing is deleted.
 *   BackToMods  Back on HR's pages: the site home. */
import 'dart:async';

import 'package:flutter/material.dart' hide Text;
import 'package:flutter/material.dart' as m show Text;
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api.dart' show ApiError;
import '../core/session.dart';
import '../ui/brand.dart' show Arrive;
import '../ui/crest.dart';
import '../ui/scope.dart';
import '../ui/t.dart';
import '../ui/widgets.dart' show toast;
import 'attendance.dart' show hrSite, hrModule;

/// The design's colours (boards 4 – 5b).
class ModC {
  static const navy = Color(0xFF0F1E3D), gold = Color(0xFFC9A227), goldPale = Color(0xFFE9D9A6), goldInk = Color(0xFF8A6A12), goldSoft = Color(0xFFFBF4DF);
  static const page = Color(0xFFF5F6FA),
      ink = Color(0xFF111827),
      muted = Color(0xFF5B6475),
      line = Color(0xFFE2E6EE),
      red = Color(0xFFB42318),
      redSoft = Color(0xFFFDECEA);
}

/// (tests) how a payment link is opened – the phone's browser / UPI app by itself.
Future<bool> Function(Uri u)? payLaunch;

const _days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
const _months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

/// "Friday, 27 November"
String modDay(DateTime d) => '${_days[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]}';

/// 2026-12-12 → 12-12-2026 ('' stays '')
String dmy(Object? v) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch('${v ?? ''}');
  return m == null ? '' : '${m.group(3)}-${m.group(2)}-${m.group(1)}';
}

/// paise → "₹1,234" / "₹1,234.50" (Indian grouping)
String rupees(Object? paise) {
  final p = paise is num ? paise.round() : int.tryParse('${paise ?? ''}') ?? 0;
  final r = p ~/ 100, ps = p % 100;
  var s = '$r';
  if (s.length > 3) {
    final last = s.substring(s.length - 3);
    var head = s.substring(0, s.length - 3);
    final parts = <String>[];
    while (head.length > 2) {
      parts.insert(0, head.substring(head.length - 2));
      head = head.substring(0, head.length - 2);
    }
    if (head.isNotEmpty) parts.insert(0, head);
    s = '${parts.join(',')},$last';
  }
  return '₹$s${ps == 0 ? '' : '.${ps.toString().padLeft(2, '0')}'}';
}

/// "01-12-2026 – 31-12-2026" – the days one payment covers ('' when not said)
String spanOf(Object? from, Object? to) => dmy(from).isEmpty || dmy(to).isEmpty ? '' : '${dmy(from)} – ${dmy(to)}';

/// Days from [today] to [to] (yyyy-mm-dd), at least 0; null when not said.
int? daysLeft(DateTime today, Object? to) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch('${to ?? ''}');
  if (m == null) return null;
  final t = DateTime(int.parse(m.group(1)!), int.parse(m.group(2)!), int.parse(m.group(3)!));
  final d = t.difference(DateTime(today.year, today.month, today.day)).inDays;
  return d < 0 ? 0 : d;
}

/// The Portal's word of his HR subscription at the site (api/pay "mine") – null: nothing to pay / a Portal of before / no answer.
Future<Map<String, dynamic>?> hrPlanOf(Session s) async {
  final site = s.site?.code ?? '';
  if (site.isEmpty) return null;
  try {
    final j = await s.api.pay({'action': 'mine', 'site': site});
    final h = (j['mods'] as Map?)?['hr'];
    return h is Map ? h.cast<String, dynamic>() : null;
  } catch (_) {
    return null; // (the site home is never held up by it)
  }
}

/// The chip of HR's tile – '' none.
String payChip(Map<String, dynamic>? p) => switch ('${p?['s'] ?? ''}') {
      'due' => 'Subscription due',
      'paused' => 'Paused – pay to open',
      'trial' => dmy(p?['till']).isEmpty ? 'Free trial' : 'Free trial till ${dmy(p?['till'])}',
      _ => '',
    };

class ModuleHome extends StatefulWidget {
  const ModuleHome({super.key});
  @override
  State<ModuleHome> createState() => _ModuleHomeState();
}

class _ModuleHomeState extends State<ModuleHome> with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  Map<String, dynamic>? _hr;
  late final AnimationController _open = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _read());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _open.value = 1;
    } else if (_open.value == 0 && !_open.isAnimating) {
      _open.forward();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _open.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) _read();
  }

  Future<void> _read() async {
    if (!mounted) return;
    final s = SessionScope.read(context);
    if (!s.siteMods.contains('hr')) return; // (no HR at this site: nothing to ask)
    final p = await hrPlanOf(s);
    if (mounted) setState(() => _hr = p);
  }

  Future<void> _site() async {
    final s = SessionScope.read(context);
    if (s.sites.length < 2) {
      toast(context, 'You have one site: ${s.siteName}.');
      return;
    }
    s.pickAnotherSite();
  }

  Future<void> _openHr() async {
    final s = SessionScope.read(context);
    HapticFeedback.selectionClick();
    if (_hr?['s'] == 'paused') {
      await _pay();
      if (!mounted) return;
      if (_hr?['s'] == 'paused') return; // (not paid: HR stays closed – its pages would only refuse)
    }
    s.pickModule('hr');
  }

  Future<void> _pay() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PayScreen(plan: _hr)));
    await _read();
  }

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    final mq = MediaQuery.of(context);
    final now = s.clock();
    final first = s.name.trim().split(RegExp(r'\s+')).first;
    final hello = now.hour < 12 ? 'Good morning' : (now.hour < 17 ? 'Good afternoon' : 'Good evening');
    final helloMr = now.hour < 12 ? 'शुभ सकाळ' : (now.hour < 17 ? 'शुभ दुपार' : 'शुभ संध्याकाळ');
    final chip = payChip(_hr);
    Widget arrive(double at, Widget w) => Arrive(anim: _open, at: at, child: w);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: ModC.page,
        body: ListView(padding: EdgeInsets.zero, children: [
          // ---------- the navy header: the site, the lion, the day, the greeting, the wish ----------
          Container(
            decoration: const BoxDecoration(color: ModC.navy, borderRadius: BorderRadius.vertical(bottom: Radius.circular(32))),
            padding: EdgeInsets.fromLTRB(20, mq.padding.top + 14, 20, 26),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(
                  child: Semantics(
                    button: true,
                    label: tr('Change site'),
                    child: InkWell(
                      key: const Key('mods-site'),
                      borderRadius: BorderRadius.circular(999),
                      onTap: _site,
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 44),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .10),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: ModC.goldPale.withValues(alpha: .45))),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.location_on_outlined, size: 17, color: ModC.goldPale),
                          const SizedBox(width: 8),
                          Flexible(
                              child: m.Text(s.siteName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white))),
                          if (s.sites.length > 1) ...[const SizedBox(width: 4), const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: ModC.goldPale)],
                        ]),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: ModC.gold, width: 2)),
                  alignment: Alignment.center,
                  child: const CrestLion(size: 30, dark: true),
                ),
              ]),
              const SizedBox(height: 18),
              arrive(0, m.Text(modDay(now), style: const TextStyle(fontSize: 14, color: ModC.goldPale))),
              const SizedBox(height: 4),
              arrive(
                  .06,
                  Text('$hello${first.isEmpty ? '' : ', $first'}',
                      mr: '$helloMr${first.isEmpty ? '' : ', $first'}',
                      key: const Key('mods-hello'),
                      style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: Colors.white, height: 1.2))),
              const SizedBox(height: 18),
              arrive(
                .12,
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  decoration: BoxDecoration(
                      gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [ModC.gold, ModC.goldPale]),
                      borderRadius: BorderRadius.circular(18)),
                  child: const Row(children: [
                    Icon(Icons.wb_twilight_rounded, size: 34, color: ModC.navy),
                    SizedBox(width: 14),
                    Expanded(
                        child: Text('Have a safe and productive day',
                            mr: 'तुमचा दिवस सुरक्षित आणि छान जावो', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: ModC.navy))),
                  ]),
                ),
              ),
            ]),
          ),
          // ---------- the modules ----------
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              const Expanded(child: Text('Your modules', mr: 'तुमचे modules', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: ModC.navy))),
              Flexible(child: Text('at ${s.siteName}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: ModC.muted))),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Arrive(
                anim: _open,
                at: .2,
                rise: 30,
                child: _Tile(
                  key: const Key('mods-vehicle'),
                  dark: true,
                  icon: Icons.local_shipping_outlined,
                  title: 'Vehicle',
                  sub: 'Diesel · Log Book · Maintenance · Billing',
                  onTap: () {
                    HapticFeedback.selectionClick();
                    s.pickModule('mechanical');
                  },
                ),
              ),
              // (his later word: "vtr and 18 b la … kr") HR's tile only where he has HR at this site
              if (s.siteMods.contains('hr')) const SizedBox(height: 14),
              if (s.siteMods.contains('hr'))
                Arrive(
                  anim: _open,
                  at: .28,
                  rise: 30,
                  child: _Tile(
                    key: const Key('mods-hr'),
                    dark: false,
                    icon: Icons.groups_2_outlined,
                    title: 'HR',
                    sub: 'Attendance · Leave · Papers · Payroll',
                    chip: chip,
                    chipBad: _hr?['s'] == 'paused',
                    onChip: chip.isEmpty ? null : _pay,
                    onTap: _openHr,
                  ),
                ),
            ]),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(28, 22, 28, 24 + mq.padding.bottom),
            child: const Text('Tap a module to open its own dashboard. Changing site brings you back here.',
                mr: 'module वर tap करा – त्याचा dashboard उघडेल. Site बदलली की पुन्हा इथे याल.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, height: 1.45, color: ModC.muted)),
          ),
        ]),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile(
      {super.key,
      required this.dark,
      required this.icon,
      required this.title,
      required this.sub,
      required this.onTap,
      this.chip = '',
      this.chipBad = false,
      this.onChip});
  final bool dark, chipBad;
  final IconData icon;
  final String title, sub, chip;
  final VoidCallback onTap;
  final VoidCallback? onChip;
  @override
  Widget build(BuildContext context) {
    final fg = dark ? Colors.white : ModC.navy;
    return Semantics(
      button: true,
      child: Material(
        color: dark ? ModC.navy : Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22), side: dark ? BorderSide.none : const BorderSide(color: Color(0xFFE2C76E), width: 1.5)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(color: dark ? ModC.gold.withValues(alpha: .18) : ModC.goldSoft, borderRadius: BorderRadius.circular(16)),
                  child: Icon(icon, size: 30, color: dark ? ModC.goldPale : ModC.goldInk),
                ),
                const SizedBox(width: 12),
                if (chip.isNotEmpty)
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        key: Key('mods-chip-$title'),
                        onTap: onChip,
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 32),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(color: chipBad ? ModC.redSoft : ModC.goldSoft, borderRadius: BorderRadius.circular(999)),
                          child: Text(chip,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: chipBad ? ModC.red : ModC.goldInk)),
                        ),
                      ),
                    ),
                  )
                else ...[
                  const Spacer(),
                  Icon(Icons.arrow_forward_rounded, size: 22, color: dark ? ModC.goldPale : ModC.goldInk),
                ],
              ]),
              const SizedBox(height: 14),
              Text(title, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: .5, color: fg)),
              const SizedBox(height: 4),
              Text(sub, style: TextStyle(fontSize: 14, color: dark ? const Color(0xFFC8CEDB) : const Color(0xFF4B5565))),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Back on HR's pages (the site home's HR): the site home – at a site with Vehicle; an HR-only site as before (the app closes).
class BackToMods extends StatelessWidget {
  const BackToMods({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    return PopScope(
      canPop: !s.siteHome,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && s.siteHome) s.pickModule(null);
      },
      child: child,
    );
  }
}

/// HR said "paused": the PayScreen in place of HR's pages (they would only refuse) until it is paid.
class PayGate extends StatelessWidget {
  const PayGate({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    return ValueListenableBuilder<Map<String, dynamic>?>(
      valueListenable: s.hrPaused,
      builder: (_, p, c) => p == null
          ? c!
          : PayScreen(
              key: const Key('pay-gate'),
              plan: (p['pay'] as Map?)?.cast<String, dynamic>(),
              words: p['words'] is List ? [for (final w in p['words'] as List) '$w'] : const [],
              gate: true),
      child: child,
    );
  }
}

/// HR's subscription: 5a (the company pays) or 5b (each employee pays).
class PayScreen extends StatefulWidget {
  const PayScreen({super.key, this.plan, this.words = const [], this.gate = false});

  /// What is known already (the site home's "mine", or HR's "paused" answer) – read again here.
  final Map<String, dynamic>? plan;

  /// HR's own words for "paused" (English, मराठी, हिंदी)
  final List<String> words;

  /// In place of HR's pages (PayGate): no page to go back to – the site home / another site / sign out instead.
  final bool gate;
  @override
  State<PayScreen> createState() => _PayScreenState();
}

class _PayScreenState extends State<PayScreen> with WidgetsBindingObserver {
  Map<String, dynamic>? _p;
  bool _reading = true, _busy = false, _away = false;
  String _err = '';

  /// (the demo – straight to a UPI ID) the remark of the UPI payment made from here: HR opens when Sketchline has seen it
  String _upiRef = '';

  @override
  void initState() {
    super.initState();
    _p = widget.plan;
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _read());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted && _away) {
      _away = false;
      _read(after: true);
    }
  }

  bool get _open => const {'ok', 'trial', 'free'}.contains('${_p?['s'] ?? ''}');

  /// Read again; [after] – back from Razorpay's page (or pulled down): paid → HR opens again (a new HR sign-in carries the Portal's
  /// new word). In place of HR's pages (gate): open again as soon as the Portal says it is not paused.
  Future<void> _read({bool after = false}) async {
    final s = SessionScope.read(context);
    final was = '${_p?['s'] ?? ''}';
    setState(() => _reading = true);
    final p = await hrPlanOf(s);
    if (!mounted) return;
    setState(() {
      _reading = false;
      if (p != null) _p = p;
    });
    final open = p == null ? widget.gate : const {'ok', 'trial', 'free'}.contains('${p['s'] ?? ''}');
    if (widget.gate ? open : (after && open && (was == 'due' || was == 'paused'))) await _opened(told: after);
  }

  Future<void> _opened({bool told = true}) async {
    final s = SessionScope.read(context);
    final mod = hrModule(s);
    if (mod != null) await s.api.hrEnd(mod.url); // (HR's sign-in of before still says "paused" – the next one carries the payment)
    if (!mounted) return;
    if (told) toast(context, bi('Paid – thank you. HR is open.', 'पैसे भरले – धन्यवाद. HR चालू आहे.'));
    s.hrPaused.value = null;
    if (!widget.gate && Navigator.of(context).canPop()) Navigator.of(context).pop();
  }

  Future<void> _pay() async {
    if (_busy) return;
    final s = SessionScope.read(context);
    final site = hrSite(s)?.code ?? s.site?.code ?? '';
    setState(() {
      _busy = true;
      _err = '';
    });
    try {
      final j = await s.api.pay({'action': 'link', 'site': site, 'module': 'hr'});
      final url = '${j['url'] ?? ''}', upi = '${j['upi'] ?? ''}';
      // Razorpay's page (https), or – the demo – his UPI app (upi://pay with the amount and the remark)
      if (!url.startsWith('https://') && !upi.startsWith('upi://pay?')) throw ApiError('No payment page was given – try again.');
      _away = true;
      final ok = await (payLaunch ?? (u) => launchUrl(u, mode: LaunchMode.externalApplication))(Uri.parse(upi.isNotEmpty ? upi : url));
      if (!ok) {
        _away = false;
        throw ApiError(upi.isNotEmpty
            ? bi('No UPI app opened – install or open a UPI app (PhonePe, Google Pay, Paytm…) and try again.',
                'UPI app उघडले नाही – PhonePe, Google Pay, Paytm… उघडून पुन्हा प्रयत्न करा.')
            : 'The payment page could not be opened – try again.');
      }
      if (upi.isNotEmpty && mounted) setState(() => _upiRef = '${j['ref'] ?? ''}');
    } catch (e) {
      if (mounted) setState(() => _err = e is ApiError ? e.toString() : bi('No network – connect and try again.', 'नेटवर्क नाही – जोडून पुन्हा प्रयत्न करा.'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    final mq = MediaQuery.of(context);
    final p = _p ?? const <String, dynamic>{};
    final st = '${p['s'] ?? ''}', self = p['who'] == 'employee', canPay = p['canPay'] == true;
    final a = (p['amount'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    final company = hrSite(s)?.company ?? s.site?.company ?? '';
    final grace = daysLeft(s.clock(), p['grace']);
    final lang = Lang.i.code;
    final hrWords = widget.words.length >= 3 ? (lang == 'mr' ? widget.words[1] : (lang == 'hi' ? widget.words[2] : widget.words[0])) : '';
    final state = switch (st) {
      'paused' => (self ? 'Your HR is paused' : 'HR is paused', ModC.red, ModC.redSoft),
      'due' => (grace == null ? 'Subscription due' : 'Due · $grace day${grace == 1 ? '' : 's'} of grace left', ModC.goldInk, ModC.goldSoft),
      'trial' => (dmy(p['till']).isEmpty ? 'Free trial' : 'Free trial till ${dmy(p['till'])}', const Color(0xFF1F6F43), const Color(0xFFE3F4EA)),
      'ok' => (dmy(p['till']).isEmpty ? 'Paid' : 'Paid till ${dmy(p['till'])}', const Color(0xFF1F6F43), const Color(0xFFE3F4EA)),
      'free' => ('Free for your company', const Color(0xFF1F6F43), const Color(0xFFE3F4EA)),
      _ => ('', ModC.muted, ModC.page),
    };
    final total = a['total'];
    // "1 month" / "15 days" – as the Portal set it
    final per = '${a['per'] ?? ''}'.isEmpty ? '1 month' : '${a['per']}';
    final span = spanOf(a['from'], a['to']);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: ModC.page,
        appBar: AppBar(
          backgroundColor: ModC.page,
          surfaceTintColor: Colors.transparent,
          foregroundColor: ModC.navy,
          automaticallyImplyLeading: !widget.gate,
          leading: widget.gate && s.siteHome
              ? IconButton(
                  key: const Key('pay-mods'), tooltip: tr('Your modules'), icon: const Icon(Icons.arrow_back_rounded), onPressed: () => s.pickModule(null))
              : null,
          title: Text(self ? 'My HR plan' : 'HR subscription',
              mr: self ? 'माझा HR plan' : 'HR subscription', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: ModC.navy)),
          actions: [
            if (widget.gate && !s.siteHome && s.sites.length > 1) TextButton(onPressed: s.pickAnotherSite, child: const Text('Change site')),
            if (widget.gate) IconButton(tooltip: tr('Sign out'), icon: const Icon(Icons.logout_rounded), onPressed: () => s.signOut()),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: () => _read(after: true),
          child: ListView(padding: EdgeInsets.fromLTRB(20, 4, 20, 24 + mq.padding.bottom), children: [
            if (company.isNotEmpty)
              Text(self ? company : '$company · ${canPay ? 'company admin' : 'your company pays'}', style: const TextStyle(fontSize: 14, color: ModC.muted)),
            const SizedBox(height: 14),
            if (hrWords.isNotEmpty && st == 'paused') ...[
              _box(
                  m.Text(hrWords,
                      key: const Key('pay-words'), style: const TextStyle(fontSize: 14.5, height: 1.4, color: ModC.red, fontWeight: FontWeight.w600)),
                  color: ModC.redSoft,
                  line: ModC.redSoft),
              const SizedBox(height: 12),
            ],
            if (self) ...[
              if (st == 'paused' || st == 'due')
                _box(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(state.$1, key: const Key('pay-state'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: state.$2)),
                  const SizedBox(height: 6),
                  Text('${company.isEmpty ? 'Your company' : company} has chosen that each employee pays for his own HR. Pay for $per to keep using it.',
                      style: const TextStyle(fontSize: 14, height: 1.45, color: ModC.muted)),
                ]))
              else
                _pill(state.$1, state.$2, state.$3),
              const SizedBox(height: 14),
              _box(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('HR – one person', mr: 'HR – एक व्यक्ती', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: ModC.navy)),
                const SizedBox(height: 6),
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  m.Text(total == null ? '–' : rupees(total),
                      key: const Key('pay-total'), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: ModC.navy)),
                  const SizedBox(width: 6),
                  Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text('/ $per', key: const Key('pay-per'), style: const TextStyle(fontSize: 14, color: ModC.muted))),
                ]),
                if (total != null)
                  Text(span.isEmpty ? 'Including all taxes' : 'Including all taxes · $span',
                      key: const Key('pay-taxes'), style: const TextStyle(fontSize: 13, color: ModC.muted)),
                const SizedBox(height: 12),
                for (final f in const [
                  ('Check in and check out', 'Check in आणि check out'),
                  ('Leave and its balance', 'रजा आणि शिल्लक'),
                  ('My papers and salary slips', 'माझी कागदपत्रे आणि पगार पावत्या'),
                  ('Notices from HR', 'HR च्या सूचना')
                ])
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(children: [
                      const Icon(Icons.check_circle_rounded, size: 18, color: ModC.gold),
                      const SizedBox(width: 10),
                      Expanded(child: Text(f.$1, mr: f.$2, style: const TextStyle(fontSize: 14, color: ModC.ink))),
                    ]),
                  ),
              ])),
            ] else ...[
              _box(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Expanded(child: _pill(state.$1, state.$2, state.$3, key: const Key('pay-state'))),
                  const SizedBox(width: 8),
                  Text(per, key: const Key('pay-per'), style: const TextStyle(fontSize: 13, color: ModC.muted)),
                ]),
                if (total != null) ...[
                  const SizedBox(height: 14),
                  Text(span.isEmpty ? 'To pay' : 'To pay for $span', style: const TextStyle(fontSize: 14, color: ModC.muted)),
                  m.Text(rupees(total), key: const Key('pay-total'), style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: ModC.navy)),
                  const Text('Including all taxes', key: Key('pay-taxes'), style: TextStyle(fontSize: 13, color: ModC.muted)),
                  if ((a['bySite'] as List? ?? const []).isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const Divider(height: 1, color: ModC.line),
                    _line('Active users', '${a['units'] ?? ''}'),
                    if (a['rateAll'] != null) _line('Per user', rupees(a['rateAll'])),
                  ],
                ],
              ])),
              if ((a['bySite'] as List? ?? const []).isNotEmpty) ...[
                const SizedBox(height: 14),
                _box(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const Text('Users counted', mr: 'मोजलेले users', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: ModC.navy)),
                  for (final r in (a['bySite'] as List).whereType<Map>()) _line('${r['name'] ?? r['site'] ?? ''}', '${r['n'] ?? 0}'),
                  const SizedBox(height: 8),
                  const Text('Counted on the bill date: every user with HR access who is active. A user at two sites is counted once.',
                      style: TextStyle(fontSize: 12.5, height: 1.4, color: ModC.muted)),
                ])),
              ],
              if (!canPay && st != 'ok' && st != 'free') ...[
                const SizedBox(height: 14),
                _box(const Text('Your company pays for HR – its HR admin pays. Please tell your admin.',
                    mr: 'HR चे पैसे कंपनी भरते – कंपनीचे HR admin भरतील. कृपया admin ला सांगा.',
                    key: Key('pay-admin'),
                    style: TextStyle(fontSize: 14, height: 1.4, color: ModC.ink))),
              ],
            ],
            if ('${p['why'] ?? ''}'.isNotEmpty) ...[
              const SizedBox(height: 12),
              m.Text('${p['why']}', style: const TextStyle(fontSize: 13.5, color: ModC.red)),
            ],
            if (_upiRef.isNotEmpty && !_open) ...[
              const SizedBox(height: 12),
              _box(
                  Text('Paid by UPI? HR opens as soon as Sketchline sees your payment (remark $_upiRef). Pull down to check again.',
                      mr: 'UPI ने पैसे भरले? Sketchline ला तुमचे पैसे दिसले की HR लगेच चालू होईल (remark $_upiRef). पुन्हा पाहण्यासाठी खाली ओढा.',
                      key: const Key('pay-upi-wait'),
                      style: const TextStyle(fontSize: 14, height: 1.4, color: ModC.ink)),
                  color: ModC.goldSoft,
                  line: ModC.goldSoft),
            ],
            if (_err.isNotEmpty) ...[
              const SizedBox(height: 12),
              _box(m.Text(_err, key: const Key('pay-err'), style: const TextStyle(fontSize: 14, color: ModC.red, fontWeight: FontWeight.w500)),
                  color: ModC.redSoft, line: ModC.redSoft),
            ],
            const SizedBox(height: 18),
            if (canPay && total != null && !_open)
              FilledButton(
                key: const Key('pay-go'),
                style: FilledButton.styleFrom(
                    backgroundColor: ModC.navy,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(56),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
                onPressed: _busy ? null : _pay,
                child: _busy
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.6, color: Colors.white))
                    : m.Text('${tr('Pay')} ${rupees(total)}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              ),
            if (canPay && total != null && !_open) ...[
              const SizedBox(height: 10),
              const Text('Secure payment – including all taxes',
                  mr: 'सुरक्षित payment – सर्व कर धरून', textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: ModC.muted)),
            ],
            if (_reading)
              const Padding(
                  padding: EdgeInsets.only(top: 16), child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4)))),
          ]),
        ),
      ),
    );
  }

  Widget _box(Widget child, {Color color = Colors.white, Color line = ModC.line}) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20), border: Border.all(color: line)),
        child: child,
      );

  Widget _pill(String t, Color fg, Color bg, {Key? key}) => t.isEmpty
      ? const SizedBox.shrink()
      : Align(
          alignment: Alignment.centerLeft,
          child: Container(
            key: key,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
            child: Text(t, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: fg)),
          ),
        );

  Widget _line(String a, String b) => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Row(children: [
          Expanded(child: Text(a, style: const TextStyle(fontSize: 14, color: ModC.muted))),
          m.Text(b, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ModC.ink)),
        ]),
      );
}
