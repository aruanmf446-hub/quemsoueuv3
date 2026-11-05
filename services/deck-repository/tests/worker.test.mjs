import test from 'node:test';
import assert from 'node:assert/strict';
import {webcrypto,createHash} from 'node:crypto';
import {createHandler,LIMITS} from '../src/worker.mjs';
const IMAGE='UklGRh4AAABXRUJQVlA4TBEAAAAvB8ACAAfQzUoXqv+BiOh/AAA='; // WebP real, fixture 8×12.
const ADMIN='00000000-0000-4000-8000-0000000000a1',PLAYER='00000000-0000-4000-8000-0000000000b2',OTHER='00000000-0000-4000-8000-0000000000c3';
const env={GITHUB_REPOSITORY:'owner/game',MAIN_BRANCH:'main',INBOX_BRANCH:'deck-inbox',GITHUB_TOKEN:'fixture-server-only-token',GAME_URL:'https://fixture.supabase.co',GAME_PUBLISHABLE_KEY:'fixture-public-key',MODERATOR_PUBLIC_IDS:'QSE-ADMIN',ALLOWED_ORIGINS:'https://game.example'};
const response=(body,status=200)=>new Response(JSON.stringify(body),{status,headers:{'Content-Type':'application/json'}});
class Repository {
 blobs=new Map();trees=new Map();commits=new Map();refs=new Map();calls=0;rejectNextPatch=false;
 hash(v){return createHash('sha1').update(v).digest('hex');}
 constructor(){const blob=this.put(Buffer.from(JSON.stringify({schema_version:1,decks:[]}))),tree=this.tree({'data/community/approved_decks.json':blob});const commit=this.commit(tree,[]);this.refs.set('main',commit);}
 put(data){const id=this.hash(data);this.blobs.set(id,Buffer.from(data));return id;}
 tree(files){const id=this.hash(JSON.stringify(files));this.trees.set(id,{...files});return id;}
 commit(tree,parents){const id=this.hash(tree+JSON.stringify(parents)+this.commits.size);this.commits.set(id,{tree:{sha:tree},parents});return id;}
 json(path,branch){const commit=this.commits.get(this.refs.get(branch)),id=this.trees.get(commit.tree.sha)[path];return id?JSON.parse(this.blobs.get(id).toString()):null;}
 async api(url,options){
  this.calls++;
  assert.equal(options.headers.Authorization,'Bearer '+env.GITHUB_TOKEN);
  const path=decodeURIComponent(url.pathname.replace('/repos/owner/game',''));
  const body=options.body?JSON.parse(options.body):{};
  if(path.startsWith('/git/ref/heads/')){const sha=this.refs.get(path.slice(15));return sha?response({object:{sha}}):response({},404);}
  if(path.startsWith('/git/commits/')&&options.method==='GET'){const value=this.commits.get(path.slice(13));return value?response(value):response({},404);}
  if(path.startsWith('/contents/')){
   assert.equal(options.headers.Accept,'application/vnd.github.raw+json');
   const commit=this.commits.get(url.searchParams.get('ref'));
   const sha=commit&&this.trees.get(commit.tree.sha)[path.slice(10)];
   return sha?new Response(this.blobs.get(sha)):response({},404);
  }
  if(path==='/git/refs'&&options.method==='POST'){const name=body.ref.slice(11);if(this.refs.has(name))return response({},422);this.refs.set(name,body.sha);return response({object:{sha:body.sha}},201);}
  if(path==='/git/blobs')return response({sha:this.put(Buffer.from(body.content,'base64'))},201);
  if(path==='/git/trees'){
   const files={...this.trees.get(body.base_tree)};
   for(const row of body.tree){assert.ok(!row.path.includes('..'));assert.ok(row.path.startsWith('deck_submissions/')||row.path.startsWith('assets/duel/decks/community/')||row.path==='data/community/approved_decks.json');files[row.path]=row.sha;}
   return response({sha:this.tree(files)},201);
  }
  if(path==='/git/commits'&&options.method==='POST')return response({sha:this.commit(body.tree,body.parents)},201);
  if(path.startsWith('/git/refs/heads/')&&options.method==='PATCH'){
   const branch=path.slice(16),commit=this.commits.get(body.sha);
   if(this.rejectNextPatch){this.rejectNextPatch=false;return response({},422);}
   if(!commit.parents.includes(this.refs.get(branch)))return response({},422);
   assert.equal(body.force,false);this.refs.set(branch,body.sha);return response({object:{sha:body.sha}});
  }
  throw new Error('Unexpected GitHub operation '+options.method+' '+path);
 }
}
function deck(name='Teste manual',count=5){return {visibility:'public',name,description:'Fixture sem rede',category:'Personagens',style_reference:'lendas_urbanas',cards:Array.from({length:count},(_,i)=>({name:'Carta '+i,image:IMAGE,crops:{library:{x:.5,y:.4,zoom:1},duel:{x:.5,y:.35,zoom:1}}}))};}
for(const alg of ['RS256','ES256'])test(alg+' GAME JWT, repo queue, approval, rejection, ownership, replay and publication recovery',async()=>{
 const keyAlgorithm=alg==='RS256'?{name:'RSASSA-PKCS1-v1_5',modulusLength:2048,publicExponent:new Uint8Array([1,0,1]),hash:'SHA-256'}:{name:'ECDSA',namedCurve:'P-256'};
 const signatureAlgorithm=alg==='RS256'?{name:'RSASSA-PKCS1-v1_5'}:{name:'ECDSA',hash:'SHA-256'};
 const keys=await webcrypto.subtle.generateKey(keyAlgorithm,true,['sign','verify']);
 const jwk={...await webcrypto.subtle.exportKey('jwk',keys.publicKey),kid:'fixture',alg,use:'sig'};
 const repo=new Repository();let profileCalls=0;
 const fetcher=async(url,options={})=>{
  const u=new URL(url);
  if(u.host==='api.github.com')return repo.api(u,options);
  assert.equal(u.origin,env.GAME_URL,'nenhuma chamada externa inesperada');
  if(u.pathname.endsWith('/jwks.json'))return response({keys:[jwk]});
  assert.equal(u.pathname,'/rest/v1/rpc/qse_profile_self');
  assert.equal(options.headers.apikey,env.GAME_PUBLISHABLE_KEY);
  const token=options.headers.Authorization.slice(7),claims=JSON.parse(Buffer.from(token.split('.')[1],'base64url'));
  profileCalls++;
  return response({user_id:claims.sub,public_id:claims.sub===ADMIN?'QSE-ADMIN':claims.sub===PLAYER?'QSE-PLAYER':'QSE-OTHER',nickname:claims.sub===ADMIN?'Dono':'Criador'});
 };
 const handler=createHandler({fetch:fetcher,crypto:webcrypto});
 const token=async(sub,overrides={})=>{
  const head=Buffer.from(JSON.stringify({alg,kid:'fixture'})).toString('base64url');
  const claims=Buffer.from(JSON.stringify({iss:env.GAME_URL+'/auth/v1',aud:'authenticated',role:'authenticated',sub,exp:Date.now()/1000+3600,...overrides})).toString('base64url');
  const signature=await webcrypto.subtle.sign(signatureAlgorithm,keys.privateKey,Buffer.from(head+'.'+claims));
  return head+'.'+claims+'.'+Buffer.from(signature).toString('base64url');
 };
 const tokens={admin:await token(ADMIN),player:await token(PLAYER),other:await token(OTHER)};
 const call=async(path,who='player',method='GET',body=null,extra={})=>{
  const result=await handler(new Request('https://bridge.example'+path,{method,headers:{Origin:'https://game.example',...(who?{Authorization:'Bearer '+(tokens[who]||who)}:{}),'Content-Type':'application/json',...extra},...(body===null?{}:{body:JSON.stringify(body)})}),env);
  const data=await result.json();assert.ok(!JSON.stringify(data).includes(env.GITHUB_TOKEN));return {status:result.status,data};
 };
 assert.equal((await call('/me',null)).status,401);
 assert.equal((await call('/me',await token(PLAYER,{exp:1}))).status,401);
 assert.equal((await call('/me',await token(PLAYER,{role:'anon'}))).status,401);
 assert.equal((await call('/me',await token(PLAYER,{iss:'https://evil.example/auth/v1'}))).status,401);
 assert.equal((await call('/me',tokens.player.slice(0,-10)+'aaaaaaaaaa')).status,401);
 assert.equal((await call('/me','player','GET',null,{Origin:'https://evil.example'})).status,403);
 assert.equal((await call('/me')).data.is_moderator,false);
 assert.equal((await call('/me','admin')).data.is_moderator,true);
 assert.equal((await call('/review')).status,403);
 assert.equal((await call('/submissions','player','POST',{...deck(),visibility:'private'})).status,400);
 assert.equal((await call('/submissions','player','POST',{...deck(),cards:[null]})).status,400);
 const duplicate=deck();duplicate.cards[1].name='CARTA 0';assert.equal((await call('/submissions','player','POST',duplicate)).data.error,'duplicate_card');
 const bad=deck();bad.cards[0].image=Buffer.from('<svg/>').toString('base64');assert.equal((await call('/submissions','player','POST',bad)).data.error,'invalid_image');
 assert.equal((await call('/submissions','player','POST',deck(),{'Content-Length':String(LIMITS.body+1)})).status,413);
 const submitted=await call('/submissions','player','POST',{...deck(),author:{nickname:'Impostor'},price:999});assert.equal(submitted.status,201);
 const id=submitted.data.submission.id;assert.equal(submitted.data.submission.status,'pending_review');assert.equal(submitted.data.submission.author.nickname,'Criador');
 const head=repo.refs.get('deck-inbox');assert.equal((await call('/submissions','player','POST',deck())).data.submission.id,id);assert.equal(repo.refs.get('deck-inbox'),head,'reenvio não grava outro commit');
 assert.equal((await call('/submissions/'+id,'other')).status,403);
 assert.equal((await call('/submissions/'+id+'/approve','player','POST',{})).status,403);
 const stored=JSON.stringify(repo.json('deck_submissions/'+id+'.json','deck-inbox'));assert.ok(!stored.includes(PLAYER));assert.ok(!stored.includes(tokens.player));
 const race=await Promise.all([call('/submissions/'+id+'/approve','admin','POST',{}),call('/submissions/'+id+'/approve','admin','POST',{})]);assert.ok(race.some(r=>r.status===200));assert.ok(race.every(r=>[200,409].includes(r.status)));assert.equal(repo.json('deck_submissions/'+id+'.json','deck-inbox').status,'publishing');
 assert.equal((await call('/submissions/'+id+'/reject','admin','POST',{reason:'Não aprovado'})).status,409);
 assert.equal((await call('/submissions/'+id+'/publish','admin','POST',{})).data.next,'finalize');
 const main=repo.refs.get('main');assert.equal(repo.json('data/community/approved_decks.json','main').decks.length,1);
 assert.equal((await call('/submissions/'+id+'/publish','admin','POST',{})).data.next,'finalize');assert.equal(repo.refs.get('main'),main,'retry não publica duas vezes');
 repo.rejectNextPatch=true;assert.equal((await call('/submissions/'+id+'/finalize','admin','POST',{})).status,409);
 assert.equal((await call('/submissions/'+id+'/finalize','admin','POST',{})).data.submission.status,'approved');
 assert.equal((await call('/submissions/'+id+'/approve','admin','POST',{})).data.next,'');
 const rejected=await call('/submissions','player','POST',deck('Outro deck'));
 const rid=rejected.data.submission.id;
 assert.equal((await call('/submissions/'+rid+'/reject','admin','POST',{reason:''})).status,400);
 assert.equal((await call('/submissions/'+rid+'/reject','admin','POST',{reason:'Revise o estilo das imagens.'})).data.submission.status,'rejected');
 assert.equal((await call('/submissions/'+rid)).data.submission.review_note,'Revise o estilo das imagens.');
 for(let i=0;i<3;i++)assert.equal((await call('/submissions','player','POST',deck('Pendente '+i))).status,201);
 assert.equal((await call('/submissions','player','POST',deck('Limite'))).status,429);
 const big=await call('/submissions','other','POST',{...deck('Trinta cartas',30),cover:{image:IMAGE}});assert.equal(big.status,201);
 const bid=big.data.submission.id;await call('/submissions/'+bid+'/approve','admin','POST',{});
 const before=repo.calls;assert.equal((await call('/submissions/'+bid+'/publish','admin','POST',{})).status,200);assert.ok(repo.calls-before<48,'publicação cabe no orçamento de subrequests da ponte');
 assert.equal(repo.json('assets/duel/decks/community/repo_'+bid.slice(0,24)+'/deck.json','main').cover,true);assert.equal(repo.json('assets/duel/decks/community/repo_'+bid.slice(0,24)+'/deck.json','main').price,0);assert.ok(profileCalls>0);assert.equal(repo.json('data/community/approved_decks.json','main').decks.length,2);
});
