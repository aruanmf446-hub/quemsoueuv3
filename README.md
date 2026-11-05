# Quem Sou Eu V3 — Reino do Deserto

## Estado atual — dez fases com os assets aprovados

Os quinze módulos aprovados estão integrados às dez fases: casario, mercado,
aqueduto, oásis, ruínas, fortificações e mineração. Percursos, colisões, perseguição
e personagens3D preservados. O dono autorizou publicar esta versão na main
em05/11/2026, substituindo a apresentação anterior do Reino do Deserto.

Veja [estrutura e regras](docs/desert/REINO_10_FASES.md),
[evidências atuais](evidence/ten-approved/README.md) e
[catálogo por fase](docs/desert/assets/LOTE_GRANDE.md).
A publicação é feita pelo [deploy-web.yml](https://github.com/aruanmf446-hub/quemsoueuv3/actions/workflows/deploy-web.yml)
no [Pages](https://aruanmf446-hub.github.io/quemsoueuv3/). Confira a execução
correspondente ao commit da main; a autorização não substitui o resultado do deploy.
As seções históricas abaixo registram etapas anteriores à autorização de publicação
e não substituem as evidências da integração atual.


## Bot assistido de assets

[Fila e instruções](tools/asset_pipeline/desert_bot/README.md): gera argumentos para
image_gen na conversa, registra fontes/hashes e prepara texturas no Godot. Biblioteca com15 módulos, incluindo o lote grande de10 novos assets. Veja a
[galeria e distribuição por fase](docs/desert/assets/LOTE_GRANDE.md):63 âncoras resolvidas no Godot e instaladas nas fases. Não é serviço24h nem
publica/integra os assets sozinho. Lotes padrão de dois; grandes só quando pedidos.

## Ajuste de parkour e progressão após reprovação

Na mesma branch de revisão: congelamento para trás a partir da fase3, corrida com
choque na4 e Ruptura na5. Guardas reposicionados após abastecimento e obstáculos
baixos acrescentados aos telhados; vida/ataque/defesa mantidos no percurso.
Os conceitos aprovados estão em [art-approved](docs/desert/art-approved/).
Fases1/2 agora recebem fundo gerado de dunas, cidade e palácio, além de bandeiras
com o emblema de chama existente, toldos e detalhes urbanos fora da pista.
As fachadas aprovadas agora são módulos do cenário; veja o estado atual acima.

## Reforma das dez fases — revisão separada

Branch `work/reino-deserto-10-fases`, baseada na main `967a408`.
Dez percursos modulares implementados; perseguição nos telhados, contato dos
inimigos, poderes e apoio das recargas corrigidos. Modelos originais preservados.
Dez travessias completas e 17 etapas do runner aprovadas; export Web e teste
Chromium com perfil iPhone executados. Sem merge ou publicação nesta rodada.

Veja [implementação e pendências](docs/desert/REINO_10_FASES.md) e
[capturas reais e resultados](evidence/reino-10-fases/README.md).
Ainda dependem de revisão o acabamento visual frente à referência, o balanceamento
(~4min08–4min39 no piloto) e aparelhos físicos. Os resultados abaixo são da
**entrega anterior**, já publicada, e não substituem as evidências desta branch.

## Desenvolvimento atual

Branch `work/reino-deserto-v3`, baseada em `b10be149ba2d332a44cc1dcbb4c1ebe9aaaff3d6`.
O dono confirmou o escopo completo do pacote: nove fases, perseguição em tropas,
três cargas e três poderes, além da intro, roteiro, legendas e carregamento durante a leitura.
O desenvolvimento foi retomado; este documento registra o resultado e as pendências.
Em 05/11/2026, o dono autorizou integrar toda esta entrega diretamente à `main`.
A publicação no Pages é executada pelo workflow `deploy-web.yml`; o resultado
de cada execução deve ser conferido no GitHub Actions.

## Implementado

- Nove fases com oito distritos cada, três planos ilustrativos, arquitetura próxima,
  telhados, aquedutos, oásis, ruínas e área de mineração. Modelos, skins, FBX,
  animações oficiais e controlador da fase 10 preservados.
- Reserva persistente de oito Cactus, ondas atrás da câmera, salto baixo com
  aterrissagem validada e parada em abismos e muros.
- Até três cargas por ação; Ruptura abre uma peça de chão e restaura após oito
  segundos; Âmbar imobiliza por 3,5 segundos; Relâmpago impulsiona por 1,15 segundo.
  Descobertas garantidas nas fases 2/4/6, salvas localmente. Dano, morte, Defesa
  e pausa interrompem o impulso. Percursos conservam o mínimo calculado de 180 segundos.
- HUD com ações circulares, teclado, mouse, joystick e multitoque. Defesa corrigida
  nos dois caminhos; pausa com alvo de toque ampliado; rótulos sem cortes no iPhone.
- Oito cenas de origem com o roteiro solicitado e legendas nativas, capas das nove
  fases, releitura explícita e preferência local para não repetir automaticamente.
  Recursos carregam enquanto o jogador lê; Web sem threads aquece um recurso por quadro.
- Convite HTML de instalação oculto durante intro/partida para não cobrir os controles,
  restaurado ao sair. Estilos continuam em PlayerUI; exceção de layout somente no iPhone.

Detalhes: [fases e poderes](docs/desert/REINO_V3.md),
[intro](docs/presentation/STORY_V3.md), [evidências](evidence/reino-v3/README.md).

## Validações executadas

Godot **4.7.2.stable.official.ed1daf0bf**, perfis locais isolados e sem backend.

- Mecânicas: **84 verificações, zero falhas**. Controles reais: **10, zero falhas**.
- Runner final: **14 etapas aprovadas**, incluindo layout, fase 10, progresso,
  regras desktop/toque, variedade, parkour, checkpoints e travessias 1/3/6/9.
- As nove travessias completas passaram após os ajustes físicos de itens/chão.
  A rodada final de quatro fases também inclui os últimos cenários/HUD.
- **54 capturas finais** das fases: início e distrito 5, em desktop 1672×941,
  iPhone 844×390 e janela padrão 640×360. O ponto intermediário é uma fixture
  teleportada, identificada; não serve de prova de travessia.
- Guarda iPhone: **504 verificações, zero falhas**, mais **108 capturas** dos nove modelos.
- Intro: 67 verificações por perfil em três perfis; navegação, geometria,
  cancelamento e fluxo registrados em [evidence/story-v3](evidence/story-v3/README.md).
- WebAssembly real em Chromium com UA iPhone, 844×390 e DPR 3: oito quadros por toque,
  leitura sem avanço automático, dash e persistência de leitura/habilidades após reload.
- Export de produção separado da fixture; regressões locais de duelo/batalha aprovadas,
  captura de batalha iPhone gerada; PWA **29 verificações, zero falhas**; design checker aprovado.

## Pendências e limites

1. Validar Safari/PWA em iPhone físico e versões Android/Windows. Emulação Web e
   capturas do motor não demonstram comportamento nesses aparelhos.
2. Avaliar picos de processamento em hardware real: p95 das quatro travessias finais
   ficou entre 2,7 e 4,6 ms, mas houve pico de 1,04 s no ambiente headless/software.
   Esses números não constituem benchmark de renderização em aparelho.
3. As ilustrações de cenário fornecidas no ZIP são provisórias. Conferir direção
   artística antes de substituir por arte final; preservar modelos e identidades oficiais.
4. Fixtures de encerramento imediato ainda registram avisos intermitentes de objetos
   de áudio WAV/playback no ObjectDB. Não houve erro de script; investigar ciclo de áudio
   ao encerrar/reabrir sessões prolongadas, sem confundir isso com validação de aparelho.
5. Conferir o resultado do deploy desta entrega no Pages e validar o PWA instalado.
   O dono autorizou integração direta na `main`, dispensando a PR pendente. A rede
   deste ambiente permite Git, mas continua bloqueando `api.github.com`.

Publicações: https://github.com/aruanmf446-hub/quemsoueuv3/actions/workflows/deploy-web.yml

## Regras e reprodução

Sem acesso ao Supabase, banco, credenciais, Edge Functions ou migrations.
Nenhum desses sistemas foi alterado. Testes de duelo usam serviço local.
Leia AGENTS.md, docs/layout/README_IPHONE.md e docs/referencias/README.md.

Godot local: `/workspace/.tools/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64`.
Templates em `XDG_DATA_HOME=/workspace/.runtime/data`.
Use Xvfb próprio para os testes interativos: perda de foco pausa o jogo.
Comandos reproduzíveis em [REINO_V3.md](docs/desert/REINO_V3.md).
A fixture Web fica em uma cópia isolada, com feature `iphone_layout_fixture`,
e nunca deve ser publicada como jogo; produção exclui `tests/*` e `evidence/*`.

### Melhorias do Mata-Mata e política de nickname

Reações dos avatares, apresentação da ordem e confirmação sobre cartas/decks:
[implementação, testes e pendências online](docs/DUEL_AVATAR_IMPROVEMENTS.md).
Publicação na main autorizada pelo dono. Contas cadastradas passam pelo nickname
obrigatório e o cliente bloqueia sua troca; convidados mantêm o modo local.
A unicidade/trava no banco, a ordem online e o chat de bots dependem do responsável
pelo backend: [prompt consolidado e pendências](docs/backend/PENDENCIAS_2026_11_05.md).
O Codex não modifica Supabase.
