import 'package:flutter/material.dart';

import '../ui/scope.dart';
import '../ui/theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _mail = TextEditingController(), _pw = TextEditingController();
  bool _busy = false, _show = false;

  Future<void> _go() async {
    if (_mail.text.trim().isEmpty || _pw.text.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    await SessionScope.read(context).signIn(_mail.text, _pw.text);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final err = SessionScope.of(context).error;
    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(22, 40, 22, 24), children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: C.green, borderRadius: BorderRadius.circular(22)),
            child: const Icon(Icons.local_gas_station_rounded, color: Colors.white, size: 34),
          ),
          const SizedBox(height: 22),
          const Text('Namaskar', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text('Sign in with your Portal email and password.', style: TextStyle(fontSize: 15.5, color: C.muted)),
          const Text('Portal चाच email आणि password वापरा.', style: TextStyle(fontFamily: 'NotoDeva', fontSize: 14, color: C.muted)),
          const SizedBox(height: 26),
          TextField(
            controller: _mail,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline)),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _pw,
            obscureText: !_show,
            autofillHints: const [AutofillHints.password],
            onSubmitted: (_) => _go(),
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(tooltip: _show ? 'Hide password' : 'Show password', icon: Icon(_show ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _show = !_show)),
            ),
          ),
          if (err.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: C.redSoft, borderRadius: BorderRadius.circular(16)),
              child: Text(err, style: const TextStyle(color: C.red, fontSize: 14.5, fontWeight: FontWeight.w500)),
            ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : _go,
            child: _busy ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white)) : const Text('Sign in'),
          ),
          const SizedBox(height: 18),
          const Text('Forgot your password? Ask the Super Admin for a one-time password.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: C.muted)),
        ]),
      ),
    );
  }
}
