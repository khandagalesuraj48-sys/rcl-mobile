import 'package:flutter/material.dart';

import '../ui/scope.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

class SitePickScreen extends StatelessWidget {
  const SitePickScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Your sites'), actions: [TextButton(onPressed: s.signOut, child: const Text('Sign out'))]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text('Namaskar${s.name.isNotEmpty ? ', ${s.name.split(' ').first}' : ''}', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        const TwoLang('Which site do you want to open?', 'कोणती site उघडायची?', color: C.muted, size: 15),
        if (s.error.isNotEmpty) InfoLine(s.error, bad: true),
        const SizedBox(height: 14),
        for (final x in s.sites)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                leading: const CircleAvatar(backgroundColor: C.greenSoft, child: Icon(Icons.location_on_outlined, color: C.green)),
                title: Text(x.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                subtitle: Text([x.code, x.company].where((e) => e.isNotEmpty).join(' · ')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => s.switchSite(x.code),
              ),
            ),
          ),
      ]),
    );
  }
}
