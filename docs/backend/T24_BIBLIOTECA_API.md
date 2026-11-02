# T24 — Backend da Biblioteca: contrato implementado (GAME/CATALOG)

**Fonte de requisitos:** [T24_BIBLIOTECA.md](../contracts/T24_BIBLIOTECA.md), branch original `claude/biblioteca-backend-t24` (commit `2825f56`). Implementação: `chatgpt/t24-biblioteca-backend`. Sem alterações no Godot. **Não ativar fluxos públicos antes de testes reais de moderação, upload e integração.**

## Integração

GAME REST `https://shuzporktifgiotvnpbz.supabase.co/rest/v1/rpc/<RPC>`

CATALOG REST para metadados oficiais `https://bsxicvlngphazesuzaee.supabase.co/rest/v1/qse_catalog_decks`

Cabeçalhos GAME: `apikey: <PUBLISHABLE_KEY_GAME>`, `Authorization: Bearer <JWT_GAME>`, `Content-Type: application/json`. **Não usar service_role no Godot**. Os exemplos abaixo mostram o corpo JSON de retorno das RPCs; os erros retornam JSON `{"error":"codigo"}` e podem vir com HTTP 200 por se tratar de `jsonb` retornado pela função.

## 1 — Popularidade (aplicado no GAME)

### `qse_deck_record_play(p_deck_ref text)`

Registrar apenas após o evento **real** de partida iniciada e quando houver uma referência a deck. Valores: `official:lendas_urbanas`, `creator:<uuid-canonico>`.

Requisição:
```json
{"p_deck_ref":"official:lendas_urbanas"}
```
Resposta com **nova** contagem (formato exato):
```json
{"deck_ref":"official:lendas_urbanas","recorded":true,"played_at":"<ISO8601_SERVIDOR>","reason":null}
```
Na segunda chamada pelo mesmo usuário nos **60 minutos corridos após o último registro válido**:
```json
{"deck_ref":"official:lendas_urbanas","recorded":false,"played_at":null,"reason":"duplicate_hour"}
```
O servidor usa bloqueio transacional por jogador/deck e verifica a janela móvel de 60 minutos; como proteção adicional, a unicidade no banco é `(user_id,deck_ref,played_hour)`. A tabela tem RLS e policy de INSERT por dono, mas **nenhum INSERT nem SELECT direto é concedido ao cliente**: registrar somente por RPC validada. O servidor aceita official ID presente em `qse_v3.duel_decks` ou creator ID existente pertencente ao usuário / publicado. **Não registrar partida de História sem uma referência real de deck.**

Erros: `unauthorized`, `invalid_deck_ref`, `deck_not_found`.

### `qse_deck_stats(p_refs text[])`

Requisição (até 100 referências):
```json
{"p_refs":["official:lendas_urbanas"]}
```

Resposta **real aferida com sessão autenticada simulada** em 01/11 (zero eventos/favoritos):
```json
[{"score":0,"deck_ref":"official:lendas_urbanas","favorites":0,"plays_30d":0,"players_30d":0}]
```
Formato: **array** de objetos JSON, em ordem lexicográfica de `deck_ref`. `plays_30d` conta eventos aceitos nos 30 dias anteriores; `players_30d` conta usuários únicos nessa janela; `favorites` é o total atual de favoritos, e `score` é numérico: `players_30d * 2 + plays_30d + favorites * 3`. A função devolve **somente totais, sem IDs de jogadores**.

Erros (objeto em vez de array): `unauthorized`, `invalid_refs` (ref nula/inválida ou acima de 100). Godot deve tratar `score=0` como **sem engajamento medido**, exibir sem número fictício e colocar no fim dos Populares.

## 2 — Recentes (aplicado no CATALOG e GAME)

**CATALOG:** `public.qse_catalog_decks.published_at timestamptz NOT NULL`. Para o único deck oficial `lendas_urbanas`, valor gravado:

```json
{"id":"lendas_urbanas","published_at":"2026-10-30T13:33:30Z"}
```

**Proveniência:** primeiro commit que integra Lendas Urbanas à Biblioteca do jogo, `c39fb105` (PR #29), às 13:33:30 UTC de 30/10/2026. Os PNGs existiam antes (commit `24895e49`, 04:38:30 UTC). A data usada é a **integração do deck ao jogo** — se houver uma data oficial de lançamento anterior, a moderação deve confirmá-la e corrigir a metadata, sem inferir de `updated_at`.

**GAME:** `public.qse_creator_decks.published_at timestamptz` nullable. Trigger `qse_v3.t24_set_published_at` fixa `now()` na transição **para `published`** e preserva a data quando houver atualizações sem nova aprovação; reaprovação após sair de `published` recebe uma nova data. `updated_at` permanece independente. O cliente **não tem RPC para definir `published_at`** e o status é guardado contra UPDATE direto.

## 3 — Comunidade (aplicado no GAME)

### Estado e moderação

Colunas de `public.qse_creator_decks`: `status` (draft, pending_review, published, rejected, removed), `published_at`, `review_note` e `visibility`. Deck nasce `draft/private`; cliente solicita `pending_review`; só moderador com acesso administrativo direto ao banco altera para `published/rejected/removed`. O trigger força `public` apenas quando `published`; os demais estados permanecem `private`.

A policy atual de SELECT da tabela permite somente `owner_id=auth.uid()`; portanto **`review_note` só é legível diretamente pelo dono**. O RPC público de catálogo não inclui a nota. Enquanto `pending_review` ou `published`, guardas impedem edição direta do deck e das cartas pelo usuário, inclusive movimentação da carta para outro deck.

Moderação fora do jogo (SQL administrativo, **nunca no cliente**):
```sql
-- APROVAR, apenas após verificação da solicitação
update public.qse_creator_decks
set status='published', review_note=null
where id='<UUID>' and status='pending_review';

-- REJEITAR (nota vista só pelo autor)
update public.qse_creator_decks
set status='rejected', review_note='Descreva a correção necessária'
where id='<UUID>' and status='pending_review';
```

### `qse_deck_publish_request(p_deck uuid)`

Requisição: `{"p_deck":"<UUID>"}`

Sucesso:
```json
{"deck_id":"<UUID>","status":"pending_review"}
```
Só dono de deck `draft` ou `rejected`. Requer **mínimo de 5 cartas** com nome não vazio, imagem original existente e arquivos de prévia **library.png e duel.png efetivamente existentes** no bucket privado `qse-deck-originals`. Exigência de prévias é proteção adicional para impedir vitrine sem imagens.

Erros: `unauthorized`; `deck_not_found`; `invalid_status`; `{"error":"min_cards","minimum":5,"actual":0}` (actual varia); `{"error":"missing_images_or_previews","valid":0,"total":5}` (contagens variáveis).

### `qse_deck_unpublish(p_deck uuid)`

Requisição: `{"p_deck":"<UUID>"}`. Sucesso: `{"deck_id":"<UUID>","status":"draft"}`. O acesso público às prévias é revogado imediatamente pela policy do Storage (ressalvados links previamente assinados até sua expiração). Erros: `unauthorized`, `deck_not_found`, `removed`.

### `qse_community_decks(p_query text,p_theme text,p_sort text,p_limit int,p_cursor text)`

Todos parâmetros opcionais. Exemplo:
```json
{"p_query":null,"p_theme":null,"p_sort":"popular","p_limit":24,"p_cursor":null}
```
Resposta **real**, na base atual sem decks publicados:
```json
{"items":[],"next_cursor":null}
```

Quando existirem dados, cada item tem exatamente estas chaves:
```json
{
 "id":"<UUID>","name":"<NOME>","description":"<DESCRICAO>",
 "category":"<CATEGORIA>","card_count":5,
 "cover_path":"<PATH_LIBRARY_PNG_OU_NULL>",
 "creator":{"public_id":"<QSE_ID_OU_NULL>","nickname":"<NICK_OU_NULL>","equipped_character_id":"<SKIN_OU_NULL>","level":1},
 "published_at":"<ISO8601>","score":0
}
```

`p_theme` pesquisa igualdade de categoria. `p_query` procura por nome/descrição sem diferenciar maiúsculas. Ordenação: `popular` (score desc), `recent` (published_at desc), `name` (nome asc), com id como desempate. `p_limit` de 1 a **48**. `next_cursor` é base64 da posição decimal seguinte, por exemplo `"MjQ="` para offset 24, ou `null` no fim. **Cursor baseado em offset:** alterações entre páginas podem deslocar resultados; reiniciar busca ao mudar ordenação/filtros.

Erros: `unauthorized`, `invalid_sort`, `invalid_limit`, `invalid_filter`, `invalid_cursor`.

### `qse_community_deck(p_deck uuid)`

Requisição: `{"p_deck":"<UUID>"}`. Se publicado, JSON com **somente prévias**:
```json
{
 "deck":{
   "id":"<UUID>","name":"<NOME>","description":"<DESCRICAO>",
   "category":"<CATEGORIA>","card_count":5,"published_at":"<ISO8601>",
   "creator":{"public_id":"<QSE_ID_OU_NULL>","nickname":"<NICK_OU_NULL>","equipped_character_id":"<SKIN_OU_NULL>","level":1}
 },
 "cards":[{
   "name":"<NOME>","description":"<DESCRICAO>",
   "preview_library_path":"<PATH_LIBRARY_PNG>","preview_duel_path":"<PATH_DUEL_PNG>",
   "crops":{
     "library":{"center_x":0.5,"center_y":0.5,"zoom":1},
     "duel":{"center_x":0.5,"center_y":0.5,"zoom":1}
   }
 }]
}
```

**Valores ilustrativos acima, não resultados de deck real.** Somente nomes, descrições, caminhos de prévia e parâmetros de recorte; `image_original_path` e `owner_id` não são retornados como campos de perfil ou carta. Os caminhos de Storage existentes usam prefixos de usuário UUID como parte do identificador do objeto; não tratá-los como perfis, nem exibir diretamente ao jogador.

Erros: `unauthorized`, `deck_not_found` (inclui privado/removed/rejected/pending/nonexistent).

### `qse_deck_report(p_deck uuid,p_reason text)`

Requisição: `{"p_deck":"<UUID>","p_reason":"Conteúdo impróprio"}`

Sucesso enquanto publicado:
```json
{"reported":true,"deck_id":"<UUID>","status":"published","report_count":1}
```
Na **terceira denúncia distinta desde a publicação atual**, resposta:
```json
{"reported":true,"deck_id":"<UUID>","status":"pending_review","report_count":3}
```
A atualização de status ocorre dentro da transação e remove o deck da vitrine imediatamente. Uma pessoa pode denunciar **no máximo uma vez por deck, em todos os ciclos**. Não é permitido denunciar deck próprio.

Erros: `unauthorized`, `invalid_reason` (1–280 caracteres após trim), `deck_not_published`, `cannot_report_own`, `already_reported`.

### Storage e privacidade

Bucket: **`qse-deck-originals` (PRIVATE)**. A policy `qse_deck_published_previews_read` autoriza SELECT para usuários autenticados apenas sobre arquivos nomeados `<card_uuid>_library.png` ou `<card_uuid>_duel.png` pertencentes a cartas de decks efetivamente `published/public`; os próprios originais continuam sob a policy owner-only preexistente. Usar downloads autenticados do Supabase Storage (ou URLs assinadas de curta duração). Não tornar o bucket público nem enviar `service_role` ao app. **Não modificar `qse_deck_favorites`.**

## Limites de validação

Banco e permissões aplicados, validação de respostas negativas e RLS inspecionados. **Não há decks comunitários cadastrados no GAME para realizar o teste positivo fim a fim de aprovação/publicação/denúncias**. Nem a emissão de URLs assinadas nem a integração Android/Web foi testada. Relatório: [T24_BIBLIOTECA_TESTES.md](T24_BIBLIOTECA_TESTES.md).
