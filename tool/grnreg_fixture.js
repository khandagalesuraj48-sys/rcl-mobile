// (app 3.57.0, the Store's import of the old inward register) what the web's own code (rcl-store public/grnreg.js, SheetJS 0.18.5)
// makes of an inward register – the app's core/grn_reg.dart must make exactly the same (test/grn_reg_test.dart). Test values only.
//   GRNREG_JS=<rcl-store>/public/grnreg.js NODE_PATH=<folder with xlsx 0.18.5> node tool/grnreg_fixture.js test/fixtures/sheets
const fs = require('fs'), XLSX = require('xlsx');
const RG = require(require('path').resolve(process.env.GRNREG_JS || '../rcl-store/public/grnreg.js'));
// a register as his file is: a Summary sheet, the heading on row 4 (two lines in a cell), a GRN's details on its first row only
const head = ['Sr No ', 'GRN\r\n No', 'GRN Date ', 'Challan No ', 'Invoice No.', 'Invoice Date', 'Vehicle No', 'Supplier Name ', 'Material Description', 'Received\r\nQty', 'UOM', 'Basic\r\nRate ', 'Taxable \r\nAmount', 'GST\r\n Amount', 'TCS', 'Gross \r\nAmount', 'Remark'];
const sup = []; for (let i = 0; i < 12; i++) sup.push(['Shree', 'Om', 'Sai', 'Jai'][i % 4] + ' ' + ['Hardware', 'Traders', 'Auto Parts'][Math.floor(i / 4)] + (i % 3 === 0 ? ' Bhiwandi' : ''));
const items = []; for (let i = 0; i < 40; i++) items.push([['Hydraulic Oil', 'Gear Oil', 'Fuel Filter', 'Oil Filter', 'Air Filter', 'Bolt', 'Nut', 'Washer', 'Binding Wire', 'Cement OPC'][i % 10] + ' ' + (10 + Math.floor(i / 10) * 2) + (i % 10 < 5 ? ' No' : ' MM'), ['ltr', 'Ltrs', 'nos', 'Nos ', 'pcs', 'nos', 'nos', 'box', 'kgs', 'bags'][i % 10], [180, 210, 450, 380, 900, 12, 4, 1, 80, 350][i % 10]]);
const rows = [], sr = { n: 0 }, d0 = 44900;
const row = (ref, day, s, inv, it, qty, x) => { x = x || {}; const [name, uom, rate] = items[it], tx = Math.round(qty * rate * 100) / 100, g = Math.round(tx * 18) / 100;
  return [++sr.n, ref, d0 + day, x.ch || '', inv, d0 + day - 1, x.veh || '', sup[s], x.name || name, qty, x.uom === undefined ? uom : x.uom, rate, x.tx === undefined ? tx : x.tx, g, x.tcs || '', x.gross === undefined ? Math.round((tx + g + (x.tcs || 0)) * 100) / 100 : x.gross, x.rem || ''] };
for (let ref = 1; ref <= 60; ref++) {
  const s = (ref * 7) % 12, day = Math.floor(ref / 2), n = 1 + (ref % 4);
  for (let k = 0; k < n; k++) {
    const it = (ref * 13 + k * 17) % 40, r = row(ref, day, s, 'INV-' + ref, it, 1 + ((ref + k) % 9), { veh: k ? '' : 'MH-04-AB-' + (1000 + ref), rem: (ref + k) % 3 ? 'Mechanical' : 'Hardware', tcs: ref % 20 === 0 && !k ? 12.5 : 0,
      name: ref % 9 === 0 && k === 0 ? items[it][0].replace('Hydraulic', 'Hydrolic').replace('Filter', 'Fliter').replace('Binding', 'Bindding') : '', uom: ref === 17 && k === 0 ? 'jar of 5' : undefined,
      tx: ref === 23 && k === 0 ? 999 : undefined, gross: ref === 29 && k === 0 ? 1 : undefined });
    if (k) { r[2] = ''; r[4] = ''; r[5] = ''; r[7] = ''; }
    rows.push(r);
    if (ref % 15 === 0 && k === 0) { const d = r.slice(); d[0] = ++sr.n; rows.push(d); }      // the same row twice
  }
}
rows.push(row('342-A', 31, 5, 'INV-342A', 3, 2, { rem: 'Mechanical' })); rows.push(row('342 B', 31, 9, 'INV-342B', 4, 1, {})); rows.push(row('8029`', 31, 2, 'INV-8029', 5, 1, {}));
rows.push(row(12, 11, 7, 'INV-OTHER', 8, 50, {}));      // GRN No 12 of another supplier, day and invoice: its own GRN
rows.push(row('', 32, 10, 'TCI-77', 20, 1, { rem: 'Transport' }));      // no GRN No: the next number
const cont = row('', 3, (6 * 7) % 12, 'INV-6', 21, 4, {}); rows.push(cont);      // no GRN No, the date / supplier / invoice of GRN 6: its line
const bad = row(61, 34, 3, 'INV-61', 9, 3, {}); bad[2] = '14-04-205'; rows.push(bad);      // not a date
const noq = row(62, 34, 3, 'INV-62', 7, 0, {}); noq[9] = ''; noq[12] = ''; noq[13] = ''; noq[15] = ''; rows.push(noq);      // no quantity, no amount
const amt = row(63, 34, 3, 'INV-63', 7, 0, {}); amt[9] = ''; amt[12] = 500; rows.push(amt);      // no quantity, an amount: Qty 1
const word = row(64, 34, 3, 'INV-64', 7, 0, {}); word[9] = 'two'; rows.push(word);      // a quantity that is not a number
rows.push([++sr.n, 65, '', '', '', '', '', '', '', '', '', '', '', '', '', '', '']);      // only a GRN No
const far = row(66, 35, 3, 'INV-66', 9, 3, {}); far[2] = d0 + 35 - 7305; rows.push(far);      // 20 years early
const num = row(67, 35, 3, 'INV-67', 9, 3, {}); num[8] = '45706'; rows.push(num);      // a number for a material
const hd = row(68, 35, 3, 'INV-68', 9, 3, {}); hd[8] = 'Description'; rows.push(hd);      // a heading for a material
const nos = row(69, 35, 3, 'INV-69', 9, 3, {}); nos[7] = ''; rows.push(nos);      // no supplier
rows.push(row(70, 36, 3, '30-Nov-2022', 9, 2, { ch: 'CH-9' })); rows[rows.length - 1][2] = '30-Nov-2022';      // a date typed with its month's name
rows.push(row(71, 36, 4, 'INV-71', 1, 38680, { uom: 'Kg' })); rows[rows.length - 1][11] = 42900; rows[rows.length - 1][12] = 1659372000;      // above ₹1 crore
for (let ref = 72; ref <= 76; ref++) rows.push(row(ref, 37, ref % 12, 'INV-' + ref, ref % 40, 2, { rem: ref % 2 ? 'Mechinical' : 'Mechanical' }));
const wb = XLSX.utils.book_new();
XLSX.utils.book_append_sheet(wb, XLSX.utils.aoa_to_sheet([['Material', 'Qty'], ['Cement', 10]]), 'Summary');
XLSX.utils.book_append_sheet(wb, XLSX.utils.aoa_to_sheet([['RCL – INWARD REGISTER'], [], []].concat([head], rows)), 'MAIN SHEET INWARD1');
XLSX.utils.book_append_sheet(wb, XLSX.utils.aoa_to_sheet([['Binding Wire'], ['Date', 'Qty'], [44900, 5]]), 'Binding Wire');
const out = process.argv[2];
XLSX.writeFile(wb, out + '/grn_reg.xlsx');
// read back as the page reads it
const rb = XLSX.read(fs.readFileSync(out + '/grn_reg.xlsx'), { type: 'buffer' });
const sheets = rb.SheetNames.map(n => ({ name: n, r0: 0, aoa: XLSX.utils.sheet_to_json(rb.Sheets[n], { header: 1, raw: true, defval: '' }) }));
const sh = RG.pickSheet(sheets), read = RG.readRows(sh), today = '2026-10-28';
// the Store has an item, a supplier and a GRN already; the next GRN 1
const info = { items: [['ITM-0001', 'Gear Oil 10 No', 'Ltr', 'Oil']], vendors: ['SAI HARDWARE'], grns: [[RG.docKey('4', RG.dayIn(d0 + 2), sup[(4 * 7) % 12], 'INV-4'), '4', 4, RG.dayIn(d0 + 2), sup[(4 * 7) % 12]], [RG.docKey('9999', '2023-01-02', 'X Y', ''), '12', 9999, '2023-01-02', 'X Y']], next: 1 };
const p0 = RG.plan(read, info, {}, today);
const look = p0.look.find(l => l.why.some(w => /not a date/.test(w))), wq = p0.look.find(l => /two/.test(l.qty));
const names = RG.namesOf(read);
const fixes = { party: {}, item: {}, category: { Mechinical: 'Mechanical' } };
Object.keys(names.item).filter(n => /Hydrolic|Fliter|Bindding/.test(n)).forEach(n => { fixes.item[n] = n.replace('Hydrolic', 'Hydraulic').replace('Fliter', 'Filter').replace('Bindding', 'Binding'); });
fixes.party['Shree Hardware Bhiwandi'] = 'Shree Hardware';
const ch = { fix: fixes, gone: { [p0.dups[0].line]: true }, edit: { [look.line]: { date: '2023-04-14' }, [wq.line]: { qty: '2' } } };
const p1 = RG.plan(read, info, ch, today);
fs.writeFileSync(out + '/grn_reg.json', JSON.stringify({ xlsx: XLSX.version, today, sheet: { name: sh.name, hi: sh.hi, col: sh.col, n: sh.n, others: sh.others }, rows: read, info, p0, ch, p1, names,
  far: RG.farDates([{ ref: '1', date: '2023-01-01' }, { ref: '2', date: '2023-01-05' }, { ref: '3', date: '2003-01-06' }, { ref: '4', date: '2023-01-09' }, { ref: '5', date: '2023-01-12' }, { ref: '6', date: '2023-01-15' }], today),
  units: ['nos', 'No.', 'Nos ', 'pcs', 'kgs', 'rmtr', 'jab', 'Ltrs', 'bkt', 'Sq.M', 'cum', 'Brass', 'MT', '5x5', '', 'jar of 5'].map(u => [u, RG.unitOf(u)]),
  days: [44864, 44864.75, '30-Nov-2022', '30/11/2022', '2022-11-30', '14-04-205', '31-02-2023', '1-sept-22', '', 'x'].map(d => [d, RG.dayIn(d)]),
  refs: [8029, '8029`', '342 B', '`', 'x', 12.5].map(r => [r, RG.refIn(r)]), nums: ['1,180.00', '₹ 650', '4 nos', '', 'Rs.5', '.5', '5.'].map(n => [n, RG.numIn(n)]) }, null, 1) + '\n');
console.log(sh.name, read.length, 'rows ·', p0.docs.length, 'GRNs ·', p0.look.length, 'to look at ·', p0.dups.length, 'dups ·', p0.notes.length, 'notes ·', p0.newItems.length, 'items ·', p0.newSup.length, 'suppliers · next', p0.next, '| after the choices:', p1.docs.length, p1.look.length, p1.newItems.length, p1.newSup.length);
