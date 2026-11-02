# T24 Premium — pedidos mínimos ao backend (para o ChatGPT)

O cliente Godot já está pronto e **funciona sem estes itens** (cai no próximo critério válido).
Nada abaixo altera dados existentes. Regras: RLS, nunca `service_role` no cliente.

## 1. CATALOG — regras de destaque (`public.qse_catalog_featured`)
Leitura pública (anon + authenticated, só `active = true`); escrita só pela administração (SQL/painel).

| coluna | tipo | regra |
|---|---|---|
| id | uuid pk default gen_random_uuid() | |
| kind | text not null | `pin` (deck oficial fixado) ou `campaign` (evento sazonal) |
| deck_ref | text null | `official:<id>` ou `creator:<uuid>` |
| theme | text null | temática/categoria/tag (campanha por tema, ex.: `Natal`) |
| title | text null, ≤ 40 | rótulo exibido (ex.: "Especial de Natal") |
| starts_at / ends_at | timestamptz null | janela; nulo = sem limite |
| priority | int default 0 | maior primeiro |
| active | bool default true | |

`check (deck_ref is not null or theme is not null)`. Exemplos:
```sql
insert into public.qse_catalog_featured(kind, theme, title, starts_at, ends_at)
values ('campaign','Natal','Especial de Natal','2026-12-01T03:00:00Z','2026-12-26T03:00:00Z'),
       ('campaign','Halloween','Noite de Halloween','2026-10-20T03:00:00Z','2026-11-01T03:00:00Z');
insert into public.qse_catalog_featured(kind, deck_ref, title, priority)
values ('pin','official:lendas_urbanas','Escolha da equipe',10);
```
O cliente lê `GET /rest/v1/qse_catalog_featured?select=*` junto com o catálogo (cache de 6 h);
as datas são avaliadas no aparelho, então uma campanha entra e sai sozinha.
Prioridade no cliente: pin → campanha ativa → populares (score > 0) → lançamentos (45 dias) → oficial padrão.

## 2. GAME — capa escolhida pelo criador (`public.qse_creator_decks`)
| coluna | tipo |
|---|---|
| cover_mode | text not null default 'auto' check in ('auto','card','upload') |
| cover_card_id | uuid null references qse_creator_cards(id) on delete set null |
| cover_image_path | text null — exatamente `<owner_id>/<deck_id>/deck_cover.png` |

- Storage `qse-deck-originals`: permitir ao dono enviar `deck_cover.png` (mesmas travas de moderação das prévias:
  só em `draft`); leitura por autenticados quando o deck estiver `published` (igual às prévias).
- `qse_community_decks.cover_path`: `cover_image_path` se `upload`; prévia `library` da carta `cover_card_id` se `card`;
  senão o comportamento atual.
- Se a carta da capa for excluída, `on delete set null` e o cliente volta para a automática.
- **Ao confirmar**, o cliente liga `CreatorSync.COVER_COLUMNS` (hoje `false`: enviar coluna inexistente derrubaria o upsert).

## 3. GAME — limites de enquadramento
O editor agora permite reduzir o zoom (imagem inteira dentro da carta, com fundo desfocado).
Confirmar que `portrait_zoom` e `duel_zoom` aceitam **0.35 a 6** (sem `check (>= 1)`); caso exista, ajustar.
Os campos `portrait_*` (Biblioteca) e `duel_*` (Mata-Mata) continuam separados.

## Resposta esperada
Nomes finais, constraints aplicadas, políticas de Storage e resultado dos advisors.
