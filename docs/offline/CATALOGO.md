# Catálogo de personagens — proposta compatível

Fonte ativa preservada: `data/characters.json`, `schema_version: 2`. O documento complementar é [character_registry.json](../../data/planning/character_registry.json), sem ligação nova com o carregador do jogo. Os IDs, grupos, nomes e modelos das oito entradas existentes continuam iguais na fonte ativa.

| ID estável | Nome | Categoria | Lobby inicial | Modo História |
| --- | --- | --- | --- | --- |
| `cowboy` | Cowboy | Jogável | Liberado | Nenhum papel novo definido |
| `michelly` | Michelly | Jogável | Liberada | Nenhum papel novo definido |
| `rodrigo` | Rodrigo | Jogável | Liberado | Nenhum papel novo definido |
| `lorena` | Lorena | Jogável | Liberada | Nenhum papel novo definido |
| `gus` | Gus | Jogável | Liberado | Nenhum papel novo definido |
| `lana` | Lana | Jogável | Liberada | Nenhum papel novo definido |
| `halloween` | Halloween | Jogável | Liberado | Nenhum papel novo definido |
| `el_fuego` | El Fuego | Desbloqueável e protagonista | Bloqueado | Protagonista de **todas as dez fases** do Reino do Deserto |
| `cactus` | Cactus / Cacto no catálogo inimigo | Inimigo | Não equipável | Tropa inimiga do Deserto |
| `malagueta` | Malagueta | Chefe planejado; assets existentes | Não equipável | Chefe final da **fase 10** |

`cactus` já existe em `data/desert_enemies.json`. `malagueta` já é o identificador de `pending_assets` e do diretório original; foi reutilizado, sem criar entrada jogável. `story_villains` permanece vazio na fonte ativa. Encontrar um modelo, um esqueleto ou uma animação não concede elegibilidade como skin.

## Disponibilidade de El Fuego

El Fuego fica disponível para o roteiro desde a primeira fase, mesmo bloqueado no lobby. Depois de concluir a fase 10, com as dez fases registradas e a derrota de Malagueta validada, o servidor futuro concede `desert_campaign_completed` e o desbloqueio de `el_fuego` na mesma transação.

Ele não é permanentemente exclusivo do Modo História: antes da conquista, seu uso fica restrito à campanha; após a conquista, também pode ser equipado no lobby. Cactus e Malagueta são exclusivos do conteúdo de História neste planejamento e continuam não equipáveis.

## Compatibilidade e migração pendente

A fonte ativa usa `unlock.type=flag` e `unlock.flag=desert_stage_completed`. Isso não foi alterado nesta tarefa, pois o carregador, os botões DEV e o contrato legado compartilham esse identificador. A proposta usa a conquista canônica `desert_campaign_completed` e registra a divergência explicitamente.

Migração futura coordenada:

1. Implementar conclusões verificadas das dez fases e derrota do chefe final.
2. Persistir a conquista e o desbloqueio de forma atômica e idempotente.
3. Atualizar o catálogo ativo e seus consumidores para a regra canônica, preservando o ID `el_fuego` e o formato compatível com `CharacterCatalog`.
4. Se um adaptador legado ainda precisar da flag antiga, derivá-la **somente de uma conquista canônica validada**. Nunca usar `desert_stage_completed=true` de um save local como prova para gerar a conquista.
5. Testar lobby bloqueado inicial, campanha acessível, ausência de desbloqueio nas fases 1–9 e liberação após a fase 10. Saves locais sem prova permanecem sem conquista até uma conclusão validada.

Não há recompensas monetárias, preços ou novas skins implícitas neste catálogo. [Inventário e limites dos modelos](generated/assets.md).
