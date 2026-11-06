// Real Godot WASM + original FBX; isolated fixture, external network blocked.
const {chromium}=require('playwright'),{spawn}=require('child_process'),fs=require('fs'),assert=require('assert/strict');
const dir=process.argv[2],out=process.argv[3];fs.mkdirSync(out,{recursive:true});
const server=spawn('python3',['-m','http.server','8143','--bind','127.0.0.1'],{cwd:dir,stdio:'ignore'});
(async()=>{const browser=await chromium.launch({executablePath:'/usr/bin/chromium',args:['--no-sandbox','--use-angle=swiftshader','--disable-vulkan']});
try{
 const results=[];
 for(const [width,height,iphone] of [[640,360,true],[844,390,true],[1672,941,false]].filter(([w,h])=>!process.env.QSE_PROBE_SIZE||process.env.QSE_PROBE_SIZE===w+'x'+h)){
  const context=await browser.newContext({viewport:{width,height},deviceScaleFactor:iphone?3:1,hasTouch:iphone,isMobile:iphone,...(iphone?{userAgent:'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Version/18.0 Mobile/15E148 Safari/604.1'}:{})});
  await context.route('**/*',r=>new URL(r.request().url()).hostname==='127.0.0.1'?r.continue():r.abort());
  const page=await context.newPage(),errors=[];
  page.on('console',m=>{if(/SCRIPT ERROR|Parse Error|^ERROR:/.test(m.text()))errors.push(m.text());});page.on('pageerror',e=>errors.push(e.message));
  await page.goto('http://127.0.0.1:8143/quemsoueuv3/?fixture=emotes');
  await page.waitForFunction(()=>window.qseDeckInputReady,null,{timeout:120000});
  const report=async()=>{const n=await page.evaluate(()=>qseDeckInputReport.sequence);await page.evaluate(()=>qseDeckInputProbe());await page.waitForFunction(n=>qseDeckInputReport.sequence>n,n);return page.evaluate(()=>qseDeckInputReport);};
  const tap=async(name)=>{const r=await report(),button=r.controls.find(n=>n.name===name);assert.ok(button,'missing '+name);
   const [x,y,w,h]=button.rect;assert.ok(x>=0&&y>=0&&x+w<=r.size[0]+1&&y+h<=r.size[1]+1,'outside viewport '+name);
   const canvas=await page.locator('#canvas').boundingBox(),px=canvas.x+(x+w/2)*canvas.width/r.size[0],py=canvas.y+(y+h/2)*canvas.height/r.size[1];
   if(iphone)await page.touchscreen.tap(px,py);else await page.mouse.click(px,py);};
  await tap('CosmeticTab_emotes');
  let state;const thumbnailsDeadline=Date.now()+30000;
  do {state=await report();if(state.emote_thumbnails.length===3&&state.emote_thumbnails.every(n=>n.ready))break;await page.waitForTimeout(200);}while(Date.now()<thumbnailsDeadline);
  assert.equal(state.emote_thumbnails.length,3);assert.ok(state.emote_thumbnails.every(n=>n.ready&&n.height>=100),'three visible model thumbnails');
  for(const name of ['EmotePreview_presentation','EmotePreview_celebrate','EmotePreview_disappointed']){
   const control=state.controls.find(n=>n.name===name);assert.ok(control,'missing '+name);
   const [x,y,w,h]=control.rect;assert.ok(x>=0&&y>=0&&x+w<=state.size[0]+1&&y+h<=state.size[1]+1,'outside viewport '+name);
  }
  for(const [id,animation,title,file] of [
   ['presentation','anim_2','No lobby','lobby'],['celebrate','anim_4','Você venceu!','victory'],['disappointed','anim_3','Fim de partida','defeat']]){
   await tap('EmotePreview_'+id);await page.waitForTimeout(150);state=await report();
   assert.equal(state.emote.animation,animation);assert.equal(state.emote.playing,true);assert.ok(state.labels.includes(title));
   await page.screenshot({path:out+'/'+width+'x'+height+'_'+file+'.png',scale:'css'});
  }
  const deadline=Date.now()+20000;while(Date.now()<deadline){state=await report();if(state.emote.static&&!state.emote.playing)break;await page.waitForTimeout(250);}
  assert.ok(state.emote.static&&!state.emote.playing,'must restore pose');
  await tap('CosmeticTab_shop');
  const shopDeadline=Date.now()+30000;
  do {state=await report();if(state.emote_thumbnails.length===1&&state.emote_thumbnails.every(n=>n.ready&&n.height>=100))break;await page.waitForTimeout(200);}while(Date.now()<shopDeadline);
  assert.equal(state.emote_thumbnails.length,1);assert.ok(state.emote_thumbnails[0].ready,'dance thumbnail');
  assert.ok(!state.controls.some(n=>n.name==='EmotePreview_celebrate'),'reactions are separate');
  const record=!!process.env.QSE_RECORD_DANCE;
  if(record)await page.evaluate(()=>{
   const stream=document.getElementById('canvas').captureStream(12),chunks=[];
   const recorder=new MediaRecorder(stream,{mimeType:'video/webm;codecs=vp9'});
   window.qseDanceVideo=new Promise(resolve=>{recorder.ondataavailable=e=>chunks.push(e.data);recorder.onstop=()=>{
    const reader=new FileReader();reader.onload=()=>{stream.getTracks().forEach(t=>t.stop());resolve(reader.result.split(',')[1]);};
    reader.readAsDataURL(new Blob(chunks,{type:'video/webm'}));};});
   recorder.start();setTimeout(()=>recorder.stop(),4500);
  });
  await tap('PreviewDanceMovement');await page.waitForTimeout(350);state=await report();
  assert.equal(state.emote.animation,'dance_preview');assert.equal(state.emote.playing,true);
  await page.screenshot({path:out+'/'+width+'x'+height+'_shop.png',scale:'css'});
  if(record){const video=await page.evaluate(()=>window.qseDanceVideo);fs.writeFileSync(out+'/dance-preview.webm',Buffer.from(video,'base64'));}
  await tap('BuyEmotePreview');await page.waitForTimeout(200);state=await report();
  assert.ok(state.controls.some(n=>n.name==='CloseEmotePurchase'));assert.ok(state.labels.some(n=>n.includes('100 moedas')));
  await page.screenshot({path:out+'/'+width+'x'+height+'_purchase.png',scale:'css'});
  await tap('ConfirmEmotePurchase');
  const purchaseDeadline=Date.now()+10000;
  do{state=await report();if(state.shop?.owned&&state.wallet_coins==='150')break;await page.waitForTimeout(100);}while(Date.now()<purchaseDeadline);
  assert.equal(state.shop.owned,true);assert.equal(state.wallet_coins,'150');
  await page.screenshot({path:out+'/'+width+'x'+height+'_purchased.png',scale:'css'});
  await tap('CloseEmotePurchase');await page.waitForTimeout(150);state=await report();
  assert.ok(!state.controls.some(n=>n.name==='CloseEmotePurchase'));assert.deepEqual(errors,[]);
  results.push({width,height,iphone,reactions:['lobby','victory','defeat'],dancePreview:true,purchasePrice:100,purchaseConfirmed:true,controlsVisible:true,realThumbnails:4,errors});
  fs.writeFileSync(out+'/results.json',JSON.stringify(results,null,2));
  await context.close();console.log('EMOTE_WEB_PASS '+width+'x'+height);
 }
}finally{await browser.close();server.kill();}})().catch(e=>{console.error(e);server.kill();process.exit(1);});
