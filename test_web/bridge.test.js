/* The app's web bridge (assets/web_bridge.js) in a real browser (Chromium), with a page built like the ERP: the shell page
 * with the ERP in a srcdoc frame, a module's page in a frame inside it, an Excel file made in the page, the print window.
 * The app's side (flutter_inappwebview.callHandler) is a recorder here.
 *   NODE_PATH=<folder with puppeteer-core and @sparticuz/chromium> node test_web/bridge.test.js
 * (Flutter's own tests cannot run a web view; this checks the script the web view runs.) */
'use strict';
const http = require('http'), fs = require('fs'), path = require('path');
const chromium = require('@sparticuz/chromium').default || require('@sparticuz/chromium'), puppeteer = require('puppeteer-core');
const BRIDGE = fs.readFileSync(path.join(__dirname, '..', 'assets', 'web_bridge.js'), 'utf8');
const wait = ms => new Promise(r => setTimeout(r, ms));
const out = []; let pass = 0, fail = 0;
const ok = (n, c, x) => { c ? pass++ : fail++; out.push((c ? 'PASS ' : 'FAIL ') + n + (!c && x !== undefined ? '  → ' + JSON.stringify(x).slice(0, 400) : '')); };

// the ERP's own ways (copied in kind from App.html): saveXlsxBuffer, printDoc with the window opened at the click, rclBack
const APP = `<!DOCTYPE html><html><head><title>ERP</title></head><body><h1>Diesel Issue</h1><iframe id="mod" src="/store.html"></iframe>
<script>
  var backs = 0;
  window.rclBack = function () { backs++; return backs > 1 ? 'exit' : true; };
  function saveXlsxBuffer(buf, name) { const url = URL.createObjectURL(new Blob([buf], { type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' })); const a = document.createElement('a'); a.href = url; a.download = name; document.body.appendChild(a); a.click(); setTimeout(() => { a.remove(); URL.revokeObjectURL(url); }, 4000); }
  function sheetJs(name) { const url = URL.createObjectURL(new Blob(['a,b\\n1,2'], { type: 'text/csv' })); const a = document.createElement('a'); a.download = name; a.href = url; a.click(); }
  function printDoc(title, inner, win) {
    const html = '<!DOCTYPE html><html><head><title>' + title + '</title><style>@media print { .bar { display: none; } }</style><script>function setOrient(){}<\\/script></head><body><div class="bar"><button id="xl_btn">Excel</button><button id="pr" onclick="window.print()">Print</button></div><div class="sheet">' + inner + '</div></body></html>';
    const w = win && !win.closed ? win : window.open('', '_blank');
    if (!w) { window.__noWin = 1; return; }
    w.document.open(); w.document.write(html); w.document.close();
    w.document.getElementById('xl_btn').onclick = () => saveXlsxBuffer(new Uint8Array([80, 75, 3, 4]), 'RCL_' + title + '.xlsx');
    setTimeout(() => { w.focus(); w.print(); }, 200);
  }
  function viewBill() { let w0 = window.open('', '_blank'); w0.document.write('<p>Reading…</p>'); setTimeout(() => printDoc('Bill 7', '<table><tr><td>RA Bill</td></tr></table>', w0), 300); }
<\/script></body></html>`;
const SHELL = `<!DOCTYPE html><html><head><title>Fleet ERP</title><script>window.__calls = []; window.flutter_inappwebview = { callHandler: function () { window.__calls.push([].slice.call(arguments)); return Promise.resolve(true); } };<\/script>
<script>${BRIDGE.replace(/<\/script/gi, '<\\/script')}<\/script></head>
<body><iframe id="app" style="width:100%;height:600px"></iframe><script>document.getElementById('app').srcdoc = ${JSON.stringify(APP).replace(/<\//g, '<\\/')};<\/script></body></html>`;
const STORE = `<!DOCTYPE html><html><body><h2>Store – Item Master</h2><script>function csv() { const url = URL.createObjectURL(new Blob(['\\ufeffcode,name'], { type: 'text/csv;charset=utf-8' })), a = document.createElement('a'); a.href = url; a.download = 'Items.csv'; document.body.appendChild(a); a.click(); a.remove(); }<\/script></body></html>`;

(async () => {
  const srv = http.createServer((q, s) => { s.setHeader('content-type', 'text/html; charset=utf-8'); s.end(q.url.startsWith('/store') ? STORE : SHELL); });
  await new Promise(r => srv.listen(0, '127.0.0.1', r));
  const base = 'http://127.0.0.1:' + srv.address().port;
  const b = await puppeteer.launch({ executablePath: await chromium.executablePath(), args: [...chromium.args, '--no-sandbox'], headless: 'shell' });
  const errs = [];
  try {
    const p = (await b.pages())[0] || await b.newPage();
    p.on('pageerror', e => errs.push(String(e.message)));
    await p.goto(base + '/', { waitUntil: 'load' });
    const calls = () => p.evaluate(() => window.__calls.map(c => c.map(x => typeof x === 'string' && x.length > 300 ? x.slice(0, 300) : x)));
    const app = () => p.frames().find(f => f.url() === 'about:srcdoc' && f.parentFrame() === p.mainFrame());
    const until = async (fn, ms) => { const t = Date.now(); while (Date.now() - t < (ms || 5000)) { const v = await fn(); if (v) return v; await wait(100); } return null; };
    await until(async () => { const f = app(); return f && f.evaluate(() => typeof saveXlsxBuffer === 'function').catch(() => false); });
    await wait(900); // the frames are found (every 0.7 s and at every load)

    // 1. Excel made in the ERP's frame
    await app().evaluate(() => saveXlsxBuffer(new Uint8Array([80, 75, 3, 4, 20]), 'RCL_Diesel_Issue.xlsx'));
    let c = await until(async () => (await calls()).find(x => x[0] === 'saveFile'));
    ok('Excel made in the ERP\'s frame → the app gets the file (name, type, contents)', !!c && c[1] === 'RCL_Diesel_Issue.xlsx' && /spreadsheetml/.test(c[2]) && Buffer.from(c[3], 'base64').equals(Buffer.from([80, 75, 3, 4, 20])), c);
    ok('   the page did not go anywhere (no navigation to the blob)', (await app().evaluate(() => document.querySelector('h1').textContent)) === 'Diesel Issue');

    // 2. SheetJS's way: a link that is not in the page
    await p.evaluate(() => { window.__calls = []; });
    await app().evaluate(() => sheetJs('Diesel Issue 2026-10.xlsx'));
    c = await until(async () => (await calls()).find(x => x[0] === 'saveFile'));
    ok('a file link not put in the page (XLSX.writeFile) → the app gets the file', !!c && c[1] === 'Diesel Issue 2026-10.xlsx' && Buffer.from(c[3], 'base64').toString() === 'a,b\n1,2', c);

    // 3. a module's page in a frame inside the ERP (the Store)
    await p.evaluate(() => { window.__calls = []; });
    const store = p.frames().find(f => /store\.html/.test(f.url()));
    await store.evaluate(() => csv());
    c = await until(async () => (await calls()).find(x => x[0] === 'saveFile'));
    ok('a file made in a module\'s page (frame in the frame) → the app gets it', !!c && c[1] === 'Items.csv' && /^text\/csv/.test(c[2]), c);

    // 4. the print window
    await p.evaluate(() => { window.__calls = []; });
    await app().evaluate(() => printDoc('Log Book', '<table><tr><td>MH-04-KU-3331</td><td>8 h</td></tr></table>'));
    c = await until(async () => (await calls()).find(x => x[0] === 'print'));
    const lay = await p.evaluate(() => { const l = document.getElementById('rcl_app_window'); return l && { shown: getComputedStyle(l).position === 'fixed', bar: l.firstChild.textContent }; });
    ok('print: the window opens INSIDE the app (over the page, with Close)', !!lay && lay.shown && /Close/.test(lay.bar) && /Log Book/.test(lay.bar), lay);
    ok('   its print → the app gets the page (its table, no script)', !!c && c[2] === 'Log Book' && /MH-04-KU-3331/.test(c[1]) && !/<script/i.test(c[1]) && /@media print/.test(c[1]), c);
    ok('   the ERP did not fall back to printing itself', !(await app().evaluate(() => window.__noWin)));
    await p.evaluate(() => { window.__calls = []; });
    const pw = p.frames().find(f => f.parentFrame() === p.mainFrame() && f !== app());
    await pw.evaluate(() => document.getElementById('pr').click());
    c = await until(async () => (await calls()).find(x => x[0] === 'print'));
    ok('   its own Print button → the app prints', !!c && /MH-04-KU-3331/.test(c[1]), c);
    await p.evaluate(() => { window.__calls = []; });
    await pw.evaluate(() => document.getElementById('xl_btn').click());
    c = await until(async () => (await calls()).find(x => x[0] === 'saveFile'));
    ok('   its Excel button → the app gets the Excel', !!c && c[1] === 'RCL_Log Book.xlsx', c);

    // 5. Back: the print window closes first, then the ERP's own one step back, then "leave"
    let r = await p.evaluate(() => window.__rclAppBack());
    ok('Back: closes the print window', r === 'done' && !(await p.evaluate(() => !!document.getElementById('rcl_app_window'))), r);
    r = await p.evaluate(() => window.__rclAppBack());
    ok('   then one step back in the ERP (its rclBack)', r === 'done' && (await app().evaluate(() => backs)) === 1, r);
    r = await p.evaluate(() => window.__rclAppBack());
    ok('   the ERP says "leave" → the app leaves', r === 'exit', r);

    // 6. a bill: the window opened at the click, filled later
    await p.evaluate(() => { window.__calls = []; });
    await app().evaluate(() => viewBill());
    c = await until(async () => (await calls()).find(x => x[0] === 'print'), 4000);
    ok('a saved bill (window opened first, filled later) → shown and printed', !!c && /RA Bill/.test(c[1]) && c[2] === 'Bill 7', c);
    await p.evaluate(() => window.__rclAppBack());

    // 7. a link to another site
    await p.evaluate(() => { window.__calls = []; });
    const opened = await app().evaluate(() => window.open('https://www.google.com/maps?q=17.6,74.0', '_blank'));
    c = await until(async () => (await calls()).find(x => x[0] === 'openUrl'));
    ok('window.open of another site → opened outside the app', opened === null && !!c && c[1] === 'https://www.google.com/maps?q=17.6,74.0', c);

    // 8. the page is ready
    ok('the ERP\'s page reports ready', await p.evaluate(() => window.__rclAppReady()));
    ok('one tab only', (await b.pages()).length === 1);
  } catch (e) { ok('the run finished', false, e.stack || String(e)); }
  finally { await b.close(); srv.close(); }
  ok('no script error', errs.length === 0, errs);
  console.log(out.join('\n') + '\n\nTOTAL ' + pass + ' passed, ' + fail + ' failed');
  process.exit(fail ? 1 : 0);
})();
