const { chromium } = require('playwright');
const { spawn } = require('child_process');
const fs = require('fs');
const assert = require('assert/strict');
process.env.PW_TEST_SCREENSHOT_NO_FONTS_READY = '1';
const [site, out] = process.argv.slice(2);
fs.mkdirSync(out, { recursive: true });
const server = spawn('python3', ['-m', 'http.server', '8190', '--bind', '127.0.0.1'], { cwd: site, stdio: 'ignore' });
(async () => {
  const browser = await chromium.launch({ executablePath: '/usr/bin/chromium', args: ['--no-sandbox', '--use-angle=swiftshader', '--disable-vulkan'] });
  try {
    const results = [];
    for (const [width, height] of [[1672, 941], [844, 390], [640, 360]]) {
      const mobile = width !== 1672;
      const context = await browser.newContext({
        viewport: { width, height }, deviceScaleFactor: mobile ? 3 : 1, isMobile: mobile, hasTouch: mobile,
        ...(mobile ? { userAgent: 'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Version/18.0 Mobile/15E148 Safari/604.1' } : {}),
      });
      await context.route('**/*', route => new URL(route.request().url()).hostname === '127.0.0.1' ? route.continue() : route.abort());
      const page = await context.newPage();
      const errors = [];
      page.on('console', message => {
        fs.appendFileSync(`${out}/${width}_console.log`, message.text() + '\n');
        if (/SCRIPT ERROR|Parse Error|^ERROR:/.test(message.text())) errors.push(message.text());
      });
      page.on('pageerror', error => errors.push(error.message));
      const report = async (action = '') => {
        const n = await page.evaluate(() => stageReport.sequence);
        await page.evaluate(value => { stageProbe(value); }, action);
        await page.waitForFunction(previous => stageReport.sequence > previous, n, { timeout: 30000 });
        return page.evaluate(() => stageReport);
      };
      const until = async (predicate, label, timeout = 180000) => {
        const end = Date.now() + timeout;
        let state;
        do {
          state = await report();
          if (predicate(state)) return state;
          await page.waitForTimeout(150);
        } while (Date.now() < end);
        fs.writeFileSync(`${out}/${width}_failed_state.json`, JSON.stringify(state, null, 2));
        throw Error(label);
      };
      const shot = async name => page.screenshot({ path: `${out}/${width}_${name}.png`, scale: 'css', timeout: 120000 });
      const tap = async (rect, state) => {
        const canvas = await page.locator('#canvas').boundingBox();
        const x = canvas.x + (rect[0] + rect[2] / 2) * canvas.width / state.size[0];
        const y = canvas.y + (rect[1] + rect[3] / 2) * canvas.height / state.size[1];
        if (mobile) await page.touchscreen.tap(x, y); else await page.mouse.click(x, y);
      };
      const framedArt = state => {
        for (const card of state.cards) {
          assert.equal(card.cropped, true);
          assert.equal(card.art_mode, 6);
          assert.ok(Math.abs(card.rect[2] / card.rect[3] - 9 / 16) < 0.03, 'portrait card');
        }
      };
      await page.goto('http://127.0.0.1:8190/quemsoueuv3/');
      await page.waitForFunction(() => window.stageReady, null, { timeout: 180000 });
      // Test the actual untouched selection first. Earlier versions tried input after
      // a fixed sleep for a cold-loading presentation and accidentally hit its overlay.
      let state = await until(s => s.phase === 'selection' && !s.presentation.active && s.cards.length === 9, 'initial selection');
      framedArt(state);
      await tap(state.cards[0].rect, state);
      state = await until(s => s.chosen.length === 1, 'first card responds to input');
      const firstDecision = state.controls.find(c => c.name === 'AcceptSelection');
      assert.ok(firstDecision && firstDecision.disabled, 'incomplete selection cannot submit');
      await tap(state.cards[1].rect, state);
      state = await until(s => s.chosen.length === 2, 'second card responds to input');
      const accept = state.controls.find(c => c.name === 'AcceptSelection');
      assert.ok(accept && !accept.disabled, 'confirmation on selected card');
      await shot('selection_confirm');
      await tap(accept.rect, state);
      state = await until(s => s.phase === 'countdown', 'real input commits two cards');
      assert.ok(state.presentation.active, 'authoritative countdown opens presentation');
      console.log('DUEL_INPUT_PASS', width, height, mobile ? 'touch' : 'mouse');
      // Restore the explicitly isolated geometry snapshot, including canceling any
      // pending model load. This action never exists in the production main scene.
      await report('reset_selection');
      let before = await until(s => s.phase === 'selection' && !s.presentation.active && s.cards.length === 9 && s.cards[0].rect[2] > 20, 'reset selection');
      framedArt(before);
      await shot('selection');
      for (const action of ['turns', 'remove', 'hand', 'chat']) {
        await report(action);
        const now = await until(s => s.phase === 'turns' && s.cards[0].rect[2] > 20 && Math.abs(s.cards[0].rect[2] - before.cards[0].rect[2]) < 1, `${action} settled`);
        fs.writeFileSync(`${out}/${width}_${action}.json`, JSON.stringify({ before, now }, null, 2));
        for (const name of ['BattleBoard', 'UtilityRail', 'BattleChat', 'PrivatePanel']) {
          for (let i = 0; i < 4; i++) assert.ok(Math.abs(now.panels[name][i] - before.panels[name][i]) < 1, `${action} stable ${name}`);
        }
        assert.ok(Math.abs(now.cards[0].rect[3] - before.cards[0].rect[3]) < 1, `${action} card height`);
        framedArt(now);
        if (['hand', 'chat'].includes(action)) {
          assert.equal(now.private_images.length, 2, 'two actual private images');
          for (const rect of now.private_images) {
            const [x, y, w, h] = now.private_bounds;
            assert.ok(rect[0] >= x - 1 && rect[1] >= y - 1 && rect[0] + rect[2] <= x + w + 1 && rect[1] + rect[3] <= y + h + 1, 'private image contained');
          }
        }
      }
      await shot('turns_chat');
      for (const clip of ['anim_2', 'anim_3', 'anim_4']) {
        await report(`stage:${clip}`);
        state = await until(s => s.presentation.active && s.presentation.clip === clip && s.presentation.alpha > 0.85, `loaded and visible ${clip}`);
        const rect = state.presentation.stage_rect;
        assert.ok(rect[0] >= 0 && rect[1] >= 0 && rect[0] + rect[2] <= state.size[0] + 1 && rect[1] + rect[3] <= state.size[1] + 1, 'stage inside viewport');
        await shot(clip);
        // Six seconds start after the asset is loaded; wait on actual completion.
        await until(s => !s.presentation.active, `presentation finished ${clip}`);
      }
      assert.deepEqual(errors, []);
      results.push({ width, height, mobile, framedArt: true, stablePanels: true, stableCardSize: true, privateImagesContained: true, mouseOrTouchSelection: true, presentations: ['anim_2', 'anim_3', 'anim_4'], errors });
      fs.writeFileSync(`${out}/results.json`, JSON.stringify(results, null, 2));
      console.log('DUEL_STAGE_WEB_PASS', width, height);
      await context.close();
    }
  } finally { await browser.close(); server.kill(); }
})().catch(error => { console.error(error); server.kill(); process.exit(1); });
