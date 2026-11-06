// Real WebGL frames and real keyboard input. No production/backend access.
const {chromium}=require('playwright');
const fs=require('fs');
const out=process.env.QSE_ROOF_WEB_OUT||'/tmp/qse-roof-contact-web';
fs.mkdirSync(out,{recursive:true});
(async()=>{
 const browser=await chromium.launch({executablePath:'/usr/bin/chromium',headless:true,args:['--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader']});
 try{
  const context=await browser.newContext({viewport:{width:844,height:390},deviceScaleFactor:3,isMobile:true,hasTouch:true,serviceWorkers:'block',userAgent:'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Version/18.0 Mobile/15E148 Safari/604.1'});
  const errors=[],engineErrors=[],blocked=[];
  await context.route('**/*',r=>['localhost','127.0.0.1'].includes(new URL(r.request().url()).hostname)?r.continue():(blocked.push(new URL(r.request().url()).hostname),r.abort()));
  const page=await context.newPage();page.setDefaultTimeout(180000);
  page.on('pageerror',e=>errors.push(String(e)));
  page.on('console',m=>{fs.appendFileSync(out+'/console.log',m.text()+'\n');if(/SCRIPT ERROR:|Parse Error:|^ERROR:/.test(m.text()))engineErrors.push(m.text());});
  async function state(){return page.evaluate(()=>{window.qseDesertProbe('state');return window.qseDesertState;});}
  async function tap(r,s){const c=await page.locator('#canvas').boundingBox();await page.touchscreen.tap(c.x+(r[0]+r[2]/2)*c.width/s.size[0],c.y+(r[1]+r[3]/2)*c.height/s.size[1]);}
  const records=[];
  async function snap(name){
   await page.waitForFunction(()=>{window.qseDesertProbe('state');const s=window.qseDesertState;return s.roof?.grounded&&Math.abs(s.roof.lead)<0.03;});
   const s=await state(),c=await page.locator('#canvas').boundingBox();
   if(s.roof.samples.length!==3)throw new Error('Need three visible pavement samples clear of player and pedestals');
   const samples=s.roof.samples.map(p=>[Math.round(c.x+p[0]*c.width/s.size[0]),Math.round(c.y+p[1]*c.height/s.size[1])]);
   await page.screenshot({path:out+'/'+name+'.png',scale:'css'});
   records.push({name,state:s,samples});
  }
  await page.goto('http://127.0.0.1:8135/quemsoueuv3/',{waitUntil:'domcontentloaded'});
  await page.waitForFunction(()=>typeof window.qseDesertProbe==='function');
  let s=await state();await tap(s.skip,s);
  await page.waitForFunction(()=>{window.qseDesertProbe('state');return window.qseDesertState.stage==='play';});
  await page.evaluate(()=>window.qseDesertProbe('phase:2'));
  await page.waitForFunction(()=>{window.qseDesertProbe('state');return window.qseDesertState.stage==='loading'&&window.qseDesertState.ready;});
  s=await state();await tap(s.next,s);
  await page.waitForFunction(()=>{window.qseDesertProbe('state');const s=window.qseDesertState;return s.order===2&&s.stage==='play';});
  await page.keyboard.down('ArrowRight');
  await page.waitForFunction(()=>{window.qseDesertProbe('state');return window.qseDesertState.x>-5.6;});
  await page.keyboard.up('ArrowRight');await snap('apoio_inicial');
  const start=(await state()).x;
  await page.keyboard.down('ArrowRight');
  await page.waitForFunction(x=>{window.qseDesertProbe('state');return window.qseDesertState.x>x+1.0;},start);
  await page.keyboard.up('ArrowRight');await snap('apos_direita');
  await page.keyboard.down('ArrowLeft');
  await page.waitForFunction(x=>{window.qseDesertProbe('state');return window.qseDesertState.x<x;},start);
  await page.keyboard.up('ArrowLeft');await snap('apos_esquerda');
  const report={viewport:'844x390',dpr:3,physical_device:false,renderer:'Chromium WebGL2 SwiftShader',fixture:'isolated loading scene; movement uses real input',records,errors,engineErrors,blocked};
  fs.writeFileSync(out+'/report.json',JSON.stringify(report,null,2));
  if(errors.length||engineErrors.length||blocked.length)throw new Error('Web error; see report');
  // Pixel assertions use the captured browser PNG, not engine metadata alone.
  require('child_process').execFileSync('python3',['-c',String.raw`
import json,sys
from pathlib import Path
from PIL import Image
out=Path(sys.argv[1]);p=out/'report.json';r=json.loads(p.read_text());checks=[]
for record in r['records']:
 image=Image.open(out/(record['name']+'.png')).convert('RGB')
 for x,y in record['samples']:
  rgb=image.getpixel((x,y));ok=rgb[2]-rgb[0]>25 and rgb[2]-rgb[1]>25
  checks.append({'name':record['name'],'point':[x,y],'rgb':list(rgb),'pavement':ok})
r['pixel_checks']=checks;r['pixels_passed']=len(checks)==9 and all(c['pavement'] for c in checks)
p.write_text(json.dumps(r,indent=2));print('WEB_ROOF_PIXELS',checks)
sys.exit(0 if r['pixels_passed'] else 1)
`,out],{stdio:'inherit'});
  console.log('WEB_ROOF_CONTACT PASS: real input, nine pavement pixels and three real browser screenshots');
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
