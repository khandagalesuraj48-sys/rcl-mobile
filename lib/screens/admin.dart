/* ADMINISTRATION – the app's own screens (3.9.0) of the web's Admin pages (Home → Administration, Admin only): Users & Access
 * (read only once the Super Admin gives users and access; else add / change a user, his access per page, a one-time password),
 * the access report, Company & site, the Rules of this site, Screen share – who may use it, the Activity Log, the Database check
 * and Read Me – the same server actions as the web (usersAdmin, saveUserAdmin, accessReport, saveOrgSettings, saveSiteRules,
 * rtcRights, getActivity, dbHealth, readme). */
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart' hide Text;
import 'package:flutter/material.dart' as mt show Text;
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/admin.dart';
import '../core/format.dart';
import '../core/html_lite.dart';
import '../core/session.dart';
import '../ui/fields.dart';
import '../ui/outputs.dart';
import '../ui/scope.dart';
import '../ui/t.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'approvals.dart' show openApprovals;

Future<void> openAdmin(BuildContext context) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const AdminHub()));

final _small = OutlinedButton.styleFrom(minimumSize: const Size(0, 44), padding: const EdgeInsets.symmetric(horizontal: 14));

/// A card on its own Material (the switches and tiles in it draw on it).
Widget _card(Widget child, {Key? key, Color? bg, Color line = C.line, EdgeInsets margin = const EdgeInsets.only(bottom: 12), double radius = 18}) => Padding(
      key: key,
      padding: margin,
      child: Material(color: bg ?? Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius), side: BorderSide(color: line)), clipBehavior: Clip.antiAlias, child: child),
    );

Widget _panel(List<Widget> kids, {Key? key, Color? bg}) => _card(Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: kids)), key: key, bg: bg);

Widget _note(String t) => Text(t, style: const TextStyle(fontSize: 12.5, color: C.muted, height: 1.35));

class AdminHub extends StatelessWidget {
  const AdminHub({super.key});
  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    final pages = <(String, String, String, String, Widget Function())>[
      ('Users & Access', 'युजर व access', 'gear', 'Who can open each page – Edit, View or No access', () => const UsersScreen()),
      ('Company & site', 'कंपनी व साइट', 'office_building', 'The company, the site, the names bills are made in', () => const OrgScreen()),
      ('Rules of this site', 'साइटचे नियम', 'clipboard', 'Days back for entries, the notice, the shift hours', () => const RulesScreen()),
      ('Activity Log', 'ॲक्टिव्हिटी लॉग', 'calendar', 'Every sign-in, add, change and delete – who, when, what', () => const ActivityScreen()),
      ('Screen share – who may use it', 'स्क्रीन शेअर', 'shield', 'Ticked = may show a screen and be called', () => const RtcScreen()),
      ('Read Me', 'रीड मी', 'notebook', 'How to make the app for a new site', () => const ReadMeScreen()),
    ];
    return Scaffold(
      appBar: AppBar(title: const TwoLang('Administration', 'प्रशासन', size: 20, weight: FontWeight.w700)),
      // (3.14.0) one column (every tile built), so a tile below the screen is there to be found and tapped
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(s.siteName, style: const TextStyle(fontSize: 15, color: C.muted, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        if (!s.admin) const EmptyState('Admin only', 'These pages are for the Admin of the site.', pic: 'gear'),
        if (s.admin) ...[
          for (final p in pages)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Press(
                key: Key('ad-${p.$1}'),
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => p.$5())),
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  Container(width: 58, height: 58, decoration: BoxDecoration(color: C.slateSoft, borderRadius: BorderRadius.circular(18)), alignment: Alignment.center, child: Pic(p.$3, size: 40)),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [TwoLang(p.$1, p.$2, size: 17, weight: FontWeight.w700), const SizedBox(height: 2), Text(p.$4, style: const TextStyle(fontSize: 12.5, color: C.muted))])),
                  const Icon(Icons.chevron_right_rounded, color: C.faint),
                ]),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Press(
              key: const Key('ad-db'),
              onTap: () => showDbCheck(context, s),
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                Container(width: 58, height: 58, decoration: BoxDecoration(color: C.greenSoft, borderRadius: BorderRadius.circular(18)), alignment: Alignment.center, child: Pic('oil_drum', size: 40)),
                const SizedBox(width: 14),
                const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [TwoLang('Database check', 'डेटाबेस तपासणी', size: 17, weight: FontWeight.w700), SizedBox(height: 2), Text('Every SQL step against the live database', style: TextStyle(fontSize: 12.5, color: C.muted))])),
                const Icon(Icons.chevron_right_rounded, color: C.faint),
              ]),
            ),
          ),
          // (3.14.0) the faults of the app (the web's "Faults: N" pill) and the Google Sheet backup (the web's backup pill)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Press(
              key: const Key('ad-faults'),
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const FaultsScreen())),
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                Container(width: 58, height: 58, decoration: BoxDecoration(color: C.redSoft, borderRadius: BorderRadius.circular(18)), alignment: Alignment.center, child: const Icon(Icons.report_gmailerrorred_rounded, color: C.red, size: 34)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const TwoLang('Faults of the app', 'ॲपमधील चुका', size: 17, weight: FontWeight.w700),
                    const SizedBox(height: 2),
                    Text(faultsLine(s.faults, s.today), style: const TextStyle(fontSize: 12.5, color: C.muted)),
                  ]),
                ),
                const Icon(Icons.chevron_right_rounded, color: C.faint),
              ]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Press(
              key: const Key('ad-backup'),
              onTap: () => runBackup(context, s),
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                Container(width: 58, height: 58, decoration: BoxDecoration(color: s.backup['ok'] == false ? C.redSoft : C.blueSoft, borderRadius: BorderRadius.circular(18)), alignment: Alignment.center, child: Icon(Icons.cloud_sync_rounded, color: s.backup['ok'] == false ? C.red : C.blue, size: 34)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const TwoLang('Backup to Google Sheet', 'Google Sheet बॅकअप', size: 17, weight: FontWeight.w700),
                    const SizedBox(height: 2),
                    Text(backupLine(s.backup), style: TextStyle(fontSize: 12.5, color: s.backup['ok'] == false ? C.red : C.muted)),
                  ]),
                ),
                const Icon(Icons.chevron_right_rounded, color: C.faint),
              ]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Press(
              key: const Key('ad-approvals'),
              onTap: () => openApprovals(context),
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                Container(width: 58, height: 58, decoration: BoxDecoration(color: C.amberSoft, borderRadius: BorderRadius.circular(18)), alignment: Alignment.center, child: Pic('bell', size: 40)),
                const SizedBox(width: 14),
                const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [TwoLang('Approvals', 'मंजुरी', size: 17, weight: FontWeight.w700), SizedBox(height: 2), Text('Entries sent for verification, changes of billed periods', style: TextStyle(fontSize: 12.5, color: C.muted))])),
                const Icon(Icons.chevron_right_rounded, color: C.faint),
              ]),
            ),
          ),
        ],
      ]),
      ),
    );
  }
}

// =====================================================================================================================
//  USERS & ACCESS
// =====================================================================================================================
class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});
  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  Map<String, dynamic>? d;
  String err = '', q = '';
  bool busy = false, started = false;
  final edits = <String, Map<String, dynamic>>{}; // email → what is changed and not saved
  final _pw = <String, TextEditingController>{};
  Map<String, dynamic>? adding;
  final newEmail = TextEditingController(), newName = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (started) return;
    started = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    for (final c in [..._pw.values, newEmail, newName]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final s = SessionScope.read(context);
    try {
      final r = ((await s.api.call('usersAdmin')) as Map).cast<String, dynamic>();
      if (!mounted) return;
      setState(() {
        d = r;
        err = '';
        edits.clear();
        adding = null;
      });
      for (final c in _pw.values) {
        c.clear();
      }
    } catch (e) {
      if (mounted) setState(() => err = errText(e));
    }
  }

  List<Map<String, dynamic>> get _users => [for (final u in (d?['users'] as List? ?? const []).whereType<Map>()) u.cast<String, dynamic>()];
  List<Map> get _mods => [for (final m in (d?['modules'] as List? ?? const []).whereType<Map>()) m];
  bool get _ro => d?['managedBySuper'] == true;

  Map<String, dynamic> _ed(Map u) => edits.putIfAbsent('${u['email']}', () => {'active': u['active'] != false, 'admin': u['admin'] == true, 'perms': {...((u['perms'] as Map?) ?? const {})}});

  Future<void> _save(Map<String, dynamic> x, bool isNew) async {
    final s = SessionScope.read(context);
    setState(() => busy = true);
    try {
      await s.api.call('saveUserAdmin', [x], true);
      if (!mounted) return;
      toast(context, '${isNew ? 'User added: ' : 'Saved: '}${x['email']}${'${x['newPassword']}'.isNotEmpty ? ' – tell the user the one-time password.' : ''}');
      setState(() => busy = false);
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => busy = false);
      toast(context, errText(e), bad: !isSent(e));
    }
  }

  void _saveUser(Map u) {
    final e = _ed(u);
    _save({'isNew': false, 'email': u['email'], 'name': u['name'], 'active': e['active'], 'admin': e['admin'], 'newPassword': _pw['${u['email']}']?.text ?? '', 'perms': {for (final m in _mods) '${m['key']}': e['admin'] == true ? 'Edit' : '${(e['perms'] as Map)[m['key']] ?? 'None'}'}}, false);
  }

  void _saveNew() {
    final a = adding!;
    _save({'isNew': true, 'email': newEmail.text.trim(), 'name': newName.text.trim(), 'active': a['active'], 'admin': a['admin'], 'newPassword': _pw['+new']?.text ?? '', 'perms': {for (final m in _mods) '${m['key']}': a['admin'] == true ? 'Edit' : '${(a['perms'] as Map)[m['key']] ?? 'None'}'}}, true);
  }

  Future<void> _column() async {
    final mods = _mods;
    final page = await pickFromList(context, 'Set a whole column', [for (final m in mods) '${m['label']}']);
    if (page == null || !mounted) return;
    final acc = await pickFromList(context, page, const ['all Edit', 'all View', 'all No access']);
    if (acc == null || !mounted) return;
    final key = '${mods.firstWhere((m) => m['label'] == page)['key']}', v = acc == 'all Edit' ? 'Edit' : acc == 'all View' ? 'View' : 'None';
    setState(() {
      for (final u in _users) {
        final e = _ed(u);
        if (e['admin'] != true) (e['perms'] as Map)[key] = v;
      }
    });
    toast(context, '$page: ${kAccessWord[v]} for every user – then Save each user.');
  }

  Future<void> _report() async {
    final s = SessionScope.read(context);
    Map d0;
    try {
      d0 = (await s.api.call('accessReport')) as Map;
    } catch (e) {
      if (mounted) toast(context, errText(e), bad: true);
      return;
    }
    if (!mounted) return;
    final odd = accessOdd(d0);
    final save = await askLines(context, 'Access report', [
      'Users: ${d0['users']} · pages: ${d0['modules']} · cells looked at: ${(d0['rows'] as List? ?? const []).length}',
      ...accessSummary(d0),
      if (odd.isEmpty) '✓ No empty cell and no other text: every access is written out.',
      for (final r in odd.take(40)) '${r['email']} · ${r['module']} · written: ${r['raw'] == '' ? '(empty)' : r['raw']} · access now: ${r['effective']}',
    ], note: 'This report changes nothing. "Save the full list" gives one line per user and page (opens in Excel).', yes: 'Save the full list');
    if (!save) return;
    await shareFile(Uint8List.fromList(utf8.encode(accessCsv(d0))), 'Access_report_${s.today}.csv', 'text/csv');
  }

  Future<void> _makeSuper() async {
    final s = SessionScope.read(context);
    final name = TextEditingController(), email = TextEditingController(), pw = TextEditingController(), pw2 = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dc) => AlertDialog(
        title: Text('Create the Super Admin'),
        scrollable: true,
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('The Super Admin designs the system: the sites, the users and their access on each site, and the companies. He makes no entries and sees no reports. From then on users and access are given by the Super Admin only – also yours.'),
          const SizedBox(height: 10),
          TextBox(label: 'Name', controller: name),
          const SizedBox(height: 8),
          TextBox(label: 'Email – one of its own, not a user\'s', controller: email, kb: TextInputType.emailAddress),
          const SizedBox(height: 8),
          TextField(controller: pw, obscureText: true, decoration: InputDecoration(labelText: tr('Password – 8 or more, letters and numbers'))),
          const SizedBox(height: 8),
          TextField(controller: pw2, obscureText: true, decoration: InputDecoration(labelText: tr('Password again'))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dc, false), child: Text('Cancel')),
          FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(110, 46)), onPressed: () => Navigator.pop(dc, true), child: Text('Create')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final r = (await s.api.call('createSuperAdmin', [
        {'name': name.text, 'email': email.text.trim(), 'password': pw.text, 'password2': pw2.text}
      ], true)) as Map;
      if (!mounted) return;
      await tellLines(context, 'Super Admin created – write this code down', [
        'Sign in as the Super Admin with ${r['email']} and the password you chose.',
        'If that password is ever forgotten, this recovery code is the only way back in. Write it on paper and keep it safe – it is shown only now:',
        '${r['recovery']}',
      ]);
      _load();
    } catch (e) {
      if (mounted) await tellLines(context, 'Super Admin not created', [errText(e)]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final users = _users.where((u) => q.isEmpty || '${u['name']} ${u['email']}'.toLowerCase().contains(q.toLowerCase())).toList();
    return Scaffold(
      appBar: AppBar(title: const TwoLang('Users & Access', 'युजर व access', size: 20, weight: FontWeight.w700), actions: [IconButton(tooltip: tr('Refresh'), onPressed: _load, icon: const Icon(Icons.refresh_rounded))]),
      body: d == null
          ? (err.isEmpty ? const Center(child: CircularProgressIndicator()) : ListView(padding: const EdgeInsets.all(16), children: [InfoLine(err, bad: true)]))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(key: const Key('ua-list'), padding: const EdgeInsets.fromLTRB(14, 10, 14, 30), children: [
                _note('Who can open each page: Edit (add / change / delete), View (see and print) or No access (page hidden). A change works at once for that user.'),
                if (_ro) InfoLine('Users and their access are given by the Super Admin – this list shows them; ask the Super Admin for a change.', icon: Icons.info_outline_rounded),
                const SizedBox(height: 8),
                Text('${_users.length} users · ${_users.where((u) => u['active'] != false).length} active', key: const Key('ua-note'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Wrap(spacing: 8, runSpacing: 6, children: [
                  if (!_ro && adding == null)
                    FilledButton.icon(
                      key: const Key('ua-new'),
                      style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                      onPressed: () => setState(() {
                        adding = {'active': true, 'admin': false, 'perms': <String, String>{}};
                        newEmail.clear();
                        newName.clear();
                      }),
                      icon: const Icon(Icons.person_add_alt_1_rounded),
                      label: Text('Add user'),
                    ),
                  if (!_ro) OutlinedButton(key: const Key('ua-col'), style: _small, onPressed: _column, child: Text('Set a whole column')),
                  OutlinedButton(key: const Key('ua-report'), style: _small, onPressed: _report, child: Text('Access report')),
                  if (d?['canCreateSuper'] == true) OutlinedButton(key: const Key('ua-mksa'), style: _small, onPressed: _makeSuper, child: Text('Create Super Admin')),
                ]),
                const SizedBox(height: 8),
                TextField(key: const Key('ua-q'), onChanged: (v) => setState(() => q = v.trim()), decoration: InputDecoration(hintText: tr('Search user…'), prefixIcon: const Icon(Icons.search_rounded), isDense: true)),
                const SizedBox(height: 10),
                if (adding != null) _newCard(),
                for (final u in users) _userCard(u),
                _note('A new user, or a password reset, gets a one-time password that works once – at that sign-in the user must set his own. Admin users have Edit on every page.'),
              ]),
            ),
    );
  }

  Widget _access(String key, String v, bool off, ValueChanged<String> on) => SizedBox(
        width: 150,
        child: PickField(key: Key(key), label: '', value: kAccessWord[v] ?? 'No access', items: const ['Edit', 'View', 'No access'], enabled: !off, onChanged: (x) => on(x == 'No access' ? 'None' : x)),
      );

  Widget _perms(Map e, String who) {
    final mods = _mods;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final m in mods)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(children: [
            Expanded(child: Text('${m['label']}', style: const TextStyle(fontSize: 13.5))),
            if (_ro)
              _pill(e['admin'] == true ? 'Edit' : '${(e['perms'] as Map)[m['key']] ?? 'None'}')
            else
              _access('ua-p-$who-${m['key']}', e['admin'] == true ? 'Edit' : '${(e['perms'] as Map)[m['key']] ?? 'None'}', e['admin'] == true, (v) => setState(() => (e['perms'] as Map)[m['key']] = v)),
          ]),
        ),
    ]);
  }

  Widget _pill(String v) => Pill(kAccessWord[v] ?? v, color: v == 'Edit' ? C.greenDark : v == 'View' ? C.blue : C.muted, bg: v == 'Edit' ? C.greenSoft : v == 'View' ? C.blueSoft : C.slateSoft);

  Widget _userCard(Map<String, dynamic> u) {
    final email = '${u['email']}', e = _ed(u), dirty = edits.containsKey(email) && (e['active'] != (u['active'] != false) || e['admin'] != (u['admin'] == true) || jsonEncode(e['perms']) != jsonEncode({...((u['perms'] as Map?) ?? const {})}));
    final pw = _pw.putIfAbsent(email, () => TextEditingController());
    return _card(
      key: Key('ua-$email'),
      margin: const EdgeInsets.only(bottom: 10),
      bg: u['active'] == false ? C.slateSoft : Colors.white,
      line: dirty ? C.amber : C.line,
      Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: PageStorageKey('ua-x-$email'),
          title: Text('${u['name']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(email, style: const TextStyle(fontSize: 12.5, color: C.muted)),
            const SizedBox(height: 4),
            Wrap(spacing: 6, runSpacing: 4, children: [
              if (u['admin'] == true) Pill('Admin', color: C.purple, bg: C.purpleSoft),
              if (u['active'] == false) Pill('Not active', color: C.red, bg: C.redSoft),
              if (u['mustChange'] == true) Pill('must set password', color: C.amber, bg: C.amberSoft),
              if (dirty) Pill('Not saved yet', color: C.amber, bg: C.amberSoft),
            ]),
          ]),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          children: [
            if (!_ro) ...[
              SwitchListTile(key: Key('ua-active-$email'), contentPadding: EdgeInsets.zero, title: Text('Active – can sign in'), value: e['active'] == true, onChanged: (v) => setState(() => e['active'] = v)),
              SwitchListTile(key: Key('ua-admin-$email'), contentPadding: EdgeInsets.zero, title: Text('Admin – every page with Edit, plus Users and Activity Log'), value: e['admin'] == true, onChanged: (v) => setState(() => e['admin'] = v)),
            ],
            _perms(e, email),
            if (!_ro) ...[
              const SizedBox(height: 10),
              TextField(key: Key('ua-pw-$email'), controller: pw, decoration: InputDecoration(isDense: true, labelText: tr('new one-time password'), hintText: tr('empty = the password is not changed'))),
              const SizedBox(height: 8),
              Align(alignment: Alignment.centerLeft, child: FilledButton(key: Key('ua-save-$email'), style: FilledButton.styleFrom(minimumSize: const Size(0, 44)), onPressed: busy ? null : () => _saveUser(u), child: Text('Save'))),
            ],
          ],
        ),
      ),
    );
  }

  Widget _newCard() {
    final a = adding!, pw = _pw.putIfAbsent('+new', () => TextEditingController());
    return _panel(key: const Key('ua-newcard'), bg: C.greenSoft, [
      Text('New user', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      TextBox(key: const Key('ua-new-email'), label: 'Email', controller: newEmail, kb: TextInputType.emailAddress),
      const SizedBox(height: 8),
      TextBox(key: const Key('ua-new-name'), label: 'Name', controller: newName),
      SwitchListTile(contentPadding: EdgeInsets.zero, title: Text('Active – can sign in'), value: a['active'] == true, onChanged: (v) => setState(() => a['active'] = v)),
      SwitchListTile(key: const Key('ua-new-admin'), contentPadding: EdgeInsets.zero, title: Text('Admin – every page with Edit, plus Users and Activity Log'), value: a['admin'] == true, onChanged: (v) => setState(() => a['admin'] = v)),
      _perms(a, '+new'),
      const SizedBox(height: 10),
      TextField(key: const Key('ua-new-pw'), controller: pw, decoration: InputDecoration(isDense: true, labelText: tr('one-time password'))),
      const SizedBox(height: 8),
      Wrap(spacing: 8, children: [
        FilledButton(key: const Key('ua-add'), style: FilledButton.styleFrom(minimumSize: const Size(0, 44)), onPressed: busy ? null : _saveNew, child: Text('Add')),
        OutlinedButton(key: const Key('ua-cancel'), style: _small, onPressed: () => setState(() => adding = null), child: Text('Cancel')),
      ]),
    ]);
  }
}

// =====================================================================================================================
//  COMPANY & SITE
// =====================================================================================================================
class OrgScreen extends StatefulWidget {
  const OrgScreen({super.key});
  @override
  State<OrgScreen> createState() => _OrgScreenState();
}

class _OrgScreenState extends State<OrgScreen> {
  final cust = TextEditingController(), site = TextEditingController(), logo = TextEditingController(), names = TextEditingController(), video = TextEditingController();
  bool intro = true, busy = false, started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (started) return;
    started = true;
    final o = SessionScope.read(context).org;
    cust.text = '${o['customer'] ?? SessionScope.read(context).company}';
    site.text = '${o['site'] ?? ''}';
    logo.text = '${o['logo'] ?? ''}';
    names.text = [for (final n in (o['billNames'] as List? ?? const [])) '$n'].join('\n');
    video.text = '${o['video'] ?? ''}';
    intro = o['intro'] != false;
  }

  @override
  void dispose() {
    for (final c in [cust, site, logo, names, video]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final s = SessionScope.read(context);
    setState(() => busy = true);
    try {
      final r = (await s.api.call('saveOrgSettings', [
        {'customer': cust.text.trim(), 'site': site.text.trim(), 'logo': logo.text.trim(), 'billNames': names.text.split('\n').map((x) => x.trim()).where((x) => x.isNotEmpty).toList(), 'video': video.text.trim(), 'intro': intro}
      ], true)) as Map;
      if (r['org'] is Map) s.org = (r['org'] as Map).cast<String, dynamic>();
      if ('${s.org['customer'] ?? ''}'.isNotEmpty) s.company = '${s.org['customer']}';
      if (!mounted) return;
      setState(() => busy = false);
      toast(context, 'Company & site saved.');
    } catch (e) {
      if (!mounted) return;
      setState(() => busy = false);
      toast(context, errText(e), bad: !isSent(e));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const TwoLang('Company & site', 'कंपनी व साइट', size: 20, weight: FontWeight.w700)),
        body: ListView(padding: const EdgeInsets.fromLTRB(14, 10, 14, 30), children: [
          _note('This copy of Fleet ERP is for one company and one site. Every user belongs to this site; another site has its own users and its own data.'),
          const SizedBox(height: 10),
          TextBox(key: const Key('org-customer'), label: 'Company *', controller: cust),
          const SizedBox(height: 8),
          TextBox(key: const Key('org-site'), label: 'Site / project (printed on every report)', controller: site),
          const SizedBox(height: 8),
          TextBox(key: const Key('org-logo'), label: 'Logo (https link, optional)', controller: logo, hint: 'https://…'),
          const SizedBox(height: 8),
          TextBox(key: const Key('org-names'), label: 'Names bills are made in (one per line, 1 to 4)', controller: names, maxLines: 4),
          const SizedBox(height: 8),
          TextBox(key: const Key('org-video'), label: 'Opening film (https link to an .mp4, optional)', controller: video, hint: 'empty = the built-in opening'),
          SwitchListTile(key: const Key('org-intro'), contentPadding: EdgeInsets.zero, title: Text('Play the opening when the app is opened'), value: intro, onChanged: (v) => setState(() => intro = v)),
          const SizedBox(height: 8),
          FilledButton(key: const Key('org-save'), onPressed: busy ? null : _save, child: Text('Save company & site')),
        ]),
      );
}

// =====================================================================================================================
//  RULES OF THIS SITE
// =====================================================================================================================
class RulesScreen extends StatefulWidget {
  const RulesScreen({super.key});
  @override
  State<RulesScreen> createState() => _RulesScreenState();
}

class _RulesScreenState extends State<RulesScreen> {
  final back = TextEditingController(), note = TextEditingController();
  String day = '08:00', night = '20:00';
  bool busy = false, started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (started) return;
    started = true;
    final s = SessionScope.read(context), r = s.siteRules;
    back.text = '${r['backDays'] ?? ''}';
    note.text = '${r['announce'] ?? ''}';
    day = s.dayFrom;
    night = s.nightFrom;
  }

  @override
  void dispose() {
    back.dispose();
    note.dispose();
    super.dispose();
  }

  Future<void> _time(bool isDay) async {
    final v = isDay ? day : night, p = v.split(':');
    final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: int.tryParse(p[0]) ?? 8, minute: int.tryParse(p.length > 1 ? p[1] : '0') ?? 0));
    if (t == null) return;
    final x = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    setState(() => isDay ? day = x : night = x);
  }

  Future<void> _save() async {
    final s = SessionScope.read(context);
    setState(() => busy = true);
    try {
      final r = (await s.api.call('saveSiteRules', [
        {'backDays': back.text.trim(), 'announce': note.text.trim(), 'dayFrom': day, 'nightFrom': night}
      ], true)) as Map;
      final rules = (r['rules'] as Map?)?.cast<String, dynamic>();
      if (rules != null) {
        s.siteRules = rules;
        s.dayFrom = '${rules['dayFrom'] ?? s.dayFrom}';
        s.nightFrom = '${rules['nightFrom'] ?? s.nightFrom}';
      }
      if (!mounted) return;
      setState(() => busy = false);
      toast(context, 'Rules of the site saved.');
    } catch (e) {
      if (!mounted) return;
      setState(() => busy = false);
      toast(context, errText(e), bad: !isSent(e));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const TwoLang('Rules of this site', 'साइटचे नियम', size: 20, weight: FontWeight.w700)),
        body: ListView(padding: const EdgeInsets.fromLTRB(14, 10, 14, 30), children: [
          _note('Admin only – these apply to every user of this site.'),
          const SizedBox(height: 10),
          TextBox(key: const Key('rule-back'), label: 'Users who are not Admin may enter / change entries of the last … days', controller: back, kb: TextInputType.number, hint: 'empty = no limit'),
          const SizedBox(height: 8),
          TextBox(key: const Key('rule-note'), label: 'Notice shown to everybody at the top (empty = none)', controller: note, maxLines: 2),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _timeBox('rule-day', 'Day shift starts at', day, () => _time(true))),
            const SizedBox(width: 8),
            Expanded(child: _timeBox('rule-night', 'Night shift starts at', night, () => _time(false))),
          ]),
          const SizedBox(height: 12),
          FilledButton(key: const Key('rule-save'), onPressed: busy ? null : _save, child: Text('Save the rules')),
          const SizedBox(height: 12),
          _note('More settings of the site: Company & site and users (Administration); Month close and company details for bills (Billing → Machinery Billing).'),
        ]),
      );

  Widget _timeBox(String key, String label, String v, VoidCallback on) => Press(
        key: Key(key),
        radius: 16,
        shadow: false,
        onTap: on,
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          const Icon(Icons.schedule_rounded, color: C.blue, size: 18),
          const SizedBox(width: 6),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 12, color: C.muted)), Text(v, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))])),
        ]),
      );
}

// =====================================================================================================================
//  ACTIVITY LOG
// =====================================================================================================================
class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});
  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  String from = '', to = '', module = '', action = '', err = '';
  final user = TextEditingController(), q = TextEditingController();
  Map<String, dynamic>? d;
  bool loading = true, started = false;
  int _seq = 0;
  DateTime _typed = DateTime(0);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (started) return;
    started = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    user.dispose();
    q.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final s = SessionScope.read(context), my = ++_seq;
    setState(() => loading = true);
    try {
      final r = ((await s.api.call('getActivity', [
        {'from': from, 'to': to, 'user': user.text.trim(), 'module': module, 'action': action, 'q': q.text.trim()}
      ])) as Map).cast<String, dynamic>();
      if (my != _seq || !mounted) return;
      setState(() {
        d = r;
        loading = false;
        err = '';
      });
    } catch (e) {
      if (my != _seq || !mounted) return;
      setState(() {
        loading = false;
        err = errText(e);
      });
    }
  }

  void _typedLater() {
    final at = _typed = DateTime.now();
    Future<void>.delayed(const Duration(milliseconds: 400), () {
      if (mounted && at == _typed) _load();
    });
  }

  void _range(int back) {
    final t = parseKey(SessionScope.read(context).today.isNotEmpty ? SessionScope.read(context).today : dateKey(DateTime.now()));
    setState(() {
      from = dateKey(t.subtract(Duration(days: back)));
      to = back == 1 ? from : dateKey(t);
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final rows = [for (final r in (d?['rows'] as List? ?? const []).whereType<Map>()) r], count = d?['count'] ?? 0;
    return Scaffold(
      appBar: AppBar(title: const TwoLang('Activity Log', 'ॲक्टिव्हिटी लॉग', size: 20, weight: FontWeight.w700), actions: [IconButton(tooltip: tr('Refresh'), onPressed: _load, icon: const Icon(Icons.refresh_rounded))]),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(key: const Key('act-list'), padding: const EdgeInsets.fromLTRB(14, 10, 14, 30), children: [
          _note('Every sign-in and every add, change, delete and import in the app – who did it, when, and exactly what changed.'),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: DateField(key: const Key('af-from'), label: 'From', value: from, onChanged: (v) {
              setState(() => from = v);
              _load();
            })),
            const SizedBox(width: 8),
            Expanded(child: DateField(key: const Key('af-to'), label: 'To', value: to, onChanged: (v) {
              setState(() => to = v);
              _load();
            })),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(child: PickField(key: const Key('af-module'), label: 'Module', value: module, blank: 'All', items: const ['Master', 'Diesel Inward', 'Diesel Transfer', 'Diesel Issue', 'Log Book', 'Screen Share'], onChanged: (v) {
              setState(() => module = v);
              _load();
            })),
            const SizedBox(width: 8),
            Expanded(child: PickField(key: const Key('af-action'), label: 'Action', value: action, blank: 'All', items: const ['Add', 'Edit', 'Delete', 'Import', 'Login', 'Logout'], onChanged: (v) {
              setState(() => action = v);
              _load();
            })),
          ]),
          const SizedBox(height: 6),
          TextBox(key: const Key('af-user'), label: 'User', controller: user, hint: 'Name or email', onChanged: (_) => _typedLater()),
          const SizedBox(height: 6),
          TextBox(key: const Key('af-q'), label: 'Record / text', controller: q, hint: 'e.g. DI-000123, MH-25-AJ-3232', onChanged: (_) => _typedLater()),
          const SizedBox(height: 4),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              ActionChip(key: const Key('af-today'), label: Text('Today'), onPressed: () => _range(0)),
              const SizedBox(width: 6),
              ActionChip(key: const Key('af-yday'), label: Text('Yesterday'), onPressed: () => _range(1)),
              const SizedBox(width: 6),
              ActionChip(key: const Key('af-7'), label: Text('Last 7 days'), onPressed: () => _range(6)),
              const SizedBox(width: 6),
              ActionChip(key: const Key('af-rtc'), label: Text('Screen share calls'), onPressed: () {
                setState(() => module = 'Screen Share');
                _load();
              }),
              const SizedBox(width: 6),
              ActionChip(
                key: const Key('af-reset'),
                label: Text('Clear filters'),
                onPressed: () {
                  setState(() => from = to = module = action = '');
                  user.clear();
                  q.clear();
                  _load();
                },
              ),
            ]),
          ),
          const SizedBox(height: 6),
          if (d != null) Text('Entries: $count${(count is num ? count : 0) > rows.length ? '  (showing latest ${rows.length})' : ''}', key: const Key('af-sum'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          if (err.isNotEmpty) InfoLine(err, bad: true),
          const SizedBox(height: 8),
          if (loading && d == null) const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator())),
          if (d != null && rows.isEmpty) Padding(padding: const EdgeInsets.all(20), child: Text('No activity matches this filter.', textAlign: TextAlign.center, style: const TextStyle(color: C.muted))),
          for (final r in rows) _row(r),
        ]),
      ),
    );
  }

  Widget _row(Map r) {
    final k = actKind('${r['action']}');
    final col = switch (k) { 'Add' => C.greenDark, 'Edit' => C.blue, 'Delete' || 'fail' => C.red, 'Import' => C.purple, _ => C.slate };
    final bg = switch (k) { 'Add' => C.greenSoft, 'Edit' => C.blueSoft, 'Delete' || 'fail' => C.redSoft, 'Import' => C.purpleSoft, _ => C.slateSoft };
    final lines = changeLines('${r['changes'] ?? ''}');
    return Container(
      key: Key('act-${r['id']}'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Pill('${r['action']}', color: col, bg: bg),
          const SizedBox(width: 8),
          Expanded(child: Text('${r['module']}${'${r['record'] ?? ''}'.isNotEmpty ? ' · ${r['record']}' : ''}', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700))),
        ]),
        const SizedBox(height: 4),
        Text('${r['when']} · ${r['name']}', style: const TextStyle(fontSize: 12.5, color: C.muted)),
        if ('${r['email'] ?? ''}'.isNotEmpty) Text('${r['email']}', style: const TextStyle(fontSize: 12, color: C.faint)),
        if ('${r['summary'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text('${r['summary']}', style: const TextStyle(fontSize: 13.5))),
        for (final l in lines)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: mt.Text.rich(TextSpan(children: [if (l.$1.isNotEmpty) TextSpan(text: '${l.$1}: ', style: const TextStyle(fontWeight: FontWeight.w700)), TextSpan(text: l.$2)]), style: const TextStyle(fontSize: 12.5, color: C.muted)),
          ),
      ]),
    );
  }
}

// =====================================================================================================================
//  SCREEN SHARE – WHO MAY USE IT
// =====================================================================================================================
class RtcScreen extends StatefulWidget {
  const RtcScreen({super.key});
  @override
  State<RtcScreen> createState() => _RtcScreenState();
}

class _RtcScreenState extends State<RtcScreen> {
  List<Map> users = [];
  final on = <String, bool>{};
  String err = '';
  bool busy = false, loading = true, started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (started) return;
    started = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _take(Object? r) {
    users = [for (final u in ((r as Map?)?['users'] as List? ?? const []).whereType<Map>()) u];
    on
      ..clear()
      ..addAll({for (final u in users) '${u['uid']}': u['on'] == true});
  }

  Future<void> _load() async {
    final s = SessionScope.read(context);
    try {
      final r = await s.api.call('rtcRights');
      if (!mounted) return;
      setState(() {
        _take(r);
        loading = false;
        err = '';
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          err = errText(e);
        });
      }
    }
  }

  Future<void> _save() async {
    final s = SessionScope.read(context);
    setState(() => busy = true);
    try {
      final r = await s.api.call('rtcRightsSave', [
        {'off': [for (final u in users) if (u['admin'] != true && on['${u['uid']}'] != true) u['uid']]}
      ], true);
      if (!mounted) return;
      setState(() {
        _take(r);
        busy = false;
      });
      toast(context, 'Screen share access saved.');
    } catch (e) {
      if (!mounted) return;
      setState(() => busy = false);
      toast(context, errText(e), bad: !isSent(e));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const TwoLang('Screen share', 'स्क्रीन शेअर', size: 20, weight: FontWeight.w700)),
        bottomNavigationBar: SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(14, 8, 14, 8), child: FilledButton(key: const Key('rr-save'), onPressed: busy || users.isEmpty ? null : _save, child: Text('Save screen share access')))),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(key: const Key('rr-list'), padding: const EdgeInsets.fromLTRB(14, 10, 14, 30), children: [
                _note('Ticked = may show a screen and be called. Admin users always may. Untick a user and press Save.'),
                if (err.isNotEmpty) InfoLine(err, bad: true),
                if (users.isEmpty && err.isEmpty) Padding(padding: const EdgeInsets.all(20), child: Text('No users.', textAlign: TextAlign.center, style: const TextStyle(color: C.muted))),
                for (final u in users)
                  CheckboxListTile(
                    key: Key('rr-${u['uid']}'),
                    controlAffinity: ListTileControlAffinity.leading,
                    value: u['admin'] == true || on['${u['uid']}'] == true,
                    onChanged: u['admin'] == true ? null : (v) => setState(() => on['${u['uid']}'] = v == true),
                    title: Text('${u['name']}${u['admin'] == true ? ' (Admin)' : ''}'),
                  ),
              ]),
      );
}

// =====================================================================================================================
//  DATABASE CHECK
// =====================================================================================================================
Future<void> showDbCheck(BuildContext context, Session s) async {
  Map? h;
  try {
    h = (await s.api.call('dbHealth')) as Map?;
  } catch (e) {
    if (context.mounted) toast(context, errText(e), bad: true);
    return;
  }
  if (!context.mounted || h == null) return;
  if (h['skipped'] == true) {
    await tellLines(context, 'Database check', ['This site does not run on Supabase – nothing to check.']);
    return;
  }
  final checks = [for (final x in (h['checks'] as List? ?? const []).whereType<Map>()) x], bad = checks.where((x) => x['ok'] != true).length, at = '${h['at'] ?? ''}';
  final again = await showDialog<bool>(
    context: context,
    builder: (dc) => AlertDialog(
      title: Text(bad > 0 ? 'Database: $bad thing(s) to do' : 'Database: every SQL step is in place'),
      scrollable: true,
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final x in checks)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(x['ok'] == true ? '✔ ' : '✗ ', style: TextStyle(fontWeight: FontWeight.w800, color: x['ok'] == true ? C.greenDark : C.red)),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${x['name']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                  if ('${x['note'] ?? ''}'.isNotEmpty) Text('${x['note']}', style: const TextStyle(fontSize: 12, color: C.muted)),
                  Text(x['ok'] == true ? 'in place' : '${x['fix'] ?? ''}'.isNotEmpty ? 'Run: ${x['fix']}' : 'check again', style: TextStyle(fontSize: 12.5, color: x['ok'] == true ? C.greenDark : C.red)),
                ]),
              ),
            ]),
          ),
        if (bad > 0) Text('Where: Supabase → SQL Editor → New query → paste the file → Run. The text of every file is in Administration → Read Me. Every file only adds what is missing and can be run again.', style: const TextStyle(fontSize: 12.5, color: C.muted)),
        const SizedBox(height: 6),
        Text('Checked ${whenText(at)}.', style: const TextStyle(fontSize: 12.5, color: C.muted)),
      ]),
      actions: [
        TextButton(key: const Key('db-again'), onPressed: () => Navigator.pop(dc, true), child: Text('Check again now')),
        FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(110, 46)), onPressed: () => Navigator.pop(dc, false), child: Text('Close')),
      ],
    ),
  );
  if (again == true && context.mounted) await showDbCheck(context, s);
}

// =====================================================================================================================
//  READ ME – the server's guide, drawn with the app's own widgets
// =====================================================================================================================
class ReadMeScreen extends StatefulWidget {
  const ReadMeScreen({super.key});
  @override
  State<ReadMeScreen> createState() => _ReadMeScreenState();
}

class _ReadMeScreenState extends State<ReadMeScreen> {
  HNode? doc;
  List adminCols = [];
  String err = '';
  bool loading = true, started = false;
  final ids = <String, GlobalKey>{};
  final adEmail = TextEditingController(), adName = TextEditingController(), adPw = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (started) return;
    started = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    for (final c in [adEmail, adName, adPw]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final s = SessionScope.read(context);
    setState(() => loading = true);
    try {
      final d = (await s.api.call('readme')) as Map;
      if (!mounted) return;
      setState(() {
        loading = false;
        if (d['missing'] == true) {
          err = 'ReadMe.gs file Apps Script मध्ये नाही. ती paste करा आणि Deploy → New version.';
          doc = null;
        } else {
          err = '';
          doc = parseHtml('${d['html'] ?? ''}');
          adminCols = (d['adminCols'] as List?) ?? const [];
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          err = errText(e);
        });
      }
    }
  }

  GlobalKey _id(String id) => ids.putIfAbsent(id, () => GlobalKey());

  void _go(String id) {
    final c = ids[id]?.currentContext;
    if (c != null) Scrollable.ensureVisible(c, duration: const Duration(milliseconds: 350));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const TwoLang('Read Me', 'रीड मी', size: 20, weight: FontWeight.w700), actions: [IconButton(key: const Key('rm-reload'), tooltip: tr('Refresh'), onPressed: _load, icon: const Icon(Icons.refresh_rounded))]),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                key: const Key('rm-body'),
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 40),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text('Read Me – नवीन site साठी app कसं बनवायचं', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  _note('फक्त Admin ला दिसतं.'),
                  if (err.isNotEmpty) InfoLine(err, bad: true),
                  if (doc != null) ..._blocks(doc!),
                ]),
              ),
      );

  // ---- the page, block by block ----
  List<Widget> _blocks(HNode n) {
    final out = <Widget>[], inline = <HNode>[];
    void flush() {
      if (inline.isEmpty) return;
      final spans = [for (final x in inline) _span(x)];
      if (inline.any((x) => x.plain.trim().isNotEmpty || x.tag == 'input')) out.add(Padding(padding: const EdgeInsets.only(bottom: 6), child: mt.Text.rich(TextSpan(children: spans), style: const TextStyle(fontSize: 14.5, height: 1.4))));
      inline.clear();
    }

    for (final k in n.kids) {
      if (k.tag.isNotEmpty && kBlockTags.contains(k.tag)) {
        flush();
        out.add(_block(k));
      } else if (k.tag == 'input') {
        flush();
        out.add(_input(k));
      } else {
        inline.add(k);
      }
    }
    flush();
    return out;
  }

  Widget _block(HNode n) {
    final id = n.attr('id');
    Widget w;
    switch (n.tag) {
      case 'h1' || 'h2' || 'h3':
        w = Padding(padding: const EdgeInsets.only(top: 16, bottom: 6), child: Text(n.plain.trim(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: C.greenDark)));
      case 'h4' || 'h5' || 'h6' || 'summary':
        w = Padding(padding: const EdgeInsets.only(top: 10, bottom: 4), child: Text(n.plain.trim(), style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)));
      case 'p':
        final warn = n.has('rm-warn');
        w = Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: warn ? const EdgeInsets.all(10) : EdgeInsets.zero,
          decoration: warn ? BoxDecoration(color: C.amberSoft, borderRadius: BorderRadius.circular(12)) : null,
          child: mt.Text.rich(TextSpan(children: [for (final k in n.kids) _span(k)]), style: const TextStyle(fontSize: 14.5, height: 1.4)),
        );
      case 'ul' || 'ol':
        var i = 0;
        w = Padding(
          padding: const EdgeInsets.only(bottom: 8, left: 4),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (final li in n.kids.where((k) => k.tag == 'li'))
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(width: 24, child: Text(n.tag == 'ol' ? '${++i}.' : '•', style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700))),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: _blocks(li))),
                ]),
              ),
          ]),
        );
      case 'table':
        final rows = n.all().where((x) => x.tag == 'tr').toList();
        w = Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(border: Border.all(color: C.line), borderRadius: BorderRadius.circular(12)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (var r = 0; r < rows.length; r++)
              Container(
                color: rows[r].kids.any((c) => c.tag == 'th') ? C.slateSoft : (r.isEven ? Colors.white : const Color(0xFFFAFBFA)),
                padding: const EdgeInsets.all(8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  for (final c in rows[r].kids.where((c) => c.tag == 'td' || c.tag == 'th'))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: c.tag == 'th' ? [Text(c.plain.trim(), style: const TextStyle(fontWeight: FontWeight.w800))] : _blocks(c)),
                    ),
                ]),
              ),
          ]),
        );
      case 'pre':
        final text = id == 'rm_sql_admin' ? adminSql(adminCols, email: adEmail.text, name: adName.text, pw: adPw.text) : n.plain;
        w = Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(color: const Color(0xFF1E272E), borderRadius: BorderRadius.circular(12)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                key: Key('rm-copy-$id'),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: text));
                  if (mounted) toast(context, 'Copied ✓');
                },
                icon: const Icon(Icons.copy_rounded, color: Colors.white, size: 18),
                label: Text('Copy', style: const TextStyle(color: Colors.white)),
              ),
            ),
            SizedBox(
              height: text.split('\n').length > 18 ? 320 : null,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: SelectableText(text, style: const TextStyle(fontFamily: 'monospace', fontSize: 11.5, color: Color(0xFFE8F0E8), height: 1.35))),
              ),
            ),
          ]),
        );
      case 'details':
        final sum = n.kids.where((k) => k.tag == 'summary').firstOrNull;
        w = Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(sum?.plain.trim() ?? 'More', style: const TextStyle(fontWeight: FontWeight.w700)),
            children: _blocks(HNode('div')..kids.addAll(n.kids.where((k) => k.tag != 'summary'))),
          ),
        );
      case 'label':
        w = Padding(padding: const EdgeInsets.only(bottom: 8), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: _blocks(n)));
      default: // div, section, li, td …
        if (n.has('rm-toc')) {
          w = Wrap(spacing: 6, runSpacing: 6, children: [
            for (final a in n.kids.where((k) => k.tag == 'a')) ActionChip(label: Text(a.plain.trim(), style: const TextStyle(fontSize: 12.5)), onPressed: () => _go(a.attr('data-rmgo').isNotEmpty ? a.attr('data-rmgo') : a.attr('href').replaceFirst('#', ''))),
          ]);
        } else if (n.has('rm-step')) {
          final nb = n.kids.where((k) => k.has('rm-n')).firstOrNull, body = n.kids.where((k) => k.has('rm-sb')).firstOrNull;
          w = _card(
            margin: const EdgeInsets.only(bottom: 10),
            radius: 14,
            Padding(
            padding: const EdgeInsets.all(10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              CircleAvatar(radius: 14, backgroundColor: C.green, child: Text(nb?.plain.trim() ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13))),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: body == null ? const [] : _blocks(body))),
            ]),
            ),
          );
        } else if (n.has('rm-code')) {
          w = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [for (final k in n.kids.where((k) => k.tag == 'pre')) _block(k)]);
        } else {
          w = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: _blocks(n));
        }
    }
    return id.isEmpty ? w : KeyedSubtree(key: _id(id), child: w);
  }

  Widget _input(HNode n) {
    final id = n.attr('id');
    final c = id == 'rm_ad_email' ? adEmail : id == 'rm_ad_name' ? adName : id == 'rm_ad_pw' ? adPw : null;
    if (c == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 2),
      child: TextField(key: Key('rm-in-$id'), controller: c, onChanged: (_) => setState(() {}), decoration: InputDecoration(isDense: true, hintText: n.attr('placeholder'))),
    );
  }

  InlineSpan _span(HNode n) {
    if (n.tag.isEmpty) return TextSpan(text: n.text.replaceAll(RegExp(r'\s+'), ' '));
    if (n.tag == 'br') return const TextSpan(text: '\n');
    if (n.tag == 'input') return WidgetSpan(child: SizedBox(width: double.infinity, child: _input(n)));
    if (n.tag == 'button') return const TextSpan(text: '');
    final kids = [for (final k in n.kids) _span(k)];
    TextStyle? st;
    switch (n.tag) {
      case 'b' || 'strong':
        st = const TextStyle(fontWeight: FontWeight.w800);
      case 'i' || 'em':
        st = const TextStyle(fontStyle: FontStyle.italic);
      case 'code':
        st = const TextStyle(fontFamily: 'monospace', backgroundColor: Color(0xFFEEF1F5), fontSize: 13);
      case 'small':
        st = const TextStyle(fontSize: 12.5, color: C.muted);
      case 'a':
        st = const TextStyle(color: C.blue, fontWeight: FontWeight.w600);
      case 'span':
        st = n.has('rm-ok') ? const TextStyle(color: C.greenDark, fontWeight: FontWeight.w700) : n.has('rm-bad') ? const TextStyle(color: C.red, fontWeight: FontWeight.w700) : n.has('rm-new') ? const TextStyle(color: C.amber, fontWeight: FontWeight.w700) : null;
    }
    return TextSpan(style: st, children: kids);
  }
}

// =====================================================================================================================
//  (3.14.0) FAULTS OF THE APP and THE GOOGLE SHEET BACKUP – the web's two pills at the top (Admin)
// =====================================================================================================================

/// The web's dtFull: "16/10/2026, 09:05:03 am" on the phone's clock ('–' = no time).
String dtFull(Object? iso) {
  final t = DateTime.tryParse('${iso ?? ''}')?.toLocal();
  if (t == null) return '–';
  String two(int v) => v.toString().padLeft(2, '0');
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return '${two(t.day)}/${two(t.month)}/${t.year}, ${two(h)}:${two(t.minute)}:${two(t.second)} ${t.hour < 12 ? 'am' : 'pm'}';
}

/// "Faults today: N – last: …" (the web's pill and its title).
String faultsLine(Map f, String today) {
  final n = (f['day'] == today ? (f['n'] as num?) : 0) ?? 0;
  if (n == 0) return 'No fault reported today';
  return 'Faults today: $n${'${f['last'] ?? ''}'.isNotEmpty ? ' – last: ${f['last']}' : ''}';
}

/// The backup's state as the web's pill says it.
String backupLine(Map b) {
  if (b.isEmpty) return 'Runs by itself – press to check now';
  if (b['ok'] == false) return 'Backup problem: ${b['error'] ?? ''} – press to try now';
  final t = b['lastCheck'] ?? b['lastRun'];
  return 'Checked ${dtFull(t)}.${(b['pending'] ?? 0) is num && (b['pending'] as num) > 0 ? ' ${b['pending']} table(s) are still being copied.' : ''}';
}

/// The web's Backup button (Admin): backupNow, then what it did.
Future<void> runBackup(BuildContext context, Session s) async {
  Map r;
  try {
    r = (await s.api.call('backupNow', const [], true)) as Map;
  } catch (e) {
    if (context.mounted) toast(context, errText(e), bad: true);
    return;
  }
  final info = r['info'] is Map ? (r['info'] as Map).cast<String, dynamic>() : s.backup;
  s.backup = info;
  final lines = <String>[
    if (r['off'] == true)
      'Backup is not set up in this app.'
    else if (r['busy'] == true)
      'The automatic backup is running right now. Try again in a minute.'
    else if (r['upToDate'] == true) ...[
      'Backup is up to date. Everything saved in Supabase is already in the Google Sheet.',
      'Newest change copied: ${dtFull(info['lastChangeCopied'])}',
    ] else if (r['full'] == true)
      'Full backup done. Every table was copied to the Google Sheet.'
    else ...[
      'New data copied to the Google Sheet now.',
      for (final x in (r['lines'] as List? ?? const [])) if (x is List && x.length > 1) '${x[0]}: ${x[1]}',
      if ((r['pending'] ?? 0) is num && (r['pending'] as num) > 0)
        '${r['pending']} table(s) are still to be copied – one run may take about half a minute; the rest goes on by itself in a few minutes (or press Backup again).',
    ],
  ];
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text('Backup to Google Sheet'),
      scrollable: true,
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final l in lines) Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(l, style: const TextStyle(fontSize: 14.5, height: 1.35))),
        if ('${info['url'] ?? ''}'.isNotEmpty)
          TextButton.icon(key: const Key('bk-open'), onPressed: () => launchUrl(Uri.parse('${info['url']}'), mode: LaunchMode.externalApplication), icon: const Icon(Icons.open_in_new_rounded), label: Text('Open the backup Google Sheet')),
      ]),
      actions: [FilledButton(key: const Key('tell-ok'), onPressed: () => Navigator.pop(c), child: const mt.Text('OK'))],
    ),
  );
}

class FaultsScreen extends StatefulWidget {
  const FaultsScreen({super.key});
  @override
  State<FaultsScreen> createState() => _FaultsScreenState();
}

class _FaultsScreenState extends State<FaultsScreen> {
  List<Map> list = [];
  bool loading = true;
  String err = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final s = SessionScope.read(context);
    try {
      final d = (await s.api.call('getErrors')) as Map;
      if (d['stamp'] is Map) s.faults = (d['stamp'] as Map).cast<String, dynamic>();
      if (mounted) {
        setState(() {
          list = [for (final x in (d['errors'] as List? ?? const [])) if (x is Map) x];
          loading = false;
          err = '';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          err = errText(e);
        });
      }
    }
  }

  Future<void> _empty() async {
    final s = SessionScope.read(context);
    if (!await ask(context, 'Empty the list of faults?', 'The ${list.length} faults are removed from the list.', yes: 'Empty', danger: true)) return;
    try {
      await s.api.call('clearErrors', const [], true);
      s.faults = {'day': s.today, 'n': 0, 'at': '', 'last': ''};
      if (!mounted) return;
      toast(context, 'The list of faults is empty.');
      setState(() => list = []);
    } catch (e) {
      if (mounted) toast(context, errText(e), bad: true);
    }
  }

  static String _when(Object? at) {
    final t = DateTime.tryParse('${at ?? ''}')?.toLocal();
    if (t == null) return '';
    const mon = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(t.day)} ${mon[t.month - 1]}, ${two(t.hour)}:${two(t.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('Faults of the app – ${list.length} kept, ${(s.faults['day'] == s.today ? s.faults['n'] : 0) ?? 0} today', style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700))),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(key: const Key('flt-list'), padding: const EdgeInsets.fromLTRB(14, 10, 14, 30), children: [
                if (err.isNotEmpty) InfoLine(err, bad: true),
                if (list.isEmpty && err.isEmpty) const EmptyState('No fault has been reported.', '', pic: 'shield'),
                if (list.isNotEmpty) ...[
                  _note('Written down by the app itself. "on the page" = in a user\'s browser or phone; "on the server" = while the server did the action named under Where; "database" = the database did not answer. The same fault is written once in 10 minutes.'),
                  const SizedBox(height: 10),
                  for (final x in list.take(60))
                    _card(
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${x['msg'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 3),
                          Text([_when(x['at']), '${x['by'] ?? ''}', x['kind'] == 'page' ? 'on the page' : x['kind'] == 'database' ? 'database' : 'on the server', '${x['where'] ?? ''}'].where((v) => v.isNotEmpty).join(' · '),
                              style: const TextStyle(fontSize: 12.5, color: C.muted)),
                          if ('${x['detail'] ?? ''}'.isNotEmpty)
                            Theme(
                              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                              child: ExpansionTile(
                                tilePadding: EdgeInsets.zero,
                                title: Text('details', style: const TextStyle(fontSize: 13)),
                                children: [SelectableText('${x['detail']}', style: const TextStyle(fontSize: 11.5))],
                              ),
                            ),
                        ]),
                      ),
                    ),
                  const SizedBox(height: 6),
                  OutlinedButton.icon(key: const Key('flt-empty'), style: _small, onPressed: _empty, icon: const Icon(Icons.delete_sweep_outlined), label: Text('Empty the list')),
                  _note('– after the faults have been looked at'),
                ],
              ]),
            ),
    );
  }
}
