// Actual WebAssembly fixture: blocked external hosts, touch input, safe iPhone canvas.
const {chromium}=require('playwright');
const fs=require('fs');
let activeBrowser;
const out=process.env.QSE_DESERT_WEB_OUT||'/tmp/reino-web';fs.mkdirSync(out,{recursive:true});
(async()=>{
 const browser=await chromium.launch({executablePath:'/usr/bin/chromium',headless:true,args:['--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader']});
 activeBrowser=browser;
 const context=await browser.newContext({viewport:{width:844,height:390},deviceScaleFactor:3,isMobile:true,hasTouch:true,serviceWorkers:'block',userAgent:'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1'});
 const blocked=[];await context.route('**/*',r=>{const u=new URL(r.request().url());if(['127.0.0.1','localhost'].includes(u.hostname))return r.continue();blocked.push(u.hostname);return r.abort();});
 const page=await context.newPage(),errors=[],logs=[];page.setDefaultTimeout(120000);
 page.on('pageerror',e=>errors.push(String(e)));page.on('console',m=>{logs.push(m.text());fs.appendFileSync(out+'/console.log',m.text()+'\n');});
 await page.goto(process.env.QSE_DESERT_WEB_URL||'http://127.0.0.1:8135/quemsoueuv3/',{waitUntil:'domcontentloaded',timeout:120000});
 await page.waitForFunction(()=>typeof window.qseDesertProbe==='function',null,{timeout:180000});
 async function state(){return page.evaluate(()=>{window.qseDesertProbe('state');return window.qseDesertState;});}
 async function tap(rect,s){const c=await page.locator('#canvas').boundingBox();await page.touchscreen.tap(c.x+(rect[0]+rect[2]/2)*c.width/s.size[0],c.y+(rect[1]+rect[3]/2)*c.height/s.size[1]);}
 await page.waitForTimeout(2300);
 const first=await state();if(first.index!==0)throw new Error("Story advanced automatically while reading");
 if(await page.locator('#qse-install').isVisible())throw new Error('Install invitation covers story controls');
 const states=[];
 for(let index=0;index<8;index++){
  await page.waitForTimeout(500);const s=await state();states.push(s);
  if(s.stage!=='loading'||s.index!==index||s.cards!==8)throw new Error('Unexpected intro state '+JSON.stringify(s));
  if([0,4,7].includes(index))await page.screenshot({path:out+`/intro_${index+1}.png`,scale:'css'});
  await tap(s.next,s);
  if(index<7)await page.waitForFunction(expected=>{window.qseDesertProbe("state");return window.qseDesertState.index===expected;},index+1,{timeout:120000});
 }
 await page.waitForFunction(()=>{window.qseDesertProbe('state');return window.qseDesertState.stage==='play';},null,{timeout:120000});
 await page.waitForTimeout(500);let game=await state();if(!game.read||!game.iphone)throw new Error('Read flag or iPhone profile missing');
 await page.evaluate(()=>window.qseDesertProbe('powers'));await page.waitForTimeout(200);game=await state();
 if(await page.locator('#qse-install').isVisible())throw new Error('Install invitation covers gameplay');
 await page.screenshot({path:out+'/powers.png',scale:'css'});
 const b=game.buttons.dash;if(!b)throw new Error('Dash touch button missing');
 const c=await page.locator('#canvas').boundingBox();await page.touchscreen.tap(c.x+b[0]*c.width/game.size[0],c.y+b[1]*c.height/game.size[1]);
 await page.waitForTimeout(180);const after=await state();
 if(after.charges.dash>=3||after.x<=game.x)throw new Error('Dash touch did not consume charge and move player');
 await page.reload({waitUntil:'domcontentloaded'});await page.waitForFunction(()=>typeof window.qseDesertProbe==='function',null,{timeout:120000});
 await page.waitForFunction(()=>{window.qseDesertProbe('state');return window.qseDesertState.stage==='play';},null,{timeout:120000});
 const replay=await state();if(!replay.read)throw new Error('Read flag did not persist');
 if(replay.buttons.rupture||replay.buttons.amber||replay.buttons.dash)throw new Error('Early chapter exposes later abilities after reload');
 await page.evaluate(()=>window.qseDesertProbe('rooftops'));
 await page.waitForFunction(()=>{window.qseDesertProbe('state');return window.qseDesertState.stage==='loading'&&window.qseDesertState.cards===1;},null,{timeout:120000});
 let brief=await state();await tap(brief.next,brief);
 await page.waitForFunction(()=>{window.qseDesertProbe('state');return window.qseDesertState.stage==='play'&&window.qseDesertState.order===2;},null,{timeout:120000});
 const roofBefore=await page.evaluate(()=>{window.qseDesertProbe('cactus');return window.qseDesertState;});
 const soldierBefore=roofBefore.soldiers.find(s=>s.id==='web.roof.pursuit');if(!soldierBefore)throw new Error('Roof soldier missing');
 await page.waitForFunction(before=>{window.qseDesertProbe('state');const soldier=window.qseDesertState.soldiers?.find(s=>s.id==='web.roof.pursuit');return soldier&&soldier.x<before-0.8;},soldierBefore.x,{timeout:15000,polling:100});const roofAfter=await state();const soldierAfter=roofAfter.soldiers.find(s=>s.id==='web.roof.pursuit');
 if(roofAfter.y<7.8||!soldierAfter||soldierAfter.y<7.8||soldierAfter.x>=soldierBefore.x-0.8)throw new Error('Web rooftop pursuit stopped or used street floor');
 if(!roofAfter.skyline||roofAfter.palace_pool!==3||roofAfter.house_roofs<1||roofAfter.rooftop_terraces!==0||roofAfter.roof_surfaces!==0)throw new Error('Rooftop or distant capital layers missing');
 await page.screenshot({path:out+'/roof_pursuit.png',scale:'css'});
 const stageArt=[{order:1,art_ids:game.art_ids},{order:2,art_ids:roofAfter.art_ids}];
 for(let order=3;order<=10;order++){
  await page.evaluate(value=>window.qseDesertProbe('phase:'+value),order);
  await page.waitForFunction(()=>{window.qseDesertProbe('state');return window.qseDesertState.stage==='loading'&&window.qseDesertState.ready;},null,{timeout:180000});
  const intro=await state();await tap(intro.next,intro);
  await page.waitForFunction(value=>{window.qseDesertProbe('state');return window.qseDesertState.stage==='play'&&window.qseDesertState.order===value;},order,{timeout:180000});
  await page.waitForFunction(()=>{window.qseDesertProbe('state');return window.qseDesertState.art_ids?.length>0;},null,{timeout:60000});
  const level=await state();
  if(level.skyline!==![6,10].includes(order)||(level.skyline&&level.palace_pool!==3))throw new Error('Skyline present in cave or missing outdoors');
  stageArt.push({order,art_ids:level.art_ids,skyline:level.skyline,palace_pool:level.palace_pool});
  await page.screenshot({path:out+`/phase_${String(order).padStart(2,'0')}.png`,scale:'css'});
 }
 if(stageArt.some(level=>!level.art_ids?.length))throw new Error('Approved assets missing in Web phase');
 // Fixture identificada: contato físico real após aproximar o ator, sem backend.
 const pedestalBefore=await page.evaluate(()=>{window.qseDesertProbe('pedestal');return window.qseDesertState;});
 await page.waitForFunction(()=>{window.qseDesertProbe('state');return window.qseDesertState.pedestal_collected;},null,{timeout:15000,polling:100});
 const pedestalAfter=await state();
 if(!pedestalBefore.pedestal_fixture||pedestalAfter.pedestal_count!==1||pedestalAfter.pickup_count!==0)throw new Error('Collecting attack removed or duplicated the pedestal');
 await page.screenshot({path:out+'/pedestal_after_collection_fixture.png',scale:'css'});
 const report={stageArt,states,game,after,replay,roofBefore,roofAfter,pedestalBefore,pedestalAfter,errors,blocked:[...new Set(blocked)],engineErrors:logs.filter(s=>/SCRIPT ERROR:|Parse Error:|^ERROR:/.test(s))};fs.writeFileSync(out+'/report.json',JSON.stringify(report,null,2));
 await browser.close();if(report.errors.length||report.engineErrors.length)throw new Error('Browser or engine errors; see report');
 console.log('REINO_WEB phases10 approved-art intro8 touch-dash replay-read progression PASS; external hosts blocked');
})().catch(async e=>{console.error(e);if(activeBrowser)await activeBrowser.close().catch(()=>{});process.exit(1)});
