/* Quem Sou Eu — service worker único do PWA (T24 iOS).
 * - Cache versionado por build (__BUILD__ é trocado no deploy): nunca mistura versões.
 * - Só arquivos do próprio jogo, na mesma origem e dentro do escopo; Supabase, OAuth e
 *   qualquer outro domínio passam direto pela rede (nada privado entra no cache).
 * - Uma versão nova é baixada inteira em segundo plano e só assume quando a página pede
 *   (botão "Reiniciar para atualizar", oferecido só no lobby) — nunca no meio da partida.
 */
const BUILD = "__BUILD__";
const CACHE = "qse-game-" + BUILD;
const CORE = ["./", "index.html", "index.js", "index.wasm", "index.pck", "index.audio.worklet.js",
  "index.audio.position.worklet.js", "manifest.webmanifest", "pwa/icon-180.png", "pwa/icon-192.png", "pwa/icon-512.png"];

self.addEventListener("install", (event) => {
  event.waitUntil((async () => {
    const cache = await caches.open(CACHE);
    // Arquivos opcionais (worklets de áudio podem não existir em todas as versões).
    await Promise.all(CORE.map(async (path) => {
      try {
        const response = await fetch(path, {cache: "no-cache"});
        if (response.ok) await cache.put(path, response);
        else if (["index.wasm", "index.pck", "index.js"].includes(path)) throw new Error(path + " " + response.status);
      } catch (error) {
        if (["index.wasm", "index.pck", "index.js"].includes(path)) throw error;
      }
    }));
  })());
  // Sem skipWaiting aqui: a página decide quando trocar de versão.
});

self.addEventListener("message", (event) => {
  if (event.data === "qse-activate-update") self.skipWaiting();
});

self.addEventListener("activate", (event) => {
  event.waitUntil((async () => {
    for (const key of await caches.keys()) {
      if (key.startsWith("qse-game-") && key !== CACHE) await caches.delete(key);
    }
    await self.clients.claim();
  })());
});

self.addEventListener("fetch", (event) => {
  const request = event.request;
  if (request.method !== "GET") return;
  const url = new URL(request.url);
  if (url.origin !== self.location.origin) return;               // Supabase, OAuth, CDNs: rede
  const scope = new URL(self.registration.scope);
  if (!url.pathname.startsWith(scope.pathname)) return;
  if (url.search && request.mode !== "navigate") return;           // respostas com parâmetros: rede
  const path = url.pathname.slice(scope.pathname.length) || "./";
  if (request.mode === "navigate") {
    // Página da MESMA versão do cache (HTML e motor sempre juntos); a URL com ?code= do
    // OAuth continua intacta para o jogo ler. Sem cópia guardada, vai à rede.
    event.respondWith((async () => {
      const cache = await caches.open(CACHE);
      return (await cache.match("index.html")) || fetch(request);
    })());
    return;
  }
  if (!CORE.includes(path)) return;                                // música, slides etc.: rede/HTTP cache
  event.respondWith((async () => {
    const cache = await caches.open(CACHE);
    const hit = await cache.match(path);
    if (hit) return hit;
    const response = await fetch(request);
    if (response.ok) {
      try { await cache.put(path, response.clone()); } catch (error) { /* sem espaço: segue sem cache */ }
    }
    return response;
  })());
});
