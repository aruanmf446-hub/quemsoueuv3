/* Real Chromium service workers. Engine payload is explicitly synthetic here;
   separately validate the settings button with a real Godot Web export. */
const {chromium}=require('playwright'),http=require('http'),fs=require('fs'),path=require('path'),assert=require('assert/strict'),{execFileSync}=require('child_process');
const root=path.resolve(__dirname,'../..'),dir=process.argv[2]||'/tmp/qse-update-test',out=process.argv[3]||dir+'/evidence',prefix='/quemsoueuv3/',game=prefix+'jogar/';
fs.mkdirSync(dir,{recursive:true});fs.mkdirSync(out,{recursive:true});fs.cpSync(path.join(root,'web/site'),dir+'/quemsoueuv3',{recursive:true});
const assemble=build=>execFileSync('python3',['tests/web_pwa/assemble.py',dir+game,build],{cwd:root});
let hold=false,stale=null,held=[],requests=[];const send=(res,body,type='application/octet-stream')=>{res.writeHead(200,{'Content-Type':type,'Cache-Control':'public,max-age=86400'});res.end(body);};
const server=http.createServer((req,res)=>{let url=new URL(req.url,'http://localhost');requests.push(url.pathname+url.search);let file=path.resolve(dir,'.'+url.pathname);if(!file.startsWith(path.resolve(dir)+path.sep)){res.writeHead(403);return res.end();}if(url.pathname.endsWith('/'))file+='/index.html';if(!fs.existsSync(file)){res.writeHead(404);return res.end();}const type=file.endsWith('.js')?'text/javascript':file.endsWith('.html')?'text/html':file.endsWith('.json')?'application/json':file.endsWith('.css')?'text/css':'application/octet-stream';const body=stale&&url.pathname===game+'index.html'?stale:fs.readFileSync(file);if(hold&&url.pathname===game+'index.pck'){held.push(()=>{
 res.writeHead(200,{'Content-Type':type,'Content-Length':body.length});
 let offset=0;const timer=setInterval(()=>{const end=Math.min(offset+256,body.length);res.write(body.subarray(offset,end));offset=end;if(offset===body.length){clearInterval(timer);res.end();}},40);
 res.on('close',()=>clearInterval(timer));
});return;}send(res,body,type);});
let checks=0;function check(ok,msg){assert.ok(ok,msg);checks++;console.log('PASS',msg);}
(async()=>{assemble('update-a');await new Promise(r=>server.listen(8176,'127.0.0.1',r));const browser=await chromium.launch({executablePath:'/usr/bin/chromium',args:['--no-sandbox']});try{
const ctx=await browser.newContext(),page=await ctx.newPage(),base='http://localhost:8176';await page.clock.install();await page.goto(base+game);await page.waitForFunction(()=>navigator.serviceWorker.controller&&window.qseUpdates?.getState().current==='update-a',null,{timeout:20000});
await page.evaluate(async()=>{localStorage.setItem('test-session','preserved');await new Promise((resolve,reject)=>{const req=indexedDB.open('qse-test-saves',1);req.onupgradeneeded=()=>req.result.createObjectStore('saves');req.onerror=()=>reject(req.error);req.onsuccess=()=>{const tx=req.result.transaction('saves','readwrite');tx.objectStore('saves').put('saved-deck','deck');tx.oncomplete=()=>{req.result.close();resolve();};};});});
const wasmCount=()=>requests.filter(x=>x.startsWith(game+'index.wasm?')).length;const initialWasm=wasmCount();
await page.clock.runFor(100);
const markerCount=requests.filter(x=>x.startsWith(game+'version.json?')).length;
hold=true;assemble('update-b');await page.clock.fastForward(300000);
check(requests.filter(x=>x.startsWith(game+'version.json?')).length===markerCount,'five minutes idle causes no periodic version requests');
await page.evaluate(()=>window.dispatchEvent(new Event('focus')));await page.waitForFunction(()=>window.qseUpdates.getState().latest==='update-b'&&window.qseUpdates.getState().status==='downloading',null,{timeout:20000});
for(let i=0;i<200&&!held.length;i++)await new Promise(r=>setTimeout(r,20));
check(await page.evaluate(()=>qseUpdates.getState().status==='downloading'&&!qseUpdates.getState().ready),'resume detects new version before package finishes');check(await page.evaluate(()=>qseBuild==='update-a'),'old engine version remains active during download');
await page.evaluate(()=>{qseSafeToUpdate=true;qseUpdates.open();});
await page.waitForFunction(()=>qseUpdates.getState().progress?.total>0);
check(await page.evaluate(()=>{const s=qseUpdates.getState(),bar=document.getElementById('qse-update-progress');return bar.value===s.progress.completed&&bar.max===s.progress.total;}),'loading uses actual completed files, not a fabricated percentage');
for(const [width,height] of [[1672,941],[844,390],[640,360]]){
 await page.setViewportSize({width,height});
 const box=await page.locator('#qse-update-panel').boundingBox();
 check(box&&box.x===0&&box.y===0&&Math.abs(box.width-width)<2&&Math.abs(box.height-height)<2,'full-screen update fits '+width+'x'+height);
 check(await page.locator('#qse-update-close').isVisible(),'can leave loading safely '+width+'x'+height);
 await page.screenshot({path:out+'/'+width+'x'+height+'_loading.png'});
}
await page.click('#qse-update-close');
check(await page.locator('#qse-update-panel').isHidden(),'background download does not force closed loading screen open');
await page.evaluate(()=>qseUpdates.open());await page.clock.runFor(180001);
check(await page.evaluate(()=>qseUpdates.getState().status==='stalled'),'stalled transfer has a recovery state instead of indefinite loading');
check(await page.locator('#qse-update-check').isEnabled(),'retry available after stalled download');
await page.evaluate(()=>qseUpdates.check());
await page.waitForFunction(()=>qseUpdates.getState().status==='downloading');
const bytesBefore=await page.evaluate(()=>qseUpdates.getState().progress.loadedBytes);
hold=false;held.splice(0).forEach(fn=>fn());
await page.waitForFunction(before=>{const p=qseUpdates.getState().progress;return p.loadedBytes>before&&p.completed<p.total;},bytesBefore,{timeout:20000});
check(true,'streamed bytes advance while the package is still downloading');
await page.waitForFunction(()=>qseUpdates.getState().ready,null,{timeout:20000});
await page.evaluate(async()=>{qseSafeToUpdate=true;const pending=qseUpdates.apply();qseSafeToUpdate=false;await pending;});
check(await page.evaluate(async()=>qseUpdates.getState().status==='unsafe'&&!!(await navigator.serviceWorker.getRegistration()).waiting),'entering match during async check cancels activation');
await page.evaluate(()=>{qseSafeToUpdate=false;qseUpdates.open();});await page.waitForFunction(()=>qseUpdates.getState().status==='ready');await page.evaluate(()=>qseUpdates.apply());check(await page.evaluate(()=>qseBuild==='update-a'&&qseUpdates.getState().status==='unsafe'),'unsafe match cannot restart');
await page.evaluate(()=>{qseSafeToUpdate=true;qseStoryPlaying=true;return qseUpdates.apply();});check(await page.evaluate(()=>qseBuild==='update-a'&&qseUpdates.getState().status==='unsafe'),'campaign also prevents restart');
await page.evaluate(()=>{qseStoryPlaying=false;return qseUpdates.check();});await page.clock.runFor(800);await Promise.all([page.waitForNavigation(),page.click('#qse-update-apply')]);await page.waitForFunction(()=>window.qseBuild==='update-b');
check(wasmCount()===initialWasm,'unchanged engine reused by content hash');check(await page.evaluate(()=>localStorage.getItem('test-session')==='preserved'),'session storage preserved');
await ctx.setOffline(true);await page.evaluate(()=>qseUpdates.check());check(await page.evaluate(()=>qseUpdates.getState().status==='offline'&&qseBuild==='update-b'),'offline check preserves running version');await ctx.setOffline(false);
assemble('update-c');await page.clock.runFor(3100);await page.evaluate(()=>window.dispatchEvent(new Event('focus')));await page.waitForFunction(()=>qseUpdates.getState().latest==='update-c'&&qseUpdates.getState().ready,null,{timeout:20000});check(await page.evaluate(()=>qseBuild==='update-b'),'focus detects new version without automatic restart');
const recovery=await ctx.newPage();await recovery.goto(base+prefix+'atualizar/');await recovery.waitForFunction(()=>window.qseUpdates);check(await recovery.evaluate(()=>typeof Engine==='undefined'),'external updater does not start Godot');await recovery.click('#qse-update-check');await recovery.waitForFunction(()=>qseUpdates.getState().ready,null,{timeout:20000});await recovery.click('#qse-update-apply');await recovery.waitForFunction(()=>qseUpdates.getState().status==='close-game');check(await page.evaluate(()=>qseBuild==='update-b'),'external updater blocks activation while game tab is open');
await page.close();await recovery.waitForFunction(()=>qseUpdates.getState().current==='update-c',null,{timeout:20000});await Promise.all([recovery.waitForNavigation(),recovery.click('#qse-update-apply')]);await recovery.waitForFunction(()=>qseBuild==='update-c');check(true,'external updater enters latest build after closing old game');
const preserved=await recovery.evaluate(async()=>{const value=await new Promise(resolve=>{const req=indexedDB.open('qse-test-saves',1);req.onsuccess=()=>{const tx=req.result.transaction('saves');const get=tx.objectStore('saves').get('deck');get.onsuccess=()=>resolve(get.result);tx.oncomplete=()=>req.result.close();};});return value==='saved-deck'&&localStorage.getItem('test-session')==='preserved';});check(preserved,'IndexedDB decks/progress and login survive recovery');
stale=fs.readFileSync(dir+game+'index.html');assemble('update-d');await recovery.evaluate(()=>qseUpdates.check());await recovery.waitForFunction(()=>qseUpdates.getState().status==='error',null,{timeout:20000});check(await recovery.evaluate(()=>qseBuild==='update-c'&&!qseUpdates.getState().ready),'stale CDN HTML rejected without replacing current build');stale=null;
await recovery.evaluate(()=>qseUpdates.check());await recovery.waitForFunction(()=>qseUpdates.getState().ready,null,{timeout:20000});await recovery.evaluate(()=>{qseSafeToUpdate=true;qseUpdates.open();});await recovery.waitForFunction(()=>qseUpdates.getState().status==='ready');await Promise.all([recovery.waitForNavigation(),recovery.click('#qse-update-apply')]);await recovery.waitForFunction(()=>qseBuild==='update-d');check(true,'retry installs consistent version after stale response clears');
await recovery.close();const view=await ctx.newPage();for(const [w,h] of [[1672,941],[844,390],[640,360],[390,844]]){await view.setViewportSize({width:w,height:h});await view.goto(base+prefix+'atualizar/');await view.waitForFunction(()=>window.qseUpdates);await view.click('#qse-update-check');await view.waitForFunction(()=>qseUpdates.getState().status==='current',null,{timeout:20000});check(await view.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),'external page fits '+w+'x'+h);const button=await view.locator('#qse-update-check').boundingBox();check(button.y>=0&&button.y+button.height<=h,'check button visible without scrolling '+w+'x'+h);await view.screenshot({path:out+'/'+w+'x'+h+'_external.png',fullPage:true});}await view.close();
check(requests.some(x=>x.startsWith(game+'version.json?qse_check=')),'version marker bypasses stale worker and HTTP cache');check(requests.some(x=>x.startsWith(game+'sw.js?build=update-c')),'worker URL changes once per published build');check((await ctx.serviceWorkers()).length>=1,'worker remains registered');fs.writeFileSync(out+'/results.json',JSON.stringify({checks,failures:0,versions:['update-a','update-b','update-c','update-d']},null,2));console.log('UPDATE_TEST checks='+checks+' failures=0');
}finally{await browser.close();server.close();}})().catch(e=>{console.error(e);server.close();process.exitCode=1;});
