// Actual Godot Web export + iPhone UA. All external requests blocked before network.
const {chromium}=require('playwright');
const {spawn}=require('child_process');const fs=require('fs');
const assert=require('assert/strict');
const fixed=process.argv.includes('--assert');
const dir=process.argv[2],out=process.argv[3];fs.mkdirSync(out,{recursive:true});
const server=spawn('python3',['-m','http.server','8136','--bind','127.0.0.1'],{cwd:dir,stdio:'ignore'});
(async()=>{
 const browser=await chromium.launch({executablePath:'/usr/bin/chromium',args:['--no-sandbox']});
 const context=await browser.newContext({viewport:{width:844,height:390},deviceScaleFactor:3,hasTouch:true,isMobile:true,userAgent:'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Version/18.0 Mobile/15E148 Safari/604.1'});
 await context.route('**/*',route=>new URL(route.request().url()).hostname==='127.0.0.1'?route.continue():route.abort());
 const page=await context.newPage(),errors=[];
 page.on('console',m=>{fs.appendFileSync(out+'/console.log',m.text()+'\n');if(/SCRIPT ERROR|Parse Error|^ERROR:/.test(m.text()))errors.push(m.text());});
 page.on('pageerror',e=>errors.push(e.message));
 const report=async()=>{
  const before=await page.evaluate(()=>window.qseDeckInputReport?.sequence||0);
  await page.evaluate(()=>qseDeckInputProbe());
  if(fixed)await page.waitForFunction(n=>window.qseDeckInputReport?.sequence>n,before,{timeout:10000});
  return page.evaluate(()=>qseDeckInputReport);
 };
 const load=async(mode)=>{await page.goto('http://127.0.0.1:8136/quemsoueuv3/?fixture='+mode);
  await page.evaluate(()=>{window.__inputTrace=[];document.addEventListener('input',e=>window.__inputTrace.push(['dom',e.target.value,e.inputType,e.isComposing]),true);});
  await page.waitForFunction(()=>window.qseDeckInputReady,null,{timeout:120000});await page.waitForTimeout(500);};
 const results={errors};
 try {
  await load('nickname');results.nicknameInitial=await report();
  const input=page.locator('input.qse-field.qse-on').last();
  await input.fill('NovoNick');await page.waitForTimeout(250);results.nicknameTyped=await report();
  results.nicknameTypedDOM=await page.evaluate(()=>({tag:document.activeElement.tagName,value:document.activeElement.value,trace:window.__inputTrace,bridge:window.__bridgeTrace,regions:qseNativeInput.debug(),inputs:Array.from(document.querySelectorAll('.qse-field')).map(n=>({tag:n.tagName,value:n.value,on:n.className}))}));
  await input.fill('');await page.waitForTimeout(250);results.nicknameDeleted=await report();
  await page.keyboard.type('Digitado',{delay:120});await page.waitForTimeout(300);results.nicknameKeys=await report();
  await page.keyboard.press('Backspace');await page.keyboard.press('Backspace');await page.waitForTimeout(300);results.nicknameBackspace=await report();
  await page.screenshot({path:out+'/nickname.png',scale:'css'});
  fs.writeFileSync(out+'/nickname-results.json',JSON.stringify(results,null,2));
  await load('deck');await page.evaluate(()=>qseDeckInputProbe('bottom'));await page.waitForTimeout(400);
  let state=await report();results.deck=state;
  const button=state.controls.find(c=>c.name==='AddCard');
  const canvas=await page.locator('#canvas').boundingBox();
  const chooser=page.waitForEvent('filechooser',{timeout:2500}).catch(()=>null);
  const [x,y,w,h]=button.rect;
  await page.touchscreen.tap(canvas.x+(x+w/2)*canvas.width/state.size[0],canvas.y+(y+h/2)*canvas.height/state.size[1]);
  const file=await chooser;results.fileChooser=!!file;
  if(file){await file.setFiles(require('path').join(__dirname,'../../assets/duel/decks/oficial/lendas_urbanas/momo.png'));await page.waitForTimeout(1000);results.afterFile=await report();}
  fs.writeFileSync(out+'/file-results.json',JSON.stringify(results.afterFile,null,2));
  await page.screenshot({path:out+'/frame.png',scale:'css'});
  if(fixed){
   assert.equal(results.nicknameInitial.fields.NicknameInput,'');
   assert.equal(results.nicknameTyped.fields.NicknameInput,'NovoNick');
   assert.equal(results.nicknameDeleted.fields.NicknameInput,'');
   assert.equal(results.nicknameKeys.fields.NicknameInput,'Digitado');
   assert.equal(results.nicknameBackspace.fields.NicknameInput,'Digita');
   assert.equal(results.fileChooser,true);assert.equal(results.afterFile.cards,1);
   const tap=async(name,scroll=true)=>{
    if(scroll){await page.evaluate(n=>qseDeckInputProbe('focus:'+n),name);await page.waitForTimeout(250);}
    const r=await report(),control=r.controls.find(c=>c.name===name);assert.ok(control,'missing '+name);
    const c=await page.locator('#canvas').boundingBox();const [x,y,w,h]=control.rect;
    await page.touchscreen.tap(c.x+(x+w/2)*c.width/r.size[0],c.y+(y+h/2)*c.height/r.size[1]);await page.waitForTimeout(200);
   };
   assert.equal(await page.locator('.qse-image-input').count(),0,'file input must not cover frame modal');
   await tap('ConfirmFrame',false);await page.waitForTimeout(700);
   await tap('CardName');
   assert.equal(await page.evaluate(()=>document.activeElement.tagName),'INPUT');
   await page.locator('input.qse-typing').fill('ABCDE');
   await page.evaluate(()=>document.activeElement.setSelectionRange(2,2));
   await page.keyboard.type('x',{delay:120});
   results.cardEdit=await report();assert.equal(results.cardEdit.card_names[0],'ABxCDE');
   await page.screenshot({path:out+'/card.png',scale:'css'});
   await page.evaluate(()=>document.activeElement.blur());
   await tap('DeckDescription');
   assert.equal(await page.evaluate(()=>document.activeElement.tagName),'TEXTAREA');
   await page.locator('textarea.qse-typing').fill('Primeira');
   await page.keyboard.press('Enter');await page.keyboard.type('Segunda',{delay:80});
   results.description=await report();assert.equal(results.description.description,'Primeira\nSegunda');
   await page.evaluate(()=>{document.activeElement.value='Alterado ao fechar';document.activeElement.blur();});
   results.descriptionBlur=await report();assert.equal(results.descriptionBlur.description,'Alterado ao fechar');
   await tap('DeckName');await page.locator('input.qse-typing').fill('Meu deck mobile');
   await page.evaluate(()=>document.activeElement.blur());
   results.name=await report();assert.equal(results.name.name,'Meu deck mobile');
   const attach=async(name)=>{
    const pending=page.waitForEvent('filechooser',{timeout:5000});await tap(name);
    const chooser=await pending;await chooser.setFiles(require('path').join(__dirname,'../../assets/duel/decks/oficial/lendas_urbanas/momo.png'));
    await page.waitForTimeout(800);assert.ok((await report()).controls.some(c=>c.name==='ConfirmFrame'));
    await tap('ConfirmFrame',false);await page.waitForTimeout(600);
   };
   await attach('ReplaceImage');assert.equal((await report()).cards,1);
   await tap('DeckDetails');await page.waitForTimeout(300);
   await attach('CoverUpload');results.cover=await report();assert.equal(results.cover.cover.mode,'upload');
   results.installHidden=await page.evaluate(()=>getComputedStyle(document.getElementById('qse-install')).display==='none');assert.ok(results.installHidden);
   assert.deepEqual(errors,[]);
   console.log('IPHONE_DECK_WEB_PASS text/delete/caret/textarea/blur/add/replace/cover/modal/install');
  }
  await page.screenshot({path:out+'/deck.png',scale:'css'});
  fs.writeFileSync(out+'/results.json',JSON.stringify(results,null,2));
  console.log(JSON.stringify({nicknameInitial:results.nicknameInitial.fields,nicknameTyped:results.nicknameTyped.fields,nicknameDeleted:results.nicknameDeleted.fields,nicknameKeys:results.nicknameKeys.fields,nicknameBackspace:results.nicknameBackspace.fields,fileChooser:results.fileChooser,afterFile:results.afterFile?.cards,errors}));
 } finally {await browser.close();server.kill();}
})().catch(e=>{console.error(e);server.kill();process.exit(1);});
