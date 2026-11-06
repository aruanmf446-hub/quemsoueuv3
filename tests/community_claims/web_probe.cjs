// Real exported Godot Web UI; all remote requests blocked, explicit fixtures only.
const {chromium}=require('playwright'),{spawn}=require('child_process'),fs=require('fs'),assert=require('assert/strict');
const dir=process.argv[2],out=process.argv[3];fs.mkdirSync(out,{recursive:true});
const server=spawn('python3',['-m','http.server','8142','--bind','127.0.0.1'],{cwd:dir,stdio:'ignore'});
(async()=>{const browser=await chromium.launch({executablePath:'/usr/bin/chromium',args:['--no-sandbox','--use-angle=swiftshader','--disable-vulkan']});
try{
 for(const [width,height,iphone] of [[1672,941,false],[844,390,true],[640,360,true]]){
  const context=await browser.newContext({viewport:{width,height},deviceScaleFactor:iphone?3:1,hasTouch:iphone,isMobile:iphone,...(iphone?{userAgent:'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Version/18.0 Mobile/15E148 Safari/604.1'}:{})});
  await context.route('**/*',r=>new URL(r.request().url()).hostname==='127.0.0.1'?r.continue():r.abort());
  const page=await context.newPage(),errors=[];
  page.on('console',m=>{if(/SCRIPT ERROR|Parse Error|^ERROR:/.test(m.text()))errors.push(m.text());});page.on('pageerror',e=>errors.push(e.message));
  await page.goto('http://127.0.0.1:8142/quemsoueuv3/?fixture=claim');
  await page.waitForFunction(()=>window.qseDeckInputReady,null,{timeout:120000});
  const report=async()=>{const n=await page.evaluate(()=>qseDeckInputReport.sequence);await page.evaluate(()=>qseDeckInputProbe());await page.waitForFunction(n=>qseDeckInputReport.sequence>n,n);return page.evaluate(()=>qseDeckInputReport);};
  const tap=async(name)=>{const r=await report(),n=r.controls.find(c=>c.name===name);assert.ok(n,'missing '+name);const canvas=await page.locator('#canvas').boundingBox(),[x,y,w,h]=n.rect;const px=canvas.x+(x+w/2)*canvas.width/r.size[0],py=canvas.y+(y+h/2)*canvas.height/r.size[1];assert.ok(px>=canvas.x&&px<=canvas.x+canvas.width&&py>=canvas.y&&py<=canvas.y+canvas.height,'control must fit canvas');if(iphone)await page.touchscreen.tap(px,py);else await page.mouse.click(px,py);};
  await page.screenshot({path:out+'/'+width+'x'+height+'_resgatar.png',scale:'css',timeout:20000});
  await tap('RedeemCommunityDeck');
  let r;const deadline=Date.now()+20000;do{r=await report();if(r.labels.includes('NA SUA CONTA'))break;await page.waitForTimeout(200);}while(Date.now()<deadline);
  assert.ok(r.labels.includes('NA SUA CONTA'));assert.ok(!r.controls.some(c=>c.name==='RedeemCommunityDeck'));
  await page.screenshot({path:out+'/'+width+'x'+height+'_resgatado.png',scale:'css',timeout:20000});
  await page.evaluate(()=>qseDeckInputProbe('owned_collection'));await page.waitForTimeout(500);r=await report();
  assert.ok(r.labels.some(t=>t.includes('[TESTE] Deck resgatado')));assert.ok(r.labels.some(t=>t.includes('Criador de teste')));
  await page.evaluate(()=>qseDeckInputProbe('bottom'));await page.waitForTimeout(500);
  await page.screenshot({path:out+'/'+width+'x'+height+'_colecao.png',scale:'css',timeout:20000});
  assert.deepEqual(errors,[]);
  fs.writeFileSync(out+'/'+width+'x'+height+'_results.json',JSON.stringify({width,height,iphone,claim:true,confirmed:true,inCollection:true,creator:true,errors},null,2));
  await context.close();console.log('COMMUNITY_CLAIM_WEB_PASS '+width+'x'+height+' claim / confirmed / collection / creator, errors=0');
 }
}finally{await browser.close();server.kill();}})().catch(e=>{console.error(e);server.kill();process.exit(1);});
