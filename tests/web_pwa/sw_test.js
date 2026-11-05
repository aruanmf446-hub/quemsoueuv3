// Teste do PWA no Chromium (Playwright): registro, cache versionado, nada de terceiros no cache,
// atualização só quando o jogo diz que é seguro, troca limpa de versão e campo nativo (iOS simulado).
// NÃO substitui o teste no Safari/iPhone real.
const { chromium, webkit } = require('playwright');
const { execSync, spawn } = require('child_process');
const path = require('path');
const root = path.resolve(__dirname, '../..');
const site = '/tmp/claude-0/pwa_site';
let failures = 0, checks = 0;
function check(ok, msg) { checks++; console.log((ok ? 'PASS ' : 'FAIL ') + msg); if (!ok) failures++; }
function assemble(build) { execSync(`python3 tests/web_pwa/assemble.py ${site}/quemsoueuv3 ${build}`, { cwd: root }); }
(async () => {
  execSync(`rm -rf ${site} && mkdir -p ${site}/quemsoueuv3`);
  assemble('build-a');
  const server = spawn('python3', ['-m', 'http.server', '8765', '--bind', '127.0.0.1'], { cwd: site, stdio: 'ignore' });
  await new Promise(r => setTimeout(r, 800));
  const url = 'http://localhost:8765/quemsoueuv3/';
  const browser = await chromium.launch({ executablePath: process.env.QSE_CHROMIUM_EXECUTABLE || undefined });
  const context = await browser.newContext();
  const page = await context.newPage();
  await page.goto(url);
  await page.waitForFunction(() => navigator.serviceWorker && navigator.serviceWorker.controller !== null || false, null, { timeout: 15000 }).catch(() => {});
  // Primeira visita: a página ainda não é controlada; recarrega para o worker assumir.
  await page.reload();
  await page.waitForFunction(() => !!navigator.serviceWorker.controller, null, { timeout: 15000 });
  const regs = await page.evaluate(async () => (await navigator.serviceWorker.getRegistrations()).length);
  check(regs === 1, `um único service worker registrado (${regs})`);
  const keys = await page.evaluate(async () => caches.keys());
  check(keys.length === 1 && keys[0] === 'qse-files', `cache único por conteúdo ${JSON.stringify(keys)}`);
  const entries = async () => page.evaluate(async () => (await (await caches.open('qse-files')).keys()).map(r => r.url));
  const before = await entries();
  const cached = before.map(u => new URL(u).pathname);
  for (const f of ['index.html', 'index.js', 'index.wasm', 'index.pck', 'manifest.webmanifest']) check(cached.some(p => p.endsWith('/' + f)), `em cache: ${f}`);
  // Chamada a outro domínio (como o Supabase) não pode ser interceptada nem guardada.
  await page.evaluate(async () => { try { await fetch('https://example.invalid/rest/v1/rpc/x'); } catch (e) {} });
  const thirdParty = await page.evaluate(async () => (await (await caches.open('qse-files')).keys()).filter(r => !r.url.startsWith(location.origin)).length);
  check(thirdParty === 0, 'nenhuma resposta de terceiros (Supabase/OAuth) no cache');
  const manifest = await page.evaluate(async () => (await fetch('manifest.webmanifest')).json());
  check(manifest.display === 'standalone' && manifest.orientation === 'landscape' && manifest.scope === '/quemsoueuv3/', 'manifest standalone/landscape/escopo');
  // Depois da janela de boot, a atualização aguarda o jogador. O shell permite
  // ativação automática só nos primeiros 15 s; não testar o fluxo manual nela.
  await page.waitForTimeout(16000);
  // Nova versão publicada: baixa em segundo plano, NÃO assume sozinha.
  assemble('build-b');
  await page.evaluate(async () => (await navigator.serviceWorker.getRegistration()).update());
  await page.waitForFunction(() => window.qsePwa && window.qsePwa.updateReady, null, { timeout: 15000 });
  check(true, 'versão nova detectada e preparada');
  await page.waitForTimeout(1800);
  check(await page.evaluate(() => getComputedStyle(document.getElementById('qse-update')).display) === 'none', 'em partida/telas internas o aviso fica oculto');
  const during = await entries();
  check(before.every(u => during.includes(u)), 'versão em uso continua intacta até o jogador aceitar');
  await page.evaluate(() => { window.qseSafeToUpdate = true; });
  await page.waitForTimeout(1800);
  check(await page.evaluate(() => getComputedStyle(document.getElementById('qse-update')).display) === 'block', 'no lobby aparece "Reiniciar para atualizar"');
  await Promise.all([page.waitForNavigation({ timeout: 15000 }), page.click('#qse-update')]);
  await page.waitForFunction(() => !!navigator.serviceWorker.controller, null, { timeout: 15000 });
  await page.waitForTimeout(500);
  const after = await entries();
  const wasmBefore = before.find(u => u.includes('/index.wasm?')), pckBefore = before.find(u => u.includes('/index.pck?'));
  check(after.includes(wasmBefore), 'motor (index.wasm) igual NÃO é baixado de novo na versão nova');
  check(!after.includes(pckBefore) && after.filter(u => u.includes('/index.pck?')).length === 1, 'pacote antigo removido; só o novo fica');
  check(after.filter(u => u.includes('/index.wasm?')).length === 1, 'sem cópias duplicadas no cache');
  // Campo nativo do iPhone: com iOS simulado, toque na área registrada foca o <input> real.
  const ios = await browser.newContext({ userAgent: 'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1', hasTouch: true, isMobile: true, viewport: { width: 844, height: 390 } });
  const phone = await ios.newPage();
  await phone.goto(url);
  // Campo real sobre o campo do jogo: o toque na área do campo cai num <input> e abre o teclado.
  const sent = await phone.evaluate(() => {
    window.__log = [];
    const c = document.getElementById('canvas');
    const rx = c.width / c.clientWidth || 1, ry = c.height / c.clientHeight || 1;
    window.qseNativeInput.setRegion('chat', 100 * rx, 250 * ry, 300 * rx, 40 * ry, '', 'Mensagem…', 280, 'text', '', false);
    window.qseNativeInput.bind('chat', (t) => window.__log.push('input:' + t), (t) => window.__log.push('submit:' + t), (t) => window.__log.push('close:' + t));
    return window.qseNativeInput.enabled();
  });
  check(sent === true, 'iOS detectado (ponte de teclado ativa)');
  const safe = await phone.evaluate(() => { const c = document.getElementById('canvas'); const r = c.getBoundingClientRect(); return {top: r.top, h: r.height, w: r.width, iphone: window.qsePwa.iphone, safe: !!window.qsePwa.safe, bg: getComputedStyle(document.body).backgroundColor}; });
  check(safe.iphone && safe.safe && safe.top >= 16 && Math.abs(safe.h - (390 - safe.top - 21)) < 2 && Math.abs(safe.w - (844 - 124)) < 2, `iPhone: canvas fora do notch e na área útil ${JSON.stringify(safe)}`);
  check(safe.bg === 'rgb(0, 0, 0)', 'iPhone: faixas fora da área segura são pretas');
	const repaired = await phone.evaluate(async () => {
		const c = document.getElementById('canvas');
		c.style.width = innerWidth + 'px'; c.style.height = innerHeight + 'px';
		await new Promise(requestAnimationFrame);
		const r = c.getBoundingClientRect(), expected = window.qsePwa.safe;
		return Math.abs(r.width - expected.width) < 1 && Math.abs(r.height - expected.height) < 1 && r.top >= 16;
	});
	check(repaired, 'iPhone: área segura restaurada após o motor substituir o CSS do canvas');
  const desk = await page.evaluate(() => { const r = document.getElementById('canvas').getBoundingClientRect(); return {top: r.top, iphone: window.qsePwa.iphone}; });
  check(desk.top === 0 && desk.iphone === false, 'computador: canvas na tela inteira (nada muda)');
  const at = await phone.evaluate(() => { const r = document.getElementById('canvas').getBoundingClientRect(); return {x: r.left + 200, y: r.top + 270}; });
  const hit = await phone.evaluate((p) => { const el = document.elementFromPoint(p.x, p.y); return el && el.tagName; }, at);
  check(hit === 'INPUT', `toque na área do campo cai num <input> real (${hit})`);
  await phone.touchscreen.tap(at.x, at.y);
  await phone.waitForTimeout(200);
  check(await phone.evaluate(() => { const a = document.activeElement; return !!a && a.tagName === 'INPUT' && a.classList.contains('qse-typing'); }), 'um toque foca o campo real (teclado abre) com o visual do jogo');
  await phone.keyboard.type('oi');
  await phone.keyboard.press('Enter');
  const log = await phone.evaluate(() => window.__log.join('|'));
  check(log.includes('input:oi') && log.includes('submit:oi'), `texto volta ao jogo e Enter envia ${log}`);
  await phone.evaluate(() => document.activeElement && document.activeElement.blur());
  await phone.evaluate(() => window.qseNativeInput.clearRegion('chat'));
  check(await phone.evaluate(() => document.querySelectorAll('input.qse-field:not(#qse-login-email):not(#qse-login-password)').length) === 0, 'campo some quando a tela do jogo fecha');
  const loginKinds = await phone.evaluate(() => {
    window.__log = [];
    window.qseNativeInput.setRegion('email', 0, 0, 100, 40, '', 'Seu e-mail', 0, 'email', '', false);
    window.qseNativeInput.bind('email', (t) => window.__log.push('email:' + t), () => {}, () => {});
    const e = document.getElementById('qse-login-email');
    return [e.type, e.autocomplete, e.classList.contains('qse-on'), e.form && e.form.id];
  });
  check(loginKinds.join() === 'email,username,true,qse-login', `e-mail real no formulário (senhas salvas) ${loginKinds}`);
  check(await phone.evaluate(() => { try { window.qseNativeInput.remember(); return true; } catch (e) { return false; } }), 'pedido para salvar a senha não quebra');
  check(await phone.evaluate(() => { window.qseSetStoryPlaying(true); window.qseShowInstall(); return getComputedStyle(document.getElementById('qse-install')).display; }) === 'none', 'convite de instalação oculto durante a campanha');
  check(await phone.evaluate(() => { window.qseSetStoryPlaying(false); return getComputedStyle(document.getElementById('qse-install')).display; }) === 'block', 'convite de instalação restaurado ao sair da campanha');
  await browser.close();
  server.kill();
  console.log(`PWA_TEST checks=${checks} failures=${failures}`);
  process.exit(failures ? 1 : 0);
})().catch((e) => { console.error(e); process.exit(1); });
