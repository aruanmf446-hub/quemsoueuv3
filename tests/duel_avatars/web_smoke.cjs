// Boot do build Web real em Chromium com UA iPhone; não acessa serviços externos.
// Uso: node tests/duel_avatars/web_smoke.cjs <raiz-servida> <pasta-evidencias>
const {chromium} = require('playwright');
const {spawn} = require('child_process');
const fs = require('fs');
const path = require('path');
(async () => {
  const site=path.resolve(process.argv[2]);
  const output=path.resolve(process.argv[3]);
  fs.mkdirSync(output,{recursive:true});
  const server=spawn('python3',['-m','http.server','8827','--bind','127.0.0.1'],{cwd:site,stdio:'ignore'});
  let browser;
  try {
    await new Promise(resolve=>setTimeout(resolve,700));
    browser=await chromium.launch({executablePath:process.env.QSE_CHROMIUM_EXECUTABLE||'/usr/bin/chromium',args:['--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader']});
    const context=await browser.newContext({viewport:{width:844,height:390},deviceScaleFactor:3,hasTouch:true,isMobile:true,userAgent:'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Version/18.0 Mobile/15E148 Safari/604.1'});
    const errors=[];
    const page=await context.newPage();
    page.on('pageerror',error=>errors.push(String(error)));
    page.on('console',message=>{if (/SCRIPT ERROR:|Parse Error:/.test(message.text())) errors.push(message.text());});
    await page.route('**/*',route=>new URL(route.request().url()).hostname==='127.0.0.1'?route.continue():route.abort());
    await page.goto('http://127.0.0.1:8827/quemsoueuv3/index.html',{waitUntil:'domcontentloaded',timeout:120000});
    await page.waitForFunction(()=>!document.getElementById('boot'),null,{timeout:120000});
    await page.waitForTimeout(2500);
    const report=await page.evaluate(()=>{const canvas=document.getElementById('canvas'),r=canvas.getBoundingClientRect();return {iphone:window.qsePwa?.iphone,dpr:devicePixelRatio,canvas:[canvas.width,canvas.height],rect:[r.x,r.y,r.width,r.height]};});
    await page.screenshot({path:path.join(output,'web-iphone-boot.png'),scale:'css',timeout:120000});
    // Entrada de convidado real, sem login ou RPC externo.
    await page.touchscreen.tap(140,38);
    await page.waitForTimeout(3000);
    await page.screenshot({path:path.join(output,'web-iphone-lobby.png'),scale:'css',timeout:120000});
    fs.writeFileSync(path.join(output,'web-smoke.json'),JSON.stringify({report,errors},null,2));
    if (!report.iphone||report.dpr!==3||errors.length) throw new Error('Web boot failed: '+JSON.stringify({report,errors}));
    console.log('AVATAR_WEB_BOOT_PASS',JSON.stringify(report));
  } finally {
    if(browser) await browser.close();
    server.kill();
  }
})().catch(error=>{console.error(error);process.exitCode=1;});
