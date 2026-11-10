const {chromium}=require('playwright'),{spawn}=require('child_process'),fs=require('fs'),assert=require('assert/strict');
const site=process.argv[2],out=process.argv[3];fs.mkdirSync(out,{recursive:true});
const server=spawn('python3',['-m','http.server','8221','--bind','127.0.0.1'],{cwd:site,stdio:'ignore'});
(async()=>{const browser=await chromium.launch({executablePath:'/usr/bin/chromium',args:['--no-sandbox','--use-angle=swiftshader','--disable-vulkan']});let results=[];
try{for(const[width,height]of[[1672,941],[1920,1080],[844,390],[640,360]].filter(([w])=>!process.argv[4]||w===Number(process.argv[4]))){
const mobile=width<=844,ctx=await browser.newContext({viewport:{width,height},deviceScaleFactor:mobile?3:1,isMobile:mobile,hasTouch:mobile,...mobile?{userAgent:'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Version/18.0 Mobile/15E148 Safari/604.1'}:{}});
let errors=[],blocked=[];await ctx.route('**/*',route=>{if(new URL(route.request().url()).hostname==='127.0.0.1')return route.continue();blocked.push(new URL(route.request().url()).hostname);return route.abort();});
let page=await ctx.newPage();page.on('console',m=>{fs.appendFileSync(out+'/console.log',m.text()+'\n');if(/SCRIPT ERROR|Parse Error|^ERROR:/.test(m.text()))errors.push(m.text());});
page.on('pageerror',e=>{if(!/Failed to fetch/.test(e.message))errors.push(e.message);});
await page.goto('http://127.0.0.1:8221/quemsoueuv3/');await page.waitForFunction(()=>window.bossReady,null,{timeout:180000});await page.waitForTimeout(1500);await page.evaluate(()=>bossProbe("solo"));
const report=await page.evaluate(()=>bossReport);assert.equal(report.phase,10);assert.ok(Math.abs(report.camera[1]-5.7)<0.01,"final framing");assert.equal(report.files,5);assert.deepEqual(report.charges,[3,3]);assert.equal(report.visible_saws,1);assert.equal(report.solid_saws,1);
await page.screenshot({path:out+'/'+width+'_arena.png',scale:'css',timeout:90000});assert.deepEqual(errors,[]);
await page.evaluate(()=>bossProbe('handoff'));await page.waitForTimeout(300);
const handoff=await page.evaluate(()=>bossReport);assert.equal(handoff.visible_saws,2);assert.equal(handoff.solid_saws,2);
await page.screenshot({path:out+'/'+width+'_handoff.png',scale:'css',timeout:90000});assert.deepEqual(errors,[]);
await page.evaluate(()=>bossProbe('phase3'));await page.waitForFunction(()=>{bossProbe();return bossReport.cacti>0;},null,{timeout:60000,polling:1000});
await page.waitForTimeout(1000);await page.screenshot({path:out+'/'+width+'_phase3.png',scale:'css',timeout:90000});assert.deepEqual(errors,[]);
results.push({width,height,mobile,report,handoff,errors,blocked});fs.writeFileSync(out+'/results.json',JSON.stringify(results,null,2));console.log('BOSS_WEB_PASS',width,height);await ctx.close();
}}finally{await browser.close();server.kill();}})().catch(e=>{console.error(e);server.kill();process.exit(1);});
