/* (15-10-2026) The app's Text, in the chosen language (lib/core/lang.dart). Every screen imports material without its Text and
 * uses this one: the same arguments; what it shows is turned into मराठी / हिंदी when one is chosen. [mr] = the app's own
 * Marathi words for this English text (used as they are when Marathi is chosen). A text typed by a person or coming from the
 * data is turned only when it is a known word ("Day", "Working"), never changed otherwise. MrLine: the Marathi second line
 * under an English title – shown only while no language is chosen (as before). */
import 'package:flutter/material.dart' as m;
import 'package:flutter/widgets.dart';

import '../core/lang.dart';
export '../core/lang.dart' show tr, bi, Lang, hasDeva;

/// Rebuilds what shows words when the language changes.
class LangScope extends InheritedNotifier<Lang> {
  LangScope({super.key, required super.child}) : super(notifier: Lang.i);
  static Lang of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<LangScope>()?.notifier ?? Lang.i;
}

class Text extends StatelessWidget {
  const Text(this.data,
      {super.key,
      this.mr = '',
      this.style,
      this.strutStyle,
      this.textAlign,
      this.textDirection,
      this.locale,
      this.softWrap,
      this.overflow,
      this.textScaler,
      this.maxLines,
      this.semanticsLabel,
      this.textWidthBasis,
      this.textHeightBehavior,
      this.selectionColor});
  final String data, mr;
  final TextStyle? style;
  final StrutStyle? strutStyle;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final Locale? locale;
  final bool? softWrap;
  final TextOverflow? overflow;
  final TextScaler? textScaler;
  final int? maxLines;
  final String? semanticsLabel;
  final TextWidthBasis? textWidthBasis;
  final TextHeightBehavior? textHeightBehavior;
  final Color? selectionColor;

  @override
  Widget build(BuildContext context) {
    final l = LangScope.of(context);
    final s = mr.isNotEmpty ? l.pair(data, mr) : l.tr(data);
    return m.Text(s,
        style: style,
        strutStyle: strutStyle,
        textAlign: textAlign,
        textDirection: textDirection,
        locale: locale,
        softWrap: softWrap,
        overflow: overflow,
        textScaler: textScaler,
        maxLines: maxLines,
        semanticsLabel: semanticsLabel,
        textWidthBasis: textWidthBasis,
        textHeightBehavior: textHeightBehavior,
        selectionColor: selectionColor);
  }
}

/// The Marathi line under an English title: shown as before while no language is chosen; once one is, the title itself is in it.
class MrLine extends StatelessWidget {
  const MrLine(this.data, {super.key, this.style, this.textAlign, this.maxLines, this.overflow});
  final String data;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  @override
  Widget build(BuildContext context) =>
      LangScope.of(context).chosen ? const SizedBox.shrink() : m.Text(data, style: style, textAlign: textAlign, maxLines: maxLines, overflow: overflow);
}
