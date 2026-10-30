// Run against an exported build served by HTTP. Requires Playwright + Chromium.
// node tests/performance/web_probe.cjs http://127.0.0.1:8133/ 3 /tmp/web.png
const { chromium } = require('playwright');
(async () => {
  const url = process.argv[2];
  if (!url) throw new Error('Informe a URL do build Web.');
  const dpr = Number(process.argv[3] || 1);
  const browser = await chromium.launch({
    executablePath: process.env.CHROMIUM_PATH || '/usr/bin/chromium',
    headless: true,
    args: ['--no-sandbox', '--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'],
  });
  try {
    const page = await browser.newPage({
      ignoreHTTPSErrors: true, viewport: { width: 844, height: 390 },
      deviceScaleFactor: dpr, isMobile: dpr > 1, hasTouch: dpr > 1,
    });
    const errors = [];
    page.on('pageerror', error => errors.push(String(error)));
    const click = (x, y) => dpr > 1 ? page.touchscreen.tap(x, y) : page.mouse.click(x, y);
    await page.goto(url, { waitUntil: 'domcontentloaded' });
    await page.waitForTimeout(15000);
    await click(100, 120); // Lobby -> Modo História.
    await page.waitForTimeout(1500);
    await click(110, 360); // Jogar fase 01.
    await page.waitForTimeout(5000);
    await click(750, 40); // Pular história.
    await page.waitForTimeout(4000);
    const canvas = await page.locator('canvas').evaluate(c => ({
      width: c.width, height: c.height, dpr: devicePixelRatio,
    }));
    if (canvas.width !== 844 * dpr || canvas.height !== 390 * dpr) throw new Error('A resolução nativa do canvas foi alterada.');
    await page.screenshot({ path: process.argv[4] || '/tmp/qse-web-probe.png', scale: 'css' });
    const frames = await page.evaluate(() => new Promise(resolve => {
      const samples = [];
      let last = performance.now();
      const start = last;
      function frame(now) {
        samples.push(now - last); last = now;
        if (now - start < 4000) requestAnimationFrame(frame);
        else {
          samples.sort((a, b) => a - b);
          resolve({ count: samples.length, fps: samples.length * 1000 / (now - start),
            p95: samples[Math.floor(samples.length * .95)], max: Math.max(...samples) });
        }
      }
      requestAnimationFrame(frame);
    }));
    console.log(JSON.stringify({ url, canvas, frames, errors,
      note: 'Software GPU; idle scene, not a running/physical-phone FPS acceptance test.' }));
    if (errors.length) throw new Error('Erros JavaScript no build.');
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exitCode = 1; });
