/* (3.31.0, asked 20-10-2026: "ASK BUTTON JE AAHE WARTI TE FKT HOME LA AHE TE PRATEK PAGE WAR HAW … TYALA SMALL KR ANI HA ASK AS NKO
 * EK ROBOT TYPE IMAGE DE TYA WAR CLICK KEKL KI ASK OPN HOIL") the assistant on every page: a small robot at the top right; a tap
 * opens Ask. The red dot of the daily summary (3.15.0) is on it. */
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../screens/assistant.dart';
import 'scope.dart';
import 'theme.dart';
import 't.dart' show tr;

class AskBot extends StatelessWidget {
  const AskBot({super.key, this.size = 38, this.onLight = true});
  final double size;

  /// On a light page: a thin line round it; on the green of Home / Me: none.
  final bool onLight;

  @override
  Widget build(BuildContext context) {
    final s = context.getInheritedWidgetOfExactType<SessionScope>()?.session;
    final bot = Tooltip(
      message: tr('Ask'),
      child: Material(
        color: Colors.white,
        shape: CircleBorder(side: onLight ? const BorderSide(color: C.line) : BorderSide.none),
        elevation: onLight ? 0 : 2,
        shadowColor: Colors.black26,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () {
            HapticFeedback.selectionClick();
            openAssistant(context);
          },
          child: SizedBox(
            width: size,
            height: size,
            child: Padding(padding: EdgeInsets.all(size * .14), child: Image.asset('assets/icons3d/robot.png', filterQuality: FilterQuality.medium)),
          ),
        ),
      ),
    );
    if (s == null) return bot;
    return ValueListenableBuilder<bool>(
      valueListenable: s.briefDue,
      builder: (_, due, __) => Badge(isLabelVisible: due, smallSize: 11, backgroundColor: C.brandRed, child: bot),
    );
  }
}

/// The actions of a page's top bar with the robot at the end.
List<Widget> withAsk([List<Widget> actions = const []]) => [...actions, const Padding(padding: EdgeInsets.only(left: 2, right: 10), child: Center(child: AskBot(size: 36)))];
