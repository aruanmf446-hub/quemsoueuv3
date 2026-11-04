// Actual Godot WebAssembly, iPhone UA + DPR 3. All non-loopback requests are aborted.
const {chromium}=require('playwright');
const fs=require('fs');
const out=process.env.QSE_IPHONE_OUTPUT||'/tmp/qse-iphone-web';fs.mkdirSync(out,{recursive:true});
(async()=>{
 const browser=await chromium.launch({executablePath:'/usr/bin/chromium',headless:true,args:['--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader']});
 const context=await browser.newContext({viewport:{width:844,height:390},deviceScaleFactor:3,isMobile:true,hasTouch:true,userAgent:'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1',serviceWorkers:'block'});
 if(process.env.QSE_IPHONE_STANDALONE==='1')await context.addInitScript(()=>Object.defineProperty(navigator,'standalone',{value:true,configurable:true}));
 const blocked=[];await context.route('**/*',r=>{const u=new URL(r.request().url());if(['127.0.0.1','localhost'].includes(u.hostname))return r.continue();blocked.push(u.hostname);return r.abort();});
 const page=await context.newPage();const errors=[];const consoleErrors=[];
 page.on('pageerror',e=>errors.push(String(e)));page.on('console',m=>{if(m.type()==='error')consoleErrors.push(m.text());fs.appendFileSync(out+'/console.log',m.text()+'\n');});
 const states=process.argv.slice(2);const results=[];
 for(const state of states.length?states:['production','form','room','selection','skins','friends','profile','wallet','story','music']){
  errors.length=0;consoleErrors.length=0;
  const fixture=state!=='production';
  await page.goto(`${fixture?(process.env.QSE_FIXTURE_URL||'http://127.0.0.1:8134/quemsoueuv3/'):(process.env.QSE_PRODUCTION_URL||'http://127.0.0.1:8133/quemsoueuv3/')}${fixture?'?fixture='+state:''}`,{waitUntil:'domcontentloaded',timeout:120000});
  if(fixture)await page.waitForFunction(()=>window.qseLayoutReady===true,null,{timeout:120000});
  else await page.waitForFunction(()=>!document.getElementById('boot')||document.getElementById('boot').classList.contains('done'),null,{timeout:120000});
  await page.waitForFunction(()=>{const c=document.getElementById('canvas'),r=c.getBoundingClientRect(),s=window.qsePwa?.safe;return s&&document.fullscreenElement!==c&&Math.abs(r.width-s.width)<1&&Math.abs(r.height-s.height)<1&&Math.abs(r.left-s.left)<1&&Math.abs(r.top-s.top)<1;},null,{timeout:60000});
  if(state==='selection') {
   await page.evaluate(()=>window.qseSelectionProbe());
   const before=await page.evaluate(()=>({cards:window.qseSelectionState.cards,layout:window.qseLayoutReport.logical_size,canvas:(()=>{const r=document.getElementById('canvas').getBoundingClientRect();return {x:r.x,y:r.y,w:r.width,h:r.height};})()}));
   for(const card of before.cards.slice(0,3)) {
    const [x,y,w,h]=card.rect; const c=before.canvas;
    await page.touchscreen.tap(c.x+(x+w/2)*c.w/before.layout[0],c.y+(y+h/2)*c.h/before.layout[1]);
    await page.waitForTimeout(300);
   }
   await page.evaluate(()=>window.qseSelectionProbe());
   const selected=await page.evaluate(()=>window.qseSelectionState);
   fs.writeFileSync(out+'/selection-interaction.json',JSON.stringify(selected,null,2));
   if(selected.chosen!==3||selected.confirm_disabled)throw new Error('Selection touch or confirm state failed');
   if(selected.cards.some(c=>c.font<16||c.caption_height<40))throw new Error('Card caption too small');
  }
  const report=await page.evaluate(()=>{const c=document.getElementById('canvas'),r=c.getBoundingClientRect();return {engine:typeof Engine,iphone:window.qsePwa?.iphone,standalone:window.qsePwa?.standalone,dpr:devicePixelRatio,canvas:{width:c.width,height:c.height,css:[r.x,r.y,r.width,r.height],inline:c.style.cssText,computed:{position:getComputedStyle(c).position,margin:getComputedStyle(c).margin,transform:getComputedStyle(c).transform},fullscreen:document.fullscreenElement?.tagName,safe:window.qsePwa?.safe},fixture:window.qseLayoutReport||null};});
  await page.screenshot({path:`${out}/${state}.png`,scale:'css',timeout:120000});
  results.push({state,report,errors:[...errors],consoleErrors:[...consoleErrors]});
  fs.writeFileSync(out+'/'+state+'.json',JSON.stringify(results[results.length-1],null,2));
  fs.writeFileSync(`${out}/results.json`,JSON.stringify({results,blockedHosts:[...new Set(blocked)]},null,2));
  console.log(JSON.stringify({state,...report,errors,consoleErrors}));
 }
 await browser.close();
 if(results.some(r=>r.errors.length||r.consoleErrors.some(m=>/SCRIPT ERROR:|Parse Error:|^ERROR:/.test(m))||!r.report.iphone||r.report.dpr!==3))process.exitCode=1;
})().catch(e=>{console.error(e);process.exit(1)});
