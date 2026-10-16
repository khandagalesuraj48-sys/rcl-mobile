/* MY SETTINGS (asked 14-10-2026: "app madhe user setting banwaychi aahe, user default site set karu shakel, bakiche sagle
 * settings"): the same settings as the web's Settings page, kept with his account (the web and the app use the same ones) –
 * default site, usual shift, usual diesel place, the usual way of the Log Book entry, size of the text, mobile number,
 * photo – and his password (the Portal's, for every module). Every change is saved at once. */
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart' hide Text;
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../core/session.dart';
import 'start_page.dart' show startPagesFor;
import '../ui/scope.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import '../ui/t.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String busy = '';

  Future<void> _save(String what, Future<void> Function() fn, [String done = 'Saved.']) async {
    setState(() => busy = what);
    try {
      await fn();
      if (mounted) toast(context, bi(tr(done), 'जतन झाले.'));
    } catch (e) {
      if (mounted) toast(context, errText(e), bad: true);
    } finally {
      if (mounted) setState(() => busy = '');
    }
  }

  Future<String?> _pick(String title, List<(String, String)> items, String cur) => showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        builder: (c) => SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(c).size.height * .7),
            child: ListView(shrinkWrap: true, padding: const EdgeInsets.only(bottom: 12), children: [
              Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 8), child: Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700))),
              for (final it in items)
                ListTile(
                  leading: Icon(it.$1 == cur ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: C.green),
                  title: Text(it.$2, style: const TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () => Navigator.pop(c, it.$1),
                ),
            ]),
          ),
        ),
      );

  Future<void> _password() async {
    final old = TextEditingController(), now = TextEditingController(), again = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Change password'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: old, obscureText: true, decoration: InputDecoration(labelText: tr('Current password'))),
          const SizedBox(height: 10),
          TextField(controller: now, obscureText: true, decoration: InputDecoration(labelText: tr('New password'))),
          const SizedBox(height: 10),
          TextField(controller: again, obscureText: true, decoration: InputDecoration(labelText: tr('New password again'))),
          const SizedBox(height: 8),
          const Text('One password for the Portal and every module.', style: TextStyle(fontSize: 12.5, color: C.muted)),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')), FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(110, 46)), onPressed: () => Navigator.pop(c, true), child: const Text('Change'))],
      ),
    );
    if (ok != true || !mounted) return;
    if (now.text != again.text) {
      toast(context, 'The two new passwords are not the same.', bad: true);
      return;
    }
    final s = SessionScope.read(context);
    await _save('pw', () => s.changePassword(old.text, now.text), 'Password changed');
  }

  Future<void> _photo() async {
    final s = SessionScope.read(context);
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 400, maxHeight: 400, imageQuality: 85);
    if (x == null) return;
    final raw = await x.readAsBytes();
    final im = img.decodeImage(raw);
    if (im == null) {
      if (mounted) toast(context, 'This picture cannot be read.', bad: true);
      return;
    }
    final sq = img.copyResizeCropSquare(im, size: 160);
    var q = 82;
    Uint8List jpg = img.encodeJpg(sq, quality: q);
    while (base64Encode(jpg).length > 60000 && q > 40) {
      q -= 10;
      jpg = img.encodeJpg(sq, quality: q);
    }
    await _save('photo', () => s.savePrefs({'photo': 'data:image/jpeg;base64,${base64Encode(jpg)}'}), 'Photo saved');
  }

  /// (3.14.0) The web's "Back to the usual settings": every setting as the app comes – his photo and mobile number stay.
  static const kPrefDefault = <String, dynamic>{
    'theme': 'light', 'text': 'normal', 'density': 'normal', 'lang': 'mr', 'appLang': '', 'lbMode': '', 'lbDays': '2', 'shift': '', 'menu': 'open', //
    'enterNext': false, 'sound': false, 'lessMotion': false, 'intro': true, 'brief': true, 'voiceOut': true, 'start': '', 'loc': '', 'fav': <String>[],
  };

  Future<void> _reset() async {
    final s = SessionScope.read(context);
    if (!await ask(context, 'Back to the usual settings?', 'Theme, text size, language, first page, usual shift / location and favourites go back to how the app comes. Your photo and mobile number stay.', yes: 'Reset')) return;
    await _save('reset', () => s.savePrefs({...kPrefDefault, 'photo': s.pref('photo'), 'mobile': s.pref('mobile')}));
  }

  /// A sign-in time as the web shows it: "16 Oct 2026, 09:05" on the phone's clock.
  static String loginText(String at) {
    final t = DateTime.tryParse(at)?.toLocal();
    if (t == null) return '';
    const mon = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(t.day)} ${mon[t.month - 1]} ${t.year}, ${two(t.hour)}:${two(t.minute)}';
  }

  Future<void> _mobile() async {
    final s = SessionScope.read(context);
    final c = TextEditingController(text: s.pref('mobile'));
    final v = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Mobile number'),
        content: TextField(controller: c, keyboardType: TextInputType.phone, maxLength: 10, decoration: InputDecoration(hintText: tr('10 digits'))),
        actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')), FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(110, 46)), onPressed: () => Navigator.pop(d, c.text.trim()), child: const Text('Save'))],
      ),
    );
    if (v != null) await _save('mobile', () => s.savePrefs({'mobile': v}));
  }

  Widget _row({required IconData icon, required Color color, required String en, required String mr, required String value, VoidCallback? onTap, String id = ''}) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Press(
          onTap: busy.isEmpty ? onTap : null,
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: Row(children: [
            Container(width: 46, height: 46, decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: color)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(en, mr: mr, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600)),
                MrLine(mr, style: const TextStyle(fontFamily: 'NotoDeva', fontSize: 12.5, color: C.muted)),
                if (value.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 3), child: Text(value, style: const TextStyle(fontSize: 13.5, color: C.greenDark, fontWeight: FontWeight.w600))),
              ]),
            ),
            busy == id && id.isNotEmpty ? const Padding(padding: EdgeInsets.all(6), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5))) : const Icon(Icons.chevron_right_rounded, color: C.faint),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    String nameOf(String code) => code.isEmpty ? 'Ask me / last one' : s.sites.firstWhere((x) => x.code == code, orElse: () => SiteChoice(code, code, '', [])).name;
    const ways = [('', 'Ask me each time'), ('date', 'One date – many machinery'), ('mach', 'One machinery – many dates')];
    const sizes = [('normal', 'Normal'), ('large', 'Large'), ('xlarge', 'Larger')];
    const days = [('2', 'Last 2 days'), ('7', 'Last 7 days'), ('30', 'Last 30 days')];
    final lbDays = s.pref('lbDays').isEmpty ? '2' : s.pref('lbDays'), start = s.pref('start');
    final starts = [('', 'Dashboard (as usual)'), for (final p in startPagesFor(s)) (p.$1, p.$2)];
    final shift = s.pref('shift'), loc = s.pref('loc'), lb = s.pref('lbMode'), text = s.pref('text').isEmpty ? 'normal' : s.pref('text');
    return Scaffold(
      appBar: AppBar(title: const TwoLang('My settings', 'माझ्या सेटिंग्ज', size: 20, weight: FontWeight.w700)),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 30), children: [
        Center(
          child: GestureDetector(
            onTap: _photo,
            child: Stack(children: [
              CircleAvatar(
                radius: 46,
                backgroundColor: C.green,
                backgroundImage: s.pref('photo').startsWith('data:image') ? MemoryImage(base64Decode(s.pref('photo').split(',').last)) : null,
                child: s.pref('photo').startsWith('data:image') ? null : Text(s.name.isEmpty ? '?' : s.name[0].toUpperCase(), style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w800, color: Colors.white)),
              ),
              const Positioned(right: 0, bottom: 0, child: CircleAvatar(radius: 15, backgroundColor: Colors.white, child: Icon(Icons.edit_rounded, size: 17, color: C.green))),
            ]),
          ),
        ),
        const SizedBox(height: 8),
        Center(child: Text(s.name, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700))),
        Center(child: Text(s.email, style: const TextStyle(color: C.muted))),
        const SizedBox(height: 18),
        _row(
          id: 'site',
          icon: Icons.location_on_rounded,
          color: C.green,
          en: 'Default site',
          mr: 'नेहमीची site',
          value: nameOf(s.defaultSite),
          onTap: () async {
            final v = await _pick(bi('Default site', 'नेहमीची site'), [('', 'Ask me / the last one'), for (final x in s.sites) (x.code, x.name)], s.defaultSite);
            if (v != null && v != s.defaultSite) await _save('site', () => s.setDefaultSite(v));
          },
        ),
        _row(
          id: 'shift',
          icon: Icons.wb_twilight_rounded,
          color: C.amber,
          en: 'My usual shift',
          mr: 'नेहमीची पाळी',
          value: shift.isEmpty ? 'Automatic' : shift,
          onTap: () async {
            final v = await _pick('My usual shift', const [('', 'Automatic – Day / Night by the time'), ('Full Day', 'Full Day'), ('Day', 'Day'), ('Night', 'Night')], shift);
            if (v != null && v != shift) await _save('shift', () => s.savePrefs({'shift': v}));
          },
        ),
        _row(
          id: 'loc',
          icon: Icons.local_gas_station_rounded,
          color: C.green,
          en: 'My usual diesel place',
          mr: 'नेहमीचे डिझेल ठिकाण',
          value: loc.isEmpty ? 'None' : loc,
          onTap: () async {
            final v = await _pick('My usual diesel place', [('', 'None'), for (final l in s.locations) (l, l)], loc);
            if (v != null && v != loc) await _save('loc', () => s.savePrefs({'loc': v}));
          },
        ),
        _row(
          id: 'lb',
          icon: Icons.menu_book_rounded,
          color: C.blue,
          en: 'Log Book entry – usual way',
          mr: 'लॉगबुक – नेहमीची पद्धत',
          value: ways.firstWhere((w) => w.$1 == lb, orElse: () => ways.first).$2,
          onTap: () async {
            final v = await _pick('Log Book entry – usual way', ways, lb);
            if (v != null && v != lb) await _save('lb', () => s.savePrefs({'lbMode': v}));
          },
        ),
        _row(
          id: 'lbdays',
          icon: Icons.date_range_rounded,
          color: C.blue,
          en: 'Log Book list shows',
          mr: 'लॉगबुक यादी दाखवते',
          value: days.firstWhere((w) => w.$1 == lbDays, orElse: () => days.first).$2,
          onTap: () async {
            final v = await _pick('Log Book list shows', days, lbDays);
            if (v != null && v != lbDays) await _save('lbdays', () => s.savePrefs({'lbDays': v}));
          },
        ),
        _row(
          id: 'start',
          icon: Icons.flag_rounded,
          color: C.green,
          en: 'Page to open after sign-in',
          mr: 'sign-in नंतर उघडणारे पान',
          value: starts.firstWhere((w) => w.$1 == start, orElse: () => starts.first).$2,
          onTap: () async {
            final v = await _pick('Page to open after sign-in', starts, start);
            if (v != null && v != start) await _save('start', () => s.savePrefs({'start': v}));
          },
        ),
        // (3.15.0) the assistant's daily summary (the web's Settings: "Show me the daily summary when I open the app (once a day)")
        _row(
          id: 'brief',
          icon: Icons.wb_sunny_rounded,
          color: C.amber,
          en: 'Daily summary when I open the app',
          mr: 'ॲप उघडल्यावर रोजचा सारांश',
          value: s.prefs['brief'] == false ? 'No' : 'Yes – once a day',
          onTap: () async {
            final cur = s.prefs['brief'] == false ? 'off' : 'on';
            final v = await _pick('Show me the daily summary when I open the app (once a day)', const [('on', 'Yes – once a day'), ('off', 'No')], cur);
            if (v != null && v != cur) await _save('brief', () => s.savePrefs({'brief': v == 'on'}));
          },
        ),
        _row(
          id: 'voice',
          icon: Icons.record_voice_over_rounded,
          color: C.blue,
          en: 'Speak the answer aloud when I ask by voice',
          mr: 'मी आवाजाने विचारल्यावर उत्तर मोठ्याने बोला',
          value: s.prefs['voiceOut'] == false ? 'No' : 'Yes',
          onTap: () async {
            final cur = s.prefs['voiceOut'] == false ? 'off' : 'on';
            final v = await _pick('Speak the answer aloud when I ask by voice', const [('on', 'Yes'), ('off', 'No')], cur);
            if (v != null && v != cur) await _save('voice', () => s.savePrefs({'voiceOut': v == 'on'}));
          },
        ),
        _row(
          id: 'text',
          icon: Icons.format_size_rounded,
          color: C.purple,
          en: 'Size of the text',
          mr: 'अक्षरांचा आकार',
          value: sizes.firstWhere((w) => w.$1 == text, orElse: () => sizes.first).$2,
          onTap: () async {
            final v = await _pick('Size of the text', sizes, text);
            if (v != null && v != text) await _save('text', () => s.savePrefs({'text': v}));
          },
        ),
        // (15-10-2026) the language of the whole app – the same at all his sites and on the web
        _row(
          id: 'lang',
          icon: Icons.translate_rounded,
          color: C.blue,
          en: 'App language',
          mr: 'ॲपची भाषा',
          value: const {'mr': 'मराठी', 'hi': 'हिंदी', 'en': 'English'}[Lang.i.code] ?? 'English + मराठी',
          onTap: () async {
            final cur = Lang.i.code;
            final v = await _pick(bi('App language', 'ॲपची भाषा'), const [('mr', 'मराठी'), ('hi', 'हिंदी'), ('en', 'English')], cur);
            if (v != null && v != cur) await _save('lang', () => s.setLanguage(v));
          },
        ),
        _row(id: 'mobile', icon: Icons.phone_iphone_rounded, color: C.slate, en: 'Mobile number', mr: 'मोबाईल नंबर', value: s.pref('mobile').isEmpty ? 'Not set' : s.pref('mobile'), onTap: _mobile),
        _row(id: 'photo', icon: Icons.account_circle_rounded, color: C.orange, en: 'My photo', mr: 'माझा फोटो', value: s.pref('photo').isEmpty ? 'Not set' : 'Set', onTap: _photo),
        _row(id: 'pw', icon: Icons.password_rounded, color: C.red, en: 'Change password', mr: 'पासवर्ड बदला', value: '', onTap: _password),
        // (3.14.0) his last sign-ins (the web's "My last sign-ins")
        Container(
          key: const Key('set-logins'),
          margin: const EdgeInsets.only(top: 4, bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: C.line)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('My last sign-ins', style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            if (s.logins.isEmpty) Text('–', style: const TextStyle(color: C.muted)),
            for (final x in s.logins) if (loginText(x).isNotEmpty) Text(loginText(x), style: const TextStyle(fontSize: 13.5, color: C.muted)),
            const SizedBox(height: 6),
            Text('A sign-in that was not yours? Change your password at once – that signs every other device out.', style: const TextStyle(fontSize: 12.5, color: C.muted)),
          ]),
        ),
        OutlinedButton.icon(key: const Key('set-reset'), onPressed: busy.isEmpty ? _reset : null, icon: const Icon(Icons.restart_alt_rounded), label: Text('Back to the usual settings')),
        const Padding(padding: EdgeInsets.fromLTRB(4, 8, 4, 0), child: Text('These settings are kept with your account – the web ERP uses the same ones.', style: TextStyle(fontSize: 12.5, color: C.muted))),
      ]),
    );
  }
}
