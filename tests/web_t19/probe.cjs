// Real browser UI input. All backend traffic is mocked; never use a real account/token here.
const {chromium}=require('playwright');const fs=require('fs');
const url=process.argv[2],output=process.argv[3],size=(process.argv[4]||'844x390').split('x').map(Number),soak=Number(process.argv[5]||0);
(async()=>{
 const browser=await chromium.launch({executablePath:process.env.CHROMIUM||'/usr/bin/chromium',headless:true,args:['--no-sandbox','--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader']});
 const page=await browser.newPage({viewport:{width:size[0],height:size[1]},hasTouch:size[0]<1000});page.setDefaultTimeout(15000);
 const result={viewport:size,backend:'intercepted fixture, not live OAuth',softwareGPU:true,cycles:[],errors:[],audioRequests:0};
 page.on('console',m=>{if(m.type()==='error')result.errors.push(m.text().replace(/(?:Bearer\s+|eyJ)[\w.\-]+/g,'[redacted]'))});page.on('pageerror',e=>result.errors.push(e.message));
 await page.addInitScript(()=>{if(!localStorage.getItem('qse-v3:game:refresh'))localStorage.setItem('qse-v3:game:refresh','t19-fixture-only');window.QSE_PUBLIC_CONFIG={};window.t19frames=[];window.t19tasks=[];let last=0;function frame(now){if(last&&now-last>50)t19frames.push(now-last);last=now;requestAnimationFrame(frame)}requestAnimationFrame(frame);new PerformanceObserver(list=>{for(const t of list.getEntries())t19tasks.push({at:t.startTime,ms:t.duration})}).observe({type:'longtask',buffered:true});});
 await page.route(/https:\/\/[^/]+\.supabase\.co\//,async route=>{
  const u=route.request().url();let data={};let status=200;
  if(u.includes('/auth/v1/token'))data={access_token:'t19-fixture-only',refresh_token:'t19-rotated-fixture-only',expires_in:3600,user:{id:'00000000-0000-4000-8000-000000000019'}};
  else if(u.includes('/auth/v1/settings'))data={external:{google:true,discord:true}};
  else if(u.includes('qse_profile_self'))data={user_id:'00000000-0000-4000-8000-000000000019',public_id:'T19_FIXTURE',nickname:'Teste local',equipped_character_id:'cowboy',level:null,experience:null,statistics:{},discoverable:false};
  else {status=503;data={message:'isolated backend fixture'}}
  await route.fulfill({status,contentType:'application/json',headers:{'Access-Control-Allow-Origin':'*'},body:JSON.stringify(data)});
 });
 await page.route(/\/music\/.*\.mp3/,async route=>{result.audioRequests++;await new Promise(r=>setTimeout(r,900));await route.continue()});
 const snap=()=>page.evaluate(()=>window.QSE_PERF);
 const click=async key=>{const s=await snap();let r=s.widgets[key];if(!r?.w&&key==='settings')r={x:size[0]<760?510:(size[0]<1000?604:805),y:size[0]<1000?94:44,w:100};if(!r?.w)throw Error('Widget unavailable '+key);if(size[0]<1000)await page.touchscreen.tap(r.x,r.y);else await page.mouse.click(r.x,r.y);};
 try{
  await page.goto(url+'?t19probe=1',{waitUntil:'domcontentloaded'});
  await page.waitForFunction(()=>window.QSE_PERF?.authenticated&&QSE_PERF.route==='',{},{timeout:60000});result.initial=await snap();
  for(let i=0;i<20;i++){
   const start=Date.now();await click('settings');await page.waitForFunction(()=>QSE_PERF.route==='settings'&&!QSE_PERF.busy);
   const opened=Date.now();for(const n of [1,2,3,0]){await click('tab'+n);await page.waitForTimeout(30)}
   await click('back');await page.waitForFunction(()=>QSE_PERF.route===''&&!QSE_PERF.busy);
   if(i%4===0)await page.keyboard.press('F8');if(i===10||i===12)await page.keyboard.press('F7');
   result.cycles.push({index:i,open_ms:opened-start,roundtrip_ms:Date.now()-start,state:await snap()});
   fs.writeFileSync(output+'.progress.json',JSON.stringify(result));console.log('cycle',i,opened-start);
  }
  console.log("await_audio");await page.waitForFunction(()=>QSE_PERF.audio_playing,{},{timeout:90000});result.audioConfirmed=true;result.audioState=await snap();
  result.preReloadBrowser=await page.evaluate(()=>({longFrames:t19frames,longTasks:t19tasks,heap:performance.memory?{used:performance.memory.usedJSHeapSize,total:performance.memory.totalJSHeapSize}:null}));
  await page.reload({waitUntil:'domcontentloaded'});await page.waitForFunction(()=>window.QSE_PERF?.authenticated&&QSE_PERF.route==='',{},{timeout:60000});result.reloadAuthenticated=true;
  if(soak){const soakStart=Date.now();const end=soakStart+soak*1000;while(Date.now()<end){await page.waitForTimeout(15000);console.log("soak_remaining_s",Math.round((end-Date.now())/1000));await click('settings');await page.waitForFunction(()=>QSE_PERF.route==='settings'&&!QSE_PERF.busy);await click('tab2');await click('back');await page.waitForFunction(()=>QSE_PERF.route===''&&!QSE_PERF.busy)}result.soakSeconds=(Date.now()-soakStart)/1000}
  result.final=await snap();await click('settings');await page.waitForFunction(()=>QSE_PERF.route==='settings'&&!QSE_PERF.busy);await page.screenshot({path:output+'.png'});result.ok=true;
 }catch(e){result.failure=String(e);result.ok=false;try{result.final=await snap();await page.screenshot({path:output+'.png',timeout:3000})}catch{}}
 try{result.browser=await page.evaluate(()=>({longFrames:t19frames,longTasks:t19tasks,heap:performance.memory?{used:performance.memory.usedJSHeapSize,total:performance.memory.totalJSHeapSize}:null}));}catch{}
 fs.writeFileSync(output+'.json',JSON.stringify(result,null,2));await browser.close();process.exitCode=result.ok?0:1;
})();
