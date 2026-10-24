/* (Mechanical update-155, asked 24-10-2026: "सर्व Screens वर विनाकारण … Full Data Fetch करायचा नाही … Hidden/Inactive Screens
 * साठी कमी खर्चिक Sync आणि पुन्हा Active झाल्यावर Catch-up") – A TAB THAT IS NOT SEEN DOES NOT LOAD.
 * Home and Entries stay built under the other tabs (the shell's IndexedStack) and under every screen opened over them; until now
 * each of them loaded its lists again after every change by anyone, also when nobody saw them. Now a change only marks such a
 * tab "old"; it loads the moment it is seen again – its tab chosen, or the screen over it closed (appRoutes). */
import 'package:flutter/widgets.dart';

/// Told when a screen opened over another is closed (MaterialApp.navigatorObservers, main.dart).
final appRoutes = RouteObserver<ModalRoute<void>>();

mixin LiveWhenSeen<T extends StatefulWidget> on State<T> implements RouteAware {
  bool _old = false;
  ModalRoute<void>? _route;

  /// the tab is the one chosen (the shell says so)
  bool get liveActive;

  /// load again, quietly
  void liveReload();

  bool get liveSeen => mounted && liveActive && (_route?.isCurrent ?? true);

  /// something it shows changed: loaded now if seen, else when it is seen again
  void liveChanged() {
    if (liveSeen) {
      _old = false;
      liveReload();
    } else {
      _old = true;
    }
  }

  /// it may be seen again (its tab chosen, a screen over it closed): loaded if it is old
  void liveMaybe() {
    if (_old && liveSeen) {
      _old = false;
      liveReload();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final r = ModalRoute.of(context);
    if (r != null && r != _route) {
      if (_route != null) appRoutes.unsubscribe(this);
      _route = r;
      appRoutes.subscribe(this, r);
    }
  }

  @override
  void dispose() {
    appRoutes.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() => liveMaybe();
  @override
  void didPush() {}
  @override
  void didPop() {}
  @override
  void didPushNext() {}
}
