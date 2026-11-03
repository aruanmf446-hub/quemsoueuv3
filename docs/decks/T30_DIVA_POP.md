# T30 — Diva Pop: arte, catálogo e entrega

Coleção de dez retratos de animação 3D, baseada nas dez imagens enviadas e nos nomes originais aprovados pelo usuário. Cada nome é uma personagem original para jogo de identificação; não atribuir automaticamente nome de artista real.

Requisitos:
- Oficial, público, gratuito, `diva_pop`, 10 cartas, Categoria Música pop.
- Retratos verticais integrais, sem cortes; cartaz e cartas com asset `res://assets/duel/decks/oficial/diva_pop/carta_##.png`.
- Deck aparece no catálogo local somente quando todas as 10 artes estão disponíveis; não gerar cartas sem imagem.
- GAME usa `qse_v3.duel_decks`; CATALOG usa `qse_catalog_decks` e `qse_catalog_cards`; ambas seeds no repo.
- Nova campanha de recompensa `diva_pop_2026`: identificador distinto, zero custo, autoconcessão idempotente para contas antigas e futuras. Resgate cerimonial uma única vez por campanha.
- Preservar dados antigos e regras de El Fuego. Nem artistas pop nem imagens do deck viram skins jogáveis.
- Na importação: ZIP validado, Godot smoke, publish Web e verificação de dez cartas.

**Separação importante:** a criação de tabelas e seeds não substitui os bytes PNG. O usuário deve enviar o único ZIP pela interface GitHub, pois o conector de texto não transfere arquivos binários desta conversa para GitHub.

## Implantação de backend confirmada

No GAME: 9 contas, 108 concessões (11 anteriores + Diva Pop por conta), uma nova campanha independente ativa; novo cadastro recebe 12 concessões. Teste transacional (rollback) validou feed, confirmação única e idempotência. No CATALOG: `diva_pop`, 10 cartas públicas. A UI não mostra a novidade enquanto faltarem PNGs locais. A importação do ZIP continua a única pendência de assets.
