# T25 — Auditoria de segurança e índices do GAME

Projeto: `shuzporktifgiotvnpbz`. Branch: `chatgpt/game-security-fk-index-audit`. **Não fazer merge automático; a migração já foi aplicada no GAME e versionada.** Nenhuma alteração no CHAT, CATALOG, contratos T24 ou `qse_deck_favorites`.

## 1. Índices de foreign keys: aplicado

Migração real do Supabase: `20261102170136_t25_game_foreign_key_indexes`.

Auditoria de FKs usando `pg_constraint` e `pg_index` (comparação do prefixo das colunas):

| Verificação | Antes | Depois |
| --- | ---: | ---: |
| FKs nas tabelas `public` e `qse_v3` | 50 | 50 |
| FKs sem índice adequado | **12** | **0** |
| Índices `qse_t25_*_fk_idx` criados | 0 | **12** |

Índices: `public.qse_creator_cards(deck_id,owner_id)`, `public.qse_creator_decks(cover_card_id)`; `qse_v3.campaign_progress(active_phase_id)`; `qse_v3.character_unlocks(character_id)`, `(user_id,achievement_id)`; `qse_v3.completion_evidence(phase_id)`; `qse_v3.duel_friend_invites(sender_id)`; `qse_v3.duel_invite_links(created_by)`; `qse_v3.friendships(user_high)`; `qse_v3.phase_completions(phase_id)`, `(user_id,phase_id,evidence_id)`; `qse_v3.player_loadout(user_id,equipped_character_id)`.

## 2. Advisors — antes/depois

| Advisor | Antes | Depois | Interpretação |
| --- | --- | --- | --- |
| Performance: `unindexed_foreign_keys` | INFO | **Não consta** | Corrigido |
| Performance: `unused_index` | INFO | INFO | Não remove índices sem análise de carga |
| Segurança: `authenticated_security_definer_function_executable` | WARN | WARN | Acessos necessários a RPCs do cliente/Storage |
| Segurança: `auth_leaked_password_protection` | WARN | WARN | Precisa alterar configuração do Supabase Auth |
| Segurança: `rls_enabled_no_policy` | INFO | INFO | Algumas tabelas deliberadamente não têm acesso direto |

## 3. SECURITY DEFINER — auditoria de acesso

Consulta em `pg_proc`, `pg_namespace` e `has_function_privilege`:
- **46** funções `SECURITY DEFINER` do schema `public` executáveis por `authenticated`.
- **0** dessas funções executáveis por `anon`.
- **0** funções autenticadas com `search_path` não configurado.
- **43** funções possuem referência explícita a `auth.uid()` ou a `qse_v3.require_user()` no corpo. Esta é uma verificação estática, **não prova isolamento funcional**.
- **3** exceções à checagem direta:
  - `qse_friend_action(text,uuid,uuid)` é um wrapper que delega para `qse_friend_action(text,uuid,uuid,text)`, que verifica o usuário.
  - `qse_t24_published_cover(text)` é auxiliar usado para permitir acesso de autenticados a **capas publicadas** no Storage privado.
  - `qse_t24_published_preview(text)` é auxiliar usado nas políticas do Storage e projeções comunitárias para **prévias publicadas**.

**Não foi revogado nenhum EXECUTE.** As RPCs `qse_*` são contratos em uso ou legados a preservar; os dois helpers de prévia têm dependentes RLS/RPC. Revogar sem atualizar todos os consumidores poderia impedir leitura de imagens, login social, partidas e funcionalidades sociais. O aviso do advisor permanece por desenho arquitetural, exigindo auditoria de autorização de cada função antes de uma migração mais invasiva.

Funções `SECURITY DEFINER` internas no schema `qse_v3` não estavam expostas a `authenticated` na verificação. Uma auditoria de privilégios, presença de guarda e `search_path` não substitui teste HTTP com JWTs reais.

## 4. Auth — proteção contra senhas vazadas

**Pendente, não ativada.** O conector Supabase atualmente expõe consultas/migrations/advisors, mas **não disponibiliza alteração da configuração Supabase Auth nem cadastro de usuários**. Isso é uma configuração do projeto, não uma migration PostgreSQL. A documentação oficial informa que a proteção contra senhas vazadas está disponível nos planos Pro e superiores.

Abrir https://supabase.com/dashboard/project/shuzporktifgiotvnpbz/auth/providers?provider=Email e procurar `Leaked Password Protection` (proteção de senhas vazadas), ativar caso o projeto tenha acesso e verificar novamente `get_advisors(security)`. Não presumir que foi ativado.

Docs: https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection

## 5. T24 Comunidade — E2E com contas reais

**Pendente.** Não há mecanismo de criar contas Auth e emitir sessões reais no conector disponível. Não foram utilizados e-mails inventados, contas de jogadores ou tokens `service_role`. O ensaio precisa usar caixas de correio sob controle do responsável; os quatro perfis devem ser:
- `owner`: criador.
- `reader`: leitor e primeiro denunciante.
- `r1`: segundo denunciante.
- `r2`: terceiro denunciante.

As quatro contas são suficientes porque `reader` também denuncia; não são cinco contas. Não usar dados existentes.

Ciclo de teste necessário: criar 5 cartas e enviar original, `_library.png`, `_duel.png` e `deck_cover.png` como `owner`; solicitar `qse_deck_publish_request`; aprovar via SQL administrativo; validar `qse_community_decks` e `qse_community_deck` como `reader`, inclusive `cover_path` preenchido e acesso autorizado só às prévias/capa, nunca originais; denunciar em sequência com `reader`, `r1`, `r2` e validar transição na terceira; pedir `qse_deck_unpublish`; remover os dados, objetos de Storage e sessões de teste.

**JSONs positivos reais não foram produzidos**. Não habilitar a Comunidade no cliente até homologação real. Solicitar ao dono do projeto quatro endereços/aliases de e-mail sob seu controle e um fluxo de cadastro/login real (Godot/SDK Supabase ou Dashboard Auth) antes de executar o ensaio; nunca armazenar senhas ou tokens no repositório.

## 6. Mata-Mata

Sem alterações em `qse_duel_*` nem nos contratos de sala. Integração de decks próprios ou comprados permanece fora de escopo até decisão do dono.

## Resultado final

Índices: **corrigidos e implantados**. Segurança: **verificação de privilégios concluída, avisos sem correção de Auth ou mudanças nas RPCs**. Comunidade: **E2E não executado**. PR fica em rascunho e sem merge.
