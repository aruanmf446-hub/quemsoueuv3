# Decks do Duelo (cartas em PNG)

Cada **pasta** aqui é um deck. Cada **arquivo .png** dentro dela é uma carta.

```
assets/duel/decks/
  lendas/
    deck.json            (opcional: nome e ordem)
    dragao_vermelho.png
    fada_da_lua.png
    ...
```

- Nome da pasta e dos arquivos: só letras minúsculas, números e `_` (sem espaços e sem
  acentos). O nome do arquivo é o identificador da carta: `lendas/dragao_vermelho`.
- `deck.json` (opcional): `{"name": "Lendas", "order": 1, "cards": {"dragao_vermelho": "Dragão Vermelho"}}`.
  `name` aparece na escolha de decks da sala; `order` define a posição (menor primeiro);
  `cards` dá o nome bonito de cada carta (sem ele, o jogo usa o nome do arquivo).
- Imagem: retrato (em pé), por exemplo 600 × 840 px. Até ~300 KB por carta.
- Cada deck precisa de pelo menos 2 cartas e pode ter até 300.

Depois de adicionar, trocar ou remover decks/cartas, rode:

```
python tools/duel/sync_decks.py
```

Ele gera `supabase/seed/duel_decks.sql`, que precisa ser aplicado no Supabase para o servidor
conhecer as cartas (o servidor só guarda os identificadores; as imagens ficam no jogo).
