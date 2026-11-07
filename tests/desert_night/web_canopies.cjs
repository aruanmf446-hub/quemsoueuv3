// Actual touch double jump onto the first merchant canopy. Fixture only approaches.
const {chromium}=require('playwright');const fs=require('fs'),assert=require('assert');
const out=process.env.QSE_CANOPIES_OUT||'/tmp/qse-lonas-web';fs.mkdirSync(out,{recursive:true});
(async()=>{
 const browser=await chromium.launch({executablePath:'/usr/bin/chromium',headless:true,args:['--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader']});let page,pulse;
 try{
  const context=await browser.newContext({viewport:{width:844,height:390},deviceScaleFactor:3,isMobile:true,hasTouch:true,serviceWorkers:'block',userAgent:'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Version/18.0 Mobile/15E148 Safari/604.1'});
  const errors=[],blocked=[];
  await context.route('**/*',r=>{const host=new URL(r.request().url()).hostname;if(['localhost','127.0.0.1'].includes(host))return r.continue();blocked.push(host);return r.abort();});
  page=await context.newPage();page.setDefaultTimeout(180000);
  page.on('pageerror',e=>errors.push(String(e)));page.on('console',m=>{const s=m.text();fs.appendFileSync(out+'/console.log',s+'\n');if(/SCRIPT ERROR:|Parse Error:|^ERROR:/.test(s))errors.push(s);});
  const probe=c=>page.evaluate(c=>{window.qseContinuityProbe(c);return window.qseContinuityState;},c);
  async function wait(fn){await page.waitForFunction(source=>{window.qseContinuityProbe('state');return new Function('s','return ('+source+')(s)')(window.qseContinuityState);},fn.toString(),{polling:40});return page.evaluate(()=>window.qseContinuityState);}
  let touchPoint;
  const cdp=await context.newCDPSession(page);
  const down=()=>cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{...touchPoint,id:0,radiusX:5,radiusY:5}]});
  const up=()=>cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});
  async function jump(){await down();await wait(s=>!s.actor.floor&&s.actor.vy>0);await up();}
  await page.goto('http://127.0.0.1:8135/quemsoueuv3/',{waitUntil:'domcontentloaded'});
  await page.waitForFunction(()=>typeof window.qseContinuityProbe==='function');
  pulse=setInterval(async()=>{try{fs.writeFileSync(out+'/last-state.json',JSON.stringify(await probe('state'),null,2));}catch{}},5000);
  await probe('phase:1');await wait(s=>s.stage==='play');await probe('canopy');
  const before=await wait(s=>s.actor.floor);
  const box=await page.locator('canvas').boundingBox();
  touchPoint={x:box.x+before.jump[0]*box.width,y:box.y+before.jump[1]*box.height};
  await down();
  // Do not insert extra state/geometry round trips between the two gestures:
  // SwiftShader may advance several physics ticks on each browser response.
  await page.waitForFunction(()=>{window.qseContinuityProbe('state');const s=window.qseContinuityState;return s.actor.jumps===1&&s.actor.y>s.obstacle.base+0.4;},null,{polling:20});
  await Promise.all([up(),down()]);
  const air=await wait(s=>s.actor.jumps===2);await up();
  const above=await wait(s=>s.actor.y>s.obstacle.top+0.08);
  const landed=await wait(s=>s.actor.floor&&Math.abs(s.actor.y-s.obstacle.top)<0.04);
  await probe('view');await page.screenshot({path:out+'/01_pisando_na_lona.jpg',type:'jpeg',quality:94,scale:'css'});
  await page.keyboard.down('ArrowRight');
  const walking=await wait(s=>s.actor.vx>0&&s.actor.floor&&Math.abs(s.actor.y-s.obstacle.top)<0.04);
  await page.keyboard.up('ArrowRight');
  await jump();const again=await wait(s=>!s.actor.floor&&s.actor.y>s.obstacle.top+0.3);
  await wait(s=>s.actor.floor&&Math.abs(s.actor.y-s.obstacle.top)<0.04);
  await page.keyboard.down('ArrowRight');const edge=await wait(s=>s.actor.x>s.obstacle.right+0.4&&s.actor.y<s.obstacle.top-0.2);await page.keyboard.up('ArrowRight');
  assert(!errors.length&&!blocked.length,'browser/engine/backend errors');
  fs.writeFileSync(out+'/report.json',JSON.stringify({passed:true,viewport:'844x390',dpr:3,physical_device:false,gpu:'SwiftShader software',fixture_approach:true,jumps:'native browser touchStart/touchEnd via CDP, held until physics acknowledges each jump',walking:'keyboard',before,air,above,landed,walking,again,edge,errors,blocked},null,2));
  console.log('WEB_CANOPIES PASS');
 }catch(e){if(page){fs.writeFileSync(out+'/failure-state.json',JSON.stringify(await page.evaluate(()=>window.qseContinuityState).catch(()=>null),null,2));await page.screenshot({path:out+'/failure.jpg',scale:'css'}).catch(()=>{});}throw e;}finally{clearInterval(pulse);await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
