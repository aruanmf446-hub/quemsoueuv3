// T20: navegação rápida na tela de músicas até aparecer "null function" (backend por fixture).
const {chromium}=require('playwright');const fs=require('fs');
const url=process.argv[2],out=process.argv[3],size=(process.argv[4]||'844x390').split('x').map(Number),secs=Number(process.argv[5]||300);
(async()=>{
 const browser=await chromium.launch({headless:true,args:['--no-sandbox','--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader','--autoplay-policy=no-user-gesture-required']});
 const page=await browser.newPage({viewport:{width:size[0],height:size[1]}});
 const R={url,steps:0,errors:[],crash:null,log:[]};
 page.on('pageerror',e=>{const m={message:e.message,stack:String(e.stack||'').slice(0,6000)};R.errors.push(m);if(/null function|signature mismatch|unreachable|RuntimeError/.test(e.message)&&!R.crash)R.crash=Object.assign(m,{step:R.steps,last:R.log.slice(-25)})});
 page.on('console',m=>{const t=m.text();if(m.type()==='error'&&!/503/.test(t))R.errors.push({console:t.slice(0,400)})});
 await page.addInitScript(()=>{if(!localStorage.getItem('qse-v3:game:refresh'))localStorage.setItem('qse-v3:game:refresh','t20-fixture-only')});
 await page.route(/https:\/\/[^/]+\.supabase\.co\//,async r=>{const u=r.request().url();let d={},s=200;
  if(u.includes('/auth/v1/token'))d={access_token:'t20-fixture-only',refresh_token:'t20-rot',expires_in:3600,user:{id:'00000000-0000-4000-8000-000000000020'}};
  else if(u.includes('/auth/v1/settings'))d={external:{google:true,discord:true}};
  else if(u.includes('qse_profile_self'))d={user_id:'00000000-0000-4000-8000-000000000020',public_id:'T20',nickname:'Teste',equipped_character_id:'cowboy',level:null,experience:null,statistics:{},discoverable:false};
  else{s=503;d={message:'fixture'}}
  await r.fulfill({status:s,contentType:'application/json',headers:{'Access-Control-Allow-Origin':'*'},body:JSON.stringify(d)})});
 try{
  await page.goto(url+'?t19probe=1',{waitUntil:'domcontentloaded'});
  await page.waitForFunction(()=>window.QSE_PERF?.authenticated&&QSE_PERF.route==='',{},{timeout:120000});
  const hooked=await page.evaluate(()=>typeof window.qse_t20==='function');R.hooked=hooked;
  await page.mouse.click(size[0]/2,size[1]/2);
  const cmds=['open:music','preview:0','preview:1','preview:2','preview:1','next','prev','pause','resume','back','open:settings','back','open:music','preview:3','preview:4','preview:0','next','next','prev','back'];
  const end=Date.now()+secs*1000;let i=0;
  while(Date.now()<end&&!R.crash){
   const c=Math.random()<0.7?cmds[i%cmds.length]:cmds[Math.floor(Math.random()*cmds.length)];i++;
   R.log.push(c);if(R.log.length>200)R.log.shift();
   if(hooked){try{await page.evaluate(c=>window.qse_t20(c),c)}catch(e){R.errors.push({evaluate:String(e).slice(0,300)})}}
   else{await page.keyboard.press(['F7','F8'][i%2])}
   R.steps++;await page.waitForTimeout(Math.random()<0.5?40:350);
  }
 }catch(e){R.failure=String(e)}
 fs.writeFileSync(out+'.json',JSON.stringify(R,null,1));console.log(JSON.stringify({hooked:R.hooked,steps:R.steps,crash:R.crash&&R.crash.message,errors:R.errors.length}));await browser.close();
})();
