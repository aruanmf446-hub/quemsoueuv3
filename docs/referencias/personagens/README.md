# Referência visual — Tela Personagens (Quem Sou Eu V3)

Este documento acompanha **duas capturas fornecidas pelo usuário**:

1. **REFERENCIA_APROVADA.png** — a interface desejada: barra lateral robusta de coleções, cartões grandes com nomes e retratos, filtros legíveis, prévia 3D em ambiente cinematográfico, pedestal circular e área inferior de loja.
2. **IMPLEMENTACAO_ATUAL.png** — captura atual do Godot: coleção Começo, oito personagens, retratos sem nomes, pouco acabamento nos painéis e personagem Rodrigo no visualizador à direita, sem plataforma.

**Importante:** as imagens binárias ainda precisam ser copiadas para esta pasta; o arquivo markdown não as substitui.

## Objetivo para Codex

Refinar a tela real do Godot para aproximá-la da referência aprovada; preservar os sistemas de pesquisa, favoritos, filtros, coleção Começo, estados de posse/equipado e modelos 3D.

### Diferenças principais observadas
- Menu superior atual está comprimido e com botões pequenos; na referência é espaçado e legível.
- Coleções ocupam uma caixa estreita; na referência, há uma sidebar de verdade com linhas/ícones/contadores.
- Cartões atuais mostram os modelos, mas faltam nomes e fundos próprios; referência usa retratos destacados e bordas luminosas somente no selecionado.
- Prévia 3D atual tem muito espaço escuro vazio e Rodrigo sem pedestal/sombra/iluminação contextual; referência mostra apresentação 3D em palco com ambiente e composição.
- Fundo do jogo atual compete visualmente com controles; referência usa sobreposições escuras equilibradas.
- Área sob a galeria está vazia; referência contém uma região promocional de loja. **Não criar produtos ou preços fictícios**: ocultar o banner quando não houver oferta real.
- Não inventar coleções, personagens, raridades, atributos ou descrições: apenas dados oficiais existentes.

## Instruções de implementação
- Trabalhar na cena atual e reutilizar personagens reais, sem substituir a prévia Godot por PNG.
- Garantir landscape, boa legibilidade e toque em Android/Web.
- Equipar e selecionar são operações distintas; um personagem equipado não deve mostrar Comprar.
- Capturar screenshots reais da cena executada e comparar visualmente antes de concluir.
- Não dar merge automático na main.
- Evitar respostas que incluam imagens em base64 e logs grandes (erro anterior de 4 MB).

## Situação dos screenshots
A referência aprovada e a implementação atual foram anexadas na conversa ChatGPT, mas o conector disponível para escrita GitHub não aceitou diretamente binários montados no ambiente. Adicione os dois PNG a esta pasta como `REFERENCIA_APROVADA.png` e `IMPLEMENTACAO_ATUAL.png` antes de pedir análise visual automática ao Codex.
