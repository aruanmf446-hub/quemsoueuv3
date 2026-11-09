// Real Web export, synthetic local account only. No production requests.
const {chromium}=require('playwright'),{spawn}=require('child_process'),fs=require('fs'),assert=require('assert/strict');
const site=process.argv[2],out=process.argv[3];fs.mkdirSync(out,{recursive:true});const server=spawn('python3',['-m','http.server','8180','--bind','127.0.0.1'],{cwd:site,stdio:'ignore'});
(async()=>{const browser=await chromium.launch({executablePath:'/usr/bin/chromium',args:['--no-sandbox','--use-angle=swiftshader','--disable-vulkan']});try{
for(const [width,height] of [[1672,941],[844,390],[640,360]]){
 const mobile=width!==1672,ctx=await browser.newContext({viewport:{width,height},deviceScaleFactor:mobile?3:1,isMobile:mobile,hasTouch:mobile,...(mobile?{userAgent:'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Version/18.0 Mobile/15E148 Safari/604.1'}:{})});
 await ctx.route('**/*',r=>new URL(r.request().url()).hostname==='127.0.0.1'?r.continue():r.abort());const page=await ctx.newPage(),errors=[];page.on('console',m=>{if(/SCRIPT ERROR|Parse Error|^ERROR:/.test(m.text()))errors.push(m.text());});page.on('pageerror',e=>errors.push(e.message));
 await page.goto('http://127.0.0.1:8180/quemsoueuv3/?fixture=manual_claim');await page.waitForFunction(()=>window.qseDeckInputReady,null,{timeout:120000});await page.waitForTimeout(300);const report=await page.evaluate(()=>qseDeckInputReport);
 assert.equal(report.controls.filter(c=>/^Tab[0-5]$/.test(c.name)).length,6);assert.deepEqual(errors,[]);await page.screenshot({path:out+'/'+width+'_header.png',scale:'css'});console.log('HEADER_WEB_PASS',width,height);await ctx.close();
}
}finally{await browser.close();server.kill();}})().catch(e=>{console.error(e);server.kill();process.exit(1);});
