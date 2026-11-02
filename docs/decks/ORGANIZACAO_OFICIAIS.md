# Decks oficiais — Quem Sou Eu V3

Os assets oficiais ficam em `assets/duel/decks/oficial/<slug>/`, sem misturar com uploads de jogadores.

## Decks oficiais aprovados

| ID (imutável) | Nome | Estado dos arquivos |
|---|---|---|
| `lendas_urbanas` | Lendas Urbanas | 9 PNG originais presentes |
| `nostalgia_web` | Nostalgia Web | Aguardando imagens e deck.json |
| `sol_nascente` | Sol Nascente | Aguardando imagens e deck.json |
| `pinturas` | Pinturas | Aguardando imagens e deck.json |

Cada deck precisa conter `deck.json` (nome, ordem, mapa de IDs de carta para nomes) e suas imagens PNG. **Não inserir conteúdo fictício e não publicar no catálogo remoto antes dos assets serem validados.**

## Separação do backend

- **CATALOG** (bsxicvlngphazesuzaee): metadados oficiais em `qse_catalog_decks` e `qse_catalog_cards`; nunca armazenar decks pessoais aqui.
- **GAME** (shuzporktifgiotvnpbz): `qse_creator_decks`, `qse_creator_cards`, favoritos, estatísticas e Storage privado `qse-deck-originals`, com ownership e moderação.
- **CHAT**: separado, não participa do catálogo.
- **Cloudflare R2:** descartado. Não configurar nem referenciar como backend ativo.

Preservar referências estáveis `official:lendas_urbanas` e IDs de cartas `lendas_urbanas/<slug>` apesar da nova pasta física. Novos oficiais usam `official:nostalgia_web`, `official:sol_nascente` e `official:pinturas`. Caminhos `res://` de imagens são distintos de IDs lógicos.

## Compatibilidade ainda exigida

Atualizar em tarefa de implementação/teste os leitores locais `scripts/decks/deck_library_catalog.gd` e `scripts/services/catalog_service.gd`; o sincronizador `tools/duel/sync_decks.py`; os caminhos diretos antigos do Duelo e fixtures; e o `image_path` remoto (ou fazer migração coordenada depois de testar). Godot deve reimportar os PNGs movidos; não reutilizar `.import` antigo com `source_file` anterior. Não aplicar `supabase/seed/duel_decks.sql` antigo sem revisar: ele contém DELETE de decks ausentes.

O código de produção ainda aponta para o caminho legado: manter a migração de caminho bloqueada até que todos os consumidores e testes estejam corrigidos no mesmo PR. Este documento registra a arquitetura, não declara a migração concluída.
