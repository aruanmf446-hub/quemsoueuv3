// Official Godot WASM. Test-only catalogue; no real Stripe or Supabase requests.
const {chromium}=require('playwright'),{spawn}=require('child_process'),fs=require('fs'),assert=require('assert/strict');
const dir=process.argv[2],out=process.argv[3];fs.mkdirSync(out,{recursive:true});
const server=spawn('python3',['-m','http.server','8147','--bind','127.0.0.1'],{cwd:dir,stdio:'ignore'});
(async()=>{const browser=await chromium.launch({executablePath:'/usr/bin/chromium',args:['--no-sandbox','--use-angle=swiftshader','--disable-vulkan']});
try{const results=[];
 for(const [width,height,iphone] of [[1672,941,false],[844,390,true],[640,360,true]]){
  const context=await browser.newContext({viewport:{width,height},deviceScaleFactor:iphone?3:1,hasTouch:iphone,isMobile:iphone,...(iphone?{userAgent:'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Version/18.0 Mobile/15E148 Safari/604.1'}:{})});
  const external=[];await context.route('**/*',r=>{if(new URL(r.request().url()).hostname==='127.0.0.1')return r.continue();external.push(r.request().url());return r.abort();});
  const page=await context.newPage(),errors=[];
  page.on('console',m=>{if(/SCRIPT ERROR|Parse Error|^ERROR:/.test(m.text()))errors.push(m.text());});page.on('pageerror',e=>errors.push(e.message));
  await page.goto('http://127.0.0.1:8147/quemsoueuv3/?fixture=stripe');
  await page.waitForFunction(()=>window.qseDeckInputReady,null,{timeout:120000});
  const report=async()=>{const n=await page.evaluate(()=>qseDeckInputReport.sequence);await page.evaluate(()=>qseDeckInputProbe());await page.waitForFunction(n=>qseDeckInputReport.sequence>n,n);return page.evaluate(()=>qseDeckInputReport);};
  const tap=async(name)=>{const state=await report(),control=state.controls.find(c=>c.name===name);assert.ok(control,'missing '+name);
   const [x,y,w,h]=control.rect;assert.ok(x>=0&&y>=0&&x+w<=state.size[0]+1&&y+h<=state.size[1]+1,'outside '+name);
   const c=await page.locator('#canvas').boundingBox(),px=c.x+(x+w/2)*c.width/state.size[0],py=c.y+(y+h/2)*c.height/state.size[1];
   if(iphone)await page.touchscreen.tap(px,py);else await page.mouse.click(px,py);};
  let state=await report();assert.ok(state.labels.includes('500')&&state.labels.includes('MOEDAS'));assert.ok(state.labels.some(s=>s.includes('Modo de teste')));
  assert.equal(state.wallet_coins,'250');await page.screenshot({path:out+'/'+width+'x'+height+'_packages.png',scale:'css'});
  await tap('CoinPack_fixture_pack');await page.waitForTimeout(150);state=await report();
  assert.ok(state.labels.includes('500 moedas · R$ 9,90'));assert.equal(state.wallet_coins,'250');
  await page.screenshot({path:out+'/'+width+'x'+height+'_checkout.png',scale:'css'});
  await tap('OpenStripeCheckout');await page.waitForTimeout(300);
  assert.ok(external.includes('https://checkout.stripe.com/c/pay/fixture'),'payment must open from direct gesture');
  for(const popup of context.pages())if(popup!==page)await popup.close();
  await page.bringToFront();await tap('CloseCoinCheckout');await page.waitForTimeout(100);state=await report();
  assert.ok(!state.controls.some(c=>c.name==='OpenStripeCheckout'));assert.equal(state.wallet_coins,'250');assert.deepEqual(errors,[]);
  results.push({width,height,iphone,serverPackage:true,touchOrMouse:true,safeCheckoutOpened:true,clientCannotCredit:true,errors});
  fs.writeFileSync(out+'/results.json',JSON.stringify(results,null,2));await context.close();console.log('STRIPE_WEB_PASS '+width+'x'+height);
 }
}finally{await browser.close();server.kill();}})().catch(e=>{console.error(e);server.kill();process.exit(1);});
