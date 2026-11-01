# T21 — Contrato de backend: decks de jogadores, favoritos e preferências pessoais

Estado no jogo (cliente Godot, `main`):
- **Feito, local**: rascunhos de deck, imagens originais, recortes e favoritos ficam salvos **neste aparelho**, separados por dono (`user://players/<uuid GAME | guest>/`).
- **Pendente de backend**: publicar, listar publicados, favoritos sincronizados, sincronizar playlist. O botão **Publicar** responde `backend_pending` e mostra isso ao jogador. Nenhuma ação finge estar online.
- O cliente nunca usa `service_role`. Toda escrita é do próprio dono (`auth.uid()`) no projeto **GAME**. O CATALOG continua só com o catálogo oficial.

## 1. Entidades (projeto GAME)

### `player_decks`
| campo | tipo | regra |
|---|---|---|
| `id` | uuid PK | gerado no servidor |
| `owner_id` | uuid | `= auth.uid()`; imutável |
| `name` | text | 3–60 caracteres, trim |
| `description` | text | ≤ 400 |
| `category` | text | um de: `Lendas e terror`, `Personagens`, `Animais`, `Lugares`, `Objetos`, `Outros` |
| `visibility` | text | `private` · `unlisted` · `public` |
| `status` | text | `draft` · `published` |
| `card_count` | int | 5–30 (validar no servidor) |
| `created_at`, `updated_at`, `published_at` | timestamptz | servidor |

### `player_deck_cards`
| campo | tipo | regra |
|---|---|---|
| `deck_id` | uuid FK → `player_decks.id` on delete cascade | |
| `position` | int | 0..29, único por deck (reordenação) |
| `name` | text | 1–40, único por deck (comparação sem acento/caixa) |
| `description` | text | ≤ 300 |
| `image_path` | text | caminho no Storage (original) |
| `image_width`, `image_height` | int | do original |
| `crop_library` | jsonb | `{"x":0..1,"y":0..1,"zoom":1..6}` — moldura 5:7 |
| `crop_duel` | jsonb | idem — moldura 16:5 |

Recorte = centro normalizado da moldura no original + zoom (1 = menor ampliação que cobre a moldura). A região em pixels é calculada por `CardFramer.region()` (`scripts/decks/card_framer.gd`); o servidor só precisa validar faixas. O original nunca é alterado.

### `player_deck_favorites`
| `owner_id` uuid (= auth.uid()) | `deck_id` uuid | `created_at` | PK (`owner_id`,`deck_id`) |
Também aceitar ids de decks oficiais do CATALOG (ex.: `lendas_urbanas`) — sugerido `deck_ref text` com prefixo `official:` / `player:`.

### `player_preferences` (opcional, sincronizar playlist)
| `owner_id` uuid PK | `menu_music_hidden` text[] | `menu_music_deselected` text[] | `updated_at` |
Volume, qualidade gráfica, controles e idioma **continuam por aparelho** (dependem do hardware) e não devem ser sincronizados.

## 2. Storage (GAME)
Bucket `deck-images` (privado). Caminho: `<owner_id>/<deck_id>/<card_id>_original.<png|jpg|webp>` e prévias `<card_id>_library.png` (≤ 360 px) e `<card_id>_duel.png` (≤ 480 px).
- Upload/remoção só quando o primeiro segmento do caminho = `auth.uid()`.
- Leitura: dono sempre; terceiros só se o deck estiver `published` e `public|unlisted` (URL assinada ou política equivalente).
- Limite 12 MB por arquivo; tipos `image/png`, `image/jpeg`, `image/webp`.

## 3. RLS
- `player_decks` / `player_deck_cards`: select do dono; select de terceiros só `status='published' and visibility in ('public','unlisted')` (unlisted só por id direto, não em listagens). Insert/update/delete apenas `owner_id = auth.uid()`.
- `player_deck_favorites` / `player_preferences`: tudo apenas `owner_id = auth.uid()`.
- Nenhuma escrita em decks oficiais nem em partidas.

## 4. Operações (RPC sugeridas, `security invoker`)
| RPC | entrada | saída | erros |
|---|---|---|---|
| `qse_deck_save_draft` | deck + cartas (sem bytes) | `{deck_id, updated_at}` | `invalid_deck`, `not_owner` |
| `qse_deck_publish` | `deck_id` | `{published_at}` | `invalid_deck` (lista de problemas), `missing_image` |
| `qse_deck_delete` | `deck_id` | `{}` | `not_owner` |
| `qse_deck_list_mine` | — | rascunhos e publicados do dono | |
| `qse_deck_favorite_set` | `deck_ref`, `value bool` | `{favorite}` | `not_found` |
| `qse_deck_favorites` | — | lista de `deck_ref` | |
As mensagens de validação do cliente estão em `DeckDrafts.problems()` (`scripts/decks/deck_drafts.gd`) e devem ter equivalentes no servidor.

## 5. Integração prevista no cliente
`DeckDrafts.publish()` e `set_favorite()` passam a chamar as RPCs acima quando o backend existir; a migração envia os rascunhos locais do dono ao primeiro login com o servidor disponível, sem apagar o local até confirmar.

---

## 6. Integração implementada no cliente (T21-B)

`scripts/decks/creator_sync.gd` usa a Data API e o Storage do GAME com o JWT da conta
(nunca `service_role`). Todos os nomes de tabela/coluna estão em `CreatorSync.SCHEMA`.

| Recurso | Chamada |
|---|---|
| Deck | `POST /rest/v1/qse_creator_decks?on_conflict=id` (upsert) com `id`, `owner_id` (= usuário da sessão), `name`, `description`, `category`, `requested_visibility`. **Não envia** `visibility` nem `status`. |
| Cartas | `POST /rest/v1/qse_creator_cards?on_conflict=id` (upsert) com `id`, `deck_id`, `position`, `name`, `description`, `image_original_path`, `portrait_center_x/y`, `portrait_zoom`, `duel_center_x/y`, `duel_zoom`; depois `DELETE ...?deck_id=eq.<id>&id=not.in.(...)` para as cartas removidas. |
| Imagens | `POST /storage/v1/object/qse-deck-originals/<user>/<deck>/<card>_original.<ext>` (`x-upsert: true`), mais `<card>_library.png` e `<card>_duel.png`. Download por `/storage/v1/object/authenticated/...`. |
| Favoritos | `GET/POST(on_conflict=user_id,deck_ref)/DELETE /rest/v1/qse_deck_favorites` com `official:<id>` ou `creator:<uuid>`. |
| Playlist | `GET` e `POST ?on_conflict=user_id` em `qse_user_music_selection` (`hidden_track_ids`, `deselected_track_ids`). |

Mapeamento local → servidor: o UUID v4 do deck (`server_id`) e de cada carta é gerado no
cliente e gravado no rascunho local **antes** do envio; repetir após falha faz upsert no
mesmo id (sem duplicar). O rascunho local só é apagado depois que o servidor confirma a exclusão.

### Pontos para o ChatGPT confirmar no GAME
1. `qse_creator_cards` tem as colunas `deck_id` (FK) e `position` (ordem)? Se os nomes forem outros, basta trocar `card_deck`/`card_order` em `CreatorSync.SCHEMA`.
2. As tabelas aceitam `id` gerado pelo cliente (UUID v4) em `insert`, com `default gen_random_uuid()` só como alternativa?
3. Upsert (`on_conflict=id`, `on_conflict=user_id,deck_ref`, `on_conflict=user_id`) é permitido pelas políticas de `insert` + `update` do dono?
4. O original é enviado com a **extensão real** do arquivo importado (`png`/`jpg`/`webp`), sem reconverter, para preservar os bytes. O caminho fica `<card>_original.png|jpg|webp`, não só `.webp`. Se a política do bucket exigir exatamente `.webp`, avisar.
5. Excluir uma carta do rascunho remove a linha; os arquivos dela no Storage só são apagados quando o deck inteiro é excluído.
