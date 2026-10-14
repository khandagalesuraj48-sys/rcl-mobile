/* The app's web bridge on the REAL ERP (the local test copy: GATEWAY=1 PORTAL=1 bash rig/all.sh – Mechanical at /, the Portal at
 * /portal, the Store at /store, test data only). The bridge is put in the top page only, as the app does; the app's side
 * (flutter_inappwebview.callHandler) is a recorder. Checks: the Master's Excel export, a print window with its Excel button and
 * Print, a saved file from the Store's page, Back closing the search, and the web's Logout reaching the app.
 *   NODE_PATH=<folder with puppeteer-core and @sparticuz/chromium> node test_web/real_erp.js */
'use strict';
const fs = require('fs'), path = require('path');
const chromium = require('@sparticuz/chromium').default || require('@sparticuz/chromium'), puppeteer = require('puppeteer-core');
const BRIDGE = fs.readFileSync(path.join(__dirname, '..', 'assets', 'web_bridge.js'), 'utf8');
const G = process.env.ERP || 'http://127.0.0.1:3030';
const wait = ms => new Promise(r => setTimeout(r, ms));
const out = []; let pass = 0, fail = 0;
const ok = (n, c, x) => { c ? pass++ : fail++; out.push((c ? 'PASS ' : 'FAIL ') + n + (!c && x !== undefined ? '  → ' + JSON.stringify(x).slice(0, 500) : '')); };
const until = async (fn, ms) => { const t = Date.now(); while (Date.now() - t < (ms || 20000)) { try { const v = await fn(); if (v) return v; } catch (e) { /* changing */ } await wait(250); } return null; };

(async () => {
  const b = await puppeteer.launch({ executablePath: await chromium.executablePath(), args: [...chromium.args, '--no-sandbox'], headless: 'shell', protocolTimeout: 120000 });
  const errs = [], navs = [];
  // the test site S1 has the Store (its address = this one address), as in rig/search101.js; put back at the end
  const { execSync } = require('child_process');
  const sql = (db, q) => execSync('timeout 60 su postgres -c "psql -d ' + db + ' -tA -q"', { input: q }).toString().trim();
  const before = sql('rcl_portal', "select key || '|' || url from modules where key in ('mechanical', 'store') order by key");
  sql('rcl_portal', "update modules set url = '" + G + "' where key = 'mechanical'; insert into modules (key, name, url, status, sort) values ('store', 'Store', '" + G + "/store', 'live', 2) on conflict (key) do update set url = excluded.url, status = 'live'; " +
    "insert into access (email, site, module, role, granted_by) values ('sujit@rcl.test', 'S1', 'store', 'admin', 'test') on conflict (email, site, module) do nothing; delete from counters; update users set start_item = null where email = 'sujit@rcl.test';");
  sql('rcl', "delete from web.cache where key like 'F\\_%' or key like 'LG\\_%'; delete from store_sessions;");
  try {
    const p = (await b.pages())[0] || await b.newPage();
    await p.setViewport({ width: 412, height: 860, isMobile: true, hasTouch: true, deviceScaleFactor: 1 });
    p.on('pageerror', e => errs.push(String(e.message).slice(0, 200)));
    await p.evaluateOnNewDocument(src => {
      if (window !== window.top) return; // the app puts it in the top page only
      window.__calls = [];
      window.flutter_inappwebview = { callHandler: function () { window.__calls.push([].slice.call(arguments)); return Promise.resolve(true); } };
      (0, eval)(src);
    }, BRIDGE);
    // (web update-104) what the web's watched security policy notes inside the ERP's frame – the page switch must run no eval
    await p.evaluateOnNewDocument(() => { if (window === window.top) return; document.addEventListener('securitypolicyviolation', e => { try { (window.top.__csp = window.top.__csp || []).push(e.effectiveDirective + ' ' + (e.blockedURI || '')); } catch (x) {} }); });
    await p.setRequestInterception(true);
    p.on('request', r => { if (r.isNavigationRequest() && r.frame() === p.mainFrame() && /signout=1/.test(r.url())) { navs.push(r.url()); r.abort(); } else r.continue(); });
    const calls = () => p.evaluate(() => window.__calls || []);
    const app = () => p.frames().find(f => f.parentFrame() === p.mainFrame() && f.url() === 'about:srcdoc');

    await p.goto(G + '/portal/', { waitUntil: 'load' });
    await p.evaluate(() => localStorage.setItem('rcl_trace', JSON.stringify({ beat: Date.now() - 60000, clean: false, tab: 'x', crumbs: ['09:17:28 → orgInfo'] })));
    await p.waitForSelector('#l_email', { visible: true, timeout: 20000 });
    await p.type('#l_email', 'sujit@rcl.test'); await p.type('#l_pass', 'Nashik#Road848!'); await p.click('#l_btn');
    // (the Portal's home is drawn again once its list comes in: wait for the very link, then click it)
    const go = await until(() => p.evaluate(() => { const a = [...document.querySelectorAll('#h_sites a.mod')].find(x => /module=mechanical&site=S1/.test(x.getAttribute('href'))); if (!a || document.getElementById('v_home').hidden) return false; a.click(); return true; }), 30000);
    ok('the Portal lists the test site\'s Mechanical', !!go);
    const signed = await until(async () => app() && await app().evaluate(() => document.getElementById('login_screen').hidden && !!S.token), 60000);
    ok('the ERP opens signed in through the Portal (as the app opens it)', !!signed);
    await wait(2500);
    await app().evaluate(() => { const c = document.getElementById('cf_back'); if (c && !c.hidden) { try { closeConfirm(false); } catch (e) { document.getElementById('cf_ok').click(); } } });
    ok('the page reports ready to the app', await p.evaluate(() => window.__rclAppReady()));
    ok('no "page stopped without closing properly" box in the app', !(await app().evaluate(() => [...document.querySelectorAll('div')].some(d => /without closing properly/.test(d.textContent) && d.children.length < 6))));

    // 0. another module without loading again (the app's kept-alive web view): the web's own page switch
    let g = await p.evaluate(() => window.__rclAppGo('log'));
    let title = await until(() => app().evaluate(() => document.getElementById('page_title').textContent === 'Log Book' && 'Log Book'), 8000);
    ok('__rclAppGo("log"): the web shows the Log Book at once (no new loading)', g === 'ok' && title === 'Log Book', [g, title]);
    g = await p.evaluate(() => window.__rclAppGo('bill'));
    title = await until(() => app().evaluate(() => /Billing/.test(document.getElementById('page_title').textContent) && document.getElementById('page_title').textContent), 8000);
    ok('   then "bill": Machinery Billing', g === 'ok' && !!title, [g, title]);
    g = await p.evaluate(() => window.__rclAppGo('store__dashboard'));
    const sOpen = await until(() => app().evaluate(() => !document.getElementById('sec-ext').hidden), 15000);
    ok('   then the Store\'s Dashboard (a module inside the web)', g === 'ok' && !!sOpen, g);
    const csp = await p.evaluate(() => (window.__csp || []).filter(x => /eval/.test(x)));
    ok('   the page switches ran no eval (the web\'s security policy noted nothing)', csp.length === 0, csp);
    await app().evaluate(() => showTab('dash'));
    // 1. the Master's "Export" (XLSX.writeFile – the real Excel tool)
    await app().evaluate(() => { window.rclLoadXlsx(); showTab('master'); });
    await until(() => app().evaluate(() => typeof XLSX !== 'undefined'), 20000);
    await p.evaluate(() => { window.__calls = []; });
    await app().evaluate(() => document.getElementById('m_export').click());
    let c = await until(async () => (await calls()).find(x => x[0] === 'saveFile'), 20000);
    ok('Master › Export: the Excel reaches the app (RCL_Master_<date>.xlsx, a real .xlsx; the app types it by its name)', !!c && /^RCL_Master_\d{4}-\d{2}-\d{2}\.xlsx$/.test(c[1]) && Buffer.from(c[3], 'base64').slice(0, 2).toString() === 'PK' && Buffer.from(c[3], 'base64').length > 1000, c && c.slice(0, 3));

    // 2. a print window (the ERP's own printDoc) – inside the app, its Excel button, its Print
    await p.evaluate(() => { window.__calls = []; });
    await app().evaluate(() => printDoc('Log Book – test', '<section class="p-page"><table><tr><th>Machinery</th><th>Hours</th></tr><tr><td>MH-04-KU-3331</td><td>8</td></tr></table></section>', 'rep', false, 'Rachana Construction Limited'));
    c = await until(async () => (await calls()).find(x => x[0] === 'print'), 15000);
    const lay = await p.evaluate(() => { const l = document.getElementById('rcl_app_window'); return l && l.firstChild.textContent; });
    ok('print: the ERP\'s print window opens inside the app (Close bar, its title)', !!lay && /Close/.test(lay) && /Log Book – test/.test(lay), lay);
    ok('   and the page goes to the app\'s printing (its table, without scripts)', !!c && /MH-04-KU-3331/.test(c[1]) && !/<script/i.test(c[1]) && c[2] === 'Log Book – test', c && [c[0], c[2]]);
    await p.evaluate(() => { window.__calls = []; });
    const pw = p.frames().find(f => f.parentFrame() === p.mainFrame() && f !== app());
    await pw.evaluate(() => document.getElementById('xl_btn').click());
    c = await until(async () => (await calls()).find(x => x[0] === 'saveFile'), 30000);
    ok('   its "Excel" button: the formatted Excel reaches the app', !!c && /\.xlsx$/.test(c[1]) && Buffer.from(c[3], 'base64').slice(0, 2).toString() === 'PK', c && c.slice(0, 3));
    await p.evaluate(() => { window.__calls = []; });
    await pw.evaluate(() => [...document.querySelectorAll('.bar button')].find(x => x.textContent === 'Print').click());
    c = await until(async () => (await calls()).find(x => x[0] === 'print'), 5000);
    ok('   its "Print" button: the app prints', !!c);
    let r = await p.evaluate(() => window.__rclAppBack());
    ok('Back closes the print window', r === 'done' && !(await p.evaluate(() => !!document.getElementById('rcl_app_window'))), r);

    // 3. Back inside the ERP: the search (Ctrl K) open → Back closes it
    await app().evaluate(() => gsOpen());
    if (process.env.DEBUG) console.log(await app().evaluate(() => ['cf_back', 'pw_back', 'dlg_back', 'le_back', 'rule_back', 'fixbox', 'guidebox', 'gs_back', 'ai_panel'].filter(id => { const e = document.getElementById(id); return e && !e.hidden && e.getClientRects().length; }).concat(document.querySelector('.app').classList.contains('nav-open') ? ['nav-open'] : [])));
    r = await p.evaluate(() => window.__rclAppBack());
    ok('Back with the search open: the search closes (the ERP\'s own one step)', r === 'done' && await app().evaluate(() => document.getElementById('gs_back').hidden), r);

    // 4. the Store's page inside the ERP (a frame in the frame) is reached too
    const st = await app().evaluate(() => { const m = document.querySelector('#grp_mods .modgrp[data-mod="store"] .navbtn[data-page]'); if (m) m.click(); return !!m; });
    if (st) {
      const sf = await until(() => p.frames().find(f => /\/store\/\?embed=1/.test(f.url())), 20000);
      await wait(1500);
      await p.evaluate(() => { window.__calls = []; });
      await sf.evaluate(() => { const a = document.createElement('a'); a.href = URL.createObjectURL(new Blob(['code,name'], { type: 'text/csv' })); a.download = 'Store test.csv'; document.body.appendChild(a); a.click(); a.remove(); });
      c = await until(async () => (await calls()).find(x => x[0] === 'saveFile'), 5000);
      ok('a file from the Store\'s page (inside the ERP) reaches the app', !!c && c[1] === 'Store test.csv', c);
      await app().evaluate(() => showTab('dash'));
    } else ok('the Store is in the menu (test site S1)', false);

    // 5. the web's Logout → the Portal's ?signout=1 (the app turns it into its own sign-out)
    await app().evaluate(() => document.getElementById('u_logout').click());
    await until(() => app().evaluate(() => !document.getElementById('cf_back').hidden), 5000);
    await app().evaluate(() => document.getElementById('cf_ok').click());
    const nav = await until(() => navs.length && navs[0], 15000);
    ok('the web\'s Logout goes to the Portal with ?signout=1 (the app catches it)', !!nav && /\/portal\/\?signout=1$/.test(nav), navs);
  } catch (e) { ok('the run finished', false, e.stack || String(e)); }
  finally {
    await b.close();
    before.split('\n').filter(Boolean).forEach(l => { const [k, u] = l.split('|'); sql('rcl_portal', "update modules set url = '" + u + "' where key = '" + k + "';"); });
    sql('rcl_portal', "delete from access where granted_by = 'test' and module = 'store';");
  }
  // (the web's sign-out asks the browser's password store not to sign in by itself – headless Chromium answers that with an
  //  error; a phone's web view has no such store, so the web skips it there)
  const real = errs.filter(e => !/does not support public key credentials/.test(e));
  ok('no script error on any page', real.length === 0, real);
  console.log(out.join('\n') + '\n\nTOTAL ' + pass + ' passed, ' + fail + ' failed');
  process.exit(fail ? 1 : 0);
})();
