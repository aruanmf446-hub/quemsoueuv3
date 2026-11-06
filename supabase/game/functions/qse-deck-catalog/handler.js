// Private, immutable approved previews. GAME JWTs go only to GAME.
const GAME='https://shuzporktifgiotvnpbz.supabase.co';
const CATALOG='https://bsxicvlngphazesuzaee.supabase.co';
const GAME_PUBLIC='sb_publishable_ZrugXVdGCXztHbMZiIX8Mw_K6Bg-uhW';
const BUCKET='qse-community-previews';
const UUID=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
const REF=/^community_[0-9a-f]{32}$/;
const cors={'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'authorization,apikey,content-type','Access-Control-Allow-Methods':'POST,OPTIONS','Cache-Control':'no-store'};
const reply=(body,status=200)=>new Response(JSON.stringify(body),{status,headers:{...cors,'Content-Type':'application/json'}});
class Failure extends Error {constructor(code){super(code);this.code=code;}}
const fail=code=>{throw new Failure(code);};
export function createHandler(config,transport=fetch){
 const headers=key=>({'apikey':key,'Authorization':'Bearer '+key,'Content-Type':'application/json'});
 const request=async(url,options={})=>{
  try{return await transport(url,{...options,redirect:'error',signal:AbortSignal.timeout(20000)});}catch{fail('backend_unavailable');}
 };
 const json=async(url,options)=>{
  const response=await request(url,options);
  if(!response.ok)fail(response.status===401?'unauthorized':response.status===429?'rate_limit':'backend_unavailable');
  const data=await response.json().catch(()=>null);if(data===null)fail('invalid_contract');
  if(typeof data.error==='string')fail(['deck_unavailable','deck_changed','deck_not_owned','forbidden','unauthorized'].includes(data.error)?data.error:'backend_unavailable');
  return data;
 };
 const rpc=(name,body,token)=>json(GAME+'/rest/v1/rpc/'+name,{method:'POST',headers:token?{...headers(GAME_PUBLIC),Authorization:'Bearer '+token}:headers(config.gameKey),body:JSON.stringify(body)});
 const sync=async(deckId)=>{
  const version=await rpc('qse_catalog_prepare',{p_deck:deckId});
  if(!UUID.test(version.version_id)||!version.manifest||!Array.isArray(version.source?.cards)||version.source.cards.length<5||version.source.cards.length>30)fail('invalid_contract');
  if(!version.ready){
   const jobs=[];
   for(const card of version.source.cards){
    if(!UUID.test(card.id))fail('invalid_contract');
    for(const kind of ['library','duel']){
     const source=card[kind+'_path'];
     if(typeof source!=='string'||!new RegExp('^[0-9a-f-]{36}/'+deckId+'/'+card.id+'_'+kind+'\\.png$').test(source))fail('invalid_contract');
     jobs.push({source,target:version.version_id+'/'+card.id+'_'+kind+'.png'});
    }
   }
   let cursor=0;
   await Promise.all(Array.from({length:Math.min(4,jobs.length)},async()=>{
    while(cursor<jobs.length){
     const {source,target}=jobs[cursor++];
     const response=await request(GAME+'/storage/v1/object/authenticated/qse-deck-originals/'+source,{headers:headers(config.gameKey)});
     if(!response.ok)fail('preview_unavailable');
     if(Number(response.headers.get('content-length'))>4194304)fail('preview_too_large');
     const reader=response.body.getReader(),chunks=[];let length=0;
     for(;;){const {done,value}=await reader.read();if(done)break;length+=value.byteLength;if(length>4194304){await reader.cancel();fail('preview_too_large');}chunks.push(value);}
     const bytes=new Uint8Array(length);let offset=0;for(const chunk of chunks){bytes.set(chunk,offset);offset+=chunk.byteLength;}
     if(length<8||!([137,80,78,71,13,10,26,10].every((n,i)=>bytes[i]===n)))fail('preview_invalid');
     const imageHeader=new DataView(bytes.buffer);
     if(length<24||imageHeader.getUint32(16)<1||imageHeader.getUint32(16)>2048||imageHeader.getUint32(20)<1||imageHeader.getUint32(20)>2048)fail('preview_invalid');
     const upload=await request(CATALOG+'/storage/v1/object/'+BUCKET+'/'+target,{method:'POST',headers:{...headers(config.catalogKey),'Content-Type':'image/png','x-upsert':'false'},body:bytes});
     // Concurrent preparations use the same immutable version, never overwrite.
     if(!upload.ok&&upload.status!==409)fail('catalog_unavailable');
    }
   }));
   await json(CATALOG+'/rest/v1/qse_catalog_community_versions?on_conflict=id',{method:'POST',headers:{...headers(config.catalogKey),'Prefer':'resolution=ignore-duplicates,return=representation'},body:JSON.stringify({id:version.version_id,deck_id:deckId,manifest:version.manifest})});
   const result=await rpc('qse_catalog_finalize',{p_version:version.version_id});
   if(result.ready!==true)fail('catalog_unavailable');
  }
  return version.version_id;
 };
 return async requestIn=>{
  if(requestIn.method==='OPTIONS')return new Response(null,{status:204,headers:cors});
  if(requestIn.method!=='POST')return reply({error:'method_not_allowed'},405);
  try{
   if(config.gameUrl!==GAME||config.catalogUrl!==CATALOG||!config.gameKey||!config.catalogKey)fail('not_configured');
   const auth=requestIn.headers.get('Authorization')||'';
   if(!auth.startsWith('Bearer ')||auth.length>8200)return reply({error:'unauthorized'},401);
   const token=auth.slice(7);
   const identity=await request(GAME+'/auth/v1/user',{headers:{apikey:GAME_PUBLIC,Authorization:auth}});
   if(!identity.ok)return reply({error:'unauthorized'},401);
   const user=await identity.json().catch(()=>null);
   if(!UUID.test(user?.id))return reply({error:'unauthorized'},401);
   if(Number(requestIn.headers.get('content-length'))>2048)return reply({error:'invalid_contract'},400);
   const reader=requestIn.body?.getReader(),chunks=[];let size=0;
   if(reader)for(;;){const {done,value}=await reader.read();if(done)break;size+=value.byteLength;if(size>2048){await reader.cancel();return reply({error:'invalid_contract'},400);}chunks.push(value);}
   const bytes=new Uint8Array(size);let at=0;for(const c of chunks){bytes.set(c,at);at+=c.byteLength;}
   const text=new TextDecoder().decode(bytes);
   const body=JSON.parse(text);
   if(body.action==='claim'){
    if(!UUID.test(body.deck_id))return reply({error:'invalid_contract'},400);
    const versionId=await sync(body.deck_id);
    const result=await rpc('qse_community_claim',{p_deck:body.deck_id,p_version:versionId},token);
    if(result.claimed!==true||result.deck_id!==body.deck_id||result.version_id!==versionId)fail('invalid_contract');
    return reply(result);
   }
   if(body.action==='manifests'){
    if(!Array.isArray(body.deck_refs)||body.deck_refs.length<1||body.deck_refs.length>5||!body.deck_refs.every(r=>typeof r==='string'&&REF.test(r))||new Set(body.deck_refs).size!==body.deck_refs.length)return reply({error:'invalid_contract'},400);
    const result=await rpc('qse_community_manifests',{p_refs:body.deck_refs},token);
    if(!Array.isArray(result.items)||result.items.length!==body.deck_refs.length)fail('invalid_contract');
    const paths=[];
    for(const item of result.items){
     if(!UUID.test(item.version_id)||!body.deck_refs.includes(item.id)||!Array.isArray(item.cards)||item.cards.length<5||item.cards.length>30)fail('invalid_contract');
     for(const card of item.cards)for(const kind of ['library','duel']){
      const path=card[kind+'_path'];
      if(typeof path!=='string'||!new RegExp('^'+item.version_id+'/[0-9a-f-]{36}_'+kind+'\\.png$').test(path))fail('invalid_contract');
      paths.push(path);
     }
    }
    const signed=await json(CATALOG+'/storage/v1/object/sign/'+BUCKET,{method:'POST',headers:headers(config.catalogKey),body:JSON.stringify({paths,expiresIn:3600})});
    if(!Array.isArray(signed))fail('invalid_contract');
    const urls=new Map();for(const row of signed){
     if(paths.includes(row.path)&&typeof row.signedURL==='string'&&row.signedURL.startsWith('/object/sign/'+BUCKET+'/')&&!row.error)urls.set(row.path,CATALOG+'/storage/v1'+row.signedURL);
    }
    if(urls.size!==paths.length)fail('preview_unavailable');
    for(const item of result.items)for(const card of item.cards)for(const kind of ['library','duel'])card[kind+'_url']=urls.get(card[kind+'_path']);
    return reply(result);
   }
   return reply({error:'invalid_contract'},400);
  }catch(error){
   const code=error instanceof Failure?error.code:'invalid_contract';
   return reply({error:code},code==='unauthorized'?401:code==='invalid_contract'?400:200);
  }
 };
}
