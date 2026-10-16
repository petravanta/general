/* Hub link: the "back to all apps" link every app shows. See STANDARDS.md.

   In the app's header, where the link should sit:
     <a data-hub-link href="https://petravanta.github.io/general/">All apps</a>
   Before </body>:
     <script src="https://petravanta.github.io/general/shared/hub-link.js" defer></script>

   The <a> works on its own (for example inside a claude.ai Artifact, where this script can't load).
   This script styles it as a small pill using the app's own --muted / --line / --accent tokens.
   If an app has no [data-hub-link] element, a slim bar with the link is added at the top of <body>. */
(function () {
  var HUB = 'https://petravanta.github.io/general/';
  if (location.href.indexOf(HUB) === 0 && !/\/shared\//.test(location.pathname)) return;

  var css =
    '.hub-link{display:inline-flex;align-items:center;gap:6px;flex:none;' +
    'font:600 13px/1 var(--f-body,var(--font-body,system-ui,-apple-system,"Segoe UI",sans-serif));letter-spacing:0;' +
    'color:var(--muted,#566771);text-decoration:none;border:1px solid var(--line,#cdd6db);border-radius:999px;' +
    'padding:5px 10px 5px 8px;background:transparent;white-space:nowrap}' +
    '.hub-link:hover{color:var(--ink,#14212a);border-color:var(--muted,#566771)}' +
    '.hub-link:focus-visible{outline:2px solid var(--accent,#2f6fd0);outline-offset:2px}' +
    '.hub-link svg{width:14px;height:14px;flex:none}' +
    '.hub-link-bar{display:flex;padding:8px max(16px,env(safe-area-inset-left,0px))}';

  var icon =
    '<svg viewBox="0 0 16 16" aria-hidden="true" fill="currentColor">' +
    '<rect x="1.5" y="1.5" width="5.5" height="5.5" rx="1.4"/><rect x="9" y="1.5" width="5.5" height="5.5" rx="1.4"/>' +
    '<rect x="1.5" y="9" width="5.5" height="5.5" rx="1.4"/><rect x="9" y="9" width="5.5" height="5.5" rx="1.4"/></svg>';

  function decorate(a) {
    if (a.classList.contains('hub-link')) return;
    a.classList.add('hub-link');
    if (!a.getAttribute('href')) a.setAttribute('href', HUB);
    var label = (a.textContent || '').trim() || 'All apps';
    a.innerHTML = icon + '<span>' + label.replace(/</g, '&lt;') + '</span>';
    if (!a.hasAttribute('title')) a.title = 'Back to all apps';
  }

  function init() {
    if (!document.getElementById('hub-link-css')) {
      var s = document.createElement('style');
      s.id = 'hub-link-css';
      s.textContent = css;
      document.head.appendChild(s);
    }
    var links = document.querySelectorAll('[data-hub-link]');
    if (!links.length) {
      var bar = document.createElement('div');
      bar.className = 'hub-link-bar';
      bar.innerHTML = '<a data-hub-link href="' + HUB + '">All apps</a>';
      document.body.insertBefore(bar, document.body.firstChild);
      links = bar.querySelectorAll('[data-hub-link]');
    }
    for (var i = 0; i < links.length; i++) decorate(links[i]);
  }

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init);
  else init();
})();
