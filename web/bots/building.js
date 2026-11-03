"use strict";
/* QSE Command Center — representação visual dos registros públicos do GitHub.
   Uma PR aberta NÃO comprova uma sessão de IA rodando; os indicadores
   diferenciam pipeline em execução, atualização recente e ausência de sinal. */
(() => {
  const esc = v => String(v ?? "").replace(/[&<>"']/g, s => ({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[s]));
  const agents = [
    {id:"work",label:"CHATGPT WORK",name:"Work",code:"03",symbol:"✧",color:"#8bdac4",job:"Direção visual · produto · interfaces"},
    {id:"codex",label:"CODEX",name:"Codex",code:"02",symbol:"⌘",color:"#9ca8ff",job:"Programação · revisão · integração"},
    {id:"claude",label:"CLAUDE CODE",name:"Claude",code:"01",symbol:"◇",color:"#e7b387",job:"Godot · desenvolvimento · testes"}
  ];
  function idFor(branch,message="") {
    const ref = String(branch || "").toLowerCase();
    if (/^claude([/-]|$)/.test(ref)) return "claude";
    if (/^codex([/-]|$)/.test(ref)) return "codex";
    if (/^work([/-]|$)/.test(ref)) return "work";
    const s = String(message).toLowerCase();
    if (/claude.code|claude-session|co-authored-by: claude/.test(s)) return "claude";
    if (/\bcodex\b/.test(s)) return "codex";
    if (/chatgpt.work/.test(s)) return "work";
    return "other";
  }
  const dateString = value => {
    if(!value) return "Sem registro recente";
    const d = new Date(value);
    if(!Number.isFinite(d.getTime())) return "Sem data";
    const minutes = Math.max(0,Math.floor((Date.now()-d.getTime())/60000));
    if(minutes < 2) return "agora";
    if(minutes < 60) return "há "+minutes+" min";
    if(minutes < 1440) return "há "+Math.floor(minutes/60)+" h";
    return "há "+Math.floor(minutes/1440)+" dias";
  };
  function getAgentInfo(agent, data) {
    const history = (data.history||[]).filter(p=>idFor(p.head?.ref,p.title+" "+p.body)===agent.id);
    const open = history.filter(p=>p.state==="open");
    const commits = (data.commits||[]).filter(c=>idFor("",c.commit?.message)===agent.id);
    const runs = (data.runs||[]).filter(run=>idFor(run.head_branch,run.display_title)===agent.id);
    const running = runs.filter(run=>run.status==="in_progress"||run.status==="queued"||run.status==="waiting");
    const times = [
      ...history.map(p=>p.updated_at),...commits.map(c=>c.commit?.committer?.date || c.commit?.author?.date),
      ...runs.map(run=>run.updated_at)
    ].filter(Boolean).sort((a,b)=>new Date(b)-new Date(a));
    const last = times[0]||null;
    const recent = last && Date.now()-new Date(last).getTime()<2*60*60*1000;
    const status = running.length ? "pipeline" : recent ? "recent" : "quiet";
    const headline = running.length ? "Pipeline executando" : recent ? "Atividade GitHub recente" : "Sem atividade recente";
    const task = open[0]?.title || history[0]?.title || commits[0]?.commit?.message?.split("\n")[0] || "Nenhuma tarefa atribuída na amostra.";
    const branch = open[0]?.head?.ref || history[0]?.head?.ref || "sem branch atribuída";
    return {agent,open,commits,history,runs,running,last,status,headline,task,branch};
  }
  function floor(info) {
    const {agent,open,last,status,headline,task,branch}=info;
    const glow = status!=="quiet"?" lit":"";
    const windows = [0,1,2,3].map((n)=>'<span class="tower-window tower-window-'+n+(status==="pipeline"?" illuminated":status==="recent"&&(n===0||n===2)?" illuminated":"")+'"><span class="tower-lamp"></span><span class="tower-desk"></span><span class="tower-monitor"></span></span>').join("");
    return '<button type="button" class="tower-floor '+status+glow+'" data-floor-agent="'+agent.id+'" style="--floor-accent:'+agent.color+'" aria-label="Abrir atividades de '+esc(agent.name)+'">'+
      '<span class="tower-floor-id">'+agent.code+'</span><span class="tower-interior">'+windows+'</span>'+
      '<span class="tower-profile"><span class="tower-symbol">'+agent.symbol+'</span><span class="tower-profile-text"><strong>'+esc(agent.label)+'</strong><small>'+esc(agent.job)+'</small></span></span>'+
      '<span class="tower-floor-meta"><span class="tower-signal '+status+'"><span class="signal-point"></span>'+esc(headline)+'</span>'+
      '<span class="tower-summary">'+esc(task)+'</span><span class="tower-branch">'+esc(branch)+'</span></span>'+
      '<span class="tower-chevron">↗</span>'+
    '</button>';
  }
  function report(infos) {
    const withOpen = infos.filter(x=>x.open.length).length;
    const running = infos.reduce((acc,x)=>acc+x.running.length,0);
    const last = infos.map(x=>x.last).filter(Boolean).sort((a,b)=>new Date(b)-new Date(a))[0];
    return '<div class="building-report-header"><span class="section-kicker">TELEMETRIA PÚBLICA</span><span class="report-pulse"></span></div>'+
      '<h3>Movimento<br><em>no estúdio.</em></h3>'+
      '<div class="building-report-stat"><strong>'+withOpen+'<small>/03</small></strong><span>Agentes com PR aberta<br><small>Não significa trabalhando agora</small></span></div>'+
      '<div class="building-report-stat"><strong>'+running+'</strong><span>Pipelines atribuídos<br>em execução agora</span></div>'+
      '<div class="report-rule"></div>'+
      '<div class="report-last"><span>ÚLTIMA ATIVIDADE IDENTIFICADA</span><strong>'+esc(dateString(last))+'</strong></div>'+
      '<div class="report-key"><span><i class="key-dot pipeline"></i> Pipeline em andamento</span><span><i class="key-dot recent"></i> Atividade nas últimas 2h</span><span><i class="key-dot quiet"></i> Sem sinal recente</span></div>'+
      '<p class="report-disclaimer">Os andares representam atividades <b>publicadas no GitHub</b>. A plataforma não informa quem está digitando ou programando localmente.</p>';
  }
  function render(data) {
    const floors = document.getElementById("building-floors");
    const summary = document.getElementById("building-report");
    if(!floors || !summary) return;
    const infos=agents.map(a=>getAgentInfo(a,data));
    floors.innerHTML=infos.map(floor).join("");
    summary.innerHTML=report(infos);
    const updated=document.getElementById("building-last-sync");
    if(updated) updated.textContent="Atualizado: "+new Date().toLocaleTimeString("pt-BR",{hour:"2-digit",minute:"2-digit"});
  }
  document.addEventListener("click",event => {
    const floor=event.target.closest("[data-floor-agent]");
    if(floor) window.dispatchEvent(new CustomEvent("qse-select-agent",{detail:{id:floor.dataset.floorAgent}}));
  });
  window.QSEBuilding = Object.freeze({render});
})();