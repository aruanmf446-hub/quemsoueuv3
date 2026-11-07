/* O jogo saiu da raiz para /jogar/ (que tem o próprio service worker).
   Este arquivo só remove o service worker antigo da raiz e recarrega as abas
   para mostrarem a página inicial. Não guarda nada em cache. */
self.addEventListener("install", () => self.skipWaiting());
self.addEventListener("activate", (event) => {
  event.waitUntil((async () => {
    await caches.delete("qse-files");
    await self.registration.unregister();
    for (const c of await self.clients.matchAll({ type: "window" })) c.navigate(c.url);
  })());
});
