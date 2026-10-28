# Supabase — proposta, sem implantação

Nenhuma tabela, função, política, conta ou credencial foi criada. O jogo continua usando seus arquivos locais de desenvolvimento. Este documento define a migração futura e contratos para revisão, não um backend já funcional.

## Contratos preparados

- [player_state.schema.json](../../data/contracts/player_state.schema.json): perfil, campanhas, conclusões, personagens desbloqueados, equipado, conquistas e revisão do estado.
- [phase_attempt.schema.json](../../data/contracts/phase_attempt.schema.json): tentativa emitida pelo servidor, fase, expiração e política de verificação.
- [progress_operation.schema.json](../../data/contracts/progress_operation.schema.json): comandos propostos `begin_phase`, `complete_phase` e `equip_character`.
- [progress_service.proposal.json](../../data/contracts/progress_service.proposal.json): tabelas, operações, transações e regra de conclusão.
- [Estado inicial sintético](../../data/contracts/examples/player_state.initial.json) e [campanha concluída sintética](../../data/contracts/examples/player_state.completed.json): fixtures de validação, sem jogadores ou conquistas reais.

JSON Schema verifica estrutura e formatos. As regras de propriedade, pré-requisitos, equipamento e concessão precisam ser executadas no servidor; o verificador offline apenas demonstra a consistência dos exemplos e da proposta.

## Modelo relacional proposto

Todos os identificadores de personagem usam os IDs já existentes. UUIDs identificam jogadores, tentativas e requisições; timestamps seriam `timestamptz`, definidos pelo servidor. Não guardar moeda, preço ou XP nestas tabelas por suposição.

| Tabela proposta | Chave | Campos principais | Restrições necessárias |
| --- | --- | --- | --- |
| `player_profiles` | `user_id` UUID | `display_name` texto, `created_at`, `updated_at` | FK para a identidade autenticada; alterações de perfil limitadas aos campos permitidos. |
| `campaign_progress` | `(user_id, campaign_id)` | `status`, `current_phase_id` opcional, `completed_at` opcional, `revision` inteiro | Campanha válida; fases concluídas derivadas dos registros de conclusão. |
| `phase_completions` | `(user_id, campaign_id, phase_id)` | `completion_id` UUID único, `completed_at`, `verified` | Conclusão verificada, fase pertencente à campanha, pré-requisitos completos. |
| `character_unlocks` | `(user_id, character_id)` | `source`, `source_achievement_id` opcional, `unlocked_at` | Só IDs equipáveis; origem inicial ou conquista válida. Nunca Cactus/Malagueta. |
| `player_loadout` | `user_id` | `equipped_character_id`, `updated_at` | FK composta `(user_id, equipped_character_id)` para o desbloqueio do mesmo jogador. |
| `player_achievements` | `(user_id, achievement_id)` | `source_campaign_id`, `awarded_at` | `desert_campaign_completed` depende das dez conclusões e do encerramento validado da fase 10. |
| `phase_attempts` | `attempt_id` UUID | `user_id`, campanha/fase, emissão, expiração, estado, política de verificação | Tentativa vinculada pelo servidor ao jogador e à fase. Não reutilizar prova de outra tentativa. |
| `processed_requests` | `(user_id, request_id)` | digest do comando, resultado/revisão, timestamp | Repetição idêntica devolve resultado anterior; mesma chave com outro conteúdo é rejeitada. |

Uma versão futura das migrações deve definir os tipos finais, checks e FKs contra registros de campanhas/personagens permitidos. Não há DDL executável nem migração remota nesta entrega.

## Autoridade e acesso

- A sessão autenticada determina `user_id`; o comando do cliente não aceita escolher o dono dos dados.
- RLS permitiria leitura apenas das próprias linhas. Escrita direta de progresso, conquistas e desbloqueios pelo cliente deve ser negada.
- Atualização de nome pode ser permitida separadamente; nenhum campo de progresso vai no mesmo comando de perfil.
- Equipamento passa por uma operação transacional: consultar catálogo permitido, desbloqueio do dono e regra de conquista; só então alterar `player_loadout`.
- Segredos de administração e chaves de serviço permanecem no servidor. Nenhum arquivo desta proposta contém credenciais.

## Fluxo de conclusão e desbloqueio

1. `begin_phase` verifica campanha e pré-requisitos e emite uma tentativa com expiração. El Fuego é autorizado pelo papel de protagonista, independentemente de seu bloqueio no lobby.
2. `complete_phase` recebe `request_id`, `attempt_id` e referência de evidência de conclusão. O servidor valida sessão, vínculo, prazo, ordem e evidência independente de conclusão. Um UUID ou um `verified=true` enviado pelo cliente não prova vitória.
3. Registrar a conclusão uma única vez e atualizar a revisão. Fases 1–9 não concedem a conquista nem desbloqueiam El Fuego.
4. Na fase 10, validar também a derrota de Malagueta e o encerramento da fase; conferir todos os dez registros de conclusão.
5. Na mesma transação, completar a campanha, conceder `desert_campaign_completed` e inserir o desbloqueio de `el_fuego`. Repetições não duplicam a concessão.
6. Devolver o estado confirmado. O cliente só passa a mostrar El Fuego equipável após essa confirmação.

A verificação autoritativa de eventos de gameplay **ainda não existe**. Supabase, RLS, JSON Schema ou um digest informado pelo cliente não fornecem, sozinhos, uma prova de que o jogador derrotou o chefe. A política de evidência e o serviço que a verifica devem ser definidos antes de usar o desbloqueio em produção.

## Compatibilidade com o contrato local

`data/progress_contract.json`, o catálogo e os botões DEV continuam usando `desert_stage_completed`. Esses arquivos foram preservados. A atualização futura deve trocar a fonte de verdade de `PlayerProgress` e a regra do catálogo de forma coordenada, mantendo a estrutura esperada por `CharacterCatalog.load_all/load_entries`.

Não converter automaticamente uma flag DEV ou um arquivo `user://` em conquista. Só fazer backfill quando houver evidência suficiente das dez conclusões verificadas. Caso um consumidor antigo ainda precise da flag, projetá-la da conquista canônica confirmada para o formato legado; não fazer a conversão inversa por suposição.

## Operação offline e falhas

- Cache local pode exibir o último estado confirmado, com indicação de que está desatualizado; não concede novos desbloqueios.
- Conclusões offline podem ficar como pendentes, separadas das verificadas. Não equipar El Fuego a partir delas até existir política de verificação e sincronização aprovada.
- `request_id` torna retentativas idempotentes. Tratar falha após commit consultando o resultado anterior, sem conceder recompensas novamente.
- Conclusões concorrentes exigem unicidade e transação/serialização do progresso do mesmo jogador.
- Usar revisão de estado para evitar sobrescrever progresso mais recente. Logs operacionais não devem expor tokens ou dados pessoais desnecessários.

## Validação futura

Testar propriedade de linhas, tentativa de equipar Cactus/Malagueta, El Fuego bloqueado, conclusão só da fase 1 ou só da fase 10, pré-requisitos faltantes, reenvio/concor­rência, queda após commit, migração de save DEV e autorização do protagonista dentro da campanha. Nenhum desses testes remotos foi executado nesta tarefa.
