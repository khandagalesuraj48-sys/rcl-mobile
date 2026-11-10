/* PURCHASE PHASE 1 – the app's own screens (3.94.0, with rcl-purchase "Purchase Phase 1", asked 09-11-2026: "ek sath enginnering
 * modual purchase modual banwayla surwat kr"; his decisions P1 – P3). Home → Purchase: the Inbox (the sites' approved requirement
 * lines still to order – from each site's Store), Enquiries (RFQ – made from the Inbox, the suppliers asked, "Share on WhatsApp"),
 * Quotations (each supplier's, typed as he gave it), the Comparative Statement (WITHOUT GST, L1 marked, the award line by line, sent
 * for approval BY AMOUNT – never one's own), Waiting for my approval, Suppliers and (the Super Admin) the CS limit. The same actions,
 * checks and access as the web's pages (POST <purchase>/api/pur – api.pur, the Portal's ticket for 'purchase'); the server checks
 * every save again. The papers' print stays on the web. */
import 'package:flutter/material.dart' hide Text;
import 'package:url_launcher/url_launcher.dart';

import '../core/format.dart';
import '../ui/ask_bot.dart';
import '../ui/fields.dart';
import '../ui/scope.dart';
import '../ui/t.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

/// One call to Purchase of the site open now.
Future<Map<String, dynamic>> purCall(BuildContext context, Map<String, dynamic> body) {
  final s = SessionScope.read(context), site = s.site, m = site?.module('purchase');
  if (site == null || m == null) throw StateError('none');
  return s.api.pur(site.code, m.url, body);
}

num _n(Object? v) => v is num ? v : num.tryParse('${v ?? ''}'.replaceAll(',', '')) ?? 0;
String _s(Object? v) => v == null ? '' : '$v';
String _day(Object? d) => _s(d).isEmpty ? '' : showDate(_s(d).substring(0, _s(d).length < 10 ? _s(d).length : 10));
String _at(Object? t) => _s(t).isEmpty ? '' : whenText(_s(t));
List<Map<String, dynamic>> _list(Object? v) => [for (final x in (v as List? ?? const []).whereType<Map>()) x.cast<String, dynamic>()];
Map<String, dynamic> _map(Object? v) => ((v as Map?) ?? const {}).cast<String, dynamic>();
num _r2(num v) => (v * 100).round() / 100;

/// ₹1,23,456.00 – as the web's money()
String purMoney(Object? v) {
  final n = _n(v), f = n.abs().toStringAsFixed(2).split('.');
  return '₹${n < 0 ? '−' : ''}${fmtNum(int.parse(f[0]))}.${f[1]}';
}

String purQty(Object? v) => fmtNum(_n(v), maxDecimals: 3);
String rfqRef(Object? n) => 'RFQ-${_s(n).padLeft(4, '0')}';

/// The colours of a status, as the web's tags
(Color, Color) purTag(String st) => switch (st) {
      'Draft' => (C.muted, C.line),
      'Sent' => (C.blue, C.blueSoft),
      'Quotes in' || 'Sent back' => (C.amber, C.amberSoft),
      'Cancelled' || 'Rejected' || 'Blocked' => (C.red, C.redSoft),
      _ => (C.greenDark, C.greenSoft),
    };
Widget purPill(String st) {
  final (c, bg) = purTag(st);
  return Pill(st, color: c, bg: bg);
}

/// Who he is in Purchase (its sign-in's answer)
class PurMe {
  const PurMe(this.role, this.name, this.email);
  final String role, name, email;
  bool get admin => role == 'admin' || role == 'super';
  bool get superAdmin => role == 'super';
}

Widget _card(Widget child, {Key? key, Color? border}) => Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: softShadow(), border: border == null ? null : Border.all(color: border, width: 2)),
      child: child,
    );
Widget _small(String t, {Color color = C.muted}) => Text(t, style: TextStyle(fontSize: 12.5, color: color, height: 1.3));
// a button beside others (a Row or a Wrap): its own width – the theme's buttons fill the width
final _fs = FilledButton.styleFrom(minimumSize: const Size(0, 44)), _os = OutlinedButton.styleFrom(minimumSize: const Size(0, 44));
Widget _wait() => const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator()));

/* ======================================== INBOX – to order ======================================== */
class PurInboxScreen extends StatefulWidget {
  const PurInboxScreen({super.key, required this.me});
  final PurMe me;
  @override
  State<PurInboxScreen> createState() => _PurInboxScreenState();
}

class _PurInboxScreenState extends State<PurInboxScreen> {
  Map<String, dynamic>? data;
  final pick = <String, Map<String, dynamic>>{};
  String err = '';
  bool loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      err = '';
    });
    try {
      final r = await purCall(context, {'action': 'inbox'});
      if (!mounted) return;
      final free = <String>{};
      for (final st in _list(r['sites'])) {
        for (final q in _list(st['reqs'])) {
          for (final l in _list(q['lines'])) {
            if (l['taken'] == null) free.add('${st['site']}:${q['no']}:${l['line']}');
          }
        }
      }
      setState(() {
        data = r;
        pick.removeWhere((k, _) => !free.contains(k));
        loading = false;
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

  Future<void> _make() async {
    final lines = pick.values.toList(), needs = [for (final l in lines) if (_s(l['need_by']).isNotEmpty) _s(l['need_by'])]..sort();
    final no = await Navigator.of(context).push<int>(MaterialPageRoute(builder: (_) => PurRfqForm(lines: lines, needBy: needs.isEmpty ? '' : needs.first, today: _s(data?['today']))));
    if (no == null || !mounted) return;
    pick.clear();
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PurRfqView(me: widget.me, no: no)));
    if (mounted) _load();
  }

  Widget _line(Map<String, dynamic> st, Map<String, dynamic> q, Map<String, dynamic> l) {
    final k = '${st['site']}:${q['no']}:${l['line']}', t = l['taken'] == null ? null : _map(l['taken']), on = pick.containsKey(k);
    final spec = [_s(l['brand']), _s(l['spec'])].where((x) => x.isNotEmpty).join(' · ');
    return Opacity(
      opacity: t == null ? 1 : .55,
      child: _card(
        key: Key('pin-$k'),
        border: on ? C.green : null,
        InkWell(
          onTap: t != null
              ? null
              : () => setState(() {
                    if (on) {
                      pick.remove(k);
                    } else {
                      pick[k] = {'site': st['site'], 'req_no': q['no'], 'req_line': l['line'], 'qty': l['left'], 'left': l['left'], 'name': l['name'], 'code': l['code'], 'unit': l['unit'], 'ref': q['ref'], 'brand': l['brand'], 'spec': l['spec'], 'need_by': q['need_by']};
                    }
                  }),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (t == null) Padding(padding: const EdgeInsets.only(right: 8), child: Icon(on ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded, color: on ? C.green : C.faint)),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_s(l['name']), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                if (spec.isNotEmpty) _small(spec),
                const SizedBox(height: 4),
                Text('${tr('To order')}: ${purQty(l['left'])} ${_s(l['unit'])}${_n(l['ordered']) > 0 ? ' (${tr('of')} ${purQty(l['qty'])} · ${tr('ordered')} ${purQty(l['ordered'])})' : ''}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                _small('${_s(q['ref'])}${_s(q['for_text']).isNotEmpty ? ' – ${_s(q['for_text'])}' : ''}${_s(q['need_by']).isNotEmpty ? ' · ${tr('need by')} ${_day(q['need_by'])}' : ''}'),
                _small('${tr('Waiting since')} ${_day(q['since'])} · ${_s(q['made_by'])}'),
                if (t != null) Padding(padding: const EdgeInsets.only(top: 6), child: purPill('${rfqRef(t['rfq'])} · ${t['status']}')),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = data, sites = _list(r?['sites']);
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(title: const TwoLang('Inbox – to order', 'Inbox – मागवायचे', size: 18, weight: FontWeight.w700), actions: withAsk()),
      bottomNavigationBar: pick.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Sp.edge, 8, Sp.edge, 10),
                child: Row(children: [
                  Expanded(child: Text(tr('{0} lines ticked').replaceAll('{0}', '${pick.length}'), style: const TextStyle(fontWeight: FontWeight.w700))),
                  TextButton(key: const Key('pin-clear'), onPressed: () => setState(pick.clear), child: const Text('Clear')),
                  FilledButton(key: const Key('pin-make'), style: _fs, onPressed: _make, child: const Text('Make enquiry')),
                ]),
              ),
            ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(key: const Key('pin-list'), padding: const EdgeInsets.fromLTRB(Sp.edge, 8, Sp.edge, 40), children: [
          Text(bi('The approved Material Requirements of your sites still to order. Tick the lines, then Make enquiry. A line already in an enquiry is not asked twice.', 'मंजूर requirement च्या ओळी – निवडा आणि Enquiry बनवा.'), style: const TextStyle(fontSize: 13, color: C.muted, height: 1.35)),
          const SizedBox(height: 10),
          if (err.isNotEmpty) InfoLine(err, bad: true),
          if (loading) _wait(),
          if (!loading && r != null && r['link'] != true) InfoLine(_s(r['error']), bad: true),
          if (!loading && r != null && r['link'] == true) ...[
            if (sites.isEmpty) const EmptyState('No site', 'You have Purchase on no site with a Store.', pic: 'package'),
            for (final st in sites) ...[
              Padding(padding: const EdgeInsets.only(top: 8, bottom: 8), child: Text('${_s(st['name'])} · ${_s(st['site'])}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
              if (st['own'] == true) _small(tr('This site buys its requirements itself – none of them comes here.')),
              if (_s(st['error']).isNotEmpty) InfoLine(_s(st['error']), bad: !_s(st['error']).startsWith('No Store'), help: false),
              if (st['own'] != true && _s(st['error']).isEmpty && _list(st['reqs']).every((q) => _list(q['lines']).isEmpty)) _small(tr('Nothing to order – every approved requirement is ordered.')),
              for (final q in _list(st['reqs']))
                for (final l in _list(q['lines'])) _line(st, q, l),
            ],
          ],
        ]),
      ),
    );
  }
}

/* ======================================== ENQUIRIES (RFQ) ======================================== */
/// The enquiries: [mode] 'rfq' (all – opens the enquiry), 'quotes' (Sent / Quotes in – its suppliers' quotations), 'cs' (those with a
/// quotation – opens its comparative statement)
class PurRfqListScreen extends StatefulWidget {
  const PurRfqListScreen({super.key, required this.me, this.mode = 'rfq'});
  final PurMe me;
  final String mode;
  @override
  State<PurRfqListScreen> createState() => _PurRfqListScreenState();
}

const _kRfqTabs = [('', 'All'), ('Draft', 'Draft'), ('Sent', 'Sent'), ('Quotes in', 'Quotes in'), ('Closed', 'Closed'), ('Cancelled', 'Cancelled')];

class _PurRfqListScreenState extends State<PurRfqListScreen> {
  List<Map<String, dynamic>> rows = [];
  String st = '', err = '';
  bool loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      err = '';
    });
    try {
      final r = await purCall(context, {'action': 'rfqList', if (widget.mode == 'rfq' && st.isNotEmpty) 'status': st});
      if (!mounted) return;
      setState(() {
        rows = [
          for (final q in _list(r['rfqs']))
            if (widget.mode == 'rfq' || (widget.mode == 'quotes' && (q['status'] == 'Sent' || q['status'] == 'Quotes in')) || (widget.mode == 'cs' && (_n(q['quotes']) > 0 || q['cs'] != null))) q,
        ];
        loading = false;
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

  Future<void> _open(Map<String, dynamic> q) async {
    final no = _n(q['no']).toInt();
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => widget.mode == 'cs' ? PurCsScreen(me: widget.me, rfq: no) : PurRfqView(me: widget.me, no: no)));
    if (mounted) _load();
  }

  Widget _row(Map<String, dynamic> q) {
    final cs = q['cs'] == null ? null : _map(q['cs']), vs = _list(q['vendors']);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Press(
        key: Key('prq-row-${q['no']}'),
        onTap: () => _open(q),
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(_s(q['ref']), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
            const SizedBox(width: 8),
            Expanded(child: _small('${_day(q['date'])}${_s(q['need_by']).isNotEmpty ? ' · ${tr('need by')} ${_day(q['need_by'])}' : ''}')),
            purPill(_s(q['status'])),
          ]),
          const SizedBox(height: 6),
          Text(_s(q['items']), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5), maxLines: 2, overflow: TextOverflow.ellipsis),
          _small('${_n(q['nlines'])} ${tr('lines')} · ${(q['sites'] as List? ?? const []).join(', ')}'),
          _small('${tr('Quotations')}: ${_n(q['quotes'])} ${tr('of')} ${vs.length} · ${vs.map((v) => _s(v['name'])).join(', ')}'),
          if (cs != null) Padding(padding: const EdgeInsets.only(top: 6), child: Row(children: [Text('${_s(cs['ref'])}  ', style: const TextStyle(fontWeight: FontWeight.w700)), purPill(_s(cs['status'])), const SizedBox(width: 8), Text(purMoney(cs['total']), style: const TextStyle(fontWeight: FontWeight.w700))])),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.mode;
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(title: Text(m == 'cs' ? 'Comparative Statement' : m == 'quotes' ? 'Quotations' : 'Enquiries (RFQ)', style: const TextStyle(fontWeight: FontWeight.w700)), actions: withAsk()),
      floatingActionButton: m == 'rfq'
          ? FloatingActionButton.extended(
              key: const Key('prq-new'),
              onPressed: () async {
                await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PurInboxScreen(me: widget.me)));
                if (mounted) _load();
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('New – from the Inbox'))
          : null,
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(key: const Key('prq-list'), padding: const EdgeInsets.fromLTRB(Sp.edge, 8, Sp.edge, 100), children: [
          if (m == 'quotes') _small(bi('Open the enquiry, then the supplier, and type his quotation as he gave it.', 'Enquiry उघडा, पुरवठादार निवडा आणि त्याचे दर भरा.')),
          if (m == 'cs') _small(bi('Side by side WITHOUT GST; L1 = the lowest landed rate of a line. Open an enquiry with its quotations.', 'GST शिवाय तुलना; L1 = सर्वात कमी दर.')),
          if (m == 'rfq')
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final t in _kRfqTabs)
                ChoiceChip(key: Key('prq-st-${t.$1}'), label: Text(t.$2), selected: st == t.$1, onSelected: (_) {
                  setState(() => st = t.$1);
                  _load();
                }),
            ]),
          const SizedBox(height: 10),
          if (err.isNotEmpty) InfoLine(err, bad: true),
          if (loading) _wait(),
          if (!loading && rows.isEmpty && err.isEmpty) EmptyState(m == 'cs' ? 'No quotation yet' : 'No enquiry here', m == 'rfq' ? 'Make one from the Inbox.' : 'An enquiry sent to the suppliers shows here.', pic: 'clipboard'),
          if (!loading) for (final q in rows) _row(q),
        ]),
      ),
    );
  }
}

/// One enquiry: its lines, the suppliers asked (their quotations, "Share on WhatsApp"), and what may be done now
class PurRfqView extends StatefulWidget {
  const PurRfqView({super.key, required this.me, required this.no});
  final PurMe me;
  final int no;
  @override
  State<PurRfqView> createState() => _PurRfqViewState();
}

class _PurRfqViewState extends State<PurRfqView> {
  Map<String, dynamic>? data;
  String err = '';
  bool loading = true, busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      err = '';
    });
    try {
      final r = await purCall(context, {'action': 'rfqGet', 'no': widget.no});
      if (!mounted) return;
      setState(() {
        data = r;
        loading = false;
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

  Future<void> _do(Map<String, dynamic> body, String done) async {
    setState(() => busy = true);
    try {
      final r = await purCall(context, body);
      if (!mounted) return;
      toast(context, done);
      setState(() {
        data = r;
        busy = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => busy = false);
        toast(context, errText(e), bad: true);
      }
    }
  }

  Future<void> _send(Map<String, dynamic> q) async {
    if (!await ask(context, tr('Mark {0} as sent?').replaceAll('{0}', _s(q['ref'])), tr('Share it on WhatsApp or give the print to each supplier. After this, their quotations are entered.'), yes: 'Mark as sent', no: 'Not yet')) return;
    if (mounted) await _do({'action': 'rfqSend', 'no': q['no'], 'ver': q['ver']}, '${q['ref']} – ${tr('sent')}.');
  }

  Future<void> _cancel(Map<String, dynamic> q) async {
    final why = await askNote(context, tr('Cancel {0}?').replaceAll('{0}', _s(q['ref'])), label: 'Why is it cancelled?', ok: 'Cancel enquiry', danger: true, neededMsg: 'Write the reason (a few words).');
    if (why == null || !mounted) return;
    await _do({'action': 'rfqCancel', 'no': q['no'], 'ver': q['ver'], 'why': why}, '${q['ref']} – ${tr('cancelled')}.');
  }

  Future<void> _edit(Map<String, dynamic> q) async {
    final no = await Navigator.of(context).push<int>(MaterialPageRoute(builder: (_) => PurRfqForm(old: q)));
    if (no != null && mounted) _load();
  }

  Future<void> _quote(Map<String, dynamic> v) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PurQuoteForm(rfq: widget.no, vendor: _n(v['id']).toInt())));
    if (mounted) _load();
  }

  Future<void> _cs() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PurCsScreen(me: widget.me, rfq: widget.no)));
    if (mounted) _load();
  }

  /// the enquiry as one WhatsApp message (he taps it – WhatsApp opens with the text; nothing is sent by the server) – the web's waText
  String _waText(Map<String, dynamic> q, Map<String, dynamic> v) => [
        '*Rachana Construction Limited – Request for Quotation ${q['ref']}*',
        'Date: ${_day(q['date'])}${_s(q['need_by']).isNotEmpty ? ' · Needed by: ${_day(q['need_by'])}' : ''}',
        'To: ${v['name']}',
        '',
        'Please quote your best rates for:',
        for (final (i, l) in _list(q['lines']).indexed) '${i + 1}. ${l['name']}${_s(l['brand']).isNotEmpty ? ' – ${l['brand']}' : ''}${_s(l['spec']).isNotEmpty ? ' (${l['spec']})' : ''}: ${purQty(l['qty'])} ${_s(l['unit'])}',
        '',
        'Please give: rate per unit, discount %, GST %, delivery days, freight and loading, payment terms, validity.',
        if (_s(q['remark']).isNotEmpty) 'Note: ${q['remark']}',
      ].join('\n');

  @override
  Widget build(BuildContext context) {
    final r = data, q = _map(r?['rfq']), may = _map(r?['may']), cs = r?['cs'] == null ? null : _map(r?['cs']), vs = _list(r?['vendors']);
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(title: Text(r == null ? rfqRef(widget.no) : _s(q['ref']), style: const TextStyle(fontWeight: FontWeight.w700)), actions: withAsk([IconButton(tooltip: tr('Refresh'), onPressed: _load, icon: const Icon(Icons.refresh_rounded))])),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(key: const Key('prv-view'), padding: const EdgeInsets.fromLTRB(Sp.edge, 8, Sp.edge, 40), children: [
          if (err.isNotEmpty) InfoLine(err, bad: true),
          if (loading) _wait(),
          if (!loading && r != null) ...[
            _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Expanded(child: Text(_s(q['ref']), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))), purPill(_s(q['status']))]),
              const SizedBox(height: 4),
              _small('${tr('Date')} ${_day(q['date'])}${_s(q['need_by']).isNotEmpty ? ' · ${tr('need by')} ${_day(q['need_by'])}' : ''} · ${tr('made by')} ${_s(q['created_name'])} · ${tr('site')} ${_s(q['site'])}${_s(q['sent_at']).isNotEmpty ? ' · ${tr('sent')} ${_at(q['sent_at'])}' : ''}'),
              if (_s(q['status_note']).isNotEmpty) _small(_s(q['status_note']), color: C.red),
              if (_s(q['remark']).isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text('${tr('Remark')}: ${q['remark']}', style: const TextStyle(fontSize: 13.5))),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                if (may['edit'] == true) OutlinedButton(key: const Key('prv-edit'), style: _os, onPressed: busy ? null : () => _edit(q), child: const Text('Change')),
                if (may['send'] == true) FilledButton(key: const Key('prv-send'), style: _fs, onPressed: busy ? null : () => _send(q), child: const Text('Mark as sent')),
                if (may['cs'] == true || cs != null)
                  FilledButton.tonal(key: const Key('prv-cs'), style: _fs, onPressed: busy ? null : _cs, child: Text(cs != null ? '${tr('Open')} ${cs['ref']}' : 'Make the CS')),
                if (may['cancel'] == true) TextButton(key: const Key('prv-cancel'), onPressed: busy ? null : () => _cancel(q), child: const Text('Cancel enquiry', style: TextStyle(color: C.red))),
              ]),
            ])),
            const SectionTitle('Lines', mr: 'ओळी'),
            for (final l in _list(q['lines']))
              _card(
                key: Key('prv-line-${l['line']}'),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${l['line']}. ${_s(l['name'])}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  Text('${purQty(l['qty'])} ${_s(l['unit'])}', style: const TextStyle(fontWeight: FontWeight.w600)),
                  _small('${_s(l['ref'])} · ${_s(l['site'])}${[_s(l['brand']), _s(l['spec'])].any((x) => x.isNotEmpty) ? ' · ${[_s(l['brand']), _s(l['spec'])].where((x) => x.isNotEmpty).join(' · ')}' : ''}'),
                ]),
              ),
            const SectionTitle('Suppliers asked', mr: 'विचारलेले पुरवठादार'),
            if (vs.length < 2) _small(tr('Only one supplier asked – at least 2 quotations an item, or the CS needs a reason.'), color: C.amber),
            for (final v in vs)
              _card(
                key: Key('prv-v-${v['id']}'),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(_s(v['name']), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
                    if (v['status'] == 'Blocked') purPill('Blocked'),
                  ]),
                  _small([_s(v['phone']), _s(v['gstin'])].where((x) => x.isNotEmpty).join(' · ')),
                  const SizedBox(height: 4),
                  v['quote'] == null
                      ? _small(tr('Quotation not entered yet'))
                      : _small('${tr('Quotation entered')} · ${_s(_map(v['quote'])['by'])} · ${_at(_map(v['quote'])['at'])}${_map(v['quote'])['locked'] == true ? ' · ${tr('locked')}' : ''}', color: C.greenDark),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    if (_s(v['wa']).isNotEmpty)
                      OutlinedButton.icon(
                          key: Key('prv-wa-${v['id']}'), style: _os,
                          onPressed: () => launchUrl(Uri.parse('https://wa.me/${v['wa']}?text=${Uri.encodeComponent(_waText(q, v))}'), mode: LaunchMode.externalApplication),
                          icon: const Icon(Icons.chat_rounded, size: 18),
                          label: const Text('Share on WhatsApp')),
                    if (may['quote'] == true || v['quote'] != null)
                      FilledButton.tonal(
                          key: Key('prv-q-${v['id']}'), style: _fs, onPressed: () => _quote(v), child: Text(may['quote'] == true ? (v['quote'] == null ? 'Enter quotation' : 'Change quotation') : 'See quotation')),
                  ]),
                ]),
              ),
            _small(tr('The printed enquiry: on the web (Purchase → Enquiries → Print).')),
          ],
        ]),
      ),
    );
  }
}

/// Make an enquiry from the Inbox's lines (or change a Draft / Sent one): date, need-by, remark, the lines' quantity, the suppliers
class PurRfqForm extends StatefulWidget {
  const PurRfqForm({super.key, this.lines = const [], this.needBy = '', this.today = '', this.old});
  final List<Map<String, dynamic>> lines;
  final String needBy, today;
  final Map<String, dynamic>? old;
  @override
  State<PurRfqForm> createState() => _PurRfqFormState();
}

class _PurRfqFormState extends State<PurRfqForm> {
  final remark = TextEditingController(), find = TextEditingController();
  late List<Map<String, dynamic>> lines;
  late List<TextEditingController> qty;
  final picked = <int>{};
  List<Map<String, dynamic>> vendors = [];
  String date = '', need = '', err = '';
  bool busy = false, loading = true;

  @override
  void initState() {
    super.initState();
    final o = widget.old;
    date = o == null ? (widget.today.isEmpty ? dateKey(DateTime.now()) : widget.today) : _s(o['date']);
    need = o == null ? widget.needBy : _s(o['need_by']);
    remark.text = o == null ? '' : _s(o['remark']);
    lines = [for (final l in (o == null ? widget.lines : _list(o['lines']))) Map<String, dynamic>.from(l)];
    qty = [for (final l in lines) TextEditingController(text: _s(l['qty']))];
    if (o != null) picked.addAll([for (final v in _list(o['vendors'])) _n(v['id']).toInt()]);
    WidgetsBinding.instance.addPostFrameCallback((_) => _vendors());
  }

  Future<void> _vendors() async {
    try {
      final r = await purCall(context, {'action': 'vendorList'});
      if (!mounted) return;
      setState(() {
        vendors = _list(r['vendors']);
        loading = false;
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
    if (picked.length < 2 &&
        !await ask(context, tr('Only {0} supplier?').replaceAll('{0}', '${picked.length}'), tr('At least 2 quotations an item – with fewer, the CS needs a typed reason.'), yes: 'Save anyway', no: 'Go back')) {
      return;
    }
    if (!mounted) return;
    setState(() {
      busy = true;
      err = '';
    });
    final o = widget.old;
    try {
      final r = await purCall(context, {
        'action': 'rfqSave', if (o != null) 'no': o['no'], if (o != null) 'ver': o['ver'],
        'date': date, 'need_by': need, 'remark': remark.text.trim(),
        'lines': [for (final (i, l) in lines.indexed) {'site': l['site'], 'req_no': l['req_no'], 'req_line': l['req_line'], 'qty': qty[i].text.trim().replaceAll(',', '')}],
        'vendors': picked.toList(),
      });
      if (!mounted) return;
      final q = _map(r['rfq']);
      toast(context, '${tr('Saved')} – ${q['ref']}.');
      Navigator.pop(context, _n(q['no']).toInt());
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          err = errText(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = find.text.trim().toLowerCase();
    final shown = [
      for (final v in vendors)
        if ((v['status'] == 'Approved' || picked.contains(_n(v['id']).toInt())) && (f.isEmpty || '${v['name']} ${(v['supplies'] as List? ?? const []).join(' ')}'.toLowerCase().contains(f))) v,
    ];
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(title: Text(widget.old == null ? 'New enquiry (RFQ)' : '${tr('Change')} ${widget.old!['ref']}', style: const TextStyle(fontWeight: FontWeight.w700))),
      body: ListView(key: const Key('prf-form'), padding: const EdgeInsets.fromLTRB(Sp.edge, 10, Sp.edge, 30), children: [
        DateField(key: const Key('prf-date'), label: 'Date', value: date, clear: false, last: DateTime.tryParse(widget.today) ?? DateTime.now(), onChanged: (v) => setState(() => date = v)),
        const SizedBox(height: 8),
        DateField(key: const Key('prf-need'), label: 'Need by', value: need, onChanged: (v) => setState(() => need = v)),
        const SizedBox(height: 8),
        TextBox(key: const Key('prf-rem'), label: 'Remark (printed on it)', controller: remark),
        const SectionTitle('Lines', mr: 'ओळी'),
        if (lines.isEmpty) _small(tr('No line – add them from the Inbox.')),
        for (final (i, l) in lines.indexed)
          _card(
            key: Key('prf-line-$i'),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(_s(l['name']), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
                IconButton(key: Key('prf-drop-$i'), tooltip: tr('Remove'), onPressed: () => setState(() {
                      lines.removeAt(i);
                      qty.removeAt(i);
                    }), icon: const Icon(Icons.close_rounded, color: C.red)),
              ]),
              _small('${_s(l['ref'])} · ${_s(l['site'])}${_s(l['brand']).isNotEmpty ? ' · ${l['brand']}' : ''}'),
              const SizedBox(height: 6),
              TextBox(key: Key('prf-qty-$i'), label: '${tr('Quantity')} (${_s(l['unit'])})', controller: qty[i], kb: const TextInputType.numberWithOptions(decimal: true)),
              if (l['left'] != null) _small('${tr('at most')} ${purQty(l['left'])}'),
            ]),
          ),
        SectionTitle('Suppliers to ask', mr: 'विचारायचे पुरवठादार', trailing: Text('${picked.length}', style: const TextStyle(fontWeight: FontWeight.w800, color: C.green))),
        TextBox(key: const Key('prf-find'), label: 'Find a supplier (name or what he supplies)', controller: find, onChanged: (_) => setState(() {})),
        const SizedBox(height: 6),
        if (loading) _wait(),
        if (!loading && shown.isEmpty) _small(tr('No supplier found – add one in Suppliers.')),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final v in shown)
            FilterChip(
              key: Key('prf-v-${v['id']}'),
              label: Text(_s(v['name'])),
              selected: picked.contains(_n(v['id']).toInt()),
              onSelected: (on) => setState(() => on ? picked.add(_n(v['id']).toInt()) : picked.remove(_n(v['id']).toInt())),
            ),
        ]),
        const SizedBox(height: 6),
        _small(bi('At least 2 suppliers – at least 2 quotations an item. A new supplier: Suppliers → Add.', 'किमान 2 पुरवठादार निवडा.')),
        if (err.isNotEmpty) InfoLine(err, bad: true),
        const SizedBox(height: 14),
        FilledButton(key: const Key('prf-save'), onPressed: busy || lines.isEmpty ? null : _save, child: Text(busy ? 'Saving…' : 'Save enquiry')),
      ]),
    );
  }
}

/* ======================================== QUOTATION – one supplier's, as he gave it ======================================== */
class PurQuoteForm extends StatefulWidget {
  const PurQuoteForm({super.key, required this.rfq, required this.vendor});
  final int rfq, vendor;
  @override
  State<PurQuoteForm> createState() => _PurQuoteFormState();
}

const _kQf = [('rate', 'Rate ₹ / unit'), ('disc', 'Disc. %'), ('gst', 'GST %'), ('days', 'Delivery days')];

class _PurQuoteFormState extends State<PurQuoteForm> {
  Map<String, dynamic>? data;
  final box = <String, TextEditingController>{};
  final freight = TextEditingController(), loading2 = TextEditingController(), terms = TextEditingController(), remark = TextEditingController();
  String valid = '', err = '';
  bool loading = true, busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  TextEditingController _b(Object? line, String f) => box.putIfAbsent('$line:$f', TextEditingController.new);

  Future<void> _load() async {
    setState(() {
      loading = true;
      err = '';
    });
    try {
      final r = await purCall(context, {'action': 'quoteGet', 'rfq': widget.rfq, 'vendor': widget.vendor});
      if (!mounted) return;
      final q = _map(r['quote']), by = {for (final l in _list(q['lines'])) _s(l['line']): l};
      for (final l in _list(_map(r['rfq'])['lines'])) {
        for (final f in _kQf) {
          _b(l['line'], f.$1).text = _s(by[_s(l['line'])]?[f.$1]);
        }
      }
      freight.text = _s(q['freight']);
      loading2.text = _s(q['loading']);
      terms.text = _s(q['pay_terms']);
      remark.text = _s(q['remark']);
      setState(() {
        data = r;
        valid = _s(q['valid_till']);
        loading = false;
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

  num? _v(Object? line, String f) => asNum(_b(line, f).text);

  Future<void> _save() async {
    final r = data!, q = r['quote'] == null ? null : _map(r['quote']);
    setState(() {
      busy = true;
      err = '';
    });
    try {
      await purCall(context, {
        'action': 'quoteSave', 'rfq': widget.rfq, 'vendor': widget.vendor, if (q != null) 'ver': q['ver'],
        'lines': [for (final l in _list(_map(r['rfq'])['lines'])) {'line': l['line'], for (final f in _kQf) f.$1: _b(l['line'], f.$1).text.trim()}],
        'freight': freight.text.trim(), 'loading': loading2.text.trim(), 'pay_terms': terms.text.trim(), 'valid_till': valid, 'remark': remark.text.trim(),
      });
      if (!mounted) return;
      toast(context, tr('Quotation of {0} saved.').replaceAll('{0}', _s(_map(r['vendor'])['name'])));
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          err = errText(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = data, rfq = _map(r?['rfq']), q = _map(r?['quote']), ro = _map(r?['may'])['save'] != true, cs = r?['cs'] == null ? null : _map(r?['cs']);
    num base = 0, gst = 0;
    for (final l in _list(rfq['lines'])) {
      final rate = _v(l['line'], 'rate'), disc = _v(l['line'], 'disc') ?? 0, g = _v(l['line'], 'gst');
      if (rate != null && rate > 0) {
        final net = rate * (1 - disc / 100);
        base += net * _n(l['qty']);
        if (g != null) gst += net * _n(l['qty']) * g / 100;
      }
    }
    final extra = (asNum(freight.text) ?? 0) + (asNum(loading2.text) ?? 0);
    final hist = _list(q['history']);
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(title: Text(r == null ? 'Quotation' : '${_s(_map(r['vendor'])['name'])} · ${_s(rfq['ref'])}', style: const TextStyle(fontWeight: FontWeight.w700))),
      body: ListView(key: const Key('pqf-form'), padding: const EdgeInsets.fromLTRB(Sp.edge, 10, Sp.edge, 30), children: [
        if (err.isNotEmpty) InfoLine(err, bad: true),
        if (loading) _wait(),
        if (!loading && r != null) ...[
          if (ro)
            InfoLine(
                cs != null && ['Sent', 'Approved', 'Rejected'].contains(cs['status'])
                    ? tr('Locked – its CS {0} is {1}.').replaceAll('{0}', _s(cs['ref'])).replaceAll('{1}', tr(_s(cs['status']).toLowerCase()))
                    : rfq['status'] == 'Draft'
                        ? tr('Mark the enquiry as sent first.')
                        : tr('Not changed now ({0}).').replaceAll('{0}', _s(rfq['status'])),
                help: false),
          if (!ro) _small(bi('Type it as he gave it. A line he did not quote: leave its rate empty. Every change is kept.', 'पुरवठादाराचे दर जसे दिले तसे भरा.')),
          const SizedBox(height: 8),
          for (final l in _list(rfq['lines']))
            _card(
              key: Key('pqf-line-${l['line']}'),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${l['line']}. ${_s(l['name'])}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                _small('${purQty(l['qty'])} ${_s(l['unit'])}${[_s(l['brand']), _s(l['spec'])].any((x) => x.isNotEmpty) ? ' · ${[_s(l['brand']), _s(l['spec'])].where((x) => x.isNotEmpty).join(' · ')}' : ''}'),
                const SizedBox(height: 6),
                Row(children: [
                  for (final (i, f) in _kQf.indexed) ...[
                    if (i > 0) const SizedBox(width: 6),
                    Expanded(
                      flex: f.$1 == 'rate' ? 3 : 2,
                      child: TextBox(key: Key('pqf-${f.$1}-${l['line']}'), label: f.$2, controller: _b(l['line'], f.$1), enabled: !ro, kb: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(() {})),
                    ),
                  ],
                ]),
                Builder(builder: (_) {
                  final rate = _v(l['line'], 'rate'), disc = _v(l['line'], 'disc') ?? 0;
                  if (rate == null || rate <= 0) return _small(tr('not quoted'));
                  final net = rate * (1 - disc / 100);
                  return _small('${tr('Net rate')} ${purMoney(_r2(net))} · ${tr('Amount')} ${purMoney(_r2(net * _n(l['qty'])))}', color: C.ink);
                }),
              ]),
            ),
          TextBox(key: const Key('pqf-fr'), label: 'Freight ₹ (whole quotation)', controller: freight, enabled: !ro, kb: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(() {})),
          TextBox(key: const Key('pqf-ld'), label: 'Loading / unloading ₹', controller: loading2, enabled: !ro, kb: const TextInputType.numberWithOptions(decimal: true), onChanged: (_) => setState(() {})),
          TextBox(key: const Key('pqf-pt'), label: 'Payment terms', controller: terms, enabled: !ro),
          const SizedBox(height: 8),
          DateField(key: const Key('pqf-vt'), label: 'Valid till', value: valid, enabled: !ro, onChanged: (v) => setState(() => valid = v)),
          const SizedBox(height: 8),
          TextBox(key: const Key('pqf-rm'), label: 'Remark', controller: remark, enabled: !ro),
          const SizedBox(height: 12),
          _card(
            key: const Key('pqf-sum'),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _small('${tr('Lines')} ${purMoney(_r2(base))} + ${tr('freight and loading')} ${purMoney(_r2(extra))}'),
              Text('${purMoney(_r2(base + extra))} ${tr('without GST')}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              _small('${tr('GST beside')}: ${purMoney(_r2(gst))}'),
            ]),
          ),
          if (!ro) FilledButton(key: const Key('pqf-save'), onPressed: busy ? null : _save, child: Text(busy ? 'Saving…' : 'Save quotation')),
          if (hist.isNotEmpty)
            ExpansionTile(
              key: const Key('pqf-hist'),
              tilePadding: EdgeInsets.zero,
              title: Text(tr('Changed {0} times – the earlier versions').replaceAll('{0}', '${hist.length}'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              children: [
                for (final h in hist.reversed)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${_at(h['at'])} · ${_s(h['name']).isNotEmpty ? h['name'] : h['by']}', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                    subtitle: Text(
                        '${_list(h['lines']).map((l) => '${tr('line')} ${l['line']}: ${_s(l['rate'])}${_n(l['disc']) > 0 ? ' − ${l['disc']}%' : ''}').join(' · ')}${_n(h['freight']) + _n(h['loading']) > 0 ? ' · ${tr('freight and loading')} ${purMoney(_n(h['freight']) + _n(h['loading']))}' : ''}',
                        style: const TextStyle(fontSize: 12.5)),
                  ),
              ],
            ),
        ],
      ]),
    );
  }
}

/* ======================================== COMPARATIVE STATEMENT ======================================== */
/// "Who approves it" – the web's needText
String purNeedText(String need, String site, Object? lim) => need == 'admin'
    ? tr('a Purchase Admin of {0} (up to {1})').replaceAll('{0}', site).replaceAll('{1}', purMoney(lim))
    : lim == null
        ? tr('the Super Admin (no limit set)')
        : tr('the Super Admin (above {0})').replaceAll('{0}', purMoney(lim));

class PurCsScreen extends StatefulWidget {
  const PurCsScreen({super.key, required this.me, required this.rfq});
  final PurMe me;
  final int rfq;
  @override
  State<PurCsScreen> createState() => _PurCsScreenState();
}

class _PurCsScreenState extends State<PurCsScreen> {
  Map<String, dynamic>? data;
  final award = <String, int>{};
  final why = <String, TextEditingController>{};
  final few = TextEditingController();
  String err = '';
  bool loading = true, busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _take(Map<String, dynamic> r) {
    final c = r['cs'] == null ? null : _map(r['cs']);
    award.clear();
    for (final w in why.values) {
      w.text = '';
    }
    few.text = '';
    if (c != null) {
      _map(c['award']).forEach((line, a) {
        final m = _map(a);
        if (m['vendor'] != null) award[line] = _n(m['vendor']).toInt();
        _why(line).text = _s(m['reason']);
      });
      few.text = _s(c['few_reason']);
    }
    data = r;
  }

  TextEditingController _why(String line) => why.putIfAbsent(line, TextEditingController.new);

  Future<void> _load() async {
    setState(() {
      loading = true;
      err = '';
    });
    try {
      final r = await purCall(context, {'action': 'csGet', 'rfq': widget.rfq});
      if (!mounted) return;
      setState(() {
        _take(r);
        loading = false;
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

  Map<String, dynamic> _award() => {for (final e in award.entries) e.key: {'vendor': e.value, 'reason': _why(e.key).text.trim()}};

  Future<void> _do(Map<String, dynamic> body, String Function(Map<String, dynamic> r) done) async {
    setState(() {
      busy = true;
      err = '';
    });
    try {
      final r = await purCall(context, body);
      if (!mounted) return;
      toast(context, done(r));
      setState(() {
        _take(r);
        busy = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          err = errText(e);
        });
      }
    }
  }

  // the award as chosen here: the total, the GST, who approves and what still stops it (the server checks it all again) – the web's csLive
  (num, num, List<String>) _live(Map<String, dynamic> c) {
    final sh = _map(c['sheet']), prob = <String>[];
    num tot = 0, gst = 0;
    for (final l in _list(sh['lines'])) {
      final line = _s(l['line']), v = award[line], what = '${tr('Line')} $line (${l['name']})', l1 = [for (final x in (l['l1'] as List? ?? const [])) _n(x).toInt()];
      if (_n(l['n']) < 2 && few.text.trim().length < 3) prob.add('$what: ${_n(l['n']) > 0 ? tr('only 1 quotation') : tr('no quotation')} – ${tr('write why in "Fewer than 2 quotations – why".')}');
      if (v == null) {
        prob.add('$what: ${tr('not given to a supplier yet.')}');
        continue;
      }
      if (!l1.contains(v) && _why(line).text.trim().length < 3) prob.add('$what: ${tr('not given to L1 – write why.')}');
      final q = _map(_map(l['q'])['$v']);
      tot += _n(q['value']);
      gst += _n(q['gst_amt']);
    }
    return (_r2(tot), _r2(gst), prob);
  }

  Future<void> _send(Map<String, dynamic> c, num tot, String need) async {
    if (!await ask(context, tr('Send {0} for approval?').replaceAll('{0}', _s(c['ref'])), '${tr('Total without GST')}: ${purMoney(tot)} – ${tr('approved by')} $need.\n${tr('The quotations are locked once it is sent.')}', yes: 'Send for approval', no: 'Not yet')) return;
    if (!mounted) return;
    await _do({'action': 'csSend', 'no': c['no'], 'version': c['version'], 'award': _award(), 'few_reason': few.text.trim()}, (_) => '${c['ref']} – ${tr('sent for approval')}.');
  }

  Future<void> _decide(Map<String, dynamic> c, String act) async {
    var w = '';
    if (act == 'approve') {
      if (!await ask(context, tr('Approve {0}?').replaceAll('{0}', _s(c['ref'])), '${tr('Total without GST')}: ${purMoney(c['total'])} (${tr('GST')} ${purMoney(c['gst'])}).', yes: 'Approve')) return;
    } else {
      final t = await askNote(context, '${tr(act == 'back' ? 'Send back' : 'Reject')} ${c['ref']}?',
          label: act == 'back' ? 'What is to be corrected?' : 'Why is it rejected?', ok: act == 'back' ? 'Send back' : 'Reject', danger: act == 'reject', neededMsg: 'Write the reason (a few words).');
      if (t == null) return;
      w = t;
    }
    if (!mounted) return;
    await _do({'action': 'csDecide', 'no': c['no'], 'version': c['version'], 'act': act, 'why': w}, (r) => '${c['ref']} – ${tr(_s(_map(r['cs'])['status']).toLowerCase())}.');
  }

  Widget _vendorCell(Map<String, dynamic> c, Map<String, dynamic> l, Map<String, dynamic> v, bool ed) {
    final line = _s(l['line']), id = _n(v['id']).toInt(), q = _map(l['q'])['$id'] == null ? null : _map(_map(l['q'])['$id']);
    final l1 = (l['l1'] as List? ?? const []).map((x) => _n(x).toInt()).contains(id), on = award[line] == id;
    if (q == null) return Padding(padding: const EdgeInsets.only(top: 6), child: _small('${_s(v['name'])}: ${tr('not quoted')}'));
    final body = Container(
      key: Key('pcs-c-$line-$id'),
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: on ? C.greenSoft : (l1 ? const Color(0xFFF3FAF5) : C.bg), borderRadius: BorderRadius.circular(12), border: Border.all(color: on ? C.green : C.line, width: on ? 2 : 1)),
      child: Row(children: [
        if (ed) Padding(padding: const EdgeInsets.only(right: 8), child: Icon(on ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: on ? C.green : C.faint, size: 20)),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(_s(v['name']), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
              if (l1) const Pill('L1'),
            ]),
            Text(purMoney(q['landed']), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            _small('${tr('rate')} ${fmtNum(_n(q['rate']))}${_n(q['disc']) > 0 ? ' − ${q['disc']}%' : ''} · ${tr('amount')} ${purMoney(q['value'])}'),
            _small('${tr('GST')} ${q['gst'] == null ? '–' : '${q['gst']}% = ${purMoney(q['gst_amt'])}'}${q['days'] != null ? ' · ${q['days']} ${tr('days')}' : ''}'),
          ]),
        ),
      ]),
    );
    return ed ? InkWell(onTap: () => setState(() => award[line] = id), child: body) : body;
  }

  @override
  Widget build(BuildContext context) {
    final r = data, c = r?['cs'] == null ? null : _map(r?['cs']), rq = _map(r?['rfq']);
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(title: Text(c == null ? 'Comparative Statement' : '${_s(c['ref'])} · ${_s(c['rfq_ref'])}', style: const TextStyle(fontWeight: FontWeight.w700)), actions: withAsk([IconButton(tooltip: tr('Refresh'), onPressed: _load, icon: const Icon(Icons.refresh_rounded))])),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(key: const Key('pcs-view'), padding: const EdgeInsets.fromLTRB(Sp.edge, 8, Sp.edge, 40), children: [
          if (err.isNotEmpty) InfoLine(err, bad: true),
          if (loading) _wait(),
          if (!loading && r != null && c == null)
            _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Expanded(child: Text(_s(rq['ref']), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))), purPill(_s(rq['status']))]),
              const SizedBox(height: 6),
              Text(tr('{0} quotations entered.').replaceAll('{0}', '${_n(r['quotes'])}')),
              _small(_n(r['quotes']) > 0 ? tr('Make the CS – it is worked out from the quotations.') : tr('Enter the quotations first.')),
              if (_n(r['quotes']) > 0 && ['Sent', 'Quotes in'].contains(rq['status']))
                Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: FilledButton(
                        key: const Key('pcs-make'), onPressed: busy ? null : () => _do({'action': 'csMake', 'rfq': widget.rfq}, (r) => '${_map(r['cs'])['ref']} – ${tr('worked out from the quotations.')}'), child: const Text('Make the CS'))),
            ])),
          if (!loading && c != null) ..._sheet(c),
        ]),
      ),
    );
  }

  List<Widget> _sheet(Map<String, dynamic> c) {
    final sh = _map(c['sheet']), vs = _list(sh['vendors']), lines = _list(sh['lines']), may = _map(c['may']), ed = may['edit'] == true;
    final open = c['status'] == 'Draft' || c['status'] == 'Sent back';
    final (tot, gst, prob) = ed ? _live(c) : (_n(c['total']), _n(c['gst']), <String>[]);
    final lim = open ? c['limit'] : c['cs_limit'], need = ed ? (lim == null ? 'super' : tot <= _n(lim) ? 'admin' : 'super') : _s(c['need']);
    final needText = purNeedText(need, _s(c['site']), lim), anyFew = lines.any((l) => _n(l['n']) < 2);
    Widget tile(String label, String v, {Key? key}) => Expanded(
          child: Container(
            key: key,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: softShadow()),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_small(label), Text(v, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))]),
          ),
        );
    return [
      _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Expanded(child: Text('${_s(c['ref'])} · ${_s(c['rfq_ref'])}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))), purPill(_s(c['status']))]),
        _small('${tr('Made by')} ${_s(c['created_name'])} · ${tr('worked out')} ${_at(sh['at'])}${_s(c['sent_at']).isNotEmpty ? ' · ${tr('sent by')} ${_s(c['sent_name'])} ${_at(c['sent_at'])}' : ''}${_s(c['decided_at']).isNotEmpty ? ' · ${tr(_s(c['status']).toLowerCase())} ${tr('by')} ${_s(c['decided_name'])} ${_at(c['decided_at'])}' : ''}'),
      ])),
      Row(children: [tile(tr('Total without GST'), purMoney(tot), key: const Key('pcs-tot')), const SizedBox(width: 8), tile(tr('GST (beside)'), purMoney(gst))]),
      const SizedBox(height: 8),
      _card(key: const Key('pcs-need'), Row(children: [const Icon(Icons.how_to_reg_rounded, color: C.blue), const SizedBox(width: 8), Expanded(child: Text('${tr('Approves it')}: $needText', style: const TextStyle(fontWeight: FontWeight.w600)))])),
      _small(bi('WITHOUT GST: landed rate = rate less discount + freight and loading spread over his quoted lines by value. L1 = the lowest. A line not given to L1 needs a reason.', 'GST शिवाय; L1 = सर्वात कमी दर; L1 ला नाही दिले तर कारण.')),
      const SizedBox(height: 6),
      for (final l in lines)
        _card(
          key: Key('pcs-line-${l['line']}'),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${l['line']}. ${_s(l['name'])}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            _small('${purQty(l['qty'])} ${_s(l['unit'])} · ${_s(l['ref'])} · ${_s(l['site'])}'),
            if (_n(l['n']) < 2) Padding(padding: const EdgeInsets.only(top: 4), child: Pill(_n(l['n']) > 0 ? tr('1 quotation') : tr('no quotation'), color: C.amber, bg: C.amberSoft)),
            for (final v in vs) _vendorCell(c, l, v, ed),
            Builder(builder: (_) {
              final line = _s(l['line']), a = award[line], l1 = (l['l1'] as List? ?? const []).map((x) => _n(x).toInt()).contains(a);
              final name = vs.where((v) => _n(v['id']).toInt() == a).map((v) => _s(v['name'])).firstOrNull ?? '–';
              if (!ed) return Padding(padding: const EdgeInsets.only(top: 8), child: Text('${tr('Given to')}: $name${_why(line).text.isNotEmpty ? ' – ${_why(line).text}' : ''}', style: const TextStyle(fontWeight: FontWeight.w700)));
              if (a == null || l1) return const SizedBox.shrink();
              return Padding(padding: const EdgeInsets.only(top: 8), child: TextBox(key: Key('pcs-why-$line'), label: 'Why not L1', controller: _why(line), onChanged: (_) => setState(() {})));
            }),
          ]),
        ),
      const SectionTitle('Suppliers', mr: 'पुरवठादार'),
      for (final v in vs)
        _card(
          key: Key('pcs-v-${v['id']}'),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_s(v['name']), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            Text('${purMoney(v['total'])} ${tr('without GST')}', style: const TextStyle(fontWeight: FontWeight.w800)),
            _small('${tr('GST')} ${purMoney(v['gst'])} · ${_n(v['quoted'])} ${tr('of')} ${lines.length} ${tr('lines')} · L1 ${tr('on')} ${_n(v['l1'])}'),
            _small('${tr('Freight + loading')} ${purMoney(v['extra'])} · ${tr('on lines worth')} ${purMoney(v['base'])}'),
            if (_s(v['pay_terms']).isNotEmpty || _s(v['valid_till']).isNotEmpty) _small('${_s(v['pay_terms'])}${_s(v['valid_till']).isNotEmpty ? ' · ${tr('valid till')} ${_day(v['valid_till'])}' : ''}'),
            if (_s(v['remark']).isNotEmpty) _small(_s(v['remark'])),
          ]),
        ),
      if (anyFew || _s(c['few_reason']).isNotEmpty)
        ed
            ? TextBox(key: const Key('pcs-few'), label: 'Fewer than 2 quotations – why', controller: few, maxLines: 2, onChanged: (_) => setState(() {}))
            : _card(Text('${tr('Fewer than 2 quotations – why')}: ${_s(c['few_reason']).isEmpty ? '–' : c['few_reason']}')),
      if (ed && prob.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Column(key: const Key('pcs-prob'), crossAxisAlignment: CrossAxisAlignment.start, children: [for (final p in prob) _small('• $p', color: C.red)])),
      if (err.isNotEmpty) InfoLine(err, bad: true),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, children: [
        if (ed) ...[
          OutlinedButton(
              key: const Key('pcs-again'), style: _os,
              onPressed: busy ? null : () => _do({'action': 'csMake', 'rfq': widget.rfq, 'version': c['version']}, (r) => '${_map(r['cs'])['ref']} – ${tr('worked out from the quotations.')}'),
              child: const Text('Work out again')),
          OutlinedButton(
              key: const Key('pcs-save'), style: _os,
              onPressed: busy ? null : () => _do({'action': 'csSave', 'no': c['no'], 'version': c['version'], 'award': _award(), 'few_reason': few.text.trim()}, (_) => '${c['ref']} ${tr('saved')}.'),
              child: const Text('Save')),
          FilledButton(key: const Key('pcs-send'), style: _fs, onPressed: busy || prob.isNotEmpty ? null : () => _send(c, tot, needText), child: const Text('Send for approval')),
        ],
        if (may['decide'] == true) ...[
          FilledButton(key: const Key('pcs-ok'), style: _fs, onPressed: busy ? null : () => _decide(c, 'approve'), child: const Text('Approve')),
          OutlinedButton(key: const Key('pcs-back'), style: _os, onPressed: busy ? null : () => _decide(c, 'back'), child: const Text('Send back')),
          TextButton(key: const Key('pcs-rej'), onPressed: busy ? null : () => _decide(c, 'reject'), child: const Text('Reject', style: TextStyle(color: C.red))),
        ],
      ]),
      if (c['status'] == 'Sent' && may['decide'] != true) Padding(padding: const EdgeInsets.only(top: 8), child: _small('${tr('Waiting for')} $needText. ${_s(may['why'])}')),
      if (_list(c['trail']).isNotEmpty) ...[
        const SectionTitle('Decisions', mr: 'निर्णय'),
        for (final t in _list(c['trail']))
          _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [purPill(_s(t['act'])), const SizedBox(width: 8), Expanded(child: _small('${_s(t['name']).isNotEmpty ? t['name'] : t['by']} · ${_at(t['at'])}')), Text(purMoney(t['total']), style: const TextStyle(fontWeight: FontWeight.w700))]),
            if (_s(t['why']).isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(_s(t['why']))),
          ])),
      ],
      _small(tr('The printed CS: on the web (Purchase → Comparative Statement → Print).')),
    ];
  }
}

/* ======================================== WAITING FOR MY APPROVAL ======================================== */
class PurApproveScreen extends StatefulWidget {
  const PurApproveScreen({super.key, required this.me});
  final PurMe me;
  @override
  State<PurApproveScreen> createState() => _PurApproveScreenState();
}

class _PurApproveScreenState extends State<PurApproveScreen> {
  Map<String, dynamic>? data;
  String err = '';
  bool loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      err = '';
    });
    try {
      final r = await purCall(context, {'action': 'csList', 'mine': 1});
      if (!mounted) return;
      setState(() {
        data = r;
        loading = false;
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

  @override
  Widget build(BuildContext context) {
    final l = _list(data?['list']), far = _list(data?['elsewhere']);
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(title: const Text('Waiting for my approval', style: TextStyle(fontWeight: FontWeight.w700)), actions: withAsk()),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(key: const Key('pap-list'), padding: const EdgeInsets.fromLTRB(Sp.edge, 8, Sp.edge, 40), children: [
          _small(bi('Up to the limit a Purchase Admin of its site, above it the Super Admin – never one\'s own.', 'माझ्या मंजुरीसाठी.')),
          const SizedBox(height: 10),
          if (err.isNotEmpty) InfoLine(err, bad: true),
          if (loading) _wait(),
          if (!loading && data != null && l.isEmpty) const EmptyState('Nothing waits for you', 'A comparative statement sent for your approval shows here.', pic: 'clipboard'),
          if (!loading)
            for (final c in l)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Press(
                  key: Key('pap-row-${c['no']}'),
                  onTap: () async {
                    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PurCsScreen(me: widget.me, rfq: _n(c['rfq_no']).toInt())));
                    if (mounted) _load();
                  },
                  padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [Expanded(child: Text('${_s(c['ref'])} · ${_s(c['rfq_ref'])} · ${_s(c['site'])}', style: const TextStyle(fontWeight: FontWeight.w800))), Text(purMoney(c['total']), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5))]),
                    Text(_s(c['items']), maxLines: 2, overflow: TextOverflow.ellipsis),
                    _small('${tr('GST')} ${purMoney(c['gst'])} · ${tr('sent by')} ${_s(c['sent_name'])} ${_at(c['sent_at'])}'),
                  ]),
                ),
              ),
          if (far.isNotEmpty) _small(tr('Waiting for a Purchase Admin of another of your sites: {0} – open Purchase on that site (Change site) to decide it.').replaceAll('{0}', far.map((c) => '${c['ref']} (${c['site']})').join(', '))),
        ]),
      ),
    );
  }
}

/* ======================================== SUPPLIERS ======================================== */
class PurVendorsScreen extends StatefulWidget {
  const PurVendorsScreen({super.key, required this.me});
  final PurMe me;
  @override
  State<PurVendorsScreen> createState() => _PurVendorsScreenState();
}

class _PurVendorsScreenState extends State<PurVendorsScreen> {
  List<Map<String, dynamic>> rows = [];
  final find = TextEditingController();
  String err = '';
  bool loading = true, mayStatus = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      err = '';
    });
    try {
      final r = await purCall(context, {'action': 'vendorList'});
      if (!mounted) return;
      setState(() {
        rows = _list(r['vendors']);
        mayStatus = r['mayStatus'] == true;
        loading = false;
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

  Future<void> _form([Map<String, dynamic>? old]) async {
    final done = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => PurVendorForm(old: old)));
    if (done == true && mounted) _load();
  }

  Future<void> _status(Map<String, dynamic> v) async {
    final to = v['status'] == 'Approved' ? 'Blocked' : 'Approved';
    var w = '';
    if (to == 'Blocked') {
      final t = await askNote(context, tr('Block {0}?').replaceAll('{0}', _s(v['name'])), label: 'Why is he blocked? (he is not asked in a new enquiry)', ok: 'Block', danger: true, neededMsg: 'Write the reason (a few words).');
      if (t == null) return;
      w = t;
    } else if (!await ask(context, tr('Approve {0} again?').replaceAll('{0}', _s(v['name'])), tr('He can be asked in enquiries again.'), yes: 'Approve')) {
      return;
    }
    if (!mounted) return;
    try {
      await purCall(context, {'action': 'vendorStatus', 'id': v['id'], 'ver': v['ver'], 'status': to, 'why': w});
      if (!mounted) return;
      toast(context, '${v['name']} – ${tr(to.toLowerCase())}.');
      _load();
    } catch (e) {
      if (mounted) toast(context, errText(e), bad: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = find.text.trim().toLowerCase();
    final shown = [
      for (final v in rows)
        if (f.isEmpty || [v['name'], v['gstin'], v['phone'], ...(v['supplies'] as List? ?? const [])].join(' ').toLowerCase().contains(f)) v,
    ];
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(title: const TwoLang('Suppliers', 'पुरवठादार', size: 18, weight: FontWeight.w700), actions: withAsk()),
      floatingActionButton: FloatingActionButton.extended(key: const Key('pvn-new'), onPressed: () => _form(), icon: const Icon(Icons.add_rounded), label: const Text('Add supplier')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(key: const Key('pvn-list'), padding: const EdgeInsets.fromLTRB(Sp.edge, 8, Sp.edge, 100), children: [
          _small(bi('Purchase\'s own supplier list – one for every site. GST no. and PAN are checked.', 'पुरवठादारांची यादी.')),
          const SizedBox(height: 8),
          TextBox(key: const Key('pvn-find'), label: 'Find', controller: find, onChanged: (_) => setState(() {})),
          const SizedBox(height: 10),
          if (err.isNotEmpty) InfoLine(err, bad: true),
          if (loading) _wait(),
          if (!loading && shown.isEmpty && err.isEmpty) EmptyState(rows.isEmpty ? 'No supplier yet' : 'No supplier found', rows.isEmpty ? 'Add the first one.' : 'Try another word.', pic: 'package'),
          if (!loading)
            for (final v in shown)
              Opacity(
                opacity: v['status'] == 'Blocked' ? .6 : 1,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Press(
                    key: Key('pvn-row-${v['id']}'),
                    onTap: () => _form(v),
                    padding: const EdgeInsets.all(14),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [Expanded(child: Text(_s(v['name']), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5))), purPill(_s(v['status']))]),
                      if (_s(v['gstin']).isNotEmpty || _s(v['pan']).isNotEmpty) _small([_s(v['gstin']), _s(v['pan'])].where((x) => x.isNotEmpty).join(' · ')),
                      if (_s(v['phone']).isNotEmpty || _s(v['email']).isNotEmpty) _small([_s(v['phone']), _s(v['email'])].where((x) => x.isNotEmpty).join(' · ')),
                      if (_s(v['address']).isNotEmpty) _small(_s(v['address'])),
                      if ((v['supplies'] as List? ?? const []).isNotEmpty)
                        Padding(padding: const EdgeInsets.only(top: 6), child: Wrap(spacing: 6, runSpacing: 6, children: [for (final t in (v['supplies'] as List)) Pill('$t', color: C.blue, bg: C.blueSoft)])),
                      if (_s(v['status_note']).isNotEmpty) _small(_s(v['status_note']), color: C.red),
                      if (mayStatus)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                              key: Key('pvn-st-${v['id']}'),
                              onPressed: () => _status(v),
                              child: Text(v['status'] == 'Approved' ? 'Block' : 'Approve', style: TextStyle(color: v['status'] == 'Approved' ? C.red : C.green))),
                        ),
                    ]),
                  ),
                ),
              ),
        ]),
      ),
    );
  }
}

class PurVendorForm extends StatefulWidget {
  const PurVendorForm({super.key, this.old});
  final Map<String, dynamic>? old;
  @override
  State<PurVendorForm> createState() => _PurVendorFormState();
}

class _PurVendorFormState extends State<PurVendorForm> {
  final name = TextEditingController(), gstin = TextEditingController(), pan = TextEditingController(), phone = TextEditingController(), email = TextEditingController(), address = TextEditingController(), supplies = TextEditingController();
  String err = '';
  bool busy = false;

  @override
  void initState() {
    super.initState();
    final o = widget.old;
    if (o != null) {
      name.text = _s(o['name']);
      gstin.text = _s(o['gstin']);
      pan.text = _s(o['pan']);
      phone.text = _s(o['phone']);
      email.text = _s(o['email']);
      address.text = _s(o['address']);
      supplies.text = (o['supplies'] as List? ?? const []).join(', ');
    }
  }

  Future<void> _save() async {
    // the PAN is inside the GST no. (the web fills it the same way)
    final g = gstin.text.trim().toUpperCase();
    if (pan.text.trim().isEmpty && RegExp(r'^[0-9]{2}[A-Z]{5}[0-9]{4}').hasMatch(g)) pan.text = g.substring(2, 12);
    setState(() {
      busy = true;
      err = '';
    });
    final o = widget.old;
    try {
      final r = await purCall(context, {
        'action': 'vendorSave', if (o != null) 'id': o['id'], if (o != null) 'ver': o['ver'],
        'name': name.text.trim(), 'gstin': g, 'pan': pan.text.trim().toUpperCase(), 'phone': phone.text.trim(), 'email': email.text.trim(), 'address': address.text.trim(), 'supplies': supplies.text.trim(),
      });
      if (!mounted) return;
      toast(context, '${tr('Saved')} – ${_map(r['vendor'])['name']}.');
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          err = errText(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: C.bg,
        appBar: AppBar(title: Text(widget.old == null ? 'Add a supplier' : 'Change supplier', style: const TextStyle(fontWeight: FontWeight.w700))),
        body: ListView(key: const Key('pvf-form'), padding: const EdgeInsets.fromLTRB(Sp.edge, 10, Sp.edge, 30), children: [
          TextBox(key: const Key('pvf-name'), label: 'Name', controller: name),
          TextBox(key: const Key('pvf-gst'), label: 'GST no.', controller: gstin, upper: true),
          TextBox(key: const Key('pvf-pan'), label: 'PAN (from the GST no. when empty)', controller: pan, upper: true),
          TextBox(key: const Key('pvf-phone'), label: 'Mobile', controller: phone, kb: TextInputType.phone),
          TextBox(key: const Key('pvf-email'), label: 'E-mail', controller: email, kb: TextInputType.emailAddress),
          TextBox(key: const Key('pvf-addr'), label: 'Address', controller: address, maxLines: 2),
          TextBox(key: const Key('pvf-sup'), label: 'What he supplies (commas between: Cement, Steel …)', controller: supplies),
          if (err.isNotEmpty) InfoLine(err, bad: true),
          const SizedBox(height: 14),
          FilledButton(key: const Key('pvf-save'), onPressed: busy ? null : _save, child: Text(busy ? 'Saving…' : 'Save supplier')),
        ]),
      );
}

/* ======================================== SETTINGS – the CS limit (the Super Admin) ======================================== */
class PurSettingsScreen extends StatefulWidget {
  const PurSettingsScreen({super.key});
  @override
  State<PurSettingsScreen> createState() => _PurSettingsScreenState();
}

class _PurSettingsScreenState extends State<PurSettingsScreen> {
  Map<String, dynamic>? data;
  final limit = TextEditingController();
  String err = '';
  bool loading = true, busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _take(Map<String, dynamic> r) {
    data = r;
    limit.text = r['limit'] == null ? '' : fmtNum(_n(r['limit'])).replaceAll(',', '');
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      err = '';
    });
    try {
      final r = await purCall(context, {'action': 'settings'});
      if (!mounted) return;
      setState(() {
        _take(r);
        loading = false;
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
    setState(() {
      busy = true;
      err = '';
    });
    try {
      final r = await purCall(context, {'action': 'settingsSave', 'limit': limit.text.trim()});
      if (!mounted) return;
      toast(context, tr('The CS limit is {0}.').replaceAll('{0}', purMoney(r['limit'])));
      setState(() {
        _take(r);
        busy = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          err = errText(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = data;
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(title: const Text('CS approval limit', style: TextStyle(fontWeight: FontWeight.w700))),
      body: ListView(key: const Key('pse-form'), padding: const EdgeInsets.fromLTRB(Sp.edge, 10, Sp.edge, 30), children: [
        _small(bi('Up to this amount (the CS total without GST) a Purchase Admin of its site approves a comparative statement; above it the Super Admin. Not set: every CS goes to the Super Admin.',
            'या रकमेपर्यंत Purchase Admin, त्यावर Super Admin मंजूर करतात.')),
        const SizedBox(height: 10),
        if (err.isNotEmpty) InfoLine(err, bad: true),
        if (loading) _wait(),
        if (!loading && r != null) ...[
          _card(
            key: const Key('pse-now'),
            r['limit'] == null
                ? Text(tr('Not set – every CS goes to the Super Admin.'), style: const TextStyle(fontWeight: FontWeight.w700))
                : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _small(tr('Now')),
                    Text(purMoney(r['limit']), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                    if (_s(r['by']).isNotEmpty) _small('${tr('set by')} ${r['by']} · ${_at(r['at'])}'),
                  ]),
          ),
          if (r['maySet'] == true) ...[
            TextBox(key: const Key('pse-lim'), label: 'Limit ₹', controller: limit, kb: const TextInputType.numberWithOptions(decimal: true)),
            const SizedBox(height: 14),
            FilledButton(key: const Key('pse-save'), onPressed: busy ? null : _save, child: Text(busy ? 'Saving…' : 'Save')),
          ],
        ],
      ]),
    );
  }
}
