# Malagueta — arena da fase 10

## Revisão dos FBX e das lâminas — novembro de 2026

Pedido do dono: usar o uniforme/skin de `Idle.fbx`, incorporar os outros cinco
arquivos apenas como movimentos e fazer a lâmina atravessar toda a arena.
Esta revisão substitui as descrições de arte provisória e movimentos pendentes
do protótipo documentado abaixo. Não modifica os personagens equipáveis.

- `model.gd` mantém um único modelo visível, vindo de Idle, e adapta os canais
  de ossos dos movimentos. Parado, arremesso, caminhada com frasco, golpe,
  atordoamento e afastamento estão ligados aos estados reais do boss.
  A morte existente foi adaptada do rig antigo, descartando 18 canais sem ossos
  correspondentes. A textura embutida de Idle é extraída pelo importador Godot.
- O frasco fica na mão durante a preparação e solta após 0,65 s. Um golpe ou
  atordoamento antes da soltura cancela o lançamento. Os ataques verde/vermelho
  mantêm trajetórias distintas e podem coexistir na terceira etapa.
- Cinco lâminas serrilhadas percorrem, alternadamente, 20,4 m de largura.
  O topo liso carrega o jogador; a passagem por baixo não bloqueia a cabeça.
  Os níveis foram afastados para a lâmina superior não cortar quem está parado
  no nível inferior. O salto, o pulo duplo e os controles não foram alterados.
- Trilhos, apoios, parede contínua e bancada contextualizam a oficina.
  O guindaste existente foi reduzido para não dominar a rota.
- Saves do layout anterior voltam à entrada mantendo as Tasks concluídas;
  o novo layout é identificado por `malagueta.layout=2`.

Verificação nativa: sete movimentos importados e deformações amostradas;
12 verificações dos estados/animações; 21 da arena; 11 de combate; subida
com controles reais e três vidas intactas; perseguição, checkpoint e equivalência
das fases 1–9. As primeiras tentativas de percurso revelaram interferência entre
níveis e timing do pulo duplo; foram corrigidas antes da tentativa aprovada.
O teste de químicos aguarda as solturas animadas, em vez de exigir projéteis
instantâneos. `check_design.py` aprovado. Evidências desta revisão em
`evidence/malagueta-motion-blade/`; capturas Web são emulação Chromium,
não Safari/iPhone físico. A prévia de movimentos usa câmera aproximada e
seleção de clipes em fixture isolada, não representa uma luta completa.

Publicação pendente: a main `b3a7cebd` já falha no Approved scope guard pelos
seis FBX enviados pelo dono em `assets/characters/malagueta/`. Nenhuma política
ou variável de autorização foi alterada nesta revisão. A integração está na
branch `codex/malagueta-motion-blade`, sem merge automático. O procedimento de
exceção pertence ao dono, conforme `docs/governance/APPROVED_SCOPE.md`.

## Registro do protótipo anterior

Decisão do dono: manter a fase 9 como entrada da mineradora e substituir a batalha
na fase 10. Gameplay implementada em Godot 4.7.2, preservando a física lateral
2.5D, personagens e controles existentes. Nenhum FBX ou animação foi criado.

## Mecânica implementada

Cinco limas planas móveis e um patamar superior formam uma subida contínua. O
zigue-zague inicial foi descartado após o teste de salto detectar tetos baixos.
O topo das limas tem colisão sólida; as áreas perigosas ficam abaixo das pontas.
Hastes visuais ligam as limas às paredes. A câmera permanece fixa e enquadra o
piso acima dos controles existentes; não houve alteração global do HUD/entrada.

Malagueta recebe os ataques reais do jogador pelo contrato `take_damage` existente.
Quatro pontos de dano (dois ataques comuns) abrem uma janela de cinco segundos.
No patamar, F ou o botão TASK existente executam a tarefa. As três tarefas são
obrigatórias e ordenadas: primeiro frasco, segundo frasco, reação química.
Expirar a janela não perde tarefas anteriores nem avança o estado; é preciso
atordoar novamente. Vitória depende da reação após a terceira tarefa, não de HP
zerado ou tempo de fase.

- Etapa 1: apenas químico verde, trajetória ondulante e no máximo um verde ativo.
- Etapa 2: apenas vermelho, direção definida ao lançamento e defesa original.
- Etapa 3: ambos os químicos e até três cactos; surgimento progressivo. A rota
  dos cactos usa as posições reais das limas para subir e descer, preservando
  combate, saltos, colisões e formação do sistema original.
- Atordoamento limpa projéteis ativos e preenche ataque/defesa pelo `fill_ability`
  existente, até 3/3. Recargas de contato acessíveis no piso usam `charge_pickup`;
  cheias não são consumidas. Não há inventário ou consumo paralelo.
- As tarefas concluídas entram no checkpoint e no salvamento existente. Saves do
  protótipo anterior são reposicionados na entrada da arena. Interromper depois
  da Task3 retoma a reação, evitando um estado final bloqueado.
- A reação para ataques/surgimento e chama o encerramento/progresso existente da
  campanha e a morte original do boss (incluindo colisão e morte.fbx já existente).
  Recomeçar/checkpoint/derrota continuam no overlay original.

## Arquivos e integração

| Arquivo | Responsabilidade |
|---|---|
| `scenes/desert/phase_10.tscn` | Cena existente agora usa a arena especializada; editada pela API de cenas do Godot. |
| `scripts/desert/malagueta/arena.gd` | Montagem, câmera, adaptação do HUD/Tasks, cargas, checkpoint e vitória. |
| `scripts/desert/malagueta/encounter.gd` | Oito estados e transições controladas por tarefas reais. |
| `scripts/desert/malagueta/moving_file.gd` | Corpo móvel sólido, haste e áreas cortantes independentes. |
| `scripts/desert/malagueta/chemical.gd` | Aviso, movimento, colisão e expiração dos químicos. |
| `scripts/desert/malagueta/target.gd` | Modelo legado do boss e contrato de ataque; sem IA de perseguição do soldado. |
| `scripts/desert/malagueta/pursuer.gd` | Escolha de próximos patamares; locomoção/combate continuam no Cactus existente. |
| `scripts/desert/t15d/phase.gd` | Dois pontos de extensão: layout e criação de cactos; implementação padrão preservada. |
| `scripts/desert/t15d/cactus.gd` | Ponto de extensão da direção; padrão mantém o `signf(offset.x)` anterior. |

Cenas e dados das fases 1–9 não foram modificados. O layout ativo da fase10 é
`arena._layout_for_phase`; seu JSON legado não é a fonte dos novos obstáculos.
Nenhuma alteração em autenticação, Supabase, economia, música ou áreas congeladas.

## Parâmetros de balanceamento

Expostos no script da cena: `file_speed=0.65`, `file_travel=0.65`,
`damage_to_stun=4`, `stun_seconds=5`, `green_interval=3.2`, `green_speed=4`,
`green_amplitude=0.45`, `red_interval=2.6`, `red_speed=5.5`,
`cactus_interval=7`, `max_cacti=3`, `refill_interval=12`, `hazard_damage=1`.
Cada lima também expõe largura, deslocamento e velocidade; os químicos têm aviso
de 0.65s e duração limitada. São valores iniciais para playtest, não aprovação
final de dificuldade em aparelho físico.

## Recursos reutilizados e FBX futuros

El Fuego, Cactus e Malagueta usam modelos/rigs/clipes existentes. Foram reutilizados
`desert_mining_gantry.res`, `desert_mine_crystals.res`, materiais do Terrain,
lanternas do CityProps, ícones, recargas, efeitos de impacto e HUD originais.
As limas são geometria funcional editável; químicos usam volumes coloridos de
jogabilidade, não arte definitiva. Não houve geração de imagens ou de personagens.

Os sinais `attack_requested`, `stunned`, `task_completed`, `reaction_started` e
`defeated` são os pontos de integração para os próximos efeitos e FBX. O boss
mantém o nó Model/ActorSlot e o catálogo existente; futuros clipes não precisam
reimplementar a máquina de estados. Risada, atordoamento, frascos e reação visuais
definitivos dependem dos assets ainda não enviados. O visual é de validação da
mecânica, não uma nova aprovação artística.

## Validação executada

| Teste | Resultado |
|---|---|
| `tests/malagueta/state.gd` | 30 verificações: ordem, cinco segundos, falha/repetição, duplicidade e derrota. |
| `arena.gd` | 21 verificações: piso/lima reais, câmera, F/botão TASK, cargas, vitória e progresso local após nove fases concluídas na fixture. |
| `combat.gd` | 11 verificações: ataque real/consumo, dois golpes, defesa contra vermelho, dano sem defesa, recarga por contato e pontas cortantes. |
| `chemicals.gd` | Verde/vermelho simultâneos, trajetórias distintas e limpeza no atordoamento. |
| `traversal.gd` | Percurso inteiro com comandos de salto/pulo duplo, sem teletransporte; versão vulnerável terminou com 3 vidas. |
| `pursuit.gd` | Cacto subiu até o boss, voltou ao piso e respeitou limite de três. |
| `checkpoint.gd` | Task retida no checkpoint/save válido e retomada da reação após interrupção da Task3. |
| `regression.gd` | Layout e fábrica/direção padrão equivalentes para as nove fases anteriores. |
| Web Chromium | Abertura/renderização em1672×941 e iPhone UA/DPR3 em844×390 e640×360, sem erros de script. |

Os runners ficam em `tests/malagueta/`; executar com
`godot --headless --path . --script res://tests/malagueta/<teste>.gd` em usuário de
teste isolado. `export.py`/`web.cjs` usam cópia de staging, bloqueiam rede externa e
não são a cena de produção. As fotos usam jogador invulnerável e suprimem apenas seu piscar na fixture;
nenhuma dessas opções entra na cena de produção. A fixture Web de fase3 prepara o
estado combinado para inspeção visual; não representa progresso de uma conta.
Não houve teste em aparelho físico, Safari nem conta real/cloud nesta entrega.

Limitações registradas: o runner legado `scenario_tasks_test.gd`, mantido para
fases1–9 (fase10 coberta pela nova bateria), terminou170 checks/73 falhas.
Ele não foi declarado aprovado; a causa das falhas de Tasks anteriores não foi
resolvida neste escopo. Alguns encerramentos headless emitem avisos de recursos
pendentes; os logs foram preservados. A captura nativa final encontrou falhas
no driver de software; a conferência final de imagem usa o motor Web real.
A primeira cópia Web faltava o asset de lança já existente: a cópia foi
sincronizada; isso não exigiu alterar o asset ou o código da lança em produção.

Evidências: `evidence/malagueta/web/` (atual), `validation/` (testes e tentativas),
`initial-geometry/` e `web-missing-assets/` (históricos, não resultado final).
Sem merge/publicação automática na main.

A execução Web desktop foi repetida após ligar a derrota ao método original do
boss. Os perfis móveis verificam abertura/renderização; vitória, defesa e
interação F/TASK foram conferidas no motor nativo, não em Safari físico.
