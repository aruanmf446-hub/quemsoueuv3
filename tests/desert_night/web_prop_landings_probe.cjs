// Actual WebAssembly/WebGL2: fixture approaches a real stall; both jumps use touch input.
const {chromium}=require('playwright');
const fs=require('fs');
const out=process.env.QSE_LANDINGS_WEB_OUT||'/tmp/qse-web-landings';fs.mkdirSync(out,{recursive:true});
(async()=>{
 const browser=await chromium.launch({executablePath:'/usr/bin/chromium',headless:true,args:['--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader']});
 try{
 const context=await browser.newContext({viewport:{width:844,height:390},deviceScaleFactor:3,isMobile:true,hasTouch:true,serviceWorkers:'block',userAgent:'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Version/18.0 Mobile/15E148 Safari/604.1'});
 const errors=[],logs=[],blocked=[];
 await context.route('**/*',r=>{const host=new URL(r.request().url()).hostname;if(['localhost','127.0.0.1'].includes(host))return r.continue();blocked.push(host);return r.abort();});
 const page=await context.newPage();page.setDefaultTimeout(180000);
 page.on('pageerror',e=>errors.push(String(e)));page.on('console',m=>{logs.push(m.text());fs.appendFileSync(out+'/console.log',m.text()+'\n');});
 async function state(){return page.evaluate(()=>{window.qseDesertProbe('state');return window.qseDesertState;});}
 async function wait(test){await page.waitForFunction(source=>{window.qseDesertProbe('state');return new Function('s','return ('+source+')(s)')(window.qseDesertState);},test.toString());return state();}
 async function tap(r,s){const c=await page.locator('#canvas').boundingBox();await page.touchscreen.tap(c.x+(r[0]+r[2]/2)*c.width/s.size[0],c.y+(r[1]+r[3]/2)*c.height/s.size[1]);}
 async function jump(s){const b=s.buttons.jump;await tap([b[0]-b[2],b[1]-b[2],b[2]*2,b[2]*2],s);}
 await page.goto('http://127.0.0.1:8135/quemsoueuv3/',{waitUntil:'domcontentloaded'});
 await page.waitForFunction(()=>typeof window.qseDesertProbe==='function');let s=await state();await tap(s.skip,s);await wait(s=>s.stage==='play');
 await page.evaluate(()=>window.qseDesertProbe('phase:3'));s=await wait(s=>s.stage==='loading'&&s.ready);await tap(s.skip,s);await wait(s=>s.stage==='play'&&s.order===3);
 await page.evaluate(()=>window.qseDesertProbe('prop_approach'));const before=await wait(s=>s.prop&&s.grounded&&Math.abs(s.y-s.prop.base)<0.025);
 await page.screenshot({path:out+'/01_debaixo.png',scale:'css'});console.log('Ground approach ready');
 await jump(before);s=await wait(s=>s.y>s.prop.base+1.55&&!s.grounded);if(s.ceiling)throw Error('Jump stuck below canopy');
 await jump(s);const airborne=await wait(s=>s.y>s.prop.top+0.04);if(airborne.ceiling)throw Error('Head collided with canopy');
 const landed=await wait(s=>s.grounded&&Math.abs(s.y-s.prop.top)<0.04);
 if(landed.jumps_used!==0)throw Error('Landing did not restore jumps');
 await page.screenshot({path:out+'/02_na_lona.png',scale:'css'});console.log('Touch double jump and actual canopy landing PASS');
 await page.keyboard.press('ArrowRight',{delay:90});const walked=await state();fs.writeFileSync(out+'/walk-debug.json',JSON.stringify({landed,walked},null,2));if(walked.x<=landed.x+0.02||Math.abs(walked.y-walked.prop.top)>0.04)throw Error('Cannot run on canopy: '+JSON.stringify({dx:walked.x-landed.x,y:walked.y,top:walked.prop.top}));
 // Keep the final jump independent of the walk duration/edge: re-approach, then repeat.
 await page.evaluate(()=>window.qseDesertProbe('prop_approach'));s=await wait(s=>s.grounded&&Math.abs(s.y-s.prop.base)<0.025);await jump(s);s=await wait(s=>s.y>s.prop.base+1.55&&!s.grounded);await jump(s);s=await wait(s=>s.grounded&&Math.abs(s.y-s.prop.top)<0.04);await jump(s);
 const again=await wait(s=>s.y>s.prop.top+0.5);await page.screenshot({path:out+'/03_novo_salto.png',scale:'css'});
 const report={fixture_teleport:true,viewport:'844x390',dpr:3,physical_device:false,before,airborne,landed,walked,again,errors,blocked,engineErrors:logs.filter(s=>/SCRIPT ERROR:|Parse Error:|^ERROR:/.test(s))};
 fs.writeFileSync(out+'/report.json',JSON.stringify(report,null,2));if(errors.length||blocked.length||report.engineErrors.length)throw Error('Browser or engine error');console.log('WEB_PROP_LANDINGS PASS');
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
