// Actual Godot Web export; local fixtures and no external network calls.
const {chromium}=require('playwright'),{spawn}=require('child_process'),fs=require('fs'),assert=require('assert/strict');
const dir=process.argv[2],out=process.argv[3];fs.mkdirSync(out,{recursive:true});
const server=spawn('python3',['-m','http.server','8138','--bind','127.0.0.1'],{cwd:dir,stdio:'ignore'});
(async()=>{const browser=await chromium.launch({executablePath:'/usr/bin/chromium',args:['--no-sandbox']});
try{
 const context=await browser.newContext({viewport:{width:844,height:390},deviceScaleFactor:3,hasTouch:true,isMobile:true,userAgent:'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Version/18.0 Mobile/15E148 Safari/604.1'});
 await context.route('**/*',r=>new URL(r.request().url()).hostname==='127.0.0.1'?r.continue():r.abort());
 const page=await context.newPage(),errors=[];
 page.on('console',m=>{if(/SCRIPT ERROR|Parse Error|^ERROR:/.test(m.text()))errors.push(m.text());});page.on('pageerror',e=>errors.push(e.message));
 await page.goto('http://127.0.0.1:8138/quemsoueuv3/?fixture=community');
 await page.waitForFunction(()=>window.qseDeckInputReady,null,{timeout:120000});
 const report=async()=>{const n=await page.evaluate(()=>qseDeckInputReport.sequence);await page.evaluate(()=>qseDeckInputProbe());await page.waitForFunction(n=>qseDeckInputReport.sequence>n,n);return page.evaluate(()=>qseDeckInputReport);};
 const initial=await report(),field=initial.controls.find(n=>n.name==='DeckSearch');
 const canvas=await page.locator('#canvas').boundingBox(),[sx,sy,sw,sh]=field.rect;
 await page.touchscreen.tap(canvas.x+(sx+sw/2)*canvas.width/initial.size[0],canvas.y+(sy+sh/2)*canvas.height/initial.size[1]);
 const search=page.locator('input.qse-typing').last();
 await search.fill('USUARIO X');await search.blur();
 let r;const until=Date.now()+25000;
 while(Date.now()<until){r=await report();if(r.labels.includes('Criado por Usuário X'))break;await page.waitForTimeout(250);}
 assert.ok(r.labels.includes('Criado por Usuário X'));assert.ok(r.labels.includes('[TESTE] Rappers'));
 const id='Deck_11111111-2222-4333-8444-555555555555';
 await page.evaluate(n=>qseDeckInputProbe('focus:'+n),id);await page.waitForTimeout(250);
 r=await report();
 await page.screenshot({path:out+'/search.png',scale:'css'});
 const c=await page.locator('#canvas').boundingBox(),[x,y,w,h]=r.controls.find(n=>n.name===id).rect;
 await page.touchscreen.tap(c.x+(x+w/2)*c.width/r.size[0],c.y+(y+h/2)*c.height/r.size[1]);
 const limit=Date.now()+25000;
 while(Date.now()<limit){r=await report();if(r.controls.some(n=>n.name==='ReportDeck'))break;await page.waitForTimeout(250);}
 assert.ok(r.controls.some(n=>n.name==='ReportDeck'));assert.ok(r.labels.includes('Criado por Usuário X'));
 await page.screenshot({path:out+'/detail.png',scale:'css'});
 assert.deepEqual(errors,[]);fs.writeFileSync(out+'/results.json',JSON.stringify({errors,credit:'Criado por Usuário X',search:'USUARIO X',viewport:[844,390],dpr:3},null,2));
 console.log('COMMUNITY_ATTRIBUTION_WEB_PASS nickname search beyond first page / credit in result and detail / errors=0');
}finally{await browser.close();server.kill();}})().catch(e=>{console.error(e);server.kill();process.exit(1);});
