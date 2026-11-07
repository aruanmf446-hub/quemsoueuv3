const {chromium}=require('playwright'),{spawn}=require('child_process'),fs=require('fs'),assert=require('assert/strict');
const site=process.argv[2],out=process.argv[3];fs.mkdirSync(out,{recursive:true});const root=process.cwd();
const server=spawn('python3',['-m','http.server','8168','--bind','127.0.0.1'],{cwd:site,stdio:'ignore'});
(async()=>{let browser=await chromium.launch({executablePath:'/usr/bin/chromium',args:['--no-sandbox','--use-angle=swiftshader','--disable-vulkan']});try{let results=[];
const codes=process.argv[4]==='preview'?['fr']:['en','es','fr','ja','zh_CN','ru'];
for(const code of codes){const width=code==='en'?1672:844,height=code==='en'?941:390,iphone=code!=='en';const catalog=JSON.parse(fs.readFileSync(root+'/data/ui/'+code+'.json'));
const ctx=await browser.newContext({viewport:{width,height},deviceScaleFactor:iphone?3:1,hasTouch:iphone,isMobile:iphone,...(iphone?{userAgent:'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Version/18.0 Mobile/15E148 Safari/604.1'}:{})});await ctx.route('**/*',r=>new URL(r.request().url()).hostname==='127.0.0.1'?r.continue():r.abort());const page=await ctx.newPage(),errors=[];page.on('console',m=>{fs.appendFileSync(out+'/console.log',m.text()+'\n');if(/SCRIPT ERROR|Parse Error|^ERROR:/.test(m.text()))errors.push(m.text());});page.on('pageerror',e=>errors.push(e.message));
await page.goto('http://127.0.0.1:8168/quemsoueuv3/?fixture=i18n&lang='+code);await page.waitForFunction(()=>window.qseDeckInputReady,null,{timeout:120000});
const report=async(action)=>{let n=await page.evaluate(()=>qseDeckInputReport.sequence);await page.evaluate(a=>a?qseDeckInputProbe('i18n_screen:'+a):qseDeckInputProbe(),action);await page.waitForFunction(n=>qseDeckInputReport.sequence>n,n);return page.evaluate(()=>qseDeckInputReport);};
const capture=async(name)=>{await page.waitForTimeout(400);await page.screenshot({path:out+'/'+code+'_'+name+'.png',scale:'css'});};
let s=await report();assert.equal(s.locale,code);const text=s.labels.concat(s.controls.map(x=>x.text));assert.ok(text.includes(catalog['Criar deck']),'editor title '+code);assert.ok(text.includes(catalog['Salvar rascunho']),'save draft '+code);
if(iphone){const field=s.controls.find(n=>n.name==='DeckName'),canvas=await page.locator('#canvas').boundingBox();assert.ok(field,'name input');const[x,y,w,h]=field.rect;const px=canvas.x+(x+w/2)*canvas.width/s.size[0],py=canvas.y+(y+h/2)*canvas.height/s.size[1];if(iphone)await page.touchscreen.tap(px,py);else await page.mouse.click(px,py);await page.waitForTimeout(300);
const input=page.locator('input.qse-field.qse-typing').last();assert.equal(await input.getAttribute('placeholder'),catalog['Dê um nome ao seu deck'],'focused DOM placeholder '+code);await input.fill('Configurações');await page.waitForTimeout(300);assert.equal((await report()).name,'Configurações','typed value preserved');await input.blur();
}
await capture('editor');
for(const mode of ['review','friends','duel','lobby','tutorial']){console.log('I18N_SCREEN',code,mode);s=await report(mode);await page.waitForTimeout(300);s=await report();const texts=s.labels.concat(s.controls.map(x=>x.text));
 if(s.layout_width)assert.ok(s.layout_width<=s.size[0]+3,'layout overflow '+code+' '+mode+' '+s.layout_width);
 const expected={review:'Antes de publicar',friends:'Buscar jogadores',duel:'Mata-Mata · Partida local',lobby:'MODO HISTÓRIA',tutorial:'Âmbar · congele quem vem atrás'}[mode];assert.ok(texts.includes(catalog[expected]),mode+' translated '+code+': '+expected);
 if(mode==='friends')assert.ok(texts.includes('Configurações'),'user nickname unchanged '+code);
 await capture(mode);
}
const shell=await page.evaluate(()=>({lang:document.documentElement.lang,install:document.getElementById('qse-install').textContent}));assert.equal(shell.install,catalog['INSTALAR NO IPHONE']);assert.equal(shell.lang,code.replace('_','-'));assert.deepEqual(errors,[]);results.push({code,width,height,errors,domPlaceholder:iphone,nicknamePreserved:true,screens:['editor','review','friends','duel','lobby','tutorial']});fs.writeFileSync(out+'/results.json',JSON.stringify(results,null,2));console.log('I18N_WEB_PASS',code);await ctx.close();
}
}finally{await browser.close();server.kill();}})().catch(e=>{console.error(e);server.kill();process.exit(1);});
