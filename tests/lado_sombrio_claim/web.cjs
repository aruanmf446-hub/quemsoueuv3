const {chromium}=require('playwright'),{spawn}=require('child_process'),fs=require('fs'),assert=require('assert/strict');
const site=process.argv[2],out=process.argv[3];fs.mkdirSync(out,{recursive:true});fs.writeFileSync(out+'/console.log','');const server=spawn('python3',['-m','http.server','8180','--bind','127.0.0.1'],{cwd:site,stdio:'ignore'});
(async()=>{const browser=await chromium.launch({executablePath:'/usr/bin/chromium',args:['--no-sandbox','--use-angle=swiftshader','--disable-vulkan']});try{const results=[];
for(const [width,height] of [[1672,941],[844,390],[640,360]]){
 const iphone=width!==1672,ctx=await browser.newContext({viewport:{width,height},deviceScaleFactor:iphone?3:1,isMobile:iphone,hasTouch:iphone,...(iphone?{userAgent:'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Version/18.0 Mobile/15E148 Safari/604.1'}:{})});
 await ctx.route('**/*',r=>new URL(r.request().url()).hostname==='127.0.0.1'?r.continue():r.abort());const page=await ctx.newPage(),errors=[];
 page.on('console',m=>{fs.appendFileSync(out+'/console.log',m.text()+'\n');if(/SCRIPT ERROR|Parse Error|^ERROR:/.test(m.text()))errors.push(m.text());});page.on('pageerror',e=>errors.push(e.message));
 await page.goto('http://127.0.0.1:8180/quemsoueuv3/?fixture=manual_claim');await page.waitForFunction(()=>window.qseDeckInputReady,null,{timeout:120000});
 const report=async(action)=>{const n=await page.evaluate(()=>qseDeckInputReport.sequence);await page.evaluate(a=>a?qseDeckInputProbe(a):qseDeckInputProbe(),action);await page.waitForFunction(n=>qseDeckInputReport.sequence>n,n);return page.evaluate(()=>qseDeckInputReport);};
 const show=async(screen)=>{await report('i18n_screen:'+screen);await page.waitForTimeout(350);return report();};
 const tap=async(name)=>{const s=await report(),b=s.controls.find(b=>b.name===name);assert.ok(b,name);const[x,y,w,h]=b.rect;assert.ok(x>=0&&y>=0&&x+w<=s.size[0]+1&&y+h<=s.size[1]+1,'outside '+name);const c=await page.locator('#canvas').boundingBox(),px=c.x+(x+w/2)*c.width/s.size[0],py=c.y+(y+h/2)*c.height/s.size[1];if(iphone)await page.touchscreen.tap(px,py);else await page.mouse.click(px,py);await page.waitForTimeout(400);};
 let s=await report();assert.equal(s.pending_rewards,1);assert.equal(s.lado_access,false);assert.equal(s.local_lado,false);assert.ok(s.labels.includes('+1'));await page.screenshot({path:out+'/'+width+'_pending.png',scale:'css'});
 await tap('HeroNews');s=await report();assert.ok(s.controls.some(b=>b.name==='Claim_deck_lado_sombrio'));assert.ok(!s.controls.some(b=>b.name==='RedeemGiftBundle'));await page.screenshot({path:out+'/'+width+'_news.png',scale:'css'});
 await tap('CloseNews');s=await report();assert.equal(s.pending_rewards,1);assert.ok(s.labels.includes('+1'));
 s=await show('originals_gallery');assert.ok(!s.controls.some(b=>b.name==='Deck_lado_sombrio'));assert.ok(!s.labels.includes('QSE Originals'));
 s=await show('originals');assert.equal(s.lado_access,false);assert.ok(!s.controls.some(b=>b.name.startsWith('Card_')));
 await show('lobby');await tap('HeroNews');await report('claim_fail');await tap('Claim_deck_lado_sombrio');s=await report();assert.equal(s.lado_access,false);assert.equal(s.pending_rewards,1);
 await report('claim_success');await tap('Claim_deck_lado_sombrio');s=await report();assert.equal(s.lado_access,true);assert.equal(s.pending_rewards,0);assert.equal(s.local_lado,true);
 await tap('CloseNews');s=await report();assert.ok(!s.labels.includes('+1'));await page.screenshot({path:out+'/'+width+'_redeemed.png',scale:'css'});
 s=await show('originals');assert.ok(s.labels.includes('QSE Originals'));assert.equal(s.controls.filter(c=>c.name.startsWith('Card_')).length,10);await page.screenshot({path:out+'/'+width+'_library.png',scale:'css'});
 s=await report('claim_refresh');assert.equal(s.lado_access,true);assert.equal(s.pending_rewards,0);
 s=await report('claim_other_account');assert.equal(s.lado_access,false);assert.equal(s.local_lado,false);assert.equal(s.pending_rewards,1);assert.ok(!s.controls.some(b=>b.name.startsWith('Card_')),'reader must close on account change');
 assert.deepEqual(errors,[]);results.push({width,height,iphoneUA:iphone,pendingPersists:true,failedClaimBlocked:true,explicitClaimUnlocks:true,accountIsolated:true,cardsAfterClaim:10,errors});fs.writeFileSync(out+'/results.json',JSON.stringify(results,null,2));console.log('MANUAL_CLAIM_WEB_PASS',width,height);await ctx.close();
}
}finally{await browser.close();server.kill();}})().catch(e=>{console.error(e);server.kill();process.exit(1);});
