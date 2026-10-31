// T20: reprodução do congelamento com cliques RÁPIDOS (sem esperar busy), como o usuário.
// Backend interceptado por fixture (sem conta real). Mede quando um clique deixa de ter efeito.
const {chromium}=require('playwright');const fs=require('fs');
const url=process.argv[2],out=process.argv[3],size=(process.argv[4]||'844x390').split('x').map(Number);
const cycles=Number(process.argv[5]||20),idle=Number(process.argv[6]||0),trace=process.argv[7]==='trace';
(async()=>{
 const browser=await chromium.launch({headless:true,args:['--no-sandbox','--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader','--autoplay-policy=no-user-gesture-required','--enable-precise-memory-info']});
 const page=await browser.newPage({viewport:{width:size[0],height:size[1]},hasTouch:size[0]<1000});
 const R={url,viewport:size,cycles:[],stuck:[],errors:[],heap:[],requests:{}};
 page.on('console',m=>{if(m.type()==='error')R.errors.push(m.text().slice(0,300).replace(/(?:Bearer\s+|eyJ)[\w.\-]+/g,'[redacted]'))});
 page.on('pageerror',e=>R.errors.push('PAGEERROR '+e.message));
 page.on('crash',()=>R.errors.push('PAGE CRASH'));
 page.on('request',q=>{const k=q.url().replace(/\?.*/,'').replace(/^https:\/\/[^/]+/,'');R.requests[k]=(R.requests[k]||0)+1});
 await page.addInitScript(()=>{if(!localStorage.getItem('qse-v3:game:refresh'))localStorage.setItem('qse-v3:game:refresh','t20-fixture-only');
  window.t20={gaps:[],tasks:[]};let last=0;const f=n=>{if(last&&n-last>100)t20.gaps.push({at:Math.round(n),ms:Math.round(n-last)});last=n;requestAnimationFrame(f)};requestAnimationFrame(f);
  new PerformanceObserver(l=>{for(const t of l.getEntries())t20.tasks.push({at:Math.round(t.startTime),ms:Math.round(t.duration)})}).observe({type:'longtask',buffered:true});});
 await page.route(/https:\/\/[^/]+\.supabase\.co\//,async route=>{
  const u=route.request().url();let data={},status=200;
  if(u.includes('/auth/v1/token'))data={access_token:'t20-fixture-only',refresh_token:'t20-rotated-fixture-only',expires_in:3600,user:{id:'00000000-0000-4000-8000-000000000020'}};
  else if(u.includes('/auth/v1/settings'))data={external:{google:true,discord:true}};
  else if(u.includes('qse_profile_self'))data={user_id:'00000000-0000-4000-8000-000000000020',public_id:'T20_FIXTURE',nickname:'Teste',equipped_character_id:'cowboy',level:null,experience:null,statistics:{},discoverable:false};
  else{status=503;data={message:'fixture'}}
  await route.fulfill({status,contentType:'application/json',headers:{'Access-Control-Allow-Origin':'*'},body:JSON.stringify(data)});
 });
 const snap=()=>page.evaluate(()=>window.QSE_PERF||null);
 const at=async key=>{const s=await snap();let r=s&&s.widgets&&s.widgets[key];if(!r||!r.w)return false;if(size[0]<1000)await page.touchscreen.tap(r.x,r.y);else await page.mouse.click(r.x,r.y);return true};
 const until=async(fn,ms)=>{const t=Date.now();while(Date.now()-t<ms){const s=await snap();if(s&&fn(s))return Date.now()-t;await page.waitForTimeout(40)}return -1};
 const sampleHeap=async label=>{try{R.heap.push(Object.assign({label,t:Date.now()},await page.evaluate(()=>({used:performance.memory.usedJSHeapSize,total:performance.memory.totalJSHeapSize}))))}catch{}};
 async function cycle(tag,i){
  const c={tag,i};const t0=Date.now();
  if(!await at('settings')){c.fail='settings_widget_missing';c.state=await snap();R.stuck.push(c);return c}
  c.open_ms=await until(s=>s.route==='settings',5000);
  if(c.open_ms<0){c.fail='settings_did_not_open';c.state=await snap();R.stuck.push(c);await page.keyboard.press('Escape');return c}
  for(const n of [1,2,3,0]){if(!await at('tab'+n))c.tab_missing=(c.tab_missing||0)+1;await page.waitForTimeout(60)}
  const s=await snap();c.category=s.category;
  if(!await at('back')){c.fail='back_missing';c.state=s;R.stuck.push(c);return c}
  c.back_ms=await until(s=>s.route===''&&!s.busy,5000);
  if(c.back_ms<0){c.fail='did_not_return';c.state=await snap();R.stuck.push(c)}
  c.total_ms=Date.now()-t0;return c}
 try{
  if(trace)await browser.startTracing(page,{path:out+'.trace.json',screenshots:false,categories:['devtools.timeline','v8.execute','disabled-by-default-devtools.timeline','blink.user_timing']});
  await page.goto(url+'?t19probe=1',{waitUntil:'domcontentloaded'});
  R.boot_ms=await until(s=>s.authenticated&&s.route==='',90000);await sampleHeap('boot');
  for(let i=0;i<cycles;i++){R.cycles.push(await cycle('fast',i));fs.writeFileSync(out+'.json',JSON.stringify(R,null,1))}
  await sampleHeap('after_fast');
  if(trace){await browser.stopTracing()}
  R.audio=await until(s=>s.audio_playing,60000);
  if(idle){const end=Date.now()+idle*1000;while(Date.now()<end){await page.waitForTimeout(30000);await sampleHeap('idle');R.idleProbe=(R.idleProbe||[]);const s=await snap();R.idleProbe.push({t:Date.now(),route:s&&s.route,busy:s&&s.busy,worst:s&&s.worst_frame_ms,audio:s&&s.audio_playing,nodes:s&&s.nodes});fs.writeFileSync(out+'.json',JSON.stringify(R,null,1))}
   for(let i=0;i<cycles;i++){R.cycles.push(await cycle('after_idle',i));fs.writeFileSync(out+'.json',JSON.stringify(R,null,1))}}
  R.final=await snap();await page.screenshot({path:out+'.png'});
 }catch(e){R.failure=String(e);try{await page.screenshot({path:out+'.png',timeout:3000})}catch{}}
 try{Object.assign(R,await page.evaluate(()=>({gaps:t20.gaps,tasks:t20.tasks})))}catch{}
 R.summary={stuck:R.stuck.length,cycles:R.cycles.length,longest_gap:Math.max(0,...(R.gaps||[]).map(g=>g.ms)),longest_task:Math.max(0,...(R.tasks||[]).map(g=>g.ms)),tasks_over_200:(R.tasks||[]).filter(t=>t.ms>200).length};
 fs.writeFileSync(out+'.json',JSON.stringify(R,null,1));console.log(JSON.stringify(R.summary));await browser.close();
})();
