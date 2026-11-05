# Auditoria e implantacao — revisao manual de decks (GAME)

**Ambiente:** Supabase GAME `shuzporktifgiotvnpbz` — somente esse projeto.  
**Contrato:** `docs/backend/DECKS_STORAGE_REVISAO_MANUAL.md` na revisao `fcfdb23` de `work/decks-storage-revisao-manual`.  
**Estado:** backend aplicado no Supabase em 2026-11-05; este branch versiona as migracoes **ja executadas**. Nao reaplicar migracoes existentes.

## Identidade e autorizacao

A unica entrada preexistente de `public.qse_editor_admins` foi comparada ao Supabase Auth (usuario existente, nao excluido) e ao perfil `qse_v3.player_profiles`. O dono confirmou a conta de email **`a********6@gmail.com`**. Nickname no perfil: `NULL`. Nenhuma conta/nickname foi criada ou alterada.

Criada `public.qse_deck_reviewers`, RLS habilitado, sem grants para `anon` ou `authenticated`, com **somente esse UUID Auth inserido pontualmente**. Novos administradores do editor NAO herdam revisao. Criada `public.qse_deck_review_decisions` para auditoria de autor, data, status e motivo, tambem com RLS e sem grants ao cliente. Funcao auxiliar `qse_v3.deck_review_is_moderator()` compara `auth.uid()` diretamente com a lista restrita.

## Migracoes reais aplicadas no GAME

| Versao | Nome |
|---|---|
| `20261105222130` | `qse_deck_review_acl_and_storage_20261105` |
| `20261105222157` | `qse_deck_review_read_rpcs_20261105` |
| `20261105222227` | `qse_deck_review_atomic_decide_20261105` |

### RPCs instaladas (public; retornos jsonb)

- `qse_deck_review_access()` -> `{"is_moderator":true/false}`.
- `qse_deck_review_queue(p_limit integer DEFAULT 50)` -> `{"items":[{"id":"uuid","name":"...","status":"pending_review"}]}`. `p_limit` aceita de 1 a 100.
- `qse_deck_review_detail(p_deck uuid)` -> `{"deck":{"id":"uuid","name":"...","description":"...","status":"pending_review","creator":{"nickname":null},"cover_path":"owner/deck/deck_cover.png ou null"},"cards":[{"id":"uuid","name":"...","preview_library_path":"...","preview_duel_path":"..."}]}`.
- `qse_deck_review_decide(p_deck uuid,p_approved boolean,p_reason text DEFAULT NULL)` -> `{"deck_id":"uuid","status":"published|rejected","review_note":null|"motivo"}`.

Todas as quatro RPCs sao `SECURITY DEFINER`, `search_path=''`, com `EXECUTE` permitido apenas a `authenticated` e validacao **interna** de `auth.uid()` e de papel. Chamada de jogador nao revisor retorna `forbidden`; sem sessao nao tem EXECUTE pela role `anon` (e verificacao interna retorna `unauthorized` quando `auth.uid()` e nulo).

`decide` faz `SELECT ... FOR UPDATE` na linha do deck: o mesmo lock de `qse_deck_unpublish`. Se o autor retira antes, o revisor recebe `invalid_status`; se o revisor decide antes, a retirada do autor ainda pode restaurar `draft` pelo fluxo existente. Cada decisao aceita somente `pending_review` e gravacao de auditoria ocorre na mesma transacao. Aprovar verifica 5–30 cartas, nomes, imagens originais e ambas as previews no catalogo de `storage.objects`, mais capa quando `cover_mode='upload'`. Reprovar exige motivo aparado de 3–280 caracteres. Triggers e fluxos originais preservados.

## Storage / RLS

Bucket `qse-deck-originals` permanece **privado**, com tamanho maximo de 12 MiB por objeto. Politica nova: `storage.objects.qse_deck_pending_review_assets_read`, somente `SELECT TO authenticated`, exige bucket correto e `qse_v3.deck_review_pending_asset(name)`: usuario moderador, deck **pending_review**, e caminho vinculado a uma carta `_library.png`, `_duel.png` ou `deck_cover.png` da capa `upload`. **Nao** autoriza arquivos `_original.*`, outros rascunhos, DELETE/UPDATE/INSERT, nem bucket publico. Politicas anteriores de leitura pelo proprio autor e leitura das previas publicadas foram preservadas. Dados publicos dos detalhes nao incluem email nem Auth UUID em campos de perfil; caminhos Storage seguem o contrato e usam o prefixo UUID do owner.

## Testes executados (somente banco, com rollback)

- Confirmacao de **uma unica conta** em `qse_editor_admins` + Auth ativo + perfil; uma entrada em `qse_deck_reviewers`.
- Verificacao de grants: `authenticated` pode executar as quatro RPCs; `anon` nao; tabelas administrativas nao legiveis por ambas as roles.
- Simulacao do contexto SQL `authenticated` com `request.jwt.claim.sub` de usuario real: revisor recebeu `is_moderator:true` e fila; jogador comum/autor `false`/`forbidden`; GUC sem sessao retornou `false`/`unauthorized`.
- Fixture temporaria com 5 cartas, 15 registros metadata de objetos e uma capa: autor leu seus 16 objetos; outro jogador leu 0; revisor leu exatamente 11 previews/capa e 0 originais. Outro jogador nao leu o deck privado.
- `review_detail` nao retornou email e trouxe 5 cartas e capa. `min_cards` e `invalid_reason` conferidos.
- Aprovacao -> `published` + `public` + `published_at`. Reprovacao -> `rejected` + `review_note`. Clique repetido -> `invalid_status`; duas entradas temporarias de auditoria geradas.
- Retirada anterior a decisao -> `invalid_status`; retirada posterior a aprovacao -> `draft` pelo RPC original.
- **TODAS as fixtures revertidas por `ROLLBACK`**. Pos-teste: 0 creator decks, 0 creator cards, 0 objetos Storage no bucket, 0 decisoes historicas; somente ACL persistida.

**Nao executados:** downloads fisicos de imagens (fixtures eram apenas metadata SQL), HTTP com JWT assinado, testes de concorrencia simultanea em 2 conexoes, testes E2E reais no Godot, navegador ou iPhone. A integridade de concorrencia se apoia no mesmo lock do backend e testes sequenciais de status; requer E2E com 2 clientes.

## Pendencia independente: duelo online

`qse_v3.duel_decks` e `qse_v3.duel_deck_cards` ainda sao o catalogo de partida; decks de criadores publicados nao entram automaticamente. **Nenhuma alteracao nas regras ou catalogo do duelo nesta entrega.**

## Seguranca pendente: TRUNCATE (NAO EXECUTADA)

A role `authenticated` ainda detem privilégio efetivo de `TRUNCATE` em `qse_creator_decks`, `qse_creator_cards`, `qse_deck_favorites`, `qse_user_music_selection`. RLS nao protege `TRUNCATE`. Correcao separada **somente proposta**:

```sql
REVOKE TRUNCATE ON TABLE
  public.qse_creator_decks,
  public.qse_creator_cards,
  public.qse_deck_favorites,
  public.qse_user_music_selection
FROM authenticated;
```

Nenhum `TRUNCATE` nem `REVOKE` foi executado. Sem mudancas em autenticacao, nickname, estatisticas, economia, musica, decks oficiais ou Cloudflare/R2.
