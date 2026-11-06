// Real WebAssembly + touch. Teleport is an explicit fixture; button and walking are real input.
const {chromium}=require('playwright');
const fs=require('fs');
const out=process.env.QSE_PARKOUR_WEB_OUT||'/tmp/qse-scenario-web';fs.mkdirSync(out,{recursive:true});
(async()=>{
 const browser=await chromium.launch({executablePath:'/usr/bin/chromium',headless:true,args:['--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader']});
 try{
 const context=await browser.newContext({viewport:{width:844,height:390},deviceScaleFactor:3,isMobile:true,hasTouch:true,serviceWorkers:'block',userAgent:'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Version/18.0 Mobile/15E148 Safari/604.1'});
 const blocked=[],errors=[],logs=[];
 await context.route('**/*',r=>{if(['localhost','127.0.0.1'].includes(new URL(r.request().url()).hostname))return r.continue();blocked.push(r.request().url().split('/')[2]);return r.abort();});
 const page=await context.newPage();page.setDefaultTimeout(180000);
 page.on('pageerror',e=>errors.push(String(e)));page.on('console',m=>{logs.push(m.text());fs.appendFileSync(out+'/console.log',m.text()+'\n');});
 async function state(){return page.evaluate(()=>{window.qseDesertProbe('state');return window.qseDesertState;});}
 async function tap(rect,s){const c=await page.locator('#canvas').boundingBox();await page.touchscreen.tap(c.x+(rect[0]+rect[2]/2)*c.width/s.size[0],c.y+(rect[1]+rect[3]/2)*c.height/s.size[1]);}
 await page.goto('http://127.0.0.1:8135/quemsoueuv3/',{waitUntil:'domcontentloaded'});
 await page.waitForFunction(()=>typeof window.qseDesertProbe==='function');
 let s=await state();await tap(s.skip,s);
 await page.waitForFunction(()=>{window.qseDesertProbe('state');return window.qseDesertState.stage==='play';});
 const results=[];
 const orders=process.env.QSE_SCENARIO_ORDERS?process.env.QSE_SCENARIO_ORDERS.split(',').map(Number):[1,3,7];
 for(const order of orders) {
 await page.evaluate(n=>window.qseExpectedOrder=n,order);
 if(order!==1) {
 await page.evaluate(n=>window.qseDesertProbe('phase:'+n),order);
 await page.waitForFunction(()=>{window.qseDesertProbe('state');return window.qseDesertState.stage==='loading'&&window.qseDesertState.ready;});
 s=await state();await tap(s.next,s);
 await page.waitForFunction(()=>{window.qseDesertProbe('state');return window.qseDesertState.order===window.qseExpectedOrder&&window.qseDesertState.stage==='play';});
 }
 await page.evaluate(()=>window.qseDesertProbe('task'));
 await page.waitForFunction(()=>{window.qseDesertProbe('state');return window.qseDesertState.bridge_task.length===4;});
 const before=await state();await page.screenshot({path:out+`/task_${order}_before.png`,scale:'css'});
 await tap(before.bridge_task,before);
 await page.keyboard.down("ArrowRight");
 await page.waitForFunction(()=>{window.qseDesertProbe('state');return window.qseDesertState.bridges.some(b=>b.raised&&b.solid);});
 await page.keyboard.up("ArrowRight");
 const after=await state();await page.screenshot({path:out+`/task_${order}_after.png`,scale:'css'});
 if(after.defense_charge!==0||after.bridge_task.length)throw new Error('Task charged defense or remained visible');
 await page.keyboard.down('ArrowRight');
 await page.waitForFunction(()=>{window.qseDesertProbe('state');const s=window.qseDesertState;return s.x>s.bridges[0].end+0.7;},null,{timeout:60000});
 await page.keyboard.up('ArrowRight');const right=await state();fs.writeFileSync(out+'/last-state.json',JSON.stringify({order,right},null,2));
 await page.keyboard.down('ArrowLeft');
 await page.waitForFunction(()=>{window.qseDesertProbe('state');const s=window.qseDesertState;return s.x<s.bridges[0].start-0.7;},null,{timeout:60000});
 await page.keyboard.up('ArrowLeft');const left=await state();
 results.push({order,before,after,right,left});
 }
 const report={fixture_teleport:true,viewport:'844x390',dpr:3,physical_device:false,results,errors,blocked,engineErrors:logs.filter(s=>/SCRIPT ERROR:|Parse Error:|^ERROR:/.test(s))};
 fs.writeFileSync(out+'/report.json',JSON.stringify(report,null,2));
 if(errors.length||report.engineErrors.length||blocked.length)throw new Error('Web error; see report');
 console.log('WEB_SCENARIO PASS: phases '+orders.join(',')+'; touch with zero charges; walked both directions');
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
