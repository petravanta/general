/* Hub link: the "All apps" menu every app shows. See STANDARDS.md.

   In the app's header, where the link should sit:
     <a data-hub-link href="https://petravanta.github.io/general/">All apps</a>
   Before </body>:
     <script src="https://petravanta.github.io/general/shared/hub-link.js" defer></script>

   The <a> works on its own (for example inside a claude.ai Artifact, where this script can't load).
   This script styles it as a small pill using the app's own --muted / --line / --accent tokens, then,
   once shared/apps.json has loaded, turns it into a menu: Home (the hub) plus every app, so people can
   jump straight from one app to another. If the list can't load, the pill stays a plain link to the hub.
   If an app has no [data-hub-link] element, a slim bar with the link is added at the top of <body>. */
(function () {
  var HUB = 'https://petravanta.github.io/general/';
  if (location.href.indexOf(HUB) === 0 && !/\/shared\//.test(location.pathname)) return;

  var css =
    '.hub-link{display:inline-flex;align-items:center;gap:6px;flex:none;' +
    'font:600 13px/1 var(--f-body,var(--font-body,system-ui,-apple-system,"Segoe UI",sans-serif));letter-spacing:0;' +
    'color:var(--muted,#566771);text-decoration:none;border:1px solid var(--line,#cdd6db);border-radius:999px;' +
    'padding:5px 10px 5px 8px;background:transparent;white-space:nowrap;cursor:pointer;margin:0}' +
    '.hub-link:hover,.hub-link[aria-expanded="true"]{color:var(--ink,#14212a);border-color:var(--muted,#566771)}' +
    '.hub-link:focus-visible{outline:2px solid var(--accent,#2f6fd0);outline-offset:2px}' +
    '.hub-link svg{width:14px;height:14px;flex:none}' +
    '.hub-link .hub-caret{width:10px;height:10px;margin-left:-1px;transition:transform .15s}' +
    '.hub-link[aria-expanded="true"] .hub-caret{transform:rotate(180deg)}' +
    '.hub-link-bar{display:flex;padding:8px max(16px,env(safe-area-inset-left,0px))}' +
    '.hub-menu{position:relative;display:inline-flex;flex:none}' +
    '.hub-menu-panel{position:absolute;top:calc(100% + 6px);left:0;z-index:1000;width:max-content;min-width:220px;' +
    'max-width:calc(100vw - 32px);margin:0;padding:6px;list-style:none;box-sizing:border-box;' +
    'background:var(--surface,Canvas);color:var(--ink,CanvasText);border:1px solid var(--line,#cdd6db);border-radius:12px;' +
    'box-shadow:0 10px 30px rgba(0,0,0,.18);font:500 14px/1.3 var(--f-body,var(--font-body,system-ui,-apple-system,"Segoe UI",sans-serif))}' +
    '.hub-menu-panel[hidden]{display:none}' +
    '.hub-menu-panel a{display:flex;align-items:center;gap:10px;padding:10px;border-radius:8px;' +
    'color:inherit;text-decoration:none;min-height:24px;white-space:nowrap}' +
    '.hub-menu-panel a:hover,.hub-menu-panel a:focus-visible{background:var(--sunk,rgba(127,127,127,.14));outline:none}' +
    '.hub-menu-panel a[aria-current="page"]{font-weight:700}' +
    '.hub-menu-panel a[aria-current="page"]::after{content:"Current";margin-left:auto;padding-left:12px;' +
    'font-size:12px;font-weight:500;color:var(--muted,#566771)}' +
    '.hub-menu-panel .hub-dot{width:10px;height:10px;border-radius:50%;flex:none;background:var(--app-dot)}' +
    '.hub-menu-panel .hub-home svg{width:14px;height:14px;margin:0 -2px;flex:none;color:var(--muted,#566771)}' +
    '.hub-menu-panel .hub-sep{height:1px;margin:6px 4px;background:var(--line,#cdd6db)}' +
    '@media (prefers-reduced-motion: reduce){.hub-link .hub-caret{transition:none}}';

  var icon =
    '<svg viewBox="0 0 16 16" aria-hidden="true" fill="currentColor">' +
    '<rect x="1.5" y="1.5" width="5.5" height="5.5" rx="1.4"/><rect x="9" y="1.5" width="5.5" height="5.5" rx="1.4"/>' +
    '<rect x="1.5" y="9" width="5.5" height="5.5" rx="1.4"/><rect x="9" y="9" width="5.5" height="5.5" rx="1.4"/></svg>';
  var caret =
    '<svg class="hub-caret" viewBox="0 0 10 10" aria-hidden="true" fill="none" stroke="currentColor" stroke-width="1.6" ' +
    'stroke-linecap="round" stroke-linejoin="round"><path d="M2 3.75 5 6.75 8 3.75"/></svg>';

  function esc(s) {
    return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/"/g, '&quot;');
  }

  function decorate(a) {
    if (a.classList.contains('hub-link')) return;
    a.classList.add('hub-link');
    if (!a.getAttribute('href')) a.setAttribute('href', HUB);
    var label = (a.textContent || '').trim() || 'All apps';
    a.innerHTML = icon + '<span>' + esc(label) + '</span>';
    if (!a.hasAttribute('title')) a.title = 'Back to all apps';
  }

  function isDark() {
    var t = document.documentElement.getAttribute('data-theme');
    if (t === 'dark') return true;
    if (t === 'light') return false;
    return !!(window.matchMedia && matchMedia('(prefers-color-scheme: dark)').matches);
  }

  function here(url) {
    return location.href.indexOf(url) === 0;
  }

  /* Replace the pill link with a button + panel. The wrapper keeps data-hub-link, so
     theme-switch.js still finds the header row through it. */
  function makeMenu(a, apps) {
    var label = a.querySelector('span') ? a.querySelector('span').textContent : 'All apps';
    var wrap = document.createElement('span');
    wrap.className = 'hub-menu';
    wrap.setAttribute('data-hub-link', '');

    var btn = document.createElement('button');
    btn.type = 'button';
    btn.className = 'hub-link';
    btn.setAttribute('aria-expanded', 'false');
    btn.title = 'Switch app';
    btn.innerHTML = icon + '<span>' + esc(label) + '</span>' + caret;

    var panel = document.createElement('ul');
    panel.className = 'hub-menu-panel';
    panel.id = 'hub-menu-' + Math.random().toString(36).slice(2, 8);
    panel.hidden = true;
    btn.setAttribute('aria-controls', panel.id);

    var home =
      '<li><a class="hub-home" href="' + esc(HUB) + '">' + icon + '<span>Home</span></a></li>' +
      '<li class="hub-sep" role="separator"></li>';
    var items = apps.map(function (app) {
      return '<li><a href="' + esc(app.url) + '" data-accent="' + esc(app.accent || '') + '" data-accent-dark="' +
        esc(app.accentDark || app.accent || '') + '"' + (here(app.url) ? ' aria-current="page"' : '') + '>' +
        '<span class="hub-dot" aria-hidden="true"></span><span>' + esc(app.name) + '</span></a></li>';
    });
    panel.innerHTML = home + items.join('');

    wrap.appendChild(btn);
    wrap.appendChild(panel);
    a.parentNode.replaceChild(wrap, a);

    function links() { return panel.querySelectorAll('a'); }

    function paintDots() {
      var dark = isDark(), ls = panel.querySelectorAll('a[data-accent]');
      for (var i = 0; i < ls.length; i++) {
        ls[i].style.setProperty('--app-dot', ls[i].getAttribute(dark ? 'data-accent-dark' : 'data-accent') || 'currentColor');
      }
    }

    function place() {
      panel.style.left = '0px';
      var r = panel.getBoundingClientRect(), vw = document.documentElement.clientWidth, pad = 16;
      var shift = 0;
      if (r.right > vw - pad) shift = vw - pad - r.right;
      if (r.left + shift < pad) shift = pad - r.left;
      panel.style.left = shift + 'px';
    }

    function open(focusFirst) {
      paintDots();
      panel.hidden = false;
      btn.setAttribute('aria-expanded', 'true');
      place();
      if (focusFirst) links()[0].focus();
      document.addEventListener('pointerdown', outside, true);
    }

    function close(refocus) {
      if (panel.hidden) return;
      panel.hidden = true;
      btn.setAttribute('aria-expanded', 'false');
      document.removeEventListener('pointerdown', outside, true);
      if (refocus) btn.focus();
    }

    function outside(e) {
      if (!wrap.contains(e.target)) close(false);
    }

    btn.addEventListener('click', function () {
      if (panel.hidden) open(false); else close(false);
    });
    btn.addEventListener('keydown', function (e) {
      if ((e.key === 'ArrowDown' || e.key === 'ArrowUp') && panel.hidden) {
        e.preventDefault();
        open(true);
      }
    });
    wrap.addEventListener('keydown', function (e) {
      if (e.key === 'Escape') { close(true); return; }
      if (e.target === btn) return;
      var ls = Array.prototype.slice.call(links()), i = ls.indexOf(document.activeElement);
      if (i < 0) return;
      var next = null;
      if (e.key === 'ArrowDown') next = ls[(i + 1) % ls.length];
      else if (e.key === 'ArrowUp') next = ls[(i - 1 + ls.length) % ls.length];
      else if (e.key === 'Home') next = ls[0];
      else if (e.key === 'End') next = ls[ls.length - 1];
      if (next) { e.preventDefault(); next.focus(); }
    });
    wrap.addEventListener('focusout', function (e) {
      if (e.relatedTarget && !wrap.contains(e.relatedTarget)) close(false);
    });
    window.addEventListener('resize', function () { if (!panel.hidden) place(); });
  }

  function init() {
    if (!document.getElementById('hub-link-css')) {
      var s = document.createElement('style');
      s.id = 'hub-link-css';
      s.textContent = css;
      document.head.appendChild(s);
    }
    var links = document.querySelectorAll('a[data-hub-link]');
    if (!links.length && !document.querySelector('[data-hub-link]')) {
      var bar = document.createElement('div');
      bar.className = 'hub-link-bar';
      bar.innerHTML = '<a data-hub-link href="' + HUB + '">All apps</a>';
      document.body.insertBefore(bar, document.body.firstChild);
      links = bar.querySelectorAll('a[data-hub-link]');
    }
    for (var i = 0; i < links.length; i++) decorate(links[i]);
    if (!links.length || !window.fetch) return;

    fetch(HUB + 'shared/apps.json')
      .then(function (r) { if (!r.ok) throw new Error(r.status); return r.json(); })
      .then(function (apps) {
        if (!Array.isArray(apps) || !apps.length) return;
        for (var j = 0; j < links.length; j++) if (links[j].parentNode) makeMenu(links[j], apps);
      })
      .catch(function () { /* keep the plain link to the hub */ });
  }

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init);
  else init();
})();
