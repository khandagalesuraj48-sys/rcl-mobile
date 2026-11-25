/* (25-11-2026, the Portal's rule – his words: "ekda otp ela ki 1 minute wait resend sathi kamit kami resend 6 time tya nantr 15 minute
 * cha block pratek invalid otp or otp request la remaining kiti sangitle jail waring asel ki 15 minute nantr block hoil"; his answers:
 * 6 codes in all, 6 wrong codes) WHAT A CODE SAYS – the same words wherever a code is sent or typed (sign-in by e-mail or WhatsApp,
 * "Forgot password?", "Verify your e-mail", HR's sign-in again). The Portal counts and decides; the app only says what it answered:
 *   a code sent  → `left` = the codes he may still ask for (then 15 minutes);
 *   a wrong code → code 'code' with `left` = the wrong codes he may still type (then 15 minutes);
 *   blocked      → code 'locked' with `wait` = the seconds still to wait.
 * The words are in the app's language (written here – they come with the patch; the language files are not changed by it). */
import 'api.dart' show ApiError;
import 'lang.dart';

String _w3(String en, String mr, String hi) => Lang.i.code == 'mr' ? mr : Lang.i.code == 'hi' ? hi : en;

int? _n(Object? v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}');

/// After "Send code": how many more codes may be asked for ('' when the Portal did not say).
String codesLeftLine(Object? left) {
  final n = _n(left);
  if (n == null || n < 0) return '';
  if (n == 0) {
    return _w3('This is the last code for now – asking for another stops the codes for 15 minutes.', 'हा आत्ताचा शेवटचा code – पुन्हा मागितल्यास 15 मिनिटे code मिळणार नाही.',
        'यह अभी का आखिरी code है – फिर मांगने पर 15 मिनट code नहीं मिलेगा।');
  }
  return _w3('$n more ${n == 1 ? 'code' : 'codes'} can be asked for, then you wait 15 minutes.', 'आणखी $n code मागता येतील, नंतर 15 मिनिटे थांबावे लागेल.', 'और $n code मांग सकते हैं, फिर 15 मिनट रुकना होगा।');
}

/// A code's error in words: a wrong code with the tries left, blocked with the minutes to wait; anything else as the Portal said it.
String codeError(Object e) {
  if (e is! ApiError) return '$e';
  final left = _n(e.data['left']), wait = _n(e.data['wait']);
  if (e.code == 'locked' && wait != null && wait > 0) {
    final m = (wait / 60).ceil() < 1 ? 1 : (wait / 60).ceil();
    return _w3('Too many tries – wait $m ${m == 1 ? 'minute' : 'minutes'}, then ask for a new code.', 'खूप प्रयत्न झाले – $m मिनिटे थांबा, मग नवीन code मागा.', 'बहुत कोशिशें हो गईं – $m मिनट रुकें, फिर नया code मांगें।');
  }
  if (e.code == 'code' && left != null && left > 0) {
    return _w3('The code is wrong or has expired. $left ${left == 1 ? 'try' : 'tries'} left – after that you wait 15 minutes.',
        'Code चुकीचा आहे किंवा त्याची वेळ संपली. अजून $left प्रयत्न – त्यानंतर 15 मिनिटे थांबावे लागेल.', 'Code गलत है या उसका समय खत्म हो गया। अभी $left कोशिश बाकी – उसके बाद 15 मिनट रुकना होगा।');
  }
  return e.toString();
}
