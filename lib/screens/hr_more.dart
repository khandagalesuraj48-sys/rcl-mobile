/* (3.161.0, asked 21-11-2026) TWO MORE THINGS OF HR IN THE APP:
 *   "SIGN OUT OF HR" for a person who has the ERP and HR ("je user erp and hr madhe aahet tyana 2 ni thikani sign out de – erp madhun
 *   sign out mhanje main sign out, hr madhun sign out mhanje hr only"; his answer: HR's session ends too – opening HR again asks for the
 *   password or a code): the HR sign-in ends on the server (rcl-hr api/logout), the phone remembers "signed out of HR", and the HR
 *   pages open again only after his password – or a code sent to his e-mail – was taken by the Portal ([HrSignIn]). The ERP stays as
 *   it is. The login is ONE (the Portal's): the same password / e-mail as for the app.
 *   ADD EMPLOYEE WITH VERIFICATION (rcl-hr step 21 – lib/act_newemp.js; "Add employee app madhun"): the app's own four steps – 1 Papers
 *   (camera / photo / PDF; AI reads a photo and fills the form – he checks) · 2 Details · 3 Work · 4 Send – a draft saved at every step;
 *   "Added by me": draft / waiting for whom / rejected and why / approved with his code. The same actions as the web page. */
import 'dart:async';

import 'package:flutter/material.dart' hide Text;
import 'package:flutter/material.dart' as m show Text;

import '../core/api.dart' show ApiError;
import '../ui/design.dart';
import '../ui/hr_look.dart';
import '../ui/hr_skin.dart';
import '../ui/scope.dart';
import '../ui/t.dart';
import '../ui/widgets.dart';
import 'attach_box.dart' show pickAttFiles;
import 'attend_reqs.dart' show HrAsk;
import 'hr_me.dart' show docReady, kMeSky;

String _t(String en, String mr) => Lang.i.pair(en, mr);
String _dmy(Object? d) {
  final t = '${d ?? ''}';
  return t.length >= 10 ? '${t.substring(8, 10)}-${t.substring(5, 7)}-${t.substring(0, 4)}' : t;
}

String _two(int n) => n.toString().padLeft(2, '0');

/// A card whose rows can be pressed (ListTile, check boxes): the rows get their own Material inside the card's box.
Widget _tapCard(List<Widget> children, {Key? key}) => hrCard(key: key, [Material(type: MaterialType.transparency, child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: children))]);

/// What the phone keeps while he is signed out of HR ('1').
const kHrOut = 'hr_signed_out';

/* ───────────────────────── SIGN IN TO HR AGAIN ───────────────────────── */
/// Shown in place of the HR pages after "Sign out of HR": his password, or a code sent to his e-mail – taken by the Portal.
class HrSignIn extends StatefulWidget {
  const HrSignIn({super.key, required this.onDone});
  final VoidCallback onDone;
  @override
  State<HrSignIn> createState() => _HrSignInState();
}

class _HrSignInState extends State<HrSignIn> {
  final pass = TextEditingController(), code = TextEditingController();
  bool busy = false, otp = false, sent = false, hide = true;
  String err = '';

  @override
  void initState() {
    super.initState();
    // is the code by e-mail switched on? (the Portal's own switch)
    final s = SessionScope.read(context);
    s.api.auth({'action': 'options'}).then((r) {
      if (mounted && r['otp'] == true) setState(() => otp = true);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    pass.dispose();
    code.dispose();
    super.dispose();
  }

  String get _mail {
    final s = SessionScope.read(context);
    return s.mailLogin.isNotEmpty ? s.mailLogin : s.email;
  }

  Future<void> _run(Future<void> Function() what, {bool open = true}) async {
    setState(() {
      busy = true;
      err = '';
    });
    try {
      await what();
      if (!mounted) return;
      if (open) {
        await SessionScope.read(context).api.keep.write(kHrOut, null);
        widget.onDone();
      }
    } on ApiError catch (e) {
      if (mounted) setState(() => err = e.toString());
    } catch (_) {
      if (mounted) setState(() => err = _t('Something went wrong – please try again.', 'काहीतरी चुकले – पुन्हा करा.'));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final api = SessionScope.read(context).api;
    return ListView(key: const Key('hr-signin'), padding: const EdgeInsets.fromLTRB(20, 24, 20, 40), children: [
      Text('Sign in to HR', mr: 'HR मध्ये sign in करा', style: TextStyle(fontFamily: 'Montserrat', fontSize: 22, fontWeight: FontWeight.w800, color: sk.ink)),
      const SizedBox(height: 6),
      Text('You signed out of HR. The ERP is still open. Give your password to open HR again.', mr: 'तुम्ही HR मधून sign out केले आहे. ERP चालू आहे. HR परत उघडायला तुमचा password द्या.', style: TextStyle(fontSize: 13.5, color: sk.muted, height: 1.4)),
      const SizedBox(height: 16),
      hrCard([
        m.Text(_mail, key: const Key('hr-signin-mail'), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: sk.ink)),
        const SizedBox(height: 12),
        TextField(
          key: const Key('hr-signin-pass'),
          controller: pass,
          obscureText: hide,
          decoration: InputDecoration(labelText: _t('Password', 'Password'), border: const OutlineInputBorder(), suffixIcon: IconButton(icon: Icon(hide ? Icons.visibility_outlined : Icons.visibility_off_outlined), onPressed: () => setState(() => hide = !hide))),
        ),
        const SizedBox(height: 12),
        FilledButton(
          key: const Key('hr-signin-go'),
          onPressed: busy || pass.text.isEmpty ? null : () => _run(() async => api.auth({'action': 'login', 'email': _mail, 'password': pass.text})),
          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
          child: const Text('Open HR', mr: 'HR उघडा'),
        ),
      ]),
      if (otp) ...[
        const SizedBox(height: 12),
        hrCard([
          Text('Or a code by e-mail', mr: 'किंवा e-mail वर code', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: sk.ink)),
          const SizedBox(height: 8),
          if (!sent)
            OutlinedButton(key: const Key('hr-signin-send'), onPressed: busy ? null : () => _run(() async {
                  await api.auth({'action': 'otpSend', 'email': _mail});
                  if (mounted) setState(() => sent = true);
                }, open: false), child: const Text('Send me a code', mr: 'मला code पाठवा')),
          if (sent) ...[
            TextField(key: const Key('hr-signin-code'), controller: code, keyboardType: TextInputType.number, maxLength: 6, decoration: InputDecoration(labelText: _t('The code of your e-mail', 'E-mail वर आलेला code'), border: const OutlineInputBorder())),
            FilledButton(key: const Key('hr-signin-code-go'), onPressed: busy ? null : () => _run(() async => api.auth({'action': 'otpLogin', 'email': _mail, 'code': code.text.trim()})), child: const Text('Open HR', mr: 'HR उघडा')),
          ],
        ]),
      ],
      if (err.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: InfoLine(err, bad: true, help: false, key: const Key('hr-signin-err'))),
    ]);
  }
}

/* ───────────────────────── NEW EMPLOYEES: ADDED BY ME ───────────────────────── */
class NewEmployeesScreen extends StatefulWidget {
  const NewEmployeesScreen({super.key, required this.ask});
  final HrAsk ask;
  @override
  State<NewEmployeesScreen> createState() => _NewEmployeesScreenState();
}

class _NewEmployeesScreenState extends State<NewEmployeesScreen> {
  Map setup = const {};
  List<Map> rows = const [];
  bool loading = true;
  String err = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final s = await widget.ask({'action': 'neSetup'}), r = await widget.ask({'action': 'neList', 'tab': 'mine'});
      if (!mounted) return;
      setState(() {
        setup = s;
        rows = (r['rows'] as List? ?? const []).whereType<Map>().where((d) => d['status'] != 'cancelled').toList();
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

  Future<void> _form(Map? draft) async {
    Map? full = draft;
    if (draft != null) {
      try {
        full = (await widget.ask({'action': 'neOpen', 'id': draft['id']}))['draft'] as Map?;
      } catch (e) {
        if (mounted) setState(() => err = errText(e));
        return;
      }
    }
    if (!mounted) return;
    await Navigator.of(context).push<bool>(hrRoute(NewEmployeeFormScreen(ask: widget.ask, setup: setup, draft: full)));
    if (mounted) _load();
  }

  static const _st = {'draft': ('Draft', 'Draft', ''), 'pending': ('Waiting', 'थांबलेले', 'w'), 'approved': ('Approved', 'Approved', 'a'), 'rejected': ('Rejected', 'Rejected', 'x')};

  @override
  Widget build(BuildContext context) {
    final goes = (setup['goes_to'] as List? ?? const []).whereType<Map>().map((c) => '${c['stage'] == 'verify' ? 'Verify' : 'Approve'} – ${c['name']}').join(' › ');
    return Scaffold(
      appBar: hrHead(context, sky: kMeSky, title: 'New employees', mr: 'नवीन employees', height: 64),
      body: loading
          ? const SkeletonList(tiles: 0, rows: 4)
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(key: const Key('ne-page'), padding: const EdgeInsets.fromLTRB(16, 14, 16, 40), children: [
                if (setup['may'] == true)
                  FilledButton.icon(key: const Key('ne-new'), onPressed: () => _form(null), icon: const Icon(Icons.person_add_alt_1_outlined), label: const Text('Add employee', mr: 'Employee जोडा')),
                if (goes.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: m.Text(_t('Goes to: $goes', 'कोणाकडे जाईल: $goes'), key: const Key('ne-goes'), style: TextStyle(fontSize: 12.5, color: sk.muted, height: 1.35))),
                const SizedBox(height: 12),
                if (err.isNotEmpty) InfoLine(err, bad: true, help: false, key: const Key('ne-err')),
                if (rows.isEmpty && err.isEmpty) InfoLine(_t('You have not added anybody here yet.', 'तुम्ही अजून कोणाला जोडलेले नाही.'), help: false, key: const Key('ne-none')),
                for (final d in rows)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: hrCard(key: Key('ne-${d['id']}'), padding: const EdgeInsets.fromLTRB(14, 12, 14, 12), [
                      Row(children: [
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                            m.Text('${d['name'] ?? ''}'.isEmpty ? 'Draft' : '${d['name']}', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: sk.ink)),
                            m.Text(
                                switch ('${d['status']}') {
                                  'draft' => _t('Draft · saved ${_dmy(d['updated_at'])}', 'Draft · ${_dmy(d['updated_at'])} ला save'),
                                  'pending' => _t('Sent ${_dmy(d['sent_at'])} · ${d['waits'] ?? ''}', '${_dmy(d['sent_at'])} ला पाठवले · ${d['waits'] ?? ''}'),
                                  'rejected' => _t('Rejected: ${d['note'] ?? ''}', 'Reject: ${d['note'] ?? ''}'),
                                  _ => _t('Approved ${_dmy(d['decided_at'])}', '${_dmy(d['decided_at'])} ला approve'),
                                },
                                style: TextStyle(fontSize: 12.5, color: '${d['status']}' == 'rejected' ? const Color(0xFFC22A1B) : sk.muted, height: 1.35)),
                          ]),
                        ),
                        () {
                          final s = _st['${d['status']}'] ?? _st['draft']!;
                          return stateChip(_t(s.$1, s.$2), s.$3);
                        }(),
                      ]),
                      if (d['result'] is Map) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: sk.dark ? const Color(0xFF1B2437) : const Color(0xFFF4F6FB), borderRadius: BorderRadius.circular(14)),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                            Text('Employee code', mr: 'Employee code', style: TextStyle(fontSize: 12, color: sk.muted)),
                            m.Text('${(d['result'] as Map)['code'] ?? ''}', key: Key('ne-code-${d['id']}'), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: sk.ink)),
                            if ('${(d['result'] as Map)['signin_email'] ?? ''}'.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text('Sign-in', mr: 'Sign-in', style: TextStyle(fontSize: 12, color: sk.muted)),
                              m.Text('${(d['result'] as Map)['signin_email']}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: sk.ink)),
                            ],
                            const SizedBox(height: 6),
                            m.Text(
                                switch ('${(d['result'] as Map)['signin'] ?? ''}') {
                                  'made' => (d['result'] as Map)['mailed'] == true ? _t('His sign-in is made and the e-mail sent to him.', 'त्याचा sign-in बनला आणि mail पाठवला.') : _t('His sign-in is made. The e-mail was not sent – tell him yourself.', 'त्याचा sign-in बनला. Mail गेला नाही – त्याला स्वतः सांगा.'),
                                  'has' => _t('He already had a sign-in.', 'त्याच्याकडे आधीच sign-in होता.'),
                                  _ => _t('Sign-in: the HR Admin gives it on the web (HR › Employees › New employees › Give sign-in).', 'Sign-in: HR Admin web वरून देतो (HR › Employees › New employees › Give sign-in).'),
                                },
                                style: TextStyle(fontSize: 12.5, color: sk.muted, height: 1.35)),
                          ]),
                        ),
                      ],
                      if (d['status'] == 'draft' || d['status'] == 'rejected')
                        Padding(padding: const EdgeInsets.only(top: 10), child: OutlinedButton(key: Key('ne-go-${d['id']}'), onPressed: () => _form(d), child: Text(d['status'] == 'rejected' ? 'Put right and send again' : 'Go on', mr: d['status'] == 'rejected' ? 'दुरुस्त करून पुन्हा पाठवा' : 'पुढे चला'))),
                    ]),
                  ),
              ]),
            ),
    );
  }
}

/* ───────────────────────── THE FORM: 1 PAPERS · 2 DETAILS · 3 WORK · 4 SEND ───────────────────────── */
class NewEmployeeFormScreen extends StatefulWidget {
  const NewEmployeeFormScreen({super.key, required this.ask, required this.setup, this.draft});
  final HrAsk ask;
  final Map setup;
  final Map? draft;
  @override
  State<NewEmployeeFormScreen> createState() => _NewEmployeeFormScreenState();
}

class _NewEmployeeFormScreenState extends State<NewEmployeeFormScreen> {
  int step = 1;
  String id = '', err = '', said = '';
  bool busy = false, selected = false;
  final c = <String, TextEditingController>{for (final k in ['name', 'mobile', 'address', 'email', 'whatsapp']) k: TextEditingController()};
  String category = '', gender = '', dob = '', joined = '', designation = '', department = '';
  final docs = <Map<String, dynamic>>[], ai = <String>{}, places = <String>{};
  final rep = <Map>[];

  @override
  void initState() {
    super.initState();
    final d = widget.draft;
    if (d == null) return;
    id = '${d['id'] ?? ''}';
    final b = (d['body'] as Map?) ?? const {}, f = (b['form'] as Map?) ?? const {}, w = (b['work'] as Map?) ?? const {};
    for (final k in c.keys) {
      c[k]!.text = '${f[k] ?? ''}';
    }
    category = '${f['category'] ?? ''}';
    gender = '${f['gender'] ?? ''}';
    dob = '${f['dob'] ?? ''}';
    joined = '${f['joined_on'] ?? ''}';
    designation = '${f['designation_id'] ?? ''}';
    department = '${f['department_id'] ?? ''}';
    selected = w['places_mode'] == 'selected';
    places.addAll((w['place_ids'] as List? ?? const []).map((x) => '$x'));
    rep.addAll((d['reporting'] as List? ?? const []).whereType<Map>());
    docs.addAll((b['docs'] as List? ?? const []).whereType<Map>().map((x) => {'kind': x['kind'], 'path': x['path'], 'number': x['number'] ?? '', 'issued_on': x['issued_on'] ?? '', 'expires_on': x['expires_on'] ?? '', 'bytes': x['bytes'] ?? 1}));
  }

  @override
  void dispose() {
    for (final x in c.values) {
      x.dispose();
    }
    super.dispose();
  }

  Map<String, dynamic> get _form => {
        'name': c['name']!.text.trim(),
        'category': category,
        'gender': gender,
        'dob': dob,
        'mobile': c['mobile']!.text.trim(),
        'email': c['email']!.text.trim(),
        'joined_on': joined,
        'department_id': department,
        'designation_id': designation,
        'whatsapp': c['whatsapp']!.text.trim(),
        'address': c['address']!.text.trim(),
      };
  Map<String, dynamic> get _body => {
        'id': id,
        'form': _form,
        'work': {'places_mode': selected ? 'selected' : 'all', 'place_ids': places.toList(), 'reporting': [for (final r in rep) r['id']]},
        'docs': docs,
      };

  /// the draft is there (made with the name typed so far) – a paper needs its folder
  Future<void> _ensure() async {
    if (id.isNotEmpty) return;
    final r = await widget.ask({'action': 'neDraft', 'form': _form});
    id = '${(r['draft'] as Map)['id']}';
  }

  Future<bool> _save() async {
    try {
      await _ensure();
      await widget.ask({'action': 'neDraft', ..._body});
      return true;
    } catch (e) {
      if (mounted) setState(() => err = errText(e));
      return false;
    }
  }

  Future<void> _paper(String how) async {
    if (busy) return;
    setState(() {
      busy = true;
      err = '';
      said = '';
    });
    try {
      final got = await pickAttFiles(how, 10);
      if (got.isEmpty) return;
      await _ensure();
      if (!mounted) return;
      final api = SessionScope.read(context).api, useAi = widget.setup['ai'] == true;
      for (final (i, g) in got.indexed) {
        final f = docReady(g.name, g.bytes);
        if (f == null) throw ApiError('"${g.name}" could not be read – a photo or a PDF.');
        if (mounted) setState(() => said = _t('Keeping ${i + 1} of ${got.length}', '${got.length} पैकी ${i + 1} ठेवत आहे'));
        final u = await widget.ask({'action': 'neDocUrl', 'id': id, 'type': f.$2, 'bytes': f.$1.length});
        await api.hrFile('${u['url']}', f.$1, f.$2);
        final doc = <String, dynamic>{'kind': 'other', 'path': u['path'], 'number': '', 'issued_on': '', 'expires_on': '', 'bytes': f.$1.length};
        if (useAi && f.$2 != 'application/pdf') {
          if (mounted) setState(() => said = _t('AI reads ${i + 1} of ${got.length}', 'AI ${got.length} पैकी ${i + 1} वाचत आहे'));
          try {
            final r = await widget.ask({'action': 'neDocRead', 'id': id, 'path': u['path'], 'kind': ''}), read = (r['read'] as Map?) ?? const {};
            if ('${r['kind'] ?? ''}'.isNotEmpty) doc['kind'] = r['kind'];
            doc['number'] = '${read['number'] ?? ''}';
            doc['issued_on'] = '${read['issued_on'] ?? ''}';
            doc['expires_on'] = '${read['expires_on'] ?? ''}';
            // AI fills only what is still empty – a suggestion, marked "AI"
            void fill(String k, String v) {
              if (v.isNotEmpty && c[k]!.text.trim().isEmpty) {
                c[k]!.text = v;
                ai.add(k);
              }
            }

            fill('name', '${read['name'] ?? ''}');
            fill('address', '${read['address'] ?? ''}');
            if ('${read['date_of_birth'] ?? ''}'.isNotEmpty && dob.isEmpty) {
              dob = '${read['date_of_birth']}';
              ai.add('dob');
            }
            if ('${read['gender'] ?? ''}'.isNotEmpty && gender.isEmpty) gender = '${read['gender']}';
          } catch (_) {
            // AI could not read it: the paper is kept, the form is filled by hand
          }
        }
        docs.add(doc);
      }
    } catch (e) {
      if (mounted) setState(() => err = errText(e));
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
          said = '';
        });
      }
    }
  }

  Future<void> _send() async {
    setState(() {
      busy = true;
      err = '';
    });
    if (!await _save()) {
      if (mounted) setState(() => busy = false);
      return;
    }
    try {
      final r = await widget.ask({'action': 'neSend', 'id': id});
      if (!mounted) return;
      toast(context, _t('Sent – ${(r['draft'] as Map?)?['waits'] ?? ''}', 'पाठवले – ${(r['draft'] as Map?)?['waits'] ?? ''}'));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          err = errText(e);
        });
      }
    }
  }

  Future<void> _date(bool birth) async {
    final now = DateTime.now(), d = await showDatePicker(context: context, initialDate: birth ? DateTime(now.year - 25) : now, firstDate: DateTime(1950), lastDate: now.add(const Duration(days: 90)));
    if (d == null || !mounted) return;
    setState(() {
      final v = '${d.year}-${_two(d.month)}-${_two(d.day)}';
      if (birth) {
        dob = v;
      } else {
        joined = v;
      }
    });
  }

  Widget _txt(String k, String en, String mr, {TextInputType? type, int max = 80}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(key: Key('nef-$k'), controller: c[k], keyboardType: type, maxLength: max, decoration: InputDecoration(labelText: _t(en, mr) + (ai.contains(k) ? '  · AI' : ''), border: const OutlineInputBorder(), counterText: '')),
      );
  Widget _pick(String key, String en, String mr, String value, List<(String, String)> items, void Function(String) set) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: DropdownButtonFormField<String>(
          key: Key(key),
          initialValue: items.any((x) => x.$1 == value) ? value : null,
          isExpanded: true,
          decoration: InputDecoration(labelText: _t(en, mr), border: const OutlineInputBorder()),
          items: [for (final x in items) DropdownMenuItem(value: x.$1, child: m.Text(x.$2, maxLines: 1, overflow: TextOverflow.ellipsis))],
          onChanged: (v) => setState(() => set(v ?? '')),
        ),
      );

  List<Widget> _stepBody() {
    final kinds = {for (final k in (widget.setup['kinds'] as List? ?? const []).whereType<Map>()) '${k['key']}': '${k['name']}'};
    switch (step) {
      case 1:
        return [
          Text(widget.setup['ai'] == true ? 'Take the photos of his papers. AI reads them and fills the form – check it on the next step.' : 'Attach his papers. (AI is not switched on for you: fill the form by hand.)',
              mr: widget.setup['ai'] == true ? 'त्याच्या कागदांचे photo काढा. AI ते वाचून form भरतो – पुढच्या पायरीवर तपासा.' : 'त्याचे कागद जोडा. (तुमच्यासाठी AI चालू नाही: form हाताने भरा.)', style: TextStyle(fontSize: 13, color: sk.muted, height: 1.4)),
          const SizedBox(height: 10),
          if (docs.isEmpty) Text('No paper attached yet.', mr: 'अजून कागद जोडलेला नाही.', style: TextStyle(fontSize: 13, color: sk.muted)),
          for (final (i, d) in docs.indexed)
            ListTile(
              key: Key('nef-doc-$i'),
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.description_outlined),
              title: m.Text(kinds['${d['kind']}'] ?? '${d['kind']}'),
              subtitle: '${d['number'] ?? ''}'.isEmpty ? null : m.Text('${d['number']}'),
              trailing: IconButton(key: Key('nef-doc-x-$i'), icon: const Icon(Icons.close_rounded), onPressed: () => setState(() => docs.removeAt(i))),
            ),
          const SizedBox(height: 8),
          if (said.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 8), child: m.Text(said, key: const Key('nef-said'), style: TextStyle(fontSize: 12.5, color: sk.muted))),
          Row(children: [
            Expanded(child: OutlinedButton.icon(key: const Key('nef-camera'), onPressed: busy ? null : () => _paper('camera'), icon: const Icon(Icons.photo_camera_outlined, size: 18), label: const Text('Camera', mr: 'Camera'))),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton.icon(key: const Key('nef-gallery'), onPressed: busy ? null : () => _paper('gallery'), icon: const Icon(Icons.photo_library_outlined, size: 18), label: const Text('Photos', mr: 'Photos'))),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton.icon(key: const Key('nef-pdf'), onPressed: busy ? null : () => _paper('pdf'), icon: const Icon(Icons.picture_as_pdf_outlined, size: 18), label: const Text('PDF', mr: 'PDF'))),
          ]),
        ];
      case 2:
        return [
          _txt('name', 'Full name *', 'पूर्ण नाव *'),
          _pick('nef-category', 'Category *', 'Category *', category, const [('staff', 'Staff'), ('operator', 'Operator'), ('driver', 'Driver'), ('labour', 'Labour')], (v) => category = v),
          _pick('nef-gender', 'Gender', 'Gender', gender, const [('male', 'Male'), ('female', 'Female'), ('other', 'Other')], (v) => gender = v),
          ListTile(key: const Key('nef-dob'), contentPadding: EdgeInsets.zero, leading: const Icon(Icons.cake_outlined), title: Text('Date of birth *${ai.contains('dob') ? '  · AI' : ''}', mr: 'जन्मतारीख *${ai.contains('dob') ? '  · AI' : ''}'), subtitle: m.Text(dob.isEmpty ? '–' : _dmy(dob)), onTap: () => _date(true)),
          _txt('mobile', 'Mobile number', 'Mobile number', type: TextInputType.phone, max: 10),
          ListTile(key: const Key('nef-joined'), contentPadding: EdgeInsets.zero, leading: const Icon(Icons.event_outlined), title: const Text('Joining date', mr: 'Joining date'), subtitle: m.Text(joined.isEmpty ? '–' : _dmy(joined)), onTap: () => _date(false)),
          _pick('nef-designation', 'Designation', 'Designation', designation, [for (final x in (widget.setup['designations'] as List? ?? const []).whereType<Map>()) ('${x['id']}', '${x['name']}')], (v) => designation = v),
          _pick('nef-department', 'Department', 'Department', department, [for (final x in (widget.setup['departments'] as List? ?? const []).whereType<Map>()) ('${x['id']}', '${x['name']}')], (v) => department = v),
          _txt('address', 'Address', 'पत्ता', max: 300),
          if (ai.isNotEmpty) Text('Fields marked AI were read from his papers – a suggestion only: look at the paper and check.', mr: 'AI लिहिलेली माहिती कागदावरून वाचलेली आहे – फक्त सूचना: कागद बघून तपासा.', style: TextStyle(fontSize: 12.5, color: sk.muted, height: 1.35)),
        ];
      case 3:
        return [
          m.Text(_t('Site: ${widget.setup['site'] ?? ''}', 'Site: ${widget.setup['site'] ?? ''}'), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: sk.ink)),
          const SizedBox(height: 10),
          Text('Where may he punch?', mr: 'तो कुठे punch करू शकतो?', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: sk.muted)),
          const SizedBox(height: 6),
          Wrap(spacing: 8, children: [
            stateChip(_t('All places of the site', 'Site ची सगळी ठिकाणं'), selected ? '' : 'w', key: const Key('nef-all'), onTap: () => setState(() => selected = false)),
            stateChip(_t('Selected places', 'निवडलेली ठिकाणं'), selected ? 'w' : '', key: const Key('nef-sel'), onTap: () => setState(() => selected = true)),
          ]),
          if (selected)
            for (final x in (widget.setup['places'] as List? ?? const []).whereType<Map>())
              CheckboxListTile(key: Key('nef-place-${x['id']}'), dense: true, contentPadding: EdgeInsets.zero, controlAffinity: ListTileControlAffinity.leading, value: places.contains('${x['id']}'), title: m.Text('${x['name']}'), onChanged: (v) => setState(() => v == true ? places.add('${x['id']}') : places.remove('${x['id']}'))),
          const SizedBox(height: 8),
          Text('Reporting persons (one or many)', mr: 'Reporting persons (एक किंवा अनेक)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: sk.muted)),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final (i, r) in rep.indexed) stateChip('${i + 1}. ${r['name']}  ×', '', key: Key('nef-rep-$i'), onTap: () => setState(() => rep.removeAt(i))),
            if (rep.length < 5) stateChip(_t('+ Add', '+ जोडा'), 'w', key: const Key('nef-rep-add'), onTap: _addRep),
          ]),
        ];
      default:
        return [
          _txt('email', 'E-mail (his sign-in)', 'E-mail (त्याचा sign-in)', type: TextInputType.emailAddress, max: 120),
          _txt('whatsapp', 'WhatsApp number', 'WhatsApp number', type: TextInputType.phone, max: 10),
          Text('Goes to', mr: 'कोणाकडे जाईल', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: sk.muted)),
          for (final (i, g) in (widget.setup['goes_to'] as List? ?? const []).whereType<Map>().indexed)
            Padding(padding: const EdgeInsets.only(top: 6), child: Row(children: [stateChip('Step ${i + 1}', g['stage'] == 'verify' ? 'w' : 'a'), const SizedBox(width: 8), Expanded(child: m.Text('${g['stage'] == 'verify' ? 'Verifies' : 'Approves'} – ${g['name']}', style: TextStyle(fontSize: 13, color: sk.ink)))])),
          const SizedBox(height: 10),
          Text('After the last approval his employee code and his sign-in are made, and the e-mail with his sign-in goes to him.', mr: 'शेवटच्या approval नंतर त्याचा employee code आणि sign-in बनतो, आणि sign-in चा mail त्याला जातो.', style: TextStyle(fontSize: 12.5, color: sk.muted, height: 1.35)),
        ];
    }
  }

  Future<void> _addRep() async {
    final found = <Map>[];
    Timer? wait;
    final p = await showModalBottomSheet<Map>(
      context: context,
      isScrollControlled: true,
      builder: (b) => StatefulBuilder(
        builder: (b, set) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 14 + MediaQuery.viewInsetsOf(b).bottom),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                key: const Key('nef-rep-q'),
                autofocus: true,
                decoration: InputDecoration(hintText: _t('Search a person (any site)', 'व्यक्ती शोधा (कोणतीही site)'), prefixIcon: const Icon(Icons.search_rounded), border: const OutlineInputBorder()),
                onChanged: (v) {
                  wait?.cancel();
                  wait = Timer(const Duration(milliseconds: 300), () async {
                    if (v.trim().length < 2) return;
                    try {
                      final r = await widget.ask({'action': 'apprPick', 'q': v.trim(), 'any': 1});
                      set(() {
                        found
                          ..clear()
                          ..addAll((r['people'] as List? ?? const []).whereType<Map>().take(12));
                      });
                    } catch (_) {}
                  });
                },
              ),
              Flexible(child: ListView(shrinkWrap: true, children: [for (final x in found) ListTile(key: Key('nef-rep-${x['id']}'), dense: true, title: m.Text('${x['name']}'), subtitle: m.Text('${x['code']} · ${x['site']}'), onTap: () => Navigator.pop(b, x))])),
            ]),
          ),
        ),
      ),
    );
    if (p != null && mounted && !rep.any((y) => y['id'] == p['id'])) setState(() => rep.add(p));
  }

  @override
  Widget build(BuildContext context) {
    const names = [('Papers', 'कागद'), ('Details', 'माहिती'), ('Work', 'काम'), ('Send', 'पाठवा')];
    return Scaffold(
      appBar: hrHead(context, sky: kMeSky, title: 'Add employee', mr: 'Employee जोडा', height: 64),
      body: ListView(key: const Key('nef-page'), padding: const EdgeInsets.fromLTRB(16, 14, 16, 40), children: [
        Row(children: [
          for (final (i, n) in names.indexed)
            Expanded(
              child: GestureDetector(
                key: Key('nef-step-${i + 1}'),
                onTap: () => setState(() => step = i + 1),
                child: Container(
                  margin: EdgeInsets.only(right: i == 3 ? 0 : 6),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: step == i + 1 ? const Color(0xFF0F1F3D) : i + 1 < step ? const Color(0xFFE3F4EA) : (sk.dark ? const Color(0xFF1B2437) : const Color(0xFFE6E9F2)), borderRadius: BorderRadius.circular(10)),
                  child: m.Text('${i + 1} ${_t(n.$1, n.$2)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: step == i + 1 ? Colors.white : i + 1 < step ? const Color(0xFF14673A) : sk.muted)),
                ),
              ),
            ),
        ]),
        const SizedBox(height: 12),
        _tapCard(key: Key('nef-step$step'), _stepBody()),
        if (err.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: InfoLine(err, bad: true, help: false, key: const Key('nef-err'))),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: OutlinedButton(
              key: const Key('nef-save'),
              onPressed: busy
                  ? null
                  : () async {
                      setState(() => err = '');
                      if (await _save() && context.mounted) toast(context, _t('Draft saved.', 'Draft save झाला.'));
                    },
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              child: const Text('Save draft', mr: 'Draft save करा'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton(
              key: const Key('nef-next'),
              onPressed: busy ? null : (step < 4 ? () => setState(() => step++) : _send),
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
              child: Text(step < 4 ? 'Next' : 'Send for verification', mr: step < 4 ? 'पुढे' : 'Verification ला पाठवा'),
            ),
          ),
        ]),
      ]),
    );
  }
}
