// WebAssembly/WebGL2 real. Fixture aproxima a recarga; coleta, modal e escudo usam o jogo real.
const {chromium}=require('playwright');
const fs=require('fs');
const out=process.env.QSE_SPEAR_WEB_OUT||'/tmp/qse-web-spear';fs.mkdirSync(out,{recursive:true});
(async()=>{
 const browser=await chromium.launch({executablePath:'/usr/bin/chromium',headless:true,args:['--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader']});
 let page;
 try{
 const context=await browser.newContext({viewport:{width:844,height:390},deviceScaleFactor:3,isMobile:true,hasTouch:true,serviceWorkers:'block',userAgent:'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Version/18.0 Mobile/15E148 Safari/604.1'});
 const errors=[],logs=[],blocked=[];
 await context.route('**/*',r=>{const host=new URL(r.request().url()).hostname;if(['localhost','127.0.0.1'].includes(host))return r.continue();blocked.push(host);return r.abort();});
 page=await context.newPage();page.setDefaultTimeout(180000);
 page.on('pageerror',e=>errors.push(String(e)));page.on('console',m=>{logs.push(m.text());fs.appendFileSync(out+'/console.log',m.text()+'\n');});
 async function state(){return page.evaluate(()=>{window.qseDesertProbe('state');return window.qseDesertState;});}
 async function wait(test){await page.waitForFunction(source=>{window.qseDesertProbe('state');return new Function('s','return ('+source+')(s)')(window.qseDesertState);},test.toString());return state();}
 async function xy(x,y,s){const c=await page.locator('#canvas').boundingBox();return [c.x+x*c.width/s.size[0],c.y+y*c.height/s.size[1]];}
 async function tap(r,s){await page.touchscreen.tap(...await xy(r[0]+r[2]/2,r[1]+r[3]/2,s));}
 await page.goto(process.env.QSE_SPEAR_URL||'http://127.0.0.1:8135/quemsoueuv3/?firstUse=1',{waitUntil:'domcontentloaded'});
 await page.waitForFunction(()=>typeof window.qseDesertProbe==='function');let s=await state();await tap(s.skip,s);
 s=await wait(s=>s.stage==='play'&&s.first_use.active&&s.first_use.kind==='attack');
 await tap(s.first_use.continue,s);await wait(s=>!s.paused);
 await page.evaluate(()=>window.qseDesertProbe('spear_approach'));
 const lesson=await wait(s=>s.first_use.active&&s.first_use.kind==='defense');
 fs.writeFileSync(out+'/lesson.json',JSON.stringify(lesson,null,2));console.log('Defense lesson ready');
 if(!lesson.paused||!lesson.first_use.illustration||lesson.defense_charge!==1||lesson.spears.length!==1||lesson.spears[0].throws!==0)throw Error('First defense must pause before the throw with real illustration and charge');
 await page.screenshot({path:out+'/01_explicacao.jpg',type:'jpeg',quality:93,scale:'css'});
 const b=lesson.buttons.defend;
 const shield=await xy(b[0],b[1],lesson);
 await tap(lesson.first_use.continue,lesson);
 await wait(s=>!s.paused);
 await page.touchscreen.tap(...shield);
 fs.writeFileSync(out+'/after-touch.json',JSON.stringify(await state(),null,2));console.log('Shield tapped');
 const impact=await wait(s=>s.spears.some(g=>g.pursuit));
 if(impact.health!==3||impact.defense_charge!==0||impact.spears[0].last_hit!=='shield')throw Error('Actual touch shield failed to block: '+JSON.stringify(impact.spears));
 await page.screenshot({path:out+'/02_escudo_toque.jpg',type:'jpeg',quality:93,scale:'css'});
 console.log('Real touch shield blocks real spear; pursuit enabled only on shield hit');
 await page.reload({waitUntil:'domcontentloaded'});
 await page.waitForFunction(()=>typeof window.qseDesertProbe==='function');
 await wait(s=>s.stage==='play');
 await page.evaluate(()=>window.qseDesertProbe('spear_approach'));
 const reloaded=await wait(s=>s.defense_charge===1);
 if(reloaded.paused||reloaded.first_use.active)throw Error('Defense spear lesson repeated after reload');
 await page.evaluate(()=>window.qseDesertProbe('rooftops'));
 s=await wait(s=>s.stage==='loading'&&s.ready);await tap(s.skip,s);
 await wait(s=>s.stage==='play'&&s.order===2&&s.grounded);
 await page.screenshot({path:out+'/03_muro_fase2.jpg',type:'jpeg',quality:93,scale:'css'});
 await page.evaluate(()=>window.qseDesertProbe('phase:3'));
 s=await wait(s=>s.stage==='loading'&&s.ready);await tap(s.skip,s);
 await wait(s=>s.stage==='play'&&s.order===3);
 await page.evaluate(()=>window.qseDesertProbe('amber_showcase'));
 const amber=await wait(s=>s.amber_showcase);
 await page.screenshot({path:out+'/04_ambar_web.jpg',type:'jpeg',quality:93,scale:'css'});
 const report={fixture_teleport:true,amber_pose_fixture:true,viewport:'844x390',dpr:3,physical_device:false,gpu:'SwiftShader software',lesson,impact,reloaded,amber,errors,blocked,engineErrors:logs.filter(s=>/SCRIPT ERROR:|Parse Error:|^ERROR:/.test(s))};
 fs.writeFileSync(out+'/report.json',JSON.stringify(report,null,2));
 if(errors.length||blocked.length||report.engineErrors.length)throw Error('Browser or engine error');
 console.log('WEB_SPEAR PASS: real pickup, pause, illustration, touch block, pursuit, persistence and phase2/amber render');
 }catch(e){
  if(page){
   fs.writeFileSync(out+'/failure-state.json',JSON.stringify(await page.evaluate(()=>window.qseDesertState).catch(()=>null),null,2));
   await page.screenshot({path:out+'/failure.jpg',type:'jpeg',quality:90,scale:'css'}).catch(()=>{});
  }
  throw e;
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
