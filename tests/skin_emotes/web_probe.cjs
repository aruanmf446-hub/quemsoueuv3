// Real Godot WASM + original FBX; isolated fixture, external network blocked.
const {chromium}=require('playwright'),{spawn}=require('child_process'),fs=require('fs'),assert=require('assert/strict');
const dir=process.argv[2],out=process.argv[3];fs.mkdirSync(out,{recursive:true});
const server=spawn('python3',['-m','http.server','8143','--bind','127.0.0.1'],{cwd:dir,stdio:'ignore'});
(async()=>{const browser=await chromium.launch({executablePath:'/usr/bin/chromium',args:['--no-sandbox','--use-angle=swiftshader','--disable-vulkan']});
try{
 const results=[];
 for(const [width,height,iphone] of [[640,360,true],[844,390,true],[1672,941,false]]){
  const context=await browser.newContext({viewport:{width,height},deviceScaleFactor:iphone?3:1,hasTouch:iphone,isMobile:iphone,...(iphone?{userAgent:'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Version/18.0 Mobile/15E148 Safari/604.1'}:{})});
  await context.route('**/*',r=>new URL(r.request().url()).hostname==='127.0.0.1'?r.continue():r.abort());
  const page=await context.newPage(),errors=[];
  page.on('console',m=>{if(/SCRIPT ERROR|Parse Error|^ERROR:/.test(m.text()))errors.push(m.text());});page.on('pageerror',e=>errors.push(e.message));
  await page.goto('http://127.0.0.1:8143/quemsoueuv3/?fixture=emotes');
  await page.waitForFunction(()=>window.qseDeckInputReady,null,{timeout:120000});
  const report=async()=>{const n=await page.evaluate(()=>qseDeckInputReport.sequence);await page.evaluate(()=>qseDeckInputProbe());await page.waitForFunction(n=>qseDeckInputReport.sequence>n,n);return page.evaluate(()=>qseDeckInputReport);};
  let state=await report();
  for(const name of ['EmoteChoice','PreviewEmote']){
   const control=state.controls.find(n=>n.name===name);assert.ok(control,'missing '+name);
   const [x,y,w,h]=control.rect;assert.ok(x>=0&&y>=0&&x+w<=state.size[0]+1&&y+h<=state.size[1]+1,'outside viewport '+name);
  }
  const button=state.controls.find(n=>n.name==='PreviewEmote'),canvas=await page.locator('#canvas').boundingBox(),[x,y,w,h]=button.rect;
  const px=canvas.x+(x+w/2)*canvas.width/state.size[0],py=canvas.y+(y+h/2)*canvas.height/state.size[1];
  if(iphone)await page.touchscreen.tap(px,py);else await page.mouse.click(px,py);
  await page.waitForTimeout(150);state=await report();assert.equal(state.emote.animation,'anim_2');assert.equal(state.emote.playing,true);
  await page.screenshot({path:out+'/'+width+'x'+height+'_emotes.png',scale:'css'});
  const deadline=Date.now()+20000;while(Date.now()<deadline){state=await report();if(state.emote.static&&!state.emote.playing)break;await page.waitForTimeout(250);}
  assert.ok(state.emote.static&&!state.emote.playing,'must restore pose');assert.deepEqual(errors,[]);
  results.push({width,height,iphone,emoteStarted:true,poseRestored:true,controlsVisible:true,errors});
  fs.writeFileSync(out+'/results.json',JSON.stringify(results,null,2));
  await context.close();console.log('EMOTE_WEB_PASS '+width+'x'+height);
 }
}finally{await browser.close();server.kill();}})().catch(e=>{console.error(e);server.kill();process.exit(1);});
