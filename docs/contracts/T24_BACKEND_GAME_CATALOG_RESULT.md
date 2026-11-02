# T24 — Backend GAME/CATALOG implementado (validação)

**Implantação direta nos projetos Supabase oficiais.** Este documento não autoriza merge dos PRs #52 ou desta branch.

## CATALOG (bsxicvlngphazesuzaee)

Tabela pública `public.qse_catalog_featured`:
- `id uuid PK DEFAULT gen_random_uuid()`
- `kind text NOT NULL CHECK ('pin','campaign')`
- `deck_ref text NULL` com padrão `official:<id>` ou `creator:<uuid>`
- `theme text NULL`, `title text NULL` no máximo 40 caracteres
- `starts_at timestamptz NULL`, `ends_at timestamptz NULL`
- `priority integer NOT NULL DEFAULT 0`, `active boolean NOT NULL DEFAULT true`
- CHECK exige `deck_ref` ou `theme` e datas ordenadas.

RLS habilitado. `SELECT` concedido a `anon` e `authenticated` **somente se active = true**. Sem permissões de escrita para clientes. Exemplos cadastrados: Natal (01–26 dezembro de 2026) e Halloween (20 outubro–01 novembro de 2026), UTC-3 interpretado via `03:00Z`. **Sem pin automático**.

## GAME (shuzporktifgiotvnpbz)

`public.qse_creator_decks`:
- `cover_mode text NOT NULL DEFAULT 'auto'`, CHECK `('auto','card','upload')`.
- `cover_card_id uuid NULL` FK `qse_creator_cards(id) ON DELETE SET NULL`.
- `cover_image_path text NULL` CHECK caminho exatamente `<owner_id>/<deck_id>/deck_cover.png`.
- Trigger `qse_t24_validate_deck_cover` impede vincular carta de outro deck ou de outro dono.
- Trigger de moderação preexistente `qse_t24_deck_guard` já proíbe alterações dos decks fora do estado `draft` para o cliente.

Storage privado `qse-deck-originals`:
- Políticas novas `qse_t24_cover_insert_draft` e `qse_t24_cover_update_draft`: apenas proprietário e deck `draft`, nome exato `deck_cover.png`.
- Política nova `qse_t24_published_covers_read` + helper `public.qse_t24_published_cover`: somente `authenticated` e somente `cover_image_path` efetivamente selecionado em deck `published` e `public`.
- O bucket permanece privado; as permissões para originais e prévias preexistentes não foram alteradas nesta tarefa.

`public.qse_community_decks` preserva a assinatura, paginação, filtros e JSON atual. A chave `cover_path` já existente usa:
1. `upload`: caminho da capa existente no bucket;
2. `card`: preview `_library.png` da carta escolhida no próprio deck;
3. `auto` ou arquivo ausente: primeiro preview publicável já usado anteriormente.

`public.qse_community_deck` conserva `{deck,cards}` e acrescenta `deck.cover_path`, **fora do perfil público**. Ambos exigem JWT válido do GAME; sem JWT retornam `{"error":"unauthorized"}`.

`public.qse_creator_cards`:
- `portrait_zoom` e `duel_zoom`: CHECK `BETWEEN 0.35 AND 6`.
- `portrait_center_x/y` e `duel_center_x/y` continuam independentes.
- Constraints T21 de máximo 6 permanecem compatíveis.

**Para o Claude:** habilitar `CreatorSync.COVER_COLUMNS` somente após conferir a sincronização REST, o estado de moderação e as prévias na aplicação. Não alterar `qse_deck_favorites`.

## Teste ponta a ponta solicitado (cinco etapas)

**Pendente — não executado.** Não foram fornecidas duas contas de teste reais distintas, credenciais consentidas nem uma sessão de cliente autenticada pelo conector. O banco GAME tinha 5 contas já existentes e 0 cartas antes da implantação. Não reutilizei usuários nem seus dados, e não gerei tokens privilegiados ou cadastros artificiais.

1. Criar deck com cinco cartas e três imagens por carta: **não executado**.
2. Publicação `qse_deck_publish_request` e aprovação administrativa: **não executado**.
3. Ler `qse_community_decks` e `qse_community_deck` como outro jogador, prévias permitidas/originais negados: **não executado**.
4. Três denúncias de três contas distintas: **não executado**.
5. `qse_deck_unpublish` e limpeza de fixtures: **não executado**.

**Verificações SQL executadas:** tabelas, constraints, funções, política RLS, papel anon sem escrita no CATALOG, helpers de capa sem dados publicados, funções sem JWT retornando `unauthorized`, migrations registradas. Sem decks publicados, não existe retorno real `cover_path` não nulo para demonstrar.

## Advisors após implantação

CATALOG:
- Segurança: sem avisos.
- Desempenho: `unused_index` INFO (índice novo, ainda sem utilização em consultas).

GAME:
- Segurança: `rls_enabled_no_policy` INFO; `authenticated_security_definer_function_executable` WARN; `auth_leaked_password_protection` WARN.
- Desempenho: `unindexed_foreign_keys` INFO; `unused_index` INFO.

Referências:
- https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable
- https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection
- https://supabase.com/docs/guides/database/database-linter?lint=0001_unindexed_foreign_keys

**Status:** backend implantado nos projetos reais; **não aprovado ponta a ponta** e sem merge GitHub.
