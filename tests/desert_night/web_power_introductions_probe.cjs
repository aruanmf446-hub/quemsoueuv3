// Staging only: real WASM/touch; explicit teleport approaches actual collectible collisions.
const {chromium}=require('playwright');
const fs=require('fs');
const out=process.env.QSE_POWER_WEB_OUT||'/tmp/qse-web-powers';fs.mkdirSync(out,{recursive:true});
(async()=>{
 const browser=await chromium.launch({executablePath:'/usr/bin/chromium',headless:true,args:['--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader']});
 try{
 const context=await browser.newContext({viewport:{width:844,height:390},deviceScaleFactor:3,isMobile:true,hasTouch:true,serviceWorkers:'block',userAgent:'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Version/18.0 Mobile/15E148 Safari/604.1'});
 const errors=[],logs=[],blocked=[],results=[];
 await context.route('**/*',r=>{const host=new URL(r.request().url()).hostname;if(['localhost','127.0.0.1'].includes(host))return r.continue();blocked.push(host);return r.abort();});
 const page=await context.newPage();page.setDefaultTimeout(180000);
 page.on('pageerror',e=>errors.push(String(e)));page.on('console',m=>{logs.push(m.text());fs.appendFileSync(out+'/console.log',m.text()+'\n');});
 async function state(){return page.evaluate(()=>{window.qseDesertProbe('state');return window.qseDesertState;});}
 async function tap(r,s){const c=await page.locator('#canvas').boundingBox();await page.touchscreen.tap(c.x+(r[0]+r[2]/2)*c.width/s.size[0],c.y+(r[1]+r[3]/2)*c.height/s.size[1]);}
 async function wait(test,arg){await page.waitForFunction(({source,arg})=>{window.qseDesertProbe('state');return new Function('s','arg','return ('+source+')(s,arg)')(window.qseDesertState,arg);},{source:test.toString(),arg});return state();}
 async function launch(order){console.log('Launch '+order);await page.evaluate(n=>window.qseDesertProbe('phase:'+n),order);let s=await wait(s=>s.stage==='loading'&&s.ready);await tap(s.skip,s);return wait((s,n)=>s.stage==='play'&&s.order===n,order);}
 await page.goto('http://127.0.0.1:8135/quemsoueuv3/?firstUse=1',{waitUntil:'domcontentloaded'});
 await page.waitForFunction(()=>typeof window.qseDesertProbe==='function');let s=await state();await tap(s.skip,s);
 console.log('Opening lesson');s=await wait(s=>s.stage==='play'&&s.first_use.active);await tap(s.first_use.continue,s);await wait(s=>!s.paused);
 for(const [order,kind] of [[3,'amber'],[4,'dash'],[5,'rupture']]){
  const before=await launch(order);if(before.charges[kind]!==0||before.buttons[kind]||before.paused)throw Error(kind+': premature charge/button/lesson');
  await page.evaluate(k=>window.qseDesertProbe('collect_power:'+k),kind);
  const lesson=await wait((s,k)=>s.first_use.active&&s.first_use.kind===k,kind);
  if(!lesson.paused||!lesson.first_use.illustration||lesson.charges[kind]!==1)throw Error(kind+': missing paused illustrated lesson');
  await page.screenshot({path:out+'/'+kind+'_lesson.png',scale:'css'});
  await page.waitForTimeout(350);const still=await state();if(still.x!==lesson.x||still.charges[kind]!==1)throw Error(kind+': gameplay not paused');
  await tap(lesson.first_use.continue,lesson);s=await wait(s=>!s.paused);
  if(kind==='rupture'){await page.evaluate(()=>window.qseDesertProbe('rupture_floor'));await page.waitForTimeout(350);s=await state();}
  const b=s.buttons[kind];if(!b)throw Error(kind+': missing power touch button');await tap([b[0]-b[2],b[1]-b[2],b[2]*2,b[2]*2],s);
  const used=await wait((s,k)=>s.charges[k]===0,kind);if(!used.buttons[kind]||used.paused)throw Error(kind+': zero button disappeared');
  await page.screenshot({path:out+'/'+kind+'_zero.png',scale:'css'});results.push({kind,before,lesson,used});console.log('PASS '+kind);
 }
 await page.reload({waitUntil:'domcontentloaded'});await page.waitForFunction(()=>typeof window.qseDesertProbe==='function');s=await state();if(s.stage==='loading'){await tap(s.skip,s);await wait(s=>s.stage==='play');}
 const replay=await launch(3);if(replay.charges.amber!==0||!replay.buttons.amber||replay.buttons.dash||replay.paused)throw Error('Profile/reload persistence incorrect');
 const report={fixture_teleport:true,viewport:'844x390',dpr:3,physical_device:false,results,replay,errors,blocked,engineErrors:logs.filter(s=>/SCRIPT ERROR:|Parse Error:|^ERROR:/.test(s))};fs.writeFileSync(out+'/report.json',JSON.stringify(report,null,2));
 if(errors.length||blocked.length||report.engineErrors.length)throw Error('Browser/engine error');console.log('WEB_POWER_INTRODUCTIONS PASS');
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
