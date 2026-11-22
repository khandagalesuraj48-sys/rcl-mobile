/* CONNECT WHATSAPP (3.167.0 – the Portal's step 15, the web's "Connect WhatsApp"; his decisions of 22-11-2026: "whats app pahilenda app
 * and web 2 ni sathi asel otp sign in pn chalu asel … user verify zala ki chalu zal … whats app war persoal details kyc bank details
 * sensitive data janr nahi"). The WhatsApp assistant answers ERP questions on WhatsApp to a person who verified his number:
 *   – verified or not, and until when (10 days; the Super Admin: 1 day);
 *   – "Get my code": a 6-digit code (10 minutes, once); "Open WhatsApp" opens WhatsApp with "LINK 123456" typed to the assistant's
 *     number – he presses Send from HIS OWN WhatsApp (the number on his sign-in); this screen looks every 4 seconds and shows
 *     "Verified" by itself;
 *   – "Disconnect" ends it; no mobile number on his sign-in: said so (the Super Admin puts his own number here).
 * The Portal keeps and checks everything (api/auth.js waState / waCode / waUnlink); the app only asks. Reached from Me and from
 * "My HR" → E-mail and password. */
import 'dart:async';

import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api.dart' show ApiError;
import '../ui/hr_skin.dart';
import '../ui/scope.dart';
import '../ui/t.dart';
import '../ui/theme.dart';

Future<void> openWaConnect(BuildContext context) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const WaConnectScreen()));

/// (tests) how WhatsApp is opened – by default the phone's own WhatsApp
Future<bool> Function(Uri) waOpen = (u) => launchUrl(u, mode: LaunchMode.externalApplication);

class WaConnectScreen extends StatefulWidget {
  const WaConnectScreen({super.key});
  @override
  State<WaConnectScreen> createState() => _WaConnectScreenState();
}

class _WaConnectScreenState extends State<WaConnectScreen> {
  Map<String, dynamic>? _st, _code;
  String _err = '';
  bool _busy = false, _loading = true;
  Timer? _poll;
  final _mob = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _poll?.cancel();
    _mob.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final st = await SessionScope.read(context).waState();
      if (mounted) setState(() => _st = st);
    } on ApiError catch (e) {
      if (mounted) setState(() => _err = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _get() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _err = '';
    });
    try {
      final c = await SessionScope.read(context).waCode();
      if (!mounted) return;
      setState(() => _code = c);
      final was = '${_st?['until'] ?? ''}', until = DateTime.now().add(Duration(minutes: (c['minutes'] as num?)?.toInt() ?? 10));
      _poll?.cancel();
      _poll = Timer.periodic(const Duration(seconds: 4), (t) async {
        if (!mounted || DateTime.now().isAfter(until)) {
          t.cancel();
          return;
        }
        try {
          final n = await SessionScope.read(context).waState();
          if (!mounted) return;
          if (n['linked'] == true && '${n['until'] ?? ''}' != was) {
            t.cancel();
            setState(() {
              _st = n;
              _code = null;
            });
            HapticFeedback.lightImpact();
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(bi('WhatsApp verified ✓', 'WhatsApp verify झाले ✓'))));
          }
        } catch (_) {/* asked again in 4 seconds */}
      });
    } on ApiError catch (e) {
      if (mounted) setState(() => _err = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _end() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await SessionScope.read(context).waUnlink();
      _poll?.cancel();
      _code = null;
      await _load();
    } on ApiError catch (e) {
      if (mounted) setState(() => _err = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveMobile() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _err = '';
    });
    try {
      await SessionScope.read(context).waMyMobile(_mob.text);
      await _load();
    } on ApiError catch (e) {
      if (mounted) setState(() => _err = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context), st = _st, c = _code;
    final linked = st?['linked'] == true, days = (st?['days'] as num?)?.toInt() ?? 10;
    return Scaffold(
      backgroundColor: skApp.bg,
      appBar: AppBar(title: const Text('Connect WhatsApp')),
      body: SafeArea(
        child: ListView(key: const Key('wa-page'), padding: const EdgeInsets.fromLTRB(Sp.edge, 16, Sp.edge, 28), children: [
          Text('Ask LION about your ERP on WhatsApp – in Marathi, Hindi or English. Personal, KYC and bank details are never given there.', style: TextStyle(fontSize: 14.5, color: skApp.ink, height: 1.4)),
          MrLine('WhatsApp वर ERP बद्दल विचारा – मराठी, हिंदी किंवा English मध्ये. Personal, KYC, bank माहिती तिथे कधीच दिली जात नाही.', style: TextStyle(fontFamily: 'NotoDeva', fontSize: 13.5, color: skApp.muted)),
          const SizedBox(height: 16),
          if (_loading) const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
          if (st != null && st['on'] != true) Text('The WhatsApp assistant is not switched on.', key: const Key('wa-off'), style: TextStyle(fontSize: 14, color: skApp.muted)),
          if (st != null && st['on'] == true) ...[
            Container(
              key: Key(linked ? 'wa-linked' : 'wa-not'),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(color: linked ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(14)),
              child: Text(
                linked ? '✓ Verified on WhatsApp until ${st['until_dmy'] ?? ''} · from ${st['mobile'] ?? ''}' : 'Not verified yet. Verify once in ${days == 1 ? 'a day' : '$days days'}.',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: linked ? const Color(0xFF14532D) : const Color(0xFF334155)),
              ),
            ),
            const SizedBox(height: 14),
            if (st['hasMobile'] != true && s.superAdmin) ...[
              TextField(
                key: const Key('wa-mob'),
                controller: _mob,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')), LengthLimitingTextInputFormatter(16)],
                decoration: InputDecoration(labelText: tr('My mobile number (the WhatsApp you will ask from)'), prefixIcon: const Icon(Icons.phone_iphone_rounded)),
              ),
              const SizedBox(height: 12),
              FilledButton(key: const Key('wa-mob-save'), style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)), onPressed: _busy ? null : _saveMobile, child: const Text('Save my number')),
            ] else if (st['hasMobile'] != true)
              const Text('Your mobile number is not on your sign-in yet – ask HR or the Super Admin to add it. Then connect WhatsApp from that number.', key: Key('wa-nomobile'), style: TextStyle(fontSize: 14, color: C.red, height: 1.35))
            else ...[
              FilledButton(
                key: const Key('wa-get'),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                onPressed: _busy ? null : _get,
                child: Text(linked ? 'Verify again' : 'Get my code'),
              ),
              if (linked) TextButton(key: const Key('wa-end'), onPressed: _busy ? null : _end, child: const Text('Disconnect')),
            ],
            if (c != null) ...[
              const SizedBox(height: 16),
              Text('Send this code from your WhatsApp (${c['from'] ?? ''}) to ${c['number'] ?? ''} – valid ${c['minutes'] ?? 10} minutes, once.', style: TextStyle(fontSize: 14, color: skApp.ink, height: 1.4)),
              Container(
                key: const Key('wa-code'),
                margin: const EdgeInsets.symmetric(vertical: 12),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF16A34A), width: 2)),
                child: SelectableText('${c['code'] ?? ''}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: 8, color: Color(0xFF0F172A))),
              ),
              if ('${c['link'] ?? ''}'.isNotEmpty)
                FilledButton.icon(
                  key: const Key('wa-open'),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52), backgroundColor: const Color(0xFF16A34A)),
                  onPressed: () => waOpen(Uri.parse('${c['link']}')),
                  icon: const Icon(Icons.chat_rounded),
                  label: const Text('Open WhatsApp'),
                ),
              MrLine('हा code तुमच्या WhatsApp वरून पाठवा – "Open WhatsApp" दाबा आणि Send करा.', style: TextStyle(fontFamily: 'NotoDeva', fontSize: 13, color: skApp.muted)),
            ],
          ],
          if (_err.isNotEmpty)
            Container(
              key: const Key('wa-err'),
              margin: const EdgeInsets.only(top: 14),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(color: C.redSoft, borderRadius: BorderRadius.circular(16)),
              child: Text(_err, style: const TextStyle(color: C.red, fontSize: 14, fontWeight: FontWeight.w500, height: 1.35)),
            ),
        ]),
      ),
    );
  }
}
