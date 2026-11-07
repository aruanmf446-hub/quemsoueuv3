const {chromium}=require('playwright'),fs=require('fs'),assert=require('assert'),path=require('path'),{execFileSync}=require('child_process');
const requested=(process.env.QSE_CITIZEN_PHASES||"").split(",").filter(Boolean).map(Number);
const out=process.env.QSE_CITIZEN_OUT||'/tmp/qse-citizen-web';fs.mkdirSync(out,{recursive:true});
(async()=>{
 const browser=await chromium.launch({executablePath:'/usr/bin/chromium',headless:true,args:['--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader']});
 const errors=[],blocked=[],checks=[];
 const resume=process.env.QSE_CITIZEN_RESUME==='1';
 try{
  for(const spec of (resume?[{width:844,height:390,mobile:true,orders:[5,1,2,10]}]:[{width:844,height:390,mobile:true,orders:[5,1,2,10]},{width:640,height:360,mobile:true,orders:[1]},{width:1672,height:941,mobile:false,orders:[1]},{width:1920,height:1080,mobile:false,orders:[1]}])){
   const options={viewport:{width:spec.width,height:spec.height},deviceScaleFactor:spec.mobile?3:1,serviceWorkers:'block'};
   if(spec.mobile)Object.assign(options,{isMobile:true,hasTouch:true,userAgent:'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Version/18.0 Mobile/15E148 Safari/604.1'});
   const context=await browser.newContext(options);
   await context.route('**/*',r=>{if(['localhost','127.0.0.1'].includes(new URL(r.request().url()).hostname))return r.continue();blocked.push(r.request().url());return r.abort();});
   const page=await context.newPage();page.setDefaultTimeout(180000);
   page.on('pageerror',e=>errors.push(String(e)));page.on('console',m=>{const s=m.text();fs.appendFileSync(out+'/console.log',s+'\n');if(/SCRIPT ERROR:|Parse Error:|^ERROR:/.test(s))errors.push(s);});
   const state=()=>page.evaluate(()=>{window.qseCitizenProbe('state');return window.qseCitizenState;});
   const wait=async fn=>{const end=Date.now()+180000;while(Date.now()<end){const s=await state();if(fn(s))return s;if(errors.length)throw Error(errors.join('\n'));await page.waitForTimeout(80);}throw Error('NPC timeout: '+JSON.stringify(await state()));};
   await page.goto('http://127.0.0.1:8135/quemsoueuv3/',{waitUntil:'domcontentloaded'});await page.waitForFunction(()=>!!window.qseCitizenProbe);
   for(const order of spec.orders.filter(n=>!requested.length||requested.includes(n))){
    const checkpoint=resume?{1:0,2:6,5:3,10:6}[order]:-1;
    if(resume)await page.evaluate(([n,cp])=>window.qseCitizenProbe('resume:'+n+':'+cp),[order,checkpoint]);
    else if((await state()).order!==order)await page.evaluate(n=>window.qseCitizenProbe('phase:'+n),order);
    const tick=(await state()).tick;
    let s=await wait(s=>s.order===order&&s.active&&!s.paused&&s.tick>=tick+60);
    const visible=s.citizens.filter(n=>n.frustum&&n.visible&&n.screen.every(v=>v>=0&&v<=1));
    assert(visible.some(n=>n.species==='human')&&visible.some(n=>n.species==='cactus'),'Entry lacks people or cactus: '+JSON.stringify(s));
    assert(Math.abs(s.x-(resume?s.start_x:-8))<0.1,'Entry screenshot moved the player');
    await page.screenshot({path:out+'/'+(resume?'resume_'+checkpoint+'_':'')+'phase_'+order+'_'+spec.width+'x'+spec.height+'.jpg',type:'jpeg',quality:94,scale:'css'});
    // Conferência de pixels: esconder só este Sprite3D deve mudar corpo e pés.
    // A pausa é apenas fotográfica: não altera câmera, posição ou fila do cenário.
    if(spec.width===844&&[2,5].includes(order)){
     await page.evaluate(()=>window.qseCitizenProbe('photo-freeze'));
     for(const npc of visible.filter(n=>Math.abs(n.x-s.x)<8).slice(0,2)){
      const prefix=out+'/'+(resume?'resume_'+checkpoint+'_':'')+'phase_'+order+'_'+npc.species;
      await page.evaluate(id=>window.qseCitizenProbe('hide:'+id),npc.id);
      let photoTick=(await state()).tick;await wait(s=>s.tick>photoTick+8);
      await page.screenshot({path:prefix+'_hidden.png',scale:'css'});
      await page.evaluate(id=>window.qseCitizenProbe('show:'+id),npc.id);
      photoTick=(await state()).tick;await wait(s=>s.tick>photoTick+8);
      await page.screenshot({path:prefix+'_visible.png',scale:'css'});
      const canvas=await page.locator('canvas').boundingBox();
      const rect=[canvas.x+canvas.width*npc.rect[0],canvas.y+canvas.height*npc.rect[1],canvas.x+canvas.width*npc.rect[2],canvas.y+canvas.height*npc.rect[3]];
      const pixels=JSON.parse(execFileSync('python3',[path.join(__dirname,'pixels.py'),prefix+'_hidden.png',prefix+'_visible.png',JSON.stringify(rect)],{encoding:'utf8'}));
      console.log('PASS NPC_PIXELS',order,npc.species,JSON.stringify(pixels));
     }
     await page.evaluate(()=>window.qseCitizenProbe('photo-resume'));
    }
    const before=s.citizens.filter(n=>Math.abs(n.x-s.x)<8).map(n=>({species:n.species,x:n.x,y:n.y,z:n.z}));
    if(order===1){
     const target=s.x+1.6;await page.keyboard.down('d');s=await wait(s=>s.x>target);await page.keyboard.up('d');
     const now=s.citizens.filter(n=>Math.abs(n.x-s.start_x)<8);
     assert(before.every(n=>now.some(m=>m.species===n.species&&Math.abs(m.x-n.x)<0.001&&Math.abs(m.z-n.z)<0.001)),'Citizens move along with the runner');
    }
    checks.push({order,checkpoint,viewport:options.viewport,dpr:options.deviceScaleFactor,visible:visible.length,species:[...new Set(visible.map(n=>n.species))],normal_physics:s.active,forced_queue:false,teleport:false});
    console.log('PASS NPC_WEB',order,spec.width+'x'+spec.height,visible.length);
   }
   await context.close();
  }
  assert(!errors.length&&!blocked.length,'Browser errors or external requests');
  fs.writeFileSync(out+'/report.json',JSON.stringify({passed:true,checks,errors,blocked,gpu:'SwiftShader',physical_device:false},null,2));console.log('NPC_WEB PASS');
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
