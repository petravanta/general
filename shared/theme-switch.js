/* Theme switch: lets people pick System, Light or Dark in every app. See STANDARDS.md.

   In <head>, before any CSS, so the saved choice applies before the first paint:
     <script>try{var t=localStorage.getItem('petravanta.theme');if(t==='light'||t==='dark')document.documentElement.dataset.theme=t}catch(e){}</script>
   Before </body>:
     <script src="https://petravanta.github.io/general/shared/theme-switch.js" defer></script>

   The button goes into a [data-theme-switch] element if the page has one, otherwise at the end of the
   row that holds the [data-hub-link]. The choice is stored under one key on petravanta.github.io, so
   it carries across all the apps. Apps only need their tokens to follow STANDARDS.md: dark values under
   :root:not([data-theme="light"]) in the media query and again under :root[data-theme="dark"].

   An app with its own theme setting stays in step both ways: the button follows any change the app
   makes to data-theme, and a click fires a "petravanta:themechange" event on document with
   detail.mode set to 'system', 'light' or 'dark', so the app can save it too. */
(function () {
  var KEY = 'petravanta.theme';
  var MODES = ['system', 'light', 'dark'];
  var NAMES = { system: 'Match system', light: 'Light', dark: 'Dark' };
  var ICONS = {
    system: '<circle cx="8" cy="8" r="6" fill="none" stroke="currentColor" stroke-width="1.5"/><path d="M8 2a6 6 0 0 1 0 12z" fill="currentColor"/>',
    light: '<circle cx="8" cy="8" r="3" fill="currentColor"/><g stroke="currentColor" stroke-width="1.5" stroke-linecap="round">' +
      '<path d="M8 1.5v1.5M8 13v1.5M1.5 8H3M13 8h1.5M3.4 3.4l1.1 1.1M11.5 11.5l1.1 1.1M3.4 12.6l1.1-1.1M11.5 4.5l1.1-1.1"/></g>',
    dark: '<path d="M13.5 9.6A5.8 5.8 0 0 1 6.4 2.5a5.8 5.8 0 1 0 7.1 7.1z" fill="currentColor"/>'
  };

  var css =
    '.theme-switch{display:inline-flex;align-items:center;justify-content:center;flex:none;width:30px;height:30px;padding:0;' +
    'color:var(--muted,#566771);background:transparent;border:1px solid var(--line,#cdd6db);border-radius:999px;cursor:pointer}' +
    '.theme-switch:hover{color:var(--ink,#14212a);border-color:var(--muted,#566771)}' +
    '.theme-switch:focus-visible{outline:2px solid var(--accent,#2f6fd0);outline-offset:2px}' +
    '.theme-switch svg{width:16px;height:16px}' +
    '.theme-switch-auto{margin-left:auto}' +
    '@media (pointer:coarse){.theme-switch{width:40px;height:40px}}';

  function read() {
    try { var t = localStorage.getItem(KEY); if (t === 'system' || t === 'light' || t === 'dark') return t; } catch (e) {}
    // Nothing chosen on this device yet: keep whatever the page already shows
    var a = document.documentElement.getAttribute('data-theme');
    return a === 'light' || a === 'dark' ? a : 'system';
  }

  function apply(mode) {
    var root = document.documentElement;
    if (mode === 'system') root.removeAttribute('data-theme');
    else root.setAttribute('data-theme', mode);
    // Keep the browser's toolbar color in step with a forced theme
    var metas = document.querySelectorAll('meta[name="theme-color"][media], meta[name="theme-color"][data-media]');
    for (var i = 0; i < metas.length; i++) {
      var m = metas[i], media = m.getAttribute('data-media') || m.getAttribute('media');
      m.setAttribute('data-media', media);
      var isDark = /dark/.test(media);
      m.setAttribute('media', mode === 'system' ? media : (isDark === (mode === 'dark') ? 'all' : 'not all'));
    }
  }

  function save(mode) {
    try { localStorage.setItem(KEY, mode); } catch (e) {}
  }

  function render(btn, mode) {
    var next = MODES[(MODES.indexOf(mode) + 1) % MODES.length];
    btn.innerHTML = '<svg viewBox="0 0 16 16" aria-hidden="true">' + ICONS[mode] + '</svg>';
    btn.setAttribute('aria-label', 'Theme: ' + NAMES[mode] + '. Switch to ' + NAMES[next]);
    btn.title = 'Theme: ' + NAMES[mode];
  }

  function init() {
    if (!document.getElementById('theme-switch-css')) {
      var s = document.createElement('style');
      s.id = 'theme-switch-css';
      s.textContent = css;
      document.head.appendChild(s);
    }
    var btn = document.createElement('button');
    btn.type = 'button';
    btn.className = 'theme-switch';
    var slot = document.querySelector('[data-theme-switch]');
    var hub = document.querySelector('[data-hub-link]');
    if (slot) slot.appendChild(btn);
    else if (hub && hub.parentNode) { btn.classList.add('theme-switch-auto'); hub.parentNode.appendChild(btn); }
    else return;

    var mode = read();
    apply(mode);
    render(btn, mode);
    btn.addEventListener('click', function () {
      mode = MODES[(MODES.indexOf(mode) + 1) % MODES.length];
      save(mode);
      apply(mode);
      render(btn, mode);
      document.dispatchEvent(new CustomEvent('petravanta:themechange', { detail: { mode: mode } }));
    });
    // The app changed the theme itself (for example from its own settings)
    new MutationObserver(function () {
      var t = document.documentElement.getAttribute('data-theme');
      var now = t === 'light' || t === 'dark' ? t : 'system';
      if (now === mode) return;
      mode = now;
      save(mode);
      apply(mode);
      render(btn, mode);
    }).observe(document.documentElement, { attributes: true, attributeFilter: ['data-theme'] });
    // Another tab or app changed it
    window.addEventListener('storage', function (e) {
      if (e.key !== KEY) return;
      mode = read();
      apply(mode);
      render(btn, mode);
    });
  }

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init);
  else init();
})();
