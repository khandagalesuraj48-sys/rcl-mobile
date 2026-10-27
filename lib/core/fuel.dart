/* (3.44.0, Mechanical update-163, asked 26-10-2026: "petrol cng he field banaw ani ha electric ha pn thew") FUEL.
 * Every machinery has one fuel (Asset Master → Fuel: Diesel / Petrol / CNG / Electric – none = Diesel) and every diesel place holds
 * one (Diesel / Petrol / CNG – the Super Admin, Portal → Sites → Diesel places). A fill only from a place of the machinery's fuel, a
 * transfer only between places of one fuel – the server refuses the rest. A site of Diesel only (VTR, 18B) looks as before; a site
 * with more than one fuel shows each fuel on its own (never added together). CNG is counted in kg, the others in litres. */

/// The fuels: a machinery has one, a diesel place holds one of the first three
const kFuels = ['Diesel', 'Petrol', 'CNG', 'Electric'];

/// CNG is counted in kg, the others in litres
String fuelUnit(String f) => f == 'CNG' ? 'kg' : 'Ltr';

/// The words of a dashboard / report of ONE fuel: "Diesel" (also डिझेल / डीज़ल) → its name; for CNG the litres → kg.
/// Diesel or none: the words as they are.
String fuelText(String s, String f) {
  if (f.isEmpty || f == 'Diesel' || s.isEmpty) return s;
  final mr = f == 'Petrol' ? 'पेट्रोल' : f;
  var t = s.replaceAll(RegExp(r'\bDiesel\b'), f).replaceAll(RegExp(r'\bdiesel\b'), f == 'CNG' ? 'CNG' : f.toLowerCase()).replaceAll(RegExp('डिझेल|डीज़ल|डीजल'), mr);
  if (f == 'CNG') {
    t = t.replaceAll(RegExp(r'\b(Ltr|ltr|Litres?|litres?|Liters?|liters?|Litre)\b'), 'kg').replaceAll(RegExp('लिटर|लीटर'), 'किलो');
    t = t.replaceAllMapped(RegExp(r'(\d) L\b'), (x) => '${x[1]} kg').replaceAll('(L)', '(kg)');
  }
  return t;
}
