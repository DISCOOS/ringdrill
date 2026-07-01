// ADR-0039 Phase 3 self-unregister stub.
// Old Flutter service workers on ringdrill.app fetch this file on their
// next update check. Installing it takes them out of service; the next
// reload falls through to the Astro site and the migration UI kicks in.
self.addEventListener('install', (event) => {
  event.waitUntil(self.skipWaiting());
});

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    const cacheNames = await caches.keys();
    await Promise.all(cacheNames.map((n) => caches.delete(n)));
    await self.registration.unregister();
    const clients = await self.clients.matchAll({ type: 'window' });
    for (const client of clients) {
      client.postMessage({ type: 'sw-retired' });
    }
  })());
});
