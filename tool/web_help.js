// The web's own help, taken out of the web page as it is, for the app (3.15.0): help for every error (FIX_RULES, FIX_ANY,
// FIX_W) and what every page is for (PAGE_GUIDE, REPORT_GUIDE, GUIDE_W) – English, मराठी, हिंदी.
//   node tool/web_help.js <the web's app/App.html> assets/help/web_help.json
// Run it again whenever the web's help changes (a new error rule, a new page), so the app says what the web says.
const vm = require('vm'), fs = require('fs');
const [page, out] = process.argv.slice(2);
if (!page || !out) { console.error('node tool/web_help.js <App.html> <out.json>'); process.exit(1); }
const L = fs.readFileSync(page, 'utf8').split('\n');
// a constant as written: from its line, as many lines as make it whole (it parses)
function constText(name) {
  const i = L.findIndex(l => new RegExp('^\\s*const ' + name + ' = ').test(l)); if (i < 0) throw new Error('no ' + name);
  for (let k = i; k < i + 2000; k++) { const t = L.slice(i, k + 1).join('\n'); try { new vm.Script(t); return t; } catch (e) { /* not whole yet */ } }
  throw new Error('not whole ' + name);
}
const names = ['FIX_RULES', 'FIX_ANY', 'FIX_W', 'PAGE_GUIDE', 'REPORT_GUIDE', 'GUIDE_W'], ctx = {};
vm.createContext(ctx);
vm.runInContext(names.map(constText).join('\n') + '\nObject.assign(globalThis, {' + names.join(', ') + '});', ctx);
const lang = g => ({ en: g.en, mr: g.mr, hi: g.hi });
const help = {
  fix: ctx.FIX_RULES.map(r => ({ re: r.re.source, flags: r.re.flags, ...lang(r) })),
  fixAny: lang(ctx.FIX_ANY), fixW: ctx.FIX_W,
  pages: Object.fromEntries(Object.entries(ctx.PAGE_GUIDE).map(([k, g]) => [k, lang(g)])),
  reports: Object.fromEntries(Object.entries(ctx.REPORT_GUIDE).map(([k, g]) => [k, lang(g)])),
  guideW: ctx.GUIDE_W,
};
fs.writeFileSync(out, JSON.stringify(help) + '\n');
console.log('error rules', help.fix.length, '· pages', Object.keys(help.pages).length, '· reports', Object.keys(help.reports).length);
