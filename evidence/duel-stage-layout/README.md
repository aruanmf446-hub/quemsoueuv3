# Evidências — Mata-Mata

Logs nativos: 55 verificações em cada um dos três tamanhos, zero falhas antes
do último ajuste do limite privado para 96. Capturas native640 mostram o renderer
real, enquanto os logs adicionais usam backend headless.

`web/`: Godot 4.7.2 exportado e executado no Chromium desktop; cinco screenshots
de tabuleiro/apresentação e quatro comparações de geometria. Na tentativa final,
turns/remove/hand/chat conservaram 168.95×302.25 por carta, sem AtlasTexture.
A mão Web é vazia; conteúdo de duas cartas foi exercitado apenas no nativo.

A validação Web completa **não passou**: o runner não encontrou AcceptSelection
após os cliques de seleção. Não alcançou os dois perfis iPhone. Ver limitações e
comandos em `tests/duel_stage_layout/README.md`; screenshots isoladas não comprovam
o fluxo inteiro nem funcionamento em aparelho físico.


## Publicação autorizada — 10/11/2026

O dono autorizou publicar o PR #121 na main. O runner Web foi corrigido para
exercitar a seleção real antes dos estados simulados e esperar o fim efetivo do
palco, incluindo o carregamento do modelo, em vez de aguardar 6,8 segundos fixos.
A falha anterior era do roteiro de teste: ele tentava clicar nas cartas enquanto
a apresentação ainda recebia os eventos. Não houve mudança do servidor online.

Nesta revisão: 57 verificações nativas por resolução (1672×941, 844×390 e
640×360), dez de transições e 91 da partida local completa, todas sem falhas.
Os testes foram executados com Godot 4.7.2 na cópia isolada já importada;
a primeira tentativa no worktree sem cache de classes não carregou PlayerServices.

Verificação adicional do relato mais recente: 62 checks por resolução, zero
falhas, incluindo vinte participantes sem alterar os limites de PlayersScroll,
BattleBoard, UtilityRail, BattleChat e PrivatePanel. A ordem da apresentação vem
de turn_order da autoridade; não há novo sorteio no cliente.

Regressão PWA nesta sessão: com o Chromium instalado, o runner passou as
verificações iniciais de registro/cache/manifest, mas parou em sw_test.js:45 com
"Failed to update a ServiceWorker ... unknown error ... fetching the script".
Não foi declarado aprovado; nenhum arquivo PWA foi alterado nesta entrega.

### Resultado Web final — aprovado nas três resoluções

Godot Web 4.7.2 no Chromium: 1672×941, 844×390/DPR3 e 640×360/DPR3.
Seleção real de duas cartas e confirmação por mouse/toque, arte completa,
geometria estável ao remover cartas/abrir mão/chat, duas imagens privadas
contidas e clipes anim_2/anim_3/anim_4 em palco separado: todos passaram,
sem erros de script ou página. Evidências atuais em
`evidence/duel-stage-layout/web-final/results.json` e capturas ao lado.
Isso substitui o resultado incompleto da bateria anterior descrito acima.
Não houve validação em aparelho físico nem sessão online real.
