# Revisão de ambientes e pedestais — para avaliação

Base: `d0ae424`. Branch: `codex/ambientes-pedestais`. **Publicação na main autorizada pelo proprietário em 05/11/2026.**

## Resultado para o jogador

- Quinze módulos existentes avaliados e reaproveitados; nenhum asset novo.
- Dez fases com conjuntos de casas, lojas, praças, jardins, fortificações, ruínas
  e instalações de mineração. Três variantes por região, camadas de profundidade
  e aproximações com respiro, em vez de apenas reduzir uma taxa de espaçamento.
- Cada composição fica dentro de uma laje real, atrás da pista; marcos do plano
  têm prioridade. Os telhados da fase 2, o portal somente no fim da fase 9 e o
  espaço central da arena foram preservados.
- Coletar fogo, vida, defesa ou habilidades remove somente o item. O pedestal
  permanece e pertence ao chunk; ao revisitar, a base volta sem duplicar e sem
  recriar a recarga consumida. Capacidade cheia mantém o coletável disponível.
- Modelos, animações, física, controles, habilidades, desbloqueios, comprimento e
  balanceamento não foram alterados. Menus, música, backend e autenticação intactos.

## Capturas reais

- [Dez ambientes, desktop](painel_desktop.jpg).
- [Dez ambientes, iPhone horizontal emulado no motor](painel_iphone.jpg).
- [Bazar antes](bazar_antes_fixture.jpg) / [depois](desktop/fase_03_distrito05_fixture.jpg).
- [Jardins do Oásis](desktop/fase_05_distrito05_fixture.jpg).
- [Pedestal antes da coleta](pedestal_antes_fixture.jpg) / [depois](pedestal_depois_fixture.jpg).
- [Fase 9 no início, sem portal](desktop/fase_09.jpg) / [portal final](desktop/fase_09_portal_final_fixture.jpg).

As capturas usam Godot 4.7.2 Compatibility, Xorg e Mesa llvmpipe. As imagens do
setor 5 e do portal final são **fixtures teleportadas**, com invulnerabilidade
para inspeção: não representam travessia. A dupla do pedestal usa coleta chamada
pela fixture. Os JPGs preservam o quadro, sem recorte; as legendas dos painéis
ficam fora das capturas. Nenhuma imagem foi gerada por IA.

Foram produzidas 42 capturas nativas: desktop 1672×941 e iPhone 844×390 com o
perfil `--iphone`. Há dez quadros representativos de cada perfil e os extremos
da fase 9 nesta pasta. A área segura, base e UI aprovadas não foram modificadas.

## Validação

| Verificação | Resultado |
| --- | --- |
| Pedestais: seis tipos, cheio/coleta/sinal único, descarregar/revisitar/reinício | 60/60 |
| Composições: limites da laje, aquecimento, variantes e IDs únicos em até cinco chunks | 100/100 |
| Instalação dos quinze assets e marcos das dez fases | 86/86 |
| Galerias nativas desktop/iPhone | 21 capturas por perfil, sem erro de script |
| `reino10`, checkpoints, travessias reais 03 e 10 | aprovados |
| `check_design.py` e `scope_test.py` | aprovados |

As travessias usam entradas e coleta reais, sem teleporte ou invulnerabilidade.
Foram escolhidas Bazar e arena para cobrir o cenário representativo e a fase 10,
sem repetir todas as travessias já aprovadas na base. A montagem mantém a fila
existente de 1 ms por processamento, até cinco chunks ativos, até cinco peças
por grupo, texturas compartilhadas e nenhuma nova luz ou sombra dinâmica.
Isso não é um benchmark nem garantia de FPS em aparelho físico.

### Falha que já existe na base

`reino_v3_test.gd` passa 83/84 verificações e falha em
**“descarregar chunks preserva perseguidores vivos”**. A mesma falha foi reproduzida
usando os quatro scripts originais de `d0ae424` em staging isolado, antes da
exportação da fixture. [Log da base](baseline_reino_v3.log) e
[log da revisão](regressions/reino-v3.log). Não alteramos gameplay nem relaxamos
essa verificação para ocultá-la. As demais regressões selecionadas passaram.

Há avisos de ObjectDB no encerramento de alguns testes. Os testes de descarte
verificam os grupos de nós após remover os chunks e sair da fase; não restam
pedestais nem arte nos grupos. Os logs originais estão incluídos.

## Reprodução nativa

Requer Godot 4.7.2 e diretórios `XDG_DATA_HOME`, `XDG_CONFIG_HOME`, `XDG_CACHE_HOME`
isolados e graváveis. Capturas requerem display gráfico; testes de lógica aceitam headless.

```bash
GODOT=/caminho/Godot_v4.7.2-stable_linux.x86_64
python3 tools/player_ui/check_design.py
python3 tests/desert_night/scope_test.py
"$GODOT" --headless --path . --script res://tests/desert_night/pedestal_test.gd
"$GODOT" --headless --path . --script res://tests/desert_night/composition_test.gd
"$GODOT" --headless --path . --script res://tests/desert_night/approved_assets_test.gd
python3 tests/desert_night/run.py --godot "$GODOT" --only reino-v3 reino10 checkpoints route-03 route-10
"$GODOT" --path . --audio-driver Dummy --script res://tests/desert_night/reino_v3_gallery.gd -- /tmp/capturas 1672x941
QSE_TEST_IPHONE=1 "$GODOT" --path . --audio-driver Dummy --script res://tests/desert_night/reino_v3_gallery.gd -- /tmp/capturas-iphone 844x390 --iphone
"$GODOT" --path . --audio-driver Dummy --script res://tests/desert_night/pedestal_capture.gd -- /tmp/pedestais
```

## Web isolado, sem backend

A fixture usa as cenas e recursos reais, templates oficiais 4.7.2, Chromium com UA
iPhone, viewport 844×390, DPR 3 e toque. Todo destino externo é bloqueado antes
que uma requisição saia. Não testa Supabase, OAuth nem aparelho físico. O GPU é
SwiftShader por software; os tempos não medem desempenho de iPhone.

Reprodução: exportar uma cópia de staging, nunca trocar o projeto de produção:

```bash
mkdir -p /tmp/revisao-stage /tmp/revisao-web/quemsoueuv3
git archive codex/ambientes-pedestais | tar -x -C /tmp/revisao-stage
touch /tmp/revisao-stage/.iphone_web_fixture_stage
"$GODOT" --headless --path /tmp/revisao-stage --editor --import --quit
"$GODOT" --headless --path /tmp/revisao-stage --script res://tests/desert_night/make_web_fixture.gd
"$GODOT" --headless --path /tmp/revisao-stage --export-release Web /tmp/revisao-web/quemsoueuv3/index.html
cp -R /tmp/revisao-stage/web/loading /tmp/revisao-web/quemsoueuv3/
cp -R /tmp/revisao-stage/web/pwa /tmp/revisao-web/quemsoueuv3/
cp /tmp/revisao-stage/web/pwa/manifest.webmanifest /tmp/revisao-web/quemsoueuv3/
python3 tools/web/stamp_sw.py /tmp/revisao-web/quemsoueuv3 revisao-local
# Em outro terminal, manter o servidor local ativo:
python3 -m http.server 8135 --bind 127.0.0.1 --directory /tmp/revisao-web
# Terminal do teste, Playwright e Chromium instalados:
QSE_DESERT_WEB_OUT=/tmp/web-evidencias node tests/desert_night/web_desert_probe.cjs
```

O probe verifica leitura de oito quadros por toque, dash, replay, desbloqueios,
perseguição nos telhados e arte das dez fases. A extensão desta rodada aproxima
um ator de um item de ataque real; a física efetua a coleta e o relatório exige
um pedestal restante e zero coletáveis com aquele ID. Esse trecho é identificado
como fixture, sem alegar percurso nem validação de telefone físico.

### Resultado Web final

As dez fases passaram no Chromium emulado (844×390, DPR 3). O relatório final tem `errors=[]`, `engineErrors=[]` e `blocked=[]`; o perfil iPhone foi reconhecido (`iphone=true`). Após a coleta real por contato: `pedestal_count=1`, `pickup_count=0`, `pedestal_collected=true`. [Relatório](web/report.json), [log](web/console.log) e [captura do pedestal no Web](web/pedestal_after_collection_fixture.jpg). Também houve uma rodada Web anterior aprovada; a rodada registrada aqui usa a composição final, após aproximar os núcleos de jardins e mineração.
