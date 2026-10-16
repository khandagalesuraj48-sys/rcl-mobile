/* (3.10.0) Store – the Dashboard as the web works it out from the Item Master (counts, added this month (the stored date against India's month),
 * recently added, items by category) and the Export to Excel's columns. */
import 'package:flutter_test/flutter_test.dart';
import 'package:rcl_mobile/screens/store.dart';

void main() {
  final items = <Map>[
    {'code': 'ITM-0001', 'name': 'Hose', 'unit': 'Mtr', 'category': 'Spare Parts', 'hsn': '4009', 'gst_pct': 18, 'min_stock': 10, 'status': 'Active', 'created_at': '2026-10-02T06:00:00Z'},
    {'code': 'ITM-0002', 'name': 'Sugar', 'unit': 'Kg', 'category': 'Canteen', 'hsn': '', 'gst_pct': 5, 'min_stock': null, 'status': 'Active', 'created_at': '2026-09-30T19:00:00Z'},
    {'code': 'ITM-0003', 'name': 'Oil Filter', 'unit': 'Nos', 'category': 'Spare Parts', 'hsn': '8421', 'gst_pct': 18.5, 'min_stock': 4, 'status': 'Inactive', 'created_at': '2026-09-20T06:00:00Z'},
  ];
  test('The Store dashboard: items, active, categories, added this month (the stored date against India\'s month), recent first, by category', () {
    final d = storeDash(items, DateTime.utc(2026, 10, 14, 4));
    expect([d.all, d.active, d.all - d.active, d.cats, d.newMonth], [3, 2, 1, 2, 1],
        reason: 'as the web: the month of the date as stored (30-09 19:00 UTC is September) against this month in India');
    expect(d.recent.map((i) => i['code']), ['ITM-0001', 'ITM-0002', 'ITM-0003']);
    expect(d.byCat, [('Canteen', 1, 1), ('Spare Parts', 2, 1)]);
  });
  test('Export to Excel: the web\'s columns, numbers as numbers', () {
    final t = storeItemsDoc(items, '2026-10-14').tables.single;
    expect(t.head, ['Item Code', 'Item Name', 'Unit', 'Category', 'HSN Code', 'GST %', 'Min Stock', 'Status']);
    expect(t.rows[2].cells.map((c) => c.text), ['ITM-0003', 'Oil Filter', 'Nos', 'Spare Parts', '8421', '18.5', '4', 'Inactive']);
    expect(t.rows[1].cells[6].value, isNull, reason: 'no min stock: an empty cell');
    expect(t.rows[0].cells[5].value, 18);
  });
}
