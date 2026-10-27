/* (3.45.0, Mechanical update-164, asked 27-10-2026: "ho madhe diesel stock hot nahi ek card dilelel aahet … mi card cha opening balance
 * takel nantr apli system auto amount debit dakhwel … card war payment kel tri detail madhe payment entry card war add krta yawi")
 * FUEL CARDS – the app's own screen of the web's page Fuel Cards, at a site on fuel cards (HO): every card with its balance (opening +
 * the payments onto it − the fills paid by it, each from its opening date), a card added or changed (only the last 4 digits – never
 * the whole number), the payments / recharges onto a card with photos of the receipt, and a card's statement. The same server
 * actions, checks and access as the web: getCards, saveCard, getCardPayments, saveCardPayment, updateCardPayment, deleteCardPayment,
 * cardPhoto, getCardPayPhotos, cardStatement. */
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart' hide Text;

import '../core/format.dart';
import '../core/photo.dart' show pickBills, PhotoProblem;
import '../core/session.dart';
import '../ui/ask_bot.dart';
import '../ui/fields.dart';
import '../ui/help.dart' show GuideButton;
import '../ui/scope.dart';
import '../ui/t.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

const kCardTypes = ['Fuel card', 'Credit card', 'Debit card'];

/// A card's balance as the app shows it everywhere
String rupees(num? n) => '₹ ${fmtNum(n ?? 0)}';

class FuelCardsScreen extends StatefulWidget {
  const FuelCardsScreen({super.key});
  @override
  State<FuelCardsScreen> createState() => _FuelCardsScreenState();
}

class _FuelCardsScreenState extends State<FuelCardsScreen> {
  bool loading = true;
  String err = '', from = '', to = '';
  List<Map<String, dynamic>> pays = [];
  num payTotal = 0;
  int _seq = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (from.isNotEmpty) return;
    final s = SessionScope.read(context);
    to = s.today.isNotEmpty ? s.today : dateKey(DateTime.now());
    from = '${to.substring(0, 8)}01';
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final s = SessionScope.read(context), my = ++_seq;
    setState(() {
      loading = true;
      err = '';
    });
    try {
      final c = (await s.api.call('getCards') as Map).cast<String, dynamic>();
      final p = (await s.api.call('getCardPayments', [{'from': from, 'to': to}]) as Map).cast<String, dynamic>();
      if (my != _seq || !mounted) return;
      s.setCards(c['cards']);
      setState(() {
        pays = [for (final x in (p['rows'] as List? ?? const []).whereType<Map>()) x.cast<String, dynamic>()];
        payTotal = asNum(p['total']) ?? 0;
        loading = false;
      });
    } catch (e) {
      if (my != _seq || !mounted) return;
      setState(() {
        loading = false;
        err = errText(e);
      });
    }
  }

  Future<void> _open(Widget page) async {
    final r = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => page));
    if (r == true && mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context), can = s.canEdit('Fuel Cards');
    return Scaffold(
      appBar: AppBar(
        title: const TwoLang('Fuel Cards', 'फ्युएल कार्ड', size: 20, weight: FontWeight.w700),
        actions: withAsk([const GuideButton('cards'), IconButton(tooltip: tr('Refresh'), onPressed: _load, icon: const Icon(Icons.refresh_rounded))]),
      ),
      floatingActionButton: can ? FloatingActionButton.extended(key: const Key('fc-add'), onPressed: () => _open(const CardForm()), icon: const Icon(Icons.add_card_rounded), label: Text('Card')) : null,
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(key: const Key('fc-list'), padding: const EdgeInsets.fromLTRB(16, 10, 16, 100), children: [
          Text('Balance = opening + payments onto the card − the fills paid by it. A fill is entered in Diesel Issue with its card and ₹.', style: const TextStyle(fontSize: 12.5, color: C.muted, height: 1.35)),
          const SizedBox(height: 10),
          if (err.isNotEmpty) InfoLine(err, bad: true),
          if (!loading && s.cards.isEmpty) const EmptyState('No fuel card yet', 'Add the cards of this site – name, last 4 digits, opening balance.', pic: 'ledger'),
          for (final c in s.cards) Padding(padding: const EdgeInsets.only(bottom: 10), child: CardTile(c, onTap: () => _cardSheet(c, can))),
          FormHead('Payments onto the cards', sub: '${showDate(from)} – ${showDate(to)} · ${pays.length} · ${rupees(payTotal)}'),
          Row(children: [
            Expanded(child: DateField(key: const Key('fc-from'), label: 'From', value: from, clear: false, onChanged: (v) { setState(() => from = v); _load(); })),
            const SizedBox(width: 8),
            Expanded(child: DateField(key: const Key('fc-to'), label: 'To', value: to, clear: false, onChanged: (v) { setState(() => to = v); _load(); })),
          ]),
          const SizedBox(height: 8),
          if (can && s.cards.isNotEmpty) OutlinedButton.icon(key: const Key('fc-pay'), onPressed: () => _open(const PayForm()), icon: const Icon(Icons.add_rounded), label: Text('Payment onto a card')),
          if (loading) const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator())),
          if (!loading && pays.isEmpty) Padding(padding: const EdgeInsets.all(14), child: Text('No payment onto a card in these dates.', style: const TextStyle(color: C.muted))),
          for (final p in pays)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Press(
                key: Key('fc-p-${p['id']}'),
                onTap: () => _paySheet(p, can),
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  const Icon(Icons.account_balance_wallet_rounded, color: C.green),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${p['card']}', style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
                    Text([showDate('${p['date']}'), '${p['id']}', if ('${p['ref'] ?? ''}'.isNotEmpty) '${p['ref']}', if ((asNum(p['photos']) ?? 0) > 0) '📷 ${p['photos']}'].join(' · '), style: const TextStyle(fontSize: 12.5, color: C.muted)),
                  ])),
                  Text(rupees(asNum(p['amount'])), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: C.greenDark)),
                ]),
              ),
            ),
        ]),
      ),
    );
  }

  Future<void> _cardSheet(FuelCard c, bool can) async {
    final v = await showModalBottomSheet<String>(
      context: context,
      builder: (bc) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(c.name, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            InfoRow('Kind', [c.type, if (c.last4.isNotEmpty) '···· ${c.last4}', if (!c.active) 'Inactive'].join(' · ')),
            InfoRow('Cars', c.cars.isEmpty ? tr('every car') : c.cars.join(', ')),
            InfoRow('Opening', '${rupees(c.opening)} · ${showDate(c.openDate)}'),
            InfoRow('Paid in', rupees(c.paid)),
            InfoRow('Fuel', rupees(c.spent)),
            InfoRow('Balance', rupees(c.balance), tone: c.balance < 0 ? C.red : C.greenDark, bold: true),
            const SizedBox(height: 12),
            FilledButton.icon(key: const Key('fc-st'), onPressed: () => Navigator.pop(bc, 'st'), icon: const Icon(Icons.receipt_long_rounded), label: Text('Statement')),
            if (can) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(key: const Key('fc-edit'), onPressed: () => Navigator.pop(bc, 'edit'), icon: const Icon(Icons.edit_rounded), label: Text('Change card')),
            ],
          ]),
        ),
      ),
    );
    if (!mounted) return;
    if (v == 'st') await _open(StatementScreen(card: c.name));
    if (v == 'edit') await _open(CardForm(card: c));
  }

  Future<void> _paySheet(Map<String, dynamic> p, bool can) async {
    final v = await showModalBottomSheet<String>(
      context: context,
      builder: (bc) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('${p['id']} · ${rupees(asNum(p['amount']))}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            InfoRow('Card', '${p['card']}'),
            InfoRow('Date', showDate('${p['date']}')),
            InfoRow('Reference', '${p['ref'] ?? ''}'),
            InfoRow('Remark', '${p['remark'] ?? ''}'),
            InfoRow('Entered by', '${p['enteredBy'] ?? ''}'),
            const SizedBox(height: 10),
            if ((asNum(p['photos']) ?? 0) > 0) OutlinedButton.icon(onPressed: () => Navigator.pop(bc, 'ph'), icon: const Icon(Icons.photo_library_rounded), label: Text('Receipt photos')),
            if (can) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(key: const Key('fc-pedit'), onPressed: () => Navigator.pop(bc, 'edit'), icon: const Icon(Icons.edit_rounded), label: Text('Change')),
              const SizedBox(height: 8),
              OutlinedButton.icon(key: const Key('fc-pdel'), style: OutlinedButton.styleFrom(foregroundColor: C.red), onPressed: () => Navigator.pop(bc, 'del'), icon: const Icon(Icons.delete_outline_rounded), label: Text('Delete')),
            ],
          ]),
        ),
      ),
    );
    if (!mounted || v == null) return;
    final s = SessionScope.read(context);
    if (v == 'edit') return _open(PayForm(edit: p));
    if (v == 'ph') {
      try {
        final r = (await s.api.call('getCardPayPhotos', ['${p['id']}']) as Map).cast<String, dynamic>();
        if (!mounted) return;
        await showDialog<void>(context: context, builder: (c) => AlertDialog(
              content: SizedBox(width: 340, child: ListView(shrinkWrap: true, children: [for (final x in (r['photos'] as List? ?? const []).whereType<Map>()) if ('${x['url'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 8), child: Image.network('${x['url']}'))])),
              actions: [TextButton(onPressed: () => Navigator.pop(c), child: Text('Close'))],
            ));
      } catch (e) {
        if (mounted) toast(context, errText(e), bad: true);
      }
      return;
    }
    if (v == 'del') {
      if (!await ask(context, 'Delete ${p['id']}?', '${p['card']} – ${rupees(asNum(p['amount']))} · ${showDate('${p['date']}')}. The balance of ${p['card']} goes down by this amount.', yes: 'Delete', danger: true)) return;
      try {
        final r = (await s.api.call('deleteCardPayment', ['${p['id']}'], true) as Map).cast<String, dynamic>();
        s.setCards(r['cards']);
        if (r['stock'] != null) s.setStock(r['stock']);
        if (mounted) toast(context, '${p['id']} deleted.');
        _load();
      } catch (e) {
        if (mounted) toast(context, errText(e), bad: !isSent(e));
      }
    }
  }
}

/// One card: its kind, last 4 digits, balance (red when short), its last fill
class CardTile extends StatelessWidget {
  const CardTile(this.c, {super.key, this.onTap});
  final FuelCard c;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Opacity(
        opacity: c.active ? 1 : .6,
        child: Press(
          key: Key('fc-c-${c.name}'),
          onTap: onTap,
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(width: 48, height: 48, decoration: BoxDecoration(color: C.amberSoft, borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.credit_card_rounded, color: C.amber)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              Text([c.type, if (c.last4.isNotEmpty) '···· ${c.last4}', if (!c.active) 'Inactive', if (c.lastFill.isNotEmpty) 'last fill ${showDate(c.lastFill)}'].join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: C.muted)),
            ])),
            Text(rupees(c.balance), key: Key('fc-bal-${c.name}'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: c.balance < 0 ? C.red : C.greenDark)),
          ]),
        ),
      );
}

/// A card added or changed
class CardForm extends StatefulWidget {
  const CardForm({super.key, this.card});
  final FuelCard? card;
  @override
  State<CardForm> createState() => _CardFormState();
}

class _CardFormState extends State<CardForm> {
  final name = TextEditingController(), last4 = TextEditingController(), opening = TextEditingController();
  String type = kCardTypes.first, openDate = '', err = '';
  bool active = true, busy = false;
  final cars = <String>{};

  @override
  void initState() {
    super.initState();
    final c = widget.card;
    if (c != null) {
      name.text = c.name;
      last4.text = c.last4;
      opening.text = fmtNum(c.opening).replaceAll(',', '');
      type = kCardTypes.contains(c.type) ? c.type : kCardTypes.first;
      openDate = c.openDate;
      active = c.active;
      cars.addAll(c.cars);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (openDate.isEmpty) openDate = SessionScope.read(context).today;
  }

  @override
  void dispose() {
    name.dispose();
    last4.dispose();
    opening.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final s = SessionScope.read(context);
    setState(() {
      busy = true;
      err = '';
    });
    try {
      final r = (await s.api.call('saveCard', [{'was': widget.card?.name ?? '', 'name': name.text.trim(), 'type': type, 'last4': last4.text.trim(), 'opening': asNum(opening.text) ?? '', 'openDate': openDate, 'active': active, 'cars': cars.toList()}], true) as Map).cast<String, dynamic>();
      s.setCards(r['cards']);
      if (r['stock'] != null) s.setStock(r['stock']);
      if (!mounted) return;
      toast(context, r['added'] == true ? 'Fuel card ${r['name']} added.' : 'Fuel card ${r['name']} saved.');
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() {
          busy = false;
          err = errText(e);
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    final list = [for (final m in s.machines) if (m.fuel != 'Electric') m.id]..sort();
    return Scaffold(
      appBar: AppBar(title: TwoLang(widget.card == null ? 'New card' : 'Change card', 'कार्ड', size: 19, weight: FontWeight.w700)),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 40), children: [
        TextBox(key: const Key('cf-name'), label: 'Card name', controller: name, hint: 'e.g. HDFC Fuel Card 1', upper: true),
        const SizedBox(height: 10),
        PickField(key: const Key('cf-type'), label: 'Kind', value: type, items: kCardTypes, onChanged: (v) => setState(() => type = v)),
        const SizedBox(height: 10),
        TextBox(key: const Key('cf-last4'), label: 'Last 4 digits', controller: last4, kb: TextInputType.number, hint: 'never the whole number'),
        const SizedBox(height: 10),
        TextBox(key: const Key('cf-open'), label: 'Opening balance (₹)', controller: opening, kb: const TextInputType.numberWithOptions(decimal: true)),
        const SizedBox(height: 10),
        DateField(key: const Key('cf-date'), label: 'Opening balance on', value: openDate, clear: false, last: s.today.isEmpty ? null : parseKey(s.today), onChanged: (v) => setState(() => openDate = v)),
        SwitchListTile(key: const Key('cf-active'), contentPadding: EdgeInsets.zero, title: Text('Active'), value: active, onChanged: (v) => setState(() => active = v)),
        FormHead('Cars that use it', sub: 'None ticked = every car'),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final n in list) FilterChip(key: Key('cf-car-$n'), label: Text(n), selected: cars.contains(n), onSelected: (on) => setState(() => on ? cars.add(n) : cars.remove(n))),
        ]),
        if (err.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: InfoLine(err, bad: true)),
        const SizedBox(height: 18),
        FilledButton(key: const Key('cf-save'), onPressed: busy ? null : _save, child: Text(busy ? 'Saving…' : 'Save card')),
      ]),
    );
  }
}

/// A payment / recharge onto a card (new, or one being changed), with photos of its receipt
class PayForm extends StatefulWidget {
  const PayForm({super.key, this.edit});
  final Map<String, dynamic>? edit;
  @override
  State<PayForm> createState() => _PayFormState();
}

class _Ph {
  _Ph({this.jpg, this.url = '', this.path = ''});
  final Uint8List? jpg;
  final String url;
  String path;
}

class _PayFormState extends State<PayForm> {
  final amount = TextEditingController(), ref = TextEditingController(), remark = TextEditingController();
  String date = '', card = '', err = '';
  bool busy = false, picking = false;
  final photos = <_Ph>[];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (date.isNotEmpty) return;
    final s = SessionScope.read(context), e = widget.edit;
    date = s.today;
    card = s.cards.isNotEmpty ? s.cards.first.name : '';
    if (e != null) {
      date = '${e['date']}';
      card = '${e['card']}';
      amount.text = fmtNum(asNum(e['amount'])).replaceAll(',', '');
      ref.text = '${e['ref'] ?? ''}';
      remark.text = '${e['remark'] ?? ''}';
      if ((asNum(e['photos']) ?? 0) > 0) WidgetsBinding.instance.addPostFrameCallback((_) => _loadPhotos());
    }
  }

  Future<void> _loadPhotos() async {
    try {
      final r = (await SessionScope.read(context).api.call('getCardPayPhotos', ['${widget.edit!['id']}']) as Map).cast<String, dynamic>();
      if (!mounted) return;
      setState(() => photos.addAll([for (final x in (r['photos'] as List? ?? const []).whereType<Map>()) _Ph(url: '${x['url'] ?? ''}', path: '${x['p'] ?? ''}')]));
    } catch (_) {/* they stay as they are: not sent = kept */}
  }

  @override
  void dispose() {
    amount.dispose();
    ref.dispose();
    remark.dispose();
    super.dispose();
  }

  Future<void> _add(bool camera) async {
    if (picking || photos.length >= 5) return;
    final s = SessionScope.read(context);
    setState(() => picking = true);
    var jpgs = <Uint8List>[];
    try {
      jpgs = await pickBills(camera: camera, room: 5 - photos.length);
    } catch (x) {
      if (mounted) toast(context, x is PhotoProblem ? tr(x.message) : tr(errText(x)), bad: true);
    } finally {
      if (mounted) setState(() => picking = false);
    }
    for (final j in jpgs) {
      final ph = _Ph(jpg: j);
      setState(() => photos.add(ph));
      try {
        final r = (await s.api.call('cardPhoto', [{'data': 'data:image/jpeg;base64,${base64Encode(j)}'}], true) as Map);
        if (mounted) setState(() => ph.path = '${r['path'] ?? ''}');
      } catch (x) {
        if (!mounted) return;
        setState(() => photos.remove(ph));
        toast(context, tr(errText(x)), bad: true);
      }
    }
  }

  Future<void> _save() async {
    final s = SessionScope.read(context), e = widget.edit;
    if (photos.any((p) => p.path.isEmpty)) {
      toast(context, 'A photo is still being sent – wait a moment, then save.', bad: true);
      return;
    }
    setState(() {
      busy = true;
      err = '';
    });
    final d = {'date': date, 'card': card, 'amount': asNum(amount.text) ?? '', 'ref': ref.text.trim(), 'remark': remark.text.trim(), 'photos': [for (final p in photos) p.path]};
    try {
      final r = (await (e == null ? s.api.call('saveCardPayment', [d], true) : s.api.call('updateCardPayment', ['${e['id']}', d], true)) as Map).cast<String, dynamic>();
      s.setCards(r['cards']);
      if (r['stock'] != null) s.setStock(r['stock']);
      if (!mounted) return;
      toast(context, 'Payment ${r['id']} saved.');
      Navigator.pop(context, true);
    } catch (x) {
      if (mounted) setState(() {
          busy = false;
          err = errText(x);
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context), c = s.card(card);
    return Scaffold(
      appBar: AppBar(title: TwoLang(widget.edit == null ? 'Payment onto a card' : 'Change ${widget.edit!['id']}', 'कार्डवर भरलेले पैसे', size: 18, weight: FontWeight.w700)),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 40), children: [
        DateField(key: const Key('pf-date'), label: 'Date', value: date, clear: false, last: s.today.isEmpty ? null : parseKey(s.today), onChanged: (v) => setState(() => date = v)),
        const SizedBox(height: 10),
        PickField(key: const Key('pf-card'), label: 'Card', value: card, items: [for (final x in s.cards) x.name], onChanged: (v) => setState(() => card = v)),
        if (c != null) Padding(padding: const EdgeInsets.only(top: 6), child: InfoLine('${c.name} – balance now ${rupees(c.balance)}', icon: Icons.credit_card_rounded)),
        const SizedBox(height: 10),
        TextBox(key: const Key('pf-amount'), label: 'Amount (₹)', controller: amount, kb: const TextInputType.numberWithOptions(decimal: true)),
        const SizedBox(height: 10),
        TextBox(key: const Key('pf-ref'), label: 'Reference', controller: ref, hint: 'e.g. NEFT / UTR no.'),
        const SizedBox(height: 10),
        TextBox(key: const Key('pf-remark'), label: 'Remark', controller: remark),
        FormHead('Receipt photos', sub: 'Up to 5'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final p in photos)
            Stack(children: [
              ClipRRect(borderRadius: BorderRadius.circular(10), child: SizedBox(width: 72, height: 72, child: p.jpg != null ? Image.memory(p.jpg!, fit: BoxFit.cover) : p.url.isNotEmpty ? Image.network(p.url, fit: BoxFit.cover) : const ColoredBox(color: C.bg))),
              if (p.path.isEmpty) const Positioned.fill(child: Center(child: CircularProgressIndicator(strokeWidth: 2.5))),
              Positioned(right: 0, top: 0, child: InkWell(onTap: () => setState(() => photos.remove(p)), child: const CircleAvatar(radius: 11, backgroundColor: Colors.white, child: Icon(Icons.close_rounded, size: 15, color: C.red)))),
            ]),
          if (photos.length < 5) ...[
            OutlinedButton.icon(key: const Key('pf-cam'), onPressed: picking ? null : () => _add(true), icon: const Icon(Icons.photo_camera_rounded), label: Text('Camera')),
            OutlinedButton.icon(key: const Key('pf-gal'), onPressed: picking ? null : () => _add(false), icon: const Icon(Icons.photo_library_rounded), label: Text('Gallery')),
          ],
        ]),
        if (err.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: InfoLine(err, bad: true)),
        const SizedBox(height: 18),
        FilledButton(key: const Key('pf-save'), onPressed: busy || card.isEmpty ? null : _save, child: Text(busy ? 'Saving…' : 'Save payment')),
      ]),
    );
  }
}

/// The statement of a card: its balance at the start, every payment (+) and fill (−) with the balance after it, the closing
class StatementScreen extends StatefulWidget {
  const StatementScreen({super.key, required this.card});
  final String card;
  @override
  State<StatementScreen> createState() => _StatementScreenState();
}

class _StatementScreenState extends State<StatementScreen> {
  String card = '', from = '', to = '', err = '';
  Map<String, dynamic>? d;
  bool loading = false;

  @override
  void initState() {
    super.initState();
    card = widget.card;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final s = SessionScope.read(context);
    setState(() {
      loading = true;
      err = '';
    });
    try {
      final r = (await s.api.call('cardStatement', [{'card': card, 'from': from, 'to': to}]) as Map).cast<String, dynamic>();
      if (mounted) setState(() {
          d = r;
          loading = false;
        });
    } catch (e) {
      if (mounted) setState(() {
          loading = false;
          err = errText(e);
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context), x = d;
    final lines = [for (final l in (x?['lines'] as List? ?? const []).whereType<Map>()) l.cast<String, dynamic>()];
    String what(Map<String, dynamic> l) => l['kind'] == 'Payment'
        ? 'Payment${'${l['note'] ?? ''}'.isNotEmpty ? ' – ${l['note']}' : ''}'
        : 'Fill ${l['no']} · ${fmtNum(asNum(l['qty']))} ${l['unit'] == 'kg' ? 'kg' : 'L'}${'${l['driver'] ?? ''}'.isNotEmpty ? ' · ${l['driver']}' : ''}';
    return Scaffold(
      appBar: AppBar(title: const TwoLang('Statement', 'स्टेटमेंट', size: 19, weight: FontWeight.w700)),
      body: ListView(key: const Key('st-list'), padding: const EdgeInsets.fromLTRB(16, 12, 16, 40), children: [
        PickField(key: const Key('st-card'), label: 'Card', value: card, items: [for (final c in s.cards) c.name], onChanged: (v) {
          setState(() => card = v);
          _load();
        }),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: DateField(key: const Key('st-from'), label: 'From', value: from, onChanged: (v) { setState(() => from = v); _load(); })),
          const SizedBox(width: 8),
          Expanded(child: DateField(key: const Key('st-to'), label: 'To', value: to, onChanged: (v) { setState(() => to = v); _load(); })),
        ]),
        const SizedBox(height: 10),
        if (err.isNotEmpty) InfoLine(err, bad: true),
        if (loading) const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator())),
        if (x != null && !loading) ...[
          InfoRow('Opening ${showDate('${x['from']}')}', rupees(asNum(x['opening'])), bold: true),
          for (final l in lines)
            Container(
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: C.line)),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(what(l), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  Text('${showDate('${l['date']}')} · ${l['id']}', style: const TextStyle(fontSize: 12, color: C.muted)),
                ])),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text((asNum(l['in']) ?? 0) > 0 ? '+ ${rupees(asNum(l['in']))}' : '− ${rupees(asNum(l['out']))}', style: TextStyle(fontWeight: FontWeight.w700, color: (asNum(l['in']) ?? 0) > 0 ? C.greenDark : C.ink)),
                  Text(rupees(asNum(l['balance'])), style: TextStyle(fontSize: 12.5, color: (asNum(l['balance']) ?? 0) < 0 ? C.red : C.muted)),
                ]),
              ]),
            ),
          const SizedBox(height: 8),
          InfoRow('Closing ${showDate('${x['to']}')}', rupees(asNum(x['closing'])), tone: (asNum(x['closing']) ?? 0) < 0 ? C.red : C.greenDark, bold: true),
        ],
      ]),
    );
  }
}
