// (update-180 / app 3.56.0; update-183 / app 3.59.0: a line its GST ₹ as read – mtHasGa / mtLineGst) what the web's own code (App.html mliField / mliRows / mliSheet, SheetJS 0.18.5) makes of headings in any
// order – the app's core/maint_import.dart must make exactly the same (test/maint_import_test.dart).
//   APP_HTML=<rclerp>/app/App.html NODE_PATH=<folder with xlsx 0.18.5> node tool/mli_heads_fixture.js test/fixtures/sheets
const fs = require('fs'), vm = require('vm'), XLSX = require('xlsx');
const L = fs.readFileSync(process.env.APP_HTML || '../rclerp/app/App.html', 'utf8').split('\n');
const take = re => { const i = L.findIndex(l => re.test(l)); for (let k = i; k < i + 80; k++) { const t = L.slice(i, k + 1).join('\n'); try { new vm.Script(t); return t; } catch (e) {} } throw new Error(String(re)); };
const master = [{ id: 'RL-180', name: 'Roller No.18', ownership: 'Own', status: 'Active' }, { id: 'MH-12-XW-0180', name: 'Hycross', ownership: 'Own', status: 'Active' }];
const ctx = vm.createContext({ XLSX, S: { master, today: '2026-10-28' } }); ctx.window = ctx;
vm.runInContext(['const isoDate = d => d.toISOString().slice(0, 10);', take(/^\s*const r2 = /), take(/^\s*const mtGst = /), take(/^\s*function xlDate\(/), take(/^\s*function mliField\(/), take(/^\s*function mliRows\(/),
  take(/^\s*const mliKey = /), take(/^\s*const mliOwn = /), take(/^\s*const mliNum = /), take(/^\s*const mtHasGa = /), take(/^\s*const mtLineGst = /), take(/^\s*function mliMatch\(/), take(/^\s*function mliSheet\(/),
  'globalThis.T = { mliField, mliRows, mliSheet };'].join('\n'), ctx);
const heads = ['Sr No', 'S. No.', 'Sr.No', '#', 'No.', 'Date', 'Bill Date', 'Invoice Dt.', 'Bill No', 'Invoice No.', 'Job Card No', 'Party Name', 'Supplier', 'Garage', 'Vendor Name', 'Workshop Name', 'Service Center', 'Done By', 'Purchased From',
  'Current Reading', 'KM', 'HMR', 'Hrs', 'Reading (KM/Hrs)', 'Odometer', 'Particulars', 'Item Description', 'Description of Work', 'Spare Parts', 'Material', 'Item', 'Part No', 'HSN/SAC', 'Item Code',
  'Qty', 'Quantity', 'Qty.', 'Nos', 'Uom', 'Unit', 'U.O.M', 'Basic Rate', 'Rate', 'Unit Price', 'Rate/Unit', 'MRP', 'Amount', 'Amount (Rs.)', 'Amt ₹', 'Basic Amount', 'Taxable Value', 'Labour Charges', 'Sub Total', 'Value',
  'GST Amount', 'GST', 'Tax', 'VAT', 'GST %', 'GST Rate', 'Rate of GST', 'CGST', 'CGST 9%', 'CGST @ 9 %', 'CGST %', 'C.G.S.T', 'SGST Amt', 'S.G.S.T.', 'UTGST', 'IGST', 'IGST 18%', 'GST CGST',
  'Amount With GST', 'Amount\nWith GST', 'Amount incl. GST', 'Total (Incl. Tax)', 'Amt+GST', 'Net Amount', 'Gross Amount', 'Total Amount', 'Bill Amount', 'Payable', 'Total', 'Grand Total', 'Bill Total',
  'Remarks', 'Note', 'Discount', 'Disc %', 'Vehicle No', 'Name', '', null, 12, 'Machinery'];
const fields = heads.map(h => ctx.T.mliField(h));
const cases = [
  [['Item Description', 'Bill Date', 'KM', 'Supplier', 'Qty', 'Rate', 'Taxable Value', 'CGST 9%', 'SGST 9%', 'Net Amount', 'Remarks'],
    [['ENGINE OIL', '2024-01-02', 12345, 'SURAJ', 10, '350', '3,500.00', 315, 315, 4130, 'ok'], ['FILTER', null, null, null, 1, 500, 500, 45, 45, 590, null], ['', '', '', '', '', '', '', '', '', '', '']]],
  [['Date', 'Particulars', 'Qty', 'Rate', 'GST %', 'Net Amount'], [['2024-01-02', 'OIL', 2, 100, '18%', 236], ['2024-01-03', 'GREASE', 1, 50, '', 50]]],
  [['Date', 'Particulars', 'Qty', 'Rate', 'Total Amount', 'GST', 'Net Amount'], [['2024-01-02', 'OIL', 2, 100, 200, 36, 236]]],
  [['Date', 'Particulars', 'Qty', 'Rate'], [['2024-01-02', 'OIL', 2, 100], ['2024-01-02', 'BULB', 'two', 40]]],
  [['Date', 'Particulars', 'Amount', 'GST %'], [['2024-01-02', 'OIL', 1000, 18], ['2024-01-02', 'CLOTH', 'Rs. 1,000', '5 %']]],
  [['Date', 'Particulars', 'Amount', 'CGST', 'SGST', 'IGST', 'GST Amount'], [['2024-01-02', 'A', 100, 9, 9, '', ''], ['2024-01-02', 'B', 100, '', '', 18, ''], ['2024-01-02', 'C', 100, 9, 9, '', 20]]],
  [['Date', 'Particulars', 'Amount', 'CGST %', 'SGST %'], [['2024-01-02', 'A', 100, 9, 9]]],
  [['Date', 'Particulars', 'Amount', 'Tax', 'VAT'], [['2024-01-02', 'A', 100, 9, 9]]],
  [['Sr No', 'Date', 'Party Name', 'Current Reading', 'Particulars', 'Qty', 'Uom', 'Basic Rate', 'Amount', 'GST Amount', 'Amount With GST', 'Total'],
    [[1, '2022-12-02', 'Store', '', 'AD BLUE', 20, 'Ltr', 59, 1180, 212.4, 1392.4, ''], [2, '', '', '', 'BULB', 1, 'Nos', 40, '', '', '', ''], ['null', null, 'X', 'NULL', 'Y', -1, '', '', -50, '', '', '']]],
  [['Particulars', 'Qty'], [['A']]],
];
const rows = cases.map(c => ctx.T.mliRows(c[0], c[1]));
// his Excel in two other orders (a sheet a machinery)
const wb = XLSX.utils.book_new();
XLSX.utils.book_append_sheet(wb, XLSX.utils.aoa_to_sheet([['Rachana Construction Limited'], ['ROLLER NO-18'], ['Item Description', 'Bill Date', 'Supplier', 'KM', 'Qty', 'Unit', 'Rate', 'Taxable Value', 'CGST 9%', 'SGST 9%', 'Net Amount', 'Remarks'],
  ['AD BLUE', '02-12-2022', 'Store', '', 20, 'Ltr', 59, 1180, 106.2, 106.2, 1392.4, ''], ['FUEL FILTER', 44931, 'Store', 500, 1, 'Nos', 650, 650, 58.5, 58.5, 767, 'changed at 500 hrs'],
  ['ENGINE OIL FILTER', '', '', '', 1, 'Nos', 930, 930, 83.7, 83.7, 1097.4, ''], ['Total', '', '', '', '', '', '', '', '', '', 3256.8, '']]), 'Roller 18');
XLSX.utils.book_append_sheet(wb, XLSX.utils.aoa_to_sheet([['Hycross MH12XW0180'], ['S. No.', 'Vendor Name', 'Invoice Dt.', 'Odometer', 'Spare Parts', 'Quantity', 'U.O.M', 'Unit Price', 'GST %', 'Total Amount'],
  [1, 'Navnit Motors', '10/02/2026', 13153, 'Wiper blade', 1, 'Nos', 310, 18, 365.8], [2, '', '', '', 'Labour', 1, 'Nos', 1200, 18, 1416], [3, 'Navnit Motors', '11/03/2026', 14002, 'Washer fluid', 1, 'Ltr', 100, '', 100]]), 'Hycross');
XLSX.utils.book_append_sheet(wb, XLSX.utils.aoa_to_sheet([['Summary'], ['Machinery', 'Bills'], ['Roller 18', 2]]), 'Summary');
const out = process.argv[2];
XLSX.writeFile(wb, out + '/maint_heads.xlsx');
const rb = XLSX.read(fs.readFileSync(out + '/maint_heads.xlsx'), { type: 'buffer', cellDates: false });
const sheets = rb.SheetNames.map(n => ctx.T.mliSheet(n, XLSX.utils.sheet_to_json(rb.Sheets[n], { header: 1, raw: true, defval: '' }))).filter(x => x && x.bills.length);
fs.writeFileSync(out + '/maint_heads.json', JSON.stringify({ xlsx: XLSX.version, today: '2026-10-28', master, heads, fields, cases, rows, sheets }, null, 1) + '\n');
console.log(sheets.map(x => x.sheet + ':' + x.no + ':' + x.bills.length + ':' + x.total + ':' + x.fileTotal).join(' | '));
console.log(JSON.stringify(rows));
