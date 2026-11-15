/* (15-11-2026, his decisions) THE SKETCHLINE BETA APP (config.dart kBetaApp): a "BETA" ribbon over every screen – it works only on the
 * Beta TEST data, never on the live one; the Sketchline app has none. */
import 'package:flutter/widgets.dart';

import '../config.dart' show kBetaApp;

/// [child] with the BETA ribbon in its top corner when [on] (the Beta app); else [child] as it is.
Widget betaMark(Widget child, {bool on = kBetaApp}) =>
    on ? Banner(key: const Key('beta-mark'), message: 'BETA', location: BannerLocation.topEnd, color: const Color(0xFFD97706), child: child) : child;

/// The app's name on the phone's list of open apps.
String appTitle({bool beta = kBetaApp}) => beta ? 'Sketchline Beta' : 'Sketchline';
