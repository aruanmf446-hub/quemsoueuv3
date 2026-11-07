const {chromium}=require('playwright'),{spawn}=require('child_process'),fs=require('fs'),assert=require('assert/strict');
const site=process.argv[2],out=process.argv[3];fs.mkdirSync(out,{recursive:true});
const server=spawn('python3',['-m','http.server','8170','--bind','127.0.0.1'],{cwd:site,stdio:'ignore'});
(async()=>{const browser=await chromium.launch({executablePath:'/usr/bin/chromium',args:['--no-sandbox','--use-angle=swiftshader','--disable-vulkan']});try{
let results=[];
for(const [lang,width,height] of [['en',1672,941],['fr',844,390],['ja',640,360]].filter(row=>!process.env.QSE_NAMES_LANG||row[0]===process.env.QSE_NAMES_LANG)){
 const mobile=lang!=='en',catalog=JSON.parse(fs.readFileSync('data/ui/'+lang+'.json'));
 const ctx=await browser.newContext({viewport:{width,height},deviceScaleFactor:mobile?3:1,isMobile:mobile,hasTouch:mobile,...(mobile?{userAgent:'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Version/18.0 Mobile/15E148 Safari/604.1'}:{})});
 await ctx.route('**/*',r=>new URL(r.request().url()).hostname==='127.0.0.1'?r.continue():r.abort());
 const page=await ctx.newPage(),errors=[];page.on('console',m=>{fs.appendFileSync(out+'/console.log',m.text()+'\n');if(/SCRIPT ERROR|Parse Error|^ERROR:/.test(m.text()))errors.push(m.text());});page.on('pageerror',e=>errors.push(e.message));
 await page.goto('http://127.0.0.1:8170/quemsoueuv3/?fixture=i18n&lang='+lang);await page.waitForFunction(()=>window.qseDeckInputReady,null,{timeout:120000});
 for(const screen of ['library','official_cards','duel','skins']){
  const sequence=await page.evaluate(()=>qseDeckInputReport.sequence);await page.evaluate(s=>qseDeckInputProbe('i18n_screen:'+s),screen);await page.waitForFunction(n=>qseDeckInputReport.sequence>n,sequence,{timeout:120000});await page.waitForTimeout(screen==='skins'?1500:400);
  const settled=await page.evaluate(()=>qseDeckInputReport.sequence);await page.evaluate(()=>qseDeckInputProbe());await page.waitForFunction(n=>qseDeckInputReport.sequence>n,settled);
  let report=await page.evaluate(()=>qseDeckInputReport);
  if(screen==='skins'){
   const b=report.controls.find(c=>c.name==='SkinVariation_style_1'),box=await page.locator('#canvas').boundingBox();assert.ok(b);
   const [x,y,w,h]=b.rect,px=box.x+(x+w/2)*box.width/report.size[0],py=box.y+(y+h/2)*box.height/report.size[1];
   if(mobile)await page.touchscreen.tap(px,py);else await page.mouse.click(px,py);
   await page.waitForTimeout(300);const n=report.sequence;await page.evaluate(()=>qseDeckInputProbe());await page.waitForFunction(n=>qseDeckInputReport.sequence>n,n);report=await page.evaluate(()=>qseDeckInputReport);
   fs.writeFileSync(out+'/'+lang+'_skins-report.json',JSON.stringify(report,null,2));await page.screenshot({path:out+'/'+lang+'_skins.png',scale:'css'});
   assert.ok(report.labels.some(t=>t.includes(catalog['Patrulheiro Azul'])),'selected variant translated '+lang);
  }
  const texts=report.labels.concat(report.controls.map(c=>c.text));
  const key=screen==='skins'?'Cowboy':screen==='official_cards'?'Loira do Banheiro':'Lendas Urbanas';
  assert.ok(texts.some(t=>t.includes(catalog[key])),lang+' '+screen+' translated '+key);

  assert.deepEqual(errors,[]);await page.screenshot({path:out+'/'+lang+'_'+screen+'.png',scale:'css'});console.log('CONTENT_NAMES_PASS',lang,screen);
 }
 results.push({lang,width,height,errors,screens:['library','official_cards','duel','skins']});fs.writeFileSync(out+'/results.json',JSON.stringify(results,null,2));await ctx.close();
}
}finally{await browser.close();server.kill();}})().catch(e=>{console.error(e);server.kill();process.exit(1);});
