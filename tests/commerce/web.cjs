// Real Godot Web renderer; transport fixtures only. Production has no simulated commerce.
const {chromium}=require('playwright'),{spawn}=require('child_process'),fs=require('fs'),assert=require('assert/strict');
const dir=process.argv[2],out=process.argv[3];fs.mkdirSync(out,{recursive:true});
const server=spawn('python3',['-m','http.server','8157','--bind','127.0.0.1'],{cwd:dir,stdio:'ignore'});
(async()=>{const browser=await chromium.launch({executablePath:'/usr/bin/chromium',args:['--no-sandbox','--use-angle=swiftshader','--disable-vulkan']});
try{const results=[];
 for(const [width,height,iphone] of [[1672,941,false],[844,390,true],[640,360,true]]){
  const context=await browser.newContext({viewport:{width,height},deviceScaleFactor:iphone?3:1,hasTouch:iphone,isMobile:iphone,...(iphone?{userAgent:'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Version/18.0 Mobile/15E148 Safari/604.1'}:{})});
  await context.route('**/*',r=>new URL(r.request().url()).hostname==='127.0.0.1'?r.continue():r.abort());
  for(const mode of ['commerce','commerce_skins']){
   const page=await context.newPage(),errors=[];page.on('console',m=>{if(/SCRIPT ERROR|Parse Error|^ERROR:/.test(m.text()))errors.push(m.text());});page.on('pageerror',e=>errors.push(e.message));
   await page.goto('http://127.0.0.1:8157/quemsoueuv3/?fixture='+mode);
   await page.waitForFunction(()=>window.qseDeckInputReady,null,{timeout:120000});
   const report=async(action='')=>{const n=await page.evaluate(()=>qseDeckInputReport.sequence);await page.evaluate(a=>qseDeckInputProbe(a),action);await page.waitForFunction(n=>qseDeckInputReport.sequence>n,n);return page.evaluate(()=>qseDeckInputReport);};
   const tap=async(name)=>{const s=await report(),b=s.controls.find(b=>b.name===name);assert.ok(b,name);const[x,y,w,h]=b.rect;assert.ok(x>=0&&y>=0&&x+w<=s.size[0]+1&&y+h<=s.size[1]+1,'outside '+name);const c=await page.locator('#canvas').boundingBox(),px=c.x+(x+w/2)*c.width/s.size[0],py=c.y+(y+h/2)*c.height/s.size[1];if(iphone)await page.touchscreen.tap(px,py);else await page.mouse.click(px,py);};
   let s=await report();
   if(mode==='commerce'){
    for(const id of ['coins_100','coins_250','coins_400','deck_credit'])assert.equal(s.controls.find(b=>b.name==='CoinPack_'+id)?.disabled,true);
    assert.ok(s.labels.some(l=>l.includes('Vendas desabilitadas')));assert.ok(s.labels.includes('Créditos de deck: 0'));assert.equal(s.checkout_calls,0);
   }else{
    const end=Date.now()+30000;do{s=await report();if(s.emote_thumbnails.some(t=>t.name==='EmoteThumbnail_samba'&&t.ready))break;await page.waitForTimeout(100);}while(Date.now()<end);
    assert.ok(s.labels.includes('50 moedas'));assert.equal(s.controls.find(b=>b.name==='BuyEmotePreview').disabled,true);
    await tap('PreviewDanceMovement');s=await report();assert.equal(s.emote.animation,'emote_samba');assert.equal(s.emote.playing,true);
   }
   await page.screenshot({path:out+'/'+width+'x'+height+'_'+mode+'.png',scale:'css'});
   if(mode==='commerce_skins'){
    await tap('CosmeticTab_skins');await tap('SkinVariation_style_1');s=await report();
    const b=s.controls.find(b=>b.name==='VariationPurchase');assert.equal(b.disabled,true);assert.match(b.text,/100.*EM BREVE/);
    await page.screenshot({path:out+'/'+width+'x'+height+'_variation.png',scale:'css'});
   }
   assert.deepEqual(errors,[]);results.push({width,height,mode,disabledRealPurchases:true,errors});fs.writeFileSync(out+'/results.json',JSON.stringify(results,null,2));console.log('COMMERCE_WEB_PASS '+width+'x'+height+' '+mode);await page.close();
  }await context.close();
 }
}finally{await browser.close();server.kill();}})().catch(e=>{console.error(e);server.kill();process.exit(1);});
