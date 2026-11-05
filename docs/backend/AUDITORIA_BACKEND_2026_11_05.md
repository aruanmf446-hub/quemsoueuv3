# Quem Sou Eu V3 — auditoria GAME/CHAT e entrega 05/11/2026

## Fontes inspecionadas
- Supabase GAME `shuzporktifgiotvnpbz`: esquema `qse_v3` e `public`, funções efetivamente instaladas via `pg_get_functiondef`, grants, índices/constraints, RLS, logs, advisers, migrations e contagens.
- Supabase CHAT `wurkpjgnbqklivjhcvxk`: tabelas/índices, funções RPC, grants, gateway Edge implantado (código recuperado da versão 9 antes da edição), advisories.
- GitHub `main` no commit `cb3bfc4205ebcc69807f24a0298a5ee6a6fdabb6`, contratos `docs/contracts/T21_DECKS.md` e `docs/contracts/T22_AMIZADES.md`; estado do cliente em `docs/backend/PENDENCIAS_2026_11_05.md`.

**Importante:** mudanças no GAME e CHAT e Edge v10 **já implantadas** nos projetos reais. Este PR é para versionamento e revisão do código, NÃO é pré-requisito para ativar as alterações no banco/Edge. NÃO executar as migrations novamente em produção. Nenhuma alteração foi aplicada à `main` ou ao cliente Godot.

## 1. Nickname: alterado e implantado (GAME)
Migração `20261105190949_qse_nickname_unique_immutable_20261105`.
- `qse_v3.player_profiles.nickname` mantém grafia exibida da primeira escolha, com trim de bordas ASCII + NFC.
- Unicidade por chave `lower(normalize(btrim(nickname), NFC))`, índice único PostgreSQL; não depender de SELECT sem constraint. A comparação ignora caixa e bordas, mas não executa case folding Unicode completo nem remove acentos (documentar se o contrato exigir isso no futuro).
- CHECK + trigger de bloqueio imutável, incluindo UPDATE SQL direto que consiga privilégios; RPC `public.qse_profile_update(p_nickname)` valida, serializa a própria conta por row lock, é idempotente quando a chave canônica coincide e retorna `{error,error_code}` para `nickname_taken`, `nickname_locked`, `invalid_nickname`.
- `qse_v3.public_fragment` retorna `nickname:null`, sem `Sem nickname`; `qse_profile_self` permanece com 8 campos: `user_id,public_id,nickname,equipped_character_id,level,experience,statistics,discoverable`.
- `qse_find_players` e `qse_profile_public` omitem perfis sem nickname para terceiros. `ensure_player` e a identidade `auth.uid()` preservados.
- Antes: 10 `auth.users`, 8 `player_profiles`, 7 nicknames nulos, 1 válido, 0 colisões case/trim, 0 placeholders. Depois: mesmas contagens; nenhuma conta renomeada automaticamente.

Migração `20261105191108_qse_duel_require_confirmed_nickname_20261105`:
- `qse_duel_create`, `qse_duel_join` e `qse_duel_start` recusam nickname ausente/inválido com `{error:'nickname_required',error_code:'nickname_required'}`. Convite `qse_duel_invite_join` delega ao `qse_duel_join` e herda o controle.
- Jogo convidado local sem conta não foi alterado; login Auth/MFA não foram alterados.

## 2. Mata-Mata: alterado e implantado (GAME)
Migração `20261105191141_qse_duel_fixed_order_presentation_window_20261105`.
- `qse_v3.duel_begin_match` sorteia e persiste `turn_order` ao abrir partida, **antes da seleção**, incluindo bots. `qse_v3.duel_match_json` e `qse_v3.duel_snapshot` já retornam `turn_order` à clientela autorizada; não alterados.
- `qse_v3.duel_advance` não sorteia novamente no fim da contagem, salvo caso de partidas antigas que começaram com `turn_order` vazio.
- Fase `countdown` usa `greatest(5,ceil(7 + 1.8 * quantidade_de_participantes))` segundos para apresentação antes de `duel_next_turn`.
- Preservados: row lock na sala, heartbeat/sweep, regras de pick/timeout/reveal e cartões secretos.
- Há 17 partidas históricas; 2 ainda em `selection` com ordem vazia antes da migração; fallback mantido por segurança.
- **Ainda pendente:** E2E real com dois clientes e cenários de turnos pulados envolvendo humanos/bots/desconexões. Inspeção estática não substitui teste de concorrência no cliente.

## 3. Bots: alterado e implantado (GAME + CHAT)
GAME: migrations `20261105191547_qse_game_room_bot_public_chat_feed_20261105` e `20261105191703_qse_game_bot_event_recent_public_only_20261105`.
- `qse_duel_chat_access` retorna dados adicionais só depois de verificar membership no GAME. `bot_match_id`, `bot_phase`, lista de bots da partida e até 12 eventos públicos nos últimos 60 segundos, **somente após `reveal_at`**; sem IDs de cartas privadas.
- Contrato de participantes e autorização anterior preservados.

CHAT: migration `20261105191616_qse_chat_bot_identity_dedupe_cooldown_20261105`.
- `qse_chat_messages.sender_bot_member_id` e CHECK de um único remetente (humano ou bot), preservando histórico humano.
- `qse_chat_bot_emissions` com PK `(conversation_id,match_id,event_seq,bot_member_id)`, RLS habilitado, sem grants a usuários, para dedupe persistente.
- `qse_chat_room_bot_emit` apenas `service_role`, lock transacional, idempotência, cooldown 15s e limite 240 caracteres. `qse_chat_room_read` conserva endpoint e inclui o remetente BOT, mantendo TTL antigo.
- Gateway `qse-chat-gateway` v10 **ACTIVE**, com o mesmo `verify_jwt=false` de antes porque valida JWT do GAME internamente (JWKS/Auth GAME). Fonte implantada **idêntica** ao arquivo nesta branch.
- Geração de mensagens no servidor a partir de fase/eventos públicos, identidade `BOT` e personalidades fixas; não permite cliente escolher remetente/ID do bot; falha de emissão não bloqueia leitura de mensagens humanas.

## 4. Backlog histórico T21/T22 — auditado, não duplicado
**T21 — recursos já implantados:**
- `qse_creator_decks`, `qse_creator_cards` (contêm `deck_id`, `position` e crops), `qse_deck_favorites` (3 registros), `qse_user_music_selection` (1 registro), `qse_deck_plays`, `qse_deck_reports`.
- RPCs de comunidade, decks, denúncia, estatísticas e `qse_deck_publish_request`. Esta última valida original/previews e leva o deck a `pending_review`, não publica automaticamente.
- Bucket `qse-deck-originals` privado, até 12 MiB, MIME jpeg/png/webp; políticas de acesso a originais/rascunhos/prévias; `qse-editor-media` existe.
- Ainda falta E2E real criar→upload→revisão/moderação→publicação/listagem→favorito→playlist; na inspeção havia **0 decks** em `qse_creator_decks`.

**T22 — recursos já implantados:**
- `friend_requests` com `request_message`/`created_at`; `account_preferences.last_seen_at`; `duel_friend_invites`.
- RPCs `qse_friends`, `qse_friend_action` (com e sem mensagem), `qse_mutual_friends`, `qse_duel_invites_between`, `qse_duel_invite_send`, `qse_presence_heartbeat`, `qse_recent_matches_with`, `qse_player_suggestions`, `qse_friend_stats`. `qse_friends` já inclui mensagem/data e sinais de presença/em partida.
- Havia 0 amizades/pedidos. Funcionalidade inspecionada no servidor, **não validada com contas reais**.
- Não alterado MFA, Auth providers, wallet, inventário, XP, progresso, favoritação ou playlist.

## 5. Testes realmente executados
- **SQL isolado com rollback:** duas contas existentes sem nickname em transação; checados perfil próprio `nickname:null` e 8 campos, primeira atribuição, retry idempotente, tentativa de troca via RPC, UPDATE SQL direto bloqueado, nickname_taken com outra conta, placeholder proibido e zero-width U+200B proibido. Todas as alterações de fixture foram revertidas; zero nickname fictício persistido.
- **SQL GAME:** criação/ingresso em sala negados para conta sem nickname; inspeção de funções confirma sorteio antecipado, fallback, duração de apresentação e feed público de bots.
- **SQL CHAT em transação com rollback:** conversa temporária, primeira emissão, mesma emissão duplicada, segunda emissão sujeita a cooldown, leitura com membro BOT e reversão de todos os dados temporários.
- **Grants:** `anon` e `authenticated` não executam `qse_chat_room_bot_emit`; somente `service_role`.
- **Postflight:** Auth 10, profiles 8, stats 8, wallets 8, favoritos 3, música 1, partidas 17. CHAT 0 conversas/0 mensagens/0 emissões depois dos testes.
- **Edge:** gateway v11 ACTIVE, código idêntico à branch, mantendo a configuração de JWT existente.

**Não executados / não afirmar aprovação:** chamadas HTTP simultâneas com dois JWTs reais, testes de OAuth Google/Discord/e-mail e restauração de sessão, Godot real/CI com dois clientes, integração cruzada real GAME→CHAT com mensagens em sala, teste de desconexão e timeout em tempo real.

## 6. Advisories após mudanças
- GAME: 21 avisos informativos `rls_enabled_no_policy` (tabelas internas/fechadas), 51 `authenticated_security_definer_function_executable` já existentes na arquitetura de RPC, 1 `auth_leaked_password_protection` (segurança Auth fora do escopo). Revisar individualmente sem revogar RPCs públicas usadas pelo cliente.
  - https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable
  - https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy
- CHAT: 4 avisos informativos `rls_enabled_no_policy` (inclui tabelas sem policy por desenho service-only). Não foram relatados avisos de segurança de maior gravidade no CHAT.

## 7. Pendências de validação (não bloquear dados existentes)
1. Duas sessões reais de contas independentes disputando mesmo nickname ao mesmo tempo; duas chamadas simultâneas da mesma conta; REST/refresh de sessão/OAuth real.
2. Teste Mata-Mata sincronizado em dois clientes reais, apresentação completa, humana e bots, duplo clique em pick, heartbeat concorrente, timeout, saída e reconexão.
3. Bot Chat com dois clientes reais e polling simultâneo, reconexão, expulsão/perda de acesso, confirmação de uma única mensagem idêntica, dedupe/cooldown e confirmação de ausência de cartas ocultas.
4. E2E de moderação/storage/favoritos/playlist e convites/amigos/presença/estatísticas.
5. Revisar com testes o linter `SECURITY DEFINER` preexistente. Não ativar MFA obrigatório por esta entrega.

Não criar contas de teste na produção, não redefinir nomes existentes e não reexecutar migrations já registradas como aplicadas.
