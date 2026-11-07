// Real Godot WASM + original FBX; isolated fixture, external network blocked.
const {chromium}=require('playwright'),{spawn}=require('child_process'),fs=require('fs'),assert=require('assert/strict');
const dir=process.argv[2],out=process.argv[3];fs.mkdirSync(out,{recursive:true});
const server=spawn('python3',['-m','http.server','8148','--bind','127.0.0.1'],{cwd:dir,stdio:'ignore'});
(async()=>{const browser=await chromium.launch({executablePath:'/usr/bin/chromium',args:['--no-sandbox','--use-angle=swiftshader','--disable-vulkan']});
try{
 const results=[];
 for(const [width,height,iphone] of [[1672,941,false],[844,390,true],[640,360,true]].filter(([w,h])=>!process.env.QSE_PROBE_SIZE||process.env.QSE_PROBE_SIZE===w+'x'+h)){
  const context=await browser.newContext({viewport:{width,height},deviceScaleFactor:iphone?3:1,hasTouch:iphone,isMobile:iphone,...(iphone?{userAgent:'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Version/18.0 Mobile/15E148 Safari/604.1'}:{})});
  await context.route('**/*',r=>new URL(r.request().url()).hostname==='127.0.0.1'?r.continue():r.abort());
  const page=await context.newPage(),errors=[];
  page.on('console',m=>{if(/SCRIPT ERROR|Parse Error|^ERROR:/.test(m.text())){errors.push(m.text());console.error(m.text());}});page.on('pageerror',e=>errors.push(e.message));
  await page.goto('http://127.0.0.1:8148/quemsoueuv3/?fixture=variations');
  await page.waitForFunction(()=>window.qseDeckInputReady,null,{timeout:120000});
  const report=async()=>{const n=await page.evaluate(()=>qseDeckInputReport.sequence);await page.evaluate(()=>qseDeckInputProbe());await page.waitForFunction(n=>qseDeckInputReport.sequence>n,n);return page.evaluate(()=>qseDeckInputReport);};
  const tap=async(name)=>{const r=await report(),button=r.controls.find(n=>n.name===name);assert.ok(button,'missing '+name);
   const [x,y,w,h]=button.rect;assert.ok(x>=0&&y>=0&&x+w<=r.size[0]+1&&y+h<=r.size[1]+1,'outside viewport '+name);
   const canvas=await page.locator('#canvas').boundingBox(),px=canvas.x+(x+w/2)*canvas.width/r.size[0],py=canvas.y+(y+h/2)*canvas.height/r.size[1];
   if(iphone)await page.touchscreen.tap(px,py);else await page.mouse.click(px,py);};
  const characters=process.env.QSE_CHARACTERS?process.env.QSE_CHARACTERS.split(','):process.env.QSE_CHARACTER?[process.env.QSE_CHARACTER]:iphone?['cowboy','el_fuego','halloween']:['cowboy','el_fuego','halloween','michelly','rodrigo','lorena','gus','lana'];
  for(const id of characters){
   await page.evaluate(id=>qseDeckInputProbe('variation_character:'+id),id);
   let state;const deadline=Date.now()+30000;
   do{state=await report();if(state.variations?.character===id&&state.variations.thumbnails.length===3&&state.variations.thumbnails.every(t=>t.ready))break;await page.waitForTimeout(100);}while(Date.now()<deadline);
   if(!state.variations.thumbnails.every(t=>t.ready)){await page.screenshot({path:out+'/failed-'+id+'.png',scale:'css'});fs.writeFileSync(out+'/failed-'+id+'.json',JSON.stringify(state,null,2));}assert.equal(state.variations.character,id);assert.equal(state.variations.thumbnails.length,3);assert.ok(state.variations.thumbnails.every(t=>t.ready));
   for(const style of ['original','style_1','style_2']){
    await tap('SkinVariation_'+style);await page.waitForTimeout(120);state=await report();assert.equal(state.variations.style,style);assert.ok(!state.controls.some(c=>c.name==='CosmeticTab_variations'));const icon=state.controls.find(c=>c.name==='SkinVariation_'+style);assert.ok(Math.abs(icon.rect[2]-icon.rect[3])<2&&icon.rect[2]<=90,'compact square selector');assert.equal(state.preview_render.static,true);assert.notEqual(state.preview_render.update,4);
    if(!process.env.QSE_FAST_CAPTURE||style==='style_2')await page.screenshot({path:out+'/'+width+'x'+height+'_'+id+'_'+style+'.png',scale:'css'});
   }
   results.push({width,height,iphone,character:id,styles:3,realThumbnails:true,errors:[...errors]});
   console.log('VARIATIONS_WEB_PASS '+width+'x'+height+' '+id);
  }
  await page.evaluate(()=>qseDeckInputProbe('variation_character:cowboy'));const before=(await report()).variations.character;await tap('NextSkinCharacter');assert.notEqual((await report()).variations.character,before);await tap('PreviousSkinCharacter');assert.equal((await report()).variations.character,before);
  if(!process.env.QSE_ONLY_VARIATIONS){await tap('CosmeticTab_shop');await page.waitForTimeout(150);let state=await report();
  assert.ok(state.controls.some(c=>c.name==='PreviewDanceMovement'));assert.ok(!state.controls.some(c=>c.name.startsWith('SkinVariation_')));
  await tap('CosmeticTab_skins');await page.waitForTimeout(150);state=await report();
  assert.ok(!state.controls.some(c=>c.name==='BuyEmotePreview'));assert.deepEqual(errors,[]);}
  assert.deepEqual(errors,[]);
  fs.writeFileSync(out+'/results.json',JSON.stringify(results,null,2));
  await context.close();console.log('EMOTE_WEB_PASS '+width+'x'+height);
 }
}finally{await browser.close();server.kill();}})().catch(e=>{console.error(e);server.kill();process.exit(1);});
