// Godot WASM fixtures; local transport only. No Supabase calls.
const {chromium}=require('playwright'),{spawn}=require('child_process'),fs=require('fs'),assert=require('assert/strict');
const dir=process.argv[2],out=process.argv[3];fs.mkdirSync(out,{recursive:true});
const server=spawn('python3',['-m','http.server','8141','--bind','127.0.0.1'],{cwd:dir,stdio:'ignore'});
(async()=>{const browser=await chromium.launch({executablePath:'/usr/bin/chromium',args:['--no-sandbox','--use-angle=swiftshader','--disable-vulkan']});
try{
 const results=[];
 for(const [width,height,iphone] of [[1672,941,false],[844,390,true],[640,360,true]].filter(([w,h])=>!process.env.QSE_PROBE_SIZE||process.env.QSE_PROBE_SIZE===w+'x'+h)){
  const context=await browser.newContext({viewport:{width,height},deviceScaleFactor:iphone?3:1,hasTouch:iphone,isMobile:iphone,...(iphone?{userAgent:'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Version/18.0 Mobile/15E148 Safari/604.1'}:{})});
  await context.route('**/*',r=>new URL(r.request().url()).hostname==='127.0.0.1'?r.continue():r.abort());
  const page=await context.newPage(),errors=[];
  page.on('console',m=>{if(/SCRIPT ERROR|Parse Error|^ERROR:/.test(m.text()))errors.push(m.text());});page.on('pageerror',e=>errors.push(e.message));
  await page.goto('http://127.0.0.1:8141/quemsoueuv3/?fixture=player_report');
  await page.waitForFunction(()=>window.qseDeckInputReady,null,{timeout:120000});
  const report=async()=>{const n=await page.evaluate(()=>qseDeckInputReport.sequence);await page.evaluate(()=>qseDeckInputProbe());await page.waitForFunction(n=>qseDeckInputReport.sequence>n,n);return page.evaluate(()=>qseDeckInputReport);};
  const tap=async(name)=>{const r=await report(),n=r.controls.find(c=>c.name===name);assert.ok(n,'missing '+name);const canvas=await page.locator('#canvas').boundingBox(),[x,y,w,h]=n.rect;const px=canvas.x+(x+w/2)*canvas.width/r.size[0],py=canvas.y+(y+h/2)*canvas.height/r.size[1];assert.ok(py>=canvas.y&&py<=canvas.y+canvas.height);if(iphone)await page.touchscreen.tap(px,py);else await page.mouse.click(px,py);await page.waitForTimeout(250);};
  const waitLabel=async(text)=>{const end=Date.now()+20000;let r;while(Date.now()<end){r=await report();if(r.labels.some(t=>t.includes(text)))return r;await page.waitForTimeout(200);}fs.writeFileSync(out+'/failure.json',JSON.stringify(r,null,2));await page.screenshot({path:out+'/failure.png',scale:'css'});throw new Error('Missing feedback '+text);};
  await tap('PlayerReportReason');
  if(iphone){await page.locator('input.qse-typing').last().fill('Motivo de teste',{timeout:5000});await page.evaluate(()=>document.activeElement.blur());}
  else await page.keyboard.type('Motivo de teste',{delay:50});
  assert.equal((await report()).fields.PlayerReportReason,'Motivo de teste');
  await tap('SubmitPlayerReport');
  const denied=await waitLabel('própria conta');
  assert.equal(denied.fields.PlayerReportReason,'Motivo de teste');
  await page.screenshot({path:out+'/'+width+'x'+height+'_report.png',scale:'css',timeout:20000});
  await page.evaluate(()=>qseDeckInputProbe('report_success'));
  await page.waitForTimeout(200);
  await tap('SubmitPlayerReport');
  const sent=await waitLabel('Denúncia de jogador registrada');
  assert.ok(!sent.controls.some(n=>n.name==='PlayerReportReason'));assert.deepEqual(errors,[]);
  results.push({width,height,iphone,errors,feedback:true,reasonPreserved:true,confirmed:true});
  fs.writeFileSync(out+'/'+width+'x'+height+'_results.json',JSON.stringify(results.at(-1),null,2));
  await context.close();
  console.log('PLAYER_REPORT_WEB_PASS '+width+'x'+height+' input / business-error / text-preserved / success, errors=0');
 }
 fs.writeFileSync(out+'/results.json',JSON.stringify(results,null,2));
}finally{await browser.close();server.kill();}})().catch(e=>{console.error(e);server.kill();process.exit(1);});
