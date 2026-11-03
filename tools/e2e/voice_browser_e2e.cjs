/* Real Chrome WebRTC test. Uses a fake microphone; never records or logs audio/tokens. */
const http = require("node:http");
const fs = require("node:fs");
const { chromium } = require("playwright-core");

const url = process.env.QSE_VOICE_URL;
const ownerToken = process.env.QSE_VOICE_OWNER_TOKEN;
const readerToken = process.env.QSE_VOICE_READER_TOKEN;
const bundle = process.env.QSE_VOICE_BUNDLE;
const report = (ok, label) => {
  process.stdout.write((ok ? "PASS " : "FAIL ") + label + "\n");
  if (!ok) throw new Error("assertion_failed");
};
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));

async function main() {
  if (!url || !ownerToken || !readerToken || !bundle || !fs.existsSync(bundle)) {
    throw new Error("missing_env");
  }
  const source = fs.readFileSync(bundle);
  const server = http.createServer((req, res) => {
    if (req.url === "/livekit.js") {
      res.writeHead(200, { "Content-Type": "application/javascript", "Cache-Control": "no-store" });
      res.end(source);
    } else {
      res.writeHead(200, { "Content-Type": "text/html", "Cache-Control": "no-store" });
      res.end('<!doctype html><html><head><meta charset="utf-8"></head><body><main>Teste QSE</main><script src="/livekit.js"></script></body></html>');
    }
  });
  await new Promise(resolve => server.listen(0, "127.0.0.1", resolve));
  let browser;
  try {
    browser = await chromium.launch({
      channel: "chrome",
      headless: true,
      args: [
        "--use-fake-device-for-media-stream",
        "--use-fake-ui-for-media-stream",
        "--autoplay-policy=no-user-gesture-required",
        "--no-sandbox",
      ],
    });
    const origin = "http://127.0.0.1:" + server.address().port;
    const a = await browser.newContext({ permissions: ["microphone"] });
    const b = await browser.newContext({ permissions: ["microphone"] });
    const owner = await a.newPage();
    const reader = await b.newPage();
    await Promise.all([owner.goto(origin), reader.goto(origin)]);
    report(await owner.evaluate(() => typeof window.QSEVoice === "object") &&
           await reader.evaluate(() => typeof window.QSEVoice === "object"),
           "bridge do jogo carregada em dois contextos isolados");
    await Promise.all([
      owner.evaluate(([endpoint, token]) => window.QSEVoice.connect(endpoint, token), [url, ownerToken]),
      reader.evaluate(([endpoint, token]) => window.QSEVoice.connect(endpoint, token), [url, readerToken]),
    ]);
    const connected = await Promise.all([owner, reader].map(p => p.evaluate(() => window.QSEVoice.status().status)));
    report(connected.every(x => x === "connected"), "LiveKit Cloud aceitou dois participantes reais");
    await Promise.all([
      owner.waitForFunction(() => window.QSEVoice.status().participants.length === 1, { timeout: 30000 }),
      reader.waitForFunction(() => window.QSEVoice.status().participants.length === 1, { timeout: 30000 }),
    ]);
    report(true, "participantes se enxergam em sala isolada");
    report(!(await owner.evaluate(() => window.QSEVoice.status().mic)) &&
           !(await reader.evaluate(() => window.QSEVoice.status().mic)),
           "microfones comecam desligados");
    await owner.evaluate(() => window.QSEVoice.microphone(true));
    await reader.waitForFunction(() => document.querySelectorAll("#qse-voice-audio audio").length > 0, { timeout: 30000 });
    report(true, "microfone simulado OWNER publicado e audio recebido no READER");
    await reader.evaluate(() => window.QSEVoice.microphone(true));
    await owner.waitForFunction(() => document.querySelectorAll("#qse-voice-audio audio").length > 0, { timeout: 30000 });
    report(true, "microfone simulado READER publicado e audio recebido no OWNER");
    await reader.evaluate(() => window.QSEVoice.muteReceived(true));
    report(await reader.evaluate(() => [...document.querySelectorAll("#qse-voice-audio audio")].every(x => x.muted)),
           "mute do audio remoto");
    await Promise.all([owner.evaluate(() => window.QSEVoice.disconnect()), reader.evaluate(() => window.QSEVoice.disconnect())]);
    await delay(500);
    report((await owner.evaluate(() => window.QSEVoice.status().status)) === "idle" &&
           (await reader.evaluate(() => window.QSEVoice.status().status)) === "idle",
           "ambos participantes desconectaram");
  } finally {
    if (browser) await browser.close();
    await new Promise(resolve => server.close(resolve));
  }
}
main().catch(() => {
  process.stdout.write("FAIL teste WebRTC Chrome (sem publicar dados privados)\n");
  process.exitCode = 1;
});
