# Decks oficiais do Duelo

Os decks oficiais ficam dentro de `assets/duel/decks/oficial/<id>/`. Os decks dos jogadores ficam no Supabase GAME, não neste diretório.

## Enviar cartas PNG

1. Abra a pasta correta: `oficial/lendas_urbanas`, `oficial/nostalgia_web`, `oficial/sol_nascente` ou `oficial/pinturas`.
2. Suba as imagens `.png` com nomes em minúsculas, sem espaços nem acentos, como `meu_personagem.png`.
3. Edite o `deck.json` no mesmo diretório e acrescente cada imagem ao objeto `cards`: `"meu_personagem": "Meu Personagem"`. Sem essa entrada, a imagem não aparece na Biblioteca.
4. É necessário ter de 5 a 30 cartas completas para o deck aparecer na Biblioteca. Decks vazios ou incompletos ficam ocultos, sem imagens inventadas.
5. Rode `python tools/duel/sync_decks.py` para gerar o SQL do servidor de Duelo. **O script não apaga decks ausentes**. A inclusão remota no CATALOG é uma etapa separada após todas as cartas estarem prontas.

A referência lógica é `official:<id>` e a carta é `<id>/<nome_da_imagem>`. Essas referências **não** contêm a pasta física `oficial` e não devem ser renomeadas.

O Cloudflare R2 foi descartado. Os decks pessoais utilizam GAME e seu Storage privado.
