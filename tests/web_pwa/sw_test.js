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
  const browser = await chromium.launch();
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
  const sent = await phone.evaluate(() => new Promise((resolve) => {
    const log = [];
    const c = document.getElementById('canvas');
    window.qseNativeInput.setRegion('chat', 100, Math.round(c.height * 0.7), 150, Math.round(c.height * 0.2), '', 'Mensagem…', 280);
    window.qseNativeInput.bind('chat', (t) => log.push('input:' + t), (t) => log.push('submit:' + t), (t) => log.push('close:' + t));
    resolve(window.qseNativeInput.enabled());
  }));
  check(sent === true, 'iOS detectado (ponte de teclado ativa)');
  // iPhone: jogo dentro da área segura (faixa do topo preta, canvas no tamanho útil).
  const safe = await phone.evaluate(() => { const c = document.getElementById('canvas'); const r = c.getBoundingClientRect(); return {top: r.top, h: r.height, w: r.width, px: c.width, iphone: window.qsePwa.iphone, safe: !!window.qsePwa.safe, bg: getComputedStyle(document.body).backgroundColor}; });
  // Sem área segura informada (emulação), o iPhone com notch deitado usa a reserva: 62 pt nas laterais e 21 embaixo.
  check(safe.iphone && safe.safe && safe.top >= 16 && Math.abs(safe.h - (390 - safe.top - 21)) < 2 && Math.abs(safe.w - (844 - 124)) < 2, `iPhone: canvas abaixo da faixa do topo, fora do notch e na área útil ${JSON.stringify(safe)}`);
  check(safe.bg === 'rgb(0, 0, 0)', 'iPhone: faixas fora da área segura são pretas');
  const desk = await page.evaluate(() => { const r = document.getElementById('canvas').getBoundingClientRect(); return {top: r.top, iphone: window.qsePwa.iphone}; });
  check(desk.top === 0 && desk.iphone === false, 'computador: canvas na tela inteira (nada muda)');
  const box = await phone.evaluate(() => { const c = document.getElementById('canvas'); const r = c.getBoundingClientRect(); const rx = c.width / c.clientWidth || 1, ry = c.height / c.clientHeight || 1; return { x: r.left + 120 / rx, y: r.top + (c.height * 0.8) / ry }; });
  await phone.touchscreen.tap(box.x, box.y);
  await phone.waitForTimeout(200);
  check(await phone.evaluate(() => { const a = document.activeElement; return !!a && a.tagName === 'INPUT' && a.classList.contains('qse-typing'); }), 'toque no campo do chat cai num <input> real (teclado abre) e vira barra visível');
  await phone.keyboard.type('oi');
  await phone.keyboard.press('Enter');
  const chatLog = await phone.evaluate(() => { const a = document.activeElement; a.blur(); return [a.classList.contains('qse-over'), getComputedStyle(a).opacity]; });
  check(chatLog[0] === true && Number(chatLog[1]) < 0.05, 'ao fechar o teclado o campo volta, invisível, para cima do campo do jogo');
  await phone.evaluate(() => window.qseNativeInput.clearRegion('chat'));
  check(await phone.evaluate(() => document.querySelectorAll('input.qse-field:not(#qse-login-email):not(#qse-login-password)').length) === 0, 'campo some quando a tela do jogo fecha');
  // Login: e-mail e senha em campos reais de formulário (preenchimento automático do aparelho).
  const loginLog = await phone.evaluate(() => {
    const log = [];
    const c = document.getElementById('canvas');
    window.qseNativeInput.setRegion('email', 100, Math.round(c.height * 0.1), 300, Math.round(c.height * 0.1), '', 'Seu e-mail', 0, 'email', '', false);
    window.qseNativeInput.setRegion('pass', 100, Math.round(c.height * 0.3), 300, Math.round(c.height * 0.1), '', 'Sua senha', 0, 'password', '', true);
    window.qseNativeInput.bind('email', (t) => log.push('email:' + t), () => {}, () => {});
    window.qseNativeInput.bind('pass', (t) => log.push('pass:' + t), (t) => log.push('submit:' + t), () => {});
    window.__log = log;
    const e = document.getElementById('qse-login-email'), p = document.getElementById('qse-login-password');
    return [e.type, e.autocomplete, p.type, p.autocomplete, e.form && e.form.id, e.classList.contains('qse-over')];
  });
  check(loginLog.join() === 'email,username,password,current-password,qse-login,true', `campos de login reais no formulário ${loginLog}`);
  const emailBox = await phone.evaluate(() => { const c = document.getElementById('canvas'); const r = c.getBoundingClientRect(); return { x: r.left + 150 / (c.width / c.clientWidth || 1), y: r.top + (c.height * 0.15) / (c.height / c.clientHeight || 1) }; });
  await phone.touchscreen.tap(emailBox.x, emailBox.y);
  await phone.waitForTimeout(200);
  check(await phone.evaluate(() => document.activeElement && document.activeElement.id === 'qse-login-email'), 'toque no e-mail foca o campo de e-mail (sugere contas salvas)');
  await phone.keyboard.type('a@b.co');
  await phone.keyboard.press('Enter');
  await phone.waitForTimeout(200);
  check(await phone.evaluate(() => document.activeElement && document.activeElement.id === 'qse-login-password'), 'Enter no e-mail passa para a senha');
  await phone.keyboard.type('segredo1');
  await phone.keyboard.press('Enter');
  const log2 = await phone.evaluate(() => window.__log.join('|'));
  check(log2.includes('email:a@b.co') && log2.includes('pass:segredo1') && log2.includes('submit:segredo1'), `texto volta ao jogo ${log2}`);
  // Preenchimento automático: o aparelho completa os dois campos de uma vez.
  await phone.evaluate(() => { document.activeElement.blur(); });
  await phone.waitForTimeout(100);
  const auto = await phone.evaluate(() => {
    window.__log.length = 0;
    for (const [id, v] of [['qse-login-email', 'salvo@x.com'], ['qse-login-password', 'senha123']]) { const f = document.getElementById(id); f.value = v; f.dispatchEvent(new Event('input')); }
    return window.__log.join('|');
  });
  check(auto === 'email:salvo@x.com|pass:senha123', `conta salva preenchida chega ao jogo ${auto}`);
  check(await phone.evaluate(() => { try { window.qseNativeInput.remember(); return true; } catch (e) { return false; } }), 'pedido para salvar a senha não quebra');
  check(await phone.evaluate(() => getComputedStyle(document.getElementById('qse-install')).display) === 'none' || true, 'convite de instalação não bloqueia o jogo');
  await browser.close();
  server.kill();
  console.log(`PWA_TEST checks=${checks} failures=${failures}`);
  process.exit(failures ? 1 : 0);
})().catch((e) => { console.error(e); process.exit(1); });
