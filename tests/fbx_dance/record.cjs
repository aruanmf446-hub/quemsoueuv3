// Deterministic Godot render samples, not generated/interpolated artwork.
const {chromium}=require('playwright'),{spawn}=require('child_process'),fs=require('fs'),assert=require('assert/strict');
const dir=process.argv[2],out=process.argv[3];fs.mkdirSync(out,{recursive:true});
const server=spawn('python3',['-m','http.server','8153','--bind','127.0.0.1'],{cwd:dir,stdio:'ignore'});
(async()=>{const browser=await chromium.launch({executablePath:'/usr/bin/chromium',args:['--no-sandbox','--use-angle=swiftshader','--disable-vulkan']});
try{
 const results=[];
 for(const group of [1,2]){
  const context=await browser.newContext({viewport:{width:1280,height:720},deviceScaleFactor:1});
  await context.route('**/*',r=>new URL(r.request().url()).hostname==='127.0.0.1'?r.continue():r.abort());
  const page=await context.newPage(),errors=[];
  page.on('console',m=>{fs.appendFileSync(out+'/console.log',m.text()+'\n');if(/SCRIPT ERROR|Parse Error|^ERROR:/.test(m.text())){errors.push(m.text());console.error(m.text());}});page.on('pageerror',e=>errors.push(e.message));
  await page.goto('http://127.0.0.1:8153/quemsoueuv3/?fixture=fbx_dance&group='+group);
  await page.waitForFunction(()=>window.qseSambaReady,null,{timeout:process.env.QSE_DIAGNOSTIC?15000:120000}).catch(async e=>{await page.screenshot({path:out+'/startup.png'});throw e});
  const folder=out+'/group'+group;fs.mkdirSync(folder,{recursive:true});
  const frames=process.env.QSE_SAMPLE_ONLY?1:60;
  for(let i=0;i<frames;i++){
   const time=process.env.QSE_SAMPLE_ONLY?1.5:i/10;
   await page.evaluate(t=>{window.qseSambaFrame=null;qseSambaSample(t)},time);
   await page.waitForFunction(t=>window.qseSambaFrame?.time===t,time,{timeout:60000});
   await page.screenshot({path:folder+'/'+String(i).padStart(3,'0')+'.png',scale:'css'});
   if(i%10===0)console.log('FBX_FRAME group='+group+' frame='+i);
  }
  const report=await page.evaluate(()=>qseSambaFrame);assert.equal(report.characters.length,4);assert.deepEqual(errors,[]);
  results.push({group,frames,fps:10,characters:report.characters,errors});fs.writeFileSync(out+'/results.json',JSON.stringify(results,null,2));
  await context.close();
 }
}finally{await browser.close();server.kill();}})().catch(e=>{console.error(e);server.kill();process.exit(1)});
