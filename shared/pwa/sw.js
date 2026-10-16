// Template: copy next to the app's index.html as sw.js and rename the cache (bump the version to force a refresh).
// Offline shell (petravanta's apps standard, see general/STANDARDS.md): the app opens without a connection.
// Pages come from the network when possible and from this cache otherwise. User data never goes in here; it lives in Google Drive.
const CACHE='APP-v1';
const SHELL=['./','index.html','manifest.webmanifest','icon.svg','icon-192.png','apple-touch-icon.png'];
self.addEventListener('install',e=>{e.waitUntil(caches.open(CACHE).then(c=>c.addAll(SHELL)).then(()=>self.skipWaiting()))});
self.addEventListener('activate',e=>{e.waitUntil(caches.keys().then(ks=>Promise.all(ks.filter(k=>k!==CACHE).map(k=>caches.delete(k)))).then(()=>self.clients.claim()))});
self.addEventListener('fetch',e=>{
  const u=new URL(e.request.url);
  if(e.request.method!=='GET'||u.origin!==location.origin) return;
  e.respondWith(fetch(e.request).then(r=>{if(r.ok){const c=r.clone();caches.open(CACHE).then(x=>x.put(e.request,c))}return r})
    .catch(()=>caches.match(e.request).then(r=>r||caches.match('index.html'))));
});
