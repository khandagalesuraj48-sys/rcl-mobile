/* SUPER ADMIN – THE WHOLE SYSTEM (3.17.0): the Portal's own console (the Portal page's "Super Admin", api/admin) in the app's own
 * screens, for the Super Admin only – the same actions, the same checks (the Portal's server does them all), the same words:
 *   – Users & Access: one site at a time – every user with, for every module, No access / User / Admin; a user added (with a
 *     one-time password – at his first sign-in he sets his own), switched off, given a new one-time password; his pages in
 *     Mechanical (Edit / View / No access, kept in Mechanical) and in the Store;
 *   – Sites: name, company, Active / Closed; New site (the checklist the system works through, again and again until Ready – the
 *     SQL copied, the Supabase links); Diesel places (name and tank size); a Closed site deleted with its code typed again (its
 *     data stays in its own database);
 *   – Companies (name, GSTIN, PAN, address, logo) – one no site belongs to can be deleted;
 *   – Modules (name, link, Live / Off) – one that is Off can be deleted with its key typed again (not Mechanical);
 *   – Activity: sign-ins, users, access, sites, companies, modules – the last 200.
 * His own password: My settings → Change password (the same Portal action as the Portal's "My account"). */
import 'dart:convert';

import 'package:flutter/material.dart' hide Text;
import 'package:flutter/material.dart' as mt show Text;
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../ui/fields.dart';
import '../ui/scope.dart';
import '../ui/t.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import '../ui/ask_bot.dart';

Future<void> openSuperAdmin(BuildContext context) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SuperAdminScreen()));

/// The Marathi line for the Portal's answers people meet most (the Portal page's MR).
const kPortalMr = {
  'nostep': 'यासाठी Portal च्या Supabase मध्ये sql/portal_step2_start.sql एकदा चालवावा लागेल.',
  'wrong': 'Email किंवा password चुकीचा आहे.',
  'locked': 'खूप चुकीचे प्रयत्न झाले – 15 मिनिटांनी पुन्हा प्रयत्न करा.',
  'busy': 'खूप जण एकदम sign in करत आहेत – एक मिनिट थांबा.',
  'policy': 'Password किमान 8 अक्षरांचा, अक्षरे आणि अंक दोन्ही असलेला हवा.',
  'oldpw': 'सध्याचा password चुकीचा आहे.',
  'recovery': 'Email किंवा recovery code चुकीचा आहे.',
  'session': 'तुमचा login संपला आहे – पुन्हा sign in करा.',
};

/// The Portal's msgOf: its words, and the Marathi line when it has one.
String portalMsg(Object e) {
  if (e is! ApiError) return errText(e);
  final mr = kPortalMr[e.code == 'signin' ? 'session' : e.code];
  return '${e.message}${mr != null ? ' · $mr' : ''}';
}

const kRoleWord = {'': 'No access', 'user': 'User', 'admin': 'Admin'};
/// (3.55.0, the Store's step 2) as the Portal's note under the Store's pages – (3.62.0, the Store's step 5) and "Approves purchase orders"
const kStoreExtraNote = 'Approves requirements: Level 1 approves first, then Level 2 … (any one person of a level; nobody his own; he sees the Requirements to approve them). Store Purchase: makes the purchase orders of every site. Approves purchase orders: a PO of this site is taken in (GRN) only after one of them approves it (never his own) – his name goes on the PO as "Approved By"; nobody given – a PO is approved when made.';
const kPageWord = {'Admin': 'Admin', 'Edit': 'Edit', 'View': 'View', 'None': 'No access', 'L1': 'Level 1', 'L2': 'Level 2', 'L3': 'Level 3', 'L4': 'Level 4', 'L5': 'Level 5', 'Yes': 'Yes'};

/// The Portal's fail(): his sign-in ended – the sign-in screen, with the Marathi line; else false.
bool portalSignInEnded(BuildContext context, Object e) {
  if (e is! ApiError || !(e.needsSignIn || e.status == 401 || e.code == 'session')) return false;
  final s = SessionScope.read(context);
  // (a message still on the screen would be drawn on both the app and the sign-in while one turns into the other)
  ScaffoldMessenger.maybeOf(context)
    ?..clearSnackBars()
    ..removeCurrentSnackBar(); // at once – not with its closing animation
  Navigator.of(context, rootNavigator: true).popUntil((r) => r.isFirst);
  s.signOut(kPortalMr['session']!);
  return true;
}

/// What the console works on (the Portal's overview), loaded again after every save.
class SaData {
  SaData(Map<String, dynamic> d)
      : users = _l(d['users']),
        sites = _l(d['sites']),
        modules = _l(d['modules']),
        companies = _l(d['companies']),
        access = _l(d['access']),
        storePages = _l(d['storePages']);
  static List<Map<String, dynamic>> _l(Object? v) => [for (final x in (v is List ? v : const [])) if (x is Map) x.cast<String, dynamic>()];
  final List<Map<String, dynamic>> users, sites, modules, companies, access, storePages;

  String roleOf(String email, String site, String module) =>
      '${access.firstWhere((a) => a['email'] == email && a['site'] == site && a['module'] == module, orElse: () => const {})['role'] ?? ''}';
  Map<String, dynamic>? accessOf(String email, String site, String module) => access.where((a) => a['email'] == email && a['site'] == site && a['module'] == module).firstOrNull;
  Map<String, dynamic>? user(String email) => users.where((u) => u['email'] == email).firstOrNull;
  String siteName(String code) => '${sites.where((s) => s['code'] == code).firstOrNull?['name'] ?? code}';
  String companyName(Object? id) => '${companies.where((c) => c['id'] == id).firstOrNull?['name'] ?? ''}';
}

class SuperAdminScreen extends StatefulWidget {
  const SuperAdminScreen({super.key});
  @override
  State<SuperAdminScreen> createState() => SuperAdminState();
}

class SuperAdminState extends State<SuperAdminScreen> {
  SaData? d;
  String err = '', site = '', mod = '';
  bool started = false;
  List<Map<String, dynamic>>? audit;
  String auditErr = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (started) return;
    started = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => load());
  }

  Api get api => SessionScope.read(context).api;

  Future<void> load() async {
    try {
      final r = await api.admin({'action': 'overview'});
      if (!mounted) return;
      setState(() {
        d = SaData(r);
        err = '';
        site = d!.sites.any((s) => s['code'] == site) ? site : '${d!.sites.firstOrNull?['code'] ?? ''}';
        mod = d!.modules.any((m) => m['key'] == mod) ? mod : '';
      });
    } catch (e) {
      if (!mounted || portalSignInEnded(context, e)) return;
      setState(() => err = portalMsg(e));
    }
  }

  bool auditBusy = false;
  Future<void> loadAudit() async {
    if (auditBusy) return;
    auditBusy = true;
    setState(() {
      audit = null;
      auditErr = '';
    });
    try {
      final r = await api.admin({'action': 'audit'});
      if (mounted) setState(() => audit = SaData._l(r['rows']));
    } catch (e) {
      if (mounted && !portalSignInEnded(context, e)) setState(() => auditErr = portalMsg(e));
    } finally {
      auditBusy = false;
    }
  }

  void say(String t, {bool bad = false}) {
    if (mounted) toast(context, t, bad: bad);
  }

  /// An error in the Portal's words (its sign-in ended: the sign-in screen).
  void failed(Object e) {
    if (mounted && !portalSignInEnded(context, e)) say(portalMsg(e), bad: true);
  }

  /// A save: the Portal's answer, then the overview again; an error in the Portal's words.
  Future<bool> run(Future<void> Function() fn) async {
    try {
      await fn();
    } catch (e) {
      failed(e);
      await load();
      return false;
    }
    await load();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const TwoLang('Super Admin', 'सुपर ॲडमिन', size: 20, weight: FontWeight.w700),
          actions: withAsk([IconButton(key: const Key('sa-reload'), tooltip: tr('Refresh'), onPressed: load, icon: const Icon(Icons.refresh_rounded))]),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
            onTap: (i) {
              if (i == 4 && audit == null) loadAudit();
            },
            tabs: [
              Tab(key: const Key('sa-t-users'), text: tr('Users & Access')),
              Tab(key: const Key('sa-t-sites'), text: tr('Sites')),
              Tab(key: const Key('sa-t-companies'), text: tr('Companies')),
              Tab(key: const Key('sa-t-modules'), text: tr('Modules')),
              Tab(key: const Key('sa-t-audit'), text: tr('Activity')),
            ],
          ),
        ),
        body: d == null
            ? (err.isEmpty ? const Center(child: CircularProgressIndicator()) : ListView(padding: const EdgeInsets.all(16), children: [InfoLine(err, bad: true)]))
            : TabBarView(children: [_users(), _sites(), _companies(), _modules(), _audit()]),
      ),
    );
  }

  Widget _note(String t) => Padding(padding: const EdgeInsets.fromLTRB(2, 0, 2, 10), child: Text(t, style: const TextStyle(fontSize: 13, color: C.muted, height: 1.35)));

  Widget _card({required Widget child, VoidCallback? onTap, Key? key, Color color = Colors.white}) => Padding(
        key: key,
        padding: const EdgeInsets.only(bottom: 10),
        child: Press(onTap: onTap, color: color, padding: const EdgeInsets.fromLTRB(14, 12, 12, 12), child: child),
      );

  Widget _chip(String t, Color c, Color bg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
        child: Text(t, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: c)),
      );

  Widget _role(String r) => switch (r) {
        'admin' => _chip('Admin', C.purple, C.purpleSoft),
        'user' => _chip('User', C.greenDark, C.greenSoft),
        _ => _chip('No access', C.faint, C.slateSoft),
      };

  /* ---------------- Users & Access ---------------- */
  List<Map<String, dynamic>> get _mods => [for (final m in d!.modules) if (mod.isEmpty || m['key'] == mod) m];

  Widget _users() {
    final x = d!, people = x.users.where((u) => u['super'] != true).toList();
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(key: const Key('sa-users'), padding: const EdgeInsets.fromLTRB(16, 12, 16, 30), children: [
        _note('Pick a site: for every user, which module he may open there – Admin, User or No access. Access is separate on every site. Switched off = cannot sign in.'),
        Row(children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              key: ValueKey('sa-site|$site'),
              initialValue: x.sites.any((s) => s['code'] == site) ? site : null,
              isExpanded: true,
              decoration: InputDecoration(labelText: tr('Site')),
              hint: const Text('– no site yet –'),
              items: [for (final s in x.sites) DropdownMenuItem(value: '${s['code']}', child: mt.Text('${s['name']} (${s['code']})${s['status'] == 'closed' ? ' – closed' : ''}', maxLines: 1, overflow: TextOverflow.ellipsis))],
              onChanged: (v) => setState(() => site = v ?? ''),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: DropdownButtonFormField<String>(
              key: ValueKey('sa-mod|$mod'),
              initialValue: mod,
              isExpanded: true,
              decoration: InputDecoration(labelText: tr('Module')),
              items: [
                DropdownMenuItem(value: '', child: Text('All modules')),
                for (final m in x.modules) DropdownMenuItem(value: '${m['key']}', child: mt.Text('${m['name']}${m['status'] != 'live' ? ' – off' : ''}', maxLines: 1, overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (v) => setState(() => mod = v ?? ''),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: Text('${people.length} users · ${people.where((u) => u['active'] == true).length} active', style: const TextStyle(fontSize: 13.5, color: C.muted, fontWeight: FontWeight.w600))),
          FilledButton(
            key: const Key('sa-u-new'),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: () => _user(null),
            child: const Text('+ Add user'),
          ),
        ]),
        const SizedBox(height: 10),
        for (final u in people)
          _card(
            key: Key('sa-u-${u['email']}'),
            color: u['active'] == true ? Colors.white : C.slateSoft,
            onTap: () => _user(u),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: mt.Text('${u['name']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
                if (u['active'] != true) _chip('Switched off', C.red, C.redSoft),
              ]),
              mt.Text('${u['email']}${u['mustChange'] == true ? ' · must set password' : ''}${u['noPassword'] == true ? ' · no password yet' : ''}',
                  style: const TextStyle(fontSize: 13, color: C.muted)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 6, children: [
                for (final m in _mods)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    mt.Text('${m['name']}: ', style: const TextStyle(fontSize: 13, color: C.muted)),
                    _role(x.roleOf('${u['email']}', site, '${m['key']}')),
                  ]),
              ]),
            ]),
          ),
        _note('A new user gets a one-time password: at his first sign-in he sets his own. A new one-time password ends his sign-ins.'),
      ]),
    );
  }

  Future<void> _user(Map<String, dynamic>? u) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SaUserScreen(console: this, user: u, site: site, mods: _mods)));
  }

  /* ---------------- Sites ---------------- */
  Widget _sites() {
    final x = d!;
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(key: const Key('sa-sites'), padding: const EdgeInsets.fromLTRB(16, 12, 16, 30), children: [
        _note('Every site of every module. Closed = switched off: nobody can open it. A closed site can be deleted – its data stays in its own database.'),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton(
            key: const Key('sa-st-new'),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: () => _newSite(),
            child: const Text('+ New site'),
          ),
        ),
        const SizedBox(height: 12),
        if (x.sites.isEmpty) _note('No site yet.'),
        for (final s in x.sites)
          _card(
            key: Key('sa-st-${s['code']}'),
            color: s['status'] == 'closed' ? C.slateSoft : Colors.white,
            onTap: () => _site(s),
            child: Row(children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: C.greenSoft, borderRadius: BorderRadius.circular(14)),
                child: mt.Text('${s['code']}', style: const TextStyle(fontWeight: FontWeight.w800, color: C.greenDark)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  mt.Text('${s['name']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  mt.Text(x.companyName(s['company_id']).isEmpty ? '–' : x.companyName(s['company_id']), style: const TextStyle(fontSize: 13, color: C.muted)),
                ]),
              ),
              s['status'] == 'closed' ? _chip('Closed', C.red, C.redSoft) : _chip('Active', C.greenDark, C.greenSoft),
            ]),
          ),
      ]),
    );
  }

  Future<void> _site(Map<String, dynamic> s) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SaSiteScreen(console: this, site: s)));

  Future<void> _newSite({Map<String, dynamic>? site}) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SaNewSiteScreen(console: this, site: site)));

  /* ---------------- Companies ---------------- */
  Widget _companies() {
    final x = d!;
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(key: const Key('sa-companies'), padding: const EdgeInsets.fromLTRB(16, 12, 16, 30), children: [
        _note('The companies a site belongs to.'),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            key: const Key('sa-co-new'),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: () => _company(null),
            icon: const Icon(Icons.add_business_rounded),
            label: const Text('Add a company'),
          ),
        ),
        const SizedBox(height: 12),
        if (x.companies.isEmpty) _note('No company yet – add Rachana and Sketchline below.'),
        for (final c in x.companies)
          Builder(builder: (_) {
            final used = [for (final s in x.sites) if (s['company_id'] == c['id']) '${s['code']}'];
            return _card(
              key: Key('sa-co-${c['id']}'),
              onTap: () => _company(c),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                mt.Text('${c['name']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                InfoRow('GSTIN', '${c['gstin'] ?? ''}'),
                InfoRow('PAN', '${c['pan'] ?? ''}'),
                InfoRow('Address', '${c['address'] ?? ''}'),
                InfoRow('Logo', '${c['logo'] ?? ''}'.isNotEmpty ? 'Yes' : ''),
                InfoRow('Sites', used.join(', ')),
              ]),
            );
          }),
      ]),
    );
  }

  Future<void> _company(Map<String, dynamic>? c) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SaCompanyScreen(console: this, company: c)));

  /* ---------------- Modules ---------------- */
  Widget _modules() {
    final x = d!;
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(key: const Key('sa-modules'), padding: const EdgeInsets.fromLTRB(16, 12, 16, 30), children: [
        _note('A module shows on the dashboard only when it is Live and has its link. A module that is Off can be deleted (not Mechanical).'),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton(
            key: const Key('sa-m-new'),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: () => _module(null),
            child: const Text('+ Add module'),
          ),
        ),
        const SizedBox(height: 12),
        for (final m in x.modules)
          _card(
            key: Key('sa-m-${m['key']}'),
            onTap: () => _module(m),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  mt.Text('${m['name']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  mt.Text('${m['key']} · ${'${m['url'] ?? ''}'.isEmpty ? 'no link' : m['url']}', style: const TextStyle(fontSize: 13, color: C.muted)),
                ]),
              ),
              m['status'] == 'live' ? _chip('Live', C.greenDark, C.greenSoft) : _chip('Off', C.red, C.redSoft),
            ]),
          ),
      ]),
    );
  }

  Future<void> _module(Map<String, dynamic>? m) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SaModuleScreen(console: this, module: m)));

  /* ---------------- Activity ---------------- */
  Widget _audit() {
    final rows = audit;
    return RefreshIndicator(
      onRefresh: loadAudit,
      child: ListView(key: const Key('sa-audit'), padding: const EdgeInsets.fromLTRB(16, 12, 16, 30), children: [
        _note('Sign-ins, users, access, sites, companies, modules – the last 200.'),
        if (auditErr.isNotEmpty) InfoLine(auditErr, bad: true),
        if (rows == null && auditErr.isEmpty)
          Builder(builder: (_) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && audit == null && auditErr.isEmpty) loadAudit();
            });
            return const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator()));
          }),
        if (rows != null && rows.isEmpty) _note('Nothing yet.'),
        for (final x in rows ?? const <Map<String, dynamic>>[])
          _card(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: mt.Text('${x['action']}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
                mt.Text(whenText('${x['at'] ?? ''}'), style: const TextStyle(fontSize: 12.5, color: C.muted)),
              ]),
              mt.Text('${x['actor']}${'${x['target'] ?? ''}'.isNotEmpty ? ' → ${x['target']}' : ''}', style: const TextStyle(fontSize: 13.5, color: C.ink)),
              if (x['detail'] != null) mt.Text(jsonEncode(x['detail']), style: const TextStyle(fontSize: 12, color: C.muted)),
            ]),
          ),
      ]),
    );
  }
}

/* ======================================== one user ======================================== */
class SaUserScreen extends StatefulWidget {
  const SaUserScreen({super.key, required this.console, required this.user, required this.site, required this.mods});
  final SuperAdminState console;
  final Map<String, dynamic>? user;
  final String site;
  final List<Map<String, dynamic>> mods;
  @override
  State<SaUserScreen> createState() => _SaUserScreenState();
}

class _SaUserScreenState extends State<SaUserScreen> {
  final email = TextEditingController(), name = TextEditingController(), pw = TextEditingController();
  bool active = true, busy = false;
  final roles = <String, String>{};
  bool get isNew => widget.user == null;
  SaData get d => widget.console.d!;
  String get mail => isNew ? email.text.trim().toLowerCase() : '${widget.user!['email']}';

  @override
  void initState() {
    super.initState();
    active = widget.user?['active'] != false;
    for (final m in widget.mods) {
      roles['${m['key']}'] = isNew ? '' : d.roleOf(mail, widget.site, '${m['key']}');
    }
  }

  Future<void> _save() async {
    final c = widget.console, api = c.api, site = widget.site, e = mail;
    setState(() => busy = true);
    final cur = d.user(e) ?? const {};
    var warn = '';
    final ok = await c.run(() async {
      await api.admin({'action': 'userSave', 'isNew': isNew, 'email': e, 'name': isNew ? name.text : cur['name'], 'active': active, 'newPassword': pw.text});
      for (final m in widget.mods) {
        final k = '${m['key']}', was = d.roleOf(e, site, k);
        if (site.isNotEmpty && roles[k] != was) {
          final r = await api.admin({'action': 'accessSet', 'email': e, 'site': site, 'module': k, 'role': roles[k]});
          if ('${r['warn'] ?? ''}'.isNotEmpty) warn = '${r['warn']}'; // (3.55.0) the Store not told who approves – said
        }
      }
    });
    if (!mounted) return;
    setState(() => busy = false);
    if (!ok) return;
    c.say(warn.isNotEmpty ? warn : '${isNew ? 'User added: ' : 'Saved: '}$e${pw.text.isNotEmpty ? ' – tell him the one-time password.' : ''}');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.user, site = widget.site;
    return Scaffold(
      appBar: AppBar(actions: withAsk(), title: mt.Text(isNew ? tr('+ Add user') : '${u!['name']}', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700))),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
          child: FilledButton(key: const Key('sa-u-save'), onPressed: busy ? null : _save, child: Text(busy ? 'Saving…' : (isNew ? 'Add' : 'Save'))),
        ),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 30), children: [
        if (isNew) ...[
          TextField(key: const Key('sa-u-email'), controller: email, keyboardType: TextInputType.emailAddress, decoration: InputDecoration(labelText: tr('Email'), hintText: 'email')),
          const SizedBox(height: 10),
          TextField(key: const Key('sa-u-name'), controller: name, decoration: InputDecoration(labelText: tr('Name'), hintText: 'name')),
        ] else ...[
          mt.Text('${u!['email']}', style: const TextStyle(fontSize: 15, color: C.muted)),
          if (u['mustChange'] == true || u['noPassword'] == true)
            Text(u['noPassword'] == true ? 'No password yet' : 'Must set password', style: const TextStyle(fontSize: 13.5, color: C.amber, fontWeight: FontWeight.w600)),
        ],
        const SizedBox(height: 6),
        SwitchListTile(
          key: const Key('sa-u-active'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Active'),
          subtitle: const Text('Switched off = cannot sign in.'),
          value: active,
          onChanged: (v) => setState(() => active = v),
        ),
        TextField(
          key: const Key('sa-u-pw'),
          controller: pw,
          autofillHints: const [AutofillHints.newPassword],
          decoration: InputDecoration(labelText: tr('One-time password'), hintText: isNew ? 'one-time password' : 'new one-time password'),
        ),
        FormHead('Access on ${d.siteName(site)} ($site)', sub: 'Access is separate on every site.'),
        if (site.isEmpty) const Text('– no site yet –', style: TextStyle(color: C.muted)),
        for (final m in widget.mods) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 6),
            child: mt.Text('${m['name']}${m['status'] != 'live' ? ' – off' : ''}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
          SegmentedButton<String>(
            key: Key('sa-role-${m['key']}'),
            showSelectedIcon: false,
            segments: [for (final r in const ['', 'user', 'admin']) ButtonSegment(value: r, label: Text(kRoleWord[r]!))],
            selected: {roles['${m['key']}'] ?? ''},
            onSelectionChanged: site.isEmpty ? null : (v) => setState(() => roles['${m['key']}'] = v.first),
          ),
          // his pages – once he has the module on this site (as the Portal page: after the access is saved)
          if (!isNew && (m['key'] == 'mechanical' || m['key'] == 'store') && d.roleOf(mail, site, '${m['key']}').isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: Key('sa-pages-${m['key']}'),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => m['key'] == 'mechanical' ? SaMechPagesScreen(console: widget.console, site: site, email: mail) : SaStorePagesScreen(console: widget.console, site: site, email: mail))),
                icon: const Icon(Icons.tune_rounded),
                label: const Text('Pages'),
              ),
            ),
        ],
        const SizedBox(height: 12),
        const Text('A new user gets a one-time password: at his first sign-in he sets his own. A new one-time password ends his sign-ins.', style: TextStyle(fontSize: 13, color: C.muted)),
      ]),
    );
  }
}

/* ======================================== his pages ======================================== */
class SaMechPagesScreen extends StatefulWidget {
  const SaMechPagesScreen({super.key, required this.console, required this.site, required this.email});
  final SuperAdminState console;
  final String site, email;
  @override
  State<SaMechPagesScreen> createState() => _SaMechPagesScreenState();
}

class _SaMechPagesScreenState extends State<SaMechPagesScreen> {
  List<Map<String, dynamic>>? pages;
  Map<String, dynamic>? mu;
  final perms = <String, String>{};
  String err = '';
  bool busy = false, started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (started) return;
    started = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final r = await widget.console.api.admin({'action': 'mechPages', 'site': widget.site});
      if (!mounted) return;
      setState(() {
        pages = SaData._l(r['pages']);
        mu = SaData._l(r['users']).where((x) => x['email'] == widget.email).firstOrNull;
        final p = mu?['perms'] is Map ? (mu!['perms'] as Map) : const {};
        for (final x in pages!) {
          perms['${x['key']}'] = jsTruthy(p[x['key']]) ? '${p[x['key']]}' : 'None';
        }
      });
    } catch (e) {
      if (mounted && !portalSignInEnded(context, e)) setState(() => err = portalMsg(e));
    }
  }

  Future<void> _save() async {
    setState(() => busy = true);
    try {
      final r = await widget.console.api.admin({'action': 'mechPagesSave', 'site': widget.site, 'email': widget.email, 'perms': perms});
      if (!mounted) return;
      widget.console.say(jsTruthy(r['changes']) ? 'Pages saved in Mechanical.' : 'Saved – nothing had changed.');
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => busy = false);
        widget.console.failed(e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.console.d!, u = d.user(widget.email) ?? {'name': widget.email}, admin = d.roleOf(widget.email, widget.site, 'mechanical') == 'admin';
    return Scaffold(
      appBar: AppBar(actions: withAsk(), title: mt.Text('${tr('Pages in Mechanical')} – ${u['name']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
      bottomNavigationBar: pages == null || admin
          ? null
          : SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(14, 8, 14, 8), child: FilledButton(key: const Key('sa-pg-save'), onPressed: busy ? null : _save, child: Text(busy ? 'Saving…' : 'Save pages')))),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 30), children: [
        Text('${d.siteName(widget.site)} (${widget.site}) · Admin = Edit + entries of an earlier day (a page with a date) · Edit = add / change / delete · View = see and print · No access = page hidden', style: const TextStyle(fontSize: 13, color: C.muted)),
        const SizedBox(height: 10),
        if (admin)
          const Text('Admin has Edit on every page. To give single pages, make him User above and save, then open Pages again.', style: TextStyle(fontSize: 14.5, height: 1.4))
        else if (err.isNotEmpty)
          InfoLine(err, bad: true)
        else if (pages == null)
          const Padding(padding: EdgeInsets.all(30), child: Center(child: Text('Loading the pages from Mechanical…', style: TextStyle(color: C.muted))))
        else ...[
          if (mu == null) const Text('He has not opened Mechanical on this site yet – the pages saved here are ready for his first sign-in.', style: TextStyle(fontSize: 13.5, color: C.amber)),
          for (final p in pages!)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                mt.Text('${p['label']}', style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                SegmentedButton<String>(
                  key: Key('sa-pg-${p['key']}'),
                  showSelectedIcon: false,
                  // (3.64.0, Mechanical update-189) a page with a date (dateAdmin) offers Admin too: Edit, and its entries of an earlier day
                  segments: [for (final o in p['dateAdmin'] == true ? const ['Admin', 'Edit', 'View', 'None'] : const ['Edit', 'View', 'None']) ButtonSegment(value: o, label: Text(kPageWord[o]!))],
                  selected: {perms['${p['key']}'] ?? 'None'},
                  onSelectionChanged: (v) => setState(() => perms['${p['key']}'] = v.first),
                ),
              ]),
            ),
        ],
      ]),
    );
  }
}

bool jsTruthy(Object? v) => !(v == null || v == false || v == '' || v == 0);

class SaStorePagesScreen extends StatefulWidget {
  const SaStorePagesScreen({super.key, required this.console, required this.site, required this.email});
  final SuperAdminState console;
  final String site, email;
  @override
  State<SaStorePagesScreen> createState() => _SaStorePagesScreenState();
}

class _SaStorePagesScreenState extends State<SaStorePagesScreen> {
  final pages = <String, String>{};
  bool busy = false;

  @override
  void initState() {
    super.initState();
    final d = widget.console.d!, a = d.accessOf(widget.email, widget.site, 'store'), cur = a?['pages'] is Map ? a!['pages'] as Map : const {};
    for (final p in d.storePages) {
      final opts = [for (final o in (p['opts'] as List? ?? const [])) '$o'];
      pages['${p['key']}'] = '${cur[p['key']] ?? (opts.isEmpty ? 'None' : opts.first)}';
    }
  }

  Future<void> _save() async {
    setState(() => busy = true);
    // (3.55.0, the Store's step 2) a Store Admin: only the pages given to an Admin too (who approves, Store Purchase)
    final admin = widget.console.d!.roleOf(widget.email, widget.site, 'store') == 'admin';
    final send = admin ? {for (final p in widget.console.d!.storePages) if (p['admin'] == true) '${p['key']}': pages['${p['key']}']} : pages;
    Map<String, dynamic> r = const {};
    final ok = await widget.console.run(() async => r = await widget.console.api.admin({'action': 'storePagesSave', 'site': widget.site, 'email': widget.email, 'pages': send}));
    if (!mounted) return;
    setState(() => busy = false);
    if (!ok) return;
    widget.console.say('${r['warn'] ?? ''}'.isNotEmpty ? '${r['warn']}' : 'Store pages saved.');
    Navigator.pop(context);
  }

  /// (3.55.0) one page's choice: a row of buttons; more than three choices (who approves: No access, Level 1 … 5) a pick-list
  Widget _page(Map p) {
    final opts = [for (final o in (p['opts'] as List? ?? const [])) '$o'], k = '${p['key']}';
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        mt.Text(tr('${p['label']}'), style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        if (opts.length > 3)
          PickField(key: Key('sa-spg-$k'), label: '${p['label']}', value: pages[k] ?? opts.first, items: opts, labels: {for (final o in opts) o: kPageWord[o] ?? o}, onChanged: (v) => setState(() => pages[k] = v))
        else
          SegmentedButton<String>(
            key: Key('sa-spg-$k'),
            showSelectedIcon: false,
            segments: [for (final o in opts) ButtonSegment(value: o, label: Text(kPageWord[o] ?? o))],
            selected: {pages[k] ?? ''},
            onSelectionChanged: (v) => setState(() => pages[k] = v.first),
          ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.console.d!, u = d.user(widget.email) ?? {'name': widget.email}, admin = d.roleOf(widget.email, widget.site, 'store') == 'admin';
    return Scaffold(
      appBar: AppBar(actions: withAsk(), title: mt.Text('${tr('Pages in the Store')} – ${u['name']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
      bottomNavigationBar: admin && !d.storePages.any((p) => p['admin'] == true)
          ? null
          : SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(14, 8, 14, 8), child: FilledButton(key: const Key('sa-spg-save'), onPressed: busy ? null : _save, child: Text(busy ? 'Saving…' : 'Save pages')))),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 30), children: [
        Text('${d.siteName(widget.site)} (${widget.site}) · Item Master: Edit = add items · View = see and export · No access = page hidden', style: const TextStyle(fontSize: 13, color: C.muted)),
        const SizedBox(height: 10),
        if (admin) ...[
          const Text('Store Admin has every page (and changes, deletes, imports items). To give single pages, make him User above and save, then open Pages again.', style: TextStyle(fontSize: 14.5, height: 1.4)),
          // (3.55.0, the Store's step 2) what an Admin too gets only when given: who approves the requirements, Store Purchase
          if (d.storePages.any((p) => p['admin'] == true)) ...[
            const SizedBox(height: 8),
            const Text(kStoreExtraNote, style: TextStyle(fontSize: 13, color: C.muted, height: 1.35)),
            for (final p in d.storePages) if (p['admin'] == true) _page(p),
            const SizedBox(height: 12),
            const Text('He gets these at his next opening of the Store.', style: TextStyle(fontSize: 13, color: C.muted)),
          ],
        ] else ...[
          if (d.storePages.any((p) => p['admin'] == true)) const Text(kStoreExtraNote, style: TextStyle(fontSize: 13, color: C.muted, height: 1.35)),
          for (final p in d.storePages) _page(p),
          const SizedBox(height: 12),
          const Text('He gets these at his next opening of the Store.', style: TextStyle(fontSize: 13, color: C.muted)),
        ],
      ]),
    );
  }
}

/* ======================================== one site ======================================== */
class SaSiteScreen extends StatefulWidget {
  const SaSiteScreen({super.key, required this.console, required this.site});
  final SuperAdminState console;
  final Map<String, dynamic> site;
  @override
  State<SaSiteScreen> createState() => _SaSiteScreenState();
}

class _SaSiteScreenState extends State<SaSiteScreen> {
  late final name = TextEditingController(text: '${widget.site['name'] ?? ''}');
  // (3.70.0, the Portal's 29-10-2026: "site option ahe portal madhe tithech site address and contact number name he option de") the site's
  // address and contact – the Store's papers (the PO's Shipping Address and Site Contact, a requirement's contact)
  late final addr = TextEditingController(text: '${widget.site['address'] ?? ''}'), cName = TextEditingController(text: '${widget.site['contact_name'] ?? ''}'),
      cPhone = TextEditingController(text: '${widget.site['contact_phone'] ?? ''}');
  late String company = '${widget.site['company_id'] ?? ''}', status = widget.site['status'] == 'closed' ? 'closed' : 'active';
  bool busy = false;
  String get code => '${widget.site['code']}';

  @override
  void dispose() {
    name.dispose();
    addr.dispose();
    cName.dispose();
    cPhone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final c = widget.console;
    setState(() => busy = true);
    final ok = await c.run(() => c.api.admin({'action': 'siteSave', 'isNew': false, 'code': code, 'name': name.text, 'company': company, 'status': status, 'address': addr.text, 'contact_name': cName.text, 'contact_phone': cPhone.text}));
    if (!mounted) return;
    setState(() => busy = false);
    if (!ok) return;
    c.say('Site saved.');
    Navigator.pop(context);
  }

  /// Delete a Closed site – its code typed again; its own database (the data) stays as it is.
  Future<void> _delete() async {
    final c = widget.console, d = c.d!, n = d.access.where((a) => a['site'] == code).length;
    final typed = await askNote(context, 'Delete site $code – ${widget.site['name'] ?? ''}?',
        body: [
          Text('It leaves the lists (here and in Mechanical)${n > 0 ? ' and $n access given on it are removed' : ''}.\nIts own database – all its data – is NOT deleted.', style: const TextStyle(fontSize: 14.5, height: 1.4)),
        ],
        label: 'Type the site code ($code) to delete it:',
        ok: 'Delete',
        danger: true,
        neededMsg: 'Type the site code ($code) to delete it.');
    if (typed == null || !mounted) return;
    setState(() => busy = true);
    Map<String, dynamic> r = const {};
    final ok = await c.run(() async => r = await c.api.admin({'action': 'siteDelete', 'code': code, 'confirm': typed}));
    if (!mounted) return;
    setState(() => busy = false);
    if (!ok) return;
    final gone = (r['accessRemoved'] as num?) ?? 0;
    c.say('Site $code deleted${gone > 0 ? ' ($gone access removed)' : ''}. Its data stays in its own database.');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.console.d!, closed = widget.site['status'] == 'closed';
    return Scaffold(
      appBar: AppBar(actions: withAsk(), title: mt.Text('${widget.site['name']} ($code)', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700))),
      bottomNavigationBar: SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(14, 8, 14, 8), child: FilledButton(key: const Key('sa-st-save'), onPressed: busy ? null : _save, child: Text(busy ? 'Saving…' : 'Save')))),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 30), children: [
        TextField(key: const Key('sa-st-name'), controller: name, maxLength: 80, decoration: InputDecoration(labelText: tr('Name'))),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          key: const Key('sa-st-comp'),
          initialValue: d.companies.any((c) => c['id'] == company) ? company : '',
          isExpanded: true,
          decoration: InputDecoration(labelText: tr('Company')),
          items: [const DropdownMenuItem(value: '', child: Text('–')), for (final c in d.companies) DropdownMenuItem(value: '${c['id']}', child: mt.Text('${c['name']}'))],
          onChanged: (v) => setState(() => company = v ?? ''),
        ),
        const SizedBox(height: 10),
        TextField(key: const Key('sa-st-addr'), controller: addr, maxLength: 300, minLines: 1, maxLines: 3, decoration: InputDecoration(labelText: tr('Site address'), hintText: tr('e.g. Site office, Valshind, NH 848'))),
        TextField(key: const Key('sa-st-cname'), controller: cName, maxLength: 80, decoration: InputDecoration(labelText: tr('Contact name'))),
        TextField(key: const Key('sa-st-cphone'), controller: cPhone, maxLength: 40, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: tr('Contact number'))),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          key: const Key('sa-st-status'),
          showSelectedIcon: false,
          segments: const [ButtonSegment(value: 'active', label: Text('Active')), ButtonSegment(value: 'closed', label: Text('Closed'))],
          selected: {status},
          onSelectionChanged: (v) => setState(() => status = v.first),
        ),
        const SizedBox(height: 16),
        if (!closed)
          OutlinedButton.icon(
            key: const Key('sa-st-places'),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SaPlacesScreen(console: widget.console, site: code))),
            icon: const Icon(Icons.local_gas_station_rounded),
            label: const Text('Diesel places'),
          ),
        if (closed) ...[
          OutlinedButton.icon(
            key: const Key('sa-st-setup'),
            onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => SaNewSiteScreen(console: widget.console, site: widget.site))),
            icon: const Icon(Icons.playlist_add_check_rounded),
            label: const Text('Set up'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            key: const Key('sa-st-del'),
            style: OutlinedButton.styleFrom(foregroundColor: C.red),
            onPressed: busy ? null : _delete,
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Delete'),
          ),
        ],
        const SizedBox(height: 14),
        const Text('Closed = switched off: nobody can open it. A closed site can be deleted – its data stays in its own database.', style: TextStyle(fontSize: 13, color: C.muted)),
      ]),
    );
  }
}

/* ======================================== diesel places ======================================== */
/// One diesel place being written: its name, tank size, and what Mechanical said of it.
class SaPlace {
  SaPlace([Map<String, dynamic>? p])
      : name = TextEditingController(text: '${p?['name'] ?? ''}'),
        cap = TextEditingController(text: p?['cap'] == null || p?['cap'] == 0 ? '' : '${p?['cap']}'),
        had = '${p?['name'] ?? ''}',
        used = p?['used'] == true,
        stock = p?['stock'];
  final TextEditingController name, cap;
  final String had;
  final bool used;
  final Object? stock;
  Map<String, Object> get value => {'name': name.text.trim(), 'cap': num.tryParse(cap.text.trim()) ?? 0};
}

/// The places as they are sent (the Portal page's placesRead): those with a name or a size.
List<Map<String, Object>> placesOf(List<SaPlace> l) => [for (final p in l) if ((p.value['name'] as String).isNotEmpty || p.value['cap'] != 0) p.value];

/// The rows of diesel places (name · tank size · [live]: stock now · Remove).
class PlacesEditor extends StatelessWidget {
  const PlacesEditor({super.key, required this.rows, required this.live, required this.changed});
  final List<SaPlace> rows;
  final bool live;
  final VoidCallback changed;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final (i, p) in rows.indexed)
          Padding(
            key: ObjectKey(p),
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                flex: 3,
                child: TextField(
                  key: Key('pl-name-$i'),
                  controller: p.name,
                  readOnly: p.used,
                  maxLength: 40,
                  decoration: InputDecoration(labelText: tr('Diesel place'), hintText: 'e.g. Camp Pump', helperText: p.used ? tr('has entries – the name stays') : null, counterText: ''),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextField(
                  key: Key('pl-cap-$i'),
                  controller: p.cap,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: tr('Tank size (Ltr)'), hintText: 'e.g. 18000', helperText: live ? '${tr('Stock now')}: ${p.had.isNotEmpty && p.stock != null ? '${fmtNum(asNum(p.stock), maxDecimals: 3)} Ltr' : '–'}' : null),
                ),
              ),
              SizedBox(
                width: 40,
                child: p.used
                    ? null
                    : IconButton(
                        key: Key('pl-del-$i'),
                        tooltip: tr('Remove'),
                        icon: const Icon(Icons.close_rounded, color: C.red),
                        onPressed: () {
                          rows.removeAt(i);
                          if (rows.isEmpty) rows.add(SaPlace());
                          changed();
                        },
                      ),
              ),
            ]),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            key: const Key('pl-add'),
            onPressed: () {
              rows.add(SaPlace());
              changed();
            },
            child: const Text('+ Add place'),
          ),
        ),
      ]);
}

class SaPlacesScreen extends StatefulWidget {
  const SaPlacesScreen({super.key, required this.console, required this.site});
  final SuperAdminState console;
  final String site;
  @override
  State<SaPlacesScreen> createState() => _SaPlacesScreenState();
}

class _SaPlacesScreenState extends State<SaPlacesScreen> {
  Map<String, dynamic>? r;
  final rows = <SaPlace>[];
  String err = '';
  bool busy = false, started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (started) return;
    started = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _take(Map<String, dynamic> x) {
    r = x;
    rows
      ..clear()
      ..addAll([for (final p in SaData._l(x['places'])) SaPlace(p)]);
    if (rows.isEmpty) rows.add(SaPlace());
  }

  Future<void> _load() async {
    try {
      final x = await widget.console.api.admin({'action': 'placesGet', 'site': widget.site});
      if (mounted) setState(() => _take(x));
    } catch (e) {
      if (mounted && !portalSignInEnded(context, e)) setState(() => err = portalMsg(e));
    }
  }

  Future<void> _save() async {
    setState(() => busy = true);
    try {
      final x = await widget.console.api.admin({'action': 'placesSave', 'site': widget.site, 'places': placesOf(rows)});
      if (!mounted) return;
      setState(() {
        busy = false;
        _take({'set': true, ...x});
      });
      toast(context, 'Diesel places of ${widget.site} saved: ${SaData._l(x['places']).map((p) => p['name']).join(', ')}.');
    } catch (e) {
      if (!mounted) return;
      setState(() => busy = false);
      widget.console.failed(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.console.d!, x = r;
    return Scaffold(
      appBar: AppBar(actions: withAsk(), title: mt.Text('${tr('Diesel places')} – ${d.siteName(widget.site)} (${widget.site})', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
      bottomNavigationBar: x == null
          ? null
          : SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(14, 8, 14, 8), child: FilledButton(key: const Key('pl-save'), onPressed: busy ? null : _save, child: Text(busy ? 'Saving…' : 'Save diesel places')))),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 30), children: [
        if (err.isNotEmpty)
          InfoLine(err, bad: true)
        else if (x == null)
          const Padding(padding: EdgeInsets.all(30), child: Center(child: Text('Loading the diesel places from Mechanical…', style: TextStyle(color: C.muted))))
        else ...[
          // (the Portal page's words, a sentence a line – each in the chosen language)
          for (final l in [
            'Where diesel is kept on this site, with the tank size. Diesel Inward, Issue and Transfer use these; the first one is chosen first on the forms.',
            if (x['entries'] == true)
              x['firstFixed'] == true
                  ? 'A place that has entries keeps its name and cannot be removed; the first place stays the first (old entries without a place count there).'
                  : 'A place that has entries keeps its name and cannot be removed.',
            if (x['set'] != true) 'Not set yet – this site still has the places of the first site.',
          ])
            Text(l, style: TextStyle(fontSize: 13, color: l.startsWith('Not set') ? C.amber : C.muted, height: 1.35, fontWeight: l.startsWith('Not set') ? FontWeight.w700 : FontWeight.w400)),
          const SizedBox(height: 12),
          PlacesEditor(rows: rows, live: true, changed: () => setState(() {})),
        ],
      ]),
    );
  }
}

/* ======================================== New site ======================================== */
const kNsStep = {
  'link': '1. The Supabase project link',
  'key': '2. The secret key – in Vercel, never here',
  'connect': '3. The database answers with that key',
  'tables': '4. Mechanical\'s tables in the new database',
  'company': '5. Company settings (as the first site; the new name)',
  'places': '6. Diesel places (name and tank size)',
  'ready': '7. Ready',
};

class SaNewSiteScreen extends StatefulWidget {
  const SaNewSiteScreen({super.key, required this.console, this.site});
  final SuperAdminState console;

  /// "Set up" of a site in the list (one that is not Ready yet, or to check it again).
  final Map<String, dynamic>? site;
  @override
  State<SaNewSiteScreen> createState() => _SaNewSiteScreenState();
}

class _SaNewSiteScreenState extends State<SaNewSiteScreen> {
  late final code = TextEditingController(text: '${widget.site?['code'] ?? ''}'), name = TextEditingController(text: '${widget.site?['name'] ?? ''}');
  final url = TextEditingController(), sheet = TextEditingController();
  late String company = '${widget.site?['company_id'] ?? ''}';
  final places = <SaPlace>[SaPlace()];
  Map<String, dynamic>? r;
  bool busy = false;
  final stepsKey = GlobalKey();

  Future<void> _check() async {
    final c = widget.console;
    setState(() => busy = true);
    try {
      final x = await c.api.admin(
          {'action': 'siteSetup', 'code': code.text, 'name': name.text, 'company': company, 'url': url.text, 'sheet': sheet.text, 'places': placesOf(places)});
      if (!mounted) return;
      setState(() {
        r = x;
        busy = false;
      });
      // (on the phone) the checklist is brought into view – what is done, and the first step that is not
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final k = stepsKey.currentContext;
        if (k != null && k.mounted) Scrollable.ensureVisible(k, duration: const Duration(milliseconds: 300));
      });
      if (x['ready'] == true) c.say('Site ${x['site']} is ready.');
      await c.load();
    } catch (e) {
      if (!mounted) return;
      setState(() => busy = false);
      widget.console.failed(e);
    }
  }

  Future<void> _sql() async {
    try {
      final x = await widget.console.api.admin({'action': 'siteSql'});
      final sql = '${x['sql'] ?? ''}';
      await Clipboard.setData(ClipboardData(text: sql));
      if (mounted) toast(context, 'The SQL is copied (${(sql.length / 1024).round()} KB) – paste it in the new project\'s SQL Editor and Run.');
    } catch (e) {
      if (mounted) widget.console.failed(e);
    }
  }

  Widget _link(String label, String href, String key) => OutlinedButton.icon(
        key: Key(key),
        onPressed: () => launchUrl(Uri.parse(href), mode: LaunchMode.externalApplication),
        icon: const Icon(Icons.open_in_new_rounded, size: 18),
        label: Text(label),
      );

  Widget _steps(Map<String, dynamic> x) {
    final done = {for (final s in SaData._l(x['steps'])) '${s['step']}': s};
    const order = ['link', 'key', 'connect', 'tables', 'company', 'places', 'ready'];
    final firstBad = order.where((k) => done[k] != null && done[k]!['ok'] != true).firstOrNull;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final k in order)
        Builder(builder: (_) {
          final d = done[k], ok = d?['ok'] == true, note = '${d?['note'] ?? ''}';
          final show = d != null || k == firstBad;
          final more = <Widget>[
            if (show && note.isNotEmpty && (!ok || k == 'company' || k == 'places') && !(k == 'key' && !ok) && !(k == 'tables' && !ok)) Text(note, style: const TextStyle(fontSize: 13, color: C.muted)),
            if (show && k == 'key' && d != null && !ok) ...[
              Text('Vercel → rclerp (Mechanical) → Settings → Environment Variables → add ${x['keyName'] ?? ''} = this project\'s Secret key (Supabase → Project Settings → API Keys → Secret keys) → Save → Deployments → Redeploy. Then press Check & set up again.',
                  style: const TextStyle(fontSize: 13, color: C.muted, height: 1.35)),
              if ('${x['keysLink'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: _link('Open the project\'s API keys', '${x['keysLink']}', 'ns-keys')),
            ],
            if (show && k == 'tables' && d != null && !ok) ...[
              Text('Run Mechanical\'s SQL once in the NEW project: copy it, open its SQL Editor, paste, Run. Then press Check & set up again.${note.isNotEmpty ? '\n$note' : ''}',
                  style: const TextStyle(fontSize: 13, color: C.muted, height: 1.35)),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Wrap(spacing: 8, runSpacing: 6, children: [
                  FilledButton(key: const Key('ns-sql'), style: FilledButton.styleFrom(minimumSize: const Size(0, 40)), onPressed: _sql, child: const Text('Copy the SQL')),
                  if ('${x['sqlLink'] ?? ''}'.isNotEmpty) _link('Open its SQL Editor', '${x['sqlLink']}', 'ns-sqled'),
                ]),
              ),
            ],
            if (show && k == 'ready' && d != null && ok) ...[
              const Text('The site is Active. Give it to people under Users & Access (pick the site).', style: TextStyle(fontSize: 13, color: C.greenDark, height: 1.35)),
              if ('${x['backupEmail'] ?? ''}'.isNotEmpty && sheet.text.trim().isNotEmpty)
                Text('For its backup, share the Google Sheet with ${x['backupEmail']} as Editor.', style: const TextStyle(fontSize: 13, color: C.greenDark, height: 1.35)),
            ],
          ];
          return Container(
            key: Key('ns-step-$k'),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: d == null ? C.slateSoft : (ok ? C.greenSoft : C.redSoft), borderRadius: BorderRadius.circular(14)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(d == null ? Icons.radio_button_unchecked_rounded : (ok ? Icons.check_circle_rounded : Icons.error_rounded), size: 20, color: d == null ? C.faint : (ok ? C.green : C.red)),
                const SizedBox(width: 8),
                Expanded(child: Text(kNsStep[k]!, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700))),
              ]),
              if (more.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6, left: 28), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: more)),
            ]),
          );
        }),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.console.d!, x = r;
    return Scaffold(
      appBar: AppBar(actions: withAsk(), title: const Text('New site', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700))),
      bottomNavigationBar: SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(14, 8, 14, 8), child: FilledButton(key: const Key('ns-check'), onPressed: busy ? null : _check, child: Text(busy ? 'Checking…' : 'Check & set up')))),
      body: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 30), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Mechanical for a new site – the same app, its own database. Nothing of another site is copied and no user is made; afterwards you give the site to people under Users & Access.',
            style: TextStyle(fontSize: 13, color: C.muted, height: 1.35)),
        const SizedBox(height: 6),
        const Text('Before: make the site\'s Supabase project yourself (Supabase → New project · region Mumbai). Its secret key is never typed here – the steps below say where it goes.',
            style: TextStyle(fontSize: 13, color: C.ink, height: 1.35)),
        const SizedBox(height: 12),
        TextField(key: const Key('ns-code'), controller: code, maxLength: 12, textCapitalization: TextCapitalization.characters, decoration: InputDecoration(labelText: tr('Site code'), hintText: 'e.g. 18B', counterText: '')),
        const SizedBox(height: 8),
        TextField(key: const Key('ns-name'), controller: name, maxLength: 80, decoration: InputDecoration(labelText: tr('Site name'), hintText: 'e.g. Kolhapur 18B', counterText: '')),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          key: const Key('ns-comp'),
          initialValue: d.companies.any((c) => c['id'] == company) ? company : '',
          isExpanded: true,
          decoration: InputDecoration(labelText: tr('Company')),
          items: [const DropdownMenuItem(value: '', child: Text('–')), for (final c in d.companies) DropdownMenuItem(value: '${c['id']}', child: mt.Text('${c['name']}'))],
          onChanged: (v) => setState(() => company = v ?? ''),
        ),
        const SizedBox(height: 8),
        TextField(key: const Key('ns-url'), controller: url, keyboardType: TextInputType.url, decoration: InputDecoration(labelText: tr('Supabase project link'), hintText: 'https://….supabase.co')),
        const SizedBox(height: 8),
        TextField(key: const Key('ns-sheet'), controller: sheet, keyboardType: TextInputType.url, decoration: InputDecoration(labelText: tr('Google Sheet for its backup (can be added later)'), hintText: 'https://docs.google.com/spreadsheets/d/…')),
        const FormHead('Diesel places of this site', sub: 'Where diesel is kept – the pump, each dispenser, a store – with its tank size. Diesel Inward, Issue and Transfer use these. The first one is chosen first on the forms. Later: Sites → Diesel places.'),
        PlacesEditor(rows: places, live: false, changed: () => setState(() {})),
        if (x != null) ...[const SizedBox(height: 12), KeyedSubtree(key: stepsKey, child: _steps(x))],
      ])),
    );
  }
}

/* ======================================== a company ======================================== */
class SaCompanyScreen extends StatefulWidget {
  const SaCompanyScreen({super.key, required this.console, this.company});
  final SuperAdminState console;
  final Map<String, dynamic>? company;
  @override
  State<SaCompanyScreen> createState() => _SaCompanyScreenState();
}

class _SaCompanyScreenState extends State<SaCompanyScreen> {
  late final f = {for (final k in const ['name', 'gstin', 'pan', 'address', 'logo']) k: TextEditingController(text: '${widget.company?[k] ?? ''}')};
  bool busy = false;

  Future<void> _save() async {
    final c = widget.console;
    setState(() => busy = true);
    final ok = await c.run(() => c.api.admin({'action': 'companySave', 'id': widget.company?['id'] ?? '', for (final e in f.entries) e.key: e.value.text}));
    if (!mounted) return;
    setState(() => busy = false);
    if (!ok) return;
    c.say('Company saved.');
    Navigator.pop(context);
  }

  Future<void> _delete() async {
    final c = widget.console, co = widget.company!;
    if (!await ask(context, 'Delete the company "${co['name']}"?', 'No site belongs to it.', yes: 'Delete', danger: true) || !mounted) return;
    setState(() => busy = true);
    final ok = await c.run(() => c.api.admin({'action': 'companyDelete', 'id': co['id']}));
    if (!mounted) return;
    setState(() => busy = false);
    if (!ok) return;
    c.say('Company deleted.');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final co = widget.company, used = co == null ? const [] : [for (final s in widget.console.d!.sites) if (s['company_id'] == co['id']) s['code']];
    const labels = {'name': 'Name *', 'gstin': 'GSTIN', 'pan': 'PAN', 'address': 'Address', 'logo': 'Logo (https link)'};
    const hints = {'gstin': '27ABCDE1234F1Z5', 'pan': 'ABCDE1234F', 'logo': 'https://…'};
    const max = {'name': 80, 'gstin': 15, 'pan': 10, 'address': 300, 'logo': 300};
    return Scaffold(
      appBar: AppBar(actions: withAsk(), title: mt.Text(co == null ? tr('Add a company') : '${tr('Change')}: ${co['name']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700))),
      bottomNavigationBar: SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(14, 8, 14, 8), child: FilledButton(key: const Key('co-save'), onPressed: busy ? null : _save, child: Text(busy ? 'Saving…' : 'Save company')))),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 30), children: [
        for (final k in labels.keys) ...[
          TextField(
            key: Key('co-$k'),
            controller: f[k],
            maxLength: max[k],
            maxLines: k == 'address' ? 3 : 1,
            minLines: 1,
            textCapitalization: k == 'gstin' || k == 'pan' ? TextCapitalization.characters : TextCapitalization.none,
            decoration: InputDecoration(labelText: tr(labels[k]!), hintText: hints[k], counterText: ''),
          ),
          const SizedBox(height: 8),
        ],
        if (co != null && used.isEmpty)
          OutlinedButton.icon(
            key: const Key('co-del'),
            style: OutlinedButton.styleFrom(foregroundColor: C.red),
            onPressed: busy ? null : _delete,
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Delete'),
          ),
        if (used.isNotEmpty) Text('${tr('Sites')}: ${used.join(', ')}', style: const TextStyle(fontSize: 13, color: C.muted)),
      ]),
    );
  }
}

/* ======================================== a module ======================================== */
class SaModuleScreen extends StatefulWidget {
  const SaModuleScreen({super.key, required this.console, this.module});
  final SuperAdminState console;
  final Map<String, dynamic>? module;
  @override
  State<SaModuleScreen> createState() => _SaModuleScreenState();
}

class _SaModuleScreenState extends State<SaModuleScreen> {
  late final key = TextEditingController(), name = TextEditingController(text: '${widget.module?['name'] ?? ''}'), url = TextEditingController(text: '${widget.module?['url'] ?? ''}');
  late String status = widget.module?['status'] == 'live' ? 'live' : 'off';
  bool busy = false;
  bool get isNew => widget.module == null;

  Future<void> _save() async {
    final c = widget.console;
    setState(() => busy = true);
    final ok = await c.run(() => c.api.admin({'action': 'moduleSave', 'isNew': isNew, 'key': isNew ? key.text.trim() : widget.module!['key'], 'name': name.text, 'url': url.text.trim(), 'status': status}));
    if (!mounted) return;
    setState(() => busy = false);
    if (!ok) return;
    c.say('Module saved.');
    Navigator.pop(context);
  }

  /// Delete a module that is Off – its key typed again; everybody's access to it goes too.
  Future<void> _delete() async {
    final c = widget.console, m = widget.module!, k = '${m['key']}', n = c.d!.access.where((a) => a['module'] == k).length;
    final typed = await askNote(context, 'Delete the module ${m['name'] ?? k}?',
        body: [Text('It leaves the list${n > 0 ? ' and $n access given to it are removed' : ''}. Its own app and data are not touched.', style: const TextStyle(fontSize: 14.5, height: 1.4))],
        label: 'Type the module key ($k) to delete it:',
        ok: 'Delete',
        danger: true,
        neededMsg: 'Type the module key ($k) to delete it.');
    if (typed == null || !mounted) return;
    setState(() => busy = true);
    final ok = await c.run(() => c.api.admin({'action': 'moduleDelete', 'key': k, 'confirm': typed}));
    if (!mounted) return;
    setState(() => busy = false);
    if (!ok) return;
    c.say('Module deleted.');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.module;
    return Scaffold(
      appBar: AppBar(actions: withAsk(), title: mt.Text(isNew ? tr('+ Add module') : '${m!['name']} (${m['key']})', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700))),
      bottomNavigationBar: SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(14, 8, 14, 8), child: FilledButton(key: const Key('m-save'), onPressed: busy ? null : _save, child: Text(busy ? 'Saving…' : (isNew ? 'Add' : 'Save'))))),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 30), children: [
        if (isNew) ...[TextField(key: const Key('m-key'), controller: key, decoration: InputDecoration(labelText: tr('Key'), hintText: 'key, e.g. store')), const SizedBox(height: 8)],
        TextField(key: const Key('m-name'), controller: name, maxLength: 40, decoration: InputDecoration(labelText: tr('Name'), hintText: 'name, e.g. Store', counterText: '')),
        const SizedBox(height: 8),
        TextField(key: const Key('m-url'), controller: url, keyboardType: TextInputType.url, decoration: InputDecoration(labelText: tr('Link'), hintText: 'https://…')),
        const SizedBox(height: 14),
        SegmentedButton<String>(
          key: const Key('m-status'),
          showSelectedIcon: false,
          segments: const [ButtonSegment(value: 'live', label: Text('Live')), ButtonSegment(value: 'off', label: Text('Off'))],
          selected: {status},
          onSelectionChanged: (v) => setState(() => status = v.first),
        ),
        const SizedBox(height: 16),
        if (!isNew && m!['key'] != 'mechanical' && m['status'] != 'live')
          OutlinedButton.icon(
            key: const Key('m-del'),
            style: OutlinedButton.styleFrom(foregroundColor: C.red),
            onPressed: busy ? null : _delete,
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Delete'),
          ),
        const SizedBox(height: 10),
        const Text('A module shows on the dashboard only when it is Live and has its link. A module that is Off can be deleted (not Mechanical).', style: TextStyle(fontSize: 13, color: C.muted)),
      ]),
    );
  }
}
