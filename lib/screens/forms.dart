/* NEW ENTRY – Diesel Issue, Diesel Inward, Diesel Transfer: the same fields and the same server checks as the web pages. The
 * server decides everything (stock, closed month, bill lock, an active machinery, readings); the app shows its answer. A
 * reading that looks wrong comes back as a question – "Save anyway?" – as on the web. Diesel Issue also takes the 4 photos
 * (camera + location), as on the web. */
import 'dart:typed_data';

import 'package:flutter/material.dart' hide Text;
import 'package:flutter/services.dart';

import '../core/format.dart';
import '../core/kinds.dart';
import '../core/photo.dart';
import '../core/session.dart';
import '../ui/scope.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import '../ui/t.dart';

class EntryForm extends StatefulWidget {
  const EntryForm({super.key, required this.kind, this.edit});
  final Kind kind;

  /// An entry being changed (as in the list); null = a new one.
  final Map<String, dynamic>? edit;
  @override
  State<EntryForm> createState() => _EntryFormState();
}

class _Shot {
  Uint8List? jpg;
  String path = '';
  bool busy = false;
}

class _EntryFormState extends State<EntryForm> {
  String date = '', shift = 'Day', source = '', from = '', to = '', way = '';
  Machine? machine;
  final qty = TextEditingController(), km = TextEditingController(), hr = TextEditingController(), driver = TextEditingController(), remark = TextEditingController();
  final pump = TextEditingController(), rate = TextEditingController(), billNo = TextEditingController();
  String billDate = '';
  Map<String, dynamic>? bal; // stock at the source for this date + shift (issue)
  final shots = <String, _Shot>{};
  bool busy = false, savedOne = false;
  String err = '';
  int balSeq = 0;

  // what the AI read on the photos (dashboard → the reading, dispenser → the litres), as on the web (update-85 / 87)
  final ai = <String, Map<String, dynamic>>{}; // dash / pump → its answer ({wait: true} while reading)
  final aiPut = <TextEditingController>{}; // boxes the AI filled (typing over one makes it the person's)
  int aiTok = 0;

  Kind get k => widget.kind;
  bool get issue => k.key == 'issue';
  Map<String, dynamic>? get ed => widget.edit;
  String get editId => '${ed?['id'] ?? ''}';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final s = SessionScope.read(context);
    if (source.isEmpty) {
      date = s.today.isNotEmpty ? s.today : dateKey(DateTime.now());
      // his usual diesel place and shift (Settings)
      final loc = s.pref('loc');
      source = s.locations.contains(loc) ? loc : (s.locations.isNotEmpty ? s.locations.first : 'Dispenser');
      from = source;
      to = s.locations.firstWhere((l) => l != from, orElse: () => '');
      shift = s.myShift(const ['Day', 'Night']); // (14-10-2026) his usual shift, else Day / Night by the time
      final e = ed;
      if (e != null) _fillFrom(s, e);
      if (issue) WidgetsBinding.instance.addPostFrameCallback((_) => _balance());
    }
  }

  /// An entry being changed: its values in the boxes.
  void _fillFrom(Session s, Map<String, dynamic> e) {
    String v(String key) => '${e[key] ?? ''}';
    if (v('date').isNotEmpty) date = v('date');
    if (v('shift').isNotEmpty) shift = v('shift');
    qty.text = v('qty');
    remark.text = v('remark');
    switch (k.key) {
      case 'issue':
        source = v('source').isEmpty ? source : v('source');
        machine = s.machine(v('no'));
        final m = machine;
        // the way it was measured: as saved, else from its readings (KM, Hrs or both), else the machinery's own
        final both = v('kmReading').isNotEmpty && v('hrReading').isNotEmpty;
        final guess = both ? 'KM + Hrs' : v('kmReading').isNotEmpty ? 'KM' : v('hrReading').isNotEmpty ? 'Hrs' : '';
        way = v('mode').isNotEmpty ? v('mode') : (m != null && m.modes.contains(guess) ? guess : (m?.wayAuto ?? ''));
        km.text = v('kmReading');
        hr.text = v('hrReading');
        driver.text = v('driver');
      case 'inward':
        source = v('location').isEmpty ? source : v('location');
        pump.text = v('pump');
        rate.text = v('rate');
        billNo.text = v('billNo');
        billDate = v('billDate');
      default:
        from = v('from').isEmpty ? from : v('from');
        to = v('to').isEmpty ? to : v('to');
    }
  }

  @override
  void dispose() {
    for (final c in [qty, km, hr, driver, remark, pump, rate, billNo]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _balance() async {
    if (!issue) return;
    final s = SessionScope.read(context), my = ++balSeq;
    setState(() => bal = null);
    try {
      final r = (await s.api.call('getIssueBalance', [date, shift, editId, source]) as Map).cast<String, dynamic>();
      if (my == balSeq && mounted) setState(() => bal = r);
    } catch (_) {/* the server checks the stock at the save anyway */}
  }

  Future<void> _pickDate({bool bill = false}) async {
    final s = SessionScope.read(context);
    final last = s.today.isNotEmpty ? parseKey(s.today) : DateTime.now();
    final cur = bill ? (billDate.isEmpty ? date : billDate) : date;
    final d = await showDatePicker(context: context, initialDate: parseKey(cur), firstDate: DateTime(2024), lastDate: last);
    if (d == null) return;
    setState(() {
      if (bill) {
        billDate = dateKey(d);
      } else {
        date = dateKey(d);
      }
    });
    if (!bill) _balance();
  }

  Future<void> _pickMachine() async {
    final m = await showModalBottomSheet<Machine>(context: context, isScrollControlled: true, useSafeArea: true, builder: (_) => const MachinePicker());
    if (m == null || !mounted) return;
    setState(() {
      if (machine?.id != m.id) {
        shots.clear(); // the photos belong to one machinery (its number is printed on them)
        km.clear();
        hr.clear();
      }
      machine = m;
      way = m.debit ? '' : m.wayAuto;
    });
  }

  // ---------- photos ----------
  Future<void> _shoot(PhotoKind pk) async {
    final s = SessionScope.read(context), m = machine;
    if (m == null) {
      setState(() => err = 'Pick the machinery first – its number is printed on the photo.');
      return;
    }
    final sh = shots.putIfAbsent(pk.key, _Shot.new);
    if (sh.busy) return;
    setState(() => sh.busy = true);
    try {
      final p = await takePhoto(pk.en, m.id);
      if (p == null || !mounted || machine?.id != m.id) return;
      setState(() => sh.jpg = p.jpg);
      // the AI reads the dashboard (its reading) and the dispenser (its litres) NOW, while the photo is being sent
      if ((pk.key == 'dash' && !m.debit) || pk.key == 'pump') _aiRead(pk.key, m.id, p.jpg);
      final r = (await s.api.call('dieselPhoto', [{'kind': pk.key, 'data': p.dataUrl, 'lat': p.spot.lat, 'lng': p.spot.lng, 'acc': p.spot.acc, 'at': p.at.toUtc().toIso8601String(), 'no': m.id}], true) as Map);
      if (!mounted || machine?.id != m.id) return;
      setState(() => sh.path = (r['path'] ?? '').toString());
    } catch (e) {
      if (mounted) {
        setState(() {
          if (sh.path.isEmpty) sh.jpg = null;
        });
        toast(context, e is PhotoProblem ? e.message : errText(e), bad: true);
      }
    } finally {
      if (mounted) setState(() => sh.busy = false);
    }
  }

  Future<void> _aiRead(String kind, String no, Uint8List jpg) async {
    final s = SessionScope.read(context), tok = ++aiTok;
    setState(() => ai[kind] = {'wait': true});
    Map<String, dynamic> r;
    try {
      r = ((await s.api.call('getMeterReading', [{'kind': kind, 'data': await smallCopy(jpg), 'no': no}])) as Map).cast<String, dynamic>();
    } catch (e) {
      r = {'error': errText(e)};
    }
    if (!mounted || machine?.id != no || tok < aiTok - 4) return;
    setState(() {
      if (r['off'] == true) {
        ai.remove(kind); // the AI is not set up on this site
        return;
      }
      ai[kind] = r;
      void fill(TextEditingController c, dynamic v) {
        final n = asNum(v);
        if (n == null) return;
        if (c.text.isEmpty || aiPut.contains(c)) {
          c.text = fmtNum(n).replaceAll(',', '');
          aiPut.add(c);
        }
      }

      if (kind == 'dash') {
        if (hasKm(way)) fill(km, r['km']);
        if (hasHr(way)) fill(hr, r['hr']);
      } else {
        fill(qty, r['litres']);
      }
    });
  }

  /// The line under the photos: what the AI read, what to check, what it is still reading (as the web).
  String get _aiNote {
    final d = ai['dash'], p = ai['pump'], put = <String>[], warn = <String>[], waiting = <String>[];
    if (d != null) {
      if (d['wait'] == true) {
        waiting.add('the meter');
      } else if (d['error'] != null) {
        warn.add('the meter could not be read now – type the reading');
      } else {
        if (asNum(d['km']) != null) put.add('${fmtNum(asNum(d['km']))} km');
        if (asNum(d['hr']) != null) put.add('${fmtNum(asNum(d['hr']))} hr');
        if ('${d['check'] ?? ''}'.isNotEmpty) warn.add('reading ${d['check']}');
        if (asNum(d['km']) == null && asNum(d['hr']) == null) warn.add('the meter could not be read clearly – type the reading (or take the dashboard photo again, closer)');
      }
    }
    if (p != null) {
      if (p['wait'] == true) {
        waiting.add('the litres');
      } else if (p['error'] != null) {
        warn.add('the litres could not be read now – type the litres');
      } else {
        if (asNum(p['litres']) != null) put.add('${fmtNum(asNum(p['litres']))} L');
        if ('${p['check'] ?? ''}'.isNotEmpty) warn.add('litres: ${p['check']}');
        if (asNum(p['litres']) == null) warn.add('the litres could not be read clearly – type the litres');
      }
    }
    return [
      if (put.isNotEmpty) 'AI read on the photos: ${put.join(' · ')} – check with the photos; type over it if it is wrong.',
      if (warn.isNotEmpty) 'Check: ${warn.join('; ')}.',
      if (waiting.isNotEmpty) 'The AI is reading ${waiting.join(' and ')} on the photo…',
    ].join(' ');
  }

  bool get _photoSending => shots.values.any((x) => x.busy);
  List<Map<String, String>> get _photoList => [for (final pk in kPhotoKinds) if ((shots[pk.key]?.path ?? '').isNotEmpty) {'k': pk.key, 'p': shots[pk.key]!.path}];

  // ---------- save ----------
  Map<String, dynamic> _data() => switch (k.key) {
        'issue' => {
            'date': date, 'shift': shift, 'no': machine?.id ?? '', 'qty': asNum(qty.text) ?? '', 'kmReading': hasKm(way) ? (asNum(km.text) ?? '') : '', 'hrReading': hasHr(way) ? (asNum(hr.text) ?? '') : '',
            'driver': driver.text.trim(), 'remark': remark.text.trim(), 'source': source, 'force': false, 'mode': way,
            if (_photoList.isNotEmpty && ed == null) 'photos': _photoList,
          },
        'inward' => {'date': date, 'location': source, 'pump': pump.text.trim(), 'qty': asNum(qty.text) ?? '', 'rate': asNum(rate.text) ?? '', 'billNo': billNo.text.trim(), 'billDate': billDate},
        _ => {'date': date, 'shift': shift, 'from': from, 'to': to, 'qty': asNum(qty.text) ?? '', 'remark': remark.text.trim()},
      };

  String? _check() {
    if (issue && machine == null) return 'Pick the machinery.';
    if (issue && machine != null && !machine!.debit && machine!.modes.isNotEmpty && way.isEmpty) return 'Pick how the machinery is measured (KM / Hrs …).';
    if (k.key == 'inward' && pump.text.trim().isEmpty) return 'Enter the Pump Name.';
    if (k.key == 'transfer' && from == to) return 'From and To cannot be the same.';
    if (!((asNum(qty.text) ?? 0) > 0)) return 'Enter the litres.';
    if (issue && bal != null && (asNum(qty.text) ?? 0) > (asNum(bal!['available']) ?? double.infinity)) {
      return 'Not enough diesel at $source for ${showDate(date)} ($shift): you can issue up to ${fmtNum(asNum(bal!['available']))} L. Add a Diesel Inward first or reduce the litres.';
    }
    return null;
  }

  Future<void> _save({bool force = false}) async {
    final s = SessionScope.read(context);
    final bad = _check();
    if (bad != null) {
      setState(() => err = bad);
      HapticFeedback.mediumImpact();
      return;
    }
    if (_photoSending) {
      toast(context, 'A photo is still being sent – wait a moment, then save.', bad: true);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      busy = true;
      err = '';
    });
    try {
      final d = _data();
      if (force) d['force'] = true;
      final r = (await (ed == null ? s.api.call(k.save, [d], true) : s.api.call(_updateOf(k.key), [editId, d], true)) as Map).cast<String, dynamic>();
      if (!mounted) return;
      if (r['warning'] != null) {
        setState(() => busy = false);
        if (await ask(context, 'Please check the reading', r['warning'].toString(), yes: 'Save anyway')) await _save(force: true);
        return;
      }
      if (r['stock'] != null) s.setStock(r['stock']);
      if (issue && driver.text.trim().isNotEmpty && !s.drivers.contains(driver.text.trim())) s.drivers.add(driver.text.trim());
      savedOne = true;
      HapticFeedback.lightImpact();
      if (ed != null) {
        if (mounted) {
          toast(context, bi(tr('${k.en} $editId updated.'), 'बदल जतन झाला.'));
          Navigator.pop(context, true);
        }
        return;
      }
      await _savedSheet(r['id']?.toString() ?? '', d);
      if (!mounted) return;
      setState(() {
        busy = false;
        machine = null;
        way = '';
        shots.clear();
        ai.clear();
        aiPut.clear();
        for (final c in [qty, km, hr, remark, rate, billNo]) {
          c.clear();
        }
      });
      _balance();
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          err = errText(e);
        });
      }
    }
  }

  Future<void> _savedSheet(String id, Map<String, dynamic> d) => showModalBottomSheet<void>(
        context: context,
        showDragHandle: false,
        builder: (c) => Padding(
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 520),
              curve: Curves.elasticOut,
              builder: (_, v, ch) => Transform.scale(scale: v, child: ch),
              child: Container(width: 76, height: 76, decoration: BoxDecoration(color: k.soft, shape: BoxShape.circle), child: Icon(Icons.check_rounded, color: k.color, size: 46)),
            ),
            const SizedBox(height: 14),
            TwoLang('${k.en} saved', 'नोंद झाली', size: 21, weight: FontWeight.w700, align: CrossAxisAlignment.center),
            const SizedBox(height: 10),
            Text([id, if ((d['no'] ?? '').toString().isNotEmpty) d['no'].toString(), '${fmtNum(asNum(d['qty']))} L', showDate(d['date']?.toString())].where((e) => e.isNotEmpty).join('  ·  '), textAlign: TextAlign.center, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w500, color: C.muted)),
            if ((d['photos'] as List?)?.isNotEmpty == true) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Photos: ${(d['photos'] as List).length} of 4', style: const TextStyle(color: C.muted))),
            const SizedBox(height: 22),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(c);
                    Navigator.pop(context, true);
                  },
                  child: const Text('Done'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: FilledButton(style: FilledButton.styleFrom(backgroundColor: k.color, minimumSize: const Size.fromHeight(52)), onPressed: () => Navigator.pop(c), child: const Text('One more'))),
            ]),
          ]),
        ),
      );

  // ---------- the pieces of the form ----------
  Widget _label(String en, [String mr = '']) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 8, left: 2),
        child: Row(children: [
          Flexible(child: Text(en, mr: mr, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: C.ink))),
          if (mr.isNotEmpty) MrLine('  $mr', style: const TextStyle(fontFamily: 'NotoDeva', fontSize: 12.5, color: C.muted)),
        ]),
      );

  Widget _chips<T>(List<(T, String)> items, T? value, ValueChanged<T> onPick, {Color? color}) => Wrap(spacing: 8, runSpacing: 8, children: [
        for (final it in items)
          ChoiceChip(
            label: Text(it.$2),
            selected: it.$1 == value,
            onSelected: (_) => onPick(it.$1),
            showCheckmark: false,
            labelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5, color: it.$1 == value ? Colors.white : C.ink),
            selectedColor: color ?? k.color,
            backgroundColor: Colors.white,
            side: BorderSide(color: it.$1 == value ? (color ?? k.color) : C.line),
            shape: const StadiumBorder(),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
      ]);

  Widget _box({required Widget child, VoidCallback? onTap}) => Press(onTap: onTap, radius: 18, shadow: false, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), child: child);

  Widget _dateBox() => _box(
        onTap: _pickDate,
        child: Row(children: [
          const Icon(Icons.calendar_month_rounded, color: C.green),
          const SizedBox(width: 12),
          Expanded(child: Text(showDate(date), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
          if (date == SessionScope.read(context).today) const Pill('Today'),
        ]),
      );

  Widget _qtyField() => Container(
        padding: const EdgeInsets.fromLTRB(18, 6, 18, 6),
        decoration: BoxDecoration(color: aiPut.contains(qty) ? C.blueSoft : Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: aiPut.contains(qty) ? C.blue : C.line)),
        child: Row(children: [
          Pic(k.pic, size: 34),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: qty,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
              onChanged: (_) => setState(() => aiPut.remove(qty)),
              decoration: const InputDecoration(hintText: '0', border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none, filled: false, contentPadding: EdgeInsets.symmetric(vertical: 10)),
            ),
          ),
          const Text('Litre', style: TextStyle(fontSize: 16, color: C.muted, fontWeight: FontWeight.w600)),
        ]),
      );

  Widget _machineBox() {
    final m = machine;
    return _box(
      onTap: _pickMachine,
      child: Row(children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(color: C.greenSoft, borderRadius: BorderRadius.circular(16)),
          alignment: Alignment.center,
          child: m == null ? const Icon(Icons.search_rounded, color: C.green, size: 28) : Pic(picOfType(m.type), size: 42),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: m == null
              ? const TwoLang('Pick the machinery', 'यंत्र निवडा', color: C.muted)
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(m.id, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                  Text([if (m.name.isNotEmpty && m.name != m.id) m.name, m.type, m.owner].where((e) => e.isNotEmpty).join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: C.muted, fontSize: 13.5)),
                ]),
        ),
        const Icon(Icons.unfold_more_rounded, color: C.muted),
      ]),
    );
  }

  Widget _photos() => GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.35,
        children: [
          for (final pk in kPhotoKinds)
            Builder(builder: (_) {
              final sh = shots[pk.key];
              final done = sh != null && sh.path.isNotEmpty && sh.jpg != null;
              return Press(
                onTap: () => _shoot(pk),
                radius: 18,
                shadow: false,
                border: done ? C.green : C.line,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(17),
                  child: Stack(fit: StackFit.expand, children: [
                    if (sh?.jpg != null) Image.memory(sh!.jpg!, fit: BoxFit.cover, gaplessPlayback: true),
                    if (sh?.jpg != null) const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Color(0xAA000000)]))),
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        if (sh?.jpg == null) Pic(pk.pic, size: 34),
                        const Spacer(),
                        Text(pk.en, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: sh?.jpg != null ? Colors.white : C.ink)),
                        Row(children: [
                          Icon(sh?.busy == true ? Icons.cloud_upload_outlined : done ? Icons.check_circle_rounded : Icons.photo_camera_rounded, size: 14, color: sh?.jpg != null ? Colors.white70 : C.green),
                          const SizedBox(width: 4),
                          Text(sh?.busy == true ? 'Sending…' : done ? 'Sent' : 'Take photo', style: TextStyle(fontSize: 12, color: sh?.jpg != null ? Colors.white70 : C.muted)),
                        ]),
                      ]),
                    ),
                    if (sh?.busy == true) const Positioned(right: 10, top: 10, child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))),
                    if (done) const Positioned(right: 8, top: 8, child: CircleAvatar(radius: 12, backgroundColor: C.green, child: Icon(Icons.check_rounded, size: 16, color: Colors.white))),
                  ]),
                ),
              );
            }),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    final q = asNum(qty.text);
    final m = machine;
    final avail = bal == null ? null : asNum(bal!['available']);
    return PopScope(
      canPop: false, // the system Back too says whether something was saved (the list then loads again)
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, savedOne);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => Navigator.pop(context, savedOne)),
          titleSpacing: 0,
          title: Row(children: [
            Pic(k.pic, size: 30),
            const SizedBox(width: 10),
            Expanded(child: TwoLang(ed == null ? 'New ${k.en}' : 'Change $editId', k.mr, size: 19, weight: FontWeight.w700)),
          ]),
        ),
        // one scrolling column (not a lazy list): every field stays built, so nothing typed is lost when it scrolls away
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 130),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _label('Date', 'तारीख'),
            _dateBox(),
            if (k.key != 'inward') ...[
              _label('Shift', 'पाळी'),
              _chips<String>(const [('Day', 'Day'), ('Night', 'Night')], shift, (v) {
                setState(() => shift = v);
                _balance();
              }),
            ],
            // ---------- Diesel Issue ----------
            if (issue) ...[
              if (s.locations.length > 1) ...[
                _label('Diesel from', 'डिझेल कुठून'),
                _chips<String>([for (final l in s.locations) (l, l)], source, (v) {
                  setState(() => source = v);
                  _balance();
                }),
              ],
              _label('Machinery', 'यंत्र'),
              _machineBox(),
              if (m != null && !m.debit && m.modes.isNotEmpty) ...[
                _label('Measured by', 'मोजणी'),
                _chips<String>([for (final w in [...m.modes, if (m.hasMeter) kNoReading]) (w, w)], way, (v) => setState(() => way = v)),
              ],
              if (m != null && hasKm(way)) ...[
                _label('KM reading', 'KM रीडिंग'),
                TextField(controller: km, keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(() => aiPut.remove(km)), decoration: InputDecoration(hintText: tr('Odometer km'), prefixIcon: const Icon(Icons.speed_rounded), fillColor: aiPut.contains(km) ? C.blueSoft : Colors.white, helperText: aiPut.contains(km) ? tr('Read by the AI on the dashboard photo – check it') : null)),
              ],
              if (m != null && hasHr(way)) ...[
                _label('Hour meter', 'तास मीटर'),
                TextField(controller: hr, keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(() => aiPut.remove(hr)), decoration: InputDecoration(hintText: tr('Hours'), prefixIcon: const Icon(Icons.timer_outlined), fillColor: aiPut.contains(hr) ? C.blueSoft : Colors.white, helperText: aiPut.contains(hr) ? tr('Read by the AI on the dashboard photo – check it') : null)),
              ],
              _label('Litres', 'लिटर'),
              _qtyField(),
              const SizedBox(height: 10),
              _chips<num>(const [(20, '20'), (50, '50'), (100, '100'), (150, '150'), (200, '200')], q, (v) => setState(() => qty.text = '$v')),
              if (bal != null)
                InfoLine(
                  q == null || q == 0
                      ? 'Stock at $source on ${showDate(date)} ($shift): ${fmtNum(asNum(bal!['balance']))} L'
                      : (q > (avail ?? double.infinity) ? 'Not enough stock at $source: you can issue up to ${fmtNum(avail)} L.' : 'Stock after this issue: ${fmtNum((asNum(bal!['balance']) ?? 0) - q)} L'),
                  bad: q != null && q > (avail ?? double.infinity),
                ),
              _label('Driver / Operator', 'चालक'),
              Autocomplete<String>(
                optionsBuilder: (v) => v.text.isEmpty ? const Iterable<String>.empty() : s.drivers.where((d) => d.toLowerCase().contains(v.text.toLowerCase())).take(8),
                onSelected: (v) => driver.text = v,
                fieldViewBuilder: (c, ctl, f, sub) => TextField(controller: ctl, focusNode: f, onChanged: (v) => driver.text = v, textCapitalization: TextCapitalization.words, decoration: InputDecoration(hintText: tr('Name (optional)'), prefixIcon: Icon(Icons.person_outline_rounded))),
              ),
              if (s.canEdit('Diesel Issue') && ed == null) ...[
                _label('Photos', 'फोटो'),
                _photos(),
                if (_aiNote.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: C.blueSoft, borderRadius: BorderRadius.circular(14)),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Icon(Icons.auto_awesome_rounded, color: C.blue, size: 20),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_aiNote, style: const TextStyle(fontSize: 13.5, color: C.blue, height: 1.35, fontWeight: FontWeight.w500))),
                    ]),
                  ),
                const Padding(padding: EdgeInsets.only(top: 6, left: 2), child: Text('Taken with the camera now – date, time and place are printed on each photo.', style: TextStyle(fontSize: 12.5, color: C.muted))),
              ],
            ],
            // ---------- Diesel Inward ----------
            if (k.key == 'inward') ...[
              if (s.locations.length > 1) ...[_label('Received at', 'कुठे आले'), _chips<String>([for (final l in s.locations) (l, l)], source, (v) => setState(() => source = v))],
              _label('Pump name', 'पंप'),
              Autocomplete<String>(
                optionsBuilder: (v) => v.text.isEmpty ? s.pumps.take(8) : s.pumps.where((p) => p.toLowerCase().contains(v.text.toLowerCase())).take(8),
                onSelected: (v) => pump.text = v,
                fieldViewBuilder: (c, ctl, f, sub) => TextField(controller: ctl, focusNode: f, onChanged: (v) => pump.text = v, textCapitalization: TextCapitalization.words, decoration: InputDecoration(hintText: tr('Petrol pump'), prefixIcon: Icon(Icons.local_gas_station_outlined))),
              ),
              _label('Litres', 'लिटर'),
              _qtyField(),
              _label('Rate (₹ per litre)', 'दर'),
              TextField(controller: rate, keyboardType: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(() {}), decoration: const InputDecoration(hintText: '0.00', prefixText: '₹ ')),
              if ((asNum(rate.text) ?? 0) > 0 && (q ?? 0) > 0) InfoLine('Amount ₹ ${fmtNum((asNum(rate.text) ?? 0) * (q ?? 0))}', icon: Icons.currency_rupee_rounded),
              _label('Bill number', 'बिल नंबर'),
              TextField(controller: billNo, decoration: InputDecoration(hintText: tr('Optional'))),
              _label('Bill date', 'बिल तारीख'),
              _box(
                onTap: () => _pickDate(bill: true),
                child: Row(children: [
                  const Icon(Icons.event_note_rounded, color: C.blue),
                  const SizedBox(width: 12),
                  Text(billDate.isEmpty ? 'Optional' : showDate(billDate), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: billDate.isEmpty ? C.faint : C.ink)),
                ]),
              ),
            ],
            // ---------- Diesel Transfer ----------
            if (k.key == 'transfer') ...[
              _label('From', 'कुठून'),
              _chips<String>([for (final l in s.locations) (l, l)], from, (v) => setState(() => from = v)),
              _label('To', 'कुठे'),
              _chips<String>([for (final l in s.locations) (l, l)], to, (v) => setState(() => to = v)),
              _label('Litres', 'लिटर'),
              _qtyField(),
            ],
            if (k.key != 'inward') ...[_label('Remark', 'शेरा'), TextField(controller: remark, decoration: InputDecoration(hintText: tr('Optional')))],
            if (err.isNotEmpty) InfoLine(err, bad: true),
          ]),
        ),
        bottomNavigationBar: SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            decoration: BoxDecoration(color: C.bg, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .05), blurRadius: 12, offset: const Offset(0, -4))]),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: k.color),
              onPressed: busy ? null : _save,
              icon: busy ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white)) : const Icon(Icons.check_circle_rounded),
              label: Text(busy ? 'Saving…' : ed == null ? 'Save ${k.en}' : 'Save the change'),
            ),
          ),
        ),
      ),
    );
  }
}

/// The machinery of the site (Active only) – search by number, name, type or owner.
class MachinePicker extends StatefulWidget {
  const MachinePicker({super.key});
  @override
  State<MachinePicker> createState() => _MachinePickerState();
}

class _MachinePickerState extends State<MachinePicker> {
  String q = '';
  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    final list = s.machines.where((m) => m.active && (q.isEmpty || m.matches(q))).take(100).toList();
    return SizedBox(
      height: MediaQuery.of(context).size.height * .86,
      child: Column(children: [
        const Padding(padding: EdgeInsets.fromLTRB(20, 0, 20, 8), child: Align(alignment: Alignment.centerLeft, child: TwoLang('Pick the machinery', 'यंत्र निवडा', size: 20, weight: FontWeight.w700))),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
          child: TextField(autofocus: false, onChanged: (v) => setState(() => q = v), decoration: InputDecoration(hintText: tr('Number, name, type or owner'), prefixIcon: const Icon(Icons.search_rounded), fillColor: C.bg, enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none))),
        ),
        Expanded(
          child: list.isEmpty
              ? const EmptyState('Nothing found', 'Try a part of the number.', pic: 'construction')
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final m = list[i];
                    return Press(
                      onTap: () => Navigator.pop(context, m),
                      radius: 18,
                      shadow: false,
                      padding: const EdgeInsets.all(10),
                      child: Row(children: [
                        Container(width: 52, height: 52, decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(14)), alignment: Alignment.center, child: Pic(picOfType(m.type), size: 40)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(m.id, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                            Text([if (m.name.isNotEmpty && m.name != m.id) m.name, m.type, m.owner].where((e) => e.isNotEmpty).join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: C.muted, fontSize: 13)),
                          ]),
                        ),
                        if (m.debit) const Pill('Debit', color: C.amber, bg: C.amberSoft),
                      ]),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}

String _updateOf(String kind) => switch (kind) { 'issue' => 'updateDieselIssue', 'inward' => 'updateInward', _ => 'updateTransfer' };
String deleteOf(String kind) => switch (kind) { 'issue' => 'deleteDieselIssue', 'inward' => 'deleteInward', _ => 'deleteTransfer' };

/// Changes an entry of [k] (from the list); true when it was changed.
Future<bool> changeEntry(BuildContext context, Kind k, Map<String, dynamic> row) async => await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => EntryForm(kind: k, edit: row))) ?? false;

/// Opens a new entry of [k]; true when something was saved.
Future<bool> newEntry(BuildContext context, Kind k) async => await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => EntryForm(kind: k))) ?? false;
