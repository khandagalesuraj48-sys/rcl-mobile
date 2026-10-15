/* THE NUMBER PLATE (3.1.8, asked 15-10-2026: "diesel issue madhe apan number manualy select krt hoto but ata … number plate
 * cha photo jari ghetla systeam verify krel ha number ahe ka systeam madhe auto number pn detect hoil manual pn krta yeil").
 * The phone reads the letters of the photo itself (Google ML Kit, on the phone: no internet, nothing paid, under a second); this
 * file finds which machinery of the Asset Master that text is. Only machinery on the site on the entry's date is looked at.
 *   – every line of the photo, and two lines together (a plate written on two lines: "MH 25" / "AJ 2169");
 *   – letters the camera often mixes up count as the same (O / D / Q and 0, I / L and 1, Z and 2, S and 5, B and 8, G and 6);
 *   – an exact plate first; else one letter wrong; nothing found = the person picks (as before). */
import 'session.dart';

String plateKey(String s) => s.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

const _same = {'O': '0', 'D': '0', 'Q': '0', 'I': '1', 'L': '1', 'Z': '2', 'S': '5', 'B': '8', 'G': '6'};
String _canon(String k) => k.split('').map((c) => _same[c] ?? c).join();

/// What the photo says, as candidates to compare (each line, two lines together, all of it).
List<String> plateTexts(String ocr) {
  final lines = ocr.split(RegExp(r'[\r\n]+')).map(plateKey).where((l) => l.isNotEmpty).toList();
  final out = <String>{...lines};
  for (var i = 0; i + 1 < lines.length; i++) {
    out.add(lines[i] + lines[i + 1]);
  }
  out.add(lines.join());
  return out.where((x) => x.length >= 4).toList();
}

int _diff(String a, String b) {
  var d = 0;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) d++;
  }
  return d;
}

/// The machinery the plate text names: the best first (exact, then one letter different). Empty = not in the Asset Master.
List<Machine> plateMatches(String ocr, List<Machine> machines) {
  final texts = plateTexts(ocr).map(_canon).toList();
  final scored = <(Machine, int)>[];
  for (final m in machines) {
    final keys = {plateKey(m.id), plateKey('${m.m['no'] ?? ''}')}.where((k) => k.length >= 4).map(_canon);
    var best = 99;
    for (final k in keys) {
      for (final t in texts) {
        if (t.contains(k)) {
          best = 0;
          break;
        }
        if (k.length >= 6 && t.length >= k.length) {
          for (var i = 0; i + k.length <= t.length; i++) {
            final d = _diff(t.substring(i, i + k.length), k);
            if (d < best) best = d;
          }
        }
      }
      if (best == 0) break;
    }
    if (best <= 1) scored.add((m, best));
  }
  scored.sort((a, b) => a.$2 - b.$2);
  final exact = scored.where((x) => x.$2 == 0).map((x) => x.$1).toList();
  return exact.isNotEmpty ? exact : scored.map((x) => x.$1).toList();
}
