# Parkour e tarefas de cenário

Esta revisão remove o piso empilhado rejeitado pelo proprietário. **Não reintroduzir a sequência de cinco blocos como solução de parkour.** Os percursos usam objetos únicos com topo jogável: coberturas, toldos, trechos do aqueduto, troncos/colunas caídas, cargas e passarelas.

- **Fase 2 revisada:** cada casa inteira fornece o próprio teto jogável; não há faixa de piso, cobertura extra ou objeto suspenso sobre a casa. 120 casas separadas por vãos, com as artes existentes de casa residencial e varanda.
- `campaign_layout.gd`: oito objetos nas fases 1 e 3–9 e quatro antes da arena na fase 10. Cada objeto tem 5,6m de extensão, topo de colisão fino e espaço para aterrissagem antes dos vãos.
- `modular_architecture.gd`: visual do objeto conforme a fase; suportes não viram novas paredes de colisão.
- `tasks`: duas tarefas locais por fase 1–9 e uma na fase 10. IDs estáveis por fase. Configuração contém tipo (`gate`, `bridge`, `lift`), título e margens/alturas reais.
- `earth_bridge.gd`: nome legado do mecanismo compartilhado; não representa um poder. Portão sobe, plataforma é içada e passagem gira. Usam o mesmo evento de conclusão.
- `phase.gd` e `campaign_hud.gd`: botão temporário/F perto da tarefa; sem gasto de carga. Montagem de 0,8s segura o ator e devolve os comandos ao concluir. Estado local permanece no unload/reload e limpa no reinício.
- Cactus das fases 1–9 saltam sobre os objetos e confirmam piso ao descer. Guardas resistentes têm três marcadores de vida e alerta distinto, com preparação de golpe de 0,42s. Malagueta preserva as regras anteriores.

Recargas, modelos, habilidades permanentes, ambientes aprovados e identidade dos menus permanecem. Não envolver backend para resolver interação de cenário.

[Evidências, tabela das tarefas, testes e limitações](../../evidence/tasks-parkour/README.md).

Testes: `scenario_tasks_test.gd`, `parkour_revision_test.gd`, `skyline_roofs_test.gd` e percursos de `tests/desert_night/run.py`. O autopiloto aciona F por entrada física. `web_scenario_probe.cjs` testa toque, montagem e travessia nos dois sentidos com WebAssembly real. Fixtures aproximam o ator explicitamente; não exportar fixtures como produção.

## Revisão: obrigatoriedade e primeiro uso

- Os vãos de Task têm pelo menos 18m e não contêm piso, itens ou inimigos intermediários. `surfaces.task_void` preserva os índices, mas impede decoração e âncoras no abismo. As passagens podem substituir lotes da sequência original de casas; não desenhar casas ou uma pista sobre esse vão.
- Portões fechados têm 5,2m, superando o pulo duplo. A interação continua sem gasto de recursos e pode ser executada dos dois lados.
- TASK é um botão circular contextual acima do ataque. A ação aparece acima do botão; não usar a antiga faixa de texto no centro inferior. Defesa fica acima do pulo, evitando sobreposição.
- Fase 1 inicia com ataque/defesa 0/0. Outras fases preservam os valores iniciais anteriores. O visual de El Fuego é baixado em 0,06 unidade; a cápsula permanece igual.
- `first_use_tutorial.gd`: pausa ao entrar na fase 1 (ataque), na primeira recarga de defesa e na primeira Task. Marca cada lição como vista somente ao continuar, por perfil, no ConfigFile local e no localStorage Web. Leitura em cache, sem I/O por quadro. Outras fases não repetem as lições.
- Regressões de jogador experiente usam apenas o helper de teste `tutorial_fixture.gd`; os testes de primeiro uso partem de dados vazios e validam as pausas, os controles e a persistência.

[Capturas, testes e limites da revisão](../../evidence/tasks-tutorial/README.md).
