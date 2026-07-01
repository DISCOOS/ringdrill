// ADR-0039 Phase 3 self-unregister stub.
// Old Flutter service workers on ringdrill.app fetch this file on their
// next update check. Installing it takes them out of service; the next
// reload falls through to the Astro site and the migration UI kicks in.
self.addEventListener('install', (event) => {
  event.waitUntil(self.skipWaiting());
});

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    // caches.delete() clears ONLY the Cache Storage API (the old Flutter app
    // shell + cached network responses). It deliberately does NOT touch
    // localStorage, IndexedDB or cookies, so the user's plans — stored in
    // localStorage via the SharedPreferences web shim — survive untouched
    // and remain exportable from /migrate (ADR-0039).
    const cacheNames = await caches.keys();
    await Promise.all(cacheNames.map((n) => caches.delete(n)));
    await self.registration.unregister();
    const clients = await self.clients.matchAll({ type: 'window' });
    for (const client of clients) {
      client.postMessage({ type: 'sw-retired' });
    }
  })());
});
