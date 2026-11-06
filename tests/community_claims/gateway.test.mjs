import {test} from 'node:test';
import assert from 'node:assert/strict';
import {createHandler} from '../../supabase/game/functions/qse-deck-catalog/handler.js';
const GAME='https://shuzporktifgiotvnpbz.supabase.co',CAT='https://bsxicvlngphazesuzaee.supabase.co';
const DECK='00000000-0000-4000-8000-000000000001',VER='00000000-0000-4000-8000-000000000002',USER='00000000-0000-4000-8000-000000000003';
const REF='community_'+VER.replaceAll('-','');
const config={gameUrl:GAME,gameKey:'game-service-fixture',catalogUrl:CAT,catalogKey:'catalog-service-fixture'};
const png=Uint8Array.from(Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aRZ8AAAAASUVORK5CYII=','base64'));
const cards=Array.from({length:5},(_,i)=>{const id='00000000-0000-4000-8000-00000000001'+i;return {id,name:'Carta '+i,library_path:USER+'/'+DECK+'/'+id+'_library.png',duel_path:USER+'/'+DECK+'/'+id+'_duel.png'};});
const manifest={id:REF,deck_id:DECK,version_id:VER,name:'Deck de teste',cards:cards.map(c=>({id:REF+'/'+c.id,name:c.name,library_path:VER+'/'+c.id+'_library.png',duel_path:VER+'/'+c.id+'_duel.png'}))};
function fixture(options={}){
 const calls=[];let claims=0;
 const transport=async(url,init={})=>{
  calls.push({url,init});
  const json=(body,status=200)=>new Response(JSON.stringify(body),{status,headers:{'Content-Type':'application/json'}});
  if(url.startsWith(CAT))assert.equal(init.headers.Authorization,'Bearer catalog-service-fixture','GAME session must never authenticate to CATALOG');
  if(url===GAME+'/auth/v1/user')return json({id:USER},options.authStatus||200);
  if(url.endsWith('/qse_catalog_prepare'))return json({version_id:VER,ready:!!options.ready,source:{cards:options.cards||cards},manifest});
  if(url.includes('/storage/v1/object/authenticated/'))return new Response(png);
  if(url.startsWith(CAT+'/storage/v1/object/qse-community-previews/'))return json({},options.uploadStatus||200);
  if(url.startsWith(CAT+'/rest/v1/qse_catalog_community_versions'))return json([]);
  if(url.endsWith('/qse_catalog_finalize'))return json(options.changed?{error:'deck_changed'}:{ready:true,version_id:VER});
  if(url.endsWith('/qse_community_claim')){assert.equal(init.headers.Authorization,'Bearer player-fixture');claims++;return json({claimed:true,deck_id:DECK,version_id:VER,deck_ref:REF,already_owned:claims>1});}
  if(url.endsWith('/qse_community_manifests'))return json(options.notOwned?{error:'deck_not_owned'}:{items:[structuredClone(manifest)]});
  if(url===CAT+'/storage/v1/object/sign/qse-community-previews')return json(JSON.parse(init.body).paths.map(path=>({path,signedURL:'/object/sign/qse-community-previews/'+path+'?token=fixture'})));
  throw new Error('Unexpected endpoint '+url);
 };
 return {handler:createHandler(config,transport),calls,get claims(){return claims;}};
}
const request=(body,auth=true)=>new Request(GAME+'/functions/v1/qse-deck-catalog',{method:'POST',headers:auth?{Authorization:'Bearer player-fixture'}:{},body:JSON.stringify(body)});
test('anonymous request never reaches source or CATALOG',async()=>{const f=fixture();assert.equal((await f.handler(request({action:'claim',deck_id:DECK},false))).status,401);assert.equal(f.calls.length,0);});
test('invalid GAME session cannot publish or claim',async()=>{const f=fixture({authStatus:401});assert.equal((await f.handler(request({action:'claim',deck_id:DECK}))).status,401);assert.equal(f.calls.length,1);});
test('claim copies only approved previews and confirms entitlement as player',async()=>{const f=fixture();const r=await(await f.handler(request({action:'claim',deck_id:DECK}))).json();assert.equal(r.claimed,true);assert.equal(f.claims,1);assert.equal(f.calls.filter(c=>c.url.startsWith(CAT+'/storage/v1/object/qse-community-previews/')).length,10);assert.ok(!f.calls.some(c=>c.url.includes('original.png')));assert.ok(f.calls.findIndex(c=>c.url.endsWith('qse_catalog_finalize'))<f.calls.findIndex(c=>c.url.endsWith('qse_community_claim')));});
test('already prepared version does not download/upload again',async()=>{const f=fixture({ready:true});await f.handler(request({action:'claim',deck_id:DECK}));assert.equal(f.claims,1);assert.ok(!f.calls.some(c=>c.url.startsWith(CAT)));});
test('upload failure never confirms ownership',async()=>{const f=fixture({uploadStatus:503});const r=await(await f.handler(request({action:'claim',deck_id:DECK}))).json();assert.equal(r.error,'catalog_unavailable');assert.equal(f.claims,0);});
test('withdrawal during copy cannot finalize or claim stale version',async()=>{const f=fixture({changed:true});const r=await(await f.handler(request({action:'claim',deck_id:DECK}))).json();assert.equal(r.error,'deck_changed');assert.equal(f.claims,0);});
test('concurrent immutable upload collision is safe',async()=>{const f=fixture({uploadStatus:409});assert.equal((await(await f.handler(request({action:'claim',deck_id:DECK}))).json()).claimed,true);});
test('private original/path traversal cannot be copied',async()=>{const bad=structuredClone(cards);bad[0].library_path=USER+'/'+DECK+'/'+bad[0].id+'_original.png';const f=fixture({cards:bad});assert.equal((await(await f.handler(request({action:'claim',deck_id:DECK}))).json()).error,'invalid_contract');assert.equal(f.claims,0);assert.ok(!f.calls.some(c=>c.url.startsWith(CAT)));});
test('signed previews require GAME entitlement/room authorization',async()=>{const f=fixture({notOwned:true});const r=await(await f.handler(request({action:'manifests',deck_refs:[REF]}))).json();assert.equal(r.error,'deck_not_owned');assert.ok(!f.calls.some(c=>c.url.startsWith(CAT)));});
test('authorized manifest gets only version-scoped signed URLs',async()=>{const f=fixture();const r=await(await f.handler(request({action:'manifests',deck_refs:[REF]}))).json();assert.equal(r.items[0].cards.length,5);assert.ok(r.items[0].cards.every(c=>c.duel_url.startsWith(CAT+'/storage/v1/object/sign/qse-community-previews/'+VER+'/')));});
test('arbitrary and duplicate deck refs refused',async()=>{for(const deck_refs of [['../private'],[REF,REF],Array(6).fill(REF)]){const f=fixture();assert.equal((await f.handler(request({action:'manifests',deck_refs}))).status,400);assert.equal(f.calls.length,1);}});
test('caller supplied metadata cannot replace authoritative source',async()=>{const f=fixture();const r=await(await f.handler(request({action:'claim',deck_id:DECK,manifest:{name:'Forged'}}))).json();assert.equal(r.claimed,true);const posted=f.calls.find(c=>c.url.startsWith(CAT+'/rest/v1/'));assert.equal(JSON.parse(posted.init.body).manifest.name,'Deck de teste');});
test('oversized request cannot trigger distribution',async()=>{const f=fixture();const response=await f.handler(request({action:'claim',deck_id:DECK,extra:'x'.repeat(3000)}));assert.equal(response.status,400);assert.equal(f.claims,0);assert.equal(f.calls.length,1);});
test('unsupported action cannot trigger writes',async()=>{const f=fixture();const response=await f.handler(request({action:'approve',deck_id:DECK}));assert.equal(response.status,400);assert.equal(f.claims,0);assert.equal(f.calls.length,1);});
