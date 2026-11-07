// Render real WebGL da água (fase 5 por padrão; QSE_WATER_PHASE=4 para o canal).
// Fixture congela o ator e retira encontros para a captura.
const {chromium}=require('playwright'),fs=require('fs'),assert=require('assert');
const out=process.env.QSE_WATER_WEB_OUT||'/tmp/qse-water-web';fs.mkdirSync(out,{recursive:true});
const phase=Number(process.env.QSE_WATER_PHASE||5);assert([4,5].includes(phase),'water phase must be 4 or 5');
(async()=>{
 const browser=await chromium.launch({executablePath:'/usr/bin/chromium',headless:true,args:['--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader']});
 try{
  const context=await browser.newContext({viewport:{width:844,height:390},deviceScaleFactor:3,isMobile:true,hasTouch:true,serviceWorkers:'block',userAgent:'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Version/18.0 Mobile/15E148 Safari/604.1'});
  const errors=[],blocked=[];
  await context.route('**/*',r=>{if(['localhost','127.0.0.1'].includes(new URL(r.request().url()).hostname))return r.continue();blocked.push(new URL(r.request().url()).hostname);return r.abort();});
  const page=await context.newPage();page.setDefaultTimeout(180000);
  page.on('pageerror',e=>errors.push(String(e)));page.on('console',m=>{const s=m.text();fs.appendFileSync(out+'/console.log',s+'\n');if(/SCRIPT ERROR:|SHADER ERROR:|Parse Error:|^ERROR:/.test(s))errors.push(s);});
  await page.goto('http://127.0.0.1:8135/quemsoueuv3/',{waitUntil:'domcontentloaded'});
  await page.waitForFunction(()=>typeof window.qseContinuityProbe==='function');
  await page.evaluate(order=>window.qseContinuityProbe('phase:'+order),phase);
  await page.waitForFunction(order=>{window.qseContinuityProbe('state');return window.qseContinuityState.stage==='play'&&window.qseContinuityState.order===order;},phase);
  await page.evaluate(()=>window.qseContinuityProbe('ground'));await page.waitForTimeout(1500);
  await page.screenshot({path:out+'/fase_'+String(phase).padStart(2,'0')+'_agua.jpg',type:'jpeg',quality:94,scale:'css'});
  assert(!errors.length&&!blocked.length,'browser/shader/backend error');
  fs.writeFileSync(out+'/report.json',JSON.stringify({passed:true,phase,viewport:'844x390',dpr:3,physical_device:false,gpu:'SwiftShader software',fixture_scenery_only:true,errors,blocked},null,2));
  console.log('WEB_WATER PASS');
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
