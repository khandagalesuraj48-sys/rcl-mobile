/* THE REMINDER "VERIFY YOUR E-MAIL" on Home (3.104.0; his decision of 12-11-2026: "5 alert nantr access band nahi karaycha …
 * alert det rahayche every 1 hour"): while his e-mail is not verified and the Portal's reminder is switched on, a small strip –
 * it hides nothing and nothing is ever closed for it. The Portal is asked when Home opens and again every hour (it counts the
 * reminder at most once an hour). A verified person, the Super Admin, the reminder switched off: nothing is shown or asked. */
import 'dart:async';

import 'package:flutter/material.dart' hide Text;

import '../screens/email_verify.dart';
import 'scope.dart';
import 't.dart';

class MailStrip extends StatefulWidget {
  const MailStrip({super.key});
  @override
  State<MailStrip> createState() => _MailStripState();
}

class _MailStripState extends State<MailStrip> {
  bool _show = false, _asked = false;
  Timer? _hour;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final s = SessionScope.of(context);
    if (!s.mailRemind) {
      _hour?.cancel();
      _hour = null;
      _asked = false;
      if (_show) _show = false;
      return;
    }
    if (_asked) return;
    _asked = true;
    _ask();
    _hour = Timer.periodic(const Duration(hours: 1), (_) => _ask());
  }

  Future<void> _ask() async {
    if (!mounted) return;
    final show = await SessionScope.read(context).mailAlert();
    if (mounted && show != _show) setState(() => _show = show);
  }

  @override
  void dispose() {
    _hour?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    if (!_show || !s.mailRemind) return const SizedBox.shrink();
    return Container(
      key: const Key('mail-strip'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        const Icon(Icons.mark_email_unread_outlined, size: 20, color: Color(0xFF713F12)),
        const SizedBox(width: 8),
        const Expanded(child: Text('Verify your e-mail', mr: 'तुमचा email verify करा', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Color(0xFF713F12)))),
        if (s.mailCanVerify)
          TextButton(
            key: const Key('mail-strip-go'),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFF713F12), backgroundColor: Colors.white, minimumSize: const Size(0, 36), padding: const EdgeInsets.symmetric(horizontal: 12)),
            onPressed: () => openVerifyEmail(context),
            child: const Text('Verify now', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          ),
      ]),
    );
  }
}
