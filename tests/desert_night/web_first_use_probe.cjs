const {chromium}=require('playwright');
const fs=require('fs');
const out=process.env.QSE_TUTORIAL_OUT||'/tmp/qse-web-first-use';fs.mkdirSync(out,{recursive:true});
(async()=>{
 const browser=await chromium.launch({executablePath:'/usr/bin/chromium',headless:true,args:['--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader']});
 try{
 const context=await browser.newContext({viewport:{width:844,height:390},deviceScaleFactor:3,isMobile:true,hasTouch:true,serviceWorkers:'block',userAgent:'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Version/18.0 Mobile/15E148 Safari/604.1'});
 const errors=[],logs=[],blocked=[];
 await context.route('**/*',r=>{if(['localhost','127.0.0.1'].includes(new URL(r.request().url()).hostname))return r.continue();blocked.push(new URL(r.request().url()).hostname);return r.abort();});
 const page=await context.newPage();page.setDefaultTimeout(180000);
 page.on('pageerror',e=>errors.push(String(e)));page.on('console',m=>{logs.push(m.text());fs.appendFileSync(out+'/console.log',m.text()+'\n');});
 async function state(){return page.evaluate(()=>{window.qseDesertProbe('state');return window.qseDesertState;});}
 async function tap(r,s){const c=await page.locator('#canvas').boundingBox();await page.touchscreen.tap(c.x+(r[0]+r[2]/2)*c.width/s.size[0],c.y+(r[1]+r[3]/2)*c.height/s.size[1]);}
 async function lesson(kind){await page.waitForFunction(k=>{window.qseDesertProbe('state');const s=window.qseDesertState;return s.stage==='play'&&s.first_use.active&&s.first_use.kind===k;},kind);const s=await state();if(!s.paused)throw new Error('Lesson did not pause');return s;}
 async function resume(s){await tap(s.first_use.continue,s);await page.waitForFunction(()=>{window.qseDesertProbe('state');return !window.qseDesertState.paused;});}
 await page.goto('http://127.0.0.1:8135/quemsoueuv3/?firstUse=1',{waitUntil:'domcontentloaded'});
 await page.waitForFunction(()=>typeof window.qseDesertProbe==='function');let s=await state();await tap(s.skip,s);
 const attack=await lesson('attack');if(attack.attack_charge!==0||attack.defense_charge!==0)throw new Error('Phase1 resources not zero');
 await page.screenshot({path:out+'/attack.png',scale:'css'});
 await page.waitForTimeout(500);if((await state()).x!==attack.x)throw new Error('Paused player moved');await resume(attack);
 await page.evaluate(()=>window.qseDesertProbe('tutorial:defense'));
 const defense=await lesson('defense');if(defense.defense_charge!==1)throw new Error('Defense pickup did not supply a charge');
 await page.screenshot({path:out+'/defense.png',scale:'css'});await resume(defense);
 await page.evaluate(()=>window.qseDesertProbe('tutorial:task'));
 const task=await lesson('task');await page.screenshot({path:out+'/task_lesson.png',scale:'css'});await resume(task);
 s=await state();const r=s.bridge_task;const center=[r[0]+r[2]/2,r[1]+r[3]/2];
 if(Math.abs(center[0]-s.buttons.attack[0])>2||center[1]>=s.buttons.attack[1])throw new Error('Task not above attack');
 await page.screenshot({path:out+'/task_button.png',scale:'css'});await tap(r,s);
 await page.waitForFunction(()=>{window.qseDesertProbe('state');return window.qseDesertState.bridges.some(b=>b.raised&&b.solid);});
 const completed=await state();fs.writeFileSync(out+'/task-completed.json',JSON.stringify(completed,null,2));if(completed.defense_charge!==1||completed.bridge_task.length)throw new Error('Task consumed resources or failed to hide');
 await page.reload({waitUntil:'domcontentloaded'});
 await page.waitForFunction(()=>typeof window.qseDesertProbe==='function');
 await page.waitForFunction(()=>{window.qseDesertProbe('state');return window.qseDesertState.stage==='play';});
 const reloaded=await state();if(reloaded.paused||reloaded.first_use.active)throw new Error('Attack lesson repeated after reload');
 await page.evaluate(()=>window.qseDesertProbe('tutorial:defense'));await page.waitForFunction(()=>{window.qseDesertProbe('state');return window.qseDesertState.defense_charge===1;});
 if((await state()).paused)throw new Error('Defense lesson repeated after reload');
 await page.evaluate(()=>window.qseDesertProbe('tutorial:task'));
 await page.waitForFunction(()=>{window.qseDesertProbe('state');return window.qseDesertState.bridge_task.length===4;});
 const repeatTask=await state();if(repeatTask.paused||repeatTask.first_use.active)throw new Error('Task lesson repeated after reload');
 const report={fixture_teleport:true,viewport:'844x390',dpr:3,physical_device:false,attack,defense,task,completed,reloaded,repeatTask,errors,blocked,engineErrors:logs.filter(s=>/SCRIPT ERROR:|Parse Error:|^ERROR:/.test(s))};
 fs.writeFileSync(out+'/report.json',JSON.stringify(report,null,2));
 if(errors.length||blocked.length||report.engineErrors.length)throw new Error('Browser or engine error');
 console.log('WEB_FIRST_USE PASS: zero charges, three real pauses, contextual touch, localStorage persistence after reload');
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
