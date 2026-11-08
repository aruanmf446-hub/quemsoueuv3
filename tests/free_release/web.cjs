const {chromium}=require('playwright'),{spawn}=require('child_process'),fs=require('fs'),assert=require('assert/strict');
const site=process.argv[2],out=process.argv[3];fs.mkdirSync(out,{recursive:true});const server=spawn('python3',['-m','http.server','8174','--bind','127.0.0.1'],{cwd:site,stdio:'ignore'});
(async()=>{const browser=await chromium.launch({executablePath:'/usr/bin/chromium',args:['--no-sandbox','--use-angle=swiftshader','--disable-vulkan']});try{
 const results=[];
 for(const [width,height] of [[1672,941],[844,390],[640,360]]){
  const mobile=width!==1672,ctx=await browser.newContext({viewport:{width,height},deviceScaleFactor:mobile?3:1,isMobile:mobile,hasTouch:mobile,...(mobile?{userAgent:'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Version/18.0 Mobile/15E148 Safari/604.1'}:{})});
  await ctx.route('**/*',r=>new URL(r.request().url()).hostname==='127.0.0.1'?r.continue():r.abort());const page=await ctx.newPage(),errors=[];page.on('console',m=>{fs.appendFileSync(out+'/console.log',m.text()+'\n');if(/SCRIPT ERROR|Parse Error|^ERROR:/.test(m.text()))errors.push(m.text());});page.on('pageerror',e=>errors.push(e.message));
  await page.goto('http://127.0.0.1:8174/quemsoueuv3/?fixture=commerce_entrypoints');await page.waitForFunction(()=>window.qseDeckInputReady,null,{timeout:120000});
  const report=async(action)=>{const n=await page.evaluate(()=>qseDeckInputReport.sequence);await page.evaluate(a=>a?qseDeckInputProbe('i18n_screen:'+a):qseDeckInputProbe(),action);await page.waitForFunction(n=>qseDeckInputReport.sequence>n,n,{timeout:120000});return page.evaluate(()=>qseDeckInputReport);};
  let s=await report();assert.ok(!s.controls.some(x=>['HeroCoins','HeroEmotes'].includes(x.name)),'lobby shortcuts hidden');await page.screenshot({path:out+'/'+width+'_lobby.png',scale:'css'});
  await report('commerce_emotes');await page.waitForTimeout(1200);s=await report();
  const hidden=c=>/^(CosmeticTab_|SkinVariation_|EmotePreview_)/.test(c.name)||['VariationPurchase','PreviewDanceMovement','BuyEmotePreview','BuySkin'].includes(c.name);
  assert.ok(!s.controls.some(hidden),'old shop route cannot reveal extras');assert.ok(s.controls.some(c=>c.name==='SkinEquipButton'),'original equip button retained');
  const first=s.variations.character,b=s.controls.find(c=>c.name==='NextSkinCharacter'),box=await page.locator('#canvas').boundingBox();assert.ok(b);const [x,y,w,h]=b.rect,px=box.x+(x+w/2)*box.width/s.size[0],py=box.y+(y+h/2)*box.height/s.size[1];
  if(mobile)await page.touchscreen.tap(px,py);else await page.mouse.click(px,py);await page.waitForTimeout(600);s=await report();assert.notEqual(s.variations.character,first,'character navigation still works');assert.ok(!s.controls.some(hidden));await page.screenshot({path:out+'/'+width+'_skins.png',scale:'css'});
  await report('editor');await page.waitForTimeout(300);s=await report();assert.ok(s.controls.some(c=>c.name==='DeckName'),'deck editor available');assert.ok(!s.controls.some(c=>c.text==='Cartas'||/comprar/i.test(c.text)),'no creation-credit shop link');assert.ok(!s.labels.some(t=>t.startsWith('Cartas de criação:')),'no paid-credit messaging');assert.ok(!s.checkout_calls&&!s.emote_purchases);await page.screenshot({path:out+'/'+width+'_deck.png',scale:'css'});assert.deepEqual(errors,[]);
  results.push({width,height,mobile,hiddenCommerce:true,hiddenCosmeticExtras:true,characterNavigation:true,deckEditorAvailable:true,checkoutCalls:s.checkout_calls||0,errors});fs.writeFileSync(out+'/results.json',JSON.stringify(results,null,2));console.log('FREE_RELEASE_WEB_PASS',width,height);await ctx.close();
 }
}finally{await browser.close();server.kill();}})().catch(e=>{console.error(e);server.kill();process.exit(1);});
