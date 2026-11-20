/* THE APP'S TERMS / LOCATION NOTICE on the screen (20-11-2026 – see lib/core/app_consent.dart). [ConsentGate] wraps the app at
 * Stage.ready: when the Portal still wants it and this phone has not shown this version, the notice is shown once with Allow / Decline.
 * On Allow it is recorded on the Portal; on Decline the app opens anyway (attendance is blocked until he allows). The same notice is
 * opened again from the attendance screen (before a punch, when consent is not in force) and from Me. The notice says, in plain words,
 * that location is used for attendance and for the live tracking of a vehicle with a driver, and is shared with the person's HR /
 * employer – the full policy is on the website, linked here. In the app, while he is on duty, nothing says "you are being tracked".
 * [aiConsent] is the one-time "may we send this to an AI service" asked before the first AI feature is used. */
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_consent.dart';
import '../core/lang.dart' show tr;
import '../core/session.dart';
import '../ui/scope.dart';

const _privacyUrl = 'https://sketchline.si/privacy-policy';
const _termsUrl = 'https://sketchline.si/terms-and-conditions';

Future<void> _open(String url) async {
  try {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (_) {/* no browser / offline: nothing to do */}
}

/// Shows the notice as its own screen (from the attendance screen or Me). Returns true only when he allowed.
Future<bool> showConsent(BuildContext context) async {
  final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => const _ConsentPage(),
  ));
  return ok == true;
}

/// Wraps the app at Stage.ready: the notice once on opening when it is wanted, then the app.
class ConsentGate extends StatefulWidget {
  const ConsentGate({super.key, required this.child});
  final Widget child;
  @override
  State<ConsentGate> createState() => _ConsentGateState();
}

class _ConsentGateState extends State<ConsentGate> {
  bool _show = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  Future<void> _check() async {
    if (!mounted) return;
    final s = SessionScope.read(context);
    if (await AppConsent.popupOnOpen(s) && mounted) setState(() => _show = true);
  }

  @override
  Widget build(BuildContext context) => _show
      ? _ConsentView(
          onDone: (allowed) async {
            final s = SessionScope.read(context);
            if (!allowed) await AppConsent.markSeen(s); // shown; do not nag on open again (attendance stays blocked until allowed)
            if (mounted) setState(() => _show = false);
          })
      : widget.child;
}

/// The notice as a pushed screen (its own Scaffold + a back as Decline).
class _ConsentPage extends StatelessWidget {
  const _ConsentPage();
  @override
  Widget build(BuildContext context) => _ConsentView(onDone: (allowed) => Navigator.of(context).pop(allowed));
}

/// The notice itself. [onDone] is called with true when he allowed (already recorded on the Portal), false when he declined.
class _ConsentView extends StatefulWidget {
  const _ConsentView({required this.onDone});
  final void Function(bool allowed) onDone;
  @override
  State<_ConsentView> createState() => _ConsentViewState();
}

class _ConsentViewState extends State<_ConsentView> {
  bool _busy = false;
  String _err = '';

  Future<void> _allow() async {
    setState(() {
      _busy = true;
      _err = '';
    });
    try {
      await AppConsent.accept(SessionScope.read(context));
      if (mounted) widget.onDone(true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _err = tr('Could not save your choice – check your network and try again.');
        });
      }
    }
  }

  Widget _point(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 20, color: const Color(0xFF4C1D95)),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14.5, height: 1.35, color: Color(0xFF26324A)))),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // a back press is a Decline, handled below (so attendance stays blocked, not an accidental allow)
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_busy) widget.onDone(false);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F7FB),
        body: SafeArea(
          child: Column(children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 28, 22, 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(color: const Color(0xFFEDE8FF), borderRadius: BorderRadius.circular(16)),
                    child: const Icon(Icons.verified_user_rounded, color: Color(0xFF4C1D95), size: 28),
                  ),
                  const SizedBox(height: 16),
                  Text(tr('Before you start'),
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF0F1830))),
                  const SizedBox(height: 8),
                  Text(tr('Please read how this app uses your information, and allow it to continue.'),
                      style: const TextStyle(fontSize: 14.5, height: 1.4, color: Color(0xFF59647E))),
                  const SizedBox(height: 22),
                  _point(Icons.location_on_rounded,
                      tr('Location for attendance: while you are on duty (after you mark IN, until you mark OUT), the app records your location and shares it with your HR / employer. This continues while the app is in the background.')),
                  _point(Icons.local_shipping_rounded,
                      tr('Live vehicle tracking: for drivers and operators, while a vehicle is with you the app shares its location, also in the background, until the vehicle is released.')),
                  _point(Icons.photo_camera_front_rounded,
                      tr('Camera and face: a photo is taken with each attendance entry, and where your site uses it, your face is checked to confirm it is you.')),
                  _point(Icons.smart_toy_rounded,
                      tr('Helper (AI): when you use the assistant or ask it to read a document, what you send is passed to an AI service only to produce the result.')),
                  const SizedBox(height: 4),
                  Wrap(spacing: 18, runSpacing: 6, children: [
                    GestureDetector(
                        onTap: () => _open(_privacyUrl),
                        child: Text(tr('Privacy Policy'),
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF2563EB), decoration: TextDecoration.underline))),
                    GestureDetector(
                        onTap: () => _open(_termsUrl),
                        child: Text(tr('Terms & Conditions'),
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF2563EB), decoration: TextDecoration.underline))),
                  ]),
                  if (_err.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(_err, style: const TextStyle(fontSize: 13.5, color: Color(0xFFB91C1C))),
                  ],
                ]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 6, 22, 16),
              child: Column(children: [
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    key: const Key('consent-allow'),
                    onPressed: _busy ? null : _allow,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4C1D95),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    child: _busy
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                        : Text(tr('Allow'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(height: 6),
                TextButton(
                  key: const Key('consent-decline'),
                  onPressed: _busy ? null : () => widget.onDone(false),
                  child: Text(tr('Decline – I cannot mark attendance until I allow'),
                      style: const TextStyle(fontSize: 13.5, color: Color(0xFF59647E))),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// One-time "may we send this to an AI service?" before the first AI feature is used. Returns true to go ahead.
Future<bool> aiConsent(BuildContext context, Session s) async {
  if (await AppConsent.aiOk(s)) return true;
  if (!context.mounted) return false;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(tr('Use the helper (AI)?')),
      content: Text(tr('To help you, what you type or the document you choose is sent to an AI service and is not used for anything else. You can use the rest of the app without it.'),
          style: const TextStyle(fontSize: 14.5, height: 1.4)),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(tr('Not now'))),
        FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(tr('Allow'))),
      ],
    ),
  );
  if (ok == true) {
    await AppConsent.aiAccept(s);
    return true;
  }
  return false;
}
