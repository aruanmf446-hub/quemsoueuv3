# Rotas sobre obstáculos, tarefas por fase e Cactus

Revisão solicitada após a rejeição do piso empilhado. Publicação na main autorizada pelo proprietário nesta rodada.

## Resultado

- Removida a geração e a renderização dos cinco blocos em sequência. Cada conjunto virou um **obstáculo único de 5,6m de largura com topo físico percorrível**: cobertura, toldo, trecho de aqueduto, tronco/coluna caída, carga sobre rodas ou passarela. Oito por fase 1–9; quatro no começo da fase 10, preservando o trecho da arena.
- O jogador pode saltar, pousar e **correr sobre esses objetos**. Suportes visuais ficam fora da faixa central; não há chão invisível suspenso nem colisão adicionada aos cenários inteiros.
- Mantidas as diferenças de nível, vãos reais, pontes frágeis, recargas com pedestal e ambientes aprovados. Sem novas imagens externas ou substituição dos personagens.
- **19 tarefas contextuais:** duas em cada fase 1–9 e uma na fase 10, antes da arena. Todas usam o mesmo botão temporário/F, sem poderes permanentes ou consumo de carga. Portões sobem para liberar a rota, plataformas são içadas e passagens giram até virar piso. A ação segura o personagem por 0,8s e devolve os comandos ao terminar. Estado preservado no unload/reload e limpo no reinício.

| Fase | Tarefas |
|---|---|
| 1 | Abrir portão da capital; baixar ponte da muralha |
| 2 | Estender passarela dos telhados; içar plataforma de manutenção |
| 3 | Estender toldo do mercado; liberar depósito de especiarias |
| 4 | Abrir comporta do aqueduto; reconstruir passagem do canal |
| 5 | Reposicionar tronco do oásis; abrir passagem dos jardins |
| 6 | Alinhar laje das ruínas; abrir portal antigo |
| 7 | Acionar plataforma de carga; baixar viga do desfiladeiro |
| 8 | Abrir portão do posto; baixar passarela de vigia |
| 9 | Acionar guindaste de minério; liberar portão de serviço |
| 10 | Içar passarela da galeria |

### Cactus

Nas fases 1–9, perseguição acelera quando o guarda está longe e permite reação quando se aproxima. Cactus reconhecem e saltam sobre os novos obstáculos e descem apenas quando confirmam piso abaixo; vãos continuam sendo tratados como abismos. Guardas resistentes aparecem pontualmente nas fases 3, 5, 7, 8 e 9: precisam de dois socos, têm três marcadores de vida e alerta avermelhado. O aviso de ataque permanece; o guarda resistente prepara o golpe em 0,42s. Animação acompanha a velocidade real.

Modelos, poderes e dano do protagonista preservados. Malagueta mantém suas regras e arena. Sem alterações em autenticação, Supabase, economia, música ou menus.

## Evidências visuais

Capturas gráficas reais do Godot 4.7.2 Compatibility em Mesa/llvmpipe. Aproximação inicial por fixture; o ator corre por entradas físicas sobre o objeto, e todos os manifestos confirmam `on_floor=true`. Não são capturas do jogo em aparelho físico.

- [Corrida sobre cobertura — fase 2](iphone/corrida_fase_02.jpg).
- [Corrida sobre toldo — fase 3](iphone/corrida_fase_03.jpg).
- [Tronco no oásis — fase 5](iphone/corrida_fase_05.jpg).
- [Carga na estrada — fase 7](iphone/corrida_fase_07.jpg).
- [Portão antes](desktop/tarefa_01_antes.jpg) / [depois](desktop/tarefa_01_depois.jpg).
- [Toldo antes](desktop/tarefa_03_antes.jpg) / [depois](desktop/tarefa_03_depois.jpg).
- [Plataforma antes](desktop/tarefa_07_antes.jpg) / [depois](desktop/tarefa_07_depois.jpg).

10 capturas em 844×390 (perfil iPhone), 10 em 1672×941 e duas em 640×360. JPGs convertidos dos PNGs sem recorte. Manifestos por perfil em `captures.json`.

## Testes

- `scenario_tasks_test.gd`: **177/177**. Todas as 19 tarefas: contexto, acionamento físico por F, custo zero, conclusão, ida/volta e limpeza. Confirma remoção das pilhas e superfícies compridas. Cactus efetivamente salta, pousa, corre sobre o objeto e desce; guarda resistente recebe dois golpes reais.
- `parkour_revision_test.gd`: **52/52**, preservando teste de avanço segurado durante montagem, ponte física, retorno, descarregamento e recomposição da ponte frágil. Expectativas atualizadas para as 19 tarefas e obstáculos únicos; verificações físicas mantidas.
- `skyline_roofs_test.gd`: **74/74**; fundo aprovado, ausência de colisões/luzes na camada distante e vãos abertos.
- `reino10`, `layout`, `checkpoints` e **dez percursos completos: PASS**. `routes/results.json`, logs e JSONs de cada fase. Percursos usam ações reais e agora acionam tarefas com F; não usam teleporte ou invulnerabilidade. A primeira revisão afetou o último trecho da fase 10; os novos obstáculos foram restritos à primeira metade e o percurso do chefe foi repetido com sucesso.
- `check_design.py`, `scope_test.py`, `git diff --check`: **PASS**.
- Web: resultado final em `web/`. Chromium 844×390, DPR 3, toque em três mecanismos diferentes (portão, toldo, plataforma), avanço segurado durante montagem e caminhada nos dois sentidos. Fixtures apenas aproximam o personagem das tarefas, sem backend. PASS: sem erros JavaScript/Godot e sem requisições externas. O primeiro teste mantinha a direção pressionada durante a captura; o teste final para antes de capturar e passou nos três mecanismos.

## Limitações e estado anterior

Sem validação em iPhone físico/Safari/APK ou medição de FPS em hardware móvel. Renderização de software e tempos headless não aprovam qualidade estética nem desempenho real.

Os logs preservam avisos de recursos de áudio ativos ao encerrar certos testes headless, identificados anteriormente como AudioStreamWAV/AudioStreamPlaybackWAV. Os mecanismos são removidos ao sair das cenas.

O smoke geral já apresentava falhas em `transition_01`–`transition_09` e `functional` na main anterior (`d0ae424` e `129f031`). Não foram removidos ou enfraquecidos esses testes; esta rodada não declara a suíte geral corrigida. Status do deploy e da publicação em `publication.json`.
