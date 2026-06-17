const CACHE = 'wawaliceum-v1';

const PRECACHE = [
  './',
  './index.html',
  './js/app.js',
  './js/calculator.js',
  './js/data.js',
];

const DATA_FILES = [
  './data/schools.json',
  './data/thresholds.json',
  './data/ewd.json',
  './data/ranking.json',
  './data/matura.json',
  './data/atmosfera.json',
  './data/inicjatywy.json',
  './data/plan_naboru.json',
];

self.addEventListener('install', e => {
  e.waitUntil(
    caches.open(CACHE).then(c => c.addAll(PRECACHE)).then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', e => {
  e.waitUntil(
    caches.keys()
      .then(keys => Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', e => {
  // Network-first dla plików danych (mogą się aktualizować)
  if (DATA_FILES.some(f => e.request.url.endsWith(f.replace('./', '')))) {
    e.respondWith(
      fetch(e.request)
        .then(r => { caches.open(CACHE).then(c => c.put(e.request, r.clone())); return r; })
        .catch(() => caches.match(e.request))
    );
    return;
  }
  // Cache-first dla zasobów statycznych
  e.respondWith(
    caches.match(e.request).then(r => r || fetch(e.request).then(res => {
      caches.open(CACHE).then(c => c.put(e.request, res.clone()));
      return res;
    }))
  );
});
