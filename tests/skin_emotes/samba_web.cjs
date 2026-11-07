// Real Godot Web UI and approved Samba resources; synthetic account, no production purchases.
const {chromium}=require('playwright'),{spawn}=require('child_process'),fs=require('fs'),assert=require('assert/strict');
const dir=process.argv[2],out=process.argv[3];fs.mkdirSync(out,{recursive:true});
const server=spawn('python3',['-m','http.server','8155','--bind','127.0.0.1'],{cwd:dir,stdio:'ignore'});
(async()=>{const browser=await chromium.launch({executablePath:'/usr/bin/chromium',args:['--no-sandbox','--use-angle=swiftshader','--disable-vulkan']});
try{const results=[];
 for(const [width,height,iphone] of [[1672,941,false],[844,390,true],[640,360,true]]){
  const context=await browser.newContext({viewport:{width,height},deviceScaleFactor:iphone?3:1,hasTouch:iphone,isMobile:iphone,...(iphone?{userAgent:'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Version/18.0 Mobile/15E148 Safari/604.1'}:{})});
  await context.route('**/*',r=>new URL(r.request().url()).hostname==='127.0.0.1'?r.continue():r.abort());
  const page=await context.newPage(),errors=[];
  page.on('console',m=>{if(/SCRIPT ERROR|Parse Error|^ERROR:/.test(m.text())){errors.push(m.text());console.error(m.text());}});page.on('pageerror',e=>errors.push(e.message));
  await page.goto('http://127.0.0.1:8155/quemsoueuv3/?fixture=samba');
  await page.waitForFunction(()=>window.qseDeckInputReady,null,{timeout:120000});
  const report=async()=>{const n=await page.evaluate(()=>qseDeckInputReport.sequence);await page.evaluate(()=>qseDeckInputProbe());await page.waitForFunction(n=>qseDeckInputReport.sequence>n,n);return page.evaluate(()=>qseDeckInputReport);};
  const tap=async(name)=>{const state=await report(),c=state.controls.find(c=>c.name===name);assert.ok(c,'missing '+name);
   const [x,y,w,h]=c.rect;assert.ok(x>=0&&y>=0&&x+w<=state.size[0]+1&&y+h<=state.size[1]+1,'outside '+name);
   const canvas=await page.locator('#canvas').boundingBox(),px=canvas.x+(x+w/2)*canvas.width/state.size[0],py=canvas.y+(y+h/2)*canvas.height/state.size[1];
   if(iphone)await page.touchscreen.tap(px,py);else await page.mouse.click(px,py);};
  for(const id of ['cowboy','el_fuego','halloween']){
   await page.evaluate(id=>qseDeckInputProbe('variation_character:'+id),id);
   let state;const deadline=Date.now()+20000;
   do{state=await report();if(state.emote_thumbnails.some(t=>t.name==='EmoteThumbnail_samba'&&t.ready))break;await page.waitForTimeout(100);}while(Date.now()<deadline);
   assert.ok(state.emote_thumbnails.some(t=>t.name==='EmoteThumbnail_samba'&&t.ready));
   assert.ok(state.labels.includes('Samba'));assert.ok(state.labels.includes('Preço a definir'));
   const buy=state.controls.find(c=>c.name==='BuyEmotePreview');assert.equal(buy.text,'PREÇO A DEFINIR');assert.equal(buy.disabled,true);
   assert.ok(!state.labels.some(s=>s.includes('100 moedas')));assert.equal(state.emote_purchases,0);
   await tap('PreviewDanceMovement');state=await report();
   assert.equal(state.emote.animation,'emote_samba');assert.equal(state.emote.playing,true);
   await page.screenshot({path:out+'/'+width+'x'+height+'_'+id+'.png',scale:'css'});
   await tap('BuyEmotePreview');state=await report();
   assert.ok(!state.controls.some(c=>c.name==='ConfirmEmotePurchase'));assert.equal(state.emote_purchases,0);
   results.push({width,height,iphone,character:id,realSambaPreview:true,pricePending:true,purchases:0,errors:[...errors]});
   console.log('SAMBA_SHOP_WEB_PASS '+width+'x'+height+' '+id);
  }
  assert.deepEqual(errors,[]);fs.writeFileSync(out+'/results.json',JSON.stringify(results,null,2));await context.close();
 }
}finally{await browser.close();server.kill();}})().catch(e=>{console.error(e);server.kill();process.exit(1);});
