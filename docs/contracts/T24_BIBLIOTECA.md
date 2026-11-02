# T24 — Backend da Biblioteca (para o ChatGPT, GAME/CATALOG)

Decisões fechadas. O cliente Godot já tem os lugares prontos (Populares, Recentes, filtro Comunidade);
só troca o aviso de "dado indisponível" pelos campos abaixo. Regras de sempre: `auth.uid()`, RLS por dono,
nada de `service_role` no cliente, só perfis públicos. Referência de deck: `official:<id>` ou `creator:<uuid>`.

## 1. Popularidade (GAME)
- Tabela `qse_deck_plays(id, deck_ref text, user_id uuid, played_at timestamptz default now())`, RLS: insert só do próprio usuário, sem select direto.
- RPC `qse_deck_record_play(p_deck_ref text)`: chamada ao iniciar partida (História ou Mata-Mata). Ignora repetição do mesmo usuário+deck na mesma hora.
- RPC `qse_deck_stats(p_refs text[])` → `[{deck_ref, plays_30d int, players_30d int, favorites int, score numeric}]`.
  - `score = players_30d * 2 + plays_30d + favorites * 3`. Agregado; nunca expõe quem jogou.
- Cliente: Populares ordena por `score`; mostra "N jogadores · 30 dias" e "♥ N". Sem dados (score 0) vai para o fim, sem número inventado.

## 2. Recentes (CATALOG + GAME)
- Decks oficiais: coluna `published_at timestamptz not null` no catálogo, preenchida com a data real de lançamento (Lendas Urbanas: data do primeiro release).
- Decks da comunidade: `published_at` gravado pelo servidor só quando a moderação aprova (trigger); o cliente nunca envia.
- `updated_at` continua separado (mostrado como "Atualizado há").
- Cliente: Recentes ordena por `published_at desc`; mostra "Publicado há X".

## 3. Comunidade (GAME)
- Estados em `qse_creator_decks.status`: `draft` → `pending_review` → `published` | `rejected` (+ `removed`). Cliente não altera `status` diretamente.
- RPC `qse_deck_publish_request(p_deck uuid)`: dono, mínimo 5 cartas com imagem e nome; muda para `pending_review`. `qse_deck_unpublish(p_deck)` volta para `draft`.
- Moderação: feita pelo dono do projeto no painel/SQL (fora do cliente). Rejeição grava `review_note` legível só pelo dono do deck.
- RPC `qse_community_decks(p_query text, p_theme text, p_sort text in ('popular','recent','name'), p_limit int ≤ 48, p_cursor text)`
  → `{items:[{id, name, description, category, card_count, cover_path, creator:{public_id,nickname,equipped_character_id,level}, published_at, score}], next_cursor}`.
- RPC `qse_community_deck(p_deck uuid)` → deck + cartas (`name, description, preview_library_path, preview_duel_path, crops`). Original nunca é público.
- Storage: prévias de decks `published` legíveis por usuários autenticados (URL assinada ou política de leitura); rascunhos continuam só do dono.
- Denúncia: `qse_deck_report(p_deck uuid, p_reason text ≤ 280)`, 1 por usuário/deck; 3 denúncias distintas → volta a `pending_review` automaticamente.
- Favoritar/jogar decks da comunidade usa `creator:<uuid>` (já suportado por `qse_deck_favorites`).

## Ordem sugerida
1 (popularidade) → 2 (datas) → 3 (comunidade). Cada etapa é independente; o cliente entra depois de cada uma.
Ao terminar cada etapa, informar: nomes finais das RPCs, formato exato do retorno e exemplos de erro.
