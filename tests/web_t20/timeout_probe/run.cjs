const { chromium } = require('playwright');
(async () => {
  const b = await chromium.launch({ args: ['--use-gl=swiftshader', '--enable-unsafe-swiftshader'] });
  const p = await b.newPage();
  const log = [];
  p.on('console', m => log.push('console: ' + m.text()));
  p.on('pageerror', e => log.push('PAGEERROR: ' + e.message + '\n' + e.stack));
  await p.goto('http://127.0.0.1:8098/index.html');
  await p.waitForTimeout(25000);
  console.log(log.join('\n'));
  await b.close();
})();
