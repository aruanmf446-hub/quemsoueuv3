/* Small update controller shared by the game shell and /atualizar/.
   Never removes IndexedDB, localStorage, sessions, drafts or saves. */
(function () {
  'use strict';
  const external = !!document.body.dataset.qseUpdateGame;
  const game = new URL(document.body.dataset.qseUpdateGame || './', location.href);
  const text = value => window.qseWebText ? window.qseWebText(value) : value;
  const safe = () => external || (!!window.qseSafeToUpdate && !window.qseStoryPlaying);
  let registration, registering, checking, registeredBuild, reloadRequested = false, lastCheck = 0;
  const watched = new WeakSet(), watchedRegistrations = new WeakSet();
  const state = { status: 'idle', current: external ? '' : window.qseBuild || '', latest: '', ready: false };
  window.qsePwa = window.qsePwa || {};
  function emit(status) {
    if (status) state.status = status;
    window.qsePwa.updateReady = state.ready;
    window.dispatchEvent(new CustomEvent('qse-update-state', {detail: {...state}}));
    render();
  }
  function ask(worker) {
    return new Promise(resolve => {
      if (!worker) return resolve(null);
      const channel = new MessageChannel();
      const timer = setTimeout(() => { channel.port1.close(); resolve(null); }, 2000);
      channel.port1.onmessage = event => { clearTimeout(timer); channel.port1.close(); resolve(event.data); };
      worker.postMessage('qse-build-status', [channel.port2]);
    });
  }
  function watch(worker) {
    if (!worker || watched.has(worker)) return;
    watched.add(worker);
    worker.addEventListener('statechange', () => {
      if (worker.state === 'installed') {
        setTimeout(() => {
          state.ready = !!registration.waiting;
          emit(state.ready ? 'ready' : 'current');
        }, 0);
      } else if (worker.state === 'activated' && external) {
        ask(worker).then(info => { if (info) state.current = info.build; state.ready = !!registration.waiting; emit(state.ready ? 'ready' : 'current'); });
      } else if (worker.state === 'redundant') {
        state.ready = !!registration.waiting;
        emit('error');
      }
    });
  }
  async function register() {
    if (registration && registeredBuild === state.latest) return registration;
    if (!('serviceWorker' in navigator)) throw new Error('unsupported');
    const script = new URL('sw.js', game);
    script.searchParams.set('build', state.latest);
    if (!registering) registering = navigator.serviceWorker.register(script.href,
      {scope: game.href, updateViaCache: 'none'}).then(reg => {
      registration = reg;
      registeredBuild = state.latest;
      if (!watchedRegistrations.has(reg)) reg.addEventListener('updatefound', () => { watch(reg.installing); if (external || state.current !== state.latest) emit('downloading'); });
      watchedRegistrations.add(reg);
      watch(reg.installing);
      watch(reg.waiting);
      state.ready = !!reg.waiting;
      if (state.ready) emit('ready');
      return reg;
    }).finally(() => { registering = null; });
    return registering;
  }
  async function check() {
    if (checking) return checking;
    lastCheck = Date.now();
    checking = (async () => {
      emit('checking');
      const abort = new AbortController(), timer = setTimeout(() => abort.abort(), 15000);
      try {
        const url = new URL('version.json', game);
        url.searchParams.set('qse_check', String(Date.now()));
        const response = await fetch(url, {cache:'no-store', credentials:'same-origin', signal:abort.signal});
        if (!response.ok) throw new Error('version');
        const version = await response.json();
        if (version.schema !== 1 || !/^[a-zA-Z0-9._-]{1,100}$/.test(version.build)) throw new Error('version');
        state.latest = version.build;
        const reg = await register();
        if (external) {
          const active = await ask(reg.active);
          if (active) state.current = active.build;
        }
        // Version detection is independent of downloading the large game package.
        if (state.current !== state.latest || reg.waiting) {
          emit(reg.waiting ? 'ready' : 'downloading');
          await reg.update();
          watch(reg.installing);
        }
        state.ready = !!reg.waiting;
        if (reg.installing) emit('downloading');
        else emit(state.ready ? 'ready' : (state.current === state.latest ? 'current' : 'downloading'));
      } catch (_) { emit(navigator.onLine === false ? 'offline' : 'error'); }
      finally { clearTimeout(timer); checking = null; }
      return {...state};
    })();
    return checking;
  }
  async function apply() {
    if (!safe()) { emit('unsafe'); return false; }
    try {
      const reg = await register(), worker = reg.waiting || reg.active;
      const info = await ask(worker);
      if (!safe()) { emit('unsafe'); return false; }
      if (!info || info.build !== state.latest) { await check(); return false; }
      // The external recovery page cannot decide whether another game tab is in a match.
      if (info.gameClients > (external ? 0 : 1)) { emit('close-game'); return false; }
      if (!reg.waiting) {
        if (info.build !== state.current || external) {
          if (external) location.assign(new URL('?qse_build=' + encodeURIComponent(info.build), game));
          else location.reload();
          return true;
        }
        return false;
      }
      reloadRequested = true;
      emit('applying');
      if (external) {
        const waiting = reg.waiting;
        waiting.addEventListener('statechange', () => {
          if (waiting.state === 'activated') location.assign(new URL('?qse_build=' + encodeURIComponent(info.build), game));
        });
      }
      reg.waiting.postMessage('qse-activate-update');
      return true;
    } catch (_) { emit('error'); return false; }
  }
  if ('serviceWorker' in navigator) {
    navigator.serviceWorker.addEventListener('controllerchange', () => {
      if (!external && reloadRequested && safe()) { reloadRequested = false; location.reload(); }
    });
    navigator.serviceWorker.addEventListener('message', event => {
      if (event.data && event.data.type === 'qse-update-progress' && event.data.build !== state.current) emit('downloading');
    });
  }
  const messages = {
    idle:'Verificar atualização', checking:'Verificando atualização…', downloading:'Baixando atualização…',
    ready:'Atualização pronta para instalar.', current:'Você está na versão mais recente.',
    offline:'Sem conexão. Tente novamente quando estiver online.', error:'Não foi possível verificar. Tente novamente.',
    unsafe:'Volte ao menu para reiniciar com segurança.', 'close-game':'Feche as outras abas e o app do jogo antes de atualizar.',
    applying:'Reiniciando para atualizar…'
  };
  function render() {
    const panel = document.getElementById('qse-update-panel');
    const status = document.getElementById('qse-update-status');
    if (status) status.textContent = text(messages[state.status] || messages.idle);
    for (const [id,value] of [['qse-current-build',state.current],['qse-latest-build',state.latest]]) {
      const node = document.getElementById(id); if (node) node.textContent = value || '—';
    }
    const confirm = document.getElementById('qse-update-apply');
    if (confirm) confirm.disabled = !safe() || !state.latest || ['checking','downloading','applying','offline','error'].includes(state.status) || !(state.ready || (external && state.current === state.latest));
    const checkingButton = document.getElementById('qse-update-check');
    if (checkingButton) checkingButton.disabled = state.status === 'checking' || state.status === 'applying';
    const chip = document.getElementById('qse-update');
    if (chip) {
      chip.style.display = safe() && ['downloading','ready'].includes(state.status) ? 'block' : 'none';
      chip.textContent = state.ready ? text('ATUALIZAÇÃO DISPONÍVEL — REINICIAR PARA ATUALIZAR') : text('Baixando atualização…');
    }
    if (panel && panel.open && !safe() && state.status === 'ready' && status) status.textContent = text(messages.unsafe);
  }
  function open() {
    const panel = document.getElementById('qse-update-panel');
    if (panel && panel.showModal && !panel.open) panel.showModal();
    check();
  }
  window.qseUpdates = { check, apply, open, getState: () => ({...state}) };
  window.qseCheckForUpdate = open;
  for (const [id,action] of [['qse-update',open],['qse-update-check',check],['qse-update-apply',apply],
    ['qse-update-close',() => document.getElementById('qse-update-panel').close()]]) {
    const node = document.getElementById(id); if (node) node.addEventListener('click', action);
  }
  if (!external) {
    check();
    const resume = () => { if (document.visibilityState === 'visible' && Date.now()-lastCheck > 3000) check(); };
    window.addEventListener('focus', resume);
    window.addEventListener('pageshow', resume);
    window.addEventListener('online', resume);
    document.addEventListener('visibilitychange', resume);
    window.addEventListener("qse-update-safety", render);
    window.addEventListener("qse-locale-changed", render);
  }
  render();
})();
