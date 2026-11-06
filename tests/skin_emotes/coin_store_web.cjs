// Real Godot Web wallet view; prices and payment gateway are intentionally unset.
const {chromium}=require('playwright'),{spawn}=require('child_process'),fs=require('fs'),assert=require('assert/strict');
const dir=process.argv[2],out=process.argv[3];fs.mkdirSync(out,{recursive:true});
const server=spawn('python3',['-m','http.server','8145','--bind','127.0.0.1'],{cwd:dir,stdio:'ignore'});
(async()=>{const browser=await chromium.launch({executablePath:'/usr/bin/chromium',args:['--no-sandbox','--use-angle=swiftshader','--disable-vulkan']});
try{const results=[];
 for(const [width,height,iphone] of [[1672,941,false],[844,390,true],[640,360,true]]){
  const context=await browser.newContext({viewport:{width,height},deviceScaleFactor:iphone?3:1,hasTouch:iphone,isMobile:iphone,...(iphone?{userAgent:'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Version/18.0 Mobile/15E148 Safari/604.1'}:{})});
  await context.route('**/*',r=>new URL(r.request().url()).hostname==='127.0.0.1'?r.continue():r.abort());
  const page=await context.newPage(),errors=[];
  page.on('console',m=>{if(/SCRIPT ERROR|Parse Error|^ERROR:/.test(m.text()))errors.push(m.text());});page.on('pageerror',e=>errors.push(e.message));
  await page.goto('http://127.0.0.1:8145/quemsoueuv3/?fixture=coins');
  await page.waitForFunction(()=>window.qseDeckInputReady,null,{timeout:120000});
  await page.screenshot({path:out+'/'+width+'x'+height+'_coins.png',scale:'css'});
  const state=await page.evaluate(()=>qseDeckInputReport);
  assert.ok(state.labels.includes('Comprar moedas'));assert.ok(state.labels.some(s=>s.includes('250')));
  assert.ok(state.labels.some(s=>s.includes('em breve')));assert.ok(!state.labels.some(s=>s.includes('R$')));assert.deepEqual(errors,[]);
  results.push({width,height,iphone,balanceFromServer:true,unconfiguredPackages:true,errors});
  await context.close();console.log('COIN_STORE_WEB_PASS '+width+'x'+height);
 }
 fs.writeFileSync(out+'/results.json',JSON.stringify(results,null,2));
}finally{await browser.close();server.kill();}})().catch(e=>{console.error(e);server.kill();process.exit(1);});
