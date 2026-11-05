// Ponte Fetch API: GAME JWT -> fila GitHub -> aprovação humana -> assets no repositório.
// Sem R2/KV/SQL, geração automática ou cobrança. Segredos existem somente no servidor.
export const LIMITS = Object.freeze({cards:30, minCards:5, image:768*1024, total:6*1024*1024, body:9*1024*1024});
const enc=new TextEncoder(), dec=new TextDecoder();
const ID=/^[a-f0-9]{32}$/, UUID=/^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/i;
const CATEGORIES=['Lendas e terror','Personagens','Animais','Lugares','Objetos','Outros'];
const INDEX='deck_submissions/queue.json', MANIFEST='data/community/approved_decks.json';
class Problem extends Error {constructor(code,status=400){super(code);this.code=code;this.status=status;}}
const fail=(code,status=400)=>{throw new Problem(code,status);};
const text=(v,min,max)=>{if(typeof v!=='string'||v.trim().length<min||v.trim().length>max||/[\u0000-\u001f\u007f]/u.test(v))fail('invalid_submission');return v.trim();};
function base64(bytes){let value='';for(let i=0;i<bytes.length;i+=16384)value+=String.fromCharCode(...bytes.subarray(i,i+16384));return btoa(value);}
function unbase64(value){if(typeof value!=='string'||!/^[A-Za-z0-9+/]*={0,2}$/.test(value)||value.length%4)fail('invalid_image');try{return Uint8Array.from(atob(value),c=>c.charCodeAt(0));}catch{fail('invalid_image');}}
const b64url=s=>unbase64(s.replace(/-/g,'+').replace(/_/g,'/')+'='.repeat((4-s.length%4)%4));
const hex=bytes=>Array.from(bytes,x=>x.toString(16).padStart(2,'0')).join('');
async function digest(crypto,value){return hex(new Uint8Array(await crypto.subtle.digest('SHA-256',typeof value==='string'?enc.encode(value):value)));}
function webp(bytes){
 if(bytes.length<26||bytes.length>LIMITS.image||dec.decode(bytes.subarray(0,4))!=='RIFF'||dec.decode(bytes.subarray(8,12))!=='WEBP')fail('invalid_image');
 const d=new DataView(bytes.buffer,bytes.byteOffset,bytes.byteLength);
 if(d.getUint32(4,true)+8!==bytes.length)fail('invalid_image');
 let dimensions=null,codec=false;
 for(let at=12;at+8<=bytes.length;){
  const tag=dec.decode(bytes.subarray(at,at+4)),length=d.getUint32(at+4,true),start=at+8;
  if(start+length>bytes.length||['ANIM','ANMF'].includes(tag))fail('invalid_image');
  let size=null;
  if(tag==='VP8X'){if(length<10||(bytes[start]&2))fail('invalid_image');const n=i=>bytes[i]+bytes[i+1]*256+bytes[i+2]*65536;size=[n(start+4)+1,n(start+7)+1];}
  if(tag==='VP8 '){if(length<10||bytes[start+3]!==0x9d||bytes[start+4]!==1||bytes[start+5]!==0x2a)fail('invalid_image');size=[d.getUint16(start+6,true)&16383,d.getUint16(start+8,true)&16383];codec=true;}
  if(tag==='VP8L'){if(length<5||bytes[start]!==0x2f)fail('invalid_image');const bits=d.getUint32(start+1,true);size=[(bits&16383)+1,((bits>>>14)&16383)+1];codec=true;}
  if(size){if(!size[0]||!size[1]||size[0]>2048||size[1]>2048||size[0]*size[1]>4000000)fail('invalid_image');if(dimensions&&(dimensions[0]!==size[0]||dimensions[1]!==size[1]))fail('invalid_image');dimensions=size;}
  at=start+length+(length&1);
 }
 if(!dimensions||!codec)fail('invalid_image');return dimensions;
}
function crop(value={}){if(!value||typeof value!=='object'||Array.isArray(value))fail('invalid_submission');const out={x:0.5,y:0.5,zoom:1};for(const key of Object.keys(out)){if(value[key]!==undefined){if(typeof value[key]!=='number'||!Number.isFinite(value[key]))fail('invalid_submission');out[key]=value[key];}}if(out.x<0||out.x>1||out.y<0||out.y>1||out.zoom<0.35||out.zoom>6)fail('invalid_submission');return out;}
async function payload(crypto,body){
 if(!body||typeof body!=='object'||!Array.isArray(body.cards)||body.cards.length<LIMITS.minCards||body.cards.length>LIMITS.cards)fail('invalid_submission');
 if(body.visibility!=='public')fail('invalid_submission');
 const name=text(body.name,3,60),description=text(body.description||'',0,400),category=text(body.category,1,50);
 if(!CATEGORIES.includes(category))fail('invalid_submission');
 const cards=[],names=new Set();let total=0;
 for(const row of body.cards){
  if(!row||typeof row!=='object'||Array.isArray(row))fail('invalid_submission');
  const cardName=text(row.name,1,40),key=cardName.normalize('NFC').toLocaleLowerCase();if(names.has(key))fail('duplicate_card');names.add(key);
  if(typeof row.image!=='string'||row.image.length>Math.ceil(LIMITS.image/3)*4)fail('image_too_large');
  const bytes=unbase64(row.image);webp(bytes);total+=bytes.length;if(total>LIMITS.total)fail('deck_too_large');
  cards.push({name:cardName,description:text(row.description||'',0,300),image:row.image,sha256:await digest(crypto,bytes),crops:{library:crop(row.crops?.library),duel:crop(row.crops?.duel)}});
 }
 let cover=null;
 if(body.cover){if(typeof body.cover.image!=='string'||body.cover.image.length>Math.ceil(LIMITS.image/3)*4)fail('image_too_large');const bytes=unbase64(body.cover.image);webp(bytes);total+=bytes.length;if(total>LIMITS.total)fail('deck_too_large');cover={image:body.cover.image,sha256:await digest(crypto,bytes)};}
 return {visibility:'public',name,description,category,style_reference:text(body.style_reference||'lendas_urbanas',1,60),cards,cover};
}
class GitHub {
 constructor(env,fetcher){this.env=env;this.fetch=fetcher;this.base='https://api.github.com/repos/'+env.GITHUB_REPOSITORY;}
 async api(path,method='GET',body=null,missing=false,raw=false){
  const response=await this.fetch(this.base+path,{method,redirect:'error',headers:{Authorization:'Bearer '+this.env.GITHUB_TOKEN,Accept:raw?'application/vnd.github.raw+json':'application/vnd.github+json','X-GitHub-Api-Version':'2022-11-28','User-Agent':'QSE-Deck-Repository','Content-Type':'application/json'},...(body===null?{}:{body:JSON.stringify(body)})});
  if(missing&&response.status===404)return null;
  if(!response.ok){if(response.status===409||response.status===422)fail('retry_conflict',409);fail('repository_unavailable',502);}
  return response.status===204?{}:response.json();
 }
 async head(branch){const ref=await this.api('/git/ref/heads/'+encodeURIComponent(branch));const commit=await this.api('/git/commits/'+ref.object.sha);return {sha:ref.object.sha,tree:commit.tree.sha};}
 async json(path,ref,fallback=null){const row=await this.api('/contents/'+path+'?ref='+encodeURIComponent(ref),'GET',null,true,true);return row===null?fallback:row;}
 async blob(content,encoded=false){return (await this.api('/git/blobs','POST',{content:encoded?content:base64(enc.encode(JSON.stringify(content))),encoding:'base64'})).sha;}
 async commit(branch,head,files,message){
  const tree=[];for(const file of files)tree.push({path:file.path,mode:'100644',type:'blob',sha:file.sha||await this.blob(file.json)});
  const created=await this.api('/git/trees','POST',{base_tree:head.tree,tree});
  const commit=await this.api('/git/commits','POST',{message,tree:created.sha,parents:[head.sha]});
  await this.api('/git/refs/heads/'+encodeURIComponent(branch),'PATCH',{sha:commit.sha,force:false});return commit.sha;
 }
 async inbox(){
  const ref=await this.api('/git/ref/heads/'+encodeURIComponent(this.env.INBOX_BRANCH),'GET',null,true);
  if(!ref){const main=await this.head(this.env.MAIN_BRANCH);try{await this.api('/git/refs','POST',{ref:'refs/heads/'+this.env.INBOX_BRANCH,sha:main.sha});}catch(error){if(error.code!=='retry_conflict')throw error;}}
  return this.head(this.env.INBOX_BRANCH);
 }
 async record(id){if(!ID.test(id))fail('not_found',404);const head=await this.head(this.env.INBOX_BRANCH);const record=await this.json('deck_submissions/'+id+'.json',head.sha);if(!record)fail('not_found',404);return {head,record};}
 async update(head,record,message){
  const index=await this.json(INDEX,head.sha,{schema_version:1,items:[]});
  index.items=index.items.filter(row=>row.id!==record.id);index.items.push(summary(record));
  await this.commit(this.env.INBOX_BRANCH,head,[{path:'deck_submissions/'+record.id+'.json',json:record},{path:INDEX,json:index}],message);
 }
}
function summary(record){return {id:record.id,name:record.payload.name,author:record.author,owner:record.owner,status:record.status,count:record.payload.cards.length,created_at:record.created_at,review_note:record.review_note||'',published_commit:record.published_commit||''};}
export function createHandler({fetch:fetcher=globalThis.fetch,crypto=globalThis.crypto,now=()=>Date.now()}={}){
 const keyCache=new Map();
 async function identity(request,env){
  const auth=request.headers.get('Authorization')||'';if(!auth.startsWith('Bearer '))fail('not_authenticated',401);
  const token=auth.slice(7);if(token.length>12000)fail('not_authenticated',401);
  try{
   const parts=token.split('.');if(parts.length!==3)fail('not_authenticated',401);
   const header=JSON.parse(dec.decode(b64url(parts[0]))),claims=JSON.parse(dec.decode(b64url(parts[1]))),seconds=now()/1000;
   if(!['RS256','ES256'].includes(header.alg)||typeof header.kid!=='string'||header.crit||header.b64===false||claims.iss!==env.GAME_URL+'/auth/v1'||claims.role!=='authenticated'||!UUID.test(claims.sub)||!(claims.aud==='authenticated'||Array.isArray(claims.aud)&&claims.aud.includes('authenticated'))||typeof claims.exp!=='number'||!Number.isFinite(claims.exp)||claims.exp<=seconds||claims.nbf!==undefined&&(typeof claims.nbf!=='number'||claims.nbf>seconds+30))fail('not_authenticated',401);
   let keys=keyCache.get(env.GAME_URL);if(!keys||keys.expires<now()){
    const response=await fetcher(env.GAME_URL+'/auth/v1/.well-known/jwks.json',{signal:AbortSignal.timeout(8000)});if(!response.ok)fail('auth_unavailable',503);
    const data=await response.json();if(!Array.isArray(data.keys))fail('auth_unavailable',503);keys={keys:data.keys,expires:now()+300000};keyCache.set(env.GAME_URL,keys);
   }
   const jwk=keys.keys.find(key=>key.kid===header.kid&&(!key.alg||key.alg===header.alg));if(!jwk)fail('not_authenticated',401);
   const algorithm=header.alg==='RS256'?{name:'RSASSA-PKCS1-v1_5',hash:'SHA-256'}:{name:'ECDSA',namedCurve:'P-256'};
   const key=await crypto.subtle.importKey('jwk',jwk,algorithm,false,['verify']);
   if(!await crypto.subtle.verify(header.alg==='RS256'?algorithm:{name:'ECDSA',hash:'SHA-256'},key,b64url(parts[2]),enc.encode(parts[0]+'.'+parts[1])))fail('not_authenticated',401);
   const response=await fetcher(env.GAME_URL+'/rest/v1/rpc/qse_profile_self',{method:'POST',signal:AbortSignal.timeout(10000),headers:{apikey:env.GAME_PUBLISHABLE_KEY,Authorization:auth,'Content-Type':'application/json'},body:'{}'});
   if(!response.ok)fail('auth_unavailable',503);const profile=await response.json();
   if(profile.user_id!==claims.sub||typeof profile.public_id!=='string'||!profile.public_id.startsWith('QSE-')||typeof profile.nickname!=='string'||profile.nickname.trim().length<3)fail('nickname_required',403);
   return {owner:await digest(crypto,claims.iss+'|'+claims.sub),author:{public_id:profile.public_id,nickname:profile.nickname},moderator:(env.MODERATOR_PUBLIC_IDS||'').split(',').map(s=>s.trim()).filter(Boolean).includes(profile.public_id)};
  }catch(error){if(error instanceof Problem)throw error;fail('not_authenticated',401);}
 }
 return async function handler(request,env){
  const origin=request.headers.get('Origin'),allowed=(env.ALLOWED_ORIGINS||'https://aruanmf446-hub.github.io').split(',').map(s=>s.trim());
  const headers={'Content-Type':'application/json; charset=utf-8','Cache-Control':'no-store','X-Content-Type-Options':'nosniff',Vary:'Origin',...(origin&&allowed.includes(origin)?{'Access-Control-Allow-Origin':origin}:{}),'Access-Control-Allow-Headers':'Authorization, Content-Type','Access-Control-Allow-Methods':'GET, POST, OPTIONS'};
  const reply=(body,status=200)=>new Response(JSON.stringify(body),{status,headers});
  try{
   if(origin&&!allowed.includes(origin))fail('forbidden_origin',403);
   if(request.method==='OPTIONS')return new Response(null,{status:204,headers});
   const path=new URL(request.url).pathname.replace(/\/$/,'')||'/';
   if(path==='/health')return reply({service:'qse-deck-repository',price:0,configured:!!(env.GITHUB_TOKEN&&env.GAME_PUBLISHABLE_KEY&&env.MODERATOR_PUBLIC_IDS)});
   if(!env.GITHUB_TOKEN||!env.GAME_PUBLISHABLE_KEY||!env.MODERATOR_PUBLIC_IDS||!/^[-\w.]+\/[-\w.]+$/.test(env.GITHUB_REPOSITORY||'')||!/^https:\/\/[-a-z0-9]+\.supabase\.co$/.test(env.GAME_URL||'')||!/^[-\w]+$/.test(env.MAIN_BRANCH||'')||!/^[-\w]+$/.test(env.INBOX_BRANCH||'')||env.MAIN_BRANCH===env.INBOX_BRANCH)fail('bridge_not_configured',503);
   const user=await identity(request,env),git=new GitHub(env,fetcher);
   if(path==='/me'&&request.method==='GET')return reply({author:user.author,is_moderator:user.moderator,price:0});
   if(path==='/submissions'&&request.method==='GET'){
    const head=await git.inbox(),index=await git.json(INDEX,head.sha,{items:[]});return reply({items:index.items.filter(row=>row.owner===user.owner).sort((a,b)=>b.created_at.localeCompare(a.created_at)).slice(0,50)});
   }
   if(path==='/submissions'&&request.method==='POST'){
    const declared=Number(request.headers.get('Content-Length')||0);if(declared>LIMITS.body)fail('deck_too_large',413);
    const reader=request.body?.getReader();if(!reader)fail('invalid_submission');let size=0;const chunks=[];while(true){const chunk=await reader.read();if(chunk.done)break;size+=chunk.value.byteLength;if(size>LIMITS.body){await reader.cancel();fail('deck_too_large',413);}chunks.push(chunk.value);}const bytes=new Uint8Array(size);let offset=0;for(const chunk of chunks){bytes.set(chunk,offset);offset+=chunk.length;}
    let raw;try{raw=JSON.parse(dec.decode(bytes));}catch{fail('invalid_submission');}
    const value=await payload(crypto,raw),fingerprint=await digest(crypto,JSON.stringify(value)),id=(await digest(crypto,user.owner+'|'+fingerprint)).slice(0,32);
    const head=await git.inbox(),existing=await git.json('deck_submissions/'+id+'.json',head.sha);
    if(existing)return reply({submission:summary(existing)});
    const index=await git.json(INDEX,head.sha,{items:[]}),mine=index.items.filter(row=>row.owner===user.owner);
    if(mine.filter(row=>['pending_review','publishing'].includes(row.status)).length>=3||mine.filter(row=>Date.parse(row.created_at)>now()-86400000).length>=5)fail('submission_limit',429);
    const record={schema_version:1,id,owner:user.owner,author:user.author,created_at:new Date(now()).toISOString(),status:'pending_review',fingerprint,payload:value};
    await git.update(head,record,'deck: receber envio '+id);return reply({submission:summary(record)},201);
   }
   if(path==='/review'&&request.method==='GET'){
    if(!user.moderator)fail('forbidden',403);const head=await git.inbox(),index=await git.json(INDEX,head.sha,{items:[]});return reply({items:index.items.filter(row=>['pending_review','publishing'].includes(row.status)).sort((a,b)=>a.created_at.localeCompare(b.created_at)).slice(0,50)});
   }
   const match=path.match(/^\/submissions\/([a-f0-9]{32})(?:\/(approve|publish|finalize|reject))?$/);
   if(!match)fail('not_found',404);
   if(match[2]&&!user.moderator)fail('forbidden',403);
   const {head,record}=await git.record(match[1]),action=match[2];
   if(!action&&request.method==='GET'){
    if(!user.moderator&&record.owner!==user.owner)fail('forbidden',403);return reply({submission:record});
   }
   if(request.method!=='POST')fail('method_not_allowed',405);
   if(!user.moderator)fail('forbidden',403);
   if(action==='approve'){
    if(record.status==='approved')return reply({submission:summary(record),next:''});
    if(record.status==='publishing')return reply({submission:summary(record),next:'publish'});
    if(record.status!=='pending_review')fail('invalid_status',409);
    // Claim atômico: rejeição concorrente não pode vencer depois do início da publicação.
    record.status='publishing';record.reviewer=user.author.public_id;
    await git.update(head,record,'deck: iniciar aprovação '+record.id);return reply({submission:summary(record),next:'publish'});
   }
   if(action==='reject'){
    if(record.status==='rejected')return reply({submission:summary(record)});
    if(record.status!=='pending_review')fail('invalid_status',409);
    const length=Number(request.headers.get('Content-Length')||0);if(length>4096)fail('invalid_submission');
    const body=await request.text();if(body.length>4096)fail('invalid_submission');let data;try{data=JSON.parse(body);}catch{fail('invalid_submission');}
    record.review_note=text(data.reason,3,280);record.status='rejected';record.reviewer=user.author.public_id;
    await git.update(head,record,'deck: reprovar envio '+record.id);return reply({submission:summary(record)});
   }
   if(action==='publish'){
    if(record.status==='approved')return reply({submission:summary(record),next:''});
    if(record.status!=='publishing')fail('invalid_status',409);
    const main=await git.head(env.MAIN_BRANCH),manifest=await git.json(MANIFEST,main.sha,{schema_version:1,decks:[]}),known=manifest.decks.find(row=>row.id==='repo_'+record.id.slice(0,24));
    if(known){if(known.fingerprint!==record.fingerprint)fail('publication_conflict',409);return reply({submission:summary(record),next:'finalize'});}
    const checked=await payload(crypto,record.payload);if(await digest(crypto,JSON.stringify(checked))!==record.fingerprint)fail('publication_conflict',409);
    const folder='assets/duel/decks/community/repo_'+record.id.slice(0,24),files=[],cards={};
    for(let i=0;i<checked.cards.length;i++){
     const card=checked.cards[i],cardId='card_'+String(i+1).padStart(2,'0'),sha=await git.blob(card.image,true);
     files.push({path:folder+'/'+cardId+'.webp',sha});cards[cardId]={name:card.name,description:card.description,crops:card.crops};
    }
    if(checked.cover)files.push({path:folder+'/cover.webp',sha:await git.blob(checked.cover.image,true)});
    const deck={cover:!!checked.cover,name:checked.name,description:checked.description,category:checked.category,creator:record.author.nickname,creator_public_id:record.author.public_id,visibility:'public',published_at:new Date(now()).toISOString(),price:0,cards};
    manifest.decks.push({id:'repo_'+record.id.slice(0,24),fingerprint:record.fingerprint,published_at:new Date(now()).toISOString()});
    files.push({path:folder+'/deck.json',json:deck},{path:MANIFEST,json:manifest});
    const commit=await git.commit(env.MAIN_BRANCH,main,files,'deck: publicar coleção aprovada '+record.id);
    return reply({submission:summary(record),next:'finalize',published_commit:commit});
   }
   if(action==='finalize'){
    if(record.status==='approved')return reply({submission:summary(record),next:''});
    if(record.status!=='publishing')fail('invalid_status',409);
    const main=await git.head(env.MAIN_BRANCH),manifest=await git.json(MANIFEST,main.sha,{decks:[]});
    if(!manifest.decks.some(row=>row.id==='repo_'+record.id.slice(0,24)&&row.fingerprint===record.fingerprint))fail('publication_pending',409);
    record.status='approved';record.published_commit=main.sha;record.review_note='';record.reviewed_at=new Date(now()).toISOString();
    await git.update(head,record,'deck: concluir aprovação '+record.id);return reply({submission:summary(record),next:''});
   }
   fail('not_found',404);
  }catch(error){return reply({error:error instanceof Problem?error.code:'service_unavailable'},error instanceof Problem?error.status:503);}
 };
}
export default {fetch:createHandler()};
