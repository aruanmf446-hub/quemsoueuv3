# T24 — Hotfix de RLS para uploads e upsert no GAME

**Deploy concluído no Supabase GAME:** `shuzporktifgiotvnpbz`.  
**Migration registrada:** `20261102181355_t24_storage_upload_upsert_rls_path_hotfix`.  
**GitHub:** branch `chatgpt/storage-upsert-rls-t24-hotfix`, PR em rascunho, **não fazer merge** sem revisão.

## Causa comprovada no banco

Havia cinco políticas introduzidas pela T24 que, em suas expressões de autorização, usavam `storage.foldername(d.name)` dentro de uma subconsulta com `d` = `public.qse_creator_decks`.

`d.name` é o título do deck, não o caminho do objeto no bucket. Assim, a comparação entre `d.id` e o segundo segmento de `storage.foldername(d.name)` falhava mesmo para o dono e para decks `draft`.

A política `qse_t24_originals_insert_draft` era **RESTRICTIVE**. Como `RESTRICTIVE` combina com as políticas permissivas via AND, ela bloqueava arquivos das cartas e `deck_cover.png` apesar das permissões originais da T21. A mesma referência incorreta aparecia nas políticas de UPDATE, DELETE e nas regras permissivas da capa.

**Não era uma política restritiva limitada à capa.** A política `qse_t24_cover_insert_draft` era PERMISSIVE e valia apenas para capas; o bloqueio das cartas vinha da política restritiva de moderação. O HTTP com `x-upsert: true` requer INSERT + SELECT + UPDATE, mas essas permissões já existiam: era a avaliação incorreta do caminho que impedia os writes.

## Correção mínima aplicada

Recriadas somente as cinco políticas afetadas:

| Política | Tipo | Comando | Condição final |
| --- | --- | --- | --- |
| `qse_t24_originals_insert_draft` | RESTRICTIVE | INSERT | Mesmo dono, `storage.foldername(objects.name)[2]` corresponde ao UUID do deck, status `draft` ou `rejected` |
| `qse_t24_originals_update_draft` | RESTRICTIVE | UPDATE USING / WITH CHECK | Mesma verificação na linha anterior e nova |
| `qse_t24_originals_delete_draft_or_orphan` | RESTRICTIVE | DELETE | Dono pode excluir em `draft`/`rejected` ou limpar arquivo órfão após remoção do deck |
| `qse_t24_cover_insert_draft` | PERMISSIVE | INSERT | Caminho exato `<owner_id>/<deck_id>/deck_cover.png`, dono, deck `draft`/`rejected` |
| `qse_t24_cover_update_draft` | PERMISSIVE | UPDATE USING / WITH CHECK | Mesmas verificações de capa na linha anterior e nova |

`pending_review`, `published` e `removed` **não permitem INSERT ou UPDATE**. As políticas de capa mantêm o nome histórico `_draft`, mas seu novo predicado também aceita `rejected`.

## Inventário final de TODAS as políticas específicas do bucket

Todas destinam-se a `authenticated`:

| Política | Tipo | Ação | Papel |
| --- | --- | --- | --- |
| `qse_deck_originals_add` | PERMISSIVE | INSERT | T21: dono, pasta e nomes `<card_uuid>_original.(png\|jpg\|jpeg\|webp)`, `<card_uuid>_library.png`, `<card_uuid>_duel.png` |
| `qse_t24_cover_insert_draft` | PERMISSIVE | INSERT | Capa `deck_cover.png` conforme dono/deck/status |
| `qse_t24_originals_insert_draft` | RESTRICTIVE | INSERT | Trava de moderação `draft`/`rejected` |
| `qse_deck_originals_edit` | PERMISSIVE | UPDATE | T21: dono, pasta e nomes de cartas válidos |
| `qse_t24_cover_update_draft` | PERMISSIVE | UPDATE | Capa com dono/deck/status |
| `qse_t24_originals_update_draft` | RESTRICTIVE | UPDATE | Trava de moderação `draft`/`rejected` |
| `qse_deck_originals_read` | PERMISSIVE | SELECT | T21: somente dono e pasta de dono, incluindo **originais privados** |
| `qse_deck_published_previews_read` | PERMISSIVE | SELECT | Somente prévias `_library.png`/`_duel.png` de cartas em decks `published/public` |
| `qse_t24_published_covers_read` | PERMISSIVE | SELECT | Somente capa selecionada `cover_mode=upload` em deck `published/public` |
| `qse_deck_originals_remove` | PERMISSIVE | DELETE | T21: dono e pasta de dono |
| `qse_t24_originals_delete_draft_or_orphan` | RESTRICTIVE | DELETE | Trava de moderação e remoção de arquivos órfãos |

**Sem alterar T21, sem novos privilégios para `anon`, sem `service_role` no cliente, bucket `qse-deck-originals` permanece privado.**

## Testes SQL executados — sessão autenticada simulada

Uma transação criou decks e cartas temporários vinculados ao UUID de um Auth existente e definiu `request.jwt.claim.sub` e `SET LOCAL ROLE authenticated`. **Nenhuma conta real foi alterada; a transação foi revertida (`ROLLBACK`).**

| Caso | Resultado |
| --- | --- |
| `draft`: INSERT + UPDATE + SELECT, 4 tipos de arquivo | PASS (12 verificações) |
| `rejected`: INSERT + UPDATE + SELECT, 4 tipos | PASS (12 verificações) |
| `pending_review`: INSERT bloqueado, 4 tipos | PASS |
| `pending_review`: UPDATE bloqueado, 4 tipos | PASS |
| `published`: INSERT bloqueado, 4 tipos | PASS |
| `published`: UPDATE bloqueado, 4 tipos | PASS |
| `draft`: `INSERT .. ON CONFLICT (bucket_id,name) WHERE archived_at IS NULL DO UPDATE`, 4 tipos | PASS |
| Leitor autenticado diferente: original publicado não legível | PASS |
| Leitor autenticado diferente: library, duel e capa selecionada publicados legíveis | PASS |

Após o `ROLLBACK`, verificação final: **0 decks de comunidade, 0 cartas, 0 objetos** no projeto GAME consultado. Não persistiram registros de teste.

## Consultas finais

- **0** políticas ainda usam `storage.foldername(d.name)`.
- `qse-deck-originals.public = false`.
- Advisors de segurança continuam com os avisos preexistentes: `rls_enabled_no_policy` INFO, `authenticated_security_definer_function_executable` WARN e `auth_leaked_password_protection` WARN. Esta migration não altera Auth nem SECURITY DEFINER.

## Limitação da validação

As verificações foram feitas no PostgreSQL, com RLS e papel `authenticated` reais, incluindo um SQL `INSERT .. ON CONFLICT DO UPDATE` equivalente à autorização necessária para upsert. **Não houve envio HTTP real de bytes via `POST /storage/v1/object` com um JWT de usuário** — essa chamada precisa ser repetida no cliente para confirmar o comportamento do gateway/storage-service.

**Atenção:** quando o Supabase GAME foi consultado, a tabela `qse_creator_decks` não continha decks e `qse_creator_cards` não continha cartas, apesar do relato de um deck real. Se o erro persistir, confirmar a URL GAME do cliente, a origem do JWT, a pasta usada e se o deck foi realmente persistido nesse mesmo projeto. Não assumir que a ausência de registros significa que o usuário não tenha feito o teste.

### Recomendação de reteste no jogo

Usar um deck real em `draft`; enviar os quatro arquivos com `x-upsert: true`; repetir um deles (sobrescrever) e confirmar HTTP 200/201; em seguida verificar a sincronização. Confirmar que o bloqueio retorna em `pending_review`.
