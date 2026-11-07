const {chromium}=require('playwright'),{spawn}=require('child_process'),fs=require('fs'),assert=require('assert/strict');
const dir=process.argv[2],out=process.argv[3];fs.mkdirSync(out,{recursive:true});
const server=spawn('python3',['-m','http.server','8162','--bind','127.0.0.1'],{cwd:dir,stdio:'ignore'});
(async()=>{const browser=await chromium.launch({executablePath:'/usr/bin/chromium',args:['--no-sandbox','--use-angle=swiftshader','--disable-vulkan']});
try {let results=[];
for(const [width,height,device] of (process.argv[4]==='friends'?[[640,360,'iphone']]:[[1672,941,'desktop'],[844,390,'iphone'],[640,360,'iphone'],[844,390,'android']])){
 const iphone=device==='iphone';const context=await browser.newContext({viewport:{width,height},deviceScaleFactor:device==='desktop'?1:3,hasTouch:device!=='desktop',isMobile:device!=='desktop',...(iphone?{userAgent:'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Version/18.0 Mobile/15E148 Safari/604.1'}:device==='android'?{userAgent:'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 Chrome/130.0.0.0 Mobile Safari/537.36'}:{})});
 await context.route('**/*',r=>new URL(r.request().url()).hostname==='127.0.0.1'?r.continue():r.abort());
 const page=await context.newPage(),errors=[];page.on('console',m=>{fs.appendFileSync(out+'/console.log',m.text()+'\n');if(/SCRIPT ERROR|Parse Error|^ERROR:/.test(m.text()))errors.push(m.text());});page.on('pageerror',e=>errors.push(e.message));
 const report=async()=>{let n=await page.evaluate(()=>qseDeckInputReport.sequence);await page.evaluate(()=>qseDeckInputProbe());await page.waitForFunction(n=>qseDeckInputReport.sequence>n,n);return page.evaluate(()=>qseDeckInputReport);};
 const load=async(mode)=>{await page.goto('http://127.0.0.1:8162/quemsoueuv3/?fixture='+mode);await page.waitForFunction(()=>window.qseDeckInputReady,null,{timeout:120000});await page.waitForTimeout(700);};
 const tap=async(id)=>{let s=await report(),b=s.controls.find(c=>c.name===id||c.text===id);assert.ok(b,'missing '+id);let[x,y,w,h]=b.rect;assert.ok(x>=0&&y>=0&&x+w<=s.size[0]+2&&y+h<=s.size[1]+2,`outside ${id}: ${b.rect} viewport ${s.size}`);let c=await page.locator('#canvas').boundingBox();const px=c.x+(x+w/2)*c.width/s.size[0],py=c.y+(y+h/2)*c.height/s.size[1];if(device==='desktop')await page.mouse.click(px,py);else await page.touchscreen.tap(px,py);await page.waitForTimeout(450);};
 for(const mode of (process.argv[4]==='duel'?['duel_admin']:process.argv[4]==='languages'?['languages']:process.argv[4]==='friends'?['friends_search']:['languages','public_profile','friends_search','duel_admin'])){
 console.log('LOAD',device,mode);await load(mode);let s=await report();fs.writeFileSync(`${out}/${device}_${width}x${height}_${mode}.json`,JSON.stringify(s,null,2));await page.screenshot({path:`${out}/${device}_${width}x${height}_${mode}_layout.png`,scale:'css'});assert.ok(s.layout_width<=s.size[0]+2, `layout wider than viewport ${mode}: ${s.layout_width} > ${s.size[0]}`);
 if(mode==='languages'){
  assert.equal(s.controls.filter(x=>x.name.startsWith('Locale_')).length,7);
  await tap('Locale_ja');await page.screenshot({path:`${out}/${device}_${width}x${height}_japanese.png`,scale:'css'});await tap('ConfirmLanguage');
  await tap('Locale_zh_CN');await page.screenshot({path:`${out}/${device}_${width}x${height}_chinese.png`,scale:'css'});await tap('ConfirmLanguage');
  await tap('Locale_ru');await tap('ConfirmLanguage');await page.screenshot({path:`${out}/${device}_${width}x${height}_russian.png`,scale:'css'});
  await tap('Locale_pt_BR');assert.equal((await report()).language_choice,'pt_BR');await tap('ConfirmLanguage');assert.equal((await report()).locale,'pt_BR');await page.waitForTimeout(2000);
 }else if(mode==='public_profile'){
  assert.ok(s.labels.includes('aruan'));assert.ok(s.controls.find(x=>x.name==='AddPublicFriend'));await tap('CopyPublicId');
  await page.screenshot({path:`${out}/${device}_${width}x${height}_${mode}.png`,scale:'css'});
 }else if(mode==='friends_search'){
  assert.ok(s.labels.includes('aruan'));await page.screenshot({path:`${out}/${device}_${width}x${height}_${mode}.png`,scale:'css'});
 }else{
  let cards=s.controls.filter(x=>x.name.startsWith('DeckChoice_'));assert.equal(cards.length,2);assert.ok(cards.every(x=>x.rect[3]>=(iphone?216:280)));
  await tap(cards[1].name);await tap('AcceptSelection');
  await page.screenshot({path:`${out}/${device}_${width}x${height}_${mode}.png`,scale:'css'});await tap('SubmitRoom');
 }
 }
 assert.deepEqual(errors,[]);results.push({device,width,height,errors});fs.writeFileSync(out+'/results.json',JSON.stringify(results,null,2));console.log('PROFILE_WEB_PASS',device,width,height);await context.close();
}
}finally{await browser.close();server.kill();}})().catch(e=>{console.error(e);server.kill();process.exit(1);});
