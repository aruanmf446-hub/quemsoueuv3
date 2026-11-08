/* Quem Sou Eu — service worker único do PWA.
 * - Cache por CONTEÚDO (tools/web/stamp_sw.py grava o hash de cada arquivo no deploy): numa versão
 *   nova só é baixado o que mudou; o motor (index.wasm) fica guardado entre versões.
 * - Página e motor de uma versão nunca se misturam: cada service worker usa só os hashes dele.
 * - Só arquivos do próprio jogo, na mesma origem e dentro do escopo; Supabase, OAuth e
 *   qualquer outro domínio passam direto pela rede (nada privado entra no cache).
 * - Uma versão nova é preparada em segundo plano e só assume quando a página pede
 *   (botão "Reiniciar para atualizar", oferecido só no lobby) — nunca no meio da partida.
 */
const BUILD = "__BUILD__";
const FILES = "__FILES__";            // { "index.wasm": "<hash>", ... } — preenchido no deploy
const CACHE = "qse-files";
let installProgress = null;
const REQUIRED = ["index.html", "index.js", "index.wasm", "index.pck"];

function key(path) { return new URL(path + "?v=" + FILES[path], self.registration.scope).href; }

self.addEventListener("install", (event) => {
  event.waitUntil((async () => {
    const cache = await caches.open(CACHE);
    const clients = await self.clients.matchAll({type:"window",includeUncontrolled:true});
    let completed = 0, loadedBytes = 0, lastReport = 0;
    const total = Object.keys(FILES).length;
    function report(force = false) {
      installProgress = {completed, total, loadedBytes};
      if (!force && Date.now() - lastReport < 250) return;
      lastReport = Date.now();
      for (const client of clients) client.postMessage({type:"qse-update-progress", build:BUILD, ...installProgress});
    }
    report(true);
    await Promise.all(Object.keys(FILES).map(async (path) => {
      if (await cache.match(key(path))) { completed++; report(true); return; }                  // mesmo conteúdo: já guardado
      try {
        const response = await fetch(key(path), {cache: "reload"});
        if (response.ok) {
          // Reject a stale CDN copy of the small HTML before committing a new build.
          if (path === "index.html") {
            const bytes = await response.clone().arrayBuffer();
            const digest = await crypto.subtle.digest("SHA-256", bytes);
            const hash = Array.from(new Uint8Array(digest)).map(x => x.toString(16).padStart(2,"0")).join("").slice(0,16);
            if (hash !== FILES[path]) throw new Error("stale page");
          }
          // Count bytes while CacheStorage consumes the stream; do not buffer the package in RAM.
          let stored = response;
          if (response.body && typeof TransformStream !== "undefined") {
            const stream = response.body.pipeThrough(new TransformStream({
              transform(chunk, controller) {
                loadedBytes += chunk.byteLength;
                report();
                controller.enqueue(chunk);
              }
            }));
            stored = new Response(stream, {status:response.status, statusText:response.statusText, headers:response.headers});
          }
          await cache.put(key(path), stored);
        }
        else if (REQUIRED.includes(path)) throw new Error(path + " " + response.status);
      } catch (error) {
        if (REQUIRED.includes(path)) throw error;
      }
      completed++;
      report(true);
    }));
  })());
  // Sem skipWaiting aqui: a página decide quando trocar de versão.
});

self.addEventListener("message", (event) => {
  if (event.data === "qse-build-status" && event.ports[0]) {
    event.waitUntil((async () => {
      const scope = new URL(self.registration.scope);
      const clients = await self.clients.matchAll({type:"window", includeUncontrolled:true});
      const gameClients = clients.filter(client => {
        const url = new URL(client.url);
        return url.origin === scope.origin && url.pathname.startsWith(scope.pathname);
      }).length;
      event.ports[0].postMessage({build:BUILD, gameClients, progress:installProgress});
    })());
  }
  if (event.data === "qse-activate-update") self.skipWaiting();
});

self.addEventListener("activate", (event) => {
  event.waitUntil((async () => {
    for (const name of await caches.keys()) {
      if (name.startsWith("qse-game-")) await caches.delete(name);   // formato antigo (por build)
    }
    const cache = await caches.open(CACHE);
    const keep = new Set(Object.keys(FILES).map(key));
    for (const request of await cache.keys()) {
      if (!keep.has(request.url)) await cache.delete(request);
    }
    await self.clients.claim();
  })());
});

function cached(path, request) {
  return (async () => {
    const cache = await caches.open(CACHE);
    const hit = await cache.match(key(path));
    if (hit) return hit;
    const response = await fetch(request);
    if (response.ok) {
      try { await cache.put(key(path), response.clone()); } catch (error) { /* sem espaço: segue */ }
    }
    return response;
  })();
}

self.addEventListener("fetch", (event) => {
  const request = event.request;
  if (request.method !== "GET") return;
  const url = new URL(request.url);
  if (url.origin !== self.location.origin) return;               // Supabase, OAuth, CDNs: rede
  const scope = new URL(self.registration.scope);
  if (!url.pathname.startsWith(scope.pathname)) return;
  // /bots é outro aplicativo: não devolver index.html do Godot nas navegações do painel.
  if (url.pathname.slice(scope.pathname.length).startsWith("bots/")) return;
  if (url.search && request.mode !== "navigate") return;           // respostas com parâmetros: rede
  const path = url.pathname.slice(scope.pathname.length) || "index.html";
  if (request.mode === "navigate") {
    // Página da MESMA versão do motor; a URL com ?code= do OAuth continua intacta.
    if (FILES["index.html"]) event.respondWith(cached("index.html", "index.html"));
    return;
  }
  if (!FILES[path]) return;                                        // música, slides etc.: rede/HTTP cache
  event.respondWith(cached(path, request));
});
