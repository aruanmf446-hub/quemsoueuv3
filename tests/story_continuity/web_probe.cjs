// RPC mock only; real Supabase SQL is tested separately with backend.sql + rollback.
const {chromium}=require('playwright');const fs=require('fs');
const out=process.env.QSE_CONTINUITY_WEB_OUT||'/tmp/qse-continuity-browser';fs.mkdirSync(out,{recursive:true});
(async()=>{
 const browser=await chromium.launch({executablePath:'/usr/bin/chromium',headless:true,args:['--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader']});let page;
 try{
 const context=await browser.newContext({viewport:{width:844,height:390},deviceScaleFactor:3,isMobile:true,hasTouch:true,serviceWorkers:'block',userAgent:'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Version/18.0 Mobile/15E148 Safari/604.1'});
 const errors=[],engineErrors=[],blocked=[];
 await context.route('**/*',r=>{const host=new URL(r.request().url()).hostname;if(['localhost','127.0.0.1'].includes(host))return r.continue();blocked.push(host);return r.abort();});
 page=await context.newPage();page.setDefaultTimeout(180000);
 page.on('pageerror',e=>errors.push(String(e)));page.on('console',m=>{const s=m.text();fs.appendFileSync(out+'/console.log',s+'\n');if(/SCRIPT ERROR:|Parse Error:|^ERROR:/.test(s))engineErrors.push(s);});
 const probe=cmd=>page.evaluate(c=>{window.qseContinuityProbe(c);return window.qseContinuityState;},cmd);
 async function wait(test){await page.waitForFunction(source=>{window.qseContinuityProbe('state');return new Function('s','return ('+source+')(s)')(window.qseContinuityState);},test.toString());return probe('state');}
 await page.goto('http://127.0.0.1:8135/quemsoueuv3/',{waitUntil:'domcontentloaded'});
 await page.waitForFunction(()=>typeof window.qseContinuityProbe==='function');
 await probe('guest:5');await probe('cloud:a:2');await probe('login:a');
 const guestHigher=await wait(s=>s.sync==='success'&&s.completed===5);if(!guestHigher.notice.includes('automaticamente'))throw Error('Missing automatic conflict feedback');
 await page.screenshot({path:out+'/01_visitante_mais_avancado.jpg',type:'jpeg',quality:93,scale:'css'});console.log('Guest 5 + account 2 => 5 completed, without a prompt');
 await probe('cloud:b:7');await probe('login:b');
 const cloudHigher=await wait(s=>s.sync==='success'&&s.completed===7);console.log('Higher existing account recovered');
 await probe('login:a');await wait(s=>s.sync==='success'&&s.completed===5);
 await probe('phase:1');
 await wait(s=>s.stage==='loading'&&s.reads>0&&s.reads<s.total);
 await page.screenshot({path:out+'/02_carregando_recursos.jpg',type:'jpeg',quality:93,scale:'css'});
 await wait(s=>s.stage==='play'&&s.order===1);
 await probe('charges');await probe('goal');await probe('next');
 const arrival=await wait(s=>s.stage==='play'&&s.order===2);
 if(arrival.attack!==2||arrival.defense!==3)throw Error('Charges lost across actual phase transition');
 await page.screenshot({path:out+'/03_cargas_na_fase_seguinte.jpg',type:'jpeg',quality:93,scale:'css'});console.log('Actual Web phase1 -> phase2 preserves 2 attack / 3 defense');
 await page.reload({waitUntil:'domcontentloaded'});await page.waitForFunction(()=>typeof window.qseContinuityProbe==='function');
 await probe('cloud:a:5');await probe('login:a');await wait(s=>s.sync==='success'&&s.completed===5);
 await probe('phase:2');const restored=await wait(s=>s.stage==='play'&&s.order===2);
 if(restored.attack!==2||restored.defense!==3)throw Error('Charges lost after browser reload');
 const report={fixture_rpc_mock:true,real_backend_test:'tests/story_continuity/backend.sql, transaction rollback',viewport:'844x390',dpr:3,physical_device:false,gpu:'SwiftShader software',guestHigher,cloudHigher,arrival,restored,errors,engineErrors,blocked};
 fs.writeFileSync(out+'/report.json',JSON.stringify(report,null,2));
 if(errors.length||engineErrors.length||blocked.length)throw Error('Browser/engine/backend isolation error');console.log('WEB_CONTINUITY PASS');
 }catch(e){if(page){fs.writeFileSync(out+'/failure-state.json',JSON.stringify(await page.evaluate(()=>window.qseContinuityState).catch(()=>null),null,2));await page.screenshot({path:out+'/failure.jpg',type:'jpeg',scale:'css'}).catch(()=>{});}throw e;}finally{await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
