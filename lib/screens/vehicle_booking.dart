/* (3.91.0, Mechanical update-216, asked 08-11-2026 – the HO features, part 2) VEHICLE BOOKING – the app's own screen of the web's page:
 * a person with the page asks for a vehicle (from / until, from where to where, why, people, the vehicle he wants); those given
 * "Vehicle Booking – approve" (and the Admin) see every booking and give it – the vehicle and its driver – or say no with why; the
 * person who asked (or one who approves) cancels it before it is over. The same server actions, checks and access as the web:
 * getBookings, saveBooking, decideBooking, cancelBooking (the server never gives one vehicle to two bookings at the same time). */
import 'package:flutter/material.dart' hide Text;

import '../core/format.dart';
import '../ui/ask_bot.dart';
import '../ui/fields.dart';
import '../ui/scope.dart';
import '../ui/t.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

Future<void> openBooking(BuildContext context) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const BookingScreen()));

String _when(Map b) {
  final f = '${b['from'] ?? ''}', t = '${b['to'] ?? ''}';
  if (f.length < 16 || t.length < 16) return '';
  return '${showDate(f.substring(0, 10))} ${f.substring(11)} – ${t.substring(0, 10) == f.substring(0, 10) ? '' : '${showDate(t.substring(0, 10))} '}${t.substring(11)}';
}

Color _tone(String s) => s == 'Approved' ? C.green : s == 'Rejected' ? C.red : s == 'Cancelled' ? C.faint : C.amber;
bool _live(Map b) {
  final st = '${b['status']}', t = DateTime.tryParse('${b['to']}:00+05:30');
  return (st == 'Requested' || st == 'Approved') && t != null && t.isAfter(DateTime.now());
}

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key});
  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  List<Map<String, dynamic>> rows = [];
  bool loading = true, canDecide = false;
  String err = '', missing = '', me = '', status = '';
  int _seq = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final s = SessionScope.read(context), my = ++_seq;
    setState(() {
      loading = true;
      err = '';
    });
    try {
      final d = (await s.api.call('getBookings', [<String, dynamic>{}]) as Map).cast<String, dynamic>();
      if (my != _seq || !mounted) return;
      setState(() {
        rows = [for (final x in (d['rows'] as List? ?? const []).whereType<Map>()) x.cast<String, dynamic>()];
        canDecide = d['canDecide'] == true;
        missing = '${d['missing'] ?? ''}';
        me = '${d['me'] ?? ''}';
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

  Future<void> _ask() async {
    final r = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const BookingForm()));
    if (r == true && mounted) _load();
  }

  Future<void> _cancel(Map<String, dynamic> b) async {
    final s = SessionScope.read(context);
    if (!await ask(context, tr('Cancel booking {0}?').replaceAll('{0}', '${b['id']}'), '${_when(b)} · ${b['placeTo']}', yes: 'Cancel the booking', no: 'Keep it', danger: true)) return;
    try {
      await s.api.call('cancelBooking', ['${b['id']}'], true);
      if (!mounted) return;
      toast(context, tr('Booking {0} cancelled.').replaceAll('{0}', '${b['id']}'));
      _load();
    } catch (e) {
      if (mounted) toast(context, errText(e), bad: true);
    }
  }

  Future<void> _decide(Map<String, dynamic> b) async {
    final s = SessionScope.read(context);
    final no = TextEditingController(text: '${b['no'] ?? ''}'), drv = TextEditingController(text: '${b['driver'] ?? ''}'), reply = TextEditingController();
    final r = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (c) => Padding(
        padding: EdgeInsets.fromLTRB(Sp.edge, 6, Sp.edge, MediaQuery.of(c).viewInsets.bottom + Sp.edge),
        child: StatefulBuilder(builder: (c, set) {
          return ListView(shrinkWrap: true, children: [
            Text('${tr('Booking')} ${b['id']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('${_when(b)} · ${b['byName'] ?? b['by']}', style: const TextStyle(color: C.muted)),
            const SizedBox(height: 12),
            Press(
              key: const Key('vbd-no'),
              onTap: () async {
                final p = await pickFromList(c, tr('Vehicle'), [for (final m in s.machines) m.id]);
                if (p != null) set(() => no.text = p);
              },
              radius: 14,
              shadow: false,
              border: C.line,
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                const Icon(Icons.directions_car_rounded, color: C.green),
                const SizedBox(width: 10),
                Expanded(child: Text(no.text.isEmpty ? tr('Pick the vehicle') : no.text, style: TextStyle(fontWeight: FontWeight.w700, color: no.text.isEmpty ? C.faint : C.ink))),
                const Icon(Icons.chevron_right_rounded, color: C.faint),
              ]),
            ),
            const SizedBox(height: 10),
            TextBox(key: const Key('vbd-driver'), label: 'Driver', controller: drv, options: s.drivers),
            TextBox(key: const Key('vbd-reply'), label: 'Reply', controller: reply),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: FilledButton(key: const Key('vbd-ok'), style: FilledButton.styleFrom(minimumSize: const Size(0, 46)), onPressed: () => Navigator.pop(c, true), child: Text('Approve'))),
              const SizedBox(width: Sp.chips),
              Expanded(child: OutlinedButton(key: const Key('vbd-not'), style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46), foregroundColor: C.red), onPressed: () => Navigator.pop(c, false), child: Text('Not given'))),
            ]),
          ]);
        }),
      ),
    );
    if (r == null || !mounted) return;
    try {
      await s.api.call('decideBooking', ['${b['id']}', {'approve': r, 'no': no.text.trim(), 'driver': drv.text.trim(), 'reply': reply.text.trim()}], true);
      if (!mounted) return;
      toast(context, tr(r ? 'Booking {0} approved.' : 'Booking {0} not given.').replaceAll('{0}', '${b['id']}'));
      _load();
    } catch (e) {
      if (mounted) toast(context, errText(e), bad: true);
    }
  }

  Widget _card(Map<String, dynamic> b) {
    final st = '${b['status']}', mine = '${b['by']}' == me, live = _live(b), id = '${b['id']}';
    return Container(
      key: Key('vb-$id'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(id, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
          const Spacer(),
          Pill(tr(st), color: _tone(st), bg: _tone(st).withValues(alpha: .1)),
        ]),
        const SizedBox(height: 6),
        Text(_when(b), style: const TextStyle(fontWeight: FontWeight.w700)),
        Text('${'${b['placeFrom'] ?? ''}'.isEmpty ? '' : '${b['placeFrom']} → '}${b['placeTo'] ?? ''}', style: const TextStyle(color: C.ink)),
        Text('${b['purpose'] ?? ''}${'${b['people'] ?? ''}'.isEmpty ? '' : ' · ${b['people']} ${tr('people')}'}', style: const TextStyle(color: C.muted)),
        if (canDecide) Text('${tr('Asked by')} ${b['byName'] ?? b['by']}', style: const TextStyle(color: C.muted, fontSize: 13)),
        if ('${b['no'] ?? ''}'.isNotEmpty) Text('${b['no']}${'${b['driver'] ?? ''}'.isEmpty ? '' : ' · ${tr('driver')} ${b['driver']}'}', style: const TextStyle(color: C.green, fontWeight: FontWeight.w700)),
        if ('${b['reply'] ?? ''}'.isNotEmpty) Text('${b['reply']}', style: const TextStyle(color: C.muted, fontStyle: FontStyle.italic)),
        Wrap(spacing: 4, children: [
          if (canDecide && (st == 'Requested' || (st == 'Approved' && live))) TextButton(key: Key('vb-decide-$id'), onPressed: () => _decide(b), child: Text(st == 'Requested' ? 'Decide' : 'Change vehicle')),
          if (live && (mine || canDecide)) TextButton(key: Key('vb-cancel-$id'), style: TextButton.styleFrom(foregroundColor: C.red), onPressed: () => _cancel(b), child: Text('Cancel')),
        ]),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context), shown = rows.where((b) => status.isEmpty || b['status'] == status).toList();
    final waiting = rows.where((b) => b['status'] == 'Requested').length;
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(title: Text('Vehicle Booking', style: const TextStyle(fontWeight: FontWeight.w700)), actions: withAsk([IconButton(tooltip: tr('Refresh'), onPressed: _load, icon: const Icon(Icons.refresh_rounded))])),
      floatingActionButton: s.canEdit('Vehicle Booking') && missing.isEmpty
          ? FloatingActionButton.extended(key: const Key('vb-ask'), onPressed: _ask, icon: const Icon(Icons.add_rounded), label: Text('Ask for a vehicle'))
          : null,
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(key: const Key('vb-list'), padding: const EdgeInsets.fromLTRB(Sp.edge, 10, Sp.edge, 90), children: [
          if (loading && rows.isEmpty) const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator())),
          if (err.isNotEmpty) Text(err, style: const TextStyle(color: C.red)),
          if (missing.isNotEmpty) Text(missing, style: const TextStyle(color: C.amber)),
          if (!loading && missing.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(canDecide ? '${tr('Every booking – you decide them.')} ${tr('Waiting')}: $waiting' : tr('Your bookings.'), style: const TextStyle(color: C.muted)),
            ),
          if (rows.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Wrap(spacing: 6, runSpacing: 6, children: [
                for (final st in ['', 'Requested', 'Approved', 'Rejected', 'Cancelled'])
                  ChoiceChip(key: Key('vb-st-${st.isEmpty ? 'all' : st}'), label: Text(st.isEmpty ? 'All' : st), selected: status == st, onSelected: (_) => setState(() => status = st)),
              ]),
            ),
          if (!loading && missing.isEmpty && shown.isEmpty) const EmptyState('No booking', 'Ask for a vehicle with the button below.', pic: 'calendar'),
          for (final b in shown) _card(b),
        ]),
      ),
    );
  }
}

/// A person asks for a vehicle.
class BookingForm extends StatefulWidget {
  const BookingForm({super.key});
  @override
  State<BookingForm> createState() => _BookingFormState();
}

class _BookingFormState extends State<BookingForm> {
  final pFrom = TextEditingController(), pTo = TextEditingController(), purpose = TextEditingController(), people = TextEditingController(), remark = TextEditingController();
  String fDate = '', tDate = '', fTime = '09:00', tTime = '18:00', no = '', err = '';
  bool busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final t = SessionScope.read(context).today;
      setState(() {
        fDate = t;
        tDate = t;
      });
    });
  }

  Widget _time(String key, String label, String v, ValueChanged<String> on) => Press(
        key: Key(key),
        onTap: () async {
          final p = v.split(':'), r = await showTimePicker(context: context, initialTime: TimeOfDay(hour: int.tryParse(p[0]) ?? 9, minute: int.tryParse(p.length > 1 ? p[1] : '0') ?? 0));
          if (r != null) on('${r.hour.toString().padLeft(2, '0')}:${r.minute.toString().padLeft(2, '0')}');
        },
        radius: 14,
        shadow: false,
        border: C.line,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        child: Row(children: [const Icon(Icons.schedule_rounded, color: C.green, size: 20), const SizedBox(width: 8), Text('${tr(label)} $v', style: const TextStyle(fontWeight: FontWeight.w700))]),
      );

  Future<void> _send() async {
    final s = SessionScope.read(context);
    setState(() {
      busy = true;
      err = '';
    });
    try {
      final r = (await s.api.call('saveBooking', [
        {'from': '${fDate}T$fTime', 'to': '${tDate}T$tTime', 'placeFrom': pFrom.text.trim(), 'placeTo': pTo.text.trim(), 'purpose': purpose.text.trim(), 'people': people.text.trim(), 'no': no, 'remark': remark.text.trim()}
      ], true) as Map);
      if (!mounted) return;
      toast(context, tr('Booking {0} sent – you get a message when it is decided.').replaceAll('{0}', '${r['id']}'));
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
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(title: Text('Ask for a vehicle', style: const TextStyle(fontWeight: FontWeight.w700))),
      body: ListView(key: const Key('vbf'), padding: const EdgeInsets.fromLTRB(Sp.edge, 10, Sp.edge, 30), children: [
        const FormHead('Needed from'),
        DateField(key: const Key('vbf-fdate'), label: 'Date', value: fDate, clear: false, first: DateTime.tryParse(s.today), onChanged: (v) => setState(() => fDate = v)),
        const SizedBox(height: 8),
        _time('vbf-ftime', 'Time', fTime, (v) => setState(() => fTime = v)),
        const FormHead('Until'),
        DateField(key: const Key('vbf-tdate'), label: 'Date', value: tDate, clear: false, first: DateTime.tryParse(s.today), onChanged: (v) => setState(() => tDate = v)),
        const SizedBox(height: 8),
        _time('vbf-ttime', 'Time', tTime, (v) => setState(() => tTime = v)),
        const FormHead('Where and why'),
        TextBox(key: const Key('vbf-pfrom'), label: 'From (place)', controller: pFrom, hint: 'Head Office'),
        TextBox(key: const Key('vbf-pto'), label: 'To (place) *', controller: pTo),
        TextBox(key: const Key('vbf-purpose'), label: 'Purpose *', controller: purpose),
        TextBox(key: const Key('vbf-people'), label: 'People', controller: people, kb: TextInputType.number),
        Press(
          key: const Key('vbf-no'),
          onTap: () async {
            final p = await pickFromList(context, tr('Vehicle wanted'), ['', for (final m in s.machines) m.id]);
            if (p != null) setState(() => no = p);
          },
          radius: 14,
          shadow: false,
          border: C.line,
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            const Icon(Icons.directions_car_rounded, color: C.green),
            const SizedBox(width: 10),
            Expanded(child: Text(no.isEmpty ? tr('Vehicle wanted – any') : no, style: TextStyle(fontWeight: FontWeight.w700, color: no.isEmpty ? C.faint : C.ink))),
            const Icon(Icons.chevron_right_rounded, color: C.faint),
          ]),
        ),
        const SizedBox(height: 8),
        TextBox(key: const Key('vbf-remark'), label: 'Remark', controller: remark),
        if (err.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(err, style: const TextStyle(color: C.red))),
        const SizedBox(height: 12),
        FilledButton(key: const Key('vbf-send'), onPressed: busy ? null : _send, child: Text(busy ? 'Sending…' : 'Send request')),
      ]),
    );
  }
}
