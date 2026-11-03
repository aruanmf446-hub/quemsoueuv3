import { createClient } from "https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.118.0/+esm";
/* QSE content editor. Only public publishable keys in this file; RLS performs every authorization check.
   PIN from Github Pages does NOT confer editing permissions. */
const CONFIG={"gameUrl":"https://shuzporktifgiotvnpbz.supabase.co","gameKey":"sb_publishable_ZrugXVdGCXztHbMZiIX8Mw_K6Bg-uhW","catalogUrl":"https://bsxicvlngphazesuzaee.supabase.co","catalogKey":"sb_publishable_1JmcnJ7WLSJ3Y71XKG0Mqg_0wEMwc4Y","googleClientId":"174761608559-dsc1s4m7t013p5680etjb3q3rci3a33l.apps.googleusercontent.com"};
const sdk=createClient(CONFIG.gameUrl,CONFIG.gameKey,{auth:{persistSession:true,autoRefreshToken:true,detectSessionInUrl:true,flowType:"pkce",storageKey:"qse-editor-game-session"}});
const $=id=>document.getElementById(id);
const escapeHtml=str=>String(str??"").replace(/[&<>"']/g,ch=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[ch]));
const state={user:null,authorized:false,view:"news",rows:[],catalog:[],current:null,pendingImage:null,busy:false};
function alertUser(message,error=false){const el=$("editor-alert");el.textContent=message;el.classList.remove("hidden");el.classList.toggle("error",error);}
function clearAlert(){$("editor-alert").classList.add("hidden");}
function isImagePath(path){return /^covers\/[a-zA-Z0-9_/-]{1,120}\.(webp|png|jpg|jpeg)$/.test(String(path||""));}
function imageUrl(path){return isImagePath(path)?CONFIG.gameUrl+"/storage/v1/object/public/qse-editor-media/"+path:"";}
const rowFor=(kind,id)=>state.rows.find(x=>x.kind===kind&&x.id===id);
const officialList=()=>state.catalog.map(d=>({
 id:"deck:"+d.id,kind:"deck",title:d.name,description:d.description||"",subtitle:d.metadata?.category||"Coleção oficial",
 priority:0,active:false,cover_path:"",fromCatalog:true,
 ...rowFor("deck","deck:"+d.id)
}));
const newsList=()=>state.rows.filter(r=>r.kind==="news").sort((a,b)=>(b.priority||0)-(a.priority||0));
function items(){return state.view==="deck"?officialList():newsList();}
const dateReadable=d=>d?new Date(d).toLocaleString("pt-BR",{day:"2-digit",month:"short",hour:"2-digit",minute:"2-digit"}):"—";
function setStatus(message){$("save-feedback").textContent=message;}
function formDisabled(disabled){$("save-content").disabled=disabled;}
function setWorking(flag){state.busy=flag;$("save-content").disabled=flag||!state.current;$("refresh-content").disabled=flag;}
function formatLocalDate(iso){if(!iso)return "";const d=new Date(iso);if(!Number.isFinite(d.getTime()))return "";const n=new Date(d.getTime()-d.getTimezoneOffset()*60000);return n.toISOString().slice(0,16);}
function humanName(row){return row.title||row.id.replace(/^(news|deck):/,"").replaceAll("_"," ");}
function renderIndex(){
 const rows=items(),term=$("index-search").value.trim().toLowerCase(),list=$("item-list");list.innerHTML="";
 const filtered=rows.filter(d=>(d.title+" "+d.id+" "+d.description).toLowerCase().includes(term));
 for(const entry of filtered){
  const button=document.createElement("button");button.className="item-btn"+(state.current?.id===entry.id?" active":"");
  button.type="button";
  const cover=imageUrl(entry.cover_path);
  const mini='<div class="item-miniart">'+(cover?'<img alt="" src="'+escapeHtml(cover)+'">':(entry.kind==="deck"?"▤":"✦"))+'</div>';
  button.innerHTML=mini+'<div class="item-name-stack"><div class="item-name">'+escapeHtml(humanName(entry))+'</div><div class="item-info">'+escapeHtml(entry.id)+' · '+(entry.fromCatalog?"Capa padrão":entry.active?"Publicado":"Rascunho")+'</div></div><i class="item-state '+(entry.active?"live":"")+'"></i>';
  button.addEventListener("click",()=>selectItem(entry));list.appendChild(button);
 }
 if(!filtered.length)list.innerHTML='<p class="list-loading">Nenhum item encontrado. Use “+ Nova” para adicionar uma notícia.</p>';
 $("count-news").textContent=newsList().length;
 $("count-deck").textContent=state.catalog.length;
 $("list-title").textContent=state.view==="news"?"Novidades":"Decks oficiais";
 $("new-news").hidden=state.view!=="news";
 const all=state.rows;
 $("kpi-all").textContent=all.length;
 $("kpi-live").textContent=all.filter(x=>x.active).length;
 $("kpi-date").textContent=all.length?dateReadable([...all].sort((a,b)=>new Date(b.updated_at||0)-new Date(a.updated_at||0))[0].updated_at):"—";
}
function selectItem(item){
 state.current={...item};state.pendingImage=null;
 $("editing-name").textContent=humanName(item);$("editing-id").textContent=item.id;
 $("field-title").value=item.title||"";$("field-subtitle").value=item.subtitle||"";
 $("field-description").value=item.description||"";$("field-priority").value=item.priority??0;
 $("field-start").value=formatLocalDate(item.starts_at);$("field-end").value=formatLocalDate(item.ends_at);
 $("field-active").checked=!!item.active;$("field-cover").value="";
 $("publish-explain").textContent=item.kind==="deck"?"Apenas a personalização ativa substitui a capa e os textos locais; não oculta o deck.":"Ativar mostra esta notícia no carrossel do jogo.";
 $("cover-file-name").textContent=item.cover_path?"Capa vinculada: "+item.cover_path:"Sem capa personalizada; será usada a arte padrão.";
 updatePreview();renderIndex();setStatus("Edite e clique em Salvar e publicar.");formDisabled(false);
}
function updatePreview(){
 const item=state.current;if(!item)return;
 const title=$("field-title").value,subtitle=$("field-subtitle").value,description=$("field-description").value;
 $("preview-title").textContent=title||"Título da publicação";
 $("preview-eyebrow").textContent=subtitle||"QUEM SOU EU";
 $("preview-description").textContent=description||"Adicione uma descrição.";
 const art=$("preview-art");let src=state.pendingImage?URL.createObjectURL(state.pendingImage):imageUrl(item.cover_path);
 if(art.dataset.previewUrl?.startsWith("blob:"))URL.revokeObjectURL(art.dataset.previewUrl);
 art.dataset.previewUrl=src;art.style.backgroundImage=src?'linear-gradient(180deg,#0f1b2c11,#111c2a11),url("'+src+'")':"";
 art.querySelector(".preview-default").style.display=src?"none":"";
 const active=$("field-active").checked;
 $("editing-status").className="status-chip"+(active?" live":"");$("editing-status").textContent=active?"PUBLICADO":"RASCUNHO / DESATIVADO";
}
function createNews(){
 const slug=crypto.randomUUID().replaceAll("-","").slice(0,10);
 state.view="news";document.querySelectorAll("[data-view]").forEach(b=>b.classList.toggle("active",b.dataset.view==="news"));
 $("index-search").value="";
 selectItem({id:"news:"+slug,kind:"news",title:"",subtitle:"",description:"",cover_path:"",active:false,priority:0});
 $("field-title").focus();
}
async function refreshAll(keepSelection=true){
 if(!state.authorized)return;
 $("refresh-content").disabled=true;clearAlert();
 const [contents,catalog]=await Promise.all([
  sdk.from("qse_editor_content").select("*").order("priority",{ascending:false}).limit(300),
  fetch(CONFIG.catalogUrl+"/rest/v1/qse_catalog_decks?select=id,name,description,metadata,visibility&visibility=eq.public&order=name.asc",{headers:{apikey:CONFIG.catalogKey},cache:"no-store"}).then(async r=>{if(!r.ok)throw new Error("CATALOG "+r.status);return r.json()}).catch(error=>{alertUser("Os decks oficiais não puderam ser carregados do CATALOG: "+error.message,true);return []})
 ]);
 if(contents.error)throw contents.error;
 state.rows=contents.data||[];state.catalog=Array.isArray(catalog)?catalog:[];
 renderIndex();
 if(keepSelection&&state.current){
  const current=items().find(x=>x.id===state.current.id);
  if(current){selectItem(current);}else{state.current=null;formDisabled(true);}
 }else if(items().length)selectItem(items()[0]);
 $("refresh-content").disabled=false;
}
async function checkAccount(){
 const {data:{user},error}=await sdk.auth.getUser();
 if(error||!user){showLogin();return;}
 const {data, error:roleError}=await sdk.from("qse_editor_admins").select("user_id").eq("user_id",user.id).maybeSingle();
 if(roleError||!data){await sdk.auth.signOut();showLogin();alertUser("Esta conta não possui permissão de editor. Use o login de administrador do GAME.",true);return;}
 state.user=user;state.authorized=true;$("login-panel").classList.add("hidden");$("editor-panel").classList.remove("hidden");
 $("sign-out").hidden=false;$("session-label").textContent=user.email||"Administrador";
 try{await refreshAll(false);}catch(e){alertUser("Erro ao carregar o conteúdo: "+e.message,true);}
}
function showLogin(){state.authorized=false;state.user=null;state.current=null;$("login-panel").classList.remove("hidden");$("editor-panel").classList.add("hidden");$("sign-out").hidden=true;}
async function credentialCallback(response){
 try{clearAlert();const {error}=await sdk.auth.signInWithIdToken({provider:"google",token:response.credential});
 if(error)throw error;await checkAccount();}catch(e){alertUser("Falha no login Google: "+e.message,true);}
}
async function googleButton(){
 for(let tries=0;tries<18;tries++){
  if(window.google?.accounts?.id){
   window.google.accounts.id.initialize({client_id:CONFIG.googleClientId,callback:credentialCallback,auto_select:false});
   window.google.accounts.id.renderButton($("google-login"),{theme:"filled_black",shape:"pill",size:"large",text:"signin_with",width:300});
   return;
  }
  await new Promise(resolve=>setTimeout(resolve,350));
 }
 $("google-login").textContent="Login Google indisponível neste navegador. Use e-mail e senha abaixo.";
}
async function emailLogin(event){
 event.preventDefault();clearAlert();
 const email=$("login-email").value.trim(),password=$("login-password").value;
 const {error}=await sdk.auth.signInWithPassword({email,password});
 $("login-password").value="";
 if(error){alertUser("Não foi possível entrar: "+error.message,true);return;}
 await checkAccount();
}
async function save(event){
 event.preventDefault();if(!state.current||!state.authorized||state.busy)return;clearAlert();setWorking(true);
 const item=state.current;
 try{
  const title=$("field-title").value.trim(),desc=$("field-description").value.trim();
  if(!title)throw Error("Informe o título.");
  const starts_at=$("field-start").value?new Date($("field-start").value).toISOString():null;
  const ends_at=$("field-end").value?new Date($("field-end").value).toISOString():null;
  if(starts_at&&ends_at&&new Date(ends_at)<=new Date(starts_at))throw Error("A data final precisa ser posterior ao início.");
  let path=item.cover_path||"";
  if(state.pendingImage){
   const image=state.pendingImage;if(!["image/webp","image/png","image/jpeg"].includes(image.type)||image.size>8388608)throw Error("Envie uma imagem JPG, PNG ou WebP de até 8 MB.");
   const extension=image.type==="image/webp"?"webp":image.type==="image/png"?"png":"jpg";
   path="covers/"+crypto.randomUUID()+"."+extension;
   setStatus("Enviando capa ao Supabase…");
   const uploaded=await sdk.storage.from("qse-editor-media").upload(path,image,{cacheControl:"3600",upsert:false,contentType:image.type});
   if(uploaded.error)throw uploaded.error;
  }
  const record={id:item.id,kind:item.kind,title,subtitle:$("field-subtitle").value.trim(),description:desc,
   cover_path:path,priority:Number($("field-priority").value)||0,active:$("field-active").checked,
   starts_at,ends_at,updated_by:state.user.id,updated_at:new Date().toISOString()};
  setStatus("Validando permissão e salvando…");
  const saved=await sdk.from("qse_editor_content").upsert(record,{onConflict:"id"}).select().single();
  if(saved.error)throw saved.error;
  state.current=saved.data;state.pendingImage=null;
  alertUser("Salvo no Supabase GAME. As mudanças serão lidas no jogo ao abrir novamente a tela correspondente.");
  await refreshAll(true);setStatus("Salvo com sucesso · "+dateReadable(saved.data.updated_at));
 }catch(e){alertUser("Não foi possível publicar: "+e.message,true);setStatus("Publicação não confirmada.");}
 finally{setWorking(false);}
}
async function init(){
 $("login-form").addEventListener("submit",emailLogin);
 $("sign-out").addEventListener("click",async()=>{await sdk.auth.signOut();showLogin();clearAlert();});
 $("refresh-content").addEventListener("click",async()=>{try{await refreshAll(true);}catch(e){alertUser(e.message,true);}});
 document.querySelectorAll("[data-view]").forEach(button=>button.addEventListener("click",()=>{
  state.view=button.dataset.view;$("index-search").value="";state.current=null;
  document.querySelectorAll("[data-view]").forEach(b=>b.classList.toggle("active",b===button));
  renderIndex();if(items().length)selectItem(items()[0]);else{formDisabled(true);$("editing-name").textContent="Nenhum item";$("editing-id").textContent="Crie uma novidade para começar";}
 }));
 $("new-news").addEventListener("click",createNews);
 $("index-search").addEventListener("input",renderIndex);
 for(const id of ["field-title","field-subtitle","field-description","field-active","field-priority"]){$(id).addEventListener("input",()=>{updatePreview();setStatus("Alterações ainda não publicadas.");});}
 $("field-cover").addEventListener("change",event=>{
  const file=event.target.files?.[0];if(!file)return;
  if(!["image/webp","image/png","image/jpeg"].includes(file.type)||file.size>8388608){alertUser("Capa inválida. Use PNG, WebP ou JPEG de até 8 MB.",true);event.target.value="";return;}
  state.pendingImage=file;$("cover-file-name").textContent=file.name+" · "+(file.size/1048576).toFixed(1)+" MB";updatePreview();setStatus("Imagem selecionada; salve para enviar.");
 });
 $("content-form").addEventListener("submit",save);
 formDisabled(true);
 await googleButton();
 try{await checkAccount();}catch(e){showLogin();alertUser("Falha ao verificar sessão: "+e.message,true);}
}
init();
