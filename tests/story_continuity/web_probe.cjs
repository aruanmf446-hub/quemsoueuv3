// RPC mock only; real Supabase SQL is tested separately with backend.sql + rollback.
const {chromium}=require('playwright');const fs=require('fs');
const out=process.env.QSE_CONTINUITY_WEB_OUT||'/tmp/qse-continuity-browser';fs.mkdirSync(out,{recursive:true});
(async()=>{
 const browser=await chromium.launch({executablePath:'/usr/bin/chromium',headless:true,args:['--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader']});let page;
 try{
 const width=Number(process.env.QSE_CONTINUITY_WIDTH||844),height=Number(process.env.QSE_CONTINUITY_HEIGHT||390);
 const context=await browser.newContext({viewport:{width,height},deviceScaleFactor:3,isMobile:true,hasTouch:true,serviceWorkers:'block',userAgent:'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Version/18.0 Mobile/15E148 Safari/604.1'});
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
 await probe('feedback-controls');await wait(s=>s.actor_feedback.floor);
 await page.keyboard.down('k');const shield=await wait(s=>s.actor_feedback.defending);await page.keyboard.up('k');
 if(shield.attack!==2||shield.defense!==1)throw Error('K mapping consumes wrong resource');
 await wait(s=>!s.actor_feedback.defending);
 await page.keyboard.down('j');const punch=await wait(s=>s.attack===1);await page.keyboard.up('j');
 if(punch.defense!==1)throw Error('J also triggered defense');
 await page.waitForTimeout(600);
 await page.keyboard.down('Space');await wait(s=>s.actor_feedback.jumps===1);await page.keyboard.up('Space');
 await page.keyboard.down('Space');const doubleJump=await wait(s=>s.actor_feedback.jumps===2&&s.actor_feedback.dust>0);await page.keyboard.up('Space');
 console.log('Real browser keyboard: J attack, K defense, double-jump dust');
 await probe('charges');await probe('complete-tasks');await probe('goal');await probe('next');
 const arrival=await wait(s=>s.stage==='play'&&s.order===2);
 if(arrival.attack!==2||arrival.defense!==3)throw Error('Charges lost across actual phase transition');
 await page.screenshot({path:out+'/03_cargas_na_fase_seguinte.jpg',type:'jpeg',quality:93,scale:'css'});console.log('Actual Web phase1 -> phase2 preserves 2 attack / 3 defense');
 await page.reload({waitUntil:'domcontentloaded'});await page.waitForFunction(()=>typeof window.qseContinuityProbe==='function');
 await probe('cloud:a:5');await probe('login:a');await wait(s=>s.sync==='success'&&s.completed===5);
 await probe('phase:2');const restored=await wait(s=>s.stage==='play'&&s.order===2);
 if(restored.attack!==2||restored.defense!==3)throw Error('Charges lost after browser reload');
 await probe('phase:6');await wait(s=>s.stage==='play'&&s.order===6);
 await probe('save-run');const saved=await probe('state');
 if(saved.run.checkpoint!==4||saved.run.health!==2||saved.run.tasks!==1||Object.values(saved.run.steps)[0]!==1)throw Error('Incomplete saved run');
 await page.screenshot({path:out+'/04_partida_guardada.jpg',type:'jpeg',quality:93,scale:'css'});
 await page.reload({waitUntil:'domcontentloaded'});await page.waitForFunction(()=>typeof window.qseContinuityProbe==='function');
 await probe('cloud:a:5');await probe('login:a');await wait(s=>s.sync==='success'&&s.completed===5);
 await probe('phase:6');await wait(s=>s.stage==='play'&&s.order===6);await probe('ground');const resumed=await probe('state');
 for(const key of ['checkpoint','health','tasks','collected','defeated'])if(resumed.run[key]!==saved.run[key])throw Error('Lost '+key+' after reload');
 if(Math.abs(resumed.run.x-saved.run.x)>0.1||JSON.stringify(resumed.run.charges)!==JSON.stringify(saved.run.charges)||JSON.stringify(resumed.run.steps)!==JSON.stringify(saved.run.steps))throw Error('Lost position, charges or partial Task');
 await page.screenshot({path:out+'/05_partida_retomada.jpg',type:'jpeg',quality:93,scale:'css'});console.log('Full run survives browser reload: position, checkpoint5, health2, exact5resources, partial Task, completed Task, item and enemy');
 const report={fixture_rpc_mock:true,real_backend_test:'tests/story_continuity/backend.sql + run_backend.sql, transaction rollback',viewport:width+'x'+height,dpr:3,physical_device:false,gpu:'SwiftShader software',guestHigher,cloudHigher,shield,punch,doubleJump,arrival,restored,saved,resumed,errors,engineErrors,blocked};
 fs.writeFileSync(out+'/report.json',JSON.stringify(report,null,2));
 if(errors.length||engineErrors.length||blocked.length)throw Error('Browser/engine/backend isolation error');console.log('WEB_CONTINUITY PASS');
 }catch(e){if(page){fs.writeFileSync(out+'/failure-state.json',JSON.stringify(await page.evaluate(()=>window.qseContinuityState).catch(()=>null),null,2));await page.screenshot({path:out+'/failure.jpg',type:'jpeg',scale:'css'}).catch(()=>{});}throw e;}finally{await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
