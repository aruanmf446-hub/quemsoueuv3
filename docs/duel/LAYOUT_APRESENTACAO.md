# Mata-Mata: proporção e apresentação

Pedido do dono em 09/11/2026: estabilizar jogadores/chat/cartas e separar as
animações dos avatares da galeria, reutilizando modelos e clipes existentes.
Branch `work/duel-layout-avatar-stage`. Sem publicação automática nesta entrega.

## Implementação

- A carta usa a imagem original inteira (KEEP_ASPECT_CENTERED), sem AtlasTexture
  de recorte focal. Slot retrato 9:16, legenda separada da arte.
- A grade considera o pool original, não a contagem restante; eliminar cartas não
  altera o formato de todas as demais. Resize real da janela continua suportado.
- Jogadores têm faixa reservada com rolagem para grupos grandes. Chat e mão
  privada mantêm espaço ao abrir/fechar; a mão tem rolagem própria.
- Palco opaco separado, um único viewport 3D reutilizado, nome e posição na ordem,
  fade suave e Continuar acessível por teclado. Sem FBX sobre as cartas reveladas.
- Lobby usa anim_2; ao final os vencedores reais recebem anim_4 e os demais anim_3.
  Não foram criados modelos, clipes, skins ou movimentos substitutos.
- Seis segundos configurados por participante depois de carregar, incluindo fades.
  O relógio local reserva tempo para isso e uma margem de carga; ao terminar/pular
  a apresentação, o servidor local avança sem esperar toda a margem restante.
- Resultados permanecem visíveis se o servidor voltar ao lobby durante a sequência;
  uma nova partida interrompe a apresentação anterior. Derrota é apresentada no
  encerramento, evitando tapar um turno ao vivo.

## Limite online acordado

O dono rejeitou trabalho adicional no Supabase. Nenhum backend, SQL, chave ou
contrato online foi modificado/acessado. A apresentação inicial online respeita a
contagem existente e é interrompida quando começar o turno; não garante seis
segundos para todos nesse trecho. O resultado final não cobre um turno ativo.
Sem teste de sessão online real nesta entrega.

## Conferência

- Godot 4.7.2: partida local completa, 91 verificações aprovadas.
- Teste novo de geometria: 57 verificações em cada janela 1672×941, 844×390 e
  640×360. Fixtures locais, sem dados de produção.
- Transições de apresentação: dez verificações aprovadas, incluindo pular a
  intro local, ignorar conclusão de partida antiga, conservar resultado na volta
  ao lobby e liberar a próxima partida.
- Três clipes nativos, Continuar por teclado e restauração do efeito temporário
  de áudio: failures=0. As capturas nativas do palco antecedem o aumento de
  fill_ratio de 0.62 para 0.72; conferir evidência Web para a versão final.
- Renderização software com carga fria foi lenta (8.9–21.8s incluindo carregamento).
  Seis segundos configurados não são promessa de FPS ou duração física nesse host.
- `tests/battle_reference/flow.gd`: 388 checks, nove falhas, log preservado.
  O teste ainda clica nos antigos ConfirmSelection/CancelSelection ocultos em vez
  de AcceptSelection/RejectSelection sobre a carta e contém expectativas antigas
  de tempo da revelação. Não foi declarado aprovado nem removido do CI.
- Runner `tests/battle_reveal/flow.gd`: completou, BATTLE_REVEAL shown=2; sem
  comprovação de interação por esse runner visual.
- Design checker e diff check aprovados. Nenhuma validação em aparelho físico.

Evidências: `evidence/duel-stage-layout/` e `evidence/duel-avatar-stage/native/`.
Nenhum arquivo de área congelada ou política de proteção foi alterado.

## Resultado Web desta bateria

Desktop Chromium: artes completas9:16 e dimensões idênticas nas quatro mudanças
(turnos, remoção, mão e chat), mais capturas dos três clipes no palco final.
A confirmação por clique falhou no runner ao não localizar AcceptSelection;
a causa não foi concluída. Os perfis Web móveis não foram alcançados.
Não declarar a bateria Web completa aprovada. As três janelas nativas passaram
57 checks cada na fonte final, incluindo duas imagens privadas inteiras no
limite final de96 unidades. O export Web anterior tinha a mão vazia nesse teste.


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

## Ritmo e animações — 10/11/2026 (branch `claude/mata-mata-responsiveness-0cqhlu`)

Pedido do dono: partida com menos pressa e animações das skins sem corte.

- **Partida local:** bot espera 4,0 s antes de jogar (era 2,5), suspense de 3,0 s e
  o próximo turno só começa 1,2 s depois que a tela fecha a revelação
  (`LocalDuelServer.finish_reveal`). `TIMING.reveal` (10 s) é apenas o prazo máximo.
  A revelação local usa `RevealOverlay.pace = 1.3`.
- **Palco de apresentação:** cada jogador fica em cena pelo tempo real do clipe
  (vitória/derrota tocam uma vez até o fim; lobby fecha em voltas completas),
  entre 3,5 e 10 s, com fades de 0,4 s. Online, o tempo da contagem do servidor
  é repartido entre todos (`time_budget`) em vez de cortar a sequência.
- **Trocas na tela:** faixa de jogadores e mesa só são reconstruídas quando algo
  visível muda; texto do turno e jogador da vez entram com fade curto.
- **Sem mudança:** servidor online (tempos em `qse_v3.duel_timing`), modelos,
  clipes e El Fuego (continua sem `anim_2/3/4`).
- **Verificação:** somente análise de sintaxe (`gdparse`). O Godot não pôde ser
  executado nesta sessão; testes nativos, capturas e Web **não foram rodados**.
