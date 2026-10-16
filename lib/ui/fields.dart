/* THE BOXES OF A FORM (3.4.0) – one look for every master form of the app: a date box (tap → calendar, × clears it), a pick-list,
 * a text box with a list of earlier values to pick from, ticks as chips, and a label / value line of a details sheet. */
import 'package:flutter/material.dart' hide Text;

import '../core/format.dart';
import 't.dart';
import 'theme.dart';
import 'widgets.dart';

/// A date (yyyy-mm-dd, '' = none). [clear]: it may be emptied.
class DateField extends StatelessWidget {
  const DateField({super.key, required this.label, required this.value, required this.onChanged, this.clear = true, this.last, this.first, this.enabled = true});
  final String label, value;
  final ValueChanged<String> onChanged;
  final bool clear, enabled;
  final DateTime? last, first;
  @override
  Widget build(BuildContext context) => Opacity(
        opacity: enabled ? 1 : .5,
        child: Press(
          onTap: !enabled
              ? null
              : () async {
                  final top = last ?? DateTime(2035, 12, 31), low = first ?? DateTime(2015);
                  var init = value.length == 10 ? parseKey(value) : DateTime.now();
                  if (init.isAfter(top)) init = top;
                  if (init.isBefore(low)) init = low;
                  final d = await showDatePicker(context: context, initialDate: init, firstDate: low, lastDate: top);
                  if (d != null) onChanged(dateKey(d));
                },
          radius: 16,
          shadow: false,
          padding: const EdgeInsets.fromLTRB(10, 10, 4, 10),
          child: Row(children: [
            const Icon(Icons.event_rounded, color: C.blue, size: 18),
            const SizedBox(width: 6),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: C.muted)),
                Text(value.isEmpty ? '–' : showDate(value), maxLines: 1, softWrap: false, overflow: TextOverflow.fade, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ]),
            ),
            if (clear && value.isNotEmpty && enabled)
              InkWell(
                customBorder: const CircleBorder(),
                onTap: () => onChanged(''),
                child: Padding(padding: const EdgeInsets.all(6), child: Icon(Icons.close_rounded, size: 16, color: C.muted, semanticLabel: tr('Clear'))),
              )
            else
              const SizedBox(width: 8),
          ]),
        ),
      );
}

/// A pick-list ([items]: value, words shown). [blank]: a first line '' with these words.
class PickField extends StatelessWidget {
  const PickField({super.key, required this.label, required this.value, required this.items, required this.onChanged, this.blank, this.enabled = true});
  final String label, value;
  final List<String> items;
  final String? blank;
  final ValueChanged<String> onChanged;
  final bool enabled;
  @override
  Widget build(BuildContext context) {
    final all = [if (blank != null) '', ...items];
    return DropdownButtonFormField<String>(
      key: ValueKey('$label|$value|${all.join(',')}'),
      initialValue: all.contains(value) ? value : (all.isEmpty ? null : all.first),
      isExpanded: true,
      decoration: InputDecoration(labelText: tr(label)),
      items: [for (final x in all) DropdownMenuItem(value: x, child: Text(x.isEmpty ? (blank ?? '') : x, maxLines: 1, overflow: TextOverflow.ellipsis))],
      onChanged: enabled ? (v) => onChanged(v ?? '') : null,
    );
  }
}

/// A text box; [options]: earlier values to pick from (as the web's lists under a box).
class TextBox extends StatelessWidget {
  const TextBox({super.key, required this.label, required this.controller, this.options = const [], this.kb, this.upper = false, this.hint = '', this.enabled = true, this.onChanged, this.maxLines = 1});
  final String label, hint;
  final TextEditingController controller;
  final List<String> options;
  final TextInputType? kb;
  final bool upper, enabled;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  @override
  Widget build(BuildContext context) {
    InputDecoration deco([Widget? suffix]) => InputDecoration(labelText: tr(label), hintText: hint.isEmpty ? null : tr(hint), suffixIcon: suffix);
    final field = TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: kb,
      maxLines: maxLines,
      textCapitalization: upper ? TextCapitalization.characters : TextCapitalization.none,
      onChanged: onChanged,
      decoration: deco(options.isEmpty || !enabled
          ? null
          : IconButton(
              tooltip: tr('Pick'),
              icon: const Icon(Icons.arrow_drop_down_circle_outlined, color: C.muted),
              onPressed: () async {
                final v = await pickFromList(context, label, options);
                if (v == null) return;
                controller.text = v;
                onChanged?.call(v);
              },
            )),
    );
    return field;
  }
}

/// A list to pick one from, with a search box (null = nothing picked).
Future<String?> pickFromList(BuildContext context, String title, List<String> options) => showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (c) => _PickSheet(title: title, options: options),
    );

class _PickSheet extends StatefulWidget {
  const _PickSheet({required this.title, required this.options});
  final String title;
  final List<String> options;
  @override
  State<_PickSheet> createState() => _PickSheetState();
}

class _PickSheetState extends State<_PickSheet> {
  String q = '';
  @override
  Widget build(BuildContext context) {
    final l = widget.options.where((o) => q.isEmpty || o.toLowerCase().contains(q.toLowerCase())).toList();
    return SizedBox(
      height: MediaQuery.of(context).size.height * .75,
      child: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 8), child: Align(alignment: Alignment.centerLeft, child: Text(widget.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)))),
        if (widget.options.length > 8)
          Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), child: TextField(autofocus: false, onChanged: (v) => setState(() => q = v), decoration: InputDecoration(hintText: tr('Search'), prefixIcon: const Icon(Icons.search_rounded)))),
        Expanded(
          child: ListView(children: [
            for (final o in l) ListTile(key: Key('pick-$o'), title: Text(o), onTap: () => Navigator.pop(context, o)),
            if (l.isEmpty) Padding(padding: const EdgeInsets.all(24), child: Text('Nothing to show.', style: const TextStyle(color: C.muted))),
          ]),
        ),
      ]),
    );
  }
}

/// "Label …… value" – one line of a details sheet.
class InfoRow extends StatelessWidget {
  const InfoRow(this.label, this.value, {super.key, this.tone = C.ink, this.bold = false});
  final String label, value;
  final Color tone;
  final bool bold;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 132, child: Text(label, style: const TextStyle(fontSize: 13.5, color: C.muted))),
          Expanded(child: Text(value.isEmpty ? '–' : value, style: TextStyle(fontSize: 14.5, color: tone, fontWeight: bold ? FontWeight.w700 : FontWeight.w500, height: 1.3))),
        ]),
      );
}

/// A small heading inside a form.
class FormHead extends StatelessWidget {
  const FormHead(this.text, {super.key, this.sub = ''});
  final String text, sub;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 16, 2, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          if (sub.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2), child: Text(sub, style: const TextStyle(fontSize: 12.5, color: C.muted, height: 1.3))),
        ]),
      );
}

/// "Field / Now / New" – what a save will change (as the web's changeTable), in a question. true = go on.
Future<bool> askChanges(BuildContext context, String title, List<(String, String, String)> rows, {List<String> before = const [], String beforeHead = '', String yes = 'Update'}) async =>
    await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        scrollable: true,
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (beforeHead.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(beforeHead, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5))),
          for (final l in before) Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('• $l', style: const TextStyle(fontSize: 14, height: 1.35))),
          if (before.isNotEmpty) const SizedBox(height: 10),
          Text('These details will change:', style: const TextStyle(fontSize: 14, color: C.muted)),
          const SizedBox(height: 6),
          for (final r in rows)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: C.slateSoft, borderRadius: BorderRadius.circular(12)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(r.$1, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(r.$2.isEmpty ? '–' : r.$2, style: const TextStyle(fontSize: 13.5, color: C.muted, decoration: TextDecoration.lineThrough)),
                Text(r.$3.isEmpty ? '–' : r.$3, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: C.greenDark)),
              ]),
            ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(key: const Key('ask-yes'), style: FilledButton.styleFrom(minimumSize: const Size(110, 46)), onPressed: () => Navigator.pop(c, true), child: Text(yes)),
        ],
      ),
    ) ??
    false;

/// A message to read (OK only) – a list of what went wrong (as the web's "Nothing saved").
Future<void> tellLines(BuildContext context, String title, List<String> lines) => showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        scrollable: true,
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final l in lines) Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('• $l', style: const TextStyle(fontSize: 14.5, height: 1.35))),
        ]),
        actions: [FilledButton(key: const Key('tell-ok'), style: FilledButton.styleFrom(minimumSize: const Size(110, 46)), onPressed: () => Navigator.pop(c), child: const Text('OK'))],
      ),
    );
