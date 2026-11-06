# Composição das dez fases e acabamento das Tasks

Base: `main` em `87a29c1`. Revisão visual na branch `codex/composicao-fases-tasks`.

**Correção após reprovação das bandeiras:** retirado o estandarte solto de todos os checkpoints, o retângulo de tecido aplicado no obstáculo da fase 8 e os enfeites adicionais dos elevadores. O checkpoint agora usa uma pequena lanterna baixa de ferro e pedra, no recuo da pista. A ativação e o retorno após morrer permanecem iguais. Fotos nativas e folhas de contato atualizadas; bandeiras que fazem parte das fachadas e estruturas ilustradas originais continuam nos seus suportes.

As fotos são capturas do Godot 4.7.2 Compatibility. As galerias posicionam o jogador por fixture para inspecionar cada peça; não são prova de travessia. Os percursos completos foram executados separadamente com comandos físicos, sem teleporte ou invulnerabilidade. As duas folhas de contato apenas reúnem essas capturas.

## Galeria

- [As dez fases](visao-dez-fases.jpg).
- [As 19 Tasks antes da ativação](visao-19-tasks.jpg).
- [iPhone horizontal, 844×390](iphone-844x390): dez fases, estação disponível/consumida e checkpoint apagado/aceso.
- [Desktop, 1920×1080](desktop-1920x1080): ambientes, mecanismos e estações.
- [Horizontal, 640×360](horizontal-640x360).
- [Todas as 19 Tasks, antes e depois](tasks-844x390).
- [Capturas e relatório do navegador](web-844x390).
- [Comparação com a base](antes).
- [Relatórios e logs](validacao).

## O que mudou

| Fase | Acabamento do percurso e mecanismos |
| --- | --- |
| 01 — Capital | Arcadas completas de pedra, jardins atrás da pista, ferragens e apoio do portão. |
| 02 — Telhados | Preservado o teto jogável e o recorte corrigido; bases de recarga rasas e guindaste apoiado na margem. |
| 03 — Bazar | Balcões com a arte da barraca aprovada, tábuas e tecidos; mercadorias atrás da pista. |
| 04 — Aqueduto | Arcadas com arte do aqueduto, canal discreto e comporta metálica com corrosão na base. |
| 05 — Oásis | Tronco com madeira, amarras e galhos; jardins junto ao mecanismo do portão. |
| 06 — Ruínas | Coluna caída com capitéis; molduras de ruínas nos mecanismos, substituindo o arco da capital. |
| 07 — Estrada | Caixotes com tábuas, travessas e ferragens; guindaste com pilares completamente na margem. |
| 08 — Posto | Passagem de pedra sem bandeira aplicada, torre ao fundo e moldura do portão militar aprovado. |
| 09 — Mineradora | Caixotes e minério atrás da pista; portão de serviço e guindastes da mineração. Entrada monumental preservada no final. |
| 10 — Interior | Passarela ilustrada de madeira e pedra e guindaste apoiado; arena e combate de Malagueta preservados. |

Em todas as fases, os postes usam ferro escuro e pequenas lanternas âmbar; checkpoints usam uma lanterna baixa que acende ao ativar, sem poste ou bandeira. As recargas mantêm uma base embutida no piso, sem o cone bege elevado. A base permanece após a coleta, perde o acento e mantém esse estado ao descarregar/recarregar o trecho. Capacidade cheia continua preservando o item.

O recorte de texturas agora resolve o atlas até a imagem original. Isso preserva a correção dos telhados e evita o mesmo deslocamento em fachadas e peças das Tasks. Os guindastes mantêm cabos e pontos de animação originais, com a estrutura visual recuada para a margem.

## Assets e arquivos

Reaproveitados: `capital_market_stall`, `capital_palm_garden`, `capital_watchtower`, `capital_archway`, `desert_aqueduct`, `desert_ancient_ruins`, `desert_military_gate`, `desert_mining_gantry` e `desert_timber_bridge`, além das fachadas e panoramas já aprovados. Não há novas imagens, downloads, modelos ou serviços de geração.

Novos scripts de arte: `obstacle_art.gd` e `pedestal_art.gd`. Geometria e materiais das estações são compartilhados; as peças dos obstáculos continuam agrupadas pelo kit existente. Nenhuma luz ou processamento por quadro foi acrescentado. Não houve mudança em posição/colisão de plataformas, movimento, combate, tarefas, modelos, câmera, backend, música ou menus.

Alterados no produto: `kingdom_assets.gd`, `modular_architecture.gd`, `city_props.gd`, `task_art.gd`, `checkpoint_banner.gd`, `charge_pickup.gd` e somente os trechos visuais de estações em `phase.gd`.

## Validação e limites

- Dez percursos completos aprovados, sem morte ou respawn; inclui o chefe da fase 10. Medições headless nesses relatórios não representam FPS no navegador.
- Regressões: coleta/capacidade/persistência, Tasks, barreiras, parkour, checkpoints, tutorial, composição e descarregamento dos trechos.
- Contato dos pés/telhado: 30 verificações gráficas aprovadas em cada resolução: 844×390, 1920×1080 e 640×360.
- `check_design.py`, `scope_test.py --base 87a29c1` e `git diff --check` aprovados.
- Web exportado do commit `13a6f77`: portão da fase 1, toldo da fase 3 e ponte da fase 7 ativados pelo toque com cargas zeradas; cada passagem percorrida nos dois sentidos. Sem erros JavaScript ou do motor. Aproximação dos mecanismos feita por fixture, ativação e deslocamento por entradas reais. A revisão posterior das bandeiras foi conferida no render nativo nas três resoluções, sem repetir o navegador; suas fotos Web anteriores não mostram essa última revisão.
- Após retirar as bandeiras: checkpoints (21), Tasks (182) e composição/streaming (110) novamente aprovados. Logs em `validacao/sem-bandeiras/`.
- `approved_assets_test.gd`: quatro verificações de âncoras das fachadas da fase 2 falham também na base, antes desta mudança. Teste preservado; comparação registrada nos logs. As verificações gráficas específicas dos telhados passam.
- As galerias nativas usam Linux/Mesa llvmpipe. A emulação Web usa Chromium/WebGL via SwiftShader, viewport 844×390, DPR 3 e user-agent de iPhone. Não equivale a Safari, aparelho físico ou medição de desempenho em GPU real.
- Alguns processos do Godot avisam sobre recursos `ObjectDB` no encerramento; não se afirma ausência de vazamentos. Os testes de descarregamento verificam especificamente os nós das peças e estações.

O acabamento fica disponível para avaliação pelas capturas; os testes funcionais não substituem a aprovação estética.
