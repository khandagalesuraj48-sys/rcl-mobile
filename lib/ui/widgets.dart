import 'package:flutter/material.dart';

import 'theme.dart';

/// A short message at the bottom of the screen.
void toast(BuildContext context, String msg, {bool bad = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg), backgroundColor: bad ? C.red : C.ink, duration: Duration(seconds: bad ? 6 : 3)));
}

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
