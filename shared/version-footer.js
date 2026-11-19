/* Version footer: a small line at the bottom of every app saying which build is running. See STANDARDS.md,
   "Version and build info".

   Before </body>, next to hub-link.js:
     <script src="https://petravanta.github.io/general/shared/version-footer.js" defer></script>

   It reads version.json next to the page, which the app's Pages workflow writes when it deploys:
     { "version": "1.4.0", "commit": "<full sha>", "built": "2026-11-11T09:23:35Z", "repo": "petravanta/<repo>" }
   ("version" is optional and comes from the app's own version.json if it keeps one; the rest is stamped.)
   and shows:  v1.4.0 · a1b2c3d · built 11 Nov 2026, 09:23
   The short commit links to that commit on GitHub. Tapping "Copy debug info" copies the app, build, page URL,
   browser, theme and service-worker state as plain text, ready to paste into a bug report or a chat.

   If version.json is missing (not stamped yet, a local file, a claude.ai Artifact), it falls back to the page's
   Last-Modified date and says "unstamped", so the footer is never empty.

   The line goes into a [data-version-footer] element if the page has one (use that when the app has a fixed
   bottom bar, so the line isn't hidden behind it), otherwise into a <footer> added at the end of <body>.
   Styled with the app's own --muted / --line / --accent tokens, so it follows light and dark themes.
   Also sets window.APP_BUILD to the info it found, for the app's own error reports. */
(function () {
  var css =
    '.version-footer{display:flex;flex-wrap:wrap;justify-content:center;align-items:center;gap:4px 10px;' +
    'margin:24px 0 0;padding:12px max(16px,env(safe-area-inset-left,0px)) max(12px,env(safe-area-inset-bottom,0px));' +
    'border-top:1px solid var(--line,#cdd6db);color:var(--muted,#566771);' +
    'font:500 12px/1.4 var(--f-body,var(--font-body,system-ui,-apple-system,"Segoe UI",sans-serif));text-align:center}' +
    '.version-footer code{font:inherit;font-family:ui-monospace,SFMono-Regular,Menlo,Consolas,monospace;font-size:11.5px}' +
    '.version-footer a{color:inherit;text-decoration:underline;text-decoration-color:var(--line,#cdd6db);text-underline-offset:2px}' +
    '.version-footer a:hover{color:var(--ink,#14212a)}' +
    '.version-footer button{font:inherit;color:inherit;background:transparent;border:1px solid var(--line,#cdd6db);' +
    'border-radius:999px;padding:4px 10px;min-height:28px;cursor:pointer}' +
    '.version-footer button:hover{color:var(--ink,#14212a);border-color:var(--muted,#566771)}' +
    '.version-footer :focus-visible{outline:2px solid var(--accent,#2f6fd0);outline-offset:2px}';

  function fmtDate(iso) {
    var d = new Date(iso);
    if (isNaN(d)) return '';
    try {
      return d.toLocaleString(undefined, { day: 'numeric', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' });
    } catch (e) { return d.toISOString().slice(0, 16).replace('T', ' '); }
  }

  function guessRepo() {
    // petravanta.github.io/<repo>/...
    var m = /^\/([^\/]+)\//.exec(location.pathname);
    return location.hostname === 'petravanta.github.io' && m ? 'petravanta/' + m[1] : '';
  }

  function swState() {
    if (!('serviceWorker' in navigator)) return 'unsupported';
    return navigator.serviceWorker.controller ? 'active' : 'none';
  }

  function debugText(b) {
    var theme = document.documentElement.dataset.theme || 'system';
    var dark = window.matchMedia && matchMedia('(prefers-color-scheme: dark)').matches;
    return [
      'App: ' + (document.title || location.pathname),
      'Version: ' + (b.version || '-'),
      'Commit: ' + (b.commit || 'unstamped'),
      'Built: ' + (b.built || '-') + (b.stamped ? '' : ' (from Last-Modified)'),
      'URL: ' + location.href,
      'Browser: ' + navigator.userAgent,
      'Screen: ' + innerWidth + 'x' + innerHeight + ' @' + (window.devicePixelRatio || 1) + 'x' +
        (matchMedia('(display-mode: standalone)').matches ? ', installed' : ''),
      'Theme: ' + theme + (theme === 'system' ? (dark ? ' (dark)' : ' (light)') : ''),
      'Service worker: ' + swState(),
      'Online: ' + navigator.onLine,
      'Time: ' + new Date().toISOString()
    ].join('\n');
  }

  function render(b) {
    window.APP_BUILD = b;
    var host = document.querySelector('[data-version-footer]');
    if (!host) {
      host = document.createElement('footer');
      document.body.appendChild(host);
    }
    host.classList.add('version-footer');
    host.setAttribute('aria-label', 'Version and build info');

    var parts = [];
    if (b.version) parts.push('<span>v' + esc(b.version) + '</span>');
    if (b.commit) {
      var short = esc(b.commit.slice(0, 7));
      parts.push(b.repo
        ? '<a href="https://github.com/' + esc(b.repo) + '/commit/' + esc(b.commit) + '" target="_blank" rel="noopener"><code>' + short + '</code></a>'
        : '<code>' + short + '</code>');
    } else {
      parts.push('<span>unstamped</span>');
    }
    var when = b.built && fmtDate(b.built);
    if (when) parts.push('<span>built ' + esc(when) + '</span>');
    host.innerHTML = parts.join('<span aria-hidden="true">·</span>') + '<button type="button">Copy debug info</button>';

    var btn = host.querySelector('button');
    btn.addEventListener('click', function () {
      var text = debugText(b);
      var done = function () { btn.textContent = 'Copied'; setTimeout(function () { btn.textContent = 'Copy debug info'; }, 1600); };
      if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(text).then(done, function () { fallbackCopy(text); done(); });
      } else { fallbackCopy(text); done(); }
    });
  }

  function fallbackCopy(text) {
    var t = document.createElement('textarea');
    t.value = text; t.setAttribute('readonly', ''); t.style.position = 'fixed'; t.style.opacity = '0';
    document.body.appendChild(t); t.select();
    try { document.execCommand('copy'); } catch (e) {}
    t.remove();
  }

  function esc(s) {
    return String(s).replace(/[&<>"']/g, function (c) { return '&#' + c.charCodeAt(0) + ';'; });
  }

  function start() {
    var style = document.createElement('style');
    style.textContent = css;
    document.head.appendChild(style);

    var fallback = { stamped: false, repo: guessRepo(), built: new Date(document.lastModified).toISOString() };
    if (location.protocol === 'file:') { render(fallback); return; }
    // version.json is fetched fresh (the shared service worker still serves it from cache when offline).
    fetch(new URL('version.json', location.href).href, { cache: 'no-cache' })
      .then(function (r) { if (!r.ok) throw 0; return r.json(); })
      .then(function (v) {
        render({
          stamped: !!v.commit, version: v.version || '', commit: v.commit || '',
          built: v.built || fallback.built, repo: v.repo || fallback.repo
        });
      })
      .catch(function () { render(fallback); });
  }

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', start);
  else start();
})();
