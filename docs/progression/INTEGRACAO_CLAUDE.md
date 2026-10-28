# Roteiro de integração futura para o Claude

Esta é uma instrução para outra etapa. Nesta entrega não houve execução de Godot/Blender nem mudança em cena, física, combate, câmera, controlador ou código GDScript.

Base preservada: `codex/preparacao-offline-deserto`, commit `943c890`. Os 49 arquivos da entrega anterior e os 408 arquivos originais continuam iguais. A biblioteca nova fica em `tools/progression/`; não está conectada ao jogo.

## Antes de alterar o runtime

1. Revisar a branch de trabalho e alterações remotas existentes. Não substituir a main automaticamente.
2. Ler [contrato v2](CONTRATO_V2.md), [migração](MIGRACAO.md) e [sincronização](SINCRONIZACAO.md). Os contratos v1 foram preservados como histórico; novos adaptadores devem usar as versões v2 explicitamente.
3. Executar os testes Python de regras/contratos. Eles não substituem testes de integração no Godot.
4. Decidir a integração: portar o redutor puro para GDScript e comparar com os fixtures, ou usar a referência no backend Python. Não tentar importar módulos Python diretamente em GDScript.

## Contrato do adaptador Godot

Manter a lógica de progressão separada de cenas e controladores. O adaptador deve expor, com equivalência aos testes:

- `load_or_migrate_progress`: abre o save v2 ou prepara migração para um caminho novo; nunca apaga o legado ou redefine corrupção silenciosamente.
- `available_phases` e `start_phase`: acesso sequencial e revisitação, sem usar a skin equipada para escolher o protagonista.
- `record_checkpoint`: recebe somente IDs planejados; posição/teleporte pertencem à integração com as cenas, ainda não implementada.
- `request_phase_completion`: produz uma intenção de conclusão; online, aguarda o resultado validado pelo servidor.
- `is_lobby_character_unlocked` / `equip_character`: consultam o estado confirmado, respeitando classificação de personagem.
- `get_campaign_protagonist`: devolve El Fuego para as dez fases, mesmo bloqueado no lobby.
- `save_progress`: preserva a separação entre local provisório, cache, outbox e recibos; usa escrita segura e recuperação compatíveis com a plataforma.

No port GDScript, normalizar números inteiros lidos por `JSON.parse`, respeitar o limite de revisão do contrato e reproduzir o JSON canônico antes de conferir checksum. Não usar uma serialização diferente e declarar o save corrompido por engano. SHA-256 não autentica o jogador.

## Pontos do código existente para uma mudança futura justificada

| Arquivo preservado | Mudança futura necessária | Cuidado |
| --- | --- | --- |
| `scripts/progress/player_progress.gd` | Delegar consultas ao adaptador versionado | Não usar `desert_stage_completed` de ConfigFile como autorização de conta. |
| `scripts/skins/skins_panel.gd` | Consultar desbloqueios confirmados e separar ferramentas DEV | Botão DEV não pode emitir concessão definitiva. |
| `scripts/lobby/lobby_area.gd` | Validar/restaurar equipamento pelo estado permitido | Equipado antigo inválido fica no recibo; usar um inicial válido sem apagar a origem. |
| `data/characters.json` | Coordenar o consumidor da regra canônica | Preservar IDs e grupos; não trocar apenas uma string e deixar os consumidores antigos incoerentes. |
| `data/progress_contract.json` | Migrar os consumidores do contrato v1 | Não rebatizar flags antigas em massa nem fazer backfill sem prova. |
| `scripts/desert/phase_01.gd` | Emitir evento de intenção de conclusão da fase 1 | O evento não conclui a campanha nem libera El Fuego. Preservar a lógica de movimento/combate/câmera. |
| Cenas futuras das fases 2–10 | Mapear IDs estáveis e pontos de checkpoint | Não gerar layout jogável apenas pela existência dos JSONs de planejamento. |

Essas alterações NÃO foram feitas pela Tarefa Offline 02. Cada mudança funcional futura precisa de revisão e teste na integração real.

## Persistência e migração

Ler `user://progress_dev.cfg` e `user://lobby.cfg` sem alterar seus bytes. Criar backup e save v2 em nomes novos; instalar o novo caminho apenas depois de validar o resultado. Entrada em quarentena não vira save vazio. Exibir recuperação/revisão em vez de declarar sucesso.

Flags antigas, equipamento El Fuego e conclusões em um arquivo v1 são alegações não autenticadas. Preservá-las em recibos e backups. Uma conta só recebe desbloqueio definitivo após validação servidor. Não transferir dados entre jogadores com UUIDs diferentes silenciosamente.

O modo `offline_reference` é para demonstrar/testar regras com concessões provisórias. Não usá-lo como mecanismo de autorização online. Se o produto precisar de skins confirmadas disponíveis sem rede, projetar snapshots assinados e verificação local adequada em outra etapa.

## Adaptador Supabase futuro

- Derivar o dono da sessão autenticada no servidor. Não aceitar `user_id` escolhido no corpo do comando.
- Implementar tentativas e evidência independente: jogador/fase/tentativa, prazo, saída e derrota de Malagueta. Não usar os dublês dos testes como verificador.
- Sem verificador confiável, negar conclusão. Um `evidence_id` ou `verified=true` enviado pelo cliente não prova vitória.
- Persistir progresso, journal, evidência consumida, conquista e desbloqueio na mesma transação durável. Unicidade evita repetição de concessão.
- Respeitar `expected_revision`. Em conflito, devolver estado confirmado; não fazer união de desbloqueios com o save do cliente.
- Implementar `authenticated_decoder` sobre respostas do transporte autenticado real. Não usar `loads(save_local)` como confirmação de servidor.

Nenhuma tabela, função, política ou credencial remota foi criada nesta entrega.

## Critérios de aceitação no motor — ainda não executados

Jogador novo com sete heróis; El Fuego bloqueado como skin e disponível na campanha; fases 2–10 bloqueadas sequencialmente; checkpoint retoma sem concluir fase; morte/retomada sem duplicações; fases 1 e 9 sem conquista; fase 10 com Malagueta/saída e conquista uma vez; save legado intacto; corrupção recuperável; conflitos/reenvios sem perda ou concessão indevida; equipamento de inimigo/chefe recusado; troca de conta; respostas atrasadas e perda de conexão.

Executar esses testes no Godot somente na etapa de integração autorizada e registrar resultados separadamente dos testes Python.
