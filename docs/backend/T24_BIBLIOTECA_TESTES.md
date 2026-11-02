# T24 — Evidências de implantação, advisors e pendências

Data de execução: 01/11/2026 horário de Belém (2026-11-02 UTC em logs).

**Fontes:** [contrato original](../contracts/T24_BIBLIOTECA.md) e [API real](T24_BIBLIOTECA_API.md). GAME `shuzporktifgiotvnpbz`, CATALOG `bsxicvlngphazesuzaee`. **Nenhuma alteração do Godot nesta tarefa.** `qse_deck_favorites` não foi alterada.

## Implantação efetivamente confirmada

| Etapa | Projeto | Objetos / migrations |
| --- | --- | --- |
| 1 Popularidade | GAME | `qse_deck_plays` (RLS, 60-min rolling lock + 1 registro por hora UTC), `qse_deck_record_play`, `qse_deck_stats`. Migration `t24_1_popularidade`. |
| 2 Recentes | CATALOG | `qse_catalog_decks.published_at NOT NULL`, Lendas Urbanas: `2026-10-30T13:33:30Z`. Deploy registrado em `t24_2_recentes_catalog_safecol` e `t24_2_recentes_catalog_notnull`. |
| 2 Recentes | GAME | `qse_creator_decks.published_at`, trigger `qse_v3.t24_set_published_at`, migration `t24_2_recentes_community`. |
| 3 Comunidade | GAME | Status moderado, nota de revisão, guards INVOKER, `qse_deck_publish_request`, `qse_deck_unpublish`, `qse_deck_report`, `qse_community_decks`, `qse_community_deck`, `qse_deck_reports`, preview Storage policy e helper `qse_t24_published_preview`. Deploy fracionado `t24_3a` a `t24_3e`; correções `t24_4`, `t24_5`, `t24_6`, `t24_7`, `t24_8`. |

**Nota sobre "uma migration por etapa":** existem **três etapas lógicas e arquivos SQL reexecutáveis por área**, mas as chamadas remotas foram desmembradas em migrations menores porque a ferramenta recusou a transação monolítica e o CATALOG/GAME são bancos separados. A aplicação ficou registrada no histórico de cada Supabase; **não afirmar que só houve 3 entradas físicas**. Os arquivos `supabase/game/migrations/202611010001_...`, `202611010002_...`, `202611010003_...` e `supabase/catalog/migrations/202611010002_...` representam a especificação consolidada para novas instalações; patches de hardening estão versionados em migrations GAME adicionais.

## Verificações executadas com resultados

1. GAME, sem usuário autenticado: `qse_deck_record_play`, `qse_deck_stats` e as cinco RPCs de Comunidade retornaram `{"error":"unauthorized"}`.
2. `qse_deck_plays`: RLS `true`; `authenticated` sem `SELECT` e sem `INSERT` direto; única entrada prevista via RPC que usa `auth.uid()`.
3. GAME, **sessão SQL autenticada simulada** com UUID sem conta real, sem criar nenhum usuário/registro: `qse_deck_stats(["official:lendas_urbanas"])` retornou `[{"score":0,"deck_ref":"official:lendas_urbanas","favorites":0,"plays_30d":0,"players_30d":0}]`.
4. Mesma sessão simulada: `qse_community_decks()` retornou `{"items":[],"next_cursor":null}`; `qse_community_deck(UUID inexistente)` retornou `{"error":"deck_not_found"}`.
5. Testes negativos em sessão SQL simulada: `invalid_deck_ref`, `deck_not_found` (play, publish, unpublish), `deck_not_published`, `invalid_sort`, `invalid_limit`, `invalid_cursor`, `invalid_refs` foram retornados com os códigos esperados.
6. **Falha encontrada e corrigida:** referência `creator:` com 36 hífens provocava exceção de cast UUID; agora retorna `{"error":"invalid_deck_ref"}`, validado após migration `t24_5_uuid_strict`.
7. **Proteção adicional aplicada:** registro de popularidade inclui bloqueio transacional e rejeita novo registro dentro de 60 minutos corridos, inclusive atravessando fronteira de hora UTC. Confirmado pelo código implantado; **não verificado com duas gravações reais**.
8. Community deck/cards têm RLS `true`. Policy `qse_creator_decks_read` existente filtra `owner_id = auth.uid()`, então `review_note` não está em leitura direta de outros usuários. A publicação pública ocorre apenas pelas RPCs de projeção segura.
9. Storage: bucket `qse-deck-originals` privado; policy `qse_deck_published_previews_read` foi criada para `authenticated`; não concede leitura pública de originais e não modifica policy owner-only de leitura de originais.
10. Performance: índice duplicado detectado em `qse_creator_cards` e **removido**; índice sobre `qse_deck_reports(user_id)` acrescentado. A última execução do advisor já não acusa `duplicate_index`.
11. **Correção de segurança no Storage:** foram aplicadas três políticas RESTRICTIVE adicionais para INSERT/UPDATE/DELETE, permitindo mudanças de arquivos apenas em draft ou limpeza de órfãos após remoção do deck. SQL/políticas instalados e inspecionados; **não houve upload real no teste**.
12. CATALOG: `published_at` confirmado distinto de `updated_at`; advisors de segurança/performance sem lints na última consulta.

## Advisors de segurança — após cada etapa

| Etapa | GAME | CATALOG |
| --- | --- | --- |
| 1 | `rls_enabled_no_policy` INFO; `authenticated_security_definer_function_executable` WARN; `auth_leaked_password_protection` WARN | Sem alterações |
| 2 | Mesmas categorias de aviso | **Sem avisos** |
| 3 (final) | Mesmas categorias; INFO inclui `qse_deck_reports` sem policies **intencionalmente: negado acesso direto** | **Sem avisos** |

Na consulta final do GAME: `rls_enabled_no_policy` INFO (16 constatações), `authenticated_security_definer_function_executable` WARN (45), `auth_leaked_password_protection` WARN (1). O advisor agrupa **funções preexistentes e novas**, não significa 45 vulnerabilidades novas. As RPCs públicas T24 de leitura/escrita usam `auth.uid()`, verificam propriedade/estado e retornam projeções controladas; triggers de guarda correm como `SECURITY INVOKER`. As funções `SECURITY DEFINER` T24 devem receber revisão independente em auditoria de produção.

- RLS sem políticas: https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy
- RPCs SECURITY DEFINER: https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable
- Proteção senhas vazadas: https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection
- Índices de FK: https://supabase.com/docs/guides/database/database-linter?lint=0001_unindexed_foreign_keys

GAME advisor de performance final: `unindexed_foreign_keys` INFO (11, inclusive legados), `unused_index` INFO (13). CATALOG: sem avisos.

## Testes que NÃO foram executados / pendências

- **Fluxo positivo de registro de play:** não criou um evento real; cooldown 60 minutos e concorrência foram auditados em código SQL, não verificados com duas sessões reais.
- **Publicação:** GAME tinha **0 decks da comunidade** no momento da inspeção. Não houve deck com 5 imagens originais e 10 prévias para provar `pending_review → published` na prática.
- **Denúncias:** três jogadores diferentes, transição automática de `published → pending_review`, reenquadramento após republicação e `review_note` como resposta ao autor ainda exigem E2E com usuários reais, sem forjar identidades no banco.
- **Storage:** não houve download autorizado autenticado de prévia real de deck publicado, nem teste de negação de original por terceiro; política foi inspecionada, não exercitada por uma requisição HTTP externa.
- **Godot:** filtros, ordenação, capturas, experiência Android/Web e chamados na partida não foram alterados ou testados.
- **Histórico oficial:** data de Lendas Urbanas baseada no primeiro commit de integração (#29), não em um registro externo de lançamento; se existir lançamento oficial anterior, confirmar e ajustar.
- **Antifraude:** a RPC confirma JWT, a existência/visibilidade do deck e cooldown, mas **não possui atestado de partida autoritativo**; um cliente autenticado pode chamar a RPC sem iniciar de fato uma partida. Para rankings competitivos, instrumentar eventos de partida no GAME e registrar apenas um evento validado pelo servidor.

## Integração por fases (Claude)

1. **Ativar Popularidade** somente após testar chamadas RPC com jogador autenticado e evento real de início de partida. `score=0` deve aparecer como ausência de engajamento, não popularidade inventada.
2. **Ativar Recentes** após conectar leitura de `published_at` (CATALOG para oficiais, GAME para comunidade); não confundir com `updated_at`.
3. **Ativar Comunidade** após teste de 5 cartas reais com arquivos preview, aprovação administrativa, visibilidade restrita, denúncia por 3 usuários diferentes e reversão por despúblicação. Usar caminhos relativos do bucket privado, não abrir originais.

**Status:** Banco implantado com validações estruturais e negativas aprovadas; **homologação funcional positiva pendente**. Não afirmar publicação da Biblioteca no jogo.
