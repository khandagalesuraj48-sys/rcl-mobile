import 'package:flutter/material.dart';

import '../core/api.dart';
import 'theme.dart';

/// A label in English with its Marathi name under it (the tiles, the form titles).
class TwoLang extends StatelessWidget {
  const TwoLang(this.en, this.mr, {super.key, this.color = C.ink, this.size = 17});
  final String en, mr;
  final Color color;
  final double size;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(en, style: TextStyle(fontSize: size, fontWeight: FontWeight.w600, color: color)),
        if (mr.isNotEmpty) Text(mr, style: TextStyle(fontFamily: 'NotoDeva', fontSize: size - 3.5, color: color.withValues(alpha: .9))),
      ]);
}

/// Pills to choose one of a few (Day / Night, the locations, quick litres).
class Choice<T> extends StatelessWidget {
  const Choice({super.key, required this.items, required this.value, required this.onPick, this.label});
  final List<(T, String)> items;
  final T? value;
  final ValueChanged<T> onPick;
  final String Function(T)? label;
  @override
  Widget build(BuildContext context) => Wrap(spacing: 8, runSpacing: 8, children: [
        for (final it in items)
          Semantics(
            selected: it.$1 == value,
            button: true,
            child: Material(
              color: it.$1 == value ? C.green : Colors.white,
              shape: StadiumBorder(side: BorderSide(color: it.$1 == value ? C.green : C.line)),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: () => onPick(it.$1),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                  child: Text(it.$2, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: it.$1 == value ? Colors.white : C.ink)),
                ),
              ),
            ),
          ),
      ]);
}

/// The name of a field above it.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(top: 16, bottom: 7), child: Text(text, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: C.muted)));
}

/// A white box that opens something when tapped (machinery picker, date).
class PickBox extends StatelessWidget {
  const PickBox({super.key, required this.text, required this.onTap, this.icon = Icons.search, this.hint = false});
  final String text;
  final VoidCallback onTap;
  final IconData icon;
  final bool hint;
  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: C.line)),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 58),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(children: [
              Expanded(child: Text(text, style: TextStyle(fontSize: 16, fontWeight: hint ? FontWeight.w400 : FontWeight.w500, color: hint ? C.muted : C.ink))),
              Icon(icon, color: C.ink),
            ]),
          ),
        ),
      );
}

/// A line of information on a coloured strip (stock after this issue, a server refusal).
class InfoLine extends StatelessWidget {
  const InfoLine(this.text, {super.key, this.bad = false, this.icon});
  final String text;
  final bool bad;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 14),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: bad ? C.redSoft : C.greenSoft, borderRadius: BorderRadius.circular(16)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon ?? (bad ? Icons.error_outline : Icons.local_gas_station_outlined), size: 20, color: bad ? C.red : C.greenDark),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(fontSize: 14, height: 1.35, color: bad ? C.red : C.greenDark, fontWeight: FontWeight.w500))),
        ]),
      );
}

void toast(BuildContext context, String msg, {bool bad = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg), backgroundColor: bad ? C.red : C.ink, duration: Duration(seconds: bad ? 6 : 3)));
}

String errText(Object e) => e is ApiError ? e.toString() : 'Something went wrong – please try again.';

/// "Are you sure?" – Yes returns true.
Future<bool> ask(BuildContext context, String title, String body, {String yes = 'Yes', String no = 'Cancel'}) async =>
    await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(title),
        content: Text(body, style: const TextStyle(fontSize: 15, height: 1.4)),
        actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: Text(no)), FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(110, 46)), onPressed: () => Navigator.pop(c, true), child: Text(yes))],
      ),
    ) ??
    false;
