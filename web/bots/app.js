"use strict";
(() => {
  const REPO = "aruanmf446-hub/quemsoueuv3";
  const API = "https://api.github.com/repos/" + REPO;
  const REFRESH_MS = 300000;
  const $ = id => document.getElementById(id);
  const state = { prs: [], runs: [], commits: [], issues: [], selected: "claude", tab: "overview", loaded: false, busy: false, fileCache: new Map() };
  const agents = [
    {id:"claude",name:"Claude Code",short:"C",role:"Godot, gameplay e implementação local",color:"#dba77e",place:"Branches claude/ e commits identificados como Claude Code",summary:"Implementação local via VS Code / Godot. O GitHub mostra apenas o trabalho publicado."},
    {id:"codex",name:"Codex",short:"⌘",role:"Código, integrações e revisão técnica",color:"#9ea7ff",place:"Branches codex/ e commits identificados como Codex",summary:"Alterações de código e verificações técnicas associadas a commits e PRs publicados."},
    {id:"work",name:"ChatGPT Work",short:"W",role:"Interface, coordenação e produto",color:"#85d4ba",place:"Branches work/ e commits identificados como Work",summary:"Atividades atribuíveis ao Work nas branches ou mensagens do projeto."}
  ];
  const escapeHtml = value => String(value ?? "").replace(/[&<>"']/g, char => ({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[char]));
  const safeLink = url => {
    try {
      const u = new URL(url);
      return u.protocol === "https:" && ["github.com","www.github.com"].includes(u.hostname) ? escapeHtml(u.href) : "#";
    } catch (_) { return "#"; }
  };
  const timeAgo = iso => {
    if (!iso) return "Sem registro";
    const t = new Date(iso).getTime(); if (!Number.isFinite(t)) return "—";
    const mins = Math.max(0,Math.floor((Date.now()-t)/60000));
    if (mins < 1) return "agora";
    if (mins < 60) return "há " + mins + " min";
    const hours=Math.floor(mins/60); if(hours<24) return "há "+hours+" h";
    const days=Math.floor(hours/24); if(days<30) return "há "+days+" d";
    return new Date(t).toLocaleDateString("pt-BR",{day:"2-digit",month:"short"});
  };
  const formattedDate = iso => iso ? new Date(iso).toLocaleString("pt-BR",{day:"2-digit",month:"short",hour:"2-digit",minute:"2-digit"}) : "—";
  const classify = (branch, title="", body="") => {
    const s=String(branch || "").toLowerCase();
    if(/^claude([/-]|$)/.test(s)) return "claude";
    if(/^codex([/-]|$)/.test(s)) return "codex";
    if(/^work([/-]|$)/.test(s)) return "work";
    const content=(String(title||"")+" "+String(body||"")).toLowerCase();
    if(/claude.code|claude-session|co-authored-by: claude/.test(content)) return "claude";
    if(/\bcodex\b/.test(content)) return "codex";
    if(/chatgpt.work/.test(content)) return "work";
    return "other";
  };
  const prAgent = pr => classify(pr.head?.ref,pr.title,pr.body);
  const commitAgent = commit => classify("",commit.commit?.message || "",commit.commit?.message || "");
  const agentLabel = id => (agents.find(a=>a.id===id)||{}).name || "Equipe / GitHub";
  const runState = run => {
    if (run.status !== "completed") return {text:"Em execução",icon:"↻",cls:"running"};
    if (run.conclusion === "success") return {text:"Aprovado",icon:"✓",cls:"success"};
    if (run.conclusion === "failure" || run.conclusion === "timed_out") return {text:"Falhou",icon:"!",cls:"failure"};
    return {text:run.conclusion === "cancelled"?"Cancelado":"Concluído",icon:"–",cls:""};
  };
  const empty = s => '<div class="empty">'+escapeHtml(s)+'</div>';
  const setHtml = (id, html) => { const node=$(id); if(node)node.innerHTML=html; };
  const isValidSession = () => sessionStorage.getItem("qse-bots-auth") === "yes";

  async function digestCredentials(username,pin,settings) {
    if (!crypto?.subtle) throw new Error("O navegador precisa de HTTPS para validar o PIN.");
    if (!Number.isInteger(settings.iterations) || settings.iterations < 100000 || !/^[a-f0-9]{32,}$/i.test(settings.salt)) throw new Error("Configuração de acesso inválida.");
    const salt = Uint8Array.from(settings.salt.match(/../g), n=>parseInt(n,16));
    const text = new TextEncoder().encode(username+"\u0000"+pin);
    const key = await crypto.subtle.importKey("raw",text,{name:"PBKDF2"},false,["deriveBits"]);
    const result = await crypto.subtle.deriveBits({name:"PBKDF2",salt,iterations:settings.iterations,hash:"SHA-256"},key,256);
    return [...new Uint8Array(result)].map(v=>v.toString(16).padStart(2,"0")).join("");
  }
  async function unlock(event) {
    event.preventDefault();
    const button=$("login-button"), msg=$("auth-message");
    button.disabled=true; msg.textContent="Verificando credenciais…";
    try {
      const response=await fetch("./auth.json",{cache:"no-store"});
      if (!response.ok) throw new Error("Login ainda não configurado no GitHub Pages. Verifique o deploy.");
      const cfg=await response.json();
      const attempted=await digestCredentials($("login-user").value.trim(),$("login-pin").value,cfg);
      const expected=String(cfg.digest||"").toLowerCase();
      if(expected.length!==64 || attempted.length!==expected.length || [...attempted].some((c,i)=>c!==expected[i])) {
        throw new Error("Usuário ou PIN incorreto.");
      }
      sessionStorage.setItem("qse-bots-auth","yes");
      $("login-pin").value="";
      showDashboard();
    } catch (e) {
      msg.textContent=e.message||"Não foi possível validar o acesso.";
    } finally {button.disabled=false;}
  }
  function showDashboard() {
    $("auth-view").classList.add("hidden");
    $("dashboard").classList.remove("hidden");
    if (!state.loaded) refresh();
  }
  function logout() {
    sessionStorage.removeItem("qse-bots-auth");
    $("dashboard").classList.add("hidden");
    $("auth-view").classList.remove("hidden");
    $("login-user").value="";$("login-pin").value="";$("auth-message").textContent="";
  }
  async function get(endpoint) {
    const controller=new AbortController();
    const timer=setTimeout(()=>controller.abort(),13000);
    try {
      const response=await fetch(API+endpoint,{signal:controller.signal,headers:{"Accept":"application/vnd.github+json","X-GitHub-Api-Version":"2022-11-28"},cache:"no-store"});
      if(response.status===403 || response.status===429)throw new Error("Limite de consultas públicas do GitHub atingido. Tente novamente mais tarde.");
      if(!response.ok)throw new Error("GitHub HTTP "+response.status+" em "+endpoint.split("?")[0]);
      return response.json();
    } finally {clearTimeout(timer);}
  }
  async function refresh() {
    if(!isValidSession() || state.busy)return;
    state.busy=true; $("refresh").disabled=true;
    const jobs=[
      ["prs","/pulls?state=open&sort=updated&direction=desc&per_page=50",x=>Array.isArray(x)?x:[]],
      ["runs","/actions/runs?per_page=30",x=>x.workflow_runs||[]],
      ["commits","/commits?sha=main&per_page=25",x=>Array.isArray(x)?x:[]],
      ["issues","/issues?state=open&sort=updated&per_page=30",x=>(Array.isArray(x)?x:[]).filter(i=>!i.pull_request)]
    ];
    const results=await Promise.allSettled(jobs.map(x=>get(x[1])));
    const problems=[];let successes=0;
    results.forEach((out,i)=>{
      if(out.status==="fulfilled"){state[jobs[i][0]]=jobs[i][2](out.value);successes++;}
      else problems.push(out.reason?.message || "Erro de consulta");
    });
    state.loaded=successes>0||state.loaded;
    $("api-health").className="connection "+(successes===jobs.length?"ok":successes?"ok":"fail");
    $("api-health").innerHTML='<span class="dot"></span> '+(successes===jobs.length?"DADOS ATUALIZADOS":successes?"DADOS PARCIAIS":"SEM CONEXÃO");
    const now=new Date().toLocaleString("pt-BR",{hour:"2-digit",minute:"2-digit",day:"2-digit",month:"2-digit"});
    if(successes)$("last-updated").textContent=now;
    const notice=$("notice");
    if(problems.length){notice.textContent="Algumas fontes não responderam: "+[...new Set(problems)].join(" · ")+" Os dados disponíveis podem estar incompletos.";notice.classList.remove("hidden");}
    else notice.classList.add("hidden");
    render();
    state.busy=false;$("refresh").disabled=false;
  }
  function recentAgentItems(id){
    const prs=state.prs.filter(p=>prAgent(p)===id);
    const commits=state.commits.filter(c=>commitAgent(c)===id);
    return {prs,commits,latest:[
      ...prs.map(p=>p.updated_at),
      ...commits.map(c=>c.commit?.committer?.date || c.commit?.author?.date)
    ].filter(Boolean).sort((a,b)=>new Date(b)-new Date(a))[0]};
  }
  function agentCard(a){
    const item=recentAgentItems(a.id);
    const title=item.prs[0]?.title || item.commits[0]?.commit?.message?.split("\n")[0] || "Nenhum trabalho recente identificado";
    const badge=item.prs.length?item.prs.length+" PR ABERTA"+(item.prs.length>1?"S":""):"SEM PR ABERTA";
    return '<button type="button" class="agent-card '+(state.selected===a.id&&state.tab==="agents"?"selected":"")+'" data-agent="'+a.id+'" style="--agent-color:'+a.color+'">'+
       '<div class="agent-top"><span class="agent-icon">'+a.short+'</span><span class="agent-state '+(item.prs.length?"active":"")+'">'+badge+'</span></div>'+
       '<div class="agent-name">'+escapeHtml(a.name)+'</div><div class="agent-role">'+escapeHtml(a.role)+'</div>'+
       '<div class="agent-divider"></div><div class="agent-task">'+escapeHtml(title)+'</div>'+
       '<div class="agent-foot"><span>'+escapeHtml(item.latest?timeAgo(item.latest):"Sem atualização identificada")+'</span><span><strong>Detalhes</strong> <span class="arrow">↗</span></span></div></button>';
  }
  function activityItems(){
    const commits=state.commits.map(c=>({
      id:"commit-"+c.sha,kind:"Commit",agent:commitAgent(c),title:c.commit?.message?.split("\n")[0]||"Commit",
      date:c.commit?.committer?.date||c.commit?.author?.date,url:c.html_url,
      detail:"main · "+String(c.sha||"").slice(0,8)
    }));
    const prs=state.prs.map(p=>({id:"pr-"+p.number,kind:"Pull request",agent:prAgent(p),title:p.title,date:p.updated_at,url:p.html_url,detail:"#"+p.number+" · "+(p.head?.ref||"branch não informada")}));
    const runs=state.runs.filter(r=>r.status!=="completed"||r.conclusion==="failure").map(r=>({
      id:"run-"+r.id,kind:"Pipeline",agent:"other",title:r.name||"Pipeline",date:r.updated_at||r.created_at,url:r.html_url,
      detail:"GitHub Actions · "+runState(r).text
    }));
    return [...commits,...prs,...runs].sort((a,b)=>new Date(b.date||0)-new Date(a.date||0));
  }
  function feedRow(event){
    const symbol=event.kind==="Commit"?"⌘":event.kind==="Pull request"?"⑂":"↻";
    return '<div class="feed-row"><div class="feed-icon">'+symbol+'</div><div class="feed-body">'+
       '<div class="feed-header"><strong>'+escapeHtml(event.kind)+' · '+escapeHtml(agentLabel(event.agent))+'</strong><time title="'+escapeHtml(formattedDate(event.date))+'">'+escapeHtml(timeAgo(event.date))+'</time></div>'+
       '<a class="feed-title" href="'+safeLink(event.url)+'" target="_blank" rel="noopener noreferrer">'+escapeHtml(event.title)+'</a>'+
       '<div class="feed-meta">'+escapeHtml(event.detail)+'</div></div></div>';
  }
  function runRow(run){
    const s=runState(run);
    return '<div class="run-row"><div class="status-icon '+s.cls+'">'+s.icon+'</div><div class="run-copy">'+
      '<a class="run-title" href="'+safeLink(run.html_url)+'" target="_blank" rel="noopener noreferrer">'+escapeHtml(run.name || "Workflow")+'</a>'+
      '<div class="run-meta">'+escapeHtml(s.text)+' · '+escapeHtml(run.head_branch||"—")+' · '+escapeHtml(run.event||"—")+'</div></div>'+
      '<time class="run-time" title="'+escapeHtml(formattedDate(run.updated_at || run.created_at))+'">'+escapeHtml(timeAgo(run.updated_at || run.created_at))+'</time></div>';
  }
  function prRow(pr){
    const id=Number(pr.number);
    return '<div class="task-row"><div class="task-header"><span class="task-no">#'+id+'</span><div class="task-copy">'+
       '<a class="task-title" href="'+safeLink(pr.html_url)+'" target="_blank" rel="noopener noreferrer">'+escapeHtml(pr.title)+'</a>'+
       '<div class="task-meta">Agente: '+escapeHtml(agentLabel(prAgent(pr)))+' · '+escapeHtml(pr.head?.ref||"—")+' → '+escapeHtml(pr.base?.ref||"main")+' · '+escapeHtml(timeAgo(pr.updated_at))+'</div>'+
       '<span class="task-label">PR aberta</span><button class="file-button" type="button" data-files="'+id+'">Ver arquivos alterados ↗</button>'+
       '<div id="files-'+id+'" class="files-output hidden"></div></div></div></div>';
  }
  function issueRow(issue){
    return '<div class="task-row"><div class="task-header"><span class="task-no">#'+Number(issue.number)+'</span><div class="task-copy">'+
      '<a class="task-title" href="'+safeLink(issue.html_url)+'" target="_blank" rel="noopener noreferrer">'+escapeHtml(issue.title)+'</a>'+
      '<div class="task-meta">Aberta · '+escapeHtml(timeAgo(issue.updated_at))+'</div>'+
      (issue.labels||[]).slice(0,4).map(x=>'<span class="task-label">'+escapeHtml(typeof x==="string"?x:x.name)+'</span>').join("")+'</div></div></div>';
  }
  function renderDetail(){
    const a=agents.find(a=>a.id===state.selected)||agents[0], data=recentAgentItems(a.id);
    let html='<div class="detail-header"><h3>'+escapeHtml(a.name)+' · O que está fazendo?</h3><span class="agent-state '+(data.prs.length?"active":"")+'">'+(data.prs.length?"PRs abertas":"Sem PR aberta")+'</span></div>'+
      '<p class="detail-sub">'+escapeHtml(a.summary)+'<br><strong>Onde:</strong> '+escapeHtml(a.place)+'.<br>'+
      '<strong>Última atividade identificada:</strong> '+escapeHtml(data.latest?formattedDate(data.latest):"nenhuma na amostra consultada")+'.</p>'+
      '<div class="section-kicker">TRABALHOS EM REVISÃO</div>';
    if(data.prs.length){
      html+=data.prs.map(p=>'<div class="detail-pr"><a href="'+safeLink(p.html_url)+'" target="_blank" rel="noopener noreferrer"><strong>#'+Number(p.number)+' · '+escapeHtml(p.title)+'</strong></a>'+
       '<small>'+escapeHtml(p.head?.ref||"—")+' → '+escapeHtml(p.base?.ref||"main")+' · '+escapeHtml(timeAgo(p.updated_at))+'</small>'+
       '<button type="button" class="file-button" data-files="'+Number(p.number)+'">Ver arquivos alterados ↗</button>'+
       '<div id="files-'+Number(p.number)+'" class="files-output hidden"></div></div>').join("");
    }else html+=empty("Nenhuma PR aberta atribuível a este agente. Isso não significa que ele esteja offline.");
    if(data.commits.length) html+='<div class="section-kicker detail-latest">COMMITS IDENTIFICADOS NA MAIN</div>'+data.commits.slice(0,4).map(c=>'<div class="mini-commit"><a href="'+safeLink(c.html_url)+'" target="_blank" rel="noopener noreferrer">'+escapeHtml(c.commit?.message?.split("\n")[0]||"Commit")+'</a><small>'+escapeHtml(timeAgo(c.commit?.committer?.date||c.commit?.author?.date))+'</small></div>').join("");
    setHtml("agent-detail",html);
  }
  async function loadFiles(num,button){
    const box=$("files-"+num);
    if(!box)return;
    if(!box.classList.contains("hidden")){box.classList.add("hidden");return;}
    box.classList.remove("hidden");
    const display=files=>'<div class="file-list">'+(files.length?files.slice(0,30).map(f=>'<div class="file-row"><span>'+escapeHtml(f.filename)+'</span><small>+'+Number(f.additions||0)+' / −'+Number(f.deletions||0)+'</small></div>').join(""):empty("Nenhum arquivo retornado."))+'</div>';
    if(state.fileCache.has(num)){box.innerHTML=display(state.fileCache.get(num));return;}
    box.textContent="Consultando arquivos no GitHub…";
    if(button)button.disabled=true;
    try{
      const files=await get("/pulls/"+num+"/files?per_page=100");
      state.fileCache.set(num,files);
      box.innerHTML=display(files);
    }catch(e){box.textContent="Não foi possível consultar os arquivos: "+e.message;}
    if(button)button.disabled=false;
  }
  function render(){
    const running=state.runs.filter(r=>r.status==="in_progress"||r.status==="queued"||r.status==="waiting");
    const failed=state.runs.filter(r=>r.status==="completed"&&r.conclusion==="failure");
    $("metric-prs").textContent=state.prs.length >=50?"50+":String(state.prs.length);
    $("metric-running").textContent=String(running.length);
    $("metric-failed").textContent=String(failed.length);
    $("metric-commits").textContent=String(state.commits.length);
    $("nav-agent-count").textContent=String(agents.length);
    const cards=agents.map(agentCard).join("");
    setHtml("overview-agents",cards);setHtml("all-agents",cards);
    const acts=activityItems();
    setHtml("overview-feed",acts.length?acts.slice(0,6).map(feedRow).join(""):empty("Nenhuma atividade disponível."));
    setHtml("activity-feed",(acts.filter(a=>$("activity-filter").value==="all"||a.agent===$("activity-filter").value).map(feedRow).join(""))||empty("Nenhuma atividade para este filtro."));
    setHtml("overview-runs",state.runs.length?state.runs.slice(0,6).map(runRow).join(""):empty("Nenhuma execução disponível."));
    setHtml("all-runs",state.runs.length?state.runs.map(runRow).join(""):empty("Nenhuma execução encontrada."));
    setHtml("all-prs",state.prs.length?state.prs.map(prRow).join(""):empty("Não existem pull requests abertas na amostra consultada."));
    setHtml("all-issues",state.issues.length?state.issues.map(issueRow).join(""):empty("Nenhuma issue aberta na amostra consultada."));
    renderDetail();
  }
  const pageData={
    overview:["Visão geral","Acompanhe as entregas, a operação dos agentes e o estado do projeto."],
    agents:["Agentes","Veja onde cada operador publicou trabalho, suas branches e tarefas associadas."],
    activity:["Atividades","Histórico dos commits, pull requests e pipelines rastreáveis no GitHub."],
    pipelines:["Pipelines","Execuções reais dos workflows e situação dos testes automatizados."],
    tasks:["Tarefas & PRs","Trabalho em revisão, branches abertas e backlog registrado."]
  };
  function openTab(key){
    if(!pageData[key])return;
    state.tab=key;
    document.querySelectorAll(".nav button[data-tab]").forEach(e=>e.classList.toggle("active",e.dataset.tab===key));
    document.querySelectorAll(".view").forEach(e=>e.classList.add("hidden"));
    $("view-"+key).classList.remove("hidden");
    $("page-title").innerHTML=escapeHtml(pageData[key][0])+' <span class="title-accent">.</span>';
    $("page-subtitle").textContent=pageData[key][1];
    $("breadcrumb-page").textContent=pageData[key][0];
    if(key==="agents")render();
    document.querySelector(".page-scroll").scrollTo({top:0,behavior:"smooth"});
  }
  function init(){
    $("auth-form").addEventListener("submit",unlock);
    $("toggle-pin").addEventListener("click",()=>{
      const input=$("login-pin");input.type=input.type==="password"?"text":"password";
      $("toggle-pin").setAttribute("aria-label",input.type==="password"?"Mostrar PIN":"Ocultar PIN");
    });
    $("logout").addEventListener("click",logout);
    $("refresh").addEventListener("click",refresh);
    $("activity-filter").addEventListener("change",render);
    document.addEventListener("click",event=>{
      const nav=event.target.closest("[data-tab]");if(nav){openTab(nav.dataset.tab);return;}
      const goto=event.target.closest("[data-goto]");if(goto){openTab(goto.dataset.goto);return;}
      const agent=event.target.closest("[data-agent]");if(agent){state.selected=agent.dataset.agent;openTab("agents");return;}
      const fileButton=event.target.closest("[data-files]");if(fileButton){loadFiles(Number(fileButton.dataset.files),fileButton);return;}
    });
    document.addEventListener("visibilitychange",()=>{
      if(!document.hidden && isValidSession() && state.loaded && Date.now()-lastRefresh>REFRESH_MS)refresh();
    });
    if(isValidSession())showDashboard();
    setInterval(()=>{if(!document.hidden && isValidSession())refresh();},REFRESH_MS);
  }
  let lastRefresh=0;
  const origRefresh=refresh;
  refresh=async function(){await origRefresh();lastRefresh=Date.now();};
  init();
})();
