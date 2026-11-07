// Fixture places the actor before the obstacle; browser inputs perform every jump.
const {chromium}=require('playwright');
const fs=require('fs'),assert=require('assert');
const out=process.env.QSE_SOLID_WEB_OUT||'/tmp/qse-solid-browser';
fs.mkdirSync(out,{recursive:true});
(async()=>{
 const browser=await chromium.launch({executablePath:'/usr/bin/chromium',headless:true,args:['--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader']});
 let page;
 try{
  const context=await browser.newContext({viewport:{width:844,height:390},deviceScaleFactor:3,isMobile:true,hasTouch:true,serviceWorkers:'block',userAgent:'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Version/18.0 Mobile/15E148 Safari/604.1'});
  const errors=[],blocked=[];
  await context.route('**/*',r=>{const host=new URL(r.request().url()).hostname;if(['localhost','127.0.0.1'].includes(host))return r.continue();blocked.push(host);return r.abort();});
  page=await context.newPage();page.setDefaultTimeout(180000);
  page.on('pageerror',e=>errors.push(String(e)));
  page.on('console',m=>{const s=m.text();fs.appendFileSync(out+'/console.log',s+'\n');if(/SCRIPT ERROR:|Parse Error:|^ERROR:/.test(s))errors.push(s);});
  const probe=c=>page.evaluate(c=>{window.qseContinuityProbe(c);return window.qseContinuityState;},c);
  async function wait(predicate){await page.waitForFunction(source=>{window.qseContinuityProbe('state');return new Function('s','return ('+source+')(s)')(window.qseContinuityState);},predicate.toString(),{polling:50});return probe('state');}
  async function snap(name){await page.screenshot({path:out+'/'+name+'.jpg',type:'jpeg',quality:94,scale:'css'});}
  async function touchJump(){
   const s=await probe('state'),box=await page.locator('canvas').boundingBox();
   await page.touchscreen.tap(box.x+s.jump[0]*box.width,box.y+s.jump[1]*box.height);
  }
  await page.goto(process.env.QSE_SOLID_WEB_URL||'http://127.0.0.1:8135/quemsoueuv3/',{waitUntil:'domcontentloaded'});
  await page.waitForFunction(()=>typeof window.qseContinuityProbe==='function');
  await probe('phase:1');await wait(s=>s.stage==='play');await probe('obstacle');
  await wait(s=>s.actor.floor);
  await page.keyboard.down('ArrowRight');
  const wall=await wait(s=>s.actor.x>s.obstacle.left-0.6&&s.actor.vx===0&&s.actor.floor);
  await page.waitForTimeout(600);
  const held=await probe('state');assert(held.actor.x<held.obstacle.left-0.25,'walked through solid obstacle');
  await snap('01_lateral_solida');
  await touchJump();
  const top=await wait(s=>s.actor.floor&&Math.abs(s.actor.y-s.obstacle.top)<0.04&&s.actor.x>s.obstacle.left&&s.actor.x<s.obstacle.right);
  await page.keyboard.up('ArrowRight');await snap('02_salto_por_toque');
  await page.keyboard.down('ArrowRight');
  const exit=await wait(s=>s.actor.x>s.obstacle.right+0.7&&s.actor.floor&&Math.abs(s.actor.y-s.obstacle.base)<0.04);
  await page.keyboard.up('ArrowRight');await page.keyboard.down('ArrowLeft');
  const returnWall=await wait(s=>s.actor.x<s.obstacle.right+0.6&&s.actor.vx===0&&s.actor.floor);
  assert(returnWall.actor.x>returnWall.obstacle.right+0.25,'walked through right side');
  await touchJump();
  const returnTop=await wait(s=>s.actor.floor&&Math.abs(s.actor.y-s.obstacle.top)<0.04&&s.actor.x>s.obstacle.left&&s.actor.x<s.obstacle.right);
  await page.keyboard.up('ArrowLeft');await snap('03_salto_pelo_outro_lado');
  assert.equal(errors.length,0,'browser/engine errors');assert.equal(blocked.length,0,'unexpected external request');
  const report={passed:true,fixture_approach:true,physics_real:true,movement:'held arrow keys',jump:'actual touchscreen.tap, coordinates inside canvas safe area',viewport:'844x390',dpr:3,physical_device:false,gpu:'SwiftShader software',wall,held,top,exit,returnWall,returnTop,errors,blocked};
  fs.writeFileSync(out+'/report.json',JSON.stringify(report,null,2));
  console.log('WEB_SOLID_OBSTACLES PASS');
 }catch(e){if(page){fs.writeFileSync(out+'/failure-state.json',JSON.stringify(await page.evaluate(()=>window.qseContinuityState).catch(()=>null),null,2));await page.screenshot({path:out+'/failure.jpg',type:'jpeg',scale:'css'}).catch(()=>{});}throw e;}
 finally{await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
