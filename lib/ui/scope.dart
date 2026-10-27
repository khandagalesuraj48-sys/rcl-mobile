import 'package:flutter/widgets.dart';

import '../core/session.dart';

/// The session for every screen below it.
/// (3.48.0, the performance work) [relay]: what tells the screens below to draw again – the session itself (as always), or a
/// tab's own relay (screens/shell.dart: a tab that is not seen is not built again); [gen]: a new number = draw again once (a tab
/// seen again after a redraw it did not take).
class SessionScope extends InheritedNotifier<Listenable> {
  const SessionScope({super.key, required this.session, required super.child, Listenable? relay, this.gen = 0}) : super(notifier: relay ?? session);
  final Session session;
  final int gen;
  static Session of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<SessionScope>()!.session;
  static Session read(BuildContext context) => context.getInheritedWidgetOfExactType<SessionScope>()!.session;

  @override
  bool updateShouldNotify(SessionScope oldWidget) => oldWidget.session != session || oldWidget.notifier != notifier || oldWidget.gen != gen;
}
