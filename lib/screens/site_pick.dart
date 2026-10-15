/* WHICH SITE – when the person has more than one site. Each site shows the modules he has there. */
import 'dart:math' as math;

import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';

import '../ui/brand.dart';
import '../ui/scope.dart';
import '../ui/theme.dart';
import '../ui/t.dart';

class SitePickScreen extends StatefulWidget {
  const SitePickScreen({super.key});
  @override
  State<SitePickScreen> createState() => _SitePickScreenState();
}

class _SitePickScreenState extends State<SitePickScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _open = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

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
    _open.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    final first = s.name.split(' ').first;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: C.greenDark,
        body: Backdrop(
          road: false,
          child: SafeArea(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 24), children: [
              Row(children: [
                const Mark(size: 46),
                const Spacer(),
                TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                  onPressed: () => s.signOut(),
                  icon: const Icon(Icons.logout_rounded, size: 20),
                  label: const Text('Sign out'),
                ),
              ]),
              const SizedBox(height: 26),
              Arrive(anim: _open, at: 0, child: Text('Namaskar${first.isNotEmpty ? ', $first' : ''}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white))),
              const SizedBox(height: 4),
              Arrive(
                anim: _open,
                at: .08,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Which site do you want to open?', style: TextStyle(fontSize: 15.5, color: Colors.white.withValues(alpha: .85))),
                  MrLine('कोणती site उघडायची?', style: TextStyle(fontFamily: 'NotoDeva', fontSize: 14, color: Colors.white.withValues(alpha: .75))),
                ]),
              ),
              if (s.error.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 14),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: C.redSoft, borderRadius: BorderRadius.circular(16)),
                  child: Text(s.error, style: const TextStyle(color: C.red, fontWeight: FontWeight.w500)),
                ),
              const SizedBox(height: 20),
              for (final (i, x) in s.sites.indexed)
                Arrive(
                  anim: _open,
                  at: math.min(.55, .16 + i * .08),
                  rise: 34,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Material(
                      color: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => s.chooseSite(x.code),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
                          child: Row(children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(color: C.greenSoft, borderRadius: BorderRadius.circular(16)),
                              child: const Icon(Icons.location_on_rounded, color: C.green, size: 28),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(x.name, style: const TextStyle(fontSize: 17.5, fontWeight: FontWeight.w700, color: C.ink)),
                                const SizedBox(height: 2),
                                Text([x.code, x.company].where((e) => e.isNotEmpty).join(' · '), style: const TextStyle(fontSize: 13, color: C.muted)),
                                const SizedBox(height: 8),
                                Wrap(spacing: 6, runSpacing: 6, children: [
                                  for (final m in x.modules)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(color: C.greenChip, borderRadius: BorderRadius.circular(20)),
                                      child: Text(m.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: C.greenDark)),
                                    ),
                                ]),
                              ]),
                            ),
                            const Icon(Icons.chevron_right_rounded, color: C.muted),
                          ]),
                        ),
                      ),
                    ),
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}
