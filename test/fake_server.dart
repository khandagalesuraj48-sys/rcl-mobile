/* A pretend Portal + Mechanical for the tests (no network): it answers like the real ones, from data kept here. */
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rcl_mobile/core/grn_reg.dart' show grnDocKey;

class FakeServer {
  final calls = <String>[];
  int tickets = 0;
  bool portalSignedIn = false, superAdmin = false, mustChange = false;
  // (3.104.0) the Portal's code by e-mail: switched on?, the e-mail a code goes to, the code, where codes went, his e-mail's state in "me"
  bool otpOn = false;
  String otpMail = 'sujit.own@rcl.test', otpCode = '482913', verifyTo = '';
  final codesTo = <String>[];
  Map<String, dynamic>? mailInfo;
  int alerts = 0;
  bool tester = false; // (02-11-2026) the Portal's "me": a tester (the beta channel)
  /// (3.31.2 – update-143) the date and shift asked for is already saved: the server's prefill says so (addTo) and the save adds to it
  Map<String, dynamic>? addTo;
  String newPassword = '';
  String expireOnce = ''; // an action that first answers SESSION_EXPIRED (a Mechanical sign-in that ended)
  Map<String, String> perms = {'Diesel Issue': 'Edit', 'Diesel Inward': 'View', 'Diesel Transfer': 'None', 'Dashboard': 'View', 'Log Book': 'View', 'Reports': 'View', 'Master': 'View'};
  /// (3.43.0, Mechanical update-162) his diesel sources (getInit's user.dsrc); [userInSync]: the sync tells the user too (as Mechanical)
  Map<String, dynamic>? dsrc;
  bool userInSync = false;
  List<String>? pageAdmin; // (3.64.0, Mechanical update-189) the pages where he is Admin (entries of an earlier day)
  String? syncToday; // (3.62.1) the server's today in the live sync (Mechanical's sync gives it)
  /// (3.44.0, Mechanical update-163) a site with a place per fuel card (HO): DIESEL CARD, PETROL CARD, PETROL CAN, CNG CARD with their
  /// fuel (getInit's placeFuels), and a Petrol, a CNG and an Electric car
  bool fuels = false;
  /// (3.45.0, Mechanical update-164) a site on FUEL CARDS (HO): no diesel places, no stock – the cards with their balances (with the
  /// stock), a fill paid by a card or in Cash with its ₹; the cars of [fuels] (Petrol, CNG, Electric) are there too
  bool card = false;
  final cards = <Map<String, dynamic>>[
    {'name': 'HDFC FUEL', 'last4': '4321', 'type': 'Fuel card', 'cars': <String>[], 'opening': 20000, 'openDate': '2026-10-01', 'active': true, 'paid': 5000, 'spent': 3200, 'balance': 21800, 'fills': 2, 'payments': 1, 'lastFill': '2026-10-13', 'used': true},
    {'name': 'SBI CREDIT', 'last4': '9876', 'type': 'Credit card', 'cars': ['MH-12-HO-1163'], 'opening': 1000, 'openDate': '2026-10-01', 'active': true, 'paid': 0, 'spent': 1500, 'balance': -500, 'fills': 1, 'payments': 0, 'lastFill': '2026-10-12', 'used': true,
      // (3.47.0, Mechanical update-166) its details; it ends this month (17 days to its last day from 14-10-2026)
      'issuer': 'SBI Card', 'holder': 'Rachana Construction Ltd', 'expiry': '2026-10', 'custId': 'SBI-44120', 'expDays': 17},
    {'name': 'OLD CARD', 'last4': '1111', 'type': 'Debit card', 'cars': <String>[], 'opening': 0, 'openDate': '2026-09-01', 'active': false, 'paid': 0, 'spent': 0, 'balance': 0, 'fills': 0, 'payments': 0, 'lastFill': '', 'used': false},
  ];
  final cardCalls = <Map<String, dynamic>>[];
  /// (3.86.0, Mechanical update-212) HO's cars: their photos (number → { t, f, exp, v } as the server gives them), the calls about them;
  /// [carLinksEnd]: the links given end at once (the phone must ask for new ones); [carRefuse]: the server refuses a photo (not the Admin)
  final carPhotos = <String, Map<String, dynamic>>{
    'MH-12-HO-1163': {'t': 'https://store.test/car/t1?token=a', 'f': 'https://store.test/car/f1?token=a', 'exp': DateTime.now().millisecondsSinceEpoch + 900000, 'v': 'v1hycross'},
  };
  final carCalls = <Map<String, dynamic>>[];
  // (3.88.0, Mechanical update-213) the vehicle alerts it gives (none unless a test sets them) and how often they were asked
  Map<String, dynamic>? vehAlerts;
  int vaCalls = 0;
  // (3.91.0, Mechanical update-216) Vehicle Booking and Vehicle Expenses, as the server keeps them
  final bookings = <Map<String, dynamic>>[];
  final vexp = <Map<String, dynamic>>[];
  final vbCalls = <Map<String, dynamic>>[];
  Map<String, dynamic>? stmtAnswer;
  bool carLinksEnd = false;
  String carRefuse = '';
  Map<String, dynamic> carLink(String no, String v, int n) => {'t': 'https://store.test/car/t-$v?token=$n', 'f': 'https://store.test/car/f-$v?token=$n', 'exp': DateTime.now().millisecondsSinceEpoch + (carLinksEnd ? 1000 : 900000), 'v': v};
  /// (3.46.0, Mechanical update-165) the maintenance bills of the cars at a site on fuel cards; [maintMissing]: step 1zi not run yet
  bool maintMissing = false;
  final maintCalls = <Map<String, dynamic>>[];
  final maint = <Map<String, dynamic>>[
    {'id': 'MT-000002', 'date': '2026-10-12', 'no': 'MH-12-HO-2163', 'garage': 'Tyre House', 'billNo': 'TH-9', 'km': '', 'total': 6300, 'service': false, 'remark': '', 'enteredBy': 'Sujit Mule', 'updatedBy': '',
      'lines': [{'work': 'Tyre', 'amount': 6000}, {'work': 'Discount', 'amount': -100}, {'work': 'Engine oil', 'amount': 400}], 'files': []},
    {'id': 'MT-000001', 'date': '2026-10-05', 'no': 'MH-12-HO-1163', 'garage': 'Toyota Service', 'billNo': 'TS-101', 'km': 45210, 'total': 2360, 'service': true, 'remark': 'first service', 'enteredBy': 'Sujit Mule', 'updatedBy': '',
      'lines': [{'work': 'Engine oil', 'amount': 1200}, {'work': 'Oil filter', 'amount': 300}, {'work': 'Labour', 'amount': 500}, {'work': 'GST 18%', 'amount': 360}],
      'files': [{'sha': 'a1' * 32, 'p': 'log/a1/${'a1' * 32}.pdf', 'mime': 'application/pdf', 'size': 52000, 'name': 'bill.pdf', 'at': '2026-10-05T06:00:00Z', 'by': 'Sujit Mule'}]},
  ];
  /// (3.53.0, Mechanical update-173, 28-10-2026) what the AI reads of an old log book (readMaintLog – one a call, in order: a Map, or
  /// 'cut' – an answer cut off) and the names it finds written in more than one way (maintImportNames)
  /// (3.59.0, Mechanical update-183) also: 'busy' – the AI busy (an error, asked again by the app); a Map may carry 'more' / 'last'
  /// (a part of the page – the next part is asked after its last row)
  final mliPages = <Object>[];
  Map<String, dynamic> mliNames = {'fixes': []};
  /// (3.59.0) maintImportNames answers "busy" this many times first
  int mliNamesBusy = 0;
  /// (3.59.0, Mechanical update-184) the site keeps the vendor's Owner Name and documents (step 1zj run); the documents' files (sha → its
  /// record and bytes); the files the app downloaded (their links); importCompliance's machinery left out (not Own)
  bool vdocsOn = false;
  final vendorFiles = <String, Map<String, dynamic>>{};
  final fileGets = <String>[];
  List<String> cmpSkipped = [];
  // (3.79.0, Mechanical update-205) the documents of Vehicle Compliance: the site keeps them (step 1zl); the files sent (cmpDoc); the
  // lines of the history with their files
  bool cmpFilesOn = false;
  final cmpSent = <String, Map<String, dynamic>>{};
  final cmpRows = <Map<String, dynamic>>[
    {'id': 'CMP-000001', 'no': 'MH-25-AJ-2169', 'doc': 'RC Book', 'from': '', 'to': '', 'on': '2026-09-01', 'docNo': 'MH25AJ2169', 'amount': '', 'remark': '', 'source': 'Document', 'by': 'Tester',
      'files': [{'sha': 'c' * 64, 'p': 'log/cc/${'c' * 64}.jpg', 'mime': 'image/jpeg', 'size': 1200, 'name': 'rc old.jpg', 'at': '2026-09-01T05:00:00Z', 'by': 'Tester'}]},
  ];
  /// (3.49.0, Mechanical update-168) what maintLog answers instead of the bill below (null: that one)
  Map<String, dynamic>? maintLogAnswer;
  /// (3.56.0, Mechanical update-180) the lines of MT-000001 in the log book below – changed / taken out by updateMaintLine / deleteMaintLine
  final mlogLines = <Map<String, dynamic>>[
    {'work': 'Engine oil', 'amount': 1200},
    {'work': 'Oil filter', 'amount': 300},
    {'work': 'Labour', 'amount': 500},
    {'work': 'GST 18%', 'amount': 360},
  ];
  /// what "Read the bill (AI)" answers (readMaintBill)
  Map<String, dynamic> maintRead = {'date': '2026-10-13', 'billNo': 'MS-77', 'garage': 'Maruti Service', 'vehicle': 'MH12HO1163', 'km': 46100, 'service': true, 'total': 3540, 'check': '',
    'lines': [{'work': 'Service charge', 'amount': 2500}, {'work': 'Coolant', 'amount': 500}, {'work': 'GST 18%', 'amount': 540}]};
  final cardPays = <Map<String, dynamic>>[
    {'id': 'CP-000001', 'date': '2026-10-05', 'card': 'HDFC FUEL', 'amount': 5000, 'ref': 'UTR 1234', 'remark': 'recharge', 'photos': 1, 'enteredBy': 'Sujit Mule', 'updatedBy': ''},
  ];
  /// the bill of [mlogLines]: its lines with their GST (a free line ₹ 0)
  num get _mlogTotal => mlogLines.fold<num>(0, (t, l) {
        final a = l['amount'] is num ? l['amount'] as num : 0, g = l['gst'] is num ? l['gst'] as num : 0, paid = (l['type'] ?? 'Paid') == 'Paid' || l['type'] == 'By Insurance';
        final gv = _hasGa(l) ? l['gstAmt'] as num : 2 * ((a * g / 200) * 100).round() / 100;      // (3.59.0, Mechanical update-183) its GST ₹ as in the old log book
        return paid ? ((t + a + gv) * 100).round() / 100 : t;
      });
  /// (3.59.0) as the server's maintHasGa_: a line's GST ₹ as in the old log book (no GST %)
  static bool _hasGa(Map l) => l['gstAmt'] is num && !((l['gst'] is num ? l['gst'] as num : 0) > 0);
  Map<String, dynamic> get cardStock => {'stock': 0, 'byLoc': <String, dynamic>{}, 'cards': cards};
  final issueBal = <List>[];
  final saved = <Map<String, dynamic>>[];
  final logSaved = <Map<String, dynamic>>[];
  // (3.34.0, Mechanical update-153) attachments: the files sent (uploadAttachment), the entry's files (getLogEntry → att), Scan with
  // Mobile (the code the "computer" made, what the phone added) and a saved bill's files (getBillAttachments)
  final uploads = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> entryAtt = [];
  final capCodeOk = '${'a' * 32}.${'b' * 64}';
  final capAdds = <Map<String, dynamic>>[];
  // (3.42.0, Mechanical update-161) the phone given for the notifications (fcmSave) / taken off (fcmOff): [action, token, site]
  final fcm = <List<String>>[];
  int capHave = 0;
  bool billLock = false; // (14-10-2026) the entries are in a submitted bill: Mechanical refuses a change (not the Super Admin's)
  bool apLock = false; // (3.33.0, Mechanical update-152) the entry was approved in verification: refused the same way (not the Super Admin's)
  final saReasons = <String>[]; // (3.33.0) the Super Admin's reasons that came with a save of a locked entry
  final requests = <Map<String, dynamic>>[];
  bool tanker = false; // a water tanker (Log Book Format I) on the site, with an entry of 2 trips today
  bool tanker2 = false; // (3.18.1) a second water tanker of another agency, with a trip on 13-10-2026
  // (3.1.7) verification (update-114), the live sync, no network
  String flowFor = ''; // an action the Super Admin put under verification: answered "Sent for verification …" (nothing saved)
  Map<String, String> versions = {'master': '1', 'stock': '1', 'log': '1', 'users': '1', 'activity': '1', 'flow': '1'};
  int crPending = 0, crForMe = 0;
  Map<String, dynamic> flowMine = {}; // (update-116) his works under verification (getInit "flow")
  final flowReqs = <Map<String, dynamic>>[]; // (3.1.11, update-118) the Approvals list (his entries in verification)
  final reminded = <List<String>>[];
  /// (3.21.1) "Send again" asked: {id | ids, note}; an id in [resendRefuse] is refused by the save again (Mechanical's words)
  final resent = <Map<String, dynamic>>[];
  final resendRefuse = <String, String>{};
  /// (3.22.0, Mechanical update-130) "Open & correct": each entry's {fn, form, args, check}; the corrected entries that came; an id in
  /// [editRefuse] is answered as its save would (errors / warnings / warning – nothing sent) until it comes with force
  final fixOf = <String, Map<String, dynamic>>{};
  final edited = <Map<String, dynamic>>[];
  /// (3.23.0, Mechanical update-132) the rate history machinery-wise that getBoqs gives
  final boqHist = <Map<String, dynamic>>[];
  final editRefuse = <String, Map<String, dynamic>>{};
  // (3.25.0, Mechanical update-134) the Super Admin's delete: the entries of the dates, those deleted, the refusals (id → words)
  final sdSaved = <Map<String, dynamic>>[], sdWaiting = <Map<String, dynamic>>[], sdDeleted = <Map<String, dynamic>>[];
  final sdRefuse = <String, String>{};
  final sdAsked = <Map<String, dynamic>>[];
  // (3.26.0) calls with the web: the notes the app sent (rtcSend), the notes waiting for the app (given with the next sync), what the
  // heartbeats said they had read (rtc {r}), the missed calls
  final rtcSent = <Map<String, dynamic>>[], rtcIn = <Map<String, dynamic>>[], rtcBeats = <dynamic>[];
  int rtcN = 40;
  List<Map<String, dynamic>> rtcMissed = [];
  List<Map<String, dynamic>> rtcPeople = [
    {'uid': 'u-mahesh', 'name': 'Mahesh Jadhav', 'admin': false},
    {'uid': 'u-office', 'name': 'Office Admin', 'admin': true},
  ];
  int billsSent = 0; // (3.1.13) bill copies sent (inwardPhoto)
  final decided = <Map<String, dynamic>>[]; // (3.2.0) what the Approvals screen sent (decide, several, answer)
  final flowDetails = <String, Map<String, dynamic>>{}; // (3.31.5, update-147) an entry in full, by its number
  final ldSaved = <Map<String, dynamic>>[]; // (3.31.7, update-149) what the Log Book Debit Statement saved
  final detAsked = <List<String>>[]; // …and which numbers were asked for
  final rulesSaved = <Map<String, dynamic>>[];
  final reportAsked = <Map<String, dynamic>>[]; // (3.2.0) the reports asked, with their filters
  bool down = false; // no network to Mechanical
  /// (3.85.0, Mechanical update-211) what came with the saves (the 4th part: {short, made, reason}); the stock cannot cover the next
  /// diesel issues / transfers ([short] – "Not enough …", or kept as stock short when {short: true} came); the photos sent
  final metas = <Map<String, dynamic>>[];
  bool short = false;
  int photosSent = 0;
  static const stamp = '1760420000000.0123456789abcdef0123456789abcdef';
  bool portalDown = false; // (3.20.1) no network to the Portal either
  int portalStatus = 0; // (3.20.1) the Portal not reached: answers this code (e.g. 503) without its own words
  final rids = <String>[]; // the save numbers that came
  final tankerCalls = <Map<String, dynamic>>[];
  static const _tTrips = [
    {'shift': 'Day', 'n': 1, 'c': '123', 'a': '07:35', 'b': '07:50', 'ch': '', 'u': '', 'old': 0},
    {'shift': 'Day', 'n': 2, 'c': '18522', 'a': '10:30', 'b': '10:36', 'ch': 'VTR', 'u': 'PQC curing', 'old': 0},
  ];
  Map<String, dynamic> get _tankerDay => {'machine': {'id': 'MH-04-J-9844', 'owner': 'Chalke Enterprises', 'type': 'Water Tanker'}, 'date': '2026-10-14', 'trips': _tTrips, 'problem': '', 'other': ''};
  Map<String, dynamic> prefs = {'shift': '', 'loc': '', 'lbMode': '', 'text': 'normal', 'mobile': '', 'photo': ''};
  // (3.15.0) the assistant: the AI service set up or not, what it was sent, its next steps (scripted), the daily summary
  bool aiOn = false;
  final aiAsked = <Map<String, dynamic>>[];
  final aiScript = <Map<String, dynamic>>[];
  /// (3.59.0, Mechanical update-185) the look-ups the server runs (aiLookup): what was asked, and what each answers
  final aiLookups = <Map<String, dynamic>>[];
  /// (3.59.0) Engineering at S1 for him; what reached it; its sign-ins; its sign-in ended once
  bool engSite = false, engEnded = false;
  /// (3.103.0) HR (rcl-hr) at S1 when [hrSite], as the module [hrKey] ('hr' – the HR office's; 'hrme' – "My HR"): what was sent;
  /// the punches it keeps; the photos sent to their place; [hrNet] false = the phone has no network for HR; which phone his
  /// attendance is tied to ('' = none yet); [hrMay] false = his employee record is incomplete
  bool hrSite = false, hrNet = true, hrMay = true;
  /// (rcl-hr step 8) the site's rule "once a day"; the time today was closed by itself ('' = it was not)
  bool hrOnce = false;
  /// (rcl-hr step 12) his payslips of locked months, as the HR server gives them
  List<Map<String, dynamic>> hrSlips = [];
  /// (rcl-hr step 9) the face is needed; is his face registered; does the photo of a punch match; what was asked of api/face;
  /// the punch numbers whose photo was found his
  bool hrFace = false, hrFaceIn = false, hrFaceOk = true;
  final hrFaceSent = <Map<String, dynamic>>[];
  final hrFaceSeen = <String>{};
  final hrFacePics = <String>[];
  String hrClosed = '';
  /// (3.114.0) his shift of today (the dial of the attendance app's Home) and what comes up for him (rcl-hr "coming"); null = not said
  Map<String, dynamic>? hrShift, hrComing;
  String hrKey = 'hr', hrBound = '';
  final hrSent = <Map<String, dynamic>>[];
  final hrPunches = <Map<String, dynamic>>[];
  final hrPhotos = <String, int>{};
  /// (rcl-hr step 5) the requests to set a day right (his own: 'mine'); how many people report to him
  final hrRegs = <Map<String, dynamic>>[];
  int hrTeam = 0;
  /// (rcl-hr step 7) leave: his balance, his requests ('mine') and his team's
  num hrLeaveBal = 3;
  /// (3.108.0) a person with HR only: the Portal lists no Mechanical for him – only "My HR" at S1; the papers he attached
  bool hrOnlyUser = false;
  final hrDocs = <Map<String, dynamic>>[];
  final hrDocFiles = <String, String>{};
  final hrLeaves = <Map<String, dynamic>>[];
  Map<String, dynamic> _hrLeave() {
    final mine = hrLeaves.where((q) => q['mine'] == true).toList();
    final num wait = mine.where((q) => q['status'] == 'pending').fold<num>(0, (a, q) => a + (q['days'] as num));
    return {'ok': true, 'today': '2026-10-14', 'employee': {'code': 'E00012', 'name': 'Sujit Mule'}, 'policy': {'valid_from': '2026-10-01', 'per_month': 4, 'carry': true, 'auto_absent': true, 'levels': 2},
      'balance': hrLeaveBal, 'booked': 0, 'pending': wait, 'available': hrLeaveBal - wait, 'month': {'credit': 4, 'added': 0, 'used': 1}, 'requests': mine};
  }
  List<Map<String, dynamic>> hrPlaces = [
    {'id': 'pl1', 'name': 'Site office', 'kind': 'site_office', 'shape': 'circle', 'lat': 18.52, 'lng': 73.8567, 'radius_m': 150, 'points': []}
  ];
  Map<String, dynamic> _hrDay(String device) => {
        'employee': {'code': 'E00012', 'name': 'Sujit Mule', 'category': 'staff'},
        'may': hrMay,
        'now': DateTime.utc(2026, 10, 14, 5).millisecondsSinceEpoch,
        'day': '2026-10-14',
        'places': hrPlaces,
        'max_accuracy': 100,
        'phone': hrBound.isEmpty ? 'none' : hrBound == device ? 'this' : 'other',
        'phone_model': hrBound.isEmpty ? '' : 'Old Phone',
        'punches': hrPunches,
        'next': hrClosed.isNotEmpty ? (hrOnce ? 'done' : 'in') : hrPunches.isNotEmpty && hrPunches.last['kind'] == 'in' ? 'out' : hrOnce && hrPunches.any((p) => p['kind'] == 'in') ? 'done' : 'in',
        'once': hrOnce,
        'face': hrFace,
        'closed': hrClosed,
        if (hrShift != null) 'shift': hrShift,
      };
  http.Response _hrAct(Map<String, dynamic> b) {
    switch ('${b['action']}') {
      case 'myAttend':
        return _j({'ok': true, ..._hrDay('${b['device_id']}')});
      case 'selfieUrl':
        return _j({'ok': true, 'there': hrPhotos.containsKey('${b['client_id']}'), 'url': hrPhotos.containsKey('${b['client_id']}') ? '' : 'https://photos.test/hr-selfies/${b['client_id']}.jpg', 'type': 'image/jpeg', 'max': 1048576});
      case 'punch':
        final cid = '${b['client_id']}', dev = '${(b['device'] as Map?)?['id'] ?? ''}';
        final had = hrPunches.where((p) => p['client_id'] == cid).toList();
        if (had.isNotEmpty) return _j({'ok': true, 'again': true, 'punch': had.first, 'punches': hrPunches, 'next': _hrDay(dev)['next']});
        if (hrFace && !hrFaceSeen.contains(cid)) return _j({'error': 'Not marked: your face was not checked for this punch. Update the app (the face check is needed on your site) and mark again.', 'code': 'face'}, 403);
        if (b['dev_options'] == true) return _j({'error': 'Developer Options are ON in this phone: switch them off (Settings → Developer options) to mark attendance.', 'code': 'devoptions'}, 403);
        if (hrBound.isNotEmpty && hrBound != dev) return _j({'error': 'Your attendance is tied to another phone. Only the HR Admin can release it – then this phone will work.', 'code': 'device'}, 403);
        if (!hrPhotos.containsKey(cid)) return _j({'error': 'The photo of this punch did not arrive – take it again.', 'code': 'selfie'}, 400);
        final off = b['offline'] == true, last = hrPunches.isEmpty ? null : hrPunches.last;
        if (!off && b['kind'] == 'in' && hrOnce && hrPunches.any((p) => p['kind'] == 'in')) return _j({'error': 'Today\'s attendance is done – one IN and one OUT a day. A mistake: ask to set the day right.', 'code': 'done'}, 409);
        if (!off && b['kind'] == 'in' && last != null && last['kind'] == 'in') return _j({'error': 'You are already IN since ${last['time']}.', 'code': 'already'}, 409);
        if (!off && b['kind'] == 'out' && (last == null || last['kind'] == 'out')) return _j({'error': 'Mark IN first.', 'code': 'already'}, 409);
        hrBound = dev;
        final doubt = off && (b['elapsed'] == null || b['anchor_elapsed'] == null);
        final p = {'id': 'pn${hrPunches.length + 1}', 'client_id': cid, 'kind': b['kind'], 'at': off ? '${b['at_device']}' : '2026-10-14T05:00:00.000Z', 'time': off ? '09:40' : '10:30', 'place_id': 'pl1', 'offline': off, 'status': doubt ? 'review' : 'ok'};
        hrPunches.add(p);
        return _j({'ok': true, 'again': false, 'punch': p, 'place': 'Site office', 'punches': hrPunches, 'next': b['kind'] == 'in' ? 'out' : 'in'});
      case 'myMonth':
        // (rcl-hr step 5) every day with what it counts as, the month's count, how far back a request reaches
        final oct = '${b['month']}' == '2026-10';
        final all = !oct ? <Map<String, dynamic>>[] : [
          {'day': '2026-10-12', 'code': 'A', 'in': '', 'out': '', 'late_min': 0, 'punches': 0, 'review': 0},
          {'day': '2026-10-13', 'code': 'P', 'in': '09:12', 'out': '18:11', 'late_min': 12, 'punches': 2, 'review': 0},
          if (hrPunches.isNotEmpty) {'day': '2026-10-14', 'code': hrPunches.last['kind'] == 'in' ? 'IN' : 'A', 'in': hrPunches.first['time'], 'out': hrPunches.length > 1 ? hrPunches.last['time'] : '', 'late_min': 0, 'punches': hrPunches.length, 'review': 0},
          {'day': '2026-10-15', 'code': '', 'in': '', 'out': '', 'late_min': 0, 'punches': 0, 'review': 0},
        ];
        return _j({'ok': true, 'month': '${b['month']}', 'today': '2026-10-14', 'all': all, 'days': all.where((d) => (d['punches'] as int) > 0).toList(), 'total': {'P': oct ? 1 : 0, 'HD': 0, 'A': oct ? 1 : 0, 'WO': 0, 'H': 0, 'MIS': 0, 'late': oct ? 1 : 0, 'paid': oct ? 1 : 0}, 'reg_days': 60});
      case 'regAsk':
        if ('${b['reason']}'.length < 5) return _j({'error': 'Reason: write what happened (at least 5 letters).', 'code': 'reason'}, 400);
        if ('${b['in_time']}'.isEmpty && '${b['out_time']}'.isEmpty) return _j({'error': 'Give the IN time, the OUT time, or both.', 'code': 'time'}, 400);
        if (hrRegs.any((q) => q['day'] == b['day'] && q['status'] == 'pending' && q['mine'] == true)) return _j({'error': 'A request for this day is already waiting.', 'code': 'duplicate'}, 409);
        hrRegs.insert(0, {'id': hrRegs.length + 1, 'mine': true, 'code': 'E00012', 'name': 'Sujit Mule', 'day': b['day'], 'in_time': b['in_time'], 'out_time': b['out_time'], 'out_next_day': b['out_next_day'] == true, 'reason': b['reason'], 'status': 'pending', 'level': 2, 'steps': []});
        return _j({'ok': true, 'rows': hrRegs.where((q) => q['mine'] == true).toList()});
      case 'myRegs':
        return _j({'ok': true, 'rows': hrRegs.where((q) => q['mine'] == true).toList()});
      case 'teamRegs':
        return _j({'ok': true, 'team': hrTeam, 'rows': hrRegs.where((q) => q['mine'] != true && q['status'] == 'pending' && q['level'] == 1).toList()});
      case 'teamRegDecide':
        final q = hrRegs.firstWhere((x) => x['id'] == b['id'] && x['mine'] != true, orElse: () => <String, dynamic>{});
        if (q.isEmpty || q['status'] != 'pending' || q['level'] != 1) return _j({'error': 'This request does not wait for you any more.', 'code': 'decided'}, 409);
        if (b['decision'] == 'refused' && '${b['note']}'.length < 3) return _j({'error': 'Reason: write why it is refused.', 'code': 'note'}, 400);
        (q['steps'] as List).add({'level': 1, 'by': 'sujit@rcl.test', 'decision': b['decision'], 'note': b['note']});
        if (b['decision'] == 'approved') {
          q['level'] = 2;
        } else {
          q['status'] = 'refused';
        }
        return _j({'ok': true, 'team': hrTeam, 'rows': hrRegs.where((x) => x['mine'] != true && x['status'] == 'pending' && x['level'] == 1).toList()});
    }
    const kinds = [
      {'key': 'photo', 'name': 'Photo', 'pay': false, 'expires': false},
      {'key': 'aadhaar', 'name': 'Aadhaar card', 'pay': false, 'expires': false},
      {'key': 'pan', 'name': 'PAN card', 'pay': false, 'expires': false},
      {'key': 'bank_passbook', 'name': 'Bank passbook / cancelled cheque', 'pay': true, 'expires': false},
    ];
    List<String> docsMissing() => [for (final k in kinds) if (!hrDocs.any((d) => d['kind'] == k['key'])) '${k['name']}'];
    switch ('${b['action']}') {
      case 'myHr':
        return _j({'ok': true, if (hrComing != null) 'coming': hrComing, 'employee': {'code': 'E00012', 'name': 'Sujit Mule', 'category': 'staff', 'department': 'Projects', 'designation': 'Site Engineer'}, 'complete': {'pct': 64, 'missing': ['Blood group']},
          'details': [
            {'name': 'Employee', 'rows': [{'label': 'Code', 'value': 'E00012'}, {'label': 'Designation', 'value': 'Site Engineer'}, {'label': 'Date of birth', 'value': '01-01-1991'}]},
            {'name': 'Statutory & bank', 'rows': [{'label': 'Bank IFSC code', 'value': 'SBIN0001234'}, {'label': 'Bank account number', 'value': 'XXXX9012'}]},
          ],
          'photo': hrDocs.any((d) => d['kind'] == 'photo') ? 'https://photos.test/hr-docs/open' : '',
          'docs': {'have': hrDocs.length, 'missing': docsMissing()}, 'phone': {'bound': hrBound.isNotEmpty, 'model': hrBound.isEmpty ? '' : 'Test Phone'}});
      case 'mySlips':
        return _j({'ok': true, 'employee': {'code': 'RCL012', 'name': 'Sujit Mule'}, 'slips': hrSlips});
      case 'myDocs':
        return _j({'ok': true, 'kinds': kinds, 'docs': hrDocs, 'docsMissing': docsMissing(), 'maxMb': 10});
      case 'myDocUploadUrl':
        if (!kinds.any((k) => k['key'] == b['kind'])) return _j({'error': 'Choose what kind of paper this is.', 'code': 'kind'}, 400);
        final ext = const {'image/jpeg': 'jpg', 'image/png': 'png', 'image/webp': 'webp', 'application/pdf': 'pdf'}['${b['type']}'];
        if (ext == null) return _j({'error': 'Only a photo (JPG, PNG, WebP) or a PDF can be attached.', 'code': 'type'}, 400);
        final path = 'emp12/f${hrDocFiles.length + 1}.$ext';
        return _j({'ok': true, 'path': path, 'url': 'https://photos.test/hr-docs/$path', 'type': b['type']});
      case 'myDocAdd':
        if (!hrDocFiles.containsKey('${b['path']}')) return _j({'error': 'The file did not arrive – attach it again.', 'code': 'path'}, 400);
        hrDocs.insert(0, {'id': 'doc${hrDocs.length + 1}', 'kind': b['kind'], 'title': '', 'number': '', 'expires_on': null, 'mime': hrDocFiles['${b['path']}'], 'created_at': '2026-10-14T05:00:00.000Z'});
        return _j({'ok': true, 'id': hrDocs.first['id']});
      case 'myDocLink':
        return _j({'ok': true, 'url': 'https://photos.test/hr-docs/open'});
      case 'myLeave':
        return _j(_hrLeave());
      case 'leaveAsk':
        if ('${b['reason']}'.length < 3) return _j({'error': 'Reason: write why (at least 3 letters).', 'code': 'reason'}, 400);
        final from = DateTime.parse('${b['from']}'), to = DateTime.parse('${b['to']}');
        final num days = b['part'] == 'full' ? to.difference(from).inDays + 1 : 0.5;
        hrLeaves.insert(0, {'id': hrLeaves.length + 1, 'mine': true, 'code': 'E00012', 'name': 'Sujit Mule', 'from': b['from'], 'to': b['to'], 'part': b['part'], 'days': days, 'reason': b['reason'], 'status': 'pending', 'level': 2, 'steps': [], 'note': ''});
        return _j(_hrLeave());
      case 'leaveCancel':
        final q = hrLeaves.firstWhere((x) => x['id'] == b['id'] && x['mine'] == true && x['status'] == 'pending', orElse: () => <String, dynamic>{});
        if (q.isEmpty) return _j({'error': 'Only a request that still waits can be taken back.', 'code': 'decided'}, 409);
        q['status'] = 'cancelled';
        return _j(_hrLeave());
      case 'teamLeaves':
        return _j({'ok': true, 'team': hrTeam, 'rows': hrLeaves.where((q) => q['mine'] != true && q['status'] == 'pending' && q['level'] == 1).toList()});
      case 'teamLeaveDecide':
        final q = hrLeaves.firstWhere((x) => x['id'] == b['id'] && x['mine'] != true, orElse: () => <String, dynamic>{});
        if (q.isEmpty || q['status'] != 'pending' || q['level'] != 1) return _j({'error': 'This request does not wait for you any more.', 'code': 'decided'}, 409);
        if (b['decision'] == 'approved') {
          q['level'] = 2;
        } else {
          q['status'] = 'refused';
        }
        return _j({'ok': true, 'team': hrTeam, 'rows': hrLeaves.where((x) => x['mine'] != true && x['status'] == 'pending' && x['level'] == 1).toList()});
    }
    return _j({'error': 'This is for the HR office only.', 'code': 'role'}, 403);
  }

  // (3.72.0) Purchase (rcl-purchase) at S1 when [purSite]: its sign-in (a Portal ticket); what was sent; his role there
  bool purSite = false;
  String purRole = 'admin';
  final purSent = <Map<String, dynamic>>[];
  /// (3.94.0, Purchase Phase 1) what Purchase's server keeps: suppliers, enquiries, quotations, comparative statements, the CS limit
  num? purLimit = 200000;
  /// (3.95.0, Purchase Phase 2) the POs made here (the master – D-2); the site's copy is "at the site" as its PO 21 at once
  final purPos = <Map<String, dynamic>>[];
  /// (3.95.0) the Store's list holds a PO of the Purchase Department (read-only at the site)
  bool storePurPo = false;
  /// (3.95.0, Engineering 2B) the Measurement Book's pages
  final engMb = <Map<String, dynamic>>[
    {'no': 'MB-0001', 'work': 'W-001', 'layer': 'L2', 'from_day': '2026-10-10', 'to_day': '2026-10-12', 'mb_day': '2026-10-13', 'status': 'Measured', 'note': '', 'ver': 1,
      'measured_by': 'eng1@rcl.test', 'measured_name': 'Engineer One', 'measured_at': '2026-10-13T10:00:00Z', 'checked_name': '', 'chk_day': null, 'back_name': '', 'back_why': '',
      'lines': [{'ln': 1, 'key': 'a1', 'src': 'r0', 'day': '2026-10-12', 'email': 'eng1@rcl.test', 'name': 'Engineer One', 'line': 1, 'outside': false, 'side': 'LHS', 'from': 40000, 'to': 40400, 'len': 400, 'w_m': 7.5, 'mm_m': 250, 'w': 7.5, 'mm': 250, 'qty': 750, 'unit': 'cum', 'how': 'LxWxT', 'appr': 'yes', 'rfi': ['RFI-0001'], 'remark': '', 'skip': ''}],
      'history': <Map<String, dynamic>>[{'at': '2026-10-13T10:00:00Z', 'by': 'eng1@rcl.test', 'name': 'Engineer One', 'what': 'Measured'}]},
  ];
  final purVendors = <Map<String, dynamic>>[
    {'id': 1, 'name': 'Asha Traders', 'gstin': '27ABCDE1234F1Z5', 'pan': 'ABCDE1234F', 'address': 'Nashik', 'phone': '9876543210', 'email': 'sales@asha.test', 'supplies': ['Cement', 'Steel'], 'status': 'Approved', 'status_note': '', 'ver': 1, 'wa': '919876543210'},
    {'id': 2, 'name': 'Bharat Steel', 'gstin': '', 'pan': '', 'address': '', 'phone': '9822012345', 'email': '', 'supplies': ['Steel'], 'status': 'Approved', 'status_note': '', 'ver': 1, 'wa': '919822012345'},
    {'id': 3, 'name': 'Chetan Hardware', 'gstin': '', 'pan': '', 'address': 'Pune', 'phone': '9011122233', 'email': '', 'supplies': <String>[], 'status': 'Blocked', 'status_note': 'Late deliveries', 'ver': 2, 'wa': '919011122233'},
  ];
  final purRfqs = <Map<String, dynamic>>[
    {'no': 1, 'site': 'S1', 'date': '2026-10-11', 'need_by': '2026-10-20', 'remark': '', 'status': 'Quotes in', 'status_note': '', 'sent_at': '2026-10-11T06:00:00Z', 'created_name': 'Purchase One', 'ver': 3,
      'lines': [
        {'line': 1, 'site': 'S1', 'req_no': 7, 'req_line': 1, 'ref': 'IND-0007', 'code': 'ITM-0001', 'name': 'Cement OPC 53', 'unit': 'Bag', 'qty': 50, 'brand': 'UltraTech', 'spec': ''},
        {'line': 2, 'site': 'S1', 'req_no': 7, 'req_line': 3, 'ref': 'IND-0007', 'code': 'ITM-0004', 'name': 'TMT bar 12 mm', 'unit': 'MT', 'qty': 2, 'brand': '', 'spec': 'Fe 500D'},
      ],
      'vendors': [{'id': 1, 'name': 'Asha Traders'}, {'id': 2, 'name': 'Bharat Steel'}]},
  ];
  final purQuotes = <String, Map<String, dynamic>>{
    '1:1': {'lines': [{'line': 1, 'rate': 380, 'disc': 0, 'gst': 28, 'days': 3}, {'line': 2, 'rate': 56000, 'disc': 0, 'gst': 18, 'days': 7}], 'freight': 500, 'loading': 0, 'pay_terms': '30 days', 'valid_till': '2026-10-30', 'remark': '', 'history': [], 'locked': true, 'ver': 1, 'at': '2026-10-12T05:00:00Z', 'by': 'Purchase One'},
    '1:2': {'lines': [{'line': 1, 'rate': 385, 'disc': 0, 'gst': 28, 'days': 5}, {'line': 2, 'rate': 55000, 'disc': 0, 'gst': 18, 'days': 4}], 'freight': 1000, 'loading': 0, 'pay_terms': 'Advance', 'valid_till': '2026-10-25', 'remark': '', 'history': [], 'locked': true, 'ver': 1, 'at': '2026-10-12T05:30:00Z', 'by': 'Purchase One'},
  };
  final purCs = <int, Map<String, dynamic>>{
    1: {'no': 1, 'rfq_no': 1, 'site': 'S1', 'status': 'Sent', 'need': 'admin', 'cs_limit': 200000, 'version': 2, 'few_reason': '', 'created_by': 'p1@rcl.test', 'created_name': 'Purchase One', 'sent_name': 'Purchase One', 'sent_at': '2026-10-13T06:00:00Z',
      'award': {'1': {'vendor': 1, 'reason': ''}, '2': {'vendor': 2, 'reason': ''}}, 'total': 130500, 'gst': 25300, 'trail': <Map<String, dynamic>>[{'at': '2026-10-13T06:00:00Z', 'by': 'p1@rcl.test', 'name': 'Purchase One', 'act': 'Sent', 'why': '', 'total': 130500}],
      'sheet': {'at': '2026-10-13T05:55:00Z', 'lines': [
        {'line': 1, 'site': 'S1', 'ref': 'IND-0007', 'code': 'ITM-0001', 'name': 'Cement OPC 53', 'unit': 'Bag', 'qty': 50, 'n': 2, 'l1': [1], 'l1_rate': 390,
          'q': {'1': {'rate': 380, 'disc': 0, 'net': 380, 'landed': 390, 'value': 19500, 'gst': 28, 'gst_amt': 5320, 'days': 3}, '2': {'rate': 385, 'disc': 0, 'net': 385, 'landed': 400, 'value': 20000, 'gst': 28, 'gst_amt': 5390, 'days': 5}}},
        {'line': 2, 'site': 'S1', 'ref': 'IND-0007', 'code': 'ITM-0004', 'name': 'TMT bar 12 mm', 'unit': 'MT', 'qty': 2, 'n': 2, 'l1': [2], 'l1_rate': 55500,
          'q': {'1': {'rate': 56000, 'disc': 0, 'net': 56000, 'landed': 56000, 'value': 112000, 'gst': 18, 'gst_amt': 20160, 'days': 7}, '2': {'rate': 55000, 'disc': 0, 'net': 55000, 'landed': 55500, 'value': 111000, 'gst': 18, 'gst_amt': 19800, 'days': 4}}},
      ], 'vendors': [
        {'id': 1, 'name': 'Asha Traders', 'freight': 500, 'loading': 0, 'extra': 500, 'base': 19000, 'pay_terms': '30 days', 'valid_till': '2026-10-30', 'remark': '', 'quoted': 2, 'total': 131500, 'gst': 25480, 'l1': 1},
        {'id': 2, 'name': 'Bharat Steel', 'freight': 1000, 'loading': 0, 'extra': 1000, 'base': 110000, 'pay_terms': 'Advance', 'valid_till': '2026-10-25', 'remark': '', 'quoted': 2, 'total': 131000, 'gst': 25190, 'l1': 1},
      ]}},
  };
  final engSent = <Map<String, dynamic>>[];
  /// (3.93.0, Engineering 2A) Engineering's RFIs and hindrances (what its server keeps); his role there
  String engRole = 'admin';
  final engRfi = <Map<String, dynamic>>[
    {'no': 'RFI-0002', 'day': '2026-10-12', 'work': 'W-001', 'layer': 'L2', 'side': 'LHS', 'ch_from': 40000, 'ch_to': 40400, 'qty': 400, 'note': 'ready', 'status': 'Pending', 'asked_by': 'eng1@rcl.test', 'asked_name': 'Engineer One', 'ver': 1},
    {'no': 'RFI-0001', 'day': '2026-10-10', 'work': 'W-001', 'layer': 'L1', 'side': 'Both', 'ch_from': 39000, 'ch_to': 40000, 'qty': 1000, 'note': '', 'status': 'Approved', 'ie_day': '2026-10-11', 'ie_name': 'Mr IE', 'ie_ref': 'RFI/18B/42', 'ie_remark': '', 'asked_by': 'sujit@rcl.test', 'asked_name': 'Sujit Mule', 'ver': 2},
  ];
  final engHind = <Map<String, dynamic>>[
    {'no': 'H-0001', 'from_day': '2026-10-04', 'to_day': null, 'ch_from': 55000, 'ch_to': 56000, 'side': 'LHS', 'works': ['W-002'], 'kind': 'Land not handed over', 'detail': 'private land, court case', 'letter': 'NHAI/18B/311', 'status': 'Open', 'created_by': 'eng1@rcl.test', 'days': 11, 'ver': 1},
  ];
  int engSessions = 0;
  /// (3.61.0, Mechanical update-186) the answer word by word (/api/ai): on or not (off – a server without it: 404); what it was sent;
  /// how a step ends ('end' – its parts from [aiScript]; 'busy' – cut after some words: an err line with cut; 'busy0' / 'credit' – the
  /// service's own answer before any word: an err line without cut; 'cut' – the line lost after some words)
  bool aiStream = false;
  final aiStreamed = <Map<String, dynamic>>[];
  final aiStreamHow = <String>[];
  /// (3.61.0) his chats and the assistant's memory of him (the site's step 1zk: [aiStep])
  bool aiStep = true;
  final aiChats = <String, Map<String, dynamic>>{};
  int aiSaves = 0;
  final aiMemory = <Map<String, dynamic>>[];
  Map<String, Object> aiLookupAnswers = {
    'maintenance_bills': {'from': '2026-10-01', 'to': '2026-10-14', 'bills': [{'id': 'MT-000001', 'date': '2026-10-05', 'no': 'MH-12-HO-1163', 'garage': 'Toyota Service', 'total': 2360}], 'count': 1, 'totalRupees': 2360, 'page': 'mnt'},
  };
  Map<String, dynamic> brief = {
    'name': 'Sujit Mule', 'day': '2026-10-13',
    'sections': {
      'diesel': {'entries': 4, 'litres': 240, 'top': [{'name': 'Kobelco Sk 220', 'litres': 80}, {'name': 'MH-25-AJ-2169', 'litres': 80}, {'name': 'Sany 210 (No.1)', 'litres': 60}]},
      'stock': {'litres': 1133, 'byLoc': {'Dispenser': 813, 'VTR Store': 320}},
      'logbook': {'entries': 6, 'pending': 1, 'names': ['MH-25-AJ-2169']},
      'papers': {'expired': 1, 'due': 1, 'soonDays': 30, 'first': ['MH-25-AJ-2169 PUC']},
    },
  };
  String start = '';

  static final issues = [
    {'id': 'DI-000525', 'date': '2026-10-14', 'shift': 'Day', 'no': 'Sany 210 (No.1)', 'type': 'Excavator', 'qty': 60, 'source': 'VTR Store', 'driver': 'Gupta', 'ph': 4},
    {'id': 'DI-000522', 'date': '2026-10-14', 'shift': 'Day', 'no': 'MH-12-SY-6216', 'type': 'Bolero', 'qty': 20, 'source': 'Dispenser', 'driver': 'Maruti'},
    {'id': 'DI-000521', 'date': '2026-10-14', 'shift': 'Day', 'no': 'Kobelco Sk 220', 'type': 'Excavator', 'qty': 80, 'source': 'Dispenser', 'driver': 'Babu Bag'},
    {'id': 'DI-000520', 'date': '2026-10-14', 'shift': 'Night', 'no': 'MH-25-AJ-2169', 'type': 'Tipper', 'qty': 80, 'source': 'Dispenser', 'driver': 'Rupesh', 'ver': 'v520'},
  ];

  // (3.4.0) Asset Master and the other masters: the machinery (changed by the saves), the vendors, the BOQs, the papers
  final masterCalls = <Map<String, dynamic>>[];
  final master = <Map<String, dynamic>>[
    {'id': 'Sany 210 (No.1)', 'name': 'Sany 210', 'type': 'Excavator', 'make': 'Sany', 'owner': 'RCL', 'ownership': 'Own', 'supply': 'Company', 'status': 'Active', 'modes': ['Hrs', 'Time'], 'modesX': ['Time'], 'meterKm': false, 'meterHr': true,
      'worksOn': ['Hrs'], 'unit': 'Hrs', 'hrStd': 14, 'kmStd': '', 'tankCap': 400, 'activeFrom': '2026-09-01', 'inactiveFrom': '', 'earlier': [], 'insuranceUpto': '2027-03-31', 'enteredBy': 'Tester'},
    {'id': 'MH-25-AJ-2169', 'no': 'MH-25-AJ-2169', 'name': '', 'type': 'Tipper', 'make': 'Tata', 'owner': 'I E Enterprises', 'ownership': 'Rental', 'supply': 'Company', 'status': 'Active', 'modes': ['KM'], 'modesX': [], 'meterKm': true, 'meterHr': false,
      'worksOn': ['KM'], 'unit': 'KM', 'kmStd': 3.5, 'hrStd': '', 'tankCap': 300, 'activeFrom': '', 'inactiveFrom': '', 'earlier': [{'from': '2026-06-01', 'until': '2026-08-01'}],
      'taxUpto': 'LIFETIME', 'pucUpto': '2026-09-30', 'insuranceUpto': '2026-10-20', 'engineNo': 'E123', 'chassisNo': 'C456', 'enteredBy': 'Tester', 'updatedBy': 'Checker'},
    {'id': 'OLD-9', 'no': 'OLD-9', 'name': '', 'type': 'Roller', 'owner': '', 'ownership': 'Own', 'status': 'Inactive', 'inactiveFrom': '2026-10-01', 'modes': ['Hrs'], 'worksOn': ['Hrs'], 'unit': 'Hrs', 'hrStd': 8},
  ];
  List<Map<String, dynamic>> get _master => [
        ...master,
        if (fuels || card) ...[
          {'id': 'MH-12-HO-1163', 'no': 'MH-12-HO-1163', 'name': 'Hycross', 'type': 'Car', 'owner': 'RCL', 'ownership': 'Own', 'supply': 'Company', 'status': 'Active', 'modes': ['KM'], 'worksOn': ['KM'], 'unit': 'KM', 'kmStd': 23, 'fuel': 'Petrol'},
          {'id': 'MH-12-HO-2163', 'no': 'MH-12-HO-2163', 'name': 'Ertiga', 'type': 'Car', 'owner': 'RCL', 'ownership': 'Own', 'supply': 'Company', 'status': 'Active', 'modes': ['KM'], 'worksOn': ['KM'], 'unit': 'KM', 'kmStd': 25, 'fuel': 'CNG'},
          {'id': 'MH-12-HO-3163', 'no': 'MH-12-HO-3163', 'name': 'Nexon EV', 'type': 'Car', 'owner': 'RCL', 'ownership': 'Own', 'supply': 'Company', 'status': 'Active', 'modes': ['KM'], 'worksOn': ['KM'], 'unit': 'KM', 'kmStd': '', 'fuel': 'Electric'},
        ],
        if (tanker) {'id': 'MH-04-J-9844', 'name': '', 'type': 'Water Tanker', 'owner': 'Chalke Enterprises', 'ownership': 'Rental', 'supply': 'Company', 'status': 'Active', 'modes': ['Trip'], 'modesX': [], 'lbFormat': 'I'},
        if (tanker2) {'id': 'MH-12-AB-1001', 'name': '', 'type': 'Water Tanker', 'owner': 'Patil Water Supply', 'ownership': 'Rental', 'supply': 'Company', 'status': 'Active', 'modes': ['Trip'], 'modesX': [], 'lbFormat': 'I'},
      ];
  final vendors = <Map<String, dynamic>>[
    {'name': 'I E Enterprises', 'saved': true, 'complete': false, 'gstReg': 'No', 'pan': 'ABCDE1234F', 'bank': 'State Bank of India', 'account': '000000004321', 'ifsc': 'SBIN0001234', 'phone': '9000000000', 'boqs': 1,
      'ownership': 'Rental', 'machines': [{'id': 'MH-25-AJ-2169', 'type': 'Tipper', 'ownership': 'Rental', 'status': 'Active'}]},
    {'name': 'RCL', 'saved': false, 'complete': true, 'gstReg': 'No', 'boqs': 0, 'ownership': 'Own', 'machines': [{'id': 'Sany 210 (No.1)', 'type': 'Excavator', 'ownership': 'Own', 'status': 'Active'}]},
    {'name': 'Chalke Enterprises', 'saved': true, 'complete': true, 'gstReg': 'Yes', 'gst': '27AAAAA0000A1Z5', 'gstPct': 18, 'pan': 'AAAAA0000A', 'bank': 'Bank of Maharashtra', 'account': '000000009999', 'ifsc': 'MAHB0000123', 'boqs': 0, 'ownership': 'Rental', 'machines': [{'id': 'MH-04-J-9844', 'type': 'Water Tanker', 'ownership': 'Rental', 'status': 'Active'}]},
  ];
  final boqs = <Map<String, dynamic>>[
    {'id': 'BOQ-0001', 'no': '1', 'vendor': 'I E Enterprises', 'from': '2026-09-01', 'to': '', 'amendOf': '', 'amendNo': 0, 'gstPct': '', 'tdsPct': 2, 'woNo': 'WO-12', 'woDate': '', 'remark': '', 'enteredBy': 'Tester',
      'lines': [{'no': 'MH-25-AJ-2169', 'type': 'Tipper', 'basis': 'Monthly', 'rate': 45000, 'slabs': [], 'slabOn': '', 'diesel': 'Company', 'remark': ''}]},
  ];
  Map<String, String> lbNames = {};
  final dashAsked = <Map<String, dynamic>>[]; // (3.5.0)
  final tankChecks = <Map<String, dynamic>>[
    {'id': 'TC-0001', 'date': '2026-10-10', 'no': 'Sany 210 (No.1)', 'system': 200, 'physical': 150, 'diff': -50, 'pct': -25, 'method': 'Measured', 'toFill': '', 'reason': 'Leak at the hose', 'by': 'Tester', 'enteredBy': 'Tester'},
  ];
  // (3.6.0) Edit Log Book: a KM machinery's entries (MH-25-AJ-2169), and a water tanker's trips; what was sent
  final logBulk = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> get _editRows => [
        for (final x in const [('2026-10-12', 15000, 15040), ('2026-10-13', 15040, 15100), ('2026-10-14', 15100, 15230)])
          {'key': 'MH-25-AJ-2169|${x.$1}|Full Day', 'date': x.$1, 'shift': 'Full Day', 'no': 'MH-25-AJ-2169', 'type': 'Tipper', 'owner': 'I E Enterprises', 'unit': 'KM', 'mode': 'KM',
            'okm': x.$2, 'ckm': x.$3, 'wkm': x.$3 - x.$2, 'ohr': '', 'chr': '', 'whr': '', 'tStart': '', 'tEnd': '', 'tBrk': '', 'tSlots': '', 'trip': '', 'challan': '', 'remark': '',
            'chFrom': '12+000', 'chTo': '12+800', 'work': 'Earth carting', 'odsl': '', 'odSet': '', 'itemWork': {}, 'half': false, 'meter': '', 'debitTo': '', 'debitRate': '', 'itemQty': [], 'boqItems': []},
      ];
  Map<String, dynamic> _editData(String from, String to) => {
        'machine': master[1], 'from': from, 'to': to, 'boqItems': {},
        'rows': _editRows.where((r) => '${r['date']}'.compareTo(from) >= 0 && '${r['date']}'.compareTo(to) <= 0).toList(),
        'prev': {'key': 'MH-25-AJ-2169|2026-10-11|Full Day', 'date': '2026-10-11', 'shift': 'Full Day', 'okm': 14950, 'ckm': 15000, 'ohr': '', 'chr': '', 'stock': 120},
        'next': null, 'diesel': {'2026-10-14': {'Day': 0, 'Night': 80}}, 'prevKm': 15000, 'prevHr': '', 'locks': [], 'nextHr': null, 'hrsOnly': false,
      };
  Map<String, dynamic> _tankerRange(String from, String to, List trips) => {
        'machine': {'id': 'MH-04-J-9844', 'owner': 'Chalke Enterprises', 'type': 'Water Tanker'}, 'from': from, 'to': to,
        'trips': [for (final t in trips) {'date': t['date'] ?? '2026-10-14', 'shift': t['shift'], 'c': t['c'], 'a': t['a'], 'b': t['b'], 'ch': t['ch'], 'u': t['u'], 'old': 0}],
        'days': [], 'locks': [],
      };
  // (3.7.0) Breakdown: a breakdown carried from the last saved day, the history of breakdown runs; what was sent
  bool bdRich = false;
  final bdSent = <Map<String, dynamic>>[];
  List<Map<String, dynamic>>? bdSaved; // the status saved for 14-10-2026
  Map<String, dynamic> _bd(String date) => {
        'today': '2026-10-14', 'date': date.isEmpty ? '2026-10-14' : date,
        'report': bdSaved == null ? null : {'date': '2026-10-14', 'at': '14-10-2026 18:05', 'by': 'Tester', 'rows': bdSaved, 'count': bdSaved!.where((r) => r['status'] == 'Breakdown').length},
        'carried': bdSaved == null ? '2026-10-13' : '',
        'status': bdSaved == null
            ? {'MH25AJ2169': {'status': 'Breakdown', 'reason': 'Tyre puncture', 'remark': '', 'carried': true}}
            : {for (final r in bdSaved!) '${r['no']}'.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), ''): {'status': r['status'], 'reason': r['reason'], 'remark': r['remark']}},
        'onDate': [{'no': 'MH-25-AJ-2169', 'from': '2026-10-10', 'days': 5, 'reason': 'Tyre puncture', 'remark': '', 'id': 'MH-25-AJ-2169', 'type': 'Tipper', 'owner': 'I E Enterprises', 'ownership': 'Rental'}],
        'history': [
          {'no': 'MH-25-AJ-2169', 'from': '2026-10-10', 'backOn': '', 'reason': 'Tyre puncture', 'remark': '', 'days': 5, 'type': 'Tipper', 'owner': 'I E Enterprises', 'ownership': 'Rental', 'id': 'MH-25-AJ-2169|2026-10-10'},
          {'no': 'Sany 210 (No.1)', 'from': '2026-10-02', 'backOn': '2026-10-05', 'reason': 'Hydraulic problem', 'remark': '', 'days': 3, 'type': 'Excavator', 'owner': 'RCL', 'ownership': 'Own', 'id': 'Sany 210 (No.1)|2026-10-02'},
        ],
        'reports': [
          if (bdSaved != null) {'date': '2026-10-14', 'at': '14-10-2026 18:05', 'by': 'Tester', 'total': bdSaved!.length, 'count': bdSaved!.where((r) => r['status'] == 'Breakdown').length},
          {'date': '2026-10-13', 'at': '13-10-2026 18:00', 'by': 'Tester', 'total': 2, 'count': 1},
        ],
      };
  // (3.8.0) Billing: the vendors to bill, September's Log Book / diesel / BOQ of MH-25-AJ-2169 (a Monthly BOQ, an Idle day,
  // diesel above the standard), the saved bills, notes, payments, ledger; what was sent
  bool billing = false;
  // (3.72.2, Mechanical update-199) the dates under the month-end tank check rule: "checks" with the period's data; the check saved
  bool tankRule = false;
  Map<String, dynamic>? tankClose;
  static Object? _arg(List a, String k) => a.isNotEmpty && a[0] is Map ? (a[0] as Map)[k] : null;
  // (3.11.0) the imports and the multiple entries of the diesel pages: what was sent, the lists' filters asked
  final importSent = <Map<String, dynamic>>[];
  // (3.14.0) the other calls of part 13 (diesel history, photos, transfer stock, faults, backup) and the site's notice
  final extraCalls = <Map<String, dynamic>>[];
  String notice = '';
  final faults = <Map<String, dynamic>>[
    {'at': '2026-10-14T05:00:00Z', 'by': 'clerk@rcl.test', 'kind': 'server', 'where': 'getStock', 'msg': 'x is undefined', 'detail': 'TypeError: x is undefined'},
  ];
  final listAsked = <Map<String, dynamic>>[];
  final billSent = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> get _billRows => [
        for (var d = 1; d <= 6; d++)
          {'no': 'MH-25-AJ-2169', 'date': '2026-09-0$d', 'shift': 'Full Day', 'mode': d == 6 ? 'Idle' : 'KM', 'unit': 'KM', 'okm': d == 6 ? '' : 900 + 100 * d, 'ckm': d == 6 ? '' : 1000 + 100 * d, 'wkm': d == 6 ? '' : 100,
            'whr': '', 'trip': '', 'half': false, 'owner': 'I E Enterprises', 'type': 'Tipper', 'key': 'MH-25-AJ-2169|2026-09-0$d|Full Day', 'work': 'Earth carting', 'itemQty': []},
      ];
  Map<String, dynamic> get _billExtra => {
        'debit': {},
        'boq': {
          'MH25AJ2169': {
            for (var d = 1; d <= 30; d++)
              '2026-09-${d.toString().padLeft(2, '0')}': {'boq': '1', 'amendNo': 0, 'basis': 'Monthly', 'rate': 45000, 'nightRate': '', 'slabs': [], 'slabOn': '', 'items': [], 'diesel': 'Company', 'gstPct': '', 'tdsPct': 2, 'woNo': 'WO-12', 'woDate': ''}
          }
        },
        'issues': {
          'MH25AJ2169': {
            '2026-09-01': {'qty': 120, 'km': 1000, 'hr': '', 'lastQty': 120, 'lastKm': 1000, 'lastHr': ''},
            '2026-09-03': {'qty': 60, 'km': 1200, 'hr': '', 'lastQty': 60, 'lastKm': 1200, 'lastHr': ''},
          }
        },
        'avgRate': 92.5, 'lastRate': 93.1,
      };
  Map<String, dynamic> get _billInit => {
        'vendors': [
          {...vendors[0]},
          {...vendors[2]},
        ],
        'lastNo': {'I E ENTERPRISES|Sketchline Industries': 7},
        'settings': {
          'project': 'Test Project', 'siteAddress': 'SITE OFFICE, TEST VILLAGE',
          'companies': {
            'Sketchline Industries': {'address': 'TEST ADDRESS 1, PUNE', 'gstin': '27AAAAA0000A1Z0', 'pan': 'AAAAA0000A', 'invPrefix': 'SLI/TST/RA-', 'dnPrefix': 'SLI/TST/DN-'},
            'Rachana Construction Limited': {'address': '', 'gstin': '27BBBBB0000B1Z0', 'pan': 'BBBBB0000B', 'invPrefix': 'RCL/TST/RA-', 'dnPrefix': 'RCL/TST/DN-'},
          },
        },
        'pendingDn': [{'id': 'DN-0003', 'no': 'SLI/TST/DN-3', 'date': '2026-09-20', 'vendor': 'I E Enterprises', 'company': 'Sketchline Industries', 'total': 1500}],
      };
  static const _savedBills = [
    {'id': 'BILL-00001', 'vendor': 'I E Enterprises', 'company': 'Sketchline Industries', 'billNo': '7', 'rev': 0, 'from': '2026-08-01', 'to': '2026-08-31', 'billDate': '2026-09-05', 'net': 41250.5, 'status': 'Active', 'enteredBy': 'Tester', 'dnNo': 'SLI/TST/DN-2', 'dnAmt': 3200},
    {'id': 'BILL-00002', 'vendor': 'Chalke Enterprises', 'company': 'Rachana Construction Limited', 'billNo': '3', 'rev': 1, 'from': '2026-08-01', 'to': '2026-08-31', 'billDate': '2026-09-06', 'net': 18000, 'status': 'Superseded', 'enteredBy': 'Tester', 'dnNo': '', 'dnAmt': 0},
    // (3.77.0, Mechanical update-204) a deleted bill: not in Saved Bills, in Deleted Bills under its month
    {'id': 'BILL-00003', 'vendor': 'Chalke Enterprises', 'company': 'Sketchline Industries', 'billNo': '2', 'rev': 0, 'from': '2026-07-01', 'to': '2026-07-31', 'billDate': '2026-08-04', 'net': 9000, 'status': 'Deleted', 'enteredBy': 'Tester', 'deletedBy': 'Super Admin', 'deletedAt': '2026-08-05T06:00:00Z', 'deleteReason': 'wrong rate', 'dnNo': '', 'dnAmt': 0},
  ];
  static const _ledger = {
    'vendor': 'I E Enterprises', 'from': '', 'to': '', 'opening': 5000, 'openEntry': {'date': '2026-08-01', 'side': 'Payable', 'amount': 5000},
    'rows': [
      {'date': '2026-09-05', 'kind': 'bill', 'id': 'BILL-00001', 'bill': 41250.5, 'paid': 0, 'company': 'Sketchline Industries', 'billNo': '7', 'rev': 0, 'from': '2026-08-01', 'to': '2026-08-31', 'basic': 45000, 'diesel': 3200, 'other': 0, 'gst': 0, 'tds': 549.5, 'balance': 46250.5},
      {'date': '2026-09-25', 'kind': 'payment', 'id': 'PAY-00001', 'bill': 0, 'paid': 40000, 'company': '', 'mode': 'NEFT', 'ref': 'UTR123', 'against': 'RA 7 (01-08-2026 – 31-08-2026)', 'remark': '', 'balance': 6250.5},
      {'date': '2026-09-28', 'kind': 'dn', 'id': 'DN-0003', 'bill': -1500, 'paid': 0, 'company': 'Sketchline Industries', 'dnNo': 'SLI/TST/DN-3', 'remark': 'Work for the party', 'balance': 4750.5},
    ],
    'totalBill': 39750.5, 'totalPaid': 40000, 'closing': 4750.5,
  };
  // (3.9.0) Administration: the users and their access, the activity, the rules, Read Me; what was sent
  final adminSent = <Map<String, dynamic>>[];
  // (3.76.0, Mechanical update-203) a site's Day & tank check (the Portal) and a tank check due with a fill (Mechanical's tankDue)
  Map<String, dynamic> siteRules = {
    'dayStart': '06:00',
    'tank': {'since': '', 'groups': {'Own': '', 'Rental': '', 'Hired': ''}, 'machines': []},
    'machines': [
      {'no': 'MH-25-AJ-2169', 'name': '', 'type': 'Tipper', 'ownership': 'Rental', 'cap': 220, 'not': '', 'days': 0},
      {'no': 'Sany 210 (No.1)', 'name': '', 'type': 'Excavator', 'ownership': 'Own', 'cap': '', 'not': 'no Tank Capacity', 'days': 0},
    ],
  };
  Map<String, dynamic>? tankDueAns; // null = no check due
  final tankDueAsked = <Map>[];
  // (3.74.0) the site's own words for voice typing (Mechanical update-201): the Super Admin's words, the corrections learned, what was sent
  List<String> voiceAdmin = ['Arihant City'];
  List<Map<String, dynamic>> voiceFixes = [];
  final voiceSent = <Map<String, dynamic>>[];
  bool usersBySuper = false;
  final adminUsers = <Map<String, dynamic>>[
    {'email': 'sujit@rcl.test', 'name': 'Sujit Mule', 'active': true, 'admin': true, 'mustChange': false, 'perms': {'Dashboard': 'Edit', 'Log Book': 'Edit', 'Machinery Billing': 'Edit'}},
    {'email': 'clerk@rcl.test', 'name': 'Site Clerk', 'active': true, 'admin': false, 'mustChange': true, 'perms': {'Dashboard': 'View', 'Log Book': 'Edit', 'Machinery Billing': 'None'}},
  ];
  static const _readme = '<div class="rm-toc"><a href="#rm-what" data-rmgo="rm-what">1. हे app काय आहे</a></div><h3 id="rm-what">1. हे app काय आहे</h3><p>App चे <b>तीन</b> भाग &amp; <code>Code.gs</code>.</p>'
      '<table class="rm-t"><tr><th>भाग</th><th>काम</th></tr><tr><td><b>Supabase</b></td><td>data</td></tr></table><ol><li>पहिले</li><li>दुसरे <span class="rm-ok">✔ ok</span></li></ol>'
      '<div class="rm-step"><div class="rm-n">1</div><div class="rm-sb"><h4>Supabase project</h4><p>New project.</p></div></div>'
      '<div class="rm-adm"><label>Email <input id="rm_ad_email" type="email" placeholder="admin@company.com"></label></div><div class="rm-code"><button class="btn ghost small rm-copy" data-copy="rm_sql_admin">Copy</button><pre id="rm_sql_admin"></pre></div>';
  // (3.10.0) the Store: its sign-in (a ticket), the Item Master of the site; what was sent
  final storeSent = <Map<String, dynamic>>[];
  int storeSessions = 0;
  // (3.55.0, the Store's step 2) the pages the Store gives (as its pagesOf: a Store Admin every page, Store Purchase when given); its work
  bool storeAdmin = true;
  Map<String, dynamic> storePages = {'dashboard': 'View', 'items': 'Edit', 'req': 'Edit', 'grn': 'Edit', 'issue': 'Edit', 'reports': 'View', 'po': 'View', 'purchase': 'None'};
  final storeWork = <Map<String, dynamic>>[];
  bool regStep3 = true;
  // (3.58.0) a new GRN's GRN No: the next by itself (grnNext); typed by hand where the Store's step 4 is run (else only the next)
  bool storeStep4 = true;
  // (3.63.0) the Store's step 6 at the site: a GRN's discounts (off by default – the GRNs of before)
  bool storeStep6 = false;
  // (3.66.0) the Store's step 7 at the site: a requirement's photos (each photo sent: its fingerprint → its size)
  bool storeStep7 = true;
  final storePhotos = <String, int>{};
  // (3.70.0) the Store's step 8 at the site: the Indent No., the contact, the log book; changed after its approval, deleted (off by
  // default – the requirements as before); the PO that has requirement 1 (deleted: none)
  bool storeStep8 = false;
  int? req1Po = 1;
  final storeDeleted = <String>[];
  // (3.71.0, the Store's workflow – the Portal's Workflow and step 9) off by default: the Store as before. On: requirement 2 waits for
  // HIS verification, PO 1 for his verification, GRN 4 (against PO 1) for his verification, the return of outward 7 for his approval;
  // S1 buys its requirements itself (its Store Admin), Head Office has GRN 4 of S1 to check
  bool storeWf = false;
  final wfDone = <String>[];
  // (3.68.0) the Store's live: the site's last change (a test makes one: +1)
  int storeLive = 1;
  final regGrnsSaved = <(String, String, int, String, String)>[]; // (key, GRN No, no, date, supplier) of the register's GRNs saved
  // (3.62.0) the Store's step 5 at the site: a PO's own fields and its approval; the papers' settings; PO 1's approval
  bool storeStep5 = true;
  Map<String, dynamic> storePapers = {'prefix': '', 'email': 'store@rcl.test', 'site_contact': 'Store Keeper : 90000 00000', 'ship_to': 'VTR Site Store\nNH 848', 'terms': '1. Payment within 30 days.\n2. Material as per the specification.'};
  Map<String, dynamic> po1Appr = {'appr': 'Waiting', 'appr_name': null, 'appr_note': null};
  final storeReqs = <Map<String, dynamic>>[
    {'no': 2, 'date': '2026-10-14', 'need_by': '2026-10-20', 'for_kind': 'Machinery', 'for_text': 'Sany 210 (No.1)', 'status': 'Pending', 'level': 1, 'approvals': [], 'created_by': 'amol@rcl.test', 'created_name': 'Amol Patil',
      'lines': [{'line': 1, 'code': 'ITM-0001', 'name': 'Hydraulic Hose 1/2 inch', 'unit': 'Mtr', 'qty': 12, 'note': '', 'ordered': 0, 'left': 0}], 'mayApprove': true, 'mine': false, 'waitFor': ['Sujit Mule']},
    {'no': 1, 'date': '2026-10-12', 'need_by': null, 'for_kind': 'Site work', 'for_text': 'Ch 540+450 toe wall', 'status': 'Approved', 'level': 0, 'approvals': [{'level': 1, 'name': 'Sujit Mule', 'at': '2026-10-12T06:00:00Z', 'ok': true}], 'created_by': 'amol@rcl.test', 'created_name': 'Amol Patil',
      'lines': [{'line': 1, 'code': 'ITM-0002', 'name': 'Sugar', 'unit': 'Kg', 'qty': 50, 'note': 'canteen', 'ordered': 20, 'left': 30}], 'mayApprove': false, 'mine': false, 'waitFor': []},
  ];
  static const storePo = {'no': 1, 'site': 'S1', 'siteName': 'S1', 'date': '2026-10-13', 'vendor': 'Shri Traders', 'vendor_gst': '27ABCDE1234F1Z5', 'status': 'Open', 'state': 'Part received', 'taxable': 2000, 'gst': 100, 'total': 2100, 'created_name': 'Sujit Mule',
    'lines': [{'line': 1, 'code': 'ITM-0002', 'name': 'Sugar', 'unit': 'Kg', 'qty': 20, 'rate': 100, 'gst_pct': 5, 'taxable': 2000, 'gst': 100, 'total': 2100, 'req_no': 1, 'req_line': 1, 'received': 5, 'left': 15}]};
  static const storeIssue = {'no': 7, 'date': '2026-10-14', 'to_kind': 'Machinery', 'machinery': 'Sany 210 (No.1)', 'party': '', 'reading': 4712, 'location': '540+450', 'side': 'LHS', 'use_for': 'Breakdown', 'receiver': 'Gupta', 'debit': false, 'amount': 1200, 'created_name': 'Sujit Mule',
    'lines': [{'id': 71, 'line': 1, 'code': 'ITM-0001', 'name': 'Hydraulic Hose 1/2 inch', 'unit': 'Mtr', 'qty': 4, 'rate': 300, 'amount': 1200, 'gst': 0, 'returnable': true, 'serial': '', 'back': 1}], 'returns': [{'no': 1, 'date': '2026-10-14', 'lines': []}]};

  /// (3.71.0) GRN 4 (against PO 1) waiting for his verification, its bill checked with the PO (its rate 100 – the PO's 95 after its Disc. %)
  Map<String, dynamic> _wfGrn4() => {'no': 4, 'ref': '4', 'date': '2026-10-14', 'supplier': 'Shri Traders', 'invoice_no': 'INV-9', 'invoice_date': '2026-10-14', 'challan_no': '', 'vehicle_no': 'MH15AB1', 'po_no': 1, 'tcs': 0, 'gross': 525, 'created_name': 'Store Keeper',
        'lines': [{'line': 1, 'code': 'ITM-0002', 'name': 'Sugar', 'unit': 'Kg', 'qty': 5, 'rate': 100, 'gst_pct': 5, 'taxable': 500, 'gst': 25, 'gross': 525, 'po_line': 1, 'remark': ''}],
        'check': {'ok': false, 'diffs': [{'kind': 'rate', 'name': 'Sugar', 'unit': 'Kg', 'po': 95, 'bill': 100}]}, 'wf': {'state': 'verify', 'by': 'store@rcl.test', 'steps': []}, 'step': 'verify', 'mayDecide': true, 'waitFor': ['Sujit Mule']};
  /// (3.71.0) outward 7 with its return 1 waiting for his approval
  Map<String, dynamic> _wfIssue7() => {...storeIssue, 'returns': [{'no': 1, 'date': '2026-10-14', 'lines': [], 'wf': {'state': 'approve', 'by': 'store@rcl.test', 'steps': [{'step': 'verify', 'ok': true, 'name': 'View User', 'at': '2026-10-14T06:00:00Z'}]}, 'step': 'approve', 'mayDecide': true, 'waitFor': ['Sujit Mule']}]};

  http.Response _work(Map<String, dynamic> b) {
    List<Map<String, dynamic>> brief() => [for (final i in storeItems) {'code': i['code'], 'name': i['name'], 'unit': i['unit'], 'category': i['category'], 'gst_pct': i['gst_pct'], 'min_stock': i['min_stock'], 'status': i['status']}];
    final rep = {'title': 'Stock', 'sub': 'As on 14-10-2026', 'cols': [{'h': 'Code'}, {'h': 'Item'}, {'h': 'Stock', 'n': true}, {'h': 'Value ₹', 'n': true}], 'rows': [['ITM-0001', 'Hydraulic Hose 1/2 inch', 25, 2500], ['ITM-0002', 'Sugar', 10.5, 1050]], 'total': ['', 'Total (2 items)', '', 3550]};
    switch (b['action']) {
      case 'boot':
        return _j({'site': 'S1', 'today': '2026-10-14', 'items': brief(), 'stock': {'ITM-0001': 25, 'ITM-0002': 10.5}, 'avg': {'ITM-0001': 100, 'ITM-0002': 100},
          'machinery': [{'no': 'MH-25-AJ-2169', 'name': 'Tipper', 'own': 'Rental'}, {'no': 'Sany 210 (No.1)', 'name': 'Excavator', 'own': 'Own'}],
          'names': {'suppliers': ['Shri Traders'], 'subs': ['Ganesh Contractor'], 'vendors': ['Shri Traders'], 'gst': {'Shri Traders': '27ABCDE1234F1Z5'}},
          'levels': [{'level': 1, 'people': ['Sujit Mule']}], 'myLevels': [1], 'kinds': {'for': ['Site work', 'Machinery', 'Office', 'Other'], 'to': ['Site work', 'Sub-contractor', 'Machinery', 'Office'], 'sides': ['LHS', 'RHS', 'Both']},
          if (storeWf) 'wf': {'mine': {'vreq': true, 'vpo': true, 'vgrn': true, 'agrn': false, 'viss': false, 'aiss': true}, 'ho': {'req': false, 'grn': true, 'iss': false}, 'buy': true}, if (storeWf) 'step9': true});
      case 'dash':
        return _j({'today': '2026-10-14', 'stock': {'value': 3550, 'below': 1, 'items': 3}, 'req': {'pending': 1, 'mine': 1, 'approved': 1}, 'po': {'open': 1}, if (storeWf) 'wf': {'po': 1, 'grn': 1, 'issue': 0, 'ret': 1},
          'grn': {'today': 1, 'todayValue': 525, 'month': 2, 'monthValue': 2625, 'recent': [{'no': 4, 'date': '2026-10-14', 'supplier': 'Shri Traders', 'gross': 525}]},
          'issue': {'today': 1, 'todayValue': 1200, 'month': 1, 'monthValue': 1200, 'recent': [{'no': 7, 'date': '2026-10-14', 'to_kind': 'Machinery', 'machinery': 'Sany 210 (No.1)', 'party': '', 'amount': 1200}]}});
      case 'reqList':
        // (3.70.0) with step 8: the Indent No. (RCL/VTR/2026-27/M|P/0001), and what the server lets him do – as the Store's server
        Map<String, dynamic> s8(Map<String, dynamic> r) {
          final pos = r['no'] == 1 && req1Po != null ? [req1Po] : [];
          return {'ref': 'RCL/VTR/2026-27/${r['for_kind'] == 'Machinery' ? 'M' : 'P'}/${'${r['no']}'.padLeft(4, '0')}', 'pos': pos, 'edit': pos.isEmpty && ['Pending', 'Approved', 'Rejected'].contains(r['status']), 'del': pos.isEmpty, 'attach': true,
            'logbook': r['logbook'], 'contact_name': r['contact_name'] ?? '', 'contact_phone': r['contact_phone'] ?? ''};
        }
        Map<String, dynamic> vf(Map<String, dynamic> r) => storeWf && r['no'] == 2 && r['status'] == 'Pending' ? {'level': 0, 'step': 'verify', 'mayVerify': true, 'mayApprove': true, 'waitFor': ['Sujit Mule']} : {};
        return _j({'reqs': [for (final r in storeReqs) {...r, 'ref': 'RCL/VTR/PR/2026/${'${r['no']}'.padLeft(4, '0')}', 'photos': r['photos'] ?? [], if (storeStep8) ...s8(r), ...vf(r)}], 'levels': [{'level': 1, 'people': ['Sujit Mule']}], if (storeWf) 'verifiers': ['Sujit Mule'],
          'heading': {'site': 'VTR Site – NH 848', 'company': 'Rachana Construction Limited', 'address': 'Nashik', 'gstin': '27ABCDE1234F1Z5', 'email': storePapers['email'] ?? '', if (storeStep8) 'site_address': 'Site office, Valshind'}, 'step7': storeStep7,
          if (storeStep8) 'step8': true, if (storeStep8) 'start': {'contact_name': 'Ramesh Patil', 'contact_phone': '98765 43210'}});
      // (3.70.0) a machinery's maintenance log book; a requirement deleted, a photo taken out, its log book attached / taken out; a PO deleted
      case 'mlogInfo':
        return _j(b['no'] == 'Sany 210 (No.1)' ? {'no': b['no'], 'bills': 12, 'upto': '2026-10-10', 'amount': 45000} : {'no': b['no'], 'bills': 0, 'upto': '', 'amount': 0});
      case 'reqLogbook':
        final rqL = storeReqs.firstWhere((r) => r['no'] == b['no']);
        rqL['logbook'] = b['attach'] == true ? {'no': rqL['for_text'], 'upto': '2026-10-10', 'bills': 12, 'by': 'Sujit Mule'} : null;
        return _j({'ok': true, 'no': b['no'], 'logbook': rqL['logbook']});
      case 'reqLogbookHtml':
        final rqH = storeReqs.firstWhere((r) => r['no'] == b['no']);
        return _j({'no': b['no'], 'html': rqH['logbook'] == null ? '' : '<div class="mlbw"><div class="mlbt">Maintenance Log Book – ${rqH['for_text']}</div><table class="mlb"><tr><td>Hydraulic oil</td></tr></table></div>', 'css': '.mlb{border-collapse:collapse}'});
      case 'reqDelete':
        if (b['no'] == 1 && req1Po != null) return _j({'error': 'Requirement 1 is in PO $req1Po – delete PO $req1Po first (HO Purchase), then change or delete the requirement.', 'code': 'ordered'}, 409);
        storeReqs.removeWhere((r) => r['no'] == b['no']);
        storeDeleted.add('REQ ${b['no']}');
        return _j({'ok': true});
      case 'reqPhotoDel':
        final rqD = storeReqs.firstWhere((r) => r['no'] == b['no']);
        rqD['photos'] = [for (final p in (rqD['photos'] as List? ?? const [])) if ((p as Map)['sha'] != b['sha']) p];
        return _j({'ok': true, 'no': b['no'], 'photos': (rqD['photos'] as List).length});
      case 'poDelete':
        if (b['no'] == req1Po) req1Po = null;
        storeDeleted.add('PO ${b['no']}');
        return _j({'ok': true});
      // (3.66.0) a requirement's photos – as the Store's server: a JPEG only, kept under its fingerprint; its proof for the save
      case 'live':
        return _j({'v': storeLive});
      case 'reqPhotoUp':
        final mJ = RegExp(r'^data:image/jpeg;base64,(.+)$').firstMatch('${b['data'] ?? ''}');
        if (!storeStep7) return _j({'error': 'Photos of a requirement need the Store\'s database step 7 at this site.', 'code': 'sql'}, 400);
        if (mJ == null) return _j({'error': 'A photo must be a JPG picture (the page makes it one) – add it again.', 'code': 'field'}, 400);
        final bytes = base64Decode(mJ.group(1)!), h = crypto.sha256.convert(bytes).toString();
        storePhotos[h] = bytes.length;
        return _j({'ok': true, 'sha': h, 'size': bytes.length, 't': 'proof-${h.substring(0, 8)}'});
      case 'reqPhotos':
        final rq = storeReqs.where((r) => r['no'] == b['no']).firstOrNull;
        return _j({'no': b['no'], 'photos': [for (final p in (rq?['photos'] as List? ?? const [])) {...(p as Map), 'url': 'https://erp.test/ph/${p['sha']}.jpg'}]});
      case 'reqPhotoAdd':
        final rqA = storeReqs.firstWhere((r) => r['no'] == b['no']);
        final list = [...(rqA['photos'] as List? ?? const [])];
        for (final p in (b['photos'] as List)) {
          final m2 = (p as Map).cast<String, dynamic>();
          if (m2['t'] != 'proof-${'${m2['sha']}'.substring(0, 8)}') return _j({'error': 'A photo was not added from this page (or by you) – add it again.', 'code': 'field'}, 400);
          list.add({'sha': m2['sha'], 'size': m2['size'], 'by': 'Sujit Mule', 'at': '2026-10-14T05:00:00.000Z'});
        }
        rqA['photos'] = list;
        return _j({'ok': true, 'no': b['no'], 'photos': list.length});
      case 'reqSave':
        if (storeStep8 && b['no'] != null) {
          final rqS = storeReqs.firstWhere((r) => r['no'] == b['no']);
          return _j({'ok': true, 'no': b['no'], 'status': 'Pending', 'level': 1, 'again': rqS['status'] != 'Pending' || (rqS['approvals'] as List).isNotEmpty});
        }
        return _j({'ok': true, 'no': 3, 'status': 'Pending', 'level': 1, if (storeStep8) 'ref': 'RCL/VTR/2026-27/M/0003'});
      case 'reqDecide':
        final nos = [for (final n in (b['nos'] as List? ?? [b['no']])) n];
        for (final r in storeReqs) {
          if (nos.contains(r['no'])) {
            r['status'] = b['ok'] == true ? 'Approved' : 'Rejected';
            r['mayApprove'] = false;
          }
        }
        return _j({'ok': true, 'done': [for (final n in nos) {'no': n, 'status': b['ok'] == true ? 'Approved' : 'Rejected', 'level': 0, if (storeWf && n == 2) 'step': 'verify'}], 'left': []});
      case 'reqCancel' || 'reqClose' || 'poCancel' || 'poClose' || 'grnDelete' || 'issueDelete' || 'retDelete':
        return _j({'ok': true});
      case 'purPending':
        if (storeWf && b['mine'] == true) return _j({'sites': [{'site': 'S1', 'name': 'VTR Site – NH 848', 'reqs': [{...storeReqs.firstWhere((r) => r['no'] == 1), 'made_by': 'Amol Patil', 'since': '2026-10-12'}], 'open': 1}], 'today': '2026-10-14'});
        if (storeWf) return _j({'today': '2026-10-14', 'sites': [{'site': 'S1', 'name': 'VTR Site – NH 848', 'reqs': [], 'own': true, 'open': 1}, {'site': 'T2', 'name': '18B Kolhapur', 'reqs': [{...storeReqs.firstWhere((r) => r['no'] == 1), 'made_by': 'Amol Patil', 'since': '2026-10-12'}], 'open': 0}]});
        return _j({'sites': [
          {'site': 'S1', 'name': 'VTR Site – NH 848', 'reqs': [storeReqs.firstWhere((r) => r['no'] == 1)], 'open': 1},
          {'site': 'T2', 'name': '18B Kolhapur', 'reqs': [], 'error': 'The Store\'s step 2 is not run in this site\'s database yet.'},
        ]});
      case 'purItems':
        return _j({'site': b['site'], 'items': [for (final i in brief()) {...i, 'hsn': i['code'] == 'ITM-0002' ? '1701' : ''}], 'vendors': ['Shri Traders'], 'gst': {'Shri Traders': '27ABCDE1234F1Z5'},
          'papers': {'ship_to': storePapers['ship_to'] ?? '', 'site_contact': storePapers['site_contact'] ?? '', 'terms': storePapers['terms'] ?? ''}, 'step5': storeStep5});
      case 'poList':
        // (3.62.0) PO 1 waits for the approval of Sujit Mule (the one signed in) – it was made by someone else
        final wait = storeStep5 && po1Appr['appr'] == 'Waiting';
        // (3.70.0) with step 8: PO 1 with nothing come yet (it may be deleted); deleted – no PO
        if (storeStep8 && req1Po == null) return _j({'pos': []});
        final po0 = storeStep8 ? {...storePo, 'state': 'Open', 'lines': [{...((storePo['lines'] as List).first as Map), 'received': 0, 'left': 20, 'req_ref': 'RCL/VTR/2026-27/P/0001'}]} : storePo;
        final v1 = storeWf && wait && !wfDone.contains('PO 1');
        return _j({'pos': [{...po0, ...(storeStep5 ? po1Appr : {'appr': 'Approved'}), 'mayApprove': wait, 'waitFor': wait ? ['Sujit Mule'] : [], if (storeWf) 'grns': 1, if (v1) 'step': 'verify', if (v1) 'mayVerify': true},
          // (3.95.0) a PO of the Purchase Department – its copy here, approved (G-6), read-only at the site
          if (storePurPo)
            {'no': 21, 'site': 'S1', 'date': '2026-10-14', 'vendor': 'Bharat Steel', 'status': 'Open', 'state': 'Open', 'appr': 'Approved', 'appr_name': 'Purchase (Sujit Mule)', 'mayApprove': false, 'waitFor': [], 'total': 130800,
              'lines': [{'line': 1, 'code': 'ITM-0004', 'name': 'TMT bar 12 mm', 'unit': 'MT', 'qty': 2, 'received': 0, 'left': 2, 'req_no': 7, 'req_line': 3}], 'pur_no': 1, 'pur_rev': 1, 'pur': {'ref': 'PO-0001'}},
        ], 'buy': storePages['purchase'] == 'Edit' || (storeWf && storeAdmin), 'today': '2026-10-14'});
      // (3.71.0) one PO with every GRN against it – ordered / came / balance, each GRN checked with the PO
      case 'poGrns':
        return _j({'po': {...storePo, 'ref': 'RCL/VTR/PO/2026/0001'}, 'today': '2026-10-14', 'lines': [{'line': 1, 'code': 'ITM-0002', 'name': 'Sugar', 'unit': 'Kg', 'qty': 20, 'rate': 100, 'came': 5, 'left': 15, 'value': 2000, 'cameValue': 500, 'leftValue': 1500}],
          'grns': [{'no': 4, 'ref': '4', 'date': '2026-10-14', 'supplier': 'Shri Traders', 'invoice_no': 'INV-9', 'gross': 525, 'lines': [{'line': 1, 'name': 'Sugar', 'unit': 'Kg', 'qty': 5, 'rate': 100, 'taxable': 500, 'po_line': 1}],
            'check': {'ok': false, 'diffs': [{'kind': 'rate', 'name': 'Sugar', 'unit': 'Kg', 'po': 95, 'bill': 100}]}, 'wf': {'state': 'verify', 'by': 'store@rcl.test', 'steps': []}, 'step': 'verify', 'mayDecide': true, 'waitFor': ['Sujit Mule']}]});
      case 'wfMine':
        if (!storeWf) return _j({'grns': [], 'issues': [], 'step9': false});
        return _j({'step9': true, 'grns': [if (!wfDone.contains('grn 4')) _wfGrn4()], 'issues': [if (!wfDone.contains('ret 1')) _wfIssue7()]});
      case 'wfDecide':
        wfDone.add('${b['kind']} ${b['no']}');
        return _j({'ok': true, 'no': b['no'], 'state': b['ok'] == true ? (b['kind'] == 'grn' ? 'approve' : 'done') : 'returned', 'ho': false});
      case 'hoInbox':
        if (!storeWf) return _j({'error': 'Unknown action.'}, 404); // (as a Store before its workflow – the old tests' Purchase page unchanged)
        final grnHo = {..._wfGrn4(), 'wf': {'state': 'done', 'ho': true, 'steps': [{'step': 'approve', 'ok': true, 'name': 'Asha Accounts', 'at': '2026-10-14T06:00:00Z'}], if (wfDone.contains('ho grn 4')) 'hoOk': {'name': 'Sujit Mule'}}, 'step': '', 'mayDecide': false};
        final done = b['done'] == true;
        return _j({'kind': b['kind'], 'done': done, 'sites': [
          {'site': 'S1', 'name': 'VTR Site – NH 848', 'ho': b['kind'] == 'grn', 'step9': true, 'rows': [if (b['kind'] == 'grn' && done == wfDone.contains('ho grn 4')) grnHo]},
          {'site': 'T2', 'name': '18B Kolhapur', 'rows': [], 'step9': false},
        ]});
      case 'hoCheck':
        wfDone.add('ho ${b['kind']} ${b['no']}');
        return _j({'ok': true});
      case 'poGet':
        return _j({
          'po': {...storePo, ...po1Appr, 'ref': 'RCL/VTR/PO/2026/0001', 'words': 'Two Thousand One Hundred Rupees Only', 'credit_days': 30, 'site_contact': 'Store Keeper : 90000 00000', 'ship_to': 'VTR Site Store\nNH 848', 'freight': 0, 'load_unload': 0,
            'terms': '1. Payment within 30 days.\n2. Material as per the specification.', 'lines': [{...(storePo['lines'] as List).first as Map, 'hsn': '1701', 'disc_pct': 0, 'disc': 0}]},
          'heading': {'site': 'VTR Site – NH 848', 'company': 'Rachana Construction Limited', 'address': 'Nashik', 'gstin': '27ABCDE1234F1Z5', 'pan': 'ABCDE1234F', 'email': storePapers['email'] ?? '', 'phone': '', 'cin': '', 'web': ''},
          'supplier': {'name': 'Shri Traders', 'address': 'Nashik Road', 'mobile': '', 'email': '', 'contact': '', 'gstin': '27ABCDE1234F1Z5'},
        });
      case 'poDecide':
        if (!storeStep5) return _j({'error': 'The purchase order\'s Credit Period, Site Contact, Shipping Address, Freight, Load / Unload and its approval need the Store\'s database step 5 at this site.', 'code': 'sql'}, 400);
        if (b['ok'] != true && '${b['note'] ?? ''}'.trim().isEmpty) return _j({'error': 'Say why the PO is rejected (the one who made it sees it).', 'code': 'field'}, 400);
        po1Appr = {'appr': b['ok'] == true ? 'Approved' : 'Rejected', 'appr_name': 'Sujit Mule', 'appr_note': b['ok'] == true ? null : b['note']};
        return _j({'ok': true, 'no': b['no'], 'appr': po1Appr['appr']});
      case 'poSave':
        final po = (b['po'] as Map).cast<String, dynamic>();
        if (po['vendor'] == 'Shree Traders' && b['confirmParty'] != true) {
          return _j({'error': 'Please confirm: "Shri Traders" is already there – is "Shree Traders" another vendor?', 'code': 'party', 'near': ['Shri Traders'], 'field': 'vendor', 'typed': 'Shree Traders'}, 409);
        }
        return _j({'ok': true, 'site': b['site'], 'no': 2, 'total': 1575, 'appr': storeStep5 ? 'Waiting' : 'Approved'});
      case 'grnList':
        return _j({'from': b['from'], 'to': b['to'], 'grns': [
          // (3.63.0) with step 6: a GRN with a line's 10 % on Basic and the bill's 2 % on Basic – its net rate the stock's
          if (storeStep6)
            {'no': 6, 'ref': '6', 'date': '2026-10-14', 'supplier': 'Shri Traders', 'invoice_no': 'INV-12', 'invoice_date': '2026-10-14', 'challan_no': '', 'vehicle_no': '', 'po_no': null, 'tcs': 0, 'gross': 926.1, 'created_name': 'Sujit Mule',
              'basic': 1000, 'disc': 118, 'bill_disc': 18, 'bill_disc_pct': 2, 'bill_disc_on': 'basic',
              'lines': [{'line': 1, 'code': 'ITM-0002', 'name': 'Sugar', 'unit': 'Kg', 'qty': 10, 'rate': 100, 'gst_pct': 5, 'basic': 1000, 'disc': 100, 'disc_pct': 10, 'disc_on': 'basic', 'bill_disc': 18, 'taxable': 882, 'gst': 44.1, 'gross': 926.1, 'net_rate': 88.2, 'po_line': null, 'remark': ''}]},
          storeWf ? {..._wfGrn4(), if (wfDone.contains('grn 4')) 'wf': {'state': 'approve', 'by': 'store@rcl.test', 'steps': [{'step': 'verify', 'ok': true, 'name': 'Sujit Mule', 'at': '2026-10-14T06:00:00Z'}]}, if (wfDone.contains('grn 4')) 'mayDecide': false, if (wfDone.contains('grn 4')) 'step': 'approve'}
          : {'no': 4, 'ref': '4', 'date': '2026-10-14', 'supplier': 'Shri Traders', 'invoice_no': 'INV-9', 'invoice_date': '2026-10-14', 'challan_no': '', 'vehicle_no': 'MH15AB1', 'po_no': 1, 'tcs': 0, 'gross': 525, 'created_name': 'Sujit Mule',
            'lines': [{'line': 1, 'code': 'ITM-0002', 'name': 'Sugar', 'unit': 'Kg', 'qty': 5, 'rate': 100, 'gst_pct': 5, 'taxable': 500, 'gst': 25, 'gross': 525, 'po_line': 1, 'remark': ''}]},
          {'no': 1000000001, 'ref': '342-A', 'date': '2026-10-13', 'supplier': 'Om Hardware Bhiwandi', 'invoice_no': 'OH-77', 'invoice_date': '2026-10-12', 'challan_no': 'CH-5', 'vehicle_no': 'MH04AB1234', 'po_no': null, 'tcs': 12.5, 'gross': 1192.5, 'created_name': 'Sujit Mule',
            'lines': [{'line': 1, 'code': 'ITM-0001', 'name': 'Hydraulic Hose 1/2 inch', 'unit': 'Mtr', 'qty': 4, 'rate': 250, 'gst_pct': 18, 'taxable': 1000, 'gst': 180, 'gross': 1180, 'po_line': null, 'remark': 'Mechanical'}]},
        ]});
      case 'poOpen':
        return _j({'pos': [storePo]});
      case 'grnNext':
        return _j({'next': 5, 'step4': storeStep4, 'step6': storeStep6});
      case 'grnSave':
        final g = (b['grn'] as Map).cast<String, dynamic>();
        final over = g['po_no'] != null && (g['lines'] as List).any((l) => (num.tryParse('${(l as Map)['qty']}') ?? 0) > 15);
        if (over && b['confirmOver'] != true) return _j({'error': 'More than PO 1 still has to come – Sugar: 20 Kg (PO still has 15). Take it in anyway?', 'code': 'over', 'over': ['Sugar: 20 Kg (PO still has 15)']}, 409);
        // (3.58.0) as the Store's server: a GRN No already used – refused, the next free one said; typed by hand before step 4 – refused
        final ref = '${g['ref'] ?? ''}'.trim();
        if (b['no'] == null && ref.isNotEmpty && ['4', '342-A'].contains(ref.toUpperCase())) return _j({'error': 'GRN No $ref is already used by another GRN – the next free number is 5. Nothing was saved.', 'code': 'refused', 'next': 5}, 409);
        if (b['no'] == null && ref.isNotEmpty && ref != '5' && !storeStep4) return _j({'error': 'A GRN No typed by hand needs the Store\'s database step 4 at this site: the Admin runs sql/store_step4_grn_no.sql once in Supabase → SQL Editor (in every site). Until then the GRN gets the next number by itself – leave its GRN No as it comes.', 'code': 'sql'}, 400);
        final no = b['no'] ?? (RegExp(r'^\d{1,9}$').hasMatch(ref) ? int.parse(ref) : ref.isEmpty ? 5 : 1000000002);
        return _j({'ok': true, 'no': no, 'ref': b['no'] != null ? '${b['no']}' : (ref.isEmpty ? '5' : ref), 'gross': 2100});
      case 'issueList':
        return _j({'from': b['from'], 'to': b['to'], 'issues': [storeIssue]});
      case 'issueSave':
        return _j({'ok': true, 'no': 8, 'amount': 500});
      case 'retSave':
        return _j({'ok': true, 'no': 2});
      case 'report':
        return _j(rep);
      case 'openingList':
        return _j({'rows': [{'code': 'ITM-0001', 'qty': 20, 'rate': 100, 'date': '2026-10-01'}]});
      case 'openingSave':
        return _j({'ok': true, 'rows': (b['rows'] as List).length});
      case 'numbers' || 'numbersSave' || 'papersSave':
        if (b['action'] == 'papersSave') storePapers = {for (final k in ['prefix', 'email', 'phone', 'cin', 'web', 'site_contact', 'ship_to', 'terms', 'site_address']) if ('${b[k] ?? ''}'.isNotEmpty) k: '${b[k]}'};
        final pre = '${storePapers['prefix'] ?? ''}'.isNotEmpty ? storePapers['prefix'] : 'RCL/S1';
        return _j({'next': {'GRN': 5, 'OUT': 8}, 'used': {'GRN': 4, 'OUT': 7}, 'papers': storePapers, 'prefixNow': pre, 'step5': storeStep5, if (b['action'] != 'numbers') 'ok': true});
      // (3.57.0) the old inward register's import (rcl-store api/work.js regInfo / regNames / regVendors / regItems / regGrns)
      case 'regInfo':
        return _j({'step3': regStep3, 'ai': true, 'today': '2026-10-28', 'units': ['Nos', 'Kg', 'Ltr'], 'next': regGrnsSaved.isEmpty ? 1 : 8031, 'items': [], 'vendors': [],
          'grns': [for (final d in regGrnsSaved) [d.$1, d.$2, d.$3, d.$4, d.$5]]});
      case 'regNames':
        final fx = [
          for (final n in (b['names'] as List).whereType<List>())
            if (RegExp('Hydrolic|Fliter|Bindding').hasMatch('${n[0]}')) ['${n[0]}', '${n[0]}'.replaceAll('Hydrolic', 'Hydraulic').replaceAll('Fliter', 'Filter').replaceAll('Bindding', 'Binding')],
        ];
        return _j({'fixes': fx});
      case 'regVendors':
        return _j({'added': (b['names'] as List).length, 'have': 0});
      case 'regItems':
        return _j({'added': [for (final (i, x) in (b['items'] as List).indexed) ['ITM-${(i + 1).toString().padLeft(4, '0')}', (x as Map)['name']]], 'have': 0, 'bad': []});
      case 'regGrns':
        final saved = [];
        for (final d in (b['docs'] as List).whereType<Map>()) {
          regGrnsSaved.add((grnDocKey(d['ref'], d['date'], d['supplier'], d['invoice_no']), '${d['ref']}', regGrnsSaved.length + 1, '${d['date']}', '${d['supplier']}'));
          saved.add({'no': regGrnsSaved.length, 'ref': d['ref']});
        }
        return _j({'saved': saved, 'skipped': [], 'errors': []});
      case 'importDocs':
        if (b['check'] == true) return _j({'rows': [{'line': 2, 'ref': '11', 'item': 'Sugar', 'status': 'ok', 'msg': 'GRN of 14-10-2026 – 1 item(s)', 'code': 'ITM-0002'}], 'docs': 1, 'errors': 0});
        return _j({'ok': true, 'saved': 1, 'nos': [6], 'rows': [], 'docs': 1, 'errors': 0});
    }
    return _j({'error': 'Unknown action.'}, 404);
  }
  final storeItems = <Map<String, dynamic>>[
    {'code': 'ITM-0001', 'name': 'Hydraulic Hose 1/2 inch', 'unit': 'Mtr', 'category': 'Spare Parts', 'hsn': '40092100', 'gst_pct': 18, 'min_stock': 10, 'status': 'Active', 'similar_note': null, 'created_by': 'sujit@rcl.test', 'created_at': '2026-10-02T06:00:00Z'},
    {'code': 'ITM-0002', 'name': 'Sugar', 'unit': 'Kg', 'category': 'Canteen', 'hsn': '', 'gst_pct': 5, 'min_stock': null, 'status': 'Active', 'similar_note': null, 'created_by': 'sujit@rcl.test', 'created_at': '2026-10-10T06:00:00Z'},
    {'code': 'ITM-0003', 'name': 'Oil Filter', 'unit': 'Nos', 'category': 'Spare Parts', 'hsn': '8421', 'gst_pct': 18, 'min_stock': 4, 'status': 'Inactive', 'similar_note': null, 'created_by': 'clerk@rcl.test', 'created_at': '2026-09-20T06:00:00Z'},
  ];
  Map<String, dynamic> get _compliance => {
        'today': '2026-10-14', 'soonDays': 30, 'docs': ['Tax', 'PUC', 'Permit', 'Fitness', 'Insurance'], 'noPapers': 1,
        'machines': [
          {'no': 'MH-25-AJ-2169', 'type': 'Tipper', 'owner': 'I E Enterprises', 'ownership': 'Rental', 'files': cmpFilesOn ? 1 : 0, 'docs': {
            'Tax': {'v': 'LIFETIME', 's': 'life', 'days': ''}, 'PUC': {'v': '2026-09-30', 's': 'expired', 'days': -14}, 'Permit': {'v': '', 's': 'missing', 'days': ''},
            'Fitness': {'v': '2027-01-31', 's': 'ok', 'days': 109}, 'Insurance': {'v': '2026-10-20', 's': 'due', 'days': 6}}},
          {'no': 'Sany 210 (No.1)', 'type': 'Excavator', 'owner': 'RCL', 'ownership': 'Own', 'docs': {
            'Tax': {'v': '', 's': 'notreq', 'days': ''}, 'PUC': {'v': '', 's': 'notreq', 'days': ''}, 'Permit': {'v': '', 's': 'notreq', 'days': ''}, 'Fitness': {'v': '', 's': 'notreq', 'days': ''},
            'Insurance': {'v': '2027-03-31', 's': 'ok', 'days': 168}}},
        ],
        'types': [
          {'type': 'Tipper', 'key': 'TIPPER', 'count': 1, 'docs': ['Tax', 'PUC', 'Permit', 'Fitness', 'Insurance'], 'set': false, 'guess': 'Road vehicle – all papers'},
          {'type': 'Excavator', 'key': 'EXCAVATOR', 'count': 1, 'docs': ['Insurance'], 'set': true, 'guess': ''},
        ],
        'history': [
          {'id': 'CMP-000002', 'on': '2026-10-02', 'no': 'MH-25-AJ-2169', 'doc': 'Fitness', 'from': '2026-09-30', 'to': '2027-01-31', 'docNo': 'F-77', 'amount': 1200, 'remark': '', 'source': '', 'by': 'Tester', 'files': 0},
          if (cmpFilesOn) {'id': 'CMP-000001', 'on': '2026-09-01', 'no': 'MH-25-AJ-2169', 'doc': 'RC Book', 'from': '', 'to': '', 'docNo': 'MH25AJ2169', 'amount': '', 'remark': '', 'source': 'Document', 'by': 'Tester', 'files': 1},
        ],
        'filesOn': cmpFilesOn, 'keep': ['RC Book', 'Tax Invoice'],
      };
  List<String> _works(dynamic w) => '${w ?? ''}'.split(',').map((x) => x.trim()).where((x) => x.isNotEmpty).toList();

  // (3.94.0, Purchase Phase 1) the answers of rcl-purchase's api/pur.js, kept simple: the same shapes and the checks the screens show
  http.Response _purAct(Map<String, dynamic> b) {
    final admin = purRole != 'user', sup = purRole == 'super';
    String ref(Object? n) => 'RFQ-${'$n'.padLeft(4, '0')}';
    String csRef(Object? n) => 'CS-${'$n'.padLeft(4, '0')}';
    Map<String, dynamic>? rfqOf(Object? no) => purRfqs.where((x) => '${x['no']}' == '$no').firstOrNull;
    bool locked(int no) => ['Sent', 'Approved', 'Rejected'].contains(purCs[no]?['status']);
    int quotes(int no) => purQuotes.keys.where((k) => k.startsWith('$no:')).length;
    Map<String, dynamic> rfqOut(Map<String, dynamic> q) => {...q, 'ref': ref(q['no'])};
    Map<String, dynamic>? csBrief(int no) => purCs[no] == null ? null : {'no': purCs[no]!['no'], 'ref': csRef(purCs[no]!['no']), 'status': purCs[no]!['status'], 'total': purCs[no]!['total']};
    Map<String, dynamic> rfqGet(Map<String, dynamic> q) {
      final no = q['no'] as int, st = '${q['status']}', open = st == 'Sent' || st == 'Quotes in';
      return {'ok': true, 'rfq': rfqOut(q), 'cs': csBrief(no),
        'vendors': [for (final v in q['vendors'] as List) {...purVendors.firstWhere((y) => y['id'] == v['id']), 'quote': purQuotes['$no:${v['id']}'] == null ? null : {'at': purQuotes['$no:${v['id']}']!['at'], 'by': purQuotes['$no:${v['id']}']!['by'], 'locked': locked(no)}}],
        'may': {'edit': (st == 'Draft' || open) && !locked(no), 'send': st == 'Draft', 'cancel': st == 'Draft' || open, 'quote': open && !locked(no), 'cs': open && quotes(no) > 0}};
    }
    Map<String, dynamic> csGet(int rfq) {
      final c = purCs[rfq], q = rfqOf(rfq)!;
      if (c == null) return {'ok': true, 'cs': null, 'rfq': rfqOut(q), 'limit': purLimit, 'quotes': quotes(rfq)};
      final edit = c['status'] == 'Draft' || c['status'] == 'Sent back', decide = admin && c['status'] == 'Sent' && c['created_by'] != 'sujit@rcl.test' && (c['need'] == 'admin' || sup);
      return {'ok': true, 'rfq': rfqOut(q), 'limit': purLimit,
        'cs': {...c, 'ref': csRef(c['no']), 'rfq_ref': ref(rfq), 'limit': purLimit, 'problems': [], 'may': {'edit': edit, 'send': edit, 'decide': decide, 'why': decide ? '' : 'Only a Purchase Admin of S1 or the Super Admin decides it.'}},
        // (3.95.0) an approved CS: its POs – one a supplier × site
        if (c['status'] == 'Approved')
          'po': {'step3': true, 'groups': [
            for (final g in [(1, 'Asha Traders', 'Cement OPC 53', 24820), (2, 'Bharat Steel', 'TMT bar 12 mm', 130800)])
              {'vendor': g.$1, 'vendor_name': g.$2, 'site': 'S1', 'lines': 1, 'items': g.$3, 'total': g.$4, 'missing': g.$1 == 2 ? 1 : 0,
                'po': purPos.where((p) => p['vendor_id'] == g.$1).map((p) => {'no': p['no'], 'ref': 'PO-${'${p['no']}'.padLeft(4, '0')}', 'status': p['status'], 'state': p['status'] == 'Cancelled' ? 'Cancelled' : 'At the site', 'total': p['total']}).firstOrNull,
                'may': admin && !purPos.any((p) => p['vendor_id'] == g.$1)},
          ]},
      };
    }
    Map<String, dynamic> poGet(Map<String, dynamic> p) {
      final st = p['status'] == 'Cancelled' ? 'Cancelled' : 'At the site';
      return {'ok': true, 'site_name': 'VTR Site – NH 848', 'site_error': '', 'heading': {'company': 'Rachana Construction Limited'},
        'po': {...p, 'ref': 'PO-${'${p['no']}'.padLeft(4, '0')}', 'state': st, 'words': 'One Lakh Thirty Thousand Eight Hundred Only', 'wa': '919822012345', 'cs_ref': 'CS-0001', 'rfq_ref': 'RFQ-0001',
          'approved': {'by': 'sujit@rcl.test', 'name': 'Sujit Mule', 'at': '2026-10-14T08:00:00Z'}, 'sent': {'rev': 1, 'at': '2026-10-14T08:10:00Z', 'store_no': 21, 'error': '', 'tries': 1, 'last': '2026-10-14T08:10:00Z'}},
        'site': {'no': 21, 'ref': 'RCL/VTR/PO/2026/0021', 'status': p['status'], 'state': p['status'] == 'Cancelled' ? 'Cancelled' : 'Open', 'grn_count': 0, 'grns': [],
          'lines': [for (final l in p['lines'] as List) {'line': l['line'], 'name': l['name'], 'unit': l['unit'], 'qty': l['qty'], 'came': 0, 'left': p['status'] == 'Cancelled' ? 0 : l['qty']}]},
        'may': {'send': false, 'cancel': admin && p['status'] == 'Open'}};
    }
    switch (b['action']) {
      case 'inbox':
        final taken = {for (final q in purRfqs) if (q['status'] != 'Cancelled') for (final l in q['lines'] as List) '${l['site']}:${l['req_no']}:${l['req_line']}': {'rfq': q['no'], 'status': q['status'], 'cs': purCs[q['no']]?['no']}};
        Map<String, dynamic> ln(String site, int req, int line, String code, String name, String unit, num qty, num ordered, String brand) =>
            {'line': line, 'code': code, 'name': name, 'unit': unit, 'qty': qty, 'ordered': ordered, 'left': qty - ordered, 'brand': brand, 'spec': '', 'note': '', 'taken': taken['$site:$req:$line']};
        return _j({'ok': true, 'link': true, 'today': '2026-10-14', 'sites': [
          {'site': 'S1', 'name': 'VTR Site – NH 848', 'reqs': [
            {'no': 7, 'ref': 'IND-0007', 'date': '2026-10-10', 'need_by': '2026-10-20', 'for_kind': 'Machine', 'for_text': 'JCB 3DX', 'remark': '', 'since': '2026-10-10', 'made_by': 'Store One',
              'lines': [ln('S1', 7, 1, 'ITM-0001', 'Cement OPC 53', 'Bag', 50, 0, 'UltraTech'), ln('S1', 7, 2, 'ITM-0003', 'Binding wire', 'Kg', 40, 0, ''), ln('S1', 7, 3, 'ITM-0004', 'TMT bar 12 mm', 'MT', 2, 0, '')]},
          ]},
          {'site': 'T2', 'name': '18B Kolhapur', 'reqs': [
            {'no': 3, 'ref': 'IND-0003', 'date': '2026-10-12', 'need_by': '2026-10-18', 'for_kind': 'Site', 'for_text': '', 'remark': '', 'since': '2026-10-12', 'made_by': 'Store Two', 'lines': [ln('T2', 3, 1, 'ITM-0002', 'Diesel filter', 'Nos', 6, 2, 'Fleetguard')]},
          ]},
        ]});
      case 'rfqList':
        return _j({'ok': true, 'rfqs': [
          for (final q in purRfqs.reversed)
            if ('${b['status'] ?? ''}'.isEmpty || q['status'] == b['status'])
              {...rfqOut(q), 'nlines': (q['lines'] as List).length, 'items': (q['lines'] as List).map((l) => l['name']).join(', '), 'sites': {for (final l in q['lines'] as List) l['site']}.toList(), 'quotes': quotes(q['no'] as int), 'cs': csBrief(q['no'] as int)},
        ]});
      case 'rfqGet':
        return _j(rfqGet(rfqOf(b['no'])!));
      case 'rfqSave':
        if ((b['lines'] as List).isEmpty) return _j({'error': 'Add at least one line.', 'code': 'field'}, 400);
        final names = {'S1:7:2': ['ITM-0003', 'Binding wire', 'Kg'], 'S1:7:1': ['ITM-0001', 'Cement OPC 53', 'Bag'], 'T2:3:1': ['ITM-0002', 'Diesel filter', 'Nos']};
        final no = purRfqs.length + 1;
        final q = <String, dynamic>{'no': no, 'site': 'S1', 'date': b['date'], 'need_by': b['need_by'], 'remark': b['remark'], 'status': 'Draft', 'status_note': '', 'sent_at': null, 'created_name': 'Sujit Mule', 'ver': 1,
          'lines': [for (final (i, l) in (b['lines'] as List).indexed) {'line': i + 1, 'site': l['site'], 'req_no': l['req_no'], 'req_line': l['req_line'], 'ref': l['site'] == 'S1' ? 'IND-0007' : 'IND-0003', 'code': names['${l['site']}:${l['req_no']}:${l['req_line']}']![0], 'name': names['${l['site']}:${l['req_no']}:${l['req_line']}']![1], 'unit': names['${l['site']}:${l['req_no']}:${l['req_line']}']![2], 'qty': num.parse('${l['qty']}'), 'brand': '', 'spec': ''}],
          'vendors': [for (final id in b['vendors'] as List) {'id': id, 'name': purVendors.firstWhere((v) => v['id'] == id)['name']}]};
        purRfqs.add(q);
        return _j({...rfqGet(q), 'saved': true});
      case 'rfqSend':
        final q = rfqOf(b['no'])!;
        q['status'] = 'Sent';
        q['sent_at'] = '2026-10-14T07:00:00Z';
        q['ver'] = (q['ver'] as int) + 1;
        return _j({...rfqGet(q), 'saved': true});
      case 'rfqCancel':
        final q = rfqOf(b['no'])!;
        q['status'] = 'Cancelled';
        q['status_note'] = b['why'];
        return _j({...rfqGet(q), 'saved': true});
      case 'quoteGet':
      case 'quoteSave':
        final no = b['rfq'] as int, q = rfqOf(no)!, k = '$no:${b['vendor']}';
        if (b['action'] == 'quoteSave') {
          purQuotes[k] = {'lines': [for (final l in b['lines'] as List) {'line': l['line'], 'rate': num.tryParse('${l['rate']}'), 'disc': num.tryParse('${l['disc']}') ?? 0, 'gst': num.tryParse('${l['gst']}'), 'days': num.tryParse('${l['days']}')}],
            'freight': num.tryParse('${b['freight']}') ?? 0, 'loading': num.tryParse('${b['loading']}') ?? 0, 'pay_terms': b['pay_terms'], 'valid_till': '${b['valid_till']}'.isEmpty ? null : b['valid_till'], 'remark': b['remark'], 'history': [], 'locked': false, 'ver': 1, 'at': '2026-10-14T07:10:00Z', 'by': 'Sujit Mule'};
          if (q['status'] == 'Sent') q['status'] = 'Quotes in';
        }
        return _j({'ok': true, if (b['action'] == 'quoteSave') 'saved': true, 'rfq': rfqOut(q), 'vendor': {'id': b['vendor'], 'name': purVendors.firstWhere((v) => v['id'] == b['vendor'])['name']}, 'quote': purQuotes[k], 'may': {'save': (q['status'] == 'Sent' || q['status'] == 'Quotes in') && !locked(no)}, 'cs': csBrief(no)});
      case 'csGet':
        return _j(csGet(b['rfq'] as int));
      case 'csDecide':
        final c = purCs.values.firstWhere((x) => x['no'] == b['no']);
        if (c['version'] != b['version']) return _j({'error': 'It was changed by someone else just now – it is loaded again: look and save once more.', 'code': 'changed'}, 409);
        c['status'] = {'approve': 'Approved', 'back': 'Sent back', 'reject': 'Rejected'}[b['act']];
        c['decided_name'] = 'Sujit Mule';
        c['decided_at'] = '2026-10-14T08:00:00Z';
        c['version'] = (c['version'] as int) + 1;
        (c['trail'] as List).add({'at': '2026-10-14T08:00:00Z', 'by': 'sujit@rcl.test', 'name': 'Sujit Mule', 'act': c['status'], 'why': b['why'], 'total': c['total']});
        return _j({...csGet(c['rfq_no'] as int), 'saved': true});
      case 'csList':
        return _j({'ok': true, 'list': [
          for (final c in purCs.values)
            if (admin && c['status'] == 'Sent')
              {'no': c['no'], 'ref': csRef(c['no']), 'rfq_no': c['rfq_no'], 'rfq_ref': ref(c['rfq_no']), 'site': c['site'], 'status': c['status'], 'total': c['total'], 'gst': c['gst'], 'items': (rfqOf(c['rfq_no'])!['lines'] as List).map((l) => l['name']).join(', '), 'sent_name': c['sent_name'], 'sent_at': c['sent_at']},
        ]});
      // (3.95.0, Purchase Phase 2) the POs
      case 'poNew':
        final two = b['vendor'] == 2;
        return _j({'ok': true, 'cs': {'no': 1, 'ref': 'CS-0001', 'approved_name': 'Sujit Mule', 'approved_at': '2026-10-14T08:00:00Z'}, 'rfq': {'no': 1, 'ref': 'RFQ-0001'}, 'site': 'S1', 'site_name': 'VTR Site – NH 848',
          'vendor': {...purVendors.firstWhere((v) => v['id'] == b['vendor'])}, 'papers_error': '',
          'money': {'vendor': b['vendor'], 'site': 'S1', 'freight': two ? 1000 : 500, 'loading': 0, 'missing': two ? [2] : [], 'pay_terms': two ? 'Advance' : '30 days',
            'lines': [two
                ? {'line': 1, 'cs_line': 2, 'site': 'S1', 'req_no': 7, 'req_line': 3, 'ref': 'IND-0007', 'code': 'ITM-0004', 'name': 'TMT bar 12 mm', 'unit': 'MT', 'qty': 2, 'rate': 55000, 'disc_pct': 0, 'gst_pct': null, 'gst_quoted': false, 'landed': 55500, 'brand': '', 'spec': 'Fe 500D'}
                : {'line': 1, 'cs_line': 1, 'site': 'S1', 'req_no': 7, 'req_line': 1, 'ref': 'IND-0007', 'code': 'ITM-0001', 'name': 'Cement OPC 53', 'unit': 'Bag', 'qty': 50, 'rate': 380, 'disc_pct': 0, 'gst_pct': 28, 'gst_quoted': true, 'landed': 390, 'brand': 'UltraTech', 'spec': ''}]},
          'start': {'date': '2026-10-14', 'need_by': '2026-10-20', 'pay_terms': two ? 'Advance' : '30 days', 'ship_to': 'VTR site office, Bhiwandi', 'site_contact': 'Site office: 9000000000', 'terms': '1. Delivery: as agreed'}});
      case 'poMake':
        final two = b['vendor'] == 2, g = num.tryParse('${(b['gst'] as Map?)?['2'] ?? ''}');
        if (two && g == null) return _j({'error': 'Enter the GST % of TMT bar 12 mm.', 'code': 'field'}, 400);
        final po = <String, dynamic>{'no': purPos.length + 1, 'rev': 1, 'site': 'S1', 'cs_no': 1, 'rfq_no': 1, 'vendor_id': b['vendor'], 'vendor': {'name': purVendors.firstWhere((v) => v['id'] == b['vendor'])['name'], 'gstin': '', 'phone': '9822012345', 'address': ''},
          'date': b['date'], 'need_by': b['need_by'], 'pay_terms': b['pay_terms'], 'ship_to': b['ship_to'], 'site_contact': b['site_contact'], 'terms': b['terms'], 'remark': b['remark'], 'status': 'Open', 'status_note': '', 'ver': 1, 'created_name': 'Sujit Mule',
          'lines': [{'line': 1, 'site': 'S1', 'req_no': 7, 'req_line': 3, 'ref': 'IND-0007', 'name': 'TMT bar 12 mm', 'unit': 'MT', 'qty': 2, 'rate': 55000, 'disc_pct': 0, 'gst_pct': g ?? 18, 'taxable': 110000, 'gst': 19800, 'total': 129800, 'brand': '', 'spec': 'Fe 500D'}],
          'freight': 1000, 'loading': 0, 'taxable': 110000, 'gst': 19800, 'total': 130800};
        purPos.add(po);
        return _j({...poGet(po), 'saved': true, 'sent': true, 'send_error': ''});
      case 'poGet':
        return _j(poGet(purPos.firstWhere((p) => p['no'] == b['no'])));
      case 'poList':
        return _j({'ok': true, 'store': {'ok': true}, 'pos': [
          for (final p in purPos.reversed)
            {'no': p['no'], 'ref': 'PO-${'${p['no']}'.padLeft(4, '0')}', 'rev': 1, 'site': 'S1', 'date': p['date'], 'need_by': p['need_by'], 'vendor': (p['vendor'] as Map)['name'], 'vendor_id': p['vendor_id'], 'items': 'TMT bar 12 mm', 'nlines': 1, 'total': p['total'],
              'cs_no': 1, 'cs_ref': 'CS-0001', 'status': p['status'], 'state': p['status'] == 'Cancelled' ? 'Cancelled' : 'At the site', 'store_no': 21, 'grns': 0, 'send_error': ''},
        ]});
      case 'poCancel':
        final p = purPos.firstWhere((x) => x['no'] == b['no']);
        if ('${b['why']}'.trim().length < 3) return _j({'error': 'Write why it is cancelled.', 'code': 'field'}, 400);
        p['status'] = 'Cancelled';
        p['status_note'] = b['why'];
        p['cancelled_name'] = 'Sujit Mule';
        p['cancelled_at'] = '2026-10-14T09:00:00Z';
        return _j({...poGet(p), 'saved': true});
      case 'vendorList':
        return _j({'ok': true, 'vendors': purVendors, 'mayStatus': admin});
      case 'vendorSave':
        if ('${b['name']}'.trim().length < 2) return _j({'error': 'Enter the supplier\'s name.', 'code': 'field'}, 400);
        final v = <String, dynamic>{'id': purVendors.length + 1, 'name': b['name'], 'gstin': b['gstin'], 'pan': b['pan'], 'address': b['address'], 'phone': b['phone'], 'email': b['email'],
          'supplies': [for (final t in '${b['supplies']}'.split(',')) if (t.trim().isNotEmpty) t.trim()], 'status': 'Approved', 'status_note': '', 'ver': 1, 'wa': '91${b['phone']}'};
        purVendors.add(v);
        return _j({'ok': true, 'saved': true, 'vendor': v});
      case 'vendorStatus':
        final v = purVendors.firstWhere((x) => x['id'] == b['id']);
        v['status'] = b['status'];
        v['status_note'] = b['status'] == 'Blocked' ? b['why'] : '';
        v['ver'] = (v['ver'] as int) + 1;
        return _j({'ok': true, 'saved': true, 'vendor': v});
      case 'settings':
      case 'settingsSave':
        if (b['action'] == 'settingsSave') {
          if (!sup) return _j({'error': 'Only the Super Admin sets the CS limit.', 'code': 'access'}, 403);
          purLimit = num.parse('${b['limit']}'.replaceAll(',', ''));
        }
        return _j({'ok': true, 'limit': purLimit, 'by': 'sujit@rcl.test', 'at': '2026-10-14T08:00:00Z', 'maySet': sup});
    }
    return _j({'error': 'Unknown action.', 'code': 'action'}, 404);
  }

  /// (3.100.0) the Advertise Corner: what the Portal gives ('live'), and what was asked
  List<Map<String, dynamic>> ads = [];
  final List<Map<String, dynamic>> adsAsked = [];
  http.Response _j(Object o, [int code = 200, Map<String, String> h = const {}]) => http.Response(jsonEncode(o), code, headers: {'content-type': 'application/json', ...h});

  /* ---- (3.17.0) the Portal's Super Admin console (api/admin): its data and its checks, as the Portal's (the same words) ---- */
  final portalAdminSent = <Map<String, dynamic>>[];
  final saUsers = <Map<String, dynamic>>[
    {'email': 'sujit@rcl.test', 'name': 'Sujit Mule', 'active': true, 'super': true, 'mustChange': false, 'noPassword': false},
    {'email': 'amol@rcl.test', 'name': 'Amol Patil', 'active': true, 'super': false, 'mustChange': false, 'noPassword': false},
    {'email': 'ravi@rcl.test', 'name': 'Ravi Shinde', 'active': false, 'super': false, 'mustChange': true, 'noPassword': false},
  ];
  final saSites = <Map<String, dynamic>>[
    {'code': 'S1', 'name': 'VTR Site – NH 848', 'company_id': 'RACHANA', 'status': 'active', 'sort': 1},
    {'code': 'T2', 'name': '18B Kolhapur', 'company_id': 'RACHANA', 'status': 'active', 'sort': 2},
    {'code': 'K7', 'name': 'Karad Bypass', 'company_id': null, 'status': 'closed', 'sort': 3},
  ];
  final saModules = <Map<String, dynamic>>[
    {'key': 'mechanical', 'name': 'Mechanical', 'url': 'https://erp.test', 'status': 'live', 'sort': 1},
    {'key': 'store', 'name': 'Store', 'url': 'https://erp.test/store', 'status': 'live', 'sort': 2},
    {'key': 'hr', 'name': 'HR', 'url': null, 'status': 'off', 'sort': 3},
  ];
  final saCompanies = <Map<String, dynamic>>[
    {'id': 'RACHANA', 'name': 'Rachana Construction', 'address': 'Nashik', 'gstin': '27ABCDE1234F1Z5', 'pan': 'ABCDE1234F', 'logo': ''},
    {'id': 'SKETCHLINE', 'name': 'Sketchline', 'address': '', 'gstin': '', 'pan': '', 'logo': ''},
  ];
  final saAccess = <Map<String, dynamic>>[
    {'email': 'amol@rcl.test', 'site': 'S1', 'module': 'mechanical', 'role': 'user', 'pages': null},
    {'email': 'amol@rcl.test', 'site': 'S1', 'module': 'store', 'role': 'user', 'pages': {'dashboard': 'View', 'items': 'View'}},
    {'email': 'ravi@rcl.test', 'site': 'S1', 'module': 'mechanical', 'role': 'admin', 'pages': null},
  ];
  final saAudit = <Map<String, dynamic>>[
    {'at': '2026-10-16T13:35:12Z', 'actor': 'sujit@rcl.test', 'action': 'Access', 'target': 'amol@rcl.test', 'detail': {'site': 'S1', 'module': 'store', 'role': 'user'}},
    {'at': '2026-10-16T09:02:00Z', 'actor': 'amol@rcl.test', 'action': 'Signed in', 'target': '', 'detail': null},
  ];
  final mechUserPerms = <String, Map<String, String>>{'amol@rcl.test': {'diesel': 'Edit', 'log': 'View'}};
  static const mechPageList = [
    {'key': 'diesel', 'label': 'Diesel Issue', 'dateAdmin': true}, // (3.64.0) a page with a date: Admin offered
    {'key': 'log', 'label': 'Log Book'},
    {'key': 'reports', 'label': 'Reports'},
  ];
  List<Map<String, dynamic>> sitePlaces = [
    {'name': 'Camp Pump', 'cap': 18000, 'used': true, 'stock': 12450.5},
    {'name': 'MH12ZE1739', 'cap': 2650, 'used': false, 'stock': 800},
  ];
  final saHo = <String, Map<String, bool>>{}; // (3.71.0) the sites' workflow Head Office choices
  bool portalStep6 = true;
  bool siteKey = false, siteTables = false; // the New site checklist: the key in Vercel, Mechanical's tables run
  static const kStorePages = [
    {'key': 'dashboard', 'label': 'Dashboard', 'opts': ['View', 'None']},
    {'key': 'items', 'label': 'Item Master', 'opts': ['Edit', 'View', 'None']},
    {'key': 'req', 'label': 'Material Requirements', 'opts': ['None', 'View', 'Edit']},
    // (3.71.0, the Portal with the Store's workflow) who verifies each work and who approves the GRN / the issues
    {'key': 'vreq', 'label': 'Verifies requirements', 'opts': ['None', 'Yes'], 'admin': true},
    {'key': 'approve', 'label': 'Approves requirements', 'opts': ['None', 'L1', 'L2', 'L3', 'L4', 'L5'], 'admin': true},
    {'key': 'purchase', 'label': 'Store Purchase – every site (HO)', 'opts': ['None', 'Edit'], 'admin': true},
    {'key': 'vpo', 'label': 'Verifies purchase orders', 'opts': ['None', 'Yes'], 'admin': true},
    // (3.62.0, the Portal with the Store's step 5) who approves the site's purchase orders
    {'key': 'poapprove', 'label': 'Approves purchase orders', 'opts': ['None', 'Yes'], 'admin': true},
    {'key': 'vgrn', 'label': 'Verifies GRN (Inward)', 'opts': ['None', 'Yes'], 'admin': true},
    {'key': 'agrn', 'label': 'Approves GRN (Inward)', 'opts': ['None', 'Yes'], 'admin': true},
    {'key': 'viss', 'label': 'Verifies issues & returns', 'opts': ['None', 'Yes'], 'admin': true},
    {'key': 'aiss', 'label': 'Approves issues & returns', 'opts': ['None', 'Yes'], 'admin': true},
  ];

  http.Response _no(String msg, [int code = 400, String c = '']) => _j({'error': msg, if (c.isNotEmpty) 'code': c}, code);

  http.Response _admin(String a, Map<String, dynamic> x) {
    Map<String, dynamic>? user(String e) => saUsers.where((u) => u['email'] == e).firstOrNull;
    Map<String, dynamic>? acc(String e, String site, String m) => saAccess.where((y) => y['email'] == e && y['site'] == site && y['module'] == m).firstOrNull;
    bool siteOk(String c) => saSites.any((y) => y['code'] == c);
    void log(String what, String target, [Object? detail]) => saAudit.insert(0, {'at': '2026-10-17T10:00:00Z', 'actor': 'sujit@rcl.test', 'action': what, 'target': target, 'detail': detail});
    final email = '${x['email'] ?? ''}'.trim().toLowerCase(), site = '${x['site'] ?? ''}'.toUpperCase();
    switch (a) {
      case 'overview':
        {
          // (3.71.0) each site with its workflow's Head Office choices (the Portal's step 6)
          return _j({'users': saUsers, 'sites': [for (final y in saSites) {...y, 'ho': saHo[y['code']] ?? const {'req': true, 'grn': false, 'iss': false}, 'step6': portalStep6}], 'modules': saModules, 'companies': saCompanies, 'access': saAccess, 'storePages': kStorePages});
        }
      case 'userSave':
        {
          if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) return _no('Enter a proper email.');
          final cur = user(email), temp = '${x['newPassword'] ?? ''}', name = '${x['name'] ?? ''}'.trim();
          if (cur != null && cur['super'] == true) return _no('The Super Admin changes his own account under "My account".');
          if (temp.isNotEmpty && temp.length < 6) return _no('Give a one-time password of at least 6 characters – the user must change it at the first sign-in.');
          if (x['isNew'] == true) {
            if (cur != null) return _no('$email is already a user.', 409);
            if (temp.isEmpty) return _no('Give a one-time password of at least 6 characters – the user must change it at the first sign-in.');
            if (name.length < 2) return _no('Enter the name of the user (2 to 80 letters).');
            saUsers.add({'email': email, 'name': name, 'active': x['active'] != false, 'super': false, 'mustChange': true, 'noPassword': false});
            log('User added', email, {'name': name});
            return _j({'ok': true, 'added': true});
          }
          if (cur == null) return _no('User $email was not found.', 404);
          if (name.isNotEmpty) cur['name'] = name;
          if (x['active'] is bool) cur['active'] = x['active'];
          if (temp.isNotEmpty) cur['mustChange'] = true;
          return _j({'ok': true, 'changed': true});
        }
      case 'accessSet':
        {
          final u = user(email), role = '${x['role'] ?? ''}', m = '${x['module'] ?? ''}';
          if (u == null) return _no('User $email was not found.', 404);
          if (!siteOk(site)) return _no('This site is not in the list.', 404);
          if (role.isNotEmpty && !['admin', 'user'].contains(role)) return _no('Choose Admin, User or No access.');
          saAccess.removeWhere((y) => y['email'] == email && y['site'] == site && y['module'] == m);
          if (role.isNotEmpty) saAccess.add({'email': email, 'site': site, 'module': m, 'role': role, 'pages': null});
          log('Access', email, {'site': site, 'module': m, 'role': role.isEmpty ? 'none' : role});
          return _j({'ok': true});
        }
      case 'mechPages':
        {
          if (!siteOk(site)) return _no('Pick a site.');
          return _j({'site': site, 'pages': mechPageList, 'users': [for (final e in mechUserPerms.entries) {'email': e.key, 'perms': e.value}]});
        }
      case 'mechPagesSave':
        {
          final y = acc(email, site, 'mechanical');
          if (y == null) return _no('First give him Mechanical on this site (Admin or User), then his pages.', 400, 'noaccess');
          final given = (x['perms'] as Map).map((k, v) => MapEntry('$k', '$v')), was = mechUserPerms[email] ?? {};
          final ch = [for (final e in given.entries) if (was[e.key] != e.value) e.key];
          mechUserPerms[email] = given;
          return _j({'ok': true, 'added': was.isEmpty, 'changes': ch.join(', ')});
        }
      case 'rulesSave':
        {
          // (3.71.0, as the Portal's) what goes to Head Office once approved – needs the Portal's step 6
          if (!siteOk(site)) return _no('This site is not in the list.', 404);
          if (!portalStep6) return _no('The Head Office choices of the workflow need the Portal\'s database step 6 first: run sql/portal_step6_rules.sql once in the Portal\'s Supabase → SQL Editor, then save them again.', 400, 'nostep');
          final g = (x['ho'] as Map?) ?? const {}, ho = <String, bool>{};
          for (final k in const ['req', 'grn', 'iss']) {
            if (g[k] is! bool) return _no('Choose Yes or No for each work.', 400, 'field');
            ho[k] = g[k] as bool;
          }
          saHo[site] = ho;
          log('Workflow', '$site · store', {'headOffice': ho.entries.map((e) => '${e.key}: ${e.value ? 'Yes' : 'No'}').join(', ')});
          return _j({'ok': true, 'ho': ho});
        }
      case 'storePagesSave':
        {
          final y = acc(email, site, 'store');
          if (y == null) return _no('First give him the Store on this site (Admin or User), then his pages.', 400, 'noaccess');
          // (3.55.0, as the Portal with the Store's step 2) a Store Admin: only who approves and Store Purchase
          final pg = ((x['pages'] as Map?) ?? const {}).cast<String, dynamic>();
          y['pages'] = y['role'] == 'admin' ? {for (final p in kStorePages) if (p['admin'] == true && pg.containsKey(p['key'])) '${p['key']}': pg[p['key']]} : pg;
          return _j({'ok': true, 'pages': y['pages']});
        }
      // (3.76.0, Mechanical update-203) Sites → Day & tank check
      case 'siteRulesGet':
        {
          if (!siteOk(site)) return _no('Pick a site.');
          return _j({'site': site, ...siteRules});
        }
      case 'siteRulesSave':
        {
          if (!siteOk(site)) return _no('Pick a site.');
          if (!RegExp(r'^([01][0-9]|2[0-3]):[0-5][0-9]$').hasMatch('${x['dayStart'] ?? ''}')) return _no('Day starts at: type the hour as HH:MM (for example 06:00).');
          final t = (x['tank'] as Map?) ?? const {}, g = (t['groups'] as Map?) ?? const {};
          final on = ['Own', 'Rental', 'Hired'].any((k) => '${g[k] ?? ''}'.isNotEmpty) || (t['machines'] as List? ?? const []).any((m) => m is Map && m['on'] != false);
          siteRules = {
            'dayStart': x['dayStart'],
            'tank': {'since': on ? '2026-10-14' : '', 'groups': {for (final k in ['Own', 'Rental', 'Hired']) k: num.tryParse('${g[k] ?? ''}') ?? ''}, 'machines': [for (final m in (t['machines'] as List? ?? const [])) if (m is Map) {'no': m['no'], 'on': m['on'] != false, 'days': num.tryParse('${m['days'] ?? ''}') ?? ''}]},
            'machines': siteRules['machines'],
          };
          return _j({'ok': true, 'site': site, ...siteRules});
        }
      case 'placesGet':
        {
          if (!siteOk(site)) return _no('Pick a site.');
          return _j({'site': site, 'places': sitePlaces, 'set': true, 'entries': true, 'firstFixed': true});
        }
      case 'placesSave':
        {
          final l = [for (final p in (x['places'] as List? ?? const [])) if (p is Map) {'name': '${p['name'] ?? ''}', 'cap': p['cap'] ?? 0}];
          if (l.isEmpty) return _no('Add at least one diesel place (its name and tank size).');
          sitePlaces = [for (final p in l) {...p, 'used': p['name'] == 'Camp Pump', 'stock': p['name'] == 'Camp Pump' ? 12450.5 : 0}];
          return _j({'ok': true, 'site': site, 'places': sitePlaces, 'set': true, 'entries': true, 'firstFixed': true});
        }
      case 'siteSave':
        {
          final cur = saSites.where((y) => y['code'] == '${x['code']}'.toUpperCase()).firstOrNull;
          if ('${x['name'] ?? ''}'.trim().length < 2) return _no('Give the site a name (2 to 80 letters).');
          if (cur == null) return _no('This site is not in the list.', 404);
          cur['name'] = '${x['name']}'.trim();
          cur['company_id'] = '${x['company'] ?? ''}'.isEmpty ? null : x['company'];
          cur['status'] = x['status'];
          for (final k in ['address', 'contact_name', 'contact_phone']) {
            if (x.containsKey(k)) cur[k] = '${x[k] ?? ''}'.trim(); // (3.70.0) the site's address and contact
          }
          return _j({'ok': true});
        }
      case 'siteSetup':
        {
          final code = '${x['code'] ?? ''}'.trim().toUpperCase(), url = '${x['url'] ?? ''}'.trim();
          if (!RegExp(r'^[A-Z0-9]{1,12}$').hasMatch(code)) return _no('The site code: 1 to 12 capital letters or digits (e.g. VTR, 18B).');
          if ('${x['name'] ?? ''}'.trim().length < 2) return _no('Give the site a name (2 to 80 letters).');
          if (!siteOk(code)) saSites.add({'code': code, 'name': '${x['name']}'.trim(), 'company_id': '${x['company'] ?? ''}'.isEmpty ? null : x['company'], 'status': 'closed', 'sort': saSites.length + 1});
          final steps = <Map<String, dynamic>>[];
          Map<String, dynamic> out([Map<String, dynamic> more = const {}]) => {'site': code, 'keyName': 'SITE_${code}_KEY', 'steps': steps, 'ready': false, ...more};
          const ref = 'abcdefghijklmnopqrst';
          if (!RegExp(r'^https://[a-z0-9]{20}\.supabase\.co$').hasMatch(url)) {
            steps.add({'step': 'link', 'ok': false, 'note': 'The link must be the project\'s address, like https://abcdefghijklmnopqrst.supabase.co (Supabase → the project → Connect).'});
            return _j(out());
          }
          steps.add({'step': 'link', 'ok': true, 'note': ''});
          final links = {'sqlLink': 'https://supabase.com/dashboard/project/$ref/sql/new', 'keysLink': 'https://supabase.com/dashboard/project/$ref/settings/api-keys'};
          steps.add({'step': 'key', 'ok': siteKey, 'note': 'Vercel → …'});
          if (!siteKey) return _j(out(links));
          steps.add({'step': 'connect', 'ok': true, 'note': ''});
          steps.add({'step': 'tables', 'ok': siteTables, 'note': siteTables ? '' : 'Not there yet: rcl_diesel_issue · rcl_log_book'});
          if (!siteTables) return _j(out({'sqlLink': links['sqlLink']}));
          steps.add({'step': 'company', 'ok': true, 'note': ''});
          steps.add({'step': 'places', 'ok': true, 'note': '2 diesel places set'});
          steps.add({'step': 'ready', 'ok': true, 'note': ''});
          saSites.firstWhere((y) => y['code'] == code)['status'] = 'active';
          return _j(out({'ready': true, 'backupEmail': 'backup@rcl-erp.iam.test'}));
        }
      case 'siteSql':
        {
          return _j({'sql': '-- Mechanical\n${'create table x (id int);\n' * 200}', 'files': ['supabase_step1.sql']});
        }
      case 'siteDelete':
        {
          final code = '${x['code'] ?? ''}'.toUpperCase(), cur = saSites.where((y) => y['code'] == code).firstOrNull;
          if (cur == null) return _no('This site is not in the list.', 404);
          if (cur['status'] != 'closed') return _no('First set the site to Closed and Save – then delete it.', 400, 'notclosed');
          if ('${x['confirm'] ?? ''}'.trim().toUpperCase() != code) return _no('Type the site code ($code) to delete it.', 400, 'confirm');
          final n = saAccess.where((y) => y['site'] == code).length;
          saAccess.removeWhere((y) => y['site'] == code);
          saSites.remove(cur);
          return _j({'ok': true, 'accessRemoved': n});
        }
      case 'companySave':
        {
          final name = '${x['name'] ?? ''}'.trim(), gstin = '${x['gstin'] ?? ''}'.trim().toUpperCase(), id = '${x['id'] ?? ''}';
          if (name.length < 2) return _no('Enter the name of the company (2 to 80 letters).');
          if (gstin.isNotEmpty && !RegExp(r'^\d{2}[A-Z]{5}\d{4}[A-Z][A-Z\d]Z[A-Z\d]$').hasMatch(gstin)) return _no('GST Number "$gstin" is not in the right format (15 characters, e.g. 27ABCDE1234F1Z5).');
          final row = {'name': name, 'gstin': gstin, 'pan': '${x['pan'] ?? ''}'.toUpperCase(), 'address': '${x['address'] ?? ''}', 'logo': '${x['logo'] ?? ''}'};
          if (id.isNotEmpty) {
            saCompanies.firstWhere((c) => c['id'] == id).addAll(row);
            return _j({'ok': true, 'id': id});
          }
          final nid = name.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]+'), '');
          saCompanies.add({'id': nid, ...row});
          return _j({'ok': true, 'id': nid});
        }
      case 'companyDelete':
        {
          final used = saSites.where((y) => y['company_id'] == x['id']).map((y) => y['code']).toList();
          if (used.isNotEmpty) return _no('Sites of this company: ${used.join(', ')} – give them another company first (Sites), then delete it.', 400, 'inuse');
          saCompanies.removeWhere((c) => c['id'] == x['id']);
          return _j({'ok': true});
        }
      case 'moduleSave':
        {
          final key = '${x['key'] ?? ''}', url = '${x['url'] ?? ''}', status = '${x['status'] ?? 'off'}';
          if (!RegExp(r'^[a-z]{2,20}$').hasMatch(key)) return _no('The module key: 2 to 20 small letters (e.g. store).');
          if (status == 'live' && url.isEmpty) return _no('A module can be Live only with its link.');
          final cur = saModules.where((m) => m['key'] == key).firstOrNull;
          if (x['isNew'] == true) {
            if (cur != null) return _no('This module is already there.', 409);
            saModules.add({'key': key, 'name': '${x['name']}'.trim(), 'url': url.isEmpty ? null : url, 'status': status, 'sort': saModules.length + 1});
          } else {
            final m = cur!;
            m['url'] = url.isEmpty ? null : url;
            m['status'] = status;
            if ('${x['name'] ?? ''}'.trim().isNotEmpty) m['name'] = '${x['name']}'.trim();
          }
          return _j({'ok': true});
        }
      case 'moduleDelete':
        {
          final key = '${x['key'] ?? ''}', m = saModules.where((y) => y['key'] == key).firstOrNull;
          if (m == null) return _no('This module is not in the list.', 404);
          if (key == 'mechanical') return _no('Mechanical cannot be deleted – the sites and the pages are set up through it. Set it Off instead.', 400, 'mech');
          if (m['status'] != 'off') return _no('First set the module Off and Save – then delete it.', 400, 'notoff');
          if ('${x['confirm'] ?? ''}'.trim().toLowerCase() != key) return _no('Type the module key ($key) to delete it.', 400, 'confirm');
          final n = saAccess.where((y) => y['module'] == key).length;
          saAccess.removeWhere((y) => y['module'] == key);
          saModules.remove(m);
          return _j({'ok': true, 'accessRemoved': n});
        }
      case 'audit':
        {
          return _j({'rows': saAudit});
        }
    }
    return _no('Unknown action.', 404);
  }

  late final client = MockClient((r) async {
    final path = r.url.path;
    if (down && path.endsWith('/api/rpc')) throw http.ClientException('no network');
    if (portalDown && path.contains('/portal/')) throw http.ClientException('no network');
    if (portalStatus > 0 && path.contains('/portal/')) return http.Response('<html>Service Unavailable</html>', portalStatus);
    if (path.endsWith('/portal/api/auth')) {
      final b = jsonDecode(r.body) as Map;
      calls.add('portal:${b['action']}');
      if (r.headers['X-RCL'] != '1') return _j({'error': 'Refused'}, 403);
      if (b['action'] == 'login') {
        if (b['password'] != 'Nashik#Road848!') return _j({'error': 'Email or password is wrong.', 'code': 'wrong'}, 401);
        portalSignedIn = true;
        return _j({'user': {'email': b['email'], 'name': 'Sujit Mule', 'super': superAdmin}, 'mustChange': mustChange}, 200, {'set-cookie': 'rcl_portal=abc123; Path=/; HttpOnly; Secure; SameSite=Lax'});
      }
      if (b['action'] == 'me') {
        if (!portalSignedIn || r.headers['Cookie'] != 'rcl_portal=abc123') return _j({'signedIn': false});
        // (as the Portal: still on a given password – no module until his own is set)
        if (mustChange) return _j({'signedIn': true, 'mustChange': true, 'user': {'email': 'sujit@rcl.test', 'name': 'Sujit Mule'}, 'items': []});
        if (hrOnlyUser) {
          return _j({'signedIn': true, 'start': '', 'user': {'email': 'sujit@rcl.test', 'name': 'Sujit Mule'}, if (mailInfo != null) 'email': mailInfo, 'items': [
            {'site': 'S1', 'siteName': 'VTR Site – NH 848', 'company': 'RCL', 'module': 'hrme', 'moduleName': 'My HR', 'url': 'https://erp.test/hr'},
          ]});
        }
        return _j({'signedIn': true, 'start': start, 'user': {'email': 'sujit@rcl.test', 'name': 'Sujit Mule', 'super': superAdmin, if (tester) 'tester': true}, if (mailInfo != null) 'email': mailInfo, 'items': [
          {'site': 'S1', 'siteName': 'VTR Site – NH 848', 'company': 'RCL', 'module': 'mechanical', 'moduleName': 'Mechanical', 'url': 'https://erp.test'},
          {'site': 'S1', 'siteName': 'VTR Site – NH 848', 'company': 'RCL', 'module': 'store', 'moduleName': 'Store', 'url': 'https://erp.test/store'},
          if (engSite) {'site': 'S1', 'siteName': 'VTR Site – NH 848', 'company': 'RCL', 'module': 'engineering', 'moduleName': 'Engineering', 'url': 'https://erp.test/engineering'},      // (3.59.0)
          if (purSite) {'site': 'S1', 'siteName': 'VTR Site – NH 848', 'company': 'RCL', 'module': 'purchase', 'moduleName': 'Purchase', 'url': 'https://erp.test/purchase'},      // (3.72.0)
          if (hrSite) {'site': 'S1', 'siteName': 'VTR Site – NH 848', 'company': 'RCL', 'module': hrKey, 'moduleName': hrKey == 'hr' ? 'RCL HR' : 'My HR', 'url': 'https://erp.test/hr'},      // (3.103.0)
          {'site': 'T2', 'siteName': '18B Kolhapur', 'company': 'RCL', 'module': 'mechanical', 'moduleName': 'Mechanical', 'url': 'https://erp.test'},
          {'site': 'X9', 'siteName': 'Bad', 'company': '', 'module': 'mechanical', 'moduleName': 'Mechanical', 'url': 'javascript:alert(1)'},
          {'site': 'Z5', 'siteName': 'Store only', 'company': '', 'module': 'store', 'moduleName': 'Store', 'url': 'https://erp.test/store'},
        ]});
      }
      if (b['action'] == 'setStart') {
        start = b['module'] == '' ? '' : '${b['module']}|${b['site']}';
        return _j({'ok': true, 'start': start});
      }
      if (b['action'] == 'changePassword') {
        if (!portalSignedIn) return _j({'error': 'Please sign in.', 'code': 'signin'}, 401);
        if (b['old'] != 'Nashik#Road848!') return _j({'error': 'Current password is wrong.', 'code': 'oldpw'}, 400);
        final pw = (b['password'] ?? '').toString();
        if (pw.length < 8 || !RegExp(r'[A-Za-z]').hasMatch(pw) || !RegExp(r'[0-9]').hasMatch(pw)) {
          return _j({'error': 'The password must have at least 8 characters, with letters and numbers.', 'code': 'policy'}, 400);
        }
        mustChange = false;
        newPassword = pw;
        return _j({'ok': true}, 200, {'set-cookie': 'rcl_portal=abc123; Path=/; HttpOnly; Secure; SameSite=Lax'});      // (a fresh sign-in)
      }
      // (3.104.0) the Portal's steps 10 / 11: a code by e-mail, "verify my e-mail", the reminder
      if (b['action'] == 'options') return _j({'otp': otpOn});
      if (b['action'] == 'otpSend') {
        if (!otpOn) return _j({'error': 'Sign-in with a code is not switched on.', 'code': 'off'}, 403);
        if (b['email'] == otpMail) codesTo.add('${b['email']}');      // (a code only to a verified user's e-mail – the answer is the same)
        return _j({'ok': true, 'wait': 60, 'minutes': 10});
      }
      if (b['action'] == 'otpLogin') {
        if (b['email'] != otpMail || b['code'] != otpCode) return _j({'error': 'The code is wrong or has expired.', 'code': 'code'}, 401);
        portalSignedIn = true;
        return _j({'user': {'email': 'sujit@rcl.test', 'name': 'Sujit Mule', 'super': false}, 'mustChange': false}, 200, {'set-cookie': 'rcl_portal=abc123; Path=/; HttpOnly; Secure; SameSite=Lax'});
      }
      if (b['action'] == 'verifySend') {
        if (!portalSignedIn) return _j({'error': 'Please sign in.', 'code': 'signin'}, 401);
        final to = '${b['email'] ?? ''}'.trim().toLowerCase();
        if (to == 'taken@rcl.test') return _j({'error': 'This e-mail is already another user\'s. Type your own.', 'code': 'taken'}, 409);
        verifyTo = to;
        codesTo.add(to);
        return _j({'ok': true, 'email': to, 'wait': 60, 'minutes': 10});
      }
      if (b['action'] == 'verifyCheck') {
        if (b['code'] != otpCode || verifyTo.isEmpty) return _j({'error': 'The code is wrong or has expired.', 'code': 'code'}, 400);
        mailInfo = {'verified': true, 'canVerify': true, 'remind': true, 'login': verifyTo};
        otpMail = verifyTo;
        return _j({'ok': true, 'verified': true, 'login': verifyTo});
      }
      if (b['action'] == 'emailAlert') {
        final m = mailInfo;
        if (m == null || m['verified'] == true || m['remind'] != true) return _j({'show': false});
        alerts++;
        return _j({'show': true, 'verified': false, 'alerts': alerts, 'canVerify': m['canVerify'] == true});
      }
      if (b['action'] == 'logout') {
        portalSignedIn = false;
        return _j({'ok': true}, 200, {'set-cookie': 'rcl_portal=; Path=/; Max-Age=0'});
      }
    }
    // (3.100.0) the Advertise Corner: the posts that show now on a site
    if (path.endsWith('/portal/api/ads')) {
      final x = (jsonDecode(r.body) as Map).cast<String, dynamic>();
      adsAsked.add(x);
      if (r.headers['X-RCL'] != '1') return _j({'error': 'Refused'}, 403);
      return _j({'posts': ads});
    }
    // (3.17.0) the Portal's Super Admin console: only the Super Admin, signed in (his own password set)
    if (path.endsWith('/portal/api/admin')) {
      final x = (jsonDecode(r.body) as Map).cast<String, dynamic>();
      portalAdminSent.add(x);
      calls.add('admin:${x['action']}');
      if (r.headers['X-RCL'] != '1') return _j({'error': 'Refused'}, 403);
      if (!portalSignedIn || r.headers['Cookie'] != 'rcl_portal=abc123') return _j({'error': 'SESSION_EXPIRED', 'code': 'session'}, 401);
      if (!superAdmin) return _j({'error': 'Only the Super Admin can do this.', 'code': 'forbidden'}, 403);
      return _admin('${x['action']}', x);
    }
    if (path.endsWith('/portal/api/go')) {
      final q = r.url.queryParameters;
      calls.add('portal:go:${q['module']}:${q['site']}');
      if (q['json'] != '1' || r.headers['X-RCL'] != '1') return _j({'error': 'Refused'}, 403);
      if (!portalSignedIn) return _j({'error': 'Sign in on the Portal first.', 'code': 'signin'}, 401);
      tickets++;
      return _j({'ticket': 'tk$tickets'});
    }
    // (3.59.0) a kept file from its short link (a vendor's document)
    if (r.url.host == 'files.test') {
      fileGets.add(r.url.toString());
      final f = vendorFiles[r.url.pathSegments.isEmpty ? '' : r.url.pathSegments.last];
      if (f == null) return http.Response('Not Found', 404);
      return http.Response.bytes(f['bytes'] as List<int>, 200, headers: {'content-type': '${f['mime']}'});
    }
    if (r.url.host == 'ifsc.razorpay.com') {
      calls.add('ifsc:${r.url.path}');
      return r.url.path == '/SBIN0001234' ? _j({'BANK': 'State Bank of India', 'BRANCH': 'Nashik Road', 'CITY': 'Nashik', 'STATE': 'Maharashtra'}) : _j('Not Found', 404);
    }
    if (path.endsWith('/store/api/sso')) {
      final b = jsonDecode(r.body) as Map;
      storeSent.add({'fn': 'sso', 'ticket': b['ticket']});
      if (r.headers['X-RCL'] != '1') return _j({'error': 'Refused: this request did not come from the Store page.'}, 403);
      storeSessions++;
      return _j({'ok': true, 'user': {'email': 'sujit@rcl.test', 'name': 'Sujit Mule', 'admin': storeAdmin}, 'pages': storePages, 'site': 'S1', 'siteName': 'VTR Site – NH 848'}, 200,
          {'set-cookie': 'rcl_store=S1.store$storeSessions-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa; Path=/; HttpOnly; SameSite=Lax'});
    }
    if (path.endsWith('/store/api/items')) {
      final b = (jsonDecode(r.body) as Map).cast<String, dynamic>();
      storeSent.add({'cookie': r.headers['Cookie'], ...b});
      if (!'${r.headers['Cookie']}'.startsWith('rcl_store=S1.store')) return _j({'error': 'SESSION_EXPIRED', 'code': 'session'}, 401);
      switch (b['action']) {
        case 'list':
          return _j({'items': storeItems, 'units': ['Nos', 'Kg', 'Ltr', 'Mtr'], 'categories': ['Canteen', 'Spare Parts'], 'admin': true, 'site': 'S1'});
        case 'check':
          final n = '${b['name']}'.trim();
          final near = n.toLowerCase() == 'sugaar' ? [{'code': 'ITM-0002', 'name': 'Sugar', 'unit': 'Kg', 'category': 'Canteen', 'why': 'spelling'}] : [];
          return _j({'proper': {'name': n == 'hydrolic pump' ? 'Hydraulic Pump' : n, 'fixes': n == 'hydrolic pump' ? ['hydrolic → hydraulic'] : []}, 'exact': null, 'similar': near, 'cat': {'category': b['category'], 'near': []}});
        case 'save':
          final it = (b['item'] as Map).cast<String, dynamic>();
          if ('${it['name']}'.toLowerCase() == 'sugaar' && !((b['confirm'] as List?) ?? const []).contains('ITM-0002')) {
            return _j({'error': 'Please confirm: "Sugar" (ITM-0002) is already there – is "Sugaar" a different item?', 'code': 'similar', 'similar': [{'code': 'ITM-0002', 'name': 'Sugar', 'unit': 'Kg', 'category': 'Canteen', 'why': 'spelling'}]}, 409);
          }
          final out = {'code': 'ITM-000${storeItems.length + 1}', 'name': it['name'], 'unit': it['unit'], 'category': it['category'], 'hsn': it['hsn'], 'gst_pct': num.tryParse('${it['gst']}'), 'min_stock': num.tryParse('${it['minStock']}'), 'status': 'Active', 'created_by': 'sujit@rcl.test', 'created_at': '2026-10-14T05:00:00Z'};
          storeItems.add(out);
          return _j({'ok': true, 'item': out});
        case 'remove':
          storeItems.removeWhere((i) => i['code'] == b['code']);
          return _j({'ok': true});
        // (3.13.0) Import from Excel: the report of every row (a name already there left out, "Sugaar" near "Sugar" – confirm)
        case 'import':
          final rows = [for (final r in b['rows'] as List) (r as Map).cast<String, dynamic>()];
          final conf = ((b['confirm'] as Map?) ?? const {}).cast<String, dynamic>();
          final out = [
            for (final r in rows)
              if ('${r['name']}'.isEmpty)
                {'line': r['line'], 'name': r['name'], 'status': 'error', 'msg': 'Item Name is required.'}
              else if (storeItems.any((i) => '${i['name']}'.toLowerCase() == '${r['name']}'.toLowerCase()))
                {'line': r['line'], 'name': r['name'], 'status': 'exists', 'msg': 'Already there.'}
              else if ('${r['name']}'.toLowerCase() == 'sugaar')
                {'line': r['line'], 'name': r['name'], 'status': 'similar', 'similar': [{'code': 'ITM-0002', 'name': 'Sugar'}], 'confirmed': conf.containsKey('${r['line']}')}
              else
                {'line': r['line'], 'name': r['name'], 'status': 'new', 'catNote': ''},
          ];
          final rep = {
            'fresh': out.where((x) => x['status'] == 'new').length,
            'exists': out.where((x) => x['status'] == 'exists').length,
            'similar': out.where((x) => x['status'] == 'similar').length,
            'errors': out.where((x) => x['status'] == 'error').length,
            'rows': out,
          };
          if (b['check'] == true) return _j(rep);
          if (out.any((x) => x['status'] == 'similar' && x['confirmed'] != true)) return _j({'error': 'Confirm the near names first.', 'code': 'similar', 'report': rep}, 409);
          var added = 0;
          for (final x in out) {
            if (x['status'] == 'new' || x['status'] == 'similar') {
              added++;
              storeItems.add({'code': 'ITM-00${10 + added}', 'name': x['name'], 'unit': 'Nos', 'category': 'Spare Parts', 'hsn': '', 'gst_pct': null, 'min_stock': null, 'status': 'Active', 'created_by': 'sujit@rcl.test', 'created_at': '2026-10-14T05:00:00Z'});
            }
          }
          return _j({'ok': true, 'added': added, 'exists': rep['exists']});
      }
      return _j({'error': 'Unknown action.'}, 404);
    }
    if (path.endsWith('/store/api/work')) {
      final b = (jsonDecode(r.body) as Map).cast<String, dynamic>();
      storeWork.add(b);
      if (!'${r.headers['Cookie']}'.startsWith('rcl_store=S1.store')) return _j({'error': 'SESSION_EXPIRED', 'code': 'session'}, 401);
      // (3.59.0, the Store's store-ask) the assistant's look-up of the Store (lib/ailook.js): an unknown item refused in its words
      if (b['action'] == 'aiLook') {
        if ('${(b['args'] as Map?)?['item'] ?? ''}' == 'Unobtainium') return _j({'error': '"Unobtainium" is not an item of this site\'s Store – say which one.'}, 400);
        return _j({'ok': true, 'asOf': '14-10-2026 10:30', 'items': [{'code': 'ITM-0001', 'name': 'Engine Oil 15W40', 'unit': 'Ltr', 'stock': 120}], 'page': 'store'});
      }
      return _work(b);
    }
    // (3.59.0, Mechanical update-185 – rcl-engineering eng-ask) Engineering of the site: its sign-in (a ticket of the Portal) and its
    // look-ups (api/eng aiLook); its sign-in ended once when [engEnded]
    if (path.endsWith('/engineering/api/sso')) {
      final b = jsonDecode(r.body) as Map;
      engSent.add({'fn': 'sso', 'ticket': b['ticket']});
      if (r.headers['X-RCL'] != '1') return _j({'error': 'Refused: this request did not come from the Engineering page.'}, 403);
      engSessions++;
      return _j({'ok': true, 'user': {'email': 'sujit@rcl.test', 'name': 'Sujit Mule', 'role': 'Admin'}, 'site': 'S1', 'siteName': 'VTR Site – NH 848'}, 200, {'set-cookie': 'rcl_eng=S1.eng$engSessions; Path=/; HttpOnly; SameSite=Lax'});
    }
    // (3.103.0) HR: its sign-in (a ticket of the Portal for 'hr' or 'hrme'), its actions, the place of a punch's photo
    // (rcl-hr step 9) the face for attendance: its own endpoint, the same sign-in
    if (path.endsWith('/hr/api/face')) {
      if (!hrNet) throw http.ClientException('no network');
      if (r.headers['X-RCL'] != '1' || !'${r.headers['Cookie']}'.startsWith('rcl_hr=S1.hr')) return _j({'error': 'SESSION_EXPIRED', 'code': 'session'}, 401);
      final b = (jsonDecode(r.body) as Map).cast<String, dynamic>();
      hrFaceSent.add(b);
      switch ('${b['action']}') {
        case 'faceState':
          return _j({'ok': true, 'required': hrFace, 'min': 90, 'enrolled': hrFaceIn, 'poses': ['front', 'left', 'right', 'up', 'down']});
        case 'faceEnrolUrls':
          if (hrFaceIn) return _j({'error': 'Your face is registered already. Only the HR Admin can reset it – then you register again.', 'code': 'enrolled'}, 409);
          return _j({'ok': true, 'token': 'tok1', 'type': 'image/jpeg', 'pictures': [for (final p in ['front', 'left', 'right', 'up', 'down']) {'pose': p, 'url': 'https://photos.test/hr-docs/faces/emp12/tok1-$p.jpg'}]});
        case 'faceEnrol':
          if (hrFacePics.length < 5) return _j({'error': 'Front: the picture did not arrive – take it again.', 'code': 'picture'}, 400);
          hrFaceIn = true;
          return _j({'ok': true, 'enrolled': true});
        case 'faceCheck':
          if (!hrFaceIn) return _j({'error': 'Your face is not registered yet – register it first (once).', 'code': 'notenrolled'}, 409);
          if (!hrPhotos.containsKey('${b['client_id']}')) return _j({'error': 'The photo of this punch did not arrive – take it again.', 'code': 'selfie'}, 400);
          if (!hrFaceOk) return _j({'error': 'Not marked: the face does not match the registered face of Sujit Mule (41 % – at least 90 % is needed). Nothing is saved.', 'code': 'face', 'pct': 41, 'min': 90}, 403);
          hrFaceSeen.add('${b['client_id']}');
          return _j({'ok': true, 'match': true, 'pct': 97, 'min': 90});
      }
      return _j({'error': 'Unknown action.'}, 400);
    }
    if (path.endsWith('/hr/api/sso') || path.endsWith('/hr/api/hr') || r.url.host == 'photos.test') {
      if (!hrNet) throw http.ClientException('no network');
      if (r.url.host == 'photos.test' && r.url.path.startsWith('/hr-docs/faces/')) {
        if (r.method != 'PUT' || r.headers['Content-Type'] != 'image/jpeg') return http.Response('Bad Request', 400);
        hrFacePics.add(r.url.pathSegments.last);
        return http.Response('{}', 200);
      }
      if (r.url.host == 'photos.test' && r.url.path.startsWith('/hr-docs/')) {
        if (r.method != 'PUT' || !const ['image/jpeg', 'image/png', 'image/webp', 'application/pdf'].contains(r.headers['Content-Type'])) return http.Response('Bad Request', 400);
        hrDocFiles[r.url.path.substring(9)] = '${r.headers['Content-Type']}';
        return http.Response('{}', 200);
      }
      if (r.url.host == 'photos.test') {
        if (r.method != 'PUT' || r.headers['Content-Type'] != 'image/jpeg') return http.Response('Bad Request', 400);
        final cid = r.url.pathSegments.last.replaceAll('.jpg', '');
        if (hrPhotos.containsKey(cid)) return http.Response('Duplicate', 409);
        hrPhotos[cid] = r.bodyBytes.length;
        return http.Response('{}', 200);
      }
      if (r.headers['X-RCL'] != '1') return _j({'error': 'Refused: this request did not come from the HR page.'}, 403);
      final b = (jsonDecode(r.body) as Map).cast<String, dynamic>();
      if (path.endsWith('/hr/api/sso')) {
        hrSent.add({'fn': 'sso', 'ticket': b['ticket']});
        return _j({'ok': true, 'user': {'email': 'sujit@rcl.test', 'name': 'Sujit Mule', 'role': hrKey == 'hr' ? 'admin' : 'self'}, 'site': 'S1', 'siteName': 'VTR Site – NH 848'}, 200, {'set-cookie': 'rcl_hr=S1.hr1; Path=/; HttpOnly; SameSite=Lax'});
      }
      hrSent.add({'cookie': r.headers['Cookie'], ...b});
      if (!'${r.headers['Cookie']}'.startsWith('rcl_hr=S1.hr')) return _j({'error': 'SESSION_EXPIRED', 'code': 'session'}, 401);
      return _hrAct(b);
    }
    // (3.72.0) Purchase of the site: its sign-in (a ticket of the Portal) – who, his role, every site where he has Purchase
    if (path.endsWith('/purchase/api/sso')) {
      final b = jsonDecode(r.body) as Map;
      purSent.add({'fn': 'sso', 'ticket': b['ticket']});
      if (r.headers['X-RCL'] != '1') return _j({'error': 'Refused: this request did not come from the Purchase page.'}, 403);
      return _j({'ok': true, 'user': {'email': 'sujit@rcl.test', 'name': 'Sujit Mule', 'role': purRole}, 'site': 'S1', 'siteName': 'VTR Site – NH 848',
        'sites': [{'code': 'S1', 'name': 'VTR Site – NH 848'}, if (purRole != 'user') {'code': 'T2', 'name': '18B Kolhapur'}]}, 200, {'set-cookie': 'rcl_pur=S1.pur1; Path=/; HttpOnly; SameSite=Lax'});
    }
    if (path.endsWith('/purchase/api/pur')) {
      final b = (jsonDecode(r.body) as Map).cast<String, dynamic>();
      purSent.add({'cookie': r.headers['Cookie'], ...b});
      if (!'${r.headers['Cookie']}'.startsWith('rcl_pur=S1.pur')) return _j({'error': 'SESSION_EXPIRED', 'code': 'session'}, 401);
      return _purAct(b);
    }
    if (path.endsWith('/engineering/api/eng')) {
      final b = (jsonDecode(r.body) as Map).cast<String, dynamic>();
      engSent.add({'cookie': r.headers['Cookie'], ...b});
      if (!'${r.headers['Cookie']}'.startsWith('rcl_eng=S1.eng') || engEnded) {
        engEnded = false;
        return _j({'error': 'SESSION_EXPIRED', 'code': 'session'}, 401);
      }
      // (3.93.0, Engineering 2A) the set-up, RFIs, hindrances and PPC – the same answers as rcl-engineering's api/eng.js
      final w = (String item, String name, int sort, List<List<String>> layers) => {'kind': 'work', 'item': item, 'valid_from': '2026-09-01', 'valid_to': null, 'active': true,
            'data': {'name': name, 'unit': 'm', 'sides': [], 'strip': true, 'sort': sort, 'layers': [for (final l in layers) {'key': l[0], 'name': l[1], 'mm': 200}]}};
      switch (b['action']) {
        case 'init':
          return _j({'ok': true, 'today': '2026-10-14', 'me': {'email': 'sujit@rcl.test', 'name': 'Sujit Mule', 'role': engRole}, 'road': {'name': 'Package 18B', 'ch_from': 8000, 'ch_to': 61055},
            'masters': [w('W-001', 'Embankment', 20, [['L1', 'Layer 1'], ['L2', 'Top']]), w('W-002', 'GSB', 40, [['L1', 'Layer 1']])],
            'assign': [{'email': 'sujit@rcl.test', 'work': 'W-001', 'active': true}], 'people': [], 'reasons': [], 'units': ['m'], 'sides': ['LHS', 'Median', 'RHS'], 'remind': {'due': false},
            'rfiRule': {'on': true, 'from': '2026-10-01'}});
        case 'rfiList':
          final st = '${b['status'] ?? ''}';
          return _j({'ok': true, 'rows': [for (final x in engRfi) if (st.isEmpty || x['status'] == st) x], 'rule': {'on': true, 'from': '2026-10-01'}, 'decide': engRole != 'user'});
        case 'rfiSave':
          if ('${b['from']}'.isEmpty) return _j({'error': 'The RFI: Embankment is measured in metres – give the chainage from and to.', 'code': 'ch'}, 400);
          final no = 'RFI-${(engRfi.length + 1).toString().padLeft(4, '0')}';
          final row = {'no': no, 'day': b['day'], 'work': b['work'], 'layer': b['layer'], 'side': b['side'], 'ch_from': _chM('${b['from']}'), 'ch_to': _chM('${b['to']}'), 'note': b['note'], 'status': 'Pending', 'asked_by': 'sujit@rcl.test', 'asked_name': 'Sujit Mule', 'ver': 1};
          engRfi.insert(0, row);
          return _j({'ok': true, 'rfi': row});
        case 'rfiDecide':
          final x = engRfi.firstWhere((y) => y['no'] == b['no']);
          if (b['status'] == 'Rejected' && '${b['ie_remark']}'.trim().length < 3) return _j({'error': 'Write why the IE rejected it.', 'code': 'remark'}, 400);
          x.addAll({'status': b['status'], 'ie_day': b['ie_day'], 'ie_name': b['ie_name'], 'ie_ref': b['ie_ref'], 'ie_remark': b['ie_remark'], 'ver': (x['ver'] as int) + 1});
          return _j({'ok': true, 'rfi': x});
        case 'rfiCancel':
          final x = engRfi.firstWhere((y) => y['no'] == b['no']);
          x.addAll({'status': 'Cancelled', 'ver': (x['ver'] as int) + 1});
          return _j({'ok': true, 'rfi': x});
        case 'hindList':
          return _j({'ok': true, 'from': b['from'], 'to': b['to'], 'rows': engHind, 'kinds': ['Land not handed over', 'Utility shifting', 'Heavy rain'], 'open': engHind.where((h) => h['to_day'] == null).length,
            'works': [{'work': 'W-002', 'name': 'GSB', 'days': 11, 'count': 1, 'open': 1}]});
        case 'hindSave':
          if ('${b['kind']}'.trim().isEmpty) return _j({'error': 'Say what the hindrance is (e.g. land not handed over, utility shifting, rain).', 'code': 'kind'}, 400);
          final row = {'no': 'H-${(engHind.length + 1).toString().padLeft(4, '0')}', 'from_day': b['from_day'], 'to_day': '${b['to_day']}'.isEmpty ? null : b['to_day'], 'ch_from': '${b['ch_from']}'.isEmpty ? null : _chM('${b['ch_from']}'), 'ch_to': '${b['ch_to']}'.isEmpty ? null : _chM('${b['ch_to']}'),
            'side': b['side'], 'works': b['works'], 'kind': b['kind'], 'detail': b['detail'], 'letter': b['letter'], 'status': '${b['to_day']}'.isEmpty ? 'Open' : 'Closed', 'created_by': 'sujit@rcl.test', 'days': 3, 'ver': 1};
          engHind.insert(0, row);
          return _j({'ok': true, 'hindrance': row});
        // (3.95.0, Engineering 2B) the Measurement Book
        case 'mbList':
          final st = '${b['status'] ?? ''}';
          return _j({'ok': true, 'from': '2026-07-17', 'to': '2026-10-14', 'rows': [
            for (final m in engMb.reversed)
              if (st.isEmpty || m['status'] == st)
                {...m, 'name': m['layer'] == 'L2' ? 'Embankment · Top' : 'Embankment · Layer 1', 'lines': (m['lines'] as List).length,
                  'totals': [{'unit': 'cum', 'qty': (m['lines'] as List).fold<num>(0, (a, l) => a + ((l as Map)['qty'] as num))}]},
          ]});
        case 'mbGet':
          final m = engMb.firstWhere((x) => x['no'] == b['no']);
          return _j({'ok': true, 'mb': m, 'name': m['layer'] == 'L2' ? 'Embankment · Top' : 'Embankment · Layer 1', 'unit': 'cum', 'totals': [{'unit': 'cum', 'qty': (m['lines'] as List).fold<num>(0, (a, l) => a + ((l as Map)['qty'] as num))}]});
        case 'mbCheck':
        case 'mbBack':
          final m = engMb.firstWhere((x) => x['no'] == b['no']);
          if (m['ver'] != b['ver']) return _j({'error': 'It was changed by someone else just now.', 'code': 'changed'}, 409);
          if (m['measured_by'] == 'sujit@rcl.test') return _j({'error': 'You measured it – another Admin or the Super Admin check-measures it.', 'code': 'own'}, 403);
          if (b['action'] == 'mbCheck') {
            m['status'] = 'Check-measured';
            m['checked_name'] = 'Sujit Mule';
            m['chk_day'] = b['chk_day'];
            m['chk_remark'] = b['remark'];
          } else {
            m['status'] = 'Sent back';
            m['back_name'] = 'Sujit Mule';
            m['back_why'] = b['why'];
          }
          m['ver'] = (m['ver'] as int) + 1;
          (m['history'] as List<Map<String, dynamic>>).add({'at': '2026-10-14T11:00:00Z', 'by': 'sujit@rcl.test', 'name': 'Sujit Mule', 'what': m['status'], 'why': b['why'] ?? '', 'remark': b['remark'] ?? ''});
          return _j({'ok': true, 'mb': m});
        case 'mbOffer':
          Map<String, dynamic> ln(String k, String side, num f, num t, num w, String appr, List<String> rfi) =>
              {'key': k, 'src': 'r1', 'day': '2026-10-13', 'email': 'eng1@rcl.test', 'name': 'Engineer One', 'line': 1, 'outside': false, 'rep': null, 'side': side, 'from': f, 'to': t, 'len': t - f, 'w_m': w, 'mm_m': 300, 'qty': (t - f) * w * 0.3, 'unit': 'cum', 'how': 'LxWxT', 'appr': appr, 'rfi': rfi};
          return _j({'ok': true, 'work': b['work'], 'layer': b['layer'], 'name': 'Embankment · Layer 1', 'unit': 'm', 'from': b['from'], 'to': b['to'], 'rule': {'on': true, 'from': '2026-10-01'},
            'lines': [ln('k1', 'LHS', 44000, 44300, 8, 'yes', ['RFI-0003']), ln('k2', 'RHS', 44000, 44200, 7.5, 'off', []), ln('k3', 'LHS', 45000, 45100, 8, 'no', [])],
            'skipped': [{'why': 'in the MB', 'side': 'LHS', 'from': 40000, 'to': 40400}], 'gone': [], 'no': null, 'ver': 0, 'mb_day': null, 'note': ''});
        case 'mbSave':
          final m = <String, dynamic>{'no': 'MB-${(engMb.length + 1).toString().padLeft(4, '0')}', 'work': b['work'], 'layer': b['layer'], 'from_day': b['from'], 'to_day': b['to'], 'mb_day': b['mb_day'], 'status': 'Measured', 'note': b['note'], 'ver': 1,
            'measured_by': 'sujit@rcl.test', 'measured_name': 'Sujit Mule', 'measured_at': '2026-10-14T11:30:00Z', 'checked_name': '', 'chk_day': null,
            'lines': [for (final (i, l) in (b['lines'] as List).indexed) {'ln': i + 1, 'key': l['key'], 'day': '2026-10-13', 'name': 'Engineer One', 'side': l['key'] == 'k2' ? 'RHS' : 'LHS', 'from': 44000, 'to': l['key'] == 'k2' ? 44200 : 44300,
              'len': l['key'] == 'k2' ? 200 : 300, 'w_m': l['key'] == 'k2' ? 7.5 : 8, 'mm_m': 300, 'w': num.parse('${l['w']}'), 'mm': num.parse('${l['mm']}'), 'qty': (l['key'] == 'k2' ? 200 : 300) * num.parse('${l['w']}') * num.parse('${l['mm']}') / 1000,
              'unit': 'cum', 'how': 'LxWxT', 'appr': 'yes', 'rfi': l['key'] == 'k1' ? ['RFI-0003'] : [], 'remark': l['remark'], 'skip': l['skip']}],
            'history': <Map<String, dynamic>>[{'at': '2026-10-14T11:30:00Z', 'by': 'sujit@rcl.test', 'name': 'Sujit Mule', 'what': 'Measured'}]};
          engMb.add(m);
          return _j({'ok': true, 'mb': m, 'site': 'S1'});
        case 'mbAbstract':
          return _j({'ok': true, 'from': b['from'], 'to': b['to'], 'rows': [{'work': 'W-001', 'layer': 'L2', 'unit': 'cum', 'prev': 2262.5, 'now': 225, 'cum': 2487.5, 'pages': ['MB-0001'], 'name': 'Embankment', 'layerName': 'Top'}],
            'waiting': [for (final m in engMb) if (m['status'] != 'Check-measured') {'no': m['no'], 'status': m['status'], 'name': 'Embankment'}]});
        case 'perf':
          return _j({'ok': true, 'from': b['from'], 'to': b['to'], 'ppc': {'lines': 24, 'done': 17, 'pct': 71},
            'weeks': [{'from': '2026-10-01', 'to': '2026-10-07', 'lines': 12, 'done': 9, 'pct': 75}, {'from': '2026-10-08', 'to': '2026-10-14', 'lines': 12, 'done': 8, 'pct': 67}],
            'people': [{'name': 'Engineer One', 'ppc': {'lines': 14, 'done': 11, 'pct': 79}}, {'name': 'Engineer Two', 'ppc': {'lines': 10, 'done': 6, 'pct': 60}}],
            'reasons': [{'text': 'Water tanker late', 'times': 4, 'people': ['Engineer One']}, {'text': 'Grader breakdown', 'times': 2, 'people': ['Engineer Two']}]});
      }
      if (b['action'] != 'aiLook') return _j({'error': 'Unknown action.', 'code': 'action'}, 400);
      return _j({'ok': true, 'date': '2026-10-13', 'works': [{'name': 'PQC', 'unit': 'm', 'planned': 120, 'done': 100, 'pct': 83}], 'page': 'eng-dash'});
    }
    // (3.61.0, Mechanical update-186) the assistant's answer word by word: lines of JSON (the whole body here – the app reads it as it comes)
    if (path.endsWith('/api/ai')) {
      if (!aiStream) return _j({'error': 'not found'}, 404);
      final b = (jsonDecode(r.body) as Map).cast<String, dynamic>();
      if (b['token'] == null || '${b['token']}'.isEmpty) return _j({'error': 'SESSION_EXPIRED'}, 401);
      final x = (b['x'] as Map).cast<String, dynamic>();
      aiStreamed.add(x);
      aiAsked.add(x);
      if (!aiOn) return _j({'error': 'The assistant is not set up yet: the Admin has to put the AI key (ANTHROPIC_API_KEY – Claude) in the server\'s settings.'}, 500);
      final how = aiStreamHow.isNotEmpty ? aiStreamHow.removeAt(0) : 'end';
      final step = how == 'end'
          ? (aiScript.isNotEmpty ? aiScript.removeAt(0) : {'parts': [{'text': 'Nothing more to say.'}], 'model': 'claude-sonnet-5-5'})
          : how == 'busy' || how == 'cut'
              ? {'parts': [{'text': 'The first words of '}]}
              : {'parts': []};
      final lines = <String>[];
      for (final p in (step['parts'] as List).whereType<Map>()) {
        final t = '${p['text'] ?? ''}';
        for (var i = 0; i < t.length; i += 6) {
          lines.add(jsonEncode({'t': 'd', 'x': t.substring(i, i + 6 > t.length ? t.length : i + 6)}));
        }
      }
      if (how == 'end') lines.add(jsonEncode({'t': 'end', 'parts': step['parts'], 'model': step['model'] ?? 'claude-sonnet-5-5', 'used': 100, 'ms': 900}));
      if (how == 'busy' || how == 'busy0') lines.add(jsonEncode({'t': 'err', 'e': 'The AI service is busy right now (529) – that is on its side, not in the app. It was asked ${how == 'busy' ? 1 : 3} time(s). Please ask again in a minute.', 'cut': how == 'busy'}));
      if (how == 'credit') lines.add(jsonEncode({'t': 'err', 'e': 'The AI service has no credit left (Claude): the Admin has to add funds in Claude Console → Billing. The rest of the app works as always.', 'cut': false}));
      if (how == 'end') lines.add(jsonEncode({'t': 'd', 'x': 'what the server sends after the end is not read'}));
      return http.Response('${lines.join('\n')}\n', 200, headers: {'content-type': 'application/x-ndjson; charset=utf-8'});
    }
    if (path.endsWith('/api/rpc')) {
      final b = jsonDecode(r.body) as Map;
      final fn = b['fn'] as String, args = b['args'] as List;
      if (fn == 'ssoLogin') {
        calls.add('mech:ssoLogin:${args[0]}');
        return _j({'result': {'token': 'tok-${args[0]}', 'user': {'email': 'sujit@rcl.test', 'name': 'Sujit Mule', 'admin': superAdmin, 'super': superAdmin, 'perms': perms}, 'site': b['site'], 'siteName': b['site'] == 'S1' ? 'VTR Site – NH 848' : '18B Kolhapur'}});
      }
      if (fn == 'logout') {
        calls.add('mech:logout');
        return _j({'result': true});
      }
      final action = args[1] as String, a = args[2] as List;
      calls.add('mech:$action${b['rid'] != null ? '+rid' : ''}');
      final meta = args.length > 3 && args[3] is Map ? (args[3] as Map).cast<String, dynamic>() : null;
      if (meta != null) metas.add({'fn': action, ...meta});
      if (!(args[0] as String).startsWith('tok-')) return _j({'error': 'SESSION_EXPIRED'}, 401);
      if (expireOnce == action) {
        expireOnce = '';
        return _j({'error': 'SESSION_EXPIRED'}, 401);
      }
      final stock = card ? cardStock : fuels ? {'stock': 302, 'byLoc': {'DIESEL CARD': 150, 'PETROL CARD': 100, 'PETROL CAN': 20, 'CNG CARD': 32}, 'byFuel': {'Diesel': 150, 'Petrol': 120, 'CNG': 32}} : {'stock': 1133, 'byLoc': {'Dispenser': 813, 'VTR Store': 320}};
      const lockMsg = 'Log Book entry of MH-25-AJ-2169 on 14-10-2026: this machinery is in the submitted RA Bill 9 of Rana (RCL, 01-10-2026 to 14-10-2026) – its Log Book and diesel entries of those dates cannot be added, changed or deleted without the Super Admin.';
      const apMsg = 'Log Book entry of MH-25-AJ-2169 on 14-10-2026: it was approved on 14-10-2026 by Checker One (VF-00003) – an approved entry cannot be changed or deleted without the Super Admin. To correct it: change the entry and send it to the Super Admin for approval (the page asks) – it is saved only when he approves.';
      if (apLock && !superAdmin && action == 'updateLogRow') return _j({'error': apMsg}, 500);
      // (3.33.0) the Super Admin's save of a locked entry: his reason first (it comes as the 4th part of the call)
      if ((billLock || apLock) && superAdmin && action == 'updateLogRow') {
        final m = args.length > 3 && args[3] is Map ? args[3] as Map : null;
        if (m == null || '${m['reason'] ?? ''}'.trim().isEmpty) return _j({'error': 'SA_REASON: Super Admin – this save changes 1 locked Log Book entry (MH-25-AJ-2169 14-10-2026 – changed, in RA Bill 9). Give the reason: it is kept with the entry\'s history.'}, 500);
        saReasons.add('${m['reason']}');
      }
      if (billLock && !superAdmin && action == 'updateLogRow') return _j({'error': lockMsg}, 500);
      if (billLock && !superAdmin && action == 'saveLogRows') return _j({'result': {'ok': false, 'errors': [{'row': 1, 'msg': lockMsg}]}});
      if (action == 'sendChangeRequest') {
        requests.add((a[0] as Map).cast<String, dynamic>());
        return _j({'result': {'ok': true, 'id': 'CR-0000${requests.length}'}});
      }
      if (b['rid'] != null) rids.add('$action:${b['rid']}');
      if (flowFor == action) return _j({'error': 'Sent for verification to Checker One – VF-00007. It is saved when it is approved; nothing is saved until then.'}, 500);
      switch (action) {
        case 'sync':
          // (3.26.0) the call's part of the heartbeat (Mechanical's rtcBeat_): {r, top, m}
          final beat = a.isNotEmpty && a[0] is Map ? a[0] as Map : const {};
          rtcBeats.add(beat['r']);
          final m = [...rtcIn];
          rtcIn.clear();
          return _j({'result': {'versions': versions, 'stamp': stamp, if (syncToday != null) 'today': syncToday, if (beat.containsKey('r') || m.isNotEmpty) 'rtc': {'r': rtcN, 'top': rtcN, 'm': m},
            if (userInSync) 'user': {'email': 'sujit@rcl.test', 'name': 'Sujit Mule', 'admin': superAdmin, 'super': superAdmin, 'perms': perms, if (dsrc != null) 'dsrc': dsrc, if (pageAdmin != null) 'pageAdmin': pageAdmin}}});
        case 'rtcUsers':
          return _j({'result': {'me': 'u-sujit', 'name': 'Sujit Mule', 'users': rtcPeople, 'ice': [{'urls': ['stun:stun.l.google.com:19302']}], 'relay': false, 'max': 3}});
        case 'fcmSave':
        case 'fcmOff':
          fcm.add([action, '${(a[0] as Map)['token']}', '${b['site'] ?? ''}']);
          return _j({'result': {'ok': true, 'phones': 1, 'sending': true}});
        case 'rtcSend':
          rtcSent.add((a[0] as Map).cast<String, dynamic>());
          return _j({'result': {'ok': true, 'n': ++rtcN}});
        case 'rtcMissed':
          final x = (a[0] as Map);
          if (x['clear'] == true) rtcMissed = [];
          return _j({'result': {'list': rtcMissed, 'unseen': 0}});
        case 'rtcWa':
          return _j({'result': {'none': true, 'name': 'Mahesh Jadhav'}});
        case 'getChangeRequests':
          return _j({'result': {'requests': flowReqs, 'pending': crPending, 'forMe': crForMe}});
        case 'approvalDetails':
          final ids = (((a[0] as Map)['ids'] as List?) ?? const []).map((e) => '$e').toList();
          detAsked.add(ids);
          if (ids.isEmpty) return _no('Choose an entry to see its details.');
          return _j({'result': {'details': [for (final id in ids) flowDetails[id] ?? {'id': id, 'error': 'This request was not found – refresh the list.'}]}});
        case 'remindFlow':
          final x = (a[0] as Map).cast<String, dynamic>();
          final ids = x['all'] == true ? flowReqs.where((r) => r['canRemind'] == true).map((r) => '${r['id']}').toList() : (x['ids'] as List).map((e) => '$e').toList();
          reminded.add(ids);
          for (final r in flowReqs.where((r) => ids.contains(r['id']))) {
            r['reminds'] = ((r['reminds'] as num?) ?? 0) + 1;
            r['remindedAt'] = DateTime.now().toUtc().toIso8601String();
          }
          return _j({'result': {'ok': true, 'reminded': ids, 'later': [], 'list': {'requests': flowReqs, 'pending': crPending, 'forMe': crForMe}}});
        // (3.2.0) the reports: the real answers of the test server (test/fixtures/reports)
        case 'rptDebit' || 'rptLogDebit' || 'rptMachineCost' || 'rptDriver' || 'rptCost' || 'rptPurchase' || 'rptLedger' || 'rptWatch' || 'rptOwner' || 'rptType' || 'rptStock' || 'rptCompare' || 'rptTank' || 'rptAverage' || 'getDailyInwardIssueReport' || 'getMonthlyDieselReport' || 'getMonthlyAvgReport':
          reportAsked.add({'fn': action, ...((a.isNotEmpty ? a[0] : const {}) as Map).cast<String, dynamic>()});
          return _j({'result': jsonDecode(File('test/fixtures/reports/$action.json').readAsStringSync())});
        case 'saveDebitRates':
          return _j({'result': {'ok': true, 'count': (a[0] as List).length}});
        case 'saveLogDebits': // (3.31.7, update-149) the party + rate of Log Book entries
          final x = (a[0] as Map).cast<String, dynamic>();
          ldSaved.add(x);
          return _j({'result': {'ok': true, 'count': (x['rows'] as List).length, 'same': 0, 'keys': [], 'changes': []}});
        // (3.2.0) the Approvals screen: decide one / several, answer, the rules
        case 'decideChangeRequest':
          final x = (a[0] as Map).cast<String, dynamic>();
          decided.add(x);
          final r = flowReqs.firstWhere((r) => r['id'] == x['id']);
          final st = x['revert'] == true ? 'Reverted' : x['approve'] == true ? 'Approved' : 'Rejected';
          r['status'] = st;
          r['canDecide'] = false;
          r['decidedBy'] = 'Sujit Mule';
          r['note'] = '${x['note'] ?? ''}';
          return _j({'result': {'ok': true, 'id': x['id'], 'status': st, 'level': 1, 'levels': 1, 'list': {'requests': flowReqs, 'pending': crPending, 'forMe': crForMe}}});
        case 'decideChangeRequests':
          final x = (a[0] as Map).cast<String, dynamic>();
          decided.add(x);
          final ids = (x['ids'] as List).map((e) => '$e').toList();
          for (final r in flowReqs.where((r) => ids.contains(r['id']))) {
            r['status'] = x['revert'] == true ? 'Reverted' : x['approve'] == true ? 'Approved' : 'Rejected';
            r['canDecide'] = false;
          }
          return _j({'result': {'ok': true, 'done': [for (final id in ids) {'id': id, 'status': 'Approved'}], 'failed': [], 'list': {'requests': flowReqs, 'pending': crPending, 'forMe': crForMe}}});
        case 'answerFlow':
          final x = (a[0] as Map).cast<String, dynamic>();
          decided.add({'answer': true, ...x});
          final r = flowReqs.firstWhere((r) => r['id'] == x['id']);
          r['status'] = x['withdraw'] == true ? 'Withdrawn' : 'Pending';
          r['canAnswer'] = false;
          return _j({'result': {'ok': true, 'id': x['id'], 'status': r['status'], 'list': {'requests': flowReqs, 'pending': crPending, 'forMe': crForMe}}});
        case 'resendFlow':
          final x = (a[0] as Map).cast<String, dynamic>();
          resent.add(x);
          final ids = x['ids'] is List ? (x['ids'] as List).map((e) => '$e').toList() : ['${x['id']}'];
          final done = <Map<String, dynamic>>[], failed = <Map<String, dynamic>>[];
          for (final id in ids) {
            final r = flowReqs.firstWhere((r) => r['id'] == id, orElse: () => <String, dynamic>{});
            if (resendRefuse.containsKey(id)) {
              failed.add({'id': id, 'error': 'Not sent again: ${resendRefuse[id]} – entry $id stays as it is (nothing is lost); send it again when this is put right.'});
            } else if (r['canResend'] == true) {
              r['status'] = 'Pending';
              r['canResend'] = false;
              r['canRemind'] = true;
              r['resent'] = ((r['resent'] as num?) ?? 0) + 1;
              done.add({'id': id, 'level': 1, 'levels': r['levels'] ?? 1});
            } else {
              failed.add({'id': id, 'error': 'Entry $id was not found – refresh the list.'});
            }
          }
          if (x['ids'] == null && failed.isNotEmpty && !resendRefuse.containsKey(failed.first['id'])) return _j({'error': failed.first['error']}, 500);      // (update-129: a refusal comes back in failed)
          return _j({'result': {'ok': true, 'done': done, 'failed': failed, 'list': {'requests': flowReqs, 'pending': crPending, 'forMe': crForMe}}});
        case 'superDelList':      // (3.25.0)
          sdAsked.add({'fn': action, ...(a[0] as Map).cast<String, dynamic>()});
          if (!superAdmin) return _j({'error': 'Only the Super Admin deletes or brings back entries here (signed in through the Portal).'}, 500);
          final x = (a[0] as Map).cast<String, dynamic>();
          return _j({'result': {'from': x['from'], 'to': '${x['to'] ?? ''}'.isEmpty ? x['from'] : x['to'], 'closedUpto': '', 'saved': sdSaved, 'waiting': sdWaiting, 'deleted': sdDeleted, 'users': ['Mahesh Jadhav', 'Sujit Mule']}});
        case 'superDelete':
          final x = (a[0] as Map).cast<String, dynamic>();
          sdAsked.add({'fn': action, ...x});
          final ids = [for (final i in x['ids'] as List? ?? const []) '$i'], flows = [for (final i in x['flows'] as List? ?? const []) '$i'];
          final bad = [for (final i in [...ids, ...flows]) if (sdRefuse.containsKey(i)) sdRefuse[i]!];
          if (bad.isNotEmpty) return _j({'result': {'ok': false, 'errors': bad}});
          final kept = <Map<String, dynamic>>[];
          for (final i in [...ids, ...flows]) {
            final r = [...sdSaved, ...sdWaiting].firstWhere((r) => r['id'] == i);
            final del = 'DEL-${(sdDeleted.length + kept.length + 1).toString().padLeft(5, '0')}';
            kept.add({'del': del, 'entry': i});
            sdDeleted.add({'id': del, 'entry': i, 'kind': ids.contains(i) ? 'saved' : 'request', 'was': ids.contains(i) ? 'Saved' : r['label'], 'dates': r['dates'] ?? [r['date']], 'nos': r['nos'] ?? r['no'], 'qty': r['qty'], 'by': r['by'], 'deletedBy': 'Sujit Mule', 'deletedAt': '2026-10-14T05:00:00.000Z', 'lines': r['lines'] ?? []});
          }
          sdSaved.removeWhere((r) => ids.contains(r['id']));
          sdWaiting.removeWhere((r) => flows.contains(r['id']));
          return _j({'result': {'ok': true, 'deleted': kept.length, 'saved': ids.length, 'requests': flows.length, 'kept': kept}});
        case 'superRestore':
          final x = (a[0] as Map).cast<String, dynamic>();
          sdAsked.add({'fn': action, ...x});
          final ids = [for (final i in x['ids'] as List? ?? const []) '$i'];
          final bad = [for (final i in ids) if (sdRefuse.containsKey(i)) sdRefuse[i]!];
          if (bad.isNotEmpty) return _j({'result': {'ok': false, 'errors': bad}});
          final back = [for (final r in sdDeleted.where((r) => ids.contains(r['id']))) '${r['entry']}'];
          sdDeleted.removeWhere((r) => ids.contains(r['id']));
          return _j({'result': {'ok': true, 'restored': back.length, 'ids': back}});
        case 'openFlow':
          final x = (a[0] as Map).cast<String, dynamic>(), id = '${x['id']}';
          final r = flowReqs.firstWhere((r) => r['id'] == id, orElse: () => <String, dynamic>{}), f = fixOf[id];
          if (f == null || r['canFix'] != true) return _j({'error': 'Entry $id cannot be opened to correct here (Diesel Issue – one entry and Multiple entries – only, for now) – use "Send again", or enter it again.'}, 500);
          return _j({'result': {'ok': true, 'id': id, 'fn': f['fn'], 'form': f['form'], 'args': f['args'], 'status': r['status'], 'result': r['result'] ?? '', 'decidedBy': r['decidedBy'] ?? '', 'note': r['note'] ?? '', 'check': f['check'] ?? {'ok': true}}});
        case 'editFlow':
          final x = (a[0] as Map).cast<String, dynamic>(), id = '${x['id']}';
          edited.add(x);
          final first = (x['args'] as List).first, forced = first is Map && first['force'] == true;
          if (editRefuse.containsKey(id) && !forced) return _j({'result': {...editRefuse[id]!, 'ok': false, 'id': id, 'notSent': true}});
          final r = flowReqs.firstWhere((r) => r['id'] == id);
          r['status'] = 'Pending';
          r['canFix'] = false;
          r['canResend'] = false;
          r['canRemind'] = true;
          r['history'] = [...(r['history'] as List? ?? const []), {'step': 'Corrected and sent again', 'level': 1, 'by': 'Mahesh Jadhav', 'at': DateTime.now().toUtc().toIso8601String(), 'note': x['note'], 'changes': ['Row 2 – Machinery: KDX-130B → KDX-130']}];
          return _j({'result': {'ok': true, 'id': id, 'status': 'Pending', 'level': 1, 'levels': 1, 'changes': ['Row 2 – Machinery: KDX-130B → KDX-130'], 'list': {'requests': flowReqs, 'pending': crPending, 'forMe': crForMe}}});
        case 'getFlowRules':
          return _j({'result': {
            'tasks': [{'m': 'Diesel Issue', 'label': 'Diesel Issue', 'fns': ['saveDieselIssue'], 'diesel': true}, {'m': 'Log Book', 'label': 'Log Book', 'fns': ['saveLogRows'], 'diesel': false}],
            'rules': {'remindHours': 4, 'tasks': {'Diesel Issue': {'on': true, 'levels': [['mahesh@rcl.test']], 'daysBack': '', 'qtyAbove': '200'}}},
            'users': [{'email': 'mahesh@rcl.test', 'name': 'Mahesh Jadhav'}, {'email': 'shubham@rcl.test', 'name': 'Shubham'}],
          }});
        case 'saveFlowRules':
          rulesSaved.add((a[0] as Map).cast<String, dynamic>());
          return _j({'result': {'ok': true, 'rules': (a[0] as Map)}});
        case 'getStock':
          return _j({'result': stock});
        case 'getInit':
          return _j({'result': {'flow': flowMine, 'stamp': stamp, 'today': '2026-10-14', 'company': 'Rachana Construction Limited', 'locations': card ? <String>[] : fuels ? ['DIESEL CARD', 'PETROL CARD', 'PETROL CAN', 'CNG CARD'] : ['Dispenser', 'VTR Store'],
            if (card) ...{'fuelMode': 'card', 'siteFuels': ['Diesel', 'Petrol', 'CNG']},
            if (fuels && !card) 'placeFuels': {'DIESEL CARD': 'Diesel', 'PETROL CARD': 'Petrol', 'PETROL CAN': 'Petrol', 'CNG CARD': 'CNG'}, 'drivers': ['Gupta', 'Maruti'], 'pumps': ['IOC Bunk'], 'stock': stock,
            'user': {'email': 'sujit@rcl.test', 'name': 'Sujit Mule', 'admin': superAdmin, 'super': superAdmin, 'perms': perms, if (dsrc != null) 'dsrc': dsrc, if (pageAdmin != null) 'pageAdmin': pageAdmin},
            'master': _master, 'ai': {'on': aiOn}}});
        // (3.4.0) the masters
        case 'getVendors':
          return _j({'result': vendors});
        case 'getBoqs':
          return _j({'result': {'vendors': vendors, 'boqs': boqs, 'history': boqHist, 'vdocsOn': vdocsOn}});
        case 'saveMaster':
          final m = (a[0] as Map).cast<String, dynamic>();
          masterCalls.add({'fn': action, 'm': m, 'mode': a[1], 'id': a.length > 2 ? a[2] : null});
          // (3.88.0) Service every → kept as the server keeps it: { km, hrs, months } or none
          if (m.containsKey('svcKm') || m.containsKey('svcHrs') || m.containsKey('svcMon')) {
            dynamic nv(Object? v) => '${v ?? ''}'.trim().isEmpty ? '' : (num.tryParse('$v'.replaceAll(',', '')) ?? '');
            final sv = {'km': nv(m['svcKm']), 'hrs': nv(m['svcHrs']), 'months': nv(m['svcMon'])};
            m['svc'] = sv.values.every((v) => v == '') ? null : sv;
          }
          final id = '${m['no'] ?? ''}'.isNotEmpty ? '${m['no']}' : '${m['name']}';
          if (a[1] == 'add') {
            master.add({...m, 'id': id, 'worksOn': _works(m['worksOn'])});
          } else {
            final i = master.indexWhere((x) => x['id'] == a[2]);
            master[i] = {...master[i], ...m, 'id': id, 'worksOn': _works(m['worksOn'])};
          }
          return _j({'result': {'ok': true, 'master': _master, 'renamed': a[1] == 'edit' && id != a[2] ? {'from': a[2], 'to': id, 'text': '3 diesel issues'} : null}});
        case 'saveMasterBulk':
          final list = (a[0] as List).whereType<Map>().map((x) => x.cast<String, dynamic>()).toList();
          masterCalls.add({'fn': action, 'list': list});
          final errs = [
            for (final (k, m) in list.indexed)
              if (['no', 'name', 'type', 'make', 'unit', 'kmStd', 'hrStd', 'owner', 'ownership'].any((f) => '${m[f] ?? ''}'.isNotEmpty) && '${m['ownership']}'.isEmpty) {'row': k + 1, 'msg': '${'${m['no']}'.isNotEmpty ? m['no'] : m['name']}: select Ownership (Own / Rental / Hired / Debit / Other).'}
          ];
          if (errs.isNotEmpty) return _j({'result': {'ok': false, 'errors': errs}});
          final add = list.where((m) => '${m['no']}${m['name']}'.isNotEmpty).toList();
          for (final m in add) {
            master.add({...m, 'id': '${m['no']}'.isNotEmpty ? m['no'] : m['name'], 'status': 'Active'});
          }
          return _j({'result': {'ok': true, 'count': add.length, 'master': _master}});
        case 'deleteMaster':
          masterCalls.add({'fn': action, 'id': a[0], 'force': a[1]});
          if (a[1] != true && a[0] == 'MH-25-AJ-2169') return _j({'result': {'ok': false, 'warning': 'MH-25-AJ-2169 has 3 Diesel Issue and 2 Log Book entries. Those entries will stay, but this machinery will be removed from Master. Delete anyway?'}});
          master.removeWhere((x) => x['id'] == a[0]);
          return _j({'result': {'ok': true, 'master': _master}});
        case 'editMasterMany':
          final ids = (a[0] as List).map((e) => '$e').toList(), ch = (a[1] as Map).cast<String, dynamic>();
          masterCalls.add({'fn': action, 'ids': ids, 'changes': ch});
          for (final m in master.where((x) => ids.contains(x['id']))) {
            m.addAll(ch);
          }
          return _j({'result': {'ok': true, 'count': ids.length, 'master': _master}});
        case 'deleteMasterMany':
          final ids = (a[0] as List).map((e) => '$e').toList();
          masterCalls.add({'fn': action, 'ids': ids, 'force': a[1]});
          if (a[1] != true && ids.contains('MH-25-AJ-2169')) return _j({'result': {'ok': false, 'used': [{'id': 'MH-25-AJ-2169', 'diesel': 3, 'log': 2}]}});
          master.removeWhere((x) => ids.contains(x['id']));
          return _j({'result': {'ok': true, 'count': ids.length, 'ids': ids, 'master': _master}});
        case 'assignVendors':
          final items = (a[0] as List).whereType<Map>().map((x) => x.cast<String, dynamic>()).toList();
          masterCalls.add({'fn': action, 'items': items});
          for (final it in items) {
            master.firstWhere((x) => x['id'] == it['id'])['owner'] = it['vendor'];
          }
          return _j({'result': {'ok': true, 'count': items.length, 'master': _master, 'vendors': vendors}});
        case 'vendorsFromOwners':
          masterCalls.add({'fn': action, 'names': a[0]});
          return _j({'result': {'ok': true, 'count': (a[0] as List).length, 'names': a[0], 'vendors': vendors}});
        // (3.13.0) Asset Master – Import from Excel: checked (save false), then saved; a row named "BAD" is a mistake
        case 'importMaster':
          final rows = [for (final r in a[0] as List) (r as Map).cast<String, dynamic>()];
          masterCalls.add({'fn': action, 'rows': rows, 'save': a[1]});
          final bad = [for (final r in rows) if (r['name'] == 'BAD') {'row': r['line'], 'msg': 'Type of Machinery is required.'}];
          if (bad.isNotEmpty) return _j({'result': {'errors': bad, 'adds': 0, 'updates': 0, 'same': 0}});
          if (a[1] == true) master.add({'id': 'NEW-1', 'no': '', 'name': 'NEW-1', 'type': 'Roller', 'unit': 'Hrs', 'status': 'Active', 'activeFrom': '2026-10-01', 'owner': 'RCL', 'ownership': 'Own', 'supply': 'Company'});
          return _j({'result': {'errors': [], 'adds': 1, 'updates': rows.length - 1, 'same': 0, if (a[1] == true) 'master': _master}});
        case 'exportMaster':
          return _j({'result': {'headers': ['Machinery Number', 'Machinery Name', 'Type of Machinery', 'Standard Average (KM/Ltr)'], 'rows': [for (final m in master) [m['no'] ?? '', m['name'] ?? '', m['type'] ?? '', m['kmStd'] ?? '']]}});
        case 'getBreakdowns' when bdRich:
          bdSent.add({'fn': action, 'args': a});
          return _j({'result': _bd('${(a[0] as Map)['date'] ?? ''}')});
        case 'getBreakdowns':
          return _j({'result': {'date': (a[0] as Map)['date'], 'history': [], 'onDate': []}});
        case 'submitBdReport':
          bdSent.add({'fn': action, 'x': a[0]});
          final sent = ((a[0] as Map)['rows'] as List).cast<Map>().map((r) => r.cast<String, dynamic>()).toList();
          bdSaved = sent;
          return _j({'result': {'ok': true, 'date': (a[0] as Map)['date'], 'replaced': false, 'total': sent.length, 'count': sent.where((r) => r['status'] == 'Breakdown').length, 'list': ''}});
        case 'deleteBdReport':
          bdSent.add({'fn': action, 'date': a[0]});
          bdSaved = null;
          return _j({'result': {'ok': true, 'date': a[0], 'deleted': true}});
        // (3.59.0, Mechanical update-184) one document of a vendor sent (as the server's uploadAttachment_ 'Vendor Master'); a vendor's
        // documents with their links (getVendorDocs – 15 minutes)
        case 'vendorDoc':
          final up = (a[0] as Map).cast<String, dynamic>(), m = RegExp(r'^data:(image/jpeg|image/png|application/pdf);base64,(.+)$').firstMatch('${up['data']}');
          masterCalls.add({'fn': action, 'name': up['name']});
          if (!vdocsOn) return _j({'error': 'The documents of the vendor cannot be kept yet. This needs one database step first: the Admin runs sql/supabase_step1zj_vendor_papers.sql once in Supabase → SQL Editor (in every site).'}, 500);
          if (m == null) return _j({'error': 'An attachment must be a photo (JPG or PNG) or a PDF.'}, 500);
          final raw = base64Decode(m.group(2)!), sha = crypto.sha256.convert(raw).toString(), ext = m.group(1) == 'application/pdf' ? 'pdf' : m.group(1) == 'image/png' ? 'png' : 'jpg';
          vendorFiles[sha] = {'name': up['name'], 'mime': m.group(1), 'size': raw.length, 'bytes': raw, 'p': 'vendor/${sha.substring(0, 2)}/$sha.$ext'};
          return _j({'result': {'ok': true, 'sha': sha, 'path': 'vendor/${sha.substring(0, 2)}/$sha.$ext', 'mime': m.group(1), 'size': raw.length, 'name': up['name'], 'dup': false}});
        case 'getVendorDocs':
          masterCalls.add({'fn': action, 'name': a[0]});
          final v = vendors.where((x) => x['name'] == a[0] && x['saved'] == true).firstOrNull;
          if (v == null) return _j({'error': 'Vendor ${a[0]} is not saved in the Vendor Master yet – save its details first.'}, 500);
          return _j({'result': {'name': v['name'], 'owner': v['owner'] ?? '', 'on': vdocsOn, 'docs': [
            for (final d in (v['docs'] as List? ?? const []).whereType<Map>()) {...d, 'p': vendorFiles['${d['sha']}']?['p'] ?? 'vendor/${'${d['sha']}'.substring(0, 2)}/${d['sha']}', 'url': 'https://files.test/${d['sha']}'},
          ]}});
        case 'saveVendor':
          final v = {...(a[0] as Map).cast<String, dynamic>()};
          masterCalls.add({'fn': action, 'v': {...v}, 'mode': a[1]});
          // (3.59.0, Mechanical update-184) as the server: the Owner Name and the documents only where the site keeps them; a new document
          // must have been sent (vendorDoc) – each kept with its kind
          if (!vdocsOn && ('${v['owner'] ?? ''}'.isNotEmpty || (v['docs'] is List && (v['docs'] as List).isNotEmpty))) {
            return _j({'error': 'The documents of the vendor cannot be kept yet. This needs one database step first: the Admin runs sql/supabase_step1zj_vendor_papers.sql once in Supabase → SQL Editor (in every site).'}, 500);
          }
          if (v['docs'] is List) {
            final kept = <Map<String, dynamic>>[];
            for (final d in (v['docs'] as List).whereType<Map>()) {
              final f = vendorFiles['${d['sha']}'];
              if (f == null) return _j({'error': 'A vendor document was not added by you in the last 6 hours – add it again.'}, 500);
              kept.add({'sha': d['sha'], 'kind': d['kind'], 'name': f['name'], 'mime': f['mime'], 'size': f['size'], 'at': '2026-10-14T06:00:00Z', 'by': 'Sujit Mule'});
            }
            v['docs'] = kept;
          }
          final was = '${v['oldName']}'.isNotEmpty ? '${v['oldName']}' : '${v['name']}';
          final i = vendors.indexWhere((x) => x['name'] == was);
          if (i > -1) {
            vendors[i] = {...vendors[i], ...v, 'saved': true};
          } else {
            vendors.add({...v, 'saved': true, 'machines': [], 'boqs': 0});
          }
          return _j({'result': {'ok': true, 'name': v['name'], 'renamed': '${v['oldName']}'.isNotEmpty ? {'from': v['oldName'], 'to': v['name'], 'text': '1 assets'} : null, 'vendors': vendors}});
        case 'deleteVendor':
          masterCalls.add({'fn': action, 'name': a[0]});
          return _j({'result': {'ok': true}});
        case 'saveBoq':
          final b = (a[0] as Map).cast<String, dynamic>();
          masterCalls.add({'fn': action, 'b': b, 'mode': a[1], 'id': a.length > 2 ? a[2] : null});
          return _j({'result': {'ok': true, 'id': 'BOQ-0002', 'no': '${b['no']}'.isEmpty ? '2' : b['no'], 'amendNo': b['amendOf'] != null ? 1 : 0}});
        case 'deleteBoq':
          masterCalls.add({'fn': action, 'id': a[0]});
          boqs.removeWhere((x) => x['id'] == a[0]);
          return _j({'result': {'ok': true}});
        case 'boqMissing':
          return _j({'result': {'date': (a[0] as Map)['date'], 'rows': [{'no': 'MH-04-J-9844', 'type': 'Water Tanker', 'vendor': 'Chalke Enterprises', 'ownership': 'Rental', 'vendorSaved': true}]}});
        case 'boqRateCheck':
          final x = (a[0] as Map).cast<String, dynamic>();
          return _j({'result': {'no': x['no'], 'date': x['date'], 'vendor': 'I E Enterprises', 'hit': {'line': boqs.first['lines'][0], 'boqNo': '1', 'amendNo': 0, 'from': '2026-09-01', 'to': ''}}});
        case 'getCompliance':
          return _j({'result': _compliance});
        // (3.13.0) Vehicle Compliance – Import Excel: checked (save false), then saved
        case 'importCompliance':
          masterCalls.add({'fn': action, 'rows': a[0], 'save': a[1]});
          return _j({'result': {'errors': [], 'changes': 2, 'machines': 1, 'preview': ['MH-25-AJ-2169 – PUC: 01-10-2026 → 30-09-2027', 'MH-25-AJ-2169 – Permit: – → N/A'], 'skipped': cmpSkipped}});
        case 'renewDoc':
          masterCalls.add({'fn': action, 'x': a[0]});
          return _j({'result': {'ok': true}});
        // (3.79.0, Mechanical update-205) one file of a paper sent (as the server's uploadAttachment_ 'Vehicle Compliance'); the files kept
        // with a line (cmpFiles – the server's same checks: each sent by this person); a machinery's documents with their links
        case 'cmpDoc':
          final up = (a[0] as Map).cast<String, dynamic>(), m = RegExp(r'^data:(image/jpeg|image/png|application/pdf);base64,(.+)$').firstMatch('${up['data']}');
          masterCalls.add({'fn': action, 'name': up['name']});
          if (!cmpFilesOn) return _j({'error': 'The documents of Vehicle Compliance cannot be kept yet. This needs one database step first: the Admin runs sql/supabase_step1zl_compliance_files.sql once in Supabase → SQL Editor, in every site.'}, 500);
          if (m == null) return _j({'error': 'An attachment must be a photo (JPG or PNG) or a PDF.'}, 500);
          final raw = base64Decode(m.group(2)!), sha = crypto.sha256.convert(raw).toString(), ext = m.group(1) == 'application/pdf' ? 'pdf' : m.group(1) == 'image/png' ? 'png' : 'jpg';
          cmpSent[sha] = {'sha': sha, 'p': 'log/${sha.substring(0, 2)}/$sha.$ext', 'mime': m.group(1), 'size': raw.length, 'name': up['name'], 'at': '2026-10-14T05:00:00Z', 'by': 'Tester'};
          return _j({'result': {'ok': true, 'sha': sha, 'path': cmpSent[sha]!['p'], 'mime': m.group(1), 'size': raw.length, 'name': up['name'], 'dup': false}});
        case 'cmpFiles':
          final x = (a[0] as Map).cast<String, dynamic>();
          masterCalls.add({'fn': action, 'x': x});
          final fs = [for (final f in (x['files'] as List? ?? const []).whereType<Map>()) cmpSent['${f['sha']}']];
          if (fs.isEmpty || fs.any((f) => f == null)) return _j({'error': 'A file of the paper was not added by you in the last 6 hours – add it again.'}, 500);
          final id = 'CMP-${(cmpRows.length + 10).toString().padLeft(6, '0')}';
          cmpRows.insert(0, {'id': id, 'no': x['no'], 'doc': x['doc'], 'from': '', 'to': '', 'on': '${x['on'] ?? ''}'.isEmpty ? '2026-10-14' : x['on'], 'docNo': x['docNo'] ?? '', 'amount': '', 'remark': x['remark'] ?? '', 'source': 'Document', 'by': 'Tester', 'files': fs});
          return _j({'result': {'ok': true, 'no': x['no'], 'doc': x['doc'], 'id': id, 'n': fs.length, 'added': true}});
        case 'getCmpFiles':
          final no = '${(a[0] as Map)['no']}';
          return _j({'result': {'no': no, 'type': 'Tipper', 'owner': 'I E Enterprises', 'ownership': 'Own', 'keep': ['RC Book', 'Tax Invoice'], 'on': cmpFilesOn, 'max': 10,
            'papers': [{'name': 'Tax', 'v': 'LIFETIME'}, {'name': 'PUC', 'v': '2026-09-30'}, {'name': 'Permit', 'v': ''}, {'name': 'Fitness', 'v': '2027-01-31'}, {'name': 'Insurance', 'v': '2026-10-20'}],
            'rows': [for (final r in cmpRows.where((r) => r['no'] == no)) {...r, 'files': [for (final f in r['files'] as List) {...(f as Map), 'url': 'https://store.test/${f['p']}?token=t'}]}]}});
        case 'saveCmpRules':
          masterCalls.add({'fn': action, 'rules': a[0]});
          return _j({'result': {'ok': true}});
        case 'getLbFormatNames':
          return _j({'result': lbNames});
        case 'saveLbFormatName':
          final x = (a[0] as Map).cast<String, dynamic>();
          masterCalls.add({'fn': action, ...x});
          lbNames['${x['id']}'] = '${x['name']}';
          return _j({'result': {'ok': true, 'names': lbNames}});
        case 'saveLbFormats':
          final ch = (a[0] as Map).cast<String, dynamic>();
          masterCalls.add({'fn': action, 'ch': ch});
          for (final e in ch.entries) {
            master.firstWhere((x) => x['id'] == e.key)['lbFormat'] = e.value;
          }
          return _j({'result': {'ok': true, 'count': ch.length, 'master': _master}});
        // (3.5.0) the Dashboard and Tank Check: the real answers of the test server (test/fixtures/dash)
        case 'getDashboard' || 'logDashboard' || 'pendingLog' || 'getStockLedger' || 'getOwnershipDetail':
          dashAsked.add({'fn': action, 'args': a});
          return _j({'result': jsonDecode(File('test/fixtures/dash/$action.json').readAsStringSync())});
        case 'saveTankSettings':
          masterCalls.add({'fn': action, 'x': a[0]});
          return _j({'result': {'caps': (a[0] as Map)['caps'], 'low': (a[0] as Map)['low']}});
        case 'getTankSystem':
          return _j({'result': {'machine': master.firstWhere((m) => m['id'] == a[0], orElse: () => master.first), 'date': a[1], 'system': 120, 'fromLog': {'date': '2026-10-13', 'shift': 'Day', 'stock': 120}, 'fromCheck': null, 'addedAfter': 60, 'cap': 400}});
        case 'getTankChecks':
          return _j({'result': {'rows': tankChecks}});
        case 'saveTankCheck':
          masterCalls.add({'fn': action, 'x': a[0]});
          return _j({'result': {'ok': true, 'id': 'TC-0002'}});
        case 'deleteTankCheck':
          masterCalls.add({'fn': action, 'id': a[0]});
          tankChecks.removeWhere((x) => x['id'] == a[0]);
          return _j({'result': {'ok': true}});
        case 'getDieselIssues':
          if (a.isNotEmpty && a[0] is Map) listAsked.add({'fn': action, ...(a[0] as Map).cast<String, dynamic>()});
          return _j({'result': {'count': issues.length, 'totalQty': 240, 'rows': issues, 'share': [
            for (final i in issues) {'no': i['no'], 'type': i['type'], 'owner': '', 'entries': 1, 'qty': i['qty']},
          ]}});
        case 'importInward' || 'importDiesel' || 'saveTransferBulk':
          final rows = [for (final r in a[0] as List) (r as Map).cast<String, dynamic>()];
          importSent.add({'fn': action, 'rows': rows});
          final no = rows.where((r) => r['remark'] == 'server says no').toList();
          if (no.isNotEmpty) return _j({'result': {'ok': false, 'errors': [for (final r in no) {'row': r['line'], 'msg': 'The server refused this row.'}]}});
          return _j({'result': {'ok': true, 'count': rows.length, 'qty': rows.fold<num>(0, (x, r) => x + (r['qty'] as num)), 'stock': stock}});
        case 'saveDieselBulk':
          final b = (a[0] as Map).cast<String, dynamic>();
          importSent.add({'fn': action, 'b': b});
          final rows = [for (final r in b['rows'] as List) (r as Map).cast<String, dynamic>()];
          if (b['force'] != true && rows.any((r) => r['hrReading'] == '1')) return _j({'result': {'warnings': [{'row': 1, 'msg': 'The Hrs reading 1 is lower than the last one (4,700).'}]}});
          return _j({'result': {'ok': true, 'count': rows.where((r) => '${r['no']}'.isNotEmpty).length, 'firstId': 'DI-000527', 'lastId': 'DI-000527'}});
        case 'getStockPoints':
          return _j({'result': [for (final _ in a[0] as List) {'balance': 813, 'available': 813}]});
        case 'getInwards':
          return _j({'result': {'count': 1, 'qty': 500, 'stock': stock, 'rows': [{'id': 'IN-000050', 'date': '2026-10-14', 'qty': 500, 'pump': 'IOC Bunk', 'rate': 90, 'amount': 45000, 'billNo': 'B-1', 'billDate': '2026-10-14', 'location': 'VTR Store', 'ph': 2}]}});
        case 'getInwardPhotos': // (3.1.13, update-120) the bill copies of an inward
          return _j({'result': {'id': a[0], 'photos': [for (final n in [1, 2]) {'p': 'inward/2026-10/00000000-0000-0000-0000-00000000000$n.jpg', 'at': '2026-10-14T05:00:00.000Z', 'url': 'https://erp.test/storage/v1/object/sign/diesel-photos/inward/$n.jpg?token=t'}]}});
        case 'inwardPhoto':
          billsSent++;
          return _j({'result': {'ok': true, 'path': 'inward/2026-10/00000000-0000-0000-0000-0000000001${billsSent.toString().padLeft(2, '0')}.jpg'}});
        case 'saveInward':
          saved.add((a[0] as Map).cast<String, dynamic>());
          return _j({'result': {'ok': true, 'id': 'IN-000051', 'stock': stock}});
        case 'updateDieselIssue': // (Mechanical update-145: what is sent back – the version too)
          saved.add({'update': a[0], ...(a[1] as Map).cast<String, dynamic>()});
          return _j({'result': {'ok': true, 'id': a[0]}});
        case 'updateInward':
          saved.add({'update': a[0], ...(a[1] as Map).cast<String, dynamic>()});
          return _j({'result': {'ok': true, 'id': a[0], 'stock': stock}});
        case 'getTransfers':
          if (a.isNotEmpty && a[0] is Map) listAsked.add({'fn': action, ...(a[0] as Map).cast<String, dynamic>()});
          return _j({'result': {'count': 0, 'qty': 0, 'rows': []}});
        // (3.9.0) Administration
        case 'usersAdmin':
          return _j({'result': {'users': adminUsers, 'modules': [{'key': 'Dashboard', 'label': 'Dashboard'}, {'key': 'Log Book', 'label': 'Log Book', 'dateAdmin': true}, {'key': 'Machinery Billing', 'label': 'Machinery Billing'}], 'managedBySuper': usersBySuper, 'canCreateSuper': false}});
        case 'saveUserAdmin':
          adminSent.add({'fn': action, 'x': a[0]});
          final x = (a[0] as Map).cast<String, dynamic>();
          if (x['isNew'] == true) adminUsers.add({'email': x['email'], 'name': x['name'], 'active': x['active'], 'admin': x['admin'], 'mustChange': true, 'perms': x['perms']});
          return _j({'result': {'ok': true}});
        case 'accessReport':
          return _j({'result': {'users': 2, 'modules': 3, 'count': {'written': 5, 'empty': 1, 'admin': 3}, 'rows': [{'name': 'Site Clerk', 'email': 'clerk@rcl.test', 'active': true, 'admin': false, 'module': 'Machinery Billing', 'raw': '', 'effective': 'View', 'why': 'empty'}]}});
        case 'getActivity':
          adminSent.add({'fn': action, 'f': a[0]});
          return _j({'result': {'count': 2, 'rows': [
            {'id': 'L-2', 'when': '14-10-2026 10:12:03', 'email': 'clerk@rcl.test', 'name': 'Site Clerk', 'action': 'Edit', 'module': 'Log Book', 'record': 'MH-25-AJ-2169|2026-10-13|Full Day', 'summary': 'Log Book entry changed', 'changes': 'Close KM: 15100 → 15130; Work: Earth carting → Earth carting (Ch 12+000)'},
            {'id': 'L-1', 'when': '14-10-2026 09:01:44', 'email': 'sujit@rcl.test', 'name': 'Sujit Mule', 'action': 'Login', 'module': '', 'record': '', 'summary': 'Signed in (app)', 'changes': ''},
          ]}});
        // (3.74.0, Mechanical update-201) the site's own words for voice typing: the list, a correction learned, the Super Admin's save
        case 'getVoiceWords':
          return _j({'result': {'words': [...voiceAdmin, 'Mahalaxmi Bridge', 'Siddhappa Bhimu Basbire', 'Kaseli'], 'admin': voiceAdmin, 'fixes': voiceFixes, 'super': superAdmin}});
        case 'saveVoiceFix':
          voiceSent.add({'fn': action, 'x': a[0]});
          final x = (a[0] as Map).cast<String, dynamic>();
          final h = '${x['heard']}'.trim().toLowerCase(), f = '${x['fixed']}'.trim();
          voiceFixes = [...voiceFixes.where((y) => y['h'] != h), {'h': h, 'f': f, 'n': 1}];
          return _j({'result': {'ok': true, 'h': h, 'f': f}});
        case 'saveVoiceWords':
          voiceSent.add({'fn': action, 'x': a[0]});
          if (!superAdmin) return _j({'error': 'Only the Super Admin sets the site\'s words for voice typing (signed in through the Portal).'}, 500);
          final x = (a[0] as Map).cast<String, dynamic>();
          voiceAdmin = [for (final w in (x['words'] as List? ?? const [])) '$w'];
          voiceFixes = [for (final y in (x['fixes'] as List? ?? const [])) {'h': '${(y as Map)['h']}', 'f': '${y['f']}', 'n': 1}];
          return _j({'result': {'ok': true, 'words': voiceAdmin.length, 'fixes': voiceFixes.length}});
        case 'saveSiteRules':
          adminSent.add({'fn': action, 'x': a[0]});
          final r = (a[0] as Map).cast<String, dynamic>();
          return _j({'result': {'ok': true, 'rules': {'backDays': r['backDays'] == '' ? '' : int.parse('${r['backDays']}'), 'announce': r['announce'], 'dayFrom': r['dayFrom'], 'nightFrom': r['nightFrom']}}});
        case 'saveOrgSettings':
          adminSent.add({'fn': action, 'x': a[0]});
          return _j({'result': {'ok': true, 'org': a[0]}});
        case 'rtcRights':
          return _j({'result': {'users': [{'uid': 'u1', 'name': 'Site Clerk', 'admin': false, 'on': true}, {'uid': 'u2', 'name': 'Sujit Mule', 'admin': true, 'on': true}]}});
        case 'rtcRightsSave':
          adminSent.add({'fn': action, 'x': a[0]});
          return _j({'result': {'users': [{'uid': 'u1', 'name': 'Site Clerk', 'admin': false, 'on': false}, {'uid': 'u2', 'name': 'Sujit Mule', 'admin': true, 'on': true}]}});
        case 'dbHealth':
          return _j({'result': {'ok': false, 'at': '2026-10-14T05:00:00.000Z', 'checks': [{'name': 'Database answers', 'ok': true, 'fix': '', 'note': ''}, {'name': '"½ day" in the Log Book (step 1v)', 'ok': false, 'fix': 'supabase_step1v_half_day.sql', 'note': ''}]}});
        case 'readme':
          return _j({'result': {'html': _readme, 'adminCols': [{'col': 'email'}, {'col': 'name'}, {'col': 'password_hash'}, {'col': 'active'}, {'col': 'admin'}, {'col': 'perm_dashboard'}, {'col': 'mobile'}]}});
        // (3.8.0) Billing
        case 'getLogBookList' when billing && _arg(a, 'all') == true:
          billSent.add({'fn': action, 'args': a});
          return _j({'result': {'count': 6, 'rows': _billRows, 'summary': []}});
        case 'logPrintExtra' when billing:
          billSent.add({'fn': action, 'args': a});
          return _j({'result': {..._billExtra, if (tankRule) 'checks': {if (tankClose != null) 'MH25AJ2169': {'close': tankClose}}}});
        case 'saveBillTankCheck':
          billSent.add({'fn': action, 'x': a[0]});
          final ph = ((a[0] as Map)['physical'] as num?) ?? 0;
          tankClose = {'id': 'TC-00009', 'date': (a[0] as Map)['to'], 'physical': ph, 'system': 37.14, 'method': 'Measured in tank'};
          return _j({'result': {'ok': true, 'id': 'TC-00009', 'no': (a[0] as Map)['no'], 'date': (a[0] as Map)['to'], 'system': 37.14, 'physical': ph, 'diff': ph - 37.14, 'expect': 37.14, 'short': ph < 37.14 ? ((37.14 - ph) * 100).round() / 100 : 0, 'replaced': ''}});
        case 'billInit':
          return _j({'result': _billInit});
        case 'billCorrections':
          billSent.add({'fn': action, 'args': a});
          return _j({'result': {'items': []}});
        case 'verifyBills':
          final bs = ((a[0] as Map)['bills'] as List).cast<Map>();
          billSent.add({'fn': action, 'bills': bs});
          return _j({'result': {'bills': [
            for (final b in bs) {'vendor': (b['vendor'] as Map)['name'], 'billNo': b['billNo'], 'net': b['I'], 'bad': 0, 'warn': 1, 'checks': [{'s': 'ok', 't': 'Log Book, diesel and BOQ match the bill'}, {'s': 'warn', 't': 'Idle days paid in this bill'}]}
          ]}});
        case 'submitBills':
          billSent.add({'fn': action, 'x': a[0]});
          return _j({'result': {'ok': true, 'saved': [for (var i = 0; i < ((a[0] as Map)['bills'] as List).length; i++) {'id': 'BILL-0000${9 + i}', 'rev': 0}]}});
        case 'getBills' when _arg(a, 'id') != null:
          return _j({'result': {'bills': []}}); // (a test does not open the print view)
        case 'getBills':
          billSent.add({'fn': action, 'args': a});
          return _j({'result': {'bills': _savedBills}});
        case 'getDebitNotes':
          return _j({'result': {'notes': [
            {'id': 'DN-0003', 'no': 'SLI/TST/DN-3', 'date': '2026-09-28', 'vendor': 'I E Enterprises', 'company': 'Sketchline Industries', 'kind': 'Work', 'billNo': '', 'from': '2026-09-20', 'to': '2026-09-21', 'total': 1500, 'status': 'Active'},
          ]}});
        case 'getLookups':
          return _j({'result': {'vendors': ['I E Enterprises', 'Chalke Enterprises']}});
        case 'getDebitPending':
          billSent.add({'fn': action, 'args': a});
          return _j({'result': {'vendor': 'I E Enterprises', 'already': 0, 'rows': [{'logId': 'MH-25-AJ-2169|2026-10-02|Day', 'no': 'MH-25-AJ-2169', 'type': 'Tipper', 'date': '2026-10-02', 'shift': 'Day', 'work': 'Carting for the party', 'qty': 6, 'unit': 'Hrs', 'rate': 1100}]}});
        case 'saveDebitNote':
          billSent.add({'fn': action, 'x': a[0]});
          return _j({'result': {'ok': true, 'no': 'SLI/TST/DN-4', 'vendor': (a[0] as Map)['vendor'], 'total': 6600}});
        case 'vendorLedger':
          billSent.add({'fn': action, 'args': a});
          return _j({'result': _ledger});
        case 'billSummary':
          return _j({'result': {'rows': [
            {'id': 'BILL-00001', 'vendor': 'I E Enterprises', 'company': 'Sketchline Industries', 'billNo': '7', 'rev': 0, 'from': '2026-08-01', 'to': '2026-08-31', 'billDate': '2026-09-05', 'month': '2026-08', 'basic': 45000, 'diesel': 3200, 'other': 0, 'gst': 0, 'gstPct': 0, 'tds': 549.5, 'tdsPct': 1.32, 'net': 41250.5},
          ]}});
        case 'getPayments':
          return _j({'result': {'payments': [
            {'id': 'PAY-00001', 'type': 'Payment', 'date': '2026-09-25', 'vendor': 'I E Enterprises', 'amount': 40000, 'side': 'Payable', 'mode': 'NEFT', 'ref': 'UTR123', 'bill': 'RA 7 (01-08-2026 – 31-08-2026)', 'remark': '', 'enteredBy': 'Tester', 'updatedBy': ''},
          ], 'modes': ['NEFT', 'RTGS', 'IMPS', 'UPI', 'Cheque', 'Cash', 'Adjustment']}});
        case 'savePayment':
          billSent.add({'fn': action, 'x': a[0], 'how': a[1]});
          return _j({'result': {'ok': true, 'id': 'PAY-00002', 'amount': num.tryParse('${(a[0] as Map)['amount']}') ?? 0}});
        case 'vendorOutstanding':
          return _j({'result': {'months': ['2026-08', '2026-09', '2026-10'], 'rows': [
            {'vendor': 'I E Enterprises', 'opening': 5000, 'bills': 39750.5, 'paid': 40000, 'closing': 4750.5, 'monthEnd': [5000, 4750.5, 4750.5], 'lastPay': '2026-09-25'},
          ]}});
        case 'getLogBookList' when ((a.isNotEmpty ? a[0] : null) as Map?)?['no'] == 'MH-25-AJ-2169':
          return _j({'result': {'count': 3, 'rows': _editRows, 'summary': []}});
        // (3.6.0) Edit Log Book
        case 'getLogEditData':
          logBulk.add({'fn': action, 'args': a});
          return _j({'result': _editData('${a[1]}', '${a[2]}')});
        case 'saveLogBulk':
          logBulk.add({'fn': action, 'x': a[0]});
          final rs = ((a[0] as Map)['rows'] as List).cast<Map>();
          return _j({'result': {'ok': true, 'no': (a[0] as Map)['no'], 'changed': rs.where((r) => r['same'] != true && '${r['key']}'.isNotEmpty).length, 'added': rs.where((r) => '${r['key']}'.isEmpty).length, 'deleted': ((a[0] as Map)['deleted'] as List).length, 'shifted': 0}});
        case 'getTankerRange':
          logBulk.add({'fn': action, 'args': a});
          return _j({'result': _tankerRange('${a[1]}', '${a[2]}', _tTrips)});
        case 'saveTankerRange':
          logBulk.add({'fn': action, 'x': a[0]});
          return _j({'result': {..._tankerRange('${(a[0] as Map)['from']}', '${(a[0] as Map)['to']}', (a[0] as Map)['trips'] as List), 'ok': true, 'changed': 1, 'added': 1, 'removed': 0}});
        // (3.13.0) a water tanker's trips from a file
        case 'checkTankerImport':
          logBulk.add({'fn': action, 'x': a[0]});
          return _j({'result': {'ok': true, 'errors': [], 'added': 2, 'same': 1, 'tankers': 1}});
        case 'importTankerTrips':
          logBulk.add({'fn': action, 'x': a[0]});
          return _j({'result': {'ok': true, 'added': 2, 'same': 1}});
        case 'logPrintExtra':
          return _j({'result': {'debit': {}, 'boq': {}, 'issues': {}, 'avgRate': 90, 'lastRate': 92}});
        // (3.12.0) Log Book – all dates (the web's list filter has "ownership"), the import
        case 'getLogBookList' when ((a.isNotEmpty ? a[0] : null) as Map?)?.containsKey('ownership') == true:
          listAsked.add({'fn': action, ...(a[0] as Map).cast<String, dynamic>()});
          return _j({'result': {'count': 3, 'rows': [
            {'date': '2026-10-14', 'no': 'Sany 210 (No.1)', 'type': 'Excavator', 'owner': 'RCL', 'shift': 'Full Day', 'unit': 'Hrs', 'mode': 'Hrs', 'ohr': 4692, 'chr': 4700, 'whr': 8, 'wkm': '', 'okm': '', 'ckm': '', 'qty': 60, 'work': 'Excavation', 'chFrom': '12+000', 'chTo': '12+300', 'key': 'Sany 210 (No.1)|2026-10-14|Full Day'},
            {'date': '2026-10-14', 'no': 'MH-25-AJ-2169', 'type': 'Tipper', 'owner': 'I E Enterprises', 'shift': 'Full Day', 'unit': 'KM', 'mode': 'KM', 'okm': 15100, 'ckm': 15230, 'wkm': 130, 'whr': '', 'ohr': '', 'chr': '', 'qty': 80, 'work': 'Earth carting', 'key': 'MH-25-AJ-2169|2026-10-14|Full Day'},
            {'date': '2026-10-13', 'no': 'MH-25-AJ-2169', 'type': 'Tipper', 'owner': 'I E Enterprises', 'shift': 'Full Day', 'unit': 'KM', 'mode': 'KM', 'okm': 14970, 'ckm': 15100, 'wkm': 130, 'whr': '', 'ohr': '', 'chr': '', 'qty': 0, 'work': 'Earth carting', 'key': 'MH-25-AJ-2169|2026-10-13|Full Day'},
          ], 'totals': {'machines': 2, 'km': 260, 'hr': 8, 'issued': 140, 'consumed': 186.29}, 'summary': [
            {'no': 'MH-25-AJ-2169', 'type': 'Tipper', 'unit': 'KM', 'days': 2, 'okm': 14970, 'ckm': 15230, 'ohr': '', 'chr': '', 'firstDate': '2026-10-13', 'lastDate': '2026-10-14', 'km': 260, 'hr': 0, 'issued': 80, 'consumed': 74.29, 'diff': 5.71, 'average': '3.25 km/L', 'kmStd': 3.5, 'hrStd': ''},
            {'no': 'Sany 210 (No.1)', 'type': 'Excavator', 'unit': 'Hrs', 'days': 1, 'okm': '', 'ckm': '', 'ohr': 4692, 'chr': 4700, 'firstDate': '2026-10-14', 'lastDate': '2026-10-14', 'km': 0, 'hr': 8, 'issued': 60, 'consumed': 112, 'diff': -52, 'average': '7.5 L/hr', 'kmStd': '', 'hrStd': 14},
          ], 'itemBoq': {}}});
        case 'checkLogImport':
          importSent.add({'fn': action, 'x': a[0]});
          final rs = [for (final r in (a[0] as Map)['rows'] as List) (r as Map).cast<String, dynamic>()];
          return _j({'result': {'ok': true, 'errors': [], 'fresh': rs.length - 1, 'same': 0, 'changed': [
            {'line': rs.last['line'], 'no': rs.last['no'], 'date': rs.last['date'], 'shift': rs.last['shift'], 'diffs': [{'f': 'Close Hrs', 'from': 4700, 'to': rs.last['closingHr']}]},
          ]}});
        case 'importLogBook':
          importSent.add({'fn': action, 'x': a[0]});
          final rs = (a[0] as Map)['rows'] as List;
          final ow = (a[0] as Map)['overwrite'] == true;
          return _j({'result': {'ok': true, 'added': rs.length - 1, 'overwritten': ow ? 1 : 0, 'same': 0, 'changed': ow ? [] : [{}]}});
        case 'getLogBookList':
          return _j({'result': {'count': 6, 'rows': [
            {'no': 'Sany 210 (No.1)', 'type': 'Excavator', 'owner': 'RCL', 'shift': 'Full Day', 'mode': 'Hrs', 'ohr': 4692, 'chr': 4700, 'whr': 8, 'qty': 60, 'work': 'Excavation', 'chFrom': '12+000', 'chTo': '12+300', 'key': 'Sany 210 (No.1)|2026-10-14|Full Day'},
            {'no': 'MH-25-AJ-2169', 'type': 'Tipper', 'owner': 'I E Enterprises', 'shift': 'Full Day', 'mode': 'KM', 'okm': 15100, 'ckm': 15230, 'wkm': 130, 'qty': 80, 'work': 'Earth carting', 'key': 'MH-25-AJ-2169|2026-10-14|Full Day'},
            for (final n in ['A', 'B', 'C']) {'no': n, 'type': 'Tipper', 'mode': 'Trip', 'trip': 6, 'shift': 'Day', 'key': '$n|2026-10-14|Day'},
            {'no': 'D', 'type': 'Roller', 'mode': 'Idle', 'shift': 'Full Day', 'key': 'D|2026-10-14|Full Day'},
            if (tanker)
              {'no': 'MH-04-J-9844', 'type': 'Water Tanker', 'owner': 'Chalke Enterprises', 'date': '2026-10-14', 'shift': 'Day', 'unit': 'Trip', 'mode': 'Trip', 'trip': 2, 'challan': '123, 18522', 'key': 'MH-04-J-9844|2026-10-14|Day',
                'itemWork': {'_trips': [for (final t in _tTrips) {'c': t['c'], 'a': t['a'], 'b': t['b'], if ('${t['ch']}'.isNotEmpty) 'ch': t['ch'], if ('${t['u']}'.isNotEmpty) 'u': t['u']}]}},
            if (tanker2)
              {'no': 'MH-12-AB-1001', 'type': 'Water Tanker', 'owner': 'Patil Water Supply', 'date': '2026-10-13', 'shift': 'Night', 'unit': 'Trip', 'mode': 'Trip', 'trip': 1, 'challan': 'P-7', 'key': 'MH-12-AB-1001|2026-10-13|Night',
                'itemWork': {'_trips': [{'c': 'P-7', 'a': '21:10', 'b': '21:40', 'u': 'Curing'}]}},
          ]}});
        // (3.59.0, Mechanical update-185) a look-up of the assistant run by the server – as aiLookup_: an unknown one or a vendor not of
        // the site refused (its words)
        case 'aiLookup':
          final x = (a[0] as Map).cast<String, dynamic>();
          aiLookups.add(x);
          if ('${(x['args'] as Map?)?['vendor'] ?? ''}'.isNotEmpty && !vendors.any((v) => v['name'] == (x['args'] as Map)['vendor'])) return _j({'error': '"${(x['args'] as Map)['vendor']}" is not a vendor of this site – say which one.'}, 500);
          final ans = aiLookupAnswers['${x['name']}'];
          if (ans == null) return _j({'error': 'There is no such look-up.'}, 500);
          return _j({'result': ans});
        // (3.61.0, Mechanical update-186) his chats and the memory of him – only his (as aiChatSave_ / aiChats_ / aiMemory_ …)
        case 'aiChatSave':
          final x = (a[0] as Map).cast<String, dynamic>();
          if (!aiStep) return _j({'result': {'kept': false}});
          final msgs = (x['msgs'] as List).whereType<Map>().toList(), first = msgs.where((m) => m['r'] == 'me').firstOrNull;
          final had = aiChats['${x['id']}'];
          if (had != null && (had['n'] as int) > msgs.where((m) => m['r'] == 'me').length) return _j({'result': {'kept': false, 'id': x['id'], 'newer': true}});
          aiChats['${x['id']}'] = {'id': x['id'], 'title': first == null ? '' : '${first['t']}', 'msgs': msgs, 'n': msgs.where((m) => m['r'] == 'me').length, 'at': '2026-10-14T05:${30 + aiSaves++}:00Z'};
          return _j({'result': {'kept': true, 'id': x['id']}});
        case 'aiChats':
          if (!aiStep) return _j({'result': {'on': false, 'chats': [], 'msg': 'The assistant\'s memory and its chats need one database step first: the Admin runs sql/supabase_step1zk_ai_memory.sql once in Supabase → SQL Editor (in every site).'}});
          final list = aiChats.values.toList()..sort((p, q) => '${q['at']}'.compareTo('${p['at']}'));
          return _j({'result': {'on': true, 'chats': [for (final c in list) {'id': c['id'], 'title': c['title'], 'n': c['n'], 'at': c['at']}]}});
        case 'aiChatGet':
          final c = aiChats['${(a[0] as Map)['id']}'];
          if (c == null) return _j({'error': 'This chat is not there.'}, 500);
          return _j({'result': c});
        case 'aiMemory':
          if (!aiStep) return _j({'result': {'on': false, 'notes': [], 'msg': 'The assistant\'s memory and its chats need one database step first: the Admin runs sql/supabase_step1zk_ai_memory.sql once in Supabase → SQL Editor (in every site).'}});
          return _j({'result': {'on': true, 'notes': aiMemory}});
        case 'aiMemoryDel':
          final id = (a[0] as Map)['id'];
          if (!aiMemory.any((m) => m['id'] == id)) return _j({'error': 'Note $id is not in the memory of the assistant for you.'}, 500);
          aiMemory.removeWhere((m) => m['id'] == id);
          return _j({'result': {'forgotten': true, 'id': id}});
        case 'getAiReply':
          aiAsked.add((a[0] as Map).cast<String, dynamic>());
          if (!aiOn) return _j({'error': 'The assistant is not set up yet: the Admin has to put the AI key (ANTHROPIC_API_KEY – Claude) in the server\'s settings.'}, 500);
          return _j({'result': aiScript.isNotEmpty ? aiScript.removeAt(0) : {'parts': [{'text': 'Nothing more to say.'}], 'model': 'claude-sonnet-5-5'}});
        case 'getBrief':
          return _j({'result': brief});
        case 'getAiCheck':
          // (3.48.0, Mechanical update-167) the server's AI is Claude: it says which service, the models and what each said
          return _j({'result': {'key': aiOn, if (aiOn) 'service': 'Claude', 'fixedModel': '', 'listError': '', 'tests': [{'model': 'claude-sonnet-5-5', 'ok': true, 'ms': 1240}, {'model': 'claude-haiku-5-5', 'ok': false, 'code': 529, 'said': 'Overloaded'}]}});
        case 'getMyPrefs':
          return _j({'result': {'prefs': prefs, 'logins': ['2026-10-14T03:35:00Z', '2026-10-13T12:10:00Z'], 'rules': {'backDays': '', 'announce': notice, 'dayFrom': '08:00', 'nightFrom': '20:00'}}});
        // (3.14.0) the diesel history of a machinery, the photos of a fill, a transfer's stock, the Admin's faults and backup
        case 'dieselHistory':
          extraCalls.add({'fn': action, 'x': a[0]});
          final no = '${(a[0] as Map)['no']}';
          return _j({'result': no == 'MH-25-AJ-2169'
              ? {'no': no, 'unit': 'KM', 'date': (a[0] as Map)['date'], 'rows': [{'id': 'DI-000520', 'date': '2026-10-13', 'shift': 'Day', 'qty': 80, 'km': 15100, 'hr': '', 'source': 'Dispenser', 'driver': 'Ramesh'}], 'total': 7, 'lastKm': {'value': 15100, 'date': '2026-10-13'}, 'lastHr': null, 'month': {'qty': 520, 'count': 7}}
              : {'no': no, 'unit': '', 'date': (a[0] as Map)['date'], 'rows': [], 'total': 0, 'lastKm': null, 'lastHr': null, 'month': {'qty': 0, 'count': 0}}});
        case 'getDieselPhotos':
          extraCalls.add({'fn': action, 'id': a[0]});
          return _j({'result': {'id': a[0], 'no': 'Sany 210 (No.1)', 'date': '2026-10-14', 'shift': 'Day', 'qty': 60, 'photos': [
            {'k': 'dash', 'label': 'Dashboard (reading)', 'at': '2026-10-14T03:30:00Z', 'lat': 18.52, 'lng': 73.85, 'acc': 12, 'url': ''},
            {'k': 'pump', 'label': 'Dispenser (litres)', 'at': '2026-10-14T03:31:00Z', 'lat': '', 'lng': '', 'acc': '', 'url': ''},
          ]}});
        case 'getTransferBalance':
          extraCalls.add({'fn': action, 'args': a});
          return _j({'result': {'from': {'balance': 900, 'available': 850}, 'to': {'balance': 300, 'available': 300}}});
        case 'getErrors':
          return _j({'result': {'stamp': {'day': '2026-10-14', 'n': 1, 'at': '2026-10-14T05:00:00Z', 'last': 'getStock: x is undefined'}, 'errors': faults}});
        case 'clearErrors':
          extraCalls.add({'fn': action});
          faults.clear();
          return _j({'result': {'ok': true}});
        case 'reportError':
          extraCalls.add({'fn': action, 'x': a[0]});
          return _j({'result': {'ok': true}});
        case 'globalSearch':
          extraCalls.add({'fn': action, 'q': a[0]});
          final gq = '${a[0]}'.toUpperCase();
          return _j({'result': {
            'issues': gq.contains('525') ? [{'id': 'DI-000525', 'date': '2026-10-14', 'shift': 'Day', 'no': 'Sany 210 (No.1)', 'qty': 60, 'driver': 'Gupta', 'source': 'VTR Store', 'why': 'Issue ID'}] : [],
            'logs': [], 'inwards': [], 'transfers': [], 'tanks': [], 'breakdowns': [], 'bills': [], 'notes': [], 'payments': [], 'boqs': [], 'papers': [],
            'vendors': gq.contains('ENTERPRI') ? [{'name': 'I E Enterprises', 'gst': '', 'ownership': 'Rental', 'machines': 1, 'why': 'Vendor'}] : [],
            'counts': {'issues': gq.contains('525') ? 3 : 0}, 'fixes': gq.contains('ENTERPRIZE') ? [{'w': 'ENTERPRIZE', 'to': 'ENTERPRISES'}] : [],
          }});
        case 'backupNow':
          extraCalls.add({'fn': action});
          return _j({'result': {'ok': true, 'lines': [['diesel_issue', '3 rows'], ['log_book', '5 rows']], 'pending': 0, 'info': {'ok': true, 'lastCheck': '2026-10-14T05:10:00Z', 'url': 'https://docs.google.com/spreadsheets/d/x'}}});
        case 'saveMyPrefs':
          prefs = {...prefs, ...(a[0] as Map).cast<String, dynamic>()};
          return _j({'result': {'ok': true, 'prefs': prefs}});
        case 'getMeterReading':
          return _j({'result': (a[0] as Map)['kind'] == 'dash' ? {'hr': 4712.5, 'check': ''} : {'litres': 60}});
        case 'logPending':
          dashAsked.add({'fn': action, 'args': a}); // (3.54.0) what was asked: a period for its Print
          return _j({'result': {'items': [['OLD-9', '2026-10-14'], ['MH-25-AJ-2169', '2026-10-14'], ['MH-25-AJ-2169', '2026-10-13']]}});
        case 'getLogRowPrefill':
          final no = a[0] as String, askAdd = a.length > 3 && a[3] is Map && (a[3] as Map)['add'] == 1;      // (3.31.2: the app asks for the "add" answer)
          if (addTo != null && !askAdd) throw StateError('getLogRowPrefill without {add: 1}');
          return _j({'result': {'machine': {'id': no}, 'problem': '', 'first': false, 'openingKm': no == 'MH-25-AJ-2169' ? 15230 : '', 'openingHr': no.startsWith('Sany') ? (addTo != null ? addTo!['closeHr'] : 4700) : '', 'firstKm': false, 'firstHr': false,
            'lastDate': '2026-10-13', 'lastShift': 'Full Day', 'diesel': 80, 'dieselText': 'DI-000520', 'reads': [], 'boqItems': [], 'avgWork': {'km': 120, 'hr': '', 'src': 'own'},
            if (addTo != null) 'addTo': addTo}});
        case 'saveLogRows':
          final rows = ((a[0] as Map)['rows'] as List).map((x) => (x as Map).cast<String, dynamic>()).toList();
          logSaved.addAll(rows);
          return _j({'result': {'ok': true, 'count': rows.length, if (addTo != null) 'added': rows.length, if (addTo != null) 'into': 1}});
        case 'getLogEntry':
          return _j({'result': {'key': a[0], 'no': 'MH-25-AJ-2169', 'date': '2026-10-14', 'shift': 'Full Day', 'unit': 'KM', 'okm': 15100, 'ckm': 15230, 'ohr': '', 'chr': '', 'work': 'Earth carting', 'chFrom': '12+000', 'chTo': '12+500', 'first': false, 'boqItems': [], 'itemWork': {}, 'lock': null, 'next': null, 'prev': {'date': '2026-10-13', 'shift': 'Full Day'}, if (entryAtt.isNotEmpty) 'att': entryAtt}});
        case 'uploadAttachment':
          final up = (a[0] as Map).cast<String, dynamic>(), m = RegExp(r'^data:(image/jpeg|image/png|application/pdf);base64,(.+)$').firstMatch('${up['data']}');
          if (m == null) return _j({'error': 'An attachment must be a photo (JPG or PNG) or a PDF.'}, 500);
          final raw = base64Decode(m.group(2)!), sha = crypto.sha256.convert(raw).toString(), ext = m.group(1) == 'application/pdf' ? 'pdf' : m.group(1) == 'image/png' ? 'png' : 'jpg';
          uploads.add({'sha': sha, 'mime': m.group(1), 'size': raw.length, 'name': up['name']});
          return _j({'result': {'ok': true, 'sha': sha, 'path': 'log/${sha.substring(0, 2)}/$sha.$ext', 'mime': m.group(1), 'size': raw.length, 'name': up['name'], 'dup': false}});
        // (3.46.0, Mechanical update-165) the maintenance bills
        case 'getMaint':
          final f = (a[0] as Map).cast<String, dynamic>();
          maintCalls.add({'fn': action, 'x': f});
          // (3.50.0, Mechanical update-170) at every site
          if (maintMissing) return _j({'result': {'rows': [], 'total': 0, 'count': 0, 'works': [], 'garages': [], 'missing': true}});
          final rs = maint.where((r) => '${f['no'] ?? ''}'.isEmpty || r['no'] == f['no']).toList();
          return _j({'result': {'count': rs.length, 'total': rs.fold<num>(0, (t, r) => t + (r['total'] as num)), 'rows': rs, 'works': ['Engine oil', 'Discount', 'GST 18%', 'Labour', 'Oil filter', 'Tyre'], 'garages': ['Toyota Service', 'Tyre House']}});
        case 'saveMaint' || 'updateMaint':
          final x = ((action == 'saveMaint' ? a[0] : a[1]) as Map).cast<String, dynamic>();
          maintCalls.add({'fn': action, if (action == 'updateMaint') 'id': a[0], 'x': x});
          if (x['service'] == true && '${x['km']}'.isEmpty) return _j({'error': '${x['no']}: a service needs its KM reading – the next service is counted from it.'}, 500);
          if (x['force'] != true && maint.any((r) => r['id'] != (action == 'updateMaint' ? a[0] : '') && r['no'] == x['no'] && '${r['billNo']}' == '${x['billNo']}' && '${r['garage']}' == '${x['garage']}')) {
            final was = maint.firstWhere((r) => r['no'] == x['no'] && '${r['billNo']}' == '${x['billNo']}');
            return _j({'result': {'ok': false, 'warning': 'Bill ${x['billNo']} of ${x['garage']} for ${x['no']} is already saved (${was['id']}). Save it again?'}});
          }
          // (3.49.0, Mechanical update-168) as the server: a line's kind; the bill = its Paid lines; a claim – the insurance's part,
          // not more than the bill; the bill's Amount = what we paid; a free line's worth
          // (3.51.0, update-171) Paid by: RCL ('Paid') / Insurance ('By Insurance') are charged; a line's GST % (CGST and SGST half each,
          // each rounded); the lines paid by the insurance are the insurance's part of the bill
          const kinds = ['Paid', 'By Insurance', 'Warranty', 'FOC', 'Service Plan'];
          bool charged(Map l) => (l['type'] ?? 'Paid') == 'Paid' || l['type'] == 'By Insurance';
          num r2(num v) => (v * 100).round() / 100;
          // (3.59.0, Mechanical update-183) a line's GST ₹ as in the old log book (gstAmt, no GST %)
          num withGst(Map l) => charged(l) ? r2((l['amount'] as num) + (_hasGa(l) ? l['gstAmt'] as num : 2 * r2((l['amount'] as num) * (l['gst'] is num ? l['gst'] as num : 0) / 200))) : 0;
          final ls = [for (final l in (x['lines'] as List)) (l as Map).cast<String, dynamic>()];
          // (as the server: a page / an app of before – no gstAmt sent – may not change a bill whose lines keep their GST ₹ of the old log book)
          if (action == 'updateMaint' && ls.isNotEmpty && ls.every((l) => !l.containsKey('gstAmt')) && [for (final l in (maint.firstWhere((r) => r['id'] == a[0])['lines'] as List)) l as Map].any(_hasGa)) {
            return _j({'error': 'Bill ${a[0]} keeps the GST amounts of the old log book as they are – update the app to change it.'}, 500);
          }
          for (final (i, l) in ls.indexed) {
            if (l.containsKey('type') && !kinds.contains(l['type'])) return _j({'error': 'Bill line ${i + 1} (${l['work']}): Paid by is RCL, Insurance, Warranty, FOC or Service Plan.'}, 500);
            if (l['gst'] is num && ((l['gst'] as num) < 0 || (l['gst'] as num) > 100)) return _j({'error': 'Bill line ${i + 1} (${l['work']}): the GST is 0 to 100 %.'}, 500);
          }
          final bill = r2(ls.fold<num>(0, (t, l) => t + withGst(l))), byIns = r2(ls.fold<num>(0, (t, l) => t + (l['type'] == 'By Insurance' ? withGst(l) : 0)));
          final ins = x['insurance'] is Map ? {...(x['insurance'] as Map).cast<String, dynamic>(), if (byIns > 0) 'paid': byIns} : null;
          if (byIns > 0 && (ins == null || '${ins['company'] ?? ''}'.isEmpty)) return _j({'error': 'The insurance part of the bill: type the insurance company.'}, 500);
          if (ins != null && (ins['paid'] is! num || (ins['paid'] as num) > bill)) return _j({'error': 'The insurance part of the bill: the insurance paid ₹${ins['paid']} – more than the bill (₹$bill).'}, 500);
          final tot = r2(bill - (ins == null ? 0 : ins['paid'] as num));
          final free = ls.fold<num>(0, (t, l) => t + (charged(l) ? 0 : ((l['qty'] is num ? l['qty'] as num : 1) * (l['rate'] is num ? l['rate'] as num : 0))));
          final id = action == 'saveMaint' ? 'MT-00000${maint.length + 1}' : '${a[0]}';
          final row = {'id': id, ...x, 'insurance': ins, 'total': tot, 'billTotal': bill, 'free': free, 'files': [for (final f in (x['files'] as List)) {'sha': (f as Map)['sha']}]}..remove('force');
          if (action == 'saveMaint') { maint.insert(0, row); } else { maint[maint.indexWhere((r) => r['id'] == id)] = row; }
          return _j({'result': {'ok': true, 'id': id, 'total': tot, 'billTotal': bill}});
        case 'deleteMaint':
          maintCalls.add({'fn': action, 'id': a[0]});
          maint.removeWhere((r) => r['id'] == a[0]);
          return _j({'result': {'ok': true}});
        case 'maintFile':
          final up = (a[0] as Map).cast<String, dynamic>(), m = RegExp(r'^data:(image/jpeg|image/png|application/pdf);base64,(.+)$').firstMatch('${up['data']}');
          maintCalls.add({'fn': action, 'name': up['name']});
          if (m == null) return _j({'error': 'An attachment must be a photo (JPG or PNG) or a PDF.'}, 500);
          final raw = base64Decode(m.group(2)!), sha = crypto.sha256.convert(raw).toString(), ext = m.group(1) == 'application/pdf' ? 'pdf' : m.group(1) == 'image/png' ? 'png' : 'jpg';
          return _j({'result': {'ok': true, 'sha': sha, 'path': 'log/${sha.substring(0, 2)}/$sha.$ext', 'mime': m.group(1), 'size': raw.length, 'name': up['name'], 'dup': false}});
        case 'getMaintFiles':
          maintCalls.add({'fn': action, 'id': a[0]});
          final r = maint.firstWhere((r) => r['id'] == a[0]);
          return _j({'result': {'id': a[0], 'files': [for (final f in (r['files'] as List)) {...(f as Map), 'url': ''}]}});
        case 'readMaintBill':
          final up = (a[0] as Map).cast<String, dynamic>();
          maintCalls.add({'fn': action, 'mime': RegExp(r'^data:([^;]+);').firstMatch('${up['data']}')?.group(1) ?? ''});
          if (!aiOn) return _j({'result': {'off': true}});
          return _j({'result': maintRead});
        // (3.53.0, Mechanical update-173) the old log book imported as it is – as the server: only an Own machinery on the site now;
        // a bill's date a real one up to today; a ₹0 line without its kind kept as FOC; a bill already there (the same machinery,
        // date and party, its total to ₹1) – and the same bill twice in the file – left out; Check saves nothing
        case 'checkMaintImport' || 'importMaint':
          final x = (a[0] as Map).cast<String, dynamic>(), bills = [for (final b in (x['bills'] as List? ?? const [])) (b as Map).cast<String, dynamic>()];
          maintCalls.add({'fn': action, 'no': x['no'], 'bills': bills.length, 'garages': [for (final b in bills) b['garage']]});
          final m = _master.where((m) => m['id'] == x['no']).firstOrNull;
          if (m == null || m['ownership'] != 'Own' || m['status'] == 'Inactive') return _j({'error': '${x['no']} is not an Own machinery on this site now (Asset Master) – the old log book is imported only for those.'}, 500);
          if (bills.isEmpty) return _j({'error': 'The file has no bill for ${x['no']}.'}, 500);
          num r2(num v) => (v * 100).round() / 100;
          num lineTot(Map l) => r2((l['amount'] is num ? l['amount'] as num : 0) + (_hasGa(l) ? l['gstAmt'] as num : 2 * r2((l['amount'] is num ? l['amount'] as num : 0) * (l['gst'] is num ? l['gst'] as num : 0) / 200)));      // (3.59.0: its GST ₹ as in the old log book)
          // (28-10-2026) already there = the same machinery and date, its total to ₹1 (above ₹0) – whatever its party is called
          final have = [for (final r in maint) if (r['no'] == x['no']) (date: '${r['date']}', id: '${r['id']}', total: (r['billTotal'] ?? r['total']) as num)];
          final sameList = <Map<String, dynamic>>[];
          final errors = <Map<String, dynamic>>[], fresh = <Map<String, dynamic>>[];
          var same = 0;
          for (final (n, b) in bills.indexed) {
            final where = '${b['rows'] ?? 'Bill ${n + 1}'}', d = '${b['date'] ?? ''}';
            if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(d) || d.compareTo('2026-10-14') > 0) {
              errors.add({'rows': where, 'msg': 'Maintenance bill: the date "$d" is not a date up to today.'});
              continue;
            }
            final ls = [for (final l in (b['lines'] as List? ?? const [])) {...(l as Map).cast<String, dynamic>(), if ('${l['type'] ?? ''}'.isEmpty && (l['amount'] ?? 0) == 0) 'type': 'FOC'}];
            if (ls.isEmpty) {
              errors.add({'rows': where, 'msg': 'Type at least one work / part line of the bill.'});
              continue;
            }
            final tot = r2(ls.fold<num>(0, (t, l) => t + (l['type'] == 'FOC' ? 0 : lineTot(l))));
            final h = have.where((z) => z.date == d && tot > 0 && (z.total - tot).abs() <= 1).firstOrNull;
            if (h != null) {
              same++;
              sameList.add({'rows': where, 'date': d, 'total': tot, 'id': h.id});
              continue;
            }
            have.add((date: d, id: '($where)', total: tot));
            fresh.add({'date': d, 'garage': '${b['garage'] ?? ''}', 'km': b['km'] ?? '', 'lines': ls, 'total': tot});
          }
          final days = [for (final v in fresh) '${v['date']}']..sort();
          final report = {'ok': errors.isEmpty, 'no': x['no'], 'errors': errors, 'errorCount': errors.length, 'fresh': fresh.length, 'same': same, 'sameList': sameList,
            'lines': fresh.fold<int>(0, (t, v) => t + (v['lines'] as List).length), 'total': r2(fresh.fold<num>(0, (t, v) => t + (v['total'] as num))), 'from': days.isEmpty ? '' : days.first, 'to': days.isEmpty ? '' : days.last};
          if (errors.isNotEmpty || action == 'checkMaintImport') return _j({'result': report});
          final ids = <String>[];
          for (final v in fresh) {
            final id = 'MT-${'${maint.length + 1}'.padLeft(6, '0')}';
            maint.insert(0, {'id': id, 'no': x['no'], 'billNo': '', 'service': false, 'remark': '', 'enteredBy': 'Sujit Mule', 'updatedBy': '', 'billTotal': v['total'], 'files': [], ...v});
            ids.add(id);
          }
          return _j({'result': {...report, 'added': ids.length, 'first': ids.isEmpty ? '' : ids.first, 'last': ids.isEmpty ? '' : ids.last}});
        // (28-10-2026) the AI reads the pages of an old log book; the names written in more than one way
        case 'readMaintLog':
          final x = (a[0] as Map).cast<String, dynamic>();
          maintCalls.add({'fn': action, 'from': x['from'], 'n': x['n'], 'kind': RegExp(r'^data:([^;]+);').firstMatch('${x['data']}')?.group(1) ?? '', if (x.containsKey('max')) 'max': x['max'], if (x.containsKey('fast')) 'fast': x['fast'], if (x['after'] != null) 'after': x['after']});
          if (!RegExp(r'^data:(image/jpeg|image/png|application/pdf);base64,').hasMatch('${x['data']}')) return _j({'error': 'An old log book must be a PDF or a photo (JPG or PNG).'}, 500);
          if (!aiOn) return _j({'result': {'off': true}});
          final pdf = '${x['data']}'.startsWith('data:application/pdf'), from = pdf ? (x['from'] as num).toInt() : 1, n = pdf ? (x['n'] as num).toInt() : 1;
          final p = mliPages.isEmpty ? {'pages': 1, 'tables': []} : mliPages.removeAt(0);
          if (p == 'cut') return _j({'result': {'from': from, 'to': from + n - 1, 'pages': 0, 'tables': [], 'again': true}});
          if (p == 'busy') return _j({'error': 'The AI service is busy now – the log book – try again in a minute.'}, 500);      // (3.59.0)
          final pm = (p as Map).cast<String, dynamic>(), pages = (pm['pages'] as num? ?? 0).toInt();
          return _j({'result': {'from': from, 'to': pdf ? (pages > 0 && from + n - 1 > pages ? pages : from + n - 1) : 1, 'pages': pdf ? pages : 1, 'tables': pm['tables'] ?? [],
            if (x.containsKey('max')) ...{'more': pm['more'] == true, 'last': pm['last']}}});
        case 'maintImportNames':
          final x = (a[0] as Map).cast<String, dynamic>();
          maintCalls.add({'fn': action, 'x': x});
          if (!aiOn) return _j({'result': {'off': true}});
          if (mliNamesBusy > 0) {      // (3.59.0)
            mliNamesBusy--;
            return _j({'error': 'The AI is too slow to answer now – the names stay as in the file; try again in a minute.'}, 500);
          }
          // (as the server: only a name of the file is answered)
          final has = {for (final f in const ['party', 'work', 'uom']) f: {for (final n in (x[f] as List? ?? const [])) '${(n as List).first}'}};
          return _j({'result': {...mliNames, 'fixes': [for (final z in (mliNames['fixes'] as List? ?? const [])) if (has['${(z as List)[0]}']?.contains('${z[1]}') == true) z]}});
        // (3.59.0, Mechanical update-183) the log book status – as the server's maintStatus_: each Own machinery of the Asset Master (and any
        // other with a bill), its bills, from, up to, ₹; not added yet first
        case 'maintStatus':
          maintCalls.add({'fn': action});
          if (maintMissing) return _j({'result': {'today': '2026-10-14', 'rows': [], 'missing': true}});
          final by = <String, Map<String, dynamic>>{};
          for (final r in maint) {
            final k = '${r['no']}', d = '${r['date']}', x = by[k] ??= {'bills': 0, 'from': d, 'upTo': d, 'amount': 0};
            x['bills'] = (x['bills'] as int) + 1;
            if (d.compareTo('${x['from']}') < 0) x['from'] = d;
            if (d.compareTo('${x['upTo']}') > 0) x['upTo'] = d;
            x['amount'] = (((x['amount'] as num) + (r['total'] as num)) * 100).round() / 100;
          }
          final rows = <Map<String, dynamic>>[], seen = <String>{};
          for (final m in _master) {
            final k = '${m['id']}', x = by[k];
            if (seen.contains(k) || (m['ownership'] != 'Own' && x == null)) continue;
            seen.add(k);
            rows.add({'no': k, 'name': m['name'] ?? '', 'type': m['type'] ?? '', 'ownership': m['ownership'] ?? '', 'onSite': m['status'] != 'Inactive', 'bills': x?['bills'] ?? 0, 'from': x?['from'] ?? '', 'upTo': x?['upTo'] ?? '', 'amount': x?['amount'] ?? 0});
          }
          for (final e in by.entries) {
            if (!seen.contains(e.key)) rows.add({'no': e.key, 'name': '', 'type': '', 'ownership': '', 'onSite': false, ...e.value, 'notInMaster': true});
          }
          int had(Map r) => (r['bills'] as num) > 0 ? 1 : 0;
          rows.sort((p, q) => had(p) != had(q) ? had(p) - had(q) : '${p['no']}'.compareTo('${q['no']}'));
          return _j({'result': {'today': '2026-10-14', 'rows': rows, 'added': rows.where((r) => (r['bills'] as num) > 0).length, 'none': rows.where((r) => (r['bills'] as num) == 0).length}});
        case 'maintLog':
          final f = (a[0] as Map).cast<String, dynamic>();
          maintCalls.add({'fn': action, 'x': f});
          if (maintLogAnswer != null) return _j({'result': maintLogAnswer});
          return _j({'result': {'title': 'Maintenance Log Book – ${f['no']}', 'from': f['all'] == true ? '2026-10-05' : f['from'] ?? '2026-10-01', 'to': f['to'] ?? '2026-10-14', 'generated': '14-10-2026 10:00', 'company': 'Rachana Construction Limited',
            'all': f['all'] == true, 'store': {'on': false, 'lines': 0},      // (3.53.0, Mechanical update-175)
            'machine': {'id': f['no'], 'name': 'Hycross', 'type': 'Car', 'fuel': 'Petrol', 'unit': 'Ltr', 'meter': 'KM'}, 'card': card,
            'lines': [
              {'date': '2026-10-05', 'kind': 'Fuel', 'id': 'DI-000530', 'qty': 20, 'unit': 'Ltr', 'amount': 2100, 'paidBy': 'HDFC FUEL', 'km': 45000, 'driver': 'Gupta'},
              if (mlogLines.isNotEmpty) {'date': '2026-10-05', 'kind': 'Maintenance', 'id': 'MT-000001', 'no': f['no'], 'garage': 'Toyota Service', 'party': 'Toyota Service', 'billNo': 'TS-101', 'km': 45210, 'amount': _mlogTotal, 'total': _mlogTotal, 'service': true, 'files': 1,
                'lines': [for (final l in mlogLines) {...l}]},
              {'date': '2026-10-12', 'kind': 'Fuel', 'id': 'DI-000531', 'qty': 10, 'unit': 'Ltr', 'amount': 1050, 'paidBy': 'Cash', 'km': 45300, 'driver': ''},
            ],
            'total': {'fuel': {'qty': 30, 'amount': 3150, 'card': 2100, 'cash': 1050, 'fills': 2}, 'maint': {'amount': 2360, 'bills': 1}, 'all': 5510, 'km': 300, 'perKm': 18.37,
              'byWork': [{'work': 'Engine oil', 'amount': 1200, 'n': 1}, {'work': 'Labour', 'amount': 500, 'n': 1}, {'work': 'GST 18%', 'amount': 360, 'n': 1}, {'work': 'Oil filter', 'amount': 300, 'n': 1}]},
            'lastService': {'date': '2026-10-05', 'km': 45210, 'id': 'MT-000001'}}});
        // (3.56.0, Mechanical update-180) one line of a bill changed / taken out – as the server: the line as it was shown (its work, ₹
        // and the bill's date), else refused; the only line of a bill is not taken out
        case 'updateMaintLine' || 'deleteMaintLine':
          final x = (a[1] as Map).cast<String, dynamic>(), i = (x['i'] as num).toInt(), w = (x['was'] as Map).cast<String, dynamic>();
          maintCalls.add({'fn': action, 'id': a[0], 'x': x});
          if (a[0] != 'MT-000001') return _j({'error': 'Maintenance bill ${a[0]} was not found.'}, 500);
          if (i < 0 || i >= mlogLines.length || mlogLines[i]['work'] != w['work'] || mlogLines[i]['amount'] != w['amount'] || x['date'] != '2026-10-05') {
            return _j({'error': 'Bill ${a[0]} was changed meanwhile – show the log book again, then change its line.'}, 500);
          }
          if (action == 'deleteMaintLine') {
            if (mlogLines.length == 1) return _j({'error': 'This is the only line of bill ${a[0]} – delete the whole bill instead.'}, 500);
            mlogLines.removeAt(i);
          } else {
            final l = (x['line'] as Map).cast<String, dynamic>();
            if ('${l['work'] ?? ''}'.trim().isEmpty) return _j({'error': 'Bill line ${i + 1}: type the work / part (e.g. Engine oil, Labour).'}, 500);
            // (3.59.0, as the server) a line whose GST ₹ is kept as in the old log book: an app that does not send gstAmt may not change it
            if (_hasGa(mlogLines[i]) && !l.containsKey('gstAmt') && !((l['gst'] is num ? l['gst'] as num : 0) > 0)) return _j({'error': 'Bill ${a[0]}: this line keeps its GST amount as in the old log book – update the app to change it.'}, 500);
            mlogLines[i] = {for (final e in l.entries) if (e.value != '') e.key: e.value};
          }
          return _j({'result': {'ok': true, 'id': a[0], 'total': _mlogTotal, 'billTotal': _mlogTotal, 'lines': mlogLines.length}});
        // (3.58.0, Mechanical update-182) the Admin's "Delete this log book" – as the server: as many bills as shown, else refused (nothing deleted)
        case 'deleteMaintLog':
          final x = (a[0] as Map).cast<String, dynamic>();
          maintCalls.add({'fn': action, 'x': x});
          final n = mlogLines.isEmpty ? 0 : 1;
          if (n == 0) return _j({'error': 'No maintenance bill of ${x['no']} in these dates – nothing to delete.'}, 500);
          if (x['count'] != n) return _j({'error': 'The log book of ${x['no']} was changed meanwhile ($n bill(s) now, ${x['count']} shown) – show it again, then delete. Nothing was deleted.'}, 500);
          mlogLines.clear();
          return _j({'result': {'ok': true, 'no': x['no'], 'n': n, 'total': 0, 'all': x['all'] == true, 'ids': ['MT-000001']}});
        case 'getLogAttachments':
          return _j({'result': {'key': _arg(a, 'key'), 'no': 'MH-25-AJ-2169', 'date': '2026-10-14', 'shift': 'Full Day', 'max': 10, 'files': [for (final f in entryAtt) {...f, 'url': ''}]}});
        case 'capClaim':
          if ('${_arg(a, 'code')}' != capCodeOk) return _j({'error': 'This QR code is not valid (any more) – make a new one on the computer ("Scan with Mobile").'}, 500);
          return _j({'result': {'ok': true, 'label': 'MH-25-AJ-2169 · 14-10-2026 · Day', 'key': 'MH-25-AJ-2169|2026-10-14|Day', 'max': 10, 'have': capHave, 'ends': '2026-10-14T05:15:00Z'}});
        case 'capAdd':
          capAdds.add((a[0] as Map).cast<String, dynamic>());
          capHave += ((_arg(a, 'shas') as List?) ?? const []).length;
          return _j({'result': {'ok': true, 'have': capHave}});
        case 'getBillAttachments':
          return _j({'result': {'id': _arg(a, 'id'), 'billNo': '7', 'rev': 0, 'kind': 'submission', 'fixed': true, 'count': 2, 'files': [
            {'sha': 'c' * 64, 'p': 'log/cc/${'c' * 64}.jpg', 'mime': 'image/jpeg', 'name': 'meter.jpg', 'by': 'Op', 'at': '2026-10-01T03:00:00Z', 'url': 'https://x.test/c.jpg', 'entries': [{'key': 'K1', 'no': 'MH-25-AJ-2169', 'date': '2026-10-01', 'shift': 'Day'}, {'key': 'K2', 'no': 'MH-25-AJ-2169', 'date': '2026-10-01', 'shift': 'Night'}]},
            {'sha': 'd' * 64, 'p': 'log/dd/${'d' * 64}.pdf', 'mime': 'application/pdf', 'name': 'challan.pdf', 'by': 'Op', 'at': '2026-10-01T03:00:00Z', 'url': 'https://x.test/d.pdf', 'entries': [{'key': 'K1', 'no': 'MH-25-AJ-2169', 'date': '2026-10-01', 'shift': 'Day'}]},
          ]}});
        case 'updateLogRow':
          logSaved.add({'update': a[0], ...(a[1] as Map).cast<String, dynamic>()});
          return _j({'result': {'ok': true}});
        case 'deleteLogRow':
          return _j({'result': {'ok': true}});
        case 'getTankerTrips':
          return _j({'result': _tankerDay});
        case 'updateTankerTrip':
        case 'deleteTankerTrip':
          tankerCalls.add({'action': action, ...(a[0] as Map).cast<String, dynamic>()});
          return _j({'result': {..._tankerDay, 'ok': true}});
        case 'getIssueBalance':
          issueBal.add(a);      // (3.43.0) which source's stock was asked
          return _j({'result': {'balance': 813, 'available': 813, 'loc': 'Dispenser'}});
        case 'dieselPhoto':
          photosSent++;
          return _j({'result': {'ok': true, 'kind': (a[0] as Map)['kind'], 'path': '2026-10/00000000-0000-0000-0000-000000000001.jpg'}});
        // (3.45.0, Mechanical update-164) the fuel cards
        case 'getCards':
          return _j({'result': {'mode': card ? 'card' : 'stock', 'types': ['Fuel card', 'Credit card', 'Debit card'], 'cards': card ? cards : []}});
        case 'getCardPayments':
          cardCalls.add({'fn': action, 'x': a[0]});
          return _j({'result': {'count': cardPays.length, 'total': cardPays.fold<num>(0, (t, x) => t + (x['amount'] as num)), 'rows': cardPays}});
        case 'saveCard':
          final x = (a[0] as Map).cast<String, dynamic>();
          cardCalls.add({'fn': action, 'x': x});
          final i = cards.indexWhere((c) => c['name'] == (x['was'] ?? x['name']));
          final c = {'cars': <String>[], 'paid': 0, 'spent': 0, 'fills': 0, 'payments': 0, 'lastFill': '', 'used': false, ...(i < 0 ? <String, dynamic>{} : cards[i]), ...x}..remove('was');
          c['balance'] = (c['opening'] as num? ?? 0) + (c['paid'] as num) - (c['spent'] as num);
          if (c['lowAt'] is String) c['lowAt'] = num.tryParse('${c['lowAt']}') ?? '';      // (3.88.0) a number, as the server's
          if (i < 0) { cards.add(c); } else { cards[i] = c; }
          return _j({'result': {'ok': true, 'added': i < 0, 'name': x['name'], 'summary': '${i < 0 ? 'Fuel card added: ' : 'Fuel card changed: '}${x['name']}', 'changes': '', 'cards': cards, 'stock': cardStock}});
        case 'saveCardPayment' || 'updateCardPayment':
          final x = ((action == 'saveCardPayment' ? a[0] : a[1]) as Map).cast<String, dynamic>();
          cardCalls.add({'fn': action, if (action == 'updateCardPayment') 'id': a[0], 'x': x});
          final c = cards.firstWhere((c) => c['name'] == x['card']);
          if (action == 'saveCardPayment') {
            c['paid'] = (c['paid'] as num) + (x['amount'] as num);
            c['balance'] = (c['balance'] as num) + (x['amount'] as num);
          }
          return _j({'result': {'ok': true, 'id': action == 'saveCardPayment' ? 'CP-000002' : a[0], 'cards': cards, 'stock': cardStock}});
        case 'deleteCardPayment':
          cardCalls.add({'fn': action, 'id': a[0]});
          return _j({'result': {'ok': true, 'cards': cards, 'stock': cardStock}});
        case 'cardPhoto':
          cardCalls.add({'fn': action});
          return _j({'result': {'ok': true, 'path': '2026-10/00000000-0000-0000-0000-00000000c001.jpg'}});
        case 'getCardPayPhotos':
          return _j({'result': {'id': a[0], 'photos': []}});
        case 'cardStatement':
          final x = (a[0] as Map).cast<String, dynamic>();
          cardCalls.add({'fn': action, 'x': x});
          return _j({'result': {'card': x['card'], 'type': 'Fuel card', 'last4': '4321', 'openDate': '2026-10-01', 'from': '2026-10-01', 'to': '2026-10-14', 'opening': 20000, 'paid': 5000, 'spent': 3200, 'closing': 21800,
            'lines': [
              {'date': '2026-10-05', 'kind': 'Payment', 'id': 'CP-000001', 'in': 5000, 'out': 0, 'note': 'UTR 1234 – recharge', 'balance': 25000},
              {'date': '2026-10-13', 'kind': 'Fill', 'id': 'DI-000530', 'no': 'MH-12-HO-1163', 'qty': 30, 'unit': 'Ltr', 'driver': 'Gupta', 'km': 45210, 'out': 3200, 'in': 0, 'note': '', 'balance': 21800},
            ]}});
        case 'getCardDash':
          cardCalls.add({'fn': action, 'x': a[0]});
          return _j({'result': {'from': '2026-10-01', 'to': '2026-10-14', 'today': '2026-10-14', 'cards': cards,
            'cars': [
              {'no': 'MH-12-HO-1163', 'name': 'Hycross', 'type': 'Car', 'fuel': 'Petrol', 'unit': 'Ltr', 'std': 23, 'km': 690, 'qty': 30, 'amount': 3200, 'card': 3200, 'cash': 0, 'fills': 1, 'avg': 23, 'last': {'date': '2026-10-13', 'qty': 30, 'amount': 3200, 'km': 45210, 'paidBy': 'HDFC FUEL'},
                'make': 'Toyota', 'status': 'Active', 'kmNow': 45210, 'photo': carPhotos['MH-12-HO-1163']},
              {'no': 'MH-12-HO-2163', 'name': 'Ertiga', 'type': 'Car', 'fuel': 'CNG', 'unit': 'kg', 'std': 25, 'km': 300, 'qty': 12, 'amount': 1100, 'card': 0, 'cash': 1100, 'fills': 1, 'avg': 25, 'last': {'date': '2026-10-12', 'qty': 12, 'amount': 1100, 'km': 30100, 'paidBy': 'Cash'},
                'make': 'Maruti Suzuki', 'status': 'Active', 'kmNow': 30100, 'photo': carPhotos['MH-12-HO-2163']},
            ],
            'total': {'byFuel': {'Petrol': 30, 'CNG': 12}, 'amount': 4300, 'card': 3200, 'cash': 1100, 'fills': 2, 'km': 990, 'cars': 2}}});
        // (3.86.0, Mechanical update-212) HO's cars: one car's details, new links of the photos, a photo set / removed
        // (3.88.0, Mechanical update-213) the vehicle alerts of the site
        // (3.91.0, Mechanical update-216) Vehicle Booking – the person's own, or all for one who approves (as the server)
        case 'getBookings':
          final dec = perms['Booking Approve'] == 'Edit';
          final mine = [for (final b in bookings) if (dec || b['by'] == 'sujit@rcl.test') b];
          int n(String st) => mine.where((b) => b['status'] == st).length;
          return _j({'result': {'canDecide': dec, 'me': 'sujit@rcl.test', 'rows': mine, 'count': {'Requested': n('Requested'), 'Approved': n('Approved'), 'Rejected': n('Rejected'), 'Cancelled': n('Cancelled')}}});
        case 'saveBooking':
          final x = (a[0] as Map).cast<String, dynamic>();
          vbCalls.add({'fn': action, 'x': x});
          if ('${x['placeTo'] ?? ''}'.trim().isEmpty) return _j({'error': 'Vehicle booking: type where the vehicle is to go.'}, 500);
          if ('${x['purpose'] ?? ''}'.trim().isEmpty) return _j({'error': 'Vehicle booking: type the purpose (why the vehicle is needed).'}, 500);
          final id = 'VB-${(bookings.length + 1).toString().padLeft(6, '0')}';
          bookings.add({'id': id, 'from': x['from'], 'to': x['to'], 'placeFrom': x['placeFrom'], 'placeTo': x['placeTo'], 'purpose': x['purpose'], 'people': x['people'] == '' ? '' : int.tryParse('${x['people']}') ?? '', 'no': x['no'] ?? '', 'driver': '', 'status': 'Requested', 'by': 'sujit@rcl.test', 'byName': 'Sujit Mule', 'reply': '', 'remark': x['remark'] ?? ''});
          return _j({'result': {'ok': true, 'id': id}});
        case 'decideBooking':
          final x = (a[1] as Map).cast<String, dynamic>(), b = bookings.firstWhere((b) => b['id'] == a[0]);
          vbCalls.add({'fn': action, 'id': a[0], 'x': x});
          if (x['approve'] == true && '${x['no'] ?? ''}'.isEmpty) return _j({'error': 'Vehicle booking: pick the vehicle that goes.'}, 500);
          b.addAll({'status': x['approve'] == true ? 'Approved' : 'Rejected', if (x['approve'] == true) 'no': x['no'], if (x['approve'] == true) 'driver': x['driver'], 'reply': x['reply'], 'decidedBy': 'Sujit Mule'});
          return _j({'result': {'ok': true, 'id': a[0]}});
        case 'cancelBooking':
          vbCalls.add({'fn': action, 'id': a[0]});
          bookings.firstWhere((b) => b['id'] == a[0])['status'] = 'Cancelled';
          return _j({'result': {'ok': true, 'id': a[0]}});
        // (3.91.0, Mechanical update-216) Vehicle Expenses
        case 'getVexp':
          final f = (a[0] as Map).cast<String, dynamic>(), rs = [for (final r in vexp) if ('${r['date']}'.compareTo('${f['from']}') >= 0 && '${r['date']}'.compareTo('${f['to']}') <= 0) r];
          final by = <String, Map<String, dynamic>>{};
          for (final r in rs) {
            final c = by.putIfAbsent('${r['no']}', () => {'no': r['no'], 'n': 0, 'amount': 0, 'toll': 0, 'parking': 0, 'other': 0});
            c['n'] = (c['n'] as int) + 1;
            c['amount'] = (c['amount'] as num) + (r['amount'] as num);
          }
          return _j({'result': {'from': f['from'], 'to': f['to'], 'rows': rs.reversed.toList(), 'cars': by.values.toList(), 'total': rs.fold<num>(0, (t, r) => t + (r['amount'] as num))}});
        case 'saveVexp' || 'updateVexp':
          final x = ((action == 'saveVexp' ? a[0] : a[1]) as Map).cast<String, dynamic>();
          vbCalls.add({'fn': action, 'x': x});
          final amt = num.tryParse('${x['amount']}') ?? 0;
          if (amt <= 0) return _j({'error': 'Vehicle expense: enter the amount (₹, above 0 and up to 1,00,000).'}, 500);
          final id = action == 'saveVexp' ? 'VX-${(vexp.length + 1).toString().padLeft(6, '0')}' : '${a[0]}';
          final row = {'id': id, 'date': x['date'], 'no': x['no'], 'kind': x['kind'], 'place': x['place'], 'amount': amt, 'paidBy': x['paidBy'], 'ref': x['ref'], 'txn': '', 'source': 'Hand', 'remark': x['remark']};
          if (action == 'saveVexp') {
            vexp.add(row);
          } else {
            vexp[vexp.indexWhere((r) => r['id'] == id)] = row;
          }
          return _j({'result': {'ok': true, 'id': id}});
        case 'deleteVexp':
          vbCalls.add({'fn': action, 'id': a[0]});
          vexp.removeWhere((r) => r['id'] == a[0]);
          return _j({'result': {'ok': true, 'id': a[0]}});
        case 'readVexpStatement':
          vbCalls.add({'fn': action, 'x': (a[0] as Map).cast<String, dynamic>()});
          return _j({'result': stmtAnswer ?? {'rows': [], 'read': 0, 'matched': 0, 'saved': 0}});
        case 'importVexp':
          final rs = ((a[0] as Map)['rows'] as List).whereType<Map>().map((r) => r.cast<String, dynamic>()).toList();
          vbCalls.add({'fn': action, 'rows': rs});
          for (final r in rs) {
            vexp.add({'id': 'VX-${(vexp.length + 1).toString().padLeft(6, '0')}', 'date': r['date'], 'no': r['no'], 'kind': 'Toll', 'place': r['place'], 'amount': r['amount'], 'paidBy': 'FASTag', 'ref': '', 'txn': r['txn'], 'source': 'Statement', 'remark': ''});
          }
          return _j({'result': {'ok': true, 'added': rs.length, 'skipped': 0}});
        case 'getVehAlerts':
          vaCalls++;
          return _j({'result': vehAlerts ?? {'today': '2026-10-14', 'cars': <String, dynamic>{}, 'cards': <dynamic>[], 'n': 0, 'count': {'paper': 0, 'svc': 0, 'avg': 0, 'card': 0}}});
        case 'getCarDetail':
          final x = (a[0] as Map).cast<String, dynamic>(), no = '${x['no']}';
          carCalls.add({'fn': action, 'x': x});
          final one = no == 'MH-12-HO-1163';
          return _j({'result': {'from': x['from'], 'to': x['to'],
            'car': {'no': no, 'name': one ? 'Hycross' : 'Ertiga', 'make': one ? 'Toyota' : 'Maruti Suzuki', 'type': 'Car', 'fuel': one ? 'Petrol' : 'CNG', 'unit': one ? 'Ltr' : 'kg', 'status': 'Active', 'std': 23, 'kmNow': one ? 45210 : 30100, 'kmAt': '2026-10-13', 'photo': carPhotos[no]},
            'sum': {'qty': one ? 30 : 12, 'amount': one ? 3200 : 1100, 'card': one ? 3200 : 0, 'cash': one ? 0 : 1100, 'fills': 1, 'km': one ? 690 : 300, 'avg': one ? 23 : 25},
            'fills': [if (one) {'date': '2026-10-13', 'fuel': 'Petrol', 'qty': 30, 'unit': 'Ltr', 'amount': 3200, 'paidBy': 'HDFC FUEL', 'cash': false, 'km': 45210} else {'date': '2026-10-12', 'fuel': 'CNG', 'qty': 12, 'unit': 'kg', 'amount': 1100, 'paidBy': 'Cash', 'cash': true, 'km': 30100}],
            'log': perms['Log Book'] == 'None' && !superAdmin ? null : [{'date': '2026-10-13', 'shift': 'Full Day', 'okm': 44520, 'ckm': 45210, 'km': 690, 'driver': 'Gupta', 'work': ''}],
            'maint': [for (final m in maint) if (m['no'] == no) {'id': m['id'], 'date': m['date'], 'garage': m['garage'], 'billNo': m['billNo'], 'km': m['km'], 'amount': m['total'], 'service': m['service'], 'works': [for (final l in (m['lines'] as List)) (l as Map)['work']], 'files': 1}],
            'may': {'photo': superAdmin, 'log': true, 'maint': true}}});
        case 'getCarPhotoLinks':
          carCalls.add({'fn': action, 'x': a[0]});
          final nos = [for (final n in ((a[0] as Map)['nos'] as List? ?? const [])) '$n'];
          carLinksEnd = false;
          return _j({'result': {'photos': {for (final n in nos) if (carPhotos[n] != null) n: carPhotos[n] = carLink(n, '${carPhotos[n]!['v']}', carCalls.length)}}});
        case 'carPhotoSet':
          final x = (a[0] as Map).cast<String, dynamic>(), no = '${x['no']}';
          carCalls.add({'fn': action, 'x': {...x, 'full': '${x['full']}'.substring(0, 30), 'thumb': '${x['thumb']}'.substring(0, 30), 'fullLen': '${x['full']}'.length, 'thumbLen': '${x['thumb']}'.length}});
          if (carRefuse.isNotEmpty) return _j({'error': carRefuse}, 500);
          if ('${x['was']}' != '${carPhotos[no]?['v'] ?? ''}') return _j({'error': 'The photo of $no was changed by someone else after you opened it – open it again, nothing was saved.'}, 500);
          carPhotos[no] = carLink(no, 'v${carCalls.length}new', carCalls.length);
          return _j({'result': {'ok': true, 'no': no, 'photo': carPhotos[no]}});
        case 'carPhotoRemove':
          final x = (a[0] as Map).cast<String, dynamic>(), no = '${x['no']}';
          carCalls.add({'fn': action, 'x': x});
          if (carRefuse.isNotEmpty) return _j({'error': carRefuse}, 500);
          carPhotos.remove(no);
          return _j({'result': {'ok': true, 'no': no, 'photo': null}});
        // (3.76.0, Mechanical update-203) a tank check due with this fill?
        case 'tankDue':
          tankDueAsked.add((a[0] as Map));
          return _j({'result': tankDueAns ?? {'no': (a[0] as Map)['no'], 'date': (a[0] as Map)['date'], 'due': false}});
        case 'saveDieselIssue' || 'saveTransfer' when short:      // (3.85.0) the stock cannot cover it
          if (meta?['short'] == true) return _j({'error': 'Kept as stock short – VF-00008. Not enough diesel at Dispenser for 14-10-2026 (Day). Available: 0 Ltr, you are issuing: 40 Ltr. It is saved by itself when the stock comes (a Diesel Inward or Transfer); nothing is saved until then. See Approvals.'}, 500);
          return _j({'error': 'Not enough diesel at Dispenser for 14-10-2026 (Day). Available: 0 Ltr, you are issuing: 40 Ltr.'}, 500);
        case 'saveDieselIssue':
          final d = (a[0] as Map).cast<String, dynamic>();
          if (tankDueAns != null && tankDueAns!['due'] == true && d['tc'] == null) return _j({'error': '${d['no']}: tank check due – the last one on 31-10-2026, a check every 7 days. Type the diesel found in the tank before filling (Tank check), then save.'}, 500);
          if (card) {
            saved.add(d);
            final c = cards.where((c) => c['name'] == d['source']).firstOrNull;
            if (c != null) c['balance'] = (c['balance'] as num) - (d['amount'] as num);
            return _j({'result': {'ok': true, 'id': 'DI-000531', 'stock': cardStock}});
          }
          if (d['force'] != true && (d['hrReading'] ?? '') == 1) return _j({'result': {'ok': false, 'warning': 'The Hrs reading 1 is lower than the last one (4,700). Save anyway?'}});
          saved.add(d);
          return _j({'result': {'ok': true, 'id': 'DI-000526', 'stock': {'stock': 1133 - (d['qty'] as num), 'byLoc': {'Dispenser': 813 - (d['qty'] as num), 'VTR Store': 320}}}});
      }
      return _j({'error': 'Unknown action.'}, 404);
    }
    return _j({'error': 'not found'}, 404);
  });
}

/// (3.93.0) "40+300" → 40300 (the fake Engineering's chainage)
num? _chM(String v) {
  final m = RegExp(r'^(\d+)\+(\d+)$').firstMatch(v.trim());
  return m == null ? num.tryParse(v.trim()) : int.parse(m.group(1)!) * 1000 + int.parse(m.group(2)!);
}
