// Actual Godot WASM; fake accounts/storage, all external requests blocked.
const {chromium}=require('playwright');
const {spawn}=require('child_process'),fs=require('fs'),assert=require('assert/strict');
const dir=process.argv[2],out=process.argv[3];fs.mkdirSync(out,{recursive:true});
const server=spawn('python3',['-m','http.server','8137','--bind','127.0.0.1'],{cwd:dir,stdio:'ignore'});
(async()=>{
 const browser=await chromium.launch({executablePath:'/usr/bin/chromium',args:['--no-sandbox']});
 try{
  const context=await browser.newContext({viewport:{width:844,height:390},deviceScaleFactor:3,hasTouch:true,isMobile:true,userAgent:'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Version/18.0 Mobile/15E148 Safari/604.1'});
  await context.route('**/*',r=>new URL(r.request().url()).hostname==='127.0.0.1'?r.continue():r.abort());
  const page=await context.newPage(),errors=[];
  page.on('console',m=>{if(/SCRIPT ERROR|Parse Error|^ERROR:/.test(m.text()))errors.push(m.text());});
  page.on('pageerror',e=>errors.push(e.message));
  page.setDefaultTimeout(15000);
  await page.goto('http://127.0.0.1:8137/quemsoueuv3/?fixture=status');
  await page.waitForFunction(()=>window.qseDeckInputReady,null,{timeout:120000});
  const report=async()=>{
   const before=await page.evaluate(()=>qseDeckInputReport.sequence);
   await page.evaluate(()=>qseDeckInputProbe());
   await page.waitForFunction(n=>qseDeckInputReport.sequence>n,before);
   return page.evaluate(()=>qseDeckInputReport);
  };
  const until=async(predicate,label)=>{
   const end=Date.now()+25000;let last;
   while(Date.now()<end){last=await report();if(predicate(last))return last;await page.waitForTimeout(250);}
   fs.writeFileSync(out+'/failure.json',JSON.stringify(last,null,2));
   await page.screenshot({path:out+'/failure.png',scale:'css'});
   throw new Error('Timed out waiting for '+label);
  };
  const tap=async(name)=>{
   await page.evaluate(n=>qseDeckInputProbe('focus:'+n),name);await page.waitForTimeout(250);
   const r=await report(),b=r.controls.find(c=>c.name===name);assert.ok(b,'missing '+name);
   const c=await page.locator('#canvas').boundingBox(),[x,y,w,h]=b.rect;
   await page.touchscreen.tap(c.x+(x+w/2)*c.width/r.size[0],c.y+(y+h/2)*c.height/r.size[1]);
   await page.waitForTimeout(300);
  };
  const results={errors};
  results.rejected=await report();
  assert.ok(results.rejected.labels.includes('Reprovado · precisa de ajustes'));
  assert.ok(results.rejected.labels.some(t=>t.includes('As imagens não correspondem aos artistas de rap')));
  await page.screenshot({path:out+'/rejected.png',scale:'css'});
  await tap('SubmissionAction');
  let r=await report();assert.ok(r.controls.some(c=>c.name==='DeckName'));
  assert.ok(r.labels.some(t=>t.includes('As imagens não correspondem')));
  await tap('DeckName');await page.locator('input.qse-typing').fill('[TESTE] Rappers corrigido no celular');
  await page.evaluate(()=>document.activeElement.blur());
  await tap('ReviewDeck');await page.waitForTimeout(700);
  r=await until(r=>r.controls.some(c=>c.name==='PublishDeck'),'review page');
  await tap('PublishDeck');await until(r=>r.labels.some(t=>t.includes('Em revisão pela moderação')),'resubmission confirmation');
  await tap('TrackDeckSubmission');
  results.pending=await until(r=>r.labels.includes('Em revisão'),'pending status');assert.ok(results.pending.labels.includes('Em revisão'));
  await page.screenshot({path:out+'/pending.png',scale:'css'});
  await page.evaluate(()=>qseDeckInputProbe('approve_fixture'));await page.waitForTimeout(250);
  await tap('RefreshDeckStatuses');
  results.approved=await until(r=>r.labels.includes('Aprovado · publicado'),'approved status');assert.ok(results.approved.labels.includes('Aprovado · publicado'));
  assert.ok(!results.approved.labels.includes('Motivo da reprovação'));
  await page.screenshot({path:out+'/approved.png',scale:'css'});
  assert.deepEqual(errors,[]);
  fs.writeFileSync(out+'/results.json',JSON.stringify(results,null,2));
  console.log('DECK_SUBMISSION_STATUS_WEB_PASS reject / edit / resend / pending / approve / refresh, errors=0');
 }finally{await browser.close();server.kill();}
})().catch(e=>{console.error(e);server.kill();process.exit(1);});
