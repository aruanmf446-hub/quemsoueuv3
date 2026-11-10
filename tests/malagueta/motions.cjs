// Isolated visual inspection of the actual imported clips, not a combat replay.
const {chromium}=require('playwright'),{spawn}=require('child_process'),fs=require('fs');
const [site,out]=process.argv.slice(2);fs.mkdirSync(out,{recursive:true});
const server=spawn('python3',['-m','http.server','8222','--bind','127.0.0.1'],{cwd:site,stdio:'ignore'});
(async()=>{
 const browser=await chromium.launch({executablePath:'/usr/bin/chromium',args:['--no-sandbox','--use-angle=swiftshader','--disable-vulkan']});
 try{
  const ctx=await browser.newContext({viewport:{width:960,height:540},recordVideo:{dir:out,size:{width:960,height:540}}});
  await ctx.route('**/*',r=>new URL(r.request().url()).hostname==='127.0.0.1'?r.continue():r.abort());
  const page=await ctx.newPage(),errors=[];
  page.on('console',m=>{if(/SCRIPT ERROR|Parse Error|^ERROR:/.test(m.text()))errors.push(m.text());});
  page.on('pageerror',e=>errors.push(e.message));
  await page.goto('http://127.0.0.1:8222/quemsoueuv3/');
  await page.waitForFunction(()=>window.bossReady,null,{timeout:180000});
  for(const clip of ['base','throw','carry','hurt','dizzy','retreat','morte']){
   await page.evaluate(c=>bossProbe('motion:'+c),clip);
   await page.waitForTimeout(clip==='dizzy'?5000:3000);
   await page.screenshot({path:out+'/'+clip+'.png',timeout:90000});
   console.log('MOTION_CAPTURE',clip);
  }
  const video=page.video();await ctx.close();await video.saveAs(out+'/motions.webm');
  fs.writeFileSync(out+'/errors.json',JSON.stringify(errors,null,2));
  if(errors.length)throw Error(errors.join('\n'));
 }finally{await browser.close();server.kill();}
})().catch(e=>{console.error(e);server.kill();process.exit(1);});
