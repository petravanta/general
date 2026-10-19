/* Offline shell for every app: see STANDARDS.md, "Installing on a phone".

   Each app's own sw.js lists the files it needs to open offline, then loads this:
     self.APP_SHELL = ['./', 'manifest.webmanifest', 'icon-192.png', 'data/skills.json'];
     importScripts('https://petravanta.github.io/general/shared/app-sw.js');

   - Pages are fetched network-first, so a new version shows the next time the app opens online,
     and any URL in the app's scope (shortcut links like ?do=log included) opens the cached page offline.
   - The app's own files and the hub's shared scripts (same origin) are network-first with the cache as fallback.
   - Google Fonts are cache-first: their files never change.
   - Everything else (Google sign-in, Drive, Photos, food databases, CDNs) goes straight to the network.
   User data is never cached here; it lives in the browser's storage and the user's Drive. */
var SCOPE = self.registration.scope;
var CACHE = 'app-shell-' + new URL(SCOPE).pathname;
var SHARED = [
  'https://petravanta.github.io/general/shared/hub-link.js',
  'https://petravanta.github.io/general/shared/theme-switch.js',
  'https://petravanta.github.io/general/shared/apps.json'
];

self.addEventListener('install', function (e) {
  var files = (self.APP_SHELL || ['./']).map(function (f) { return new URL(f, SCOPE).href; });
  e.waitUntil(caches.open(CACHE).then(function (c) {
    // One missing file shouldn't stop the app from installing, so add them one by one.
    return Promise.all(files.concat(SHARED).map(function (f) { return c.add(f).catch(function () {}); }));
  }).then(function () { return self.skipWaiting(); }));
});

self.addEventListener('activate', function (e) {
  e.waitUntil(self.clients.claim());
});

function networkFirst(req, key) {
  return fetch(req).then(function (res) {
    if (res.ok) { var copy = res.clone(); caches.open(CACHE).then(function (c) { c.put(key || req, copy); }); }
    return res;
  }).catch(function () {
    return caches.match(key || req).then(function (hit) { return hit || Response.error(); });
  });
}

self.addEventListener('fetch', function (e) {
  var req = e.request, u = new URL(req.url);
  if (req.method !== 'GET') return;
  if (req.mode === 'navigate') {
    if (req.url.indexOf(SCOPE) === 0) e.respondWith(networkFirst(req, SCOPE));
    return;
  }
  if (u.hostname === 'fonts.googleapis.com' || u.hostname === 'fonts.gstatic.com') {
    e.respondWith(caches.open(CACHE).then(function (c) {
      return c.match(req).then(function (hit) {
        return hit || fetch(req).then(function (res) { if (res.ok || res.type === 'opaque') c.put(req, res.clone()); return res; });
      });
    }));
    return;
  }
  if (u.origin === location.origin) e.respondWith(networkFirst(req));
});
