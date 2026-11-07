const {chromium}=require('playwright'),fs=require('fs'),assert=require('assert');
const out=process.env.QSE_CONTROL_OUT||'/tmp/qse-control-web';fs.mkdirSync(out,{recursive:true});
(async()=>{
 const browser=await chromium.launch({executablePath:'/usr/bin/chromium',headless:true,args:['--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader']});
 const errors=[],blocked=[];let page;
 try{
  const context=await browser.newContext({viewport:{width:844,height:390},deviceScaleFactor:3,isMobile:true,hasTouch:true,serviceWorkers:'block',userAgent:'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Version/18.0 Mobile/15E148 Safari/604.1'});
  await context.route('**/*',r=>{if(['localhost','127.0.0.1'].includes(new URL(r.request().url()).hostname))return r.continue();blocked.push(r.request().url());return r.abort();});
  page=await context.newPage();page.setDefaultTimeout(180000);
  page.on('pageerror',e=>errors.push(String(e)));page.on('console',m=>{const s=m.text();fs.appendFileSync(out+'/console.log',s+'\n');if(/SCRIPT ERROR:|Parse Error:|^ERROR:/.test(s))errors.push(s);});
  const probe=cmd=>Promise.race([page.evaluate(c=>{window.qseControlProbe(c);return window.qseControlState;},cmd),new Promise((_,reject)=>setTimeout(()=>reject(Error('Probe blocked: '+cmd)),30000))]);
  const wait=async test=>{const end=Date.now()+180000;while(Date.now()<end){const s=await probe('state');if(test(s))return s;await page.waitForTimeout(60);}throw Error('State timeout: '+JSON.stringify(await probe('state')));};
  async function tap(point){const b=await page.locator('canvas').boundingBox();await page.touchscreen.tap(b.x+b.width*point[0],b.y+b.height*point[1]);}
  async function choose(index,mode){
   const s=await probe('state');await tap(s.option);await wait(s=>s.popup);
   let current=await probe('state');
   if(current.focused<0){await page.keyboard.press('ArrowDown');current=await wait(s=>s.focused>=0);}
   while(current.focused!==index){const target=current.focused+(current.focused<index?1:-1);await page.keyboard.press(current.focused<index?'ArrowDown':'ArrowUp');current=await wait(s=>s.focused===target);}
   await page.keyboard.press('Enter');await wait(s=>s.mode===mode&&!s.popup);
  }
  async function settings(){console.log('Opening pause');await page.keyboard.press('Escape');let s=await wait(s=>s.paused);console.log('Pause open',JSON.stringify(s.menu));await tap(s.menu['Configurações']);await wait(s=>Array.isArray(s.option));console.log('Pause controls open');}
  async function resume(){let s=await probe('state');await tap(s.menu['Voltar à pausa']);s=await wait(s=>!!s.menu['Continuar']);await tap(s.menu['Continuar']);await wait(s=>!s.paused);}
  await page.goto('http://127.0.0.1:8135/quemsoueuv3/',{waitUntil:'domcontentloaded'});await page.waitForFunction(()=>typeof window.qseControlProbe==='function');
  await choose(2,'keyboard');await page.screenshot({path:out+'/01_configuracoes_teclado.jpg',type:'jpeg',quality:94,scale:'css'});
  await probe('play');let s=await wait(s=>s.play&&s.actor.floor);assert(!s.touch,'Keyboard mode still shows joystick');
  const x=s.actor.x;await page.keyboard.down('d');await wait(s=>s.actor.x>x+0.3);await page.keyboard.up('d');
  await page.screenshot({path:out+'/02_somente_teclado.jpg',type:'jpeg',quality:94,scale:'css'});console.log('Keyboard mode selected by real UI and moves by key');
  await settings();await choose(3,'mixed');console.log('Mixed selected');await resume();console.log('Resumed mixed');s=await probe('state');assert(s.touch,'Mixed mode lacks buttons');
  const cdp=await context.newCDPSession(page);const b=await page.locator('canvas').boundingBox();
  const stick=s.stick;const start={x:b.x+b.width*stick[0],y:b.y+b.height*stick[1],id:1};const right={...start,x:start.x+b.width*stick[2]*0.55};
  await page.keyboard.down('d');await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[start]});await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[right]});
  await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});s=await probe('state');let at=s.actor.x;await wait(s=>s.actor.x>at+0.2);await page.keyboard.up('d');
  await cdp.send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[start]});await cdp.send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[right]});await page.keyboard.down('d');await page.keyboard.up('d');
  s=await probe('state');at=s.actor.x;await wait(s=>s.actor.x>at+0.2);await cdp.send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});
  console.log('Mixed source ownership: releasing touch preserves key; releasing key preserves joystick');
  await settings();await choose(1,'touch');await page.screenshot({path:out+'/03_controles_na_pausa.jpg',type:'jpeg',quality:94,scale:'css'});await resume();
  s=await probe('state');const shots=s.actor.attack,tick=s.tick;await page.keyboard.down('j');await wait(s=>s.tick>tick+4);await page.keyboard.up('j');s=await probe('state');assert(s.actor.attack===shots,'Touch-only responds to keyboard attack');
  await tap(s.defend_button);s=await wait(s=>s.actor.defending);assert(s.actor.defense===2,'Touch defense failed');
  await page.screenshot({path:out+'/04_somente_toque.jpg',type:'jpeg',quality:94,scale:'css'});
  await page.reload({waitUntil:'domcontentloaded'});await page.waitForFunction(()=>typeof window.qseControlProbe==='function');const restored=await probe('state');assert(restored.mode==='touch'&&restored.preference==='touch','Mode lost after browser reload');
  await probe('play');await wait(s=>s.play&&s.touch);console.log('Touch-only ignores keys, executes button, and survives reload');
  for(const size of [{width:640,height:360},{width:1672,height:941}]){
   await probe('settings');await page.setViewportSize(size);await wait(s=>Array.isArray(s.option));await page.screenshot({path:out+'/settings_'+size.width+'x'+size.height+'.jpg',type:'jpeg',quality:94,scale:'css'});
  }
  assert(!errors.length&&!blocked.length,'Browser error or external request');
  fs.writeFileSync(out+'/report.json',JSON.stringify({passed:true,real_dropdown:true,real_keyboard:true,real_touch:true,paused_switch:true,mixed_both_release_orders:true,reload:true,sizes:['844x390','640x360','1672x941'],physical_device:false,gpu:'SwiftShader',errors,blocked},null,2));
  console.log('CONTROL_MODES_WEB PASS');
 }catch(e){if(page){fs.writeFileSync(out+'/failure.json',JSON.stringify(await page.evaluate(()=>window.qseControlState).catch(()=>null),null,2));await page.screenshot({path:out+'/failure.jpg',type:'jpeg',scale:'css',timeout:10000}).catch(()=>{});}throw e;}
 finally{await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
