// Exact pause controls and real Player rules on a labelled fixture background; no external network.
const {chromium}=require('playwright'),{spawn}=require('child_process'),fs=require('fs'),assert=require('assert/strict');
const dir=process.argv[2],out=process.argv[3];fs.mkdirSync(out,{recursive:true});
const server=spawn('python3',['-m','http.server','8159','--bind','127.0.0.1'],{cwd:dir,stdio:'ignore'});
(async()=>{const browser=await chromium.launch({executablePath:'/usr/bin/chromium',args:['--no-sandbox','--use-angle=swiftshader','--disable-vulkan']});
try{const results=[];
 for(const [width,height,iphone] of (process.argv[4]==='preview'?[[844,390,true]]:[[1672,941,false],[844,390,true],[640,360,true]])){
  const context=await browser.newContext({viewport:{width,height},deviceScaleFactor:iphone?3:1,hasTouch:iphone,isMobile:iphone,...(iphone?{userAgent:'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Version/18.0 Mobile/15E148 Safari/604.1'}:{})});
  await context.route('**/*',r=>new URL(r.request().url()).hostname==='127.0.0.1'?r.continue():r.abort());
  const page=await context.newPage(),errors=[];
  page.on('console',m=>{if(/SCRIPT ERROR|Parse Error|^ERROR:/.test(m.text()))errors.push(m.text());});page.on('pageerror',e=>errors.push(e.message));
  await page.goto('http://127.0.0.1:8159/quemsoueuv3/?fixture=refill_store');
  await page.waitForFunction(()=>window.qseDeckInputReady,null,{timeout:120000});
  const report=async()=>{const n=await page.evaluate(()=>qseDeckInputReport.sequence);await page.evaluate(()=>qseDeckInputProbe());await page.waitForFunction(n=>qseDeckInputReport.sequence>n,n);return page.evaluate(()=>qseDeckInputReport);};
  const tap=async(id)=>{const s=await report(),b=s.controls.find(c=>c.name===id||c.text===id);assert.ok(b,'missing '+id);const[x,y,w,h]=b.rect;assert.ok(x>=0&&y>=0&&x+w<=s.size[0]+1&&y+h<=s.size[1]+1,'outside '+id);const c=await page.locator('#canvas').boundingBox(),px=c.x+(x+w/2)*c.width/s.size[0],py=c.y+(y+h/2)*c.height/s.size[1];if(iphone)await page.touchscreen.tap(px,py);else await page.mouse.click(px,py);};
  await tap('BuyAbilityRefill');let purchase=await report();
  assert.ok(purchase.labels.includes('1 recarga completa · 10 moedas'));
  await page.screenshot({path:out+'/'+width+'x'+height+'_purchase.png',scale:'css'});
  await tap('ConfirmAbilityRefillPurchase');
  for(let i=0;i<30;i++){purchase=await report();if(purchase.wallet_coins==='240')break;await page.waitForTimeout(50);}
  assert.equal(purchase.wallet_coins,'240');assert.ok(purchase.labels.includes('Recarga guardada na sua conta.'));
  await tap('CloseAbilityRefillPurchase');await page.evaluate(()=>qseDeckInputProbe('start_refill_phase'));
  await tap('Configurações');await tap('Recargas compradas');
  for(let i=0;i<30;i++){const boot=await report();if(boot.refills?.count===3)break;await page.waitForTimeout(50);}
  let s=await report();assert.equal(s.refills.paused,true);assert.equal(s.refills.count,3);
  const before=s.refills.calls;assert.equal(s.controls.find(b=>b.name==='UseRefill_attack').disabled,true);
  await tap('UseRefill_attack');s=await report();assert.equal(s.refills.calls,before);assert.equal(s.refills.count,3);
  await tap('UseRefill_defense');
  for(let i=0;i<30;i++){s=await report();if(s.refills.defense===3&&s.refills.count===2&&s.labels.includes('Defesa recarregada: 3/3.'))break;await page.waitForTimeout(50);}
  assert.equal(s.refills.defense,3);assert.equal(s.refills.count,2);assert.equal(s.controls.find(b=>b.name==='UseRefill_defense').disabled,true);assert.ok(s.labels.includes('Defesa recarregada: 3/3.'));
  await page.screenshot({path:out+'/'+width+'x'+height+'_pause.png',scale:'css'});
  await tap('UseRefill_dash');
  for(let i=0;i<30;i++){s=await report();if(s.refills.dash===3&&s.refills.count===1&&s.labels.includes('Corrida elétrica recarregada: 3/3.'))break;await page.waitForTimeout(50);}
  assert.equal(s.refills.dash,3);assert.equal(s.refills.count,1);assert.equal(s.refills.attack,3);
  await tap('Voltar às configurações');await tap('Voltar à pausa');await tap('Continuar');s=await report();assert.equal(s.refills.paused,false);assert.ok(!s.labels.some(l=>l.startsWith('Recargas guardadas')));assert.deepEqual(errors,[]);
  results.push({width,height,iphone,oneRefillPurchasedFor10Coins:true,emptyToFull:true,partialToFull:true,fullBlockedWithoutRpc:true,ownedStockOnlyInSettings:true,errors});fs.writeFileSync(out+'/results.json',JSON.stringify(results,null,2));console.log('REFILLS_WEB_PASS '+width+'x'+height);await context.close();
 }
}finally{await browser.close();server.kill();}})().catch(e=>{console.error(e);server.kill();process.exit(1);});
