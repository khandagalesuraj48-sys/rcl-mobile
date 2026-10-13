import 'package:flutter/material.dart';

import '../core/update.dart';
import '../ui/scope.dart';
import 'entries.dart';
import 'home.dart';
import 'me.dart';

/// The app after sign-in: Home · Entries · Me (the bar at the bottom).
class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => ShellState();
}

class ShellState extends State<Shell> {
  int tab = 0;
  final visited = <int>{0}; // a tab is built the first time it is opened
  String entriesKind = '';
  AppUpdate? update;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final u = await checkUpdate(SessionScope.read(context).api);
      if (mounted && u != null) setState(() => update = u);
    });
  }

  void openEntries(String kind) => setState(() {
        entriesKind = kind;
        tab = 1;
        visited.add(1);
      });

  @override
  Widget build(BuildContext context) => Scaffold(
        body: IndexedStack(index: tab, children: [
          HomeTab(update: update, onOpenList: openEntries),
          visited.contains(1) ? EntriesTab(kind: entriesKind) : const SizedBox.shrink(),
          visited.contains(2) ? MeTab(update: update) : const SizedBox.shrink(),
        ]),
        bottomNavigationBar: NavigationBar(
          selectedIndex: tab,
          height: 72,
          onDestinationSelected: (i) => setState(() {
            tab = i;
            visited.add(i);
          }),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Home'),
            NavigationDestination(icon: Icon(Icons.list_alt_outlined), selectedIcon: Icon(Icons.list_alt_rounded), label: 'Entries'),
            NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person_rounded), label: 'Me'),
          ],
        ),
      );
}
