/* RCL ERP app – what the web ERP needs from the phone (14-10-2026: "web warcha full access app war").
 * The app shows the very same web ERP (every page, the same access). A phone's web view cannot do three things a browser
 * does by itself, so this small script, put into the app's web view, hands them to the app:
 *   1. a file the web saves (Excel, CSV, a snapshot) – the web makes it in the page (a "blob:" / "data:" link): the file is
 *      read here and given to the app ("saveFile"), which offers it to open / share / keep;
 *   2. the print window (window.open('', '_blank') + write + print): the window is shown INSIDE the app, over the page, with a
 *      "Close" bar – its own Portrait / Landscape / Excel / Print buttons work as on the computer; "Print" gives the page to the
 *      app ("print"), which opens Android's printing (a printer or "Save as PDF");
 *   3. a link to another site (the photo in full size, the map, the backup sheet) opens outside the app ("openUrl").
 * The phone's Back button asks the web for one step back (window.__rclAppBack → the web's own rclBack).
 * Nothing else of the web is changed; the frames of the page are found by themselves (the ERP is in a frame, a module's page
 * in a frame inside it). */
(function () {
  'use strict';
  var T = window;
  if (T.__rclAppBridge) return;
  T.__rclAppBridge = 1;

  function call(name) {
    var args = [].slice.call(arguments, 1);
    try {
      var b = T.flutter_inappwebview;
      if (b && typeof b.callHandler === 'function') return Promise.resolve(b.callHandler.apply(b, [name].concat(args)));
    } catch (e) { /* the app is not there (a browser) */ }
    return Promise.resolve(null);
  }

  /* ---- 1. a file made in the page ---- */
  function nameOf(a) {
    var n = (a && (a.getAttribute('download') || '')) || '';
    return n || 'RCL_file';
  }
  function saveLink(w, href, name) {
    return w.fetch(href).then(function (r) { return r.blob(); }).then(function (b) {
      return new Promise(function (ok, no) {
        var fr = new w.FileReader();
        fr.onload = function () { ok({ d: String(fr.result || ''), t: b.type || '' }); };
        fr.onerror = function () { no(fr.error); };
        fr.readAsDataURL(b);
      });
    }).then(function (x) {
      var i = x.d.indexOf(',');
      return call('saveFile', name, x.t, i > -1 ? x.d.slice(i + 1) : '');
    }).catch(function () { return call('saveFailed', name); });
  }
  function isFileLink(h) { return /^(blob:|data:)/i.test(String(h || '')); }

  /* ---- 2. the print window inside the app ---- */
  var layer = null;
  function closeLayer() {
    if (!layer) return false;
    try { layer.remove(); } catch (e) { /* gone */ }
    layer = null;
    return true;
  }
  function htmlOf(doc) {
    var c = doc.documentElement.cloneNode(true);
    [].forEach.call(c.querySelectorAll('script'), function (s) { s.parentNode.removeChild(s); });
    return '<!DOCTYPE html>' + c.outerHTML;
  }
  function printOf(w) {
    try { return call('print', htmlOf(w.document), String(w.document.title || 'RCL ERP')); }
    catch (e) { return call('saveFailed', 'print'); }
  }
  function openLayer() {
    closeLayer();
    var d = T.document, box = d.createElement('div'), bar = d.createElement('div'), x = d.createElement('button'), t = d.createElement('span'), f = d.createElement('iframe');
    box.id = 'rcl_app_window';
    box.style.cssText = 'position:fixed;left:0;top:0;right:0;bottom:0;z-index:2147483647;background:#fff;display:flex;flex-direction:column';
    bar.style.cssText = 'flex:0 0 auto;display:flex;align-items:center;gap:10px;padding:8px 10px;background:#1B5E20;color:#fff;font:600 15px system-ui,sans-serif';
    x.type = 'button';
    x.textContent = '✕  Close';
    x.style.cssText = 'background:rgba(255,255,255,.18);color:#fff;border:0;border-radius:18px;padding:9px 16px;font:600 14px system-ui,sans-serif';
    x.onclick = closeLayer;
    t.style.cssText = 'overflow:hidden;white-space:nowrap;text-overflow:ellipsis';
    t.textContent = 'Print';
    f.style.cssText = 'flex:1 1 auto;width:100%;border:0;background:#fff';
    f.setAttribute('title', 'Print');
    bar.appendChild(x); bar.appendChild(t); box.appendChild(bar); box.appendChild(f);
    (d.body || d.documentElement).appendChild(box);
    layer = box;
    var fix = function () {
      try {
        var cw = f.contentWindow;
        if (!cw) return;
        cw.print = function () { printOf(cw); };
        cw.close = closeLayer;
        if (cw.document && cw.document.title) t.textContent = cw.document.title;
      } catch (e) { /* not ready */ }
    };
    fix();
    f.addEventListener('load', fix);
    return f.contentWindow;
  }

  /* ---- every frame of the page ---- */
  function hook(w) {
    var doc;
    try { doc = w.document; if (!doc || doc.__rclHook) return; doc.__rclHook = 1; } catch (e) { return; } // another site's frame
    if (layer && w.frameElement && layer.contains(w.frameElement)) return; // the print window: done in openLayer
    var onClick = function (e) {
      var a = e.target;
      while (a && a.nodeName !== 'A') a = a.parentNode;
      if (!a || !isFileLink(a.href)) return;
      e.preventDefault();
      e.stopPropagation();
      saveLink(w, a.href, nameOf(a));
    };
    try { if (w.__rclClick) w.removeEventListener('click', w.__rclClick, true); } catch (e) { /* none */ }
    w.__rclClick = onClick;
    w.addEventListener('click', onClick, true);
    try {
      var P = w.HTMLAnchorElement.prototype;
      if (!P.__rclClick) {
        var oc = P.click;
        P.click = function () {
          // a link not in the page gets no click event – its file is taken here
          if (isFileLink(this.href) && !this.isConnected) { saveLink(w, this.href, nameOf(this)); return; }
          return oc.apply(this, arguments);
        };
        P.__rclClick = 1;
      }
    } catch (e) { /* as it is */ }
    w.open = function (u) {
      var s = u == null ? '' : String(u);
      if (!s || s === 'about:blank') return openLayer();
      try { s = new w.URL(s, doc.baseURI).href; } catch (e) { /* as given */ }
      call('openUrl', s);
      return null;
    };
    w.print = function () { printOf(w); };
  }
  function walk(w, depth) {
    hook(w);
    var fs;
    try { fs = w.frames; } catch (e) { return; }
    for (var i = 0; i < fs.length && depth < 4; i++) walk(fs[i], depth + 1);
  }

  /* ---- the phone's Back: the print window first, then one step back in the web ---- */
  T.__rclAppBack = function () {
    if (closeLayer()) return 'done';
    try {
      var f = T.document.getElementById('app'), w = f && f.contentWindow;
      if (w && typeof w.rclBack === 'function') return w.rclBack() === 'exit' ? 'exit' : 'done';
    } catch (e) { /* not the ERP's page */ }
    return 'none';
  };
  /* ---- the web's page is ready (the ERP in its frame, or another page of the site) ---- */
  T.__rclAppReady = function () {
    try {
      var f = T.document.getElementById('app');
      if (!f) return T.document.readyState === 'complete';
      var w = f.contentWindow, d = w && w.document;
      return !!(d && d.readyState === 'complete' && d.body && d.body.children.length);
    } catch (e) { return true; }
  };

  walk(T, 0);
  T.addEventListener('load', function () { walk(T, 0); }, true);
  T.setInterval(function () { walk(T, 0); }, 700);
})();
