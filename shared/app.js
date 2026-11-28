/* One tag for the shared page scripts of petravanta's apps. See STANDARDS.md, "Shared code".

   Just before </body>:
     <script src="https://petravanta.github.io/general/shared/app.js" defer></script>

   It loads, in this order: back-stack.js (Back closes the view in front), hub-link.js (the All apps menu),
   theme-switch.js (System / Light / Dark) and version-footer.js (build line), from the same folder as itself,
   and registers the app's own sw.js (installing and offline use). A shared script added here later reaches
   every app without touching it. Scripts already on the page are not loaded twice, so an app can move to
   this tag at its own pace.

   Options, as attributes on the tag:
     data-skip="hub-link version-footer"   leave out the named scripts
     data-no-sw                            don't register sw.js (an app that registers its own elsewhere) */
(function () {
  var me = document.currentScript;
  var base = me && me.src ? me.src.replace(/[^/]*$/, '') : 'https://petravanta.github.io/general/shared/';
  var skip = ((me && me.getAttribute('data-skip')) || '').split(/[\s,]+/);
  var SCRIPTS = ['back-stack', 'hub-link', 'theme-switch', 'version-footer'];

  SCRIPTS.forEach(function (name) {
    if (skip.indexOf(name) >= 0) return;
    if (document.querySelector('script[src$="/' + name + '.js"]')) return;
    var s = document.createElement('script');
    s.src = base + name + '.js';
    s.async = false; // run in the order above
    document.head.appendChild(s);
  });

  if (!(me && me.hasAttribute('data-no-sw')) && 'serviceWorker' in navigator &&
      /^(petravanta\.github\.io|localhost|127\.0\.0\.1)$/.test(location.hostname)) {
    navigator.serviceWorker.register('sw.js').catch(function () {});
  }
})();
