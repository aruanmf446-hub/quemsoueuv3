# T19 — reprodução e regressão Web

## Godot

```sh
godot --headless --editor --path . --import --quit
godot --headless --path . --script tests/web_t19/regression.gd
python3 tools/godot/run_smoke.py --godot /caminho/Godot_v4.7.2-stable_linux.x86_64 --output /tmp/t19-smoke
```

Use XDG_DATA_HOME/XDG_CONFIG_HOME/XDG_CACHE_HOME isolados. A regressão usa a navegação
real, MP3 original e um transporte falso somente nos testes. Inclui 20 idas e voltas,
tween interrompido, retorno rápido, véu órfão, download pendente, cache, anterior com
resposta tardia, fim de faixa e falha de rede. Nenhum token real ou backend é necessário.

## Navegador real

Exporte normalmente para Web com os templates 4.7.2, copie as pastas `music/` e
`loading/` como em `.github/workflows/deploy-web.yml` e sirva por HTTP em localhost.
O wrapper usa Playwright e Chromium; `CHROMIUM` pode apontar para outro executável.
Instale Playwright fora do projeto se não estiver disponível.

```sh
python3 -m http.server 8154 --directory build/web
node tests/web_t19/probe.cjs http://127.0.0.1:8154 /tmp/t19-844 844x390 600
node tests/web_t19/probe.cjs http://127.0.0.1:8154 /tmp/t19-1920 1920x1080
node tests/web_t19/probe.cjs http://127.0.0.1:8154 /tmp/t19-640 640x360
```

O último argumento é a duração do ensaio prolongado, em segundos. O wrapper:

- intercepta HTTP Supabase e semeia SOMENTE um refresh token de fixture;
- passa pelo código real de restauração, sem conta externa e sem OAuth real;
- usa os MP3s de verdade, atrasando o início de cada download em 900 ms;
- clica na UI real em 20 ciclos, quatro abas, volta, pausa/retoma e muda de faixa;
- exige áudio iniciado antes de continuar, faz F5 e verifica restauração;
- durante 600 s volta a Ajustes/Controles/lobby a cada ~15 s;
- salva JSON de métricas e captura real, sem serializar sessão/localStorage.

Os HTTP 503 nos registros são dos serviços simulados indisponíveis, não erros da
produção. O programa não chama APIs com credenciais reais. Feche os outros navegadores
na comparação de latência: SwiftShader é software e compartilha CPU/GPU emulada.
O tempo `open_ms` inclui animação e observação pelo probe, não apenas primeiro feedback.

## Diagnóstico opcional na aplicação

`?t19probe=1` habilita `window.QSE_PERF`. Sem esse parâmetro, o autoload desliga seu
processamento e não registra eventos. Os campos são apenas tempos, contagens, retângulos
de controles e booleanos. Não inclui tokens, e-mails, sessão, cookies ou parâmetros de rota.

No console, `QSE_PERF.events.filter(e => e.label.startsWith('mp3.'))` mostra o custo da
preparação e início; `QSE_PERF.busy` e `QSE_PERF.route` mostram a navegação.
`memory_bytes=0` na Web deste ambiente significa contador não suportado.
Não exporte localStorage ou dados de autenticação ao relatar um problema.
