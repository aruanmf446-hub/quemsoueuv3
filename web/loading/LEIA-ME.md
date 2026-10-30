# Imagens da tela de carregamento

Coloque aqui as imagens que passam atrás do logo enquanto o jogo baixa.

- Formatos: `.webp` (recomendado), `.jpg` ou `.png`.
- Tamanho: 1280 px de largura basta; paisagem (deitada). Tente deixar cada uma abaixo de 200 KB,
  porque elas também são baixadas pelo celular.
- Ordem: alfabética pelo nome. Use `01.webp`, `02.webp`, `03.webp`…
- Troca a cada 4,5 segundos, com um leve zoom. O fundo fica escurecido para o logo aparecer.

Na web (navegador): o deploy copia tudo desta pasta e gera a lista sozinho.

No jogo (Godot, também rodando local): os cartões de abertura e de transição usam estas
imagens pelo caminho `res://web/loading/NN.webp`, definido em `data/ui/presentation.json`.
Se adicionar uma imagem nova e quiser ela no jogo, troque o `image` de um cartão lá.
Para tirar uma imagem, apague o arquivo.
