// Nine real WebGL scenes. Fixture positions/freezes actors for visual review only.
const {chromium}=require('playwright'),fs=require('fs'),assert=require('assert');
const out=process.env.QSE_CAMPAIGN_REVIEW_OUT||'/tmp/qse-web-campaign-review';fs.mkdirSync(out,{recursive:true});
(async()=>{
 const browser=await chromium.launch({executablePath:'/usr/bin/chromium',headless:true,args:['--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader']});
 try{
  const context=await browser.newContext({viewport:{width:844,height:390},deviceScaleFactor:3,isMobile:true,hasTouch:true,serviceWorkers:'block',userAgent:'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Version/18.0 Mobile/15E148 Safari/604.1'});
  const errors=[],blocked=[],phases=[];
  await context.route('**/*',r=>{if(['localhost','127.0.0.1'].includes(new URL(r.request().url()).hostname))return r.continue();blocked.push(new URL(r.request().url()).hostname);return r.abort();});
  const page=await context.newPage();page.setDefaultTimeout(180000);
  page.on('pageerror',e=>errors.push(String(e)));page.on('console',m=>{const s=m.text();fs.appendFileSync(out+'/console.log',s+'\n');if(/SCRIPT ERROR:|SHADER ERROR:|Parse Error:|^ERROR:/.test(s))errors.push(s);});
  await page.goto('http://127.0.0.1:8135/quemsoueuv3/',{waitUntil:'domcontentloaded'});
  await page.waitForFunction(()=>typeof window.qseContinuityProbe==='function');
  for(let order=1;order<=9;order++){
   await page.evaluate(n=>window.qseContinuityProbe('phase:'+n),order);
   await page.waitForFunction(n=>{window.qseContinuityProbe('state');return window.qseContinuityState.stage==='play'&&window.qseContinuityState.order===n;},order);
   await page.evaluate(()=>window.qseContinuityProbe('ground'));await page.waitForTimeout(600);
   await page.screenshot({path:out+'/fase_'+String(order).padStart(2,'0')+'.jpg',type:'jpeg',quality:94,scale:'css'});
   phases.push(order);assert(!errors.length&&!blocked.length,'WebGL/engine/backend error in phase '+order);
  }
  assert(phases.length===9);
  fs.writeFileSync(out+'/report.json',JSON.stringify({passed:true,phases,viewport:'844x390',dpr:3,physical_device:false,gpu:'SwiftShader software',fixture_scenery_only:true,errors,blocked},null,2));
  console.log('WEB_CAMPAIGN_REVIEW PASS 9/9');
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
