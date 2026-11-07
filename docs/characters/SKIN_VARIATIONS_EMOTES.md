# Skins, reações e emotes — prévia

Branch `work/skin-variations-emotes`.

As abas separam Skins, Reações e Emotes. As variações ficam em pequenos
seletores quadrados junto à prévia do personagem selecionado, sem aba própria.
Os exemplos gratuitos de reação são
Lobby (`anim_2`), Vitória (`anim_4`) e Derrota (`anim_3`). Os cartões reproduzem
cada contexto no personagem maior, sem alterar partidas ou resultados reais.

## Variações visuais — implementação

Selecionar um personagem mostra três quadradinhos com miniaturas: Original e
duas paletas editáveis para cada um dos oito personagens: Cowboy, Michelly, Rodrigo, Lorena, Gus, Lana, Halloween
e El Fuego. São 16 variações de cores, além dos oito originais. Não são novos
modelos ou novas roupas: preservam geometria, rig, animações, texturas e detalhes
dos personagens existentes. O shader remapeia uma faixa de cor definida por
personagem, em vez de tingir o corpo inteiro.

Os quadradinhos têm miniaturas capturadas dos modelos reais; tocar mostra a
variação no personagem maior, mantendo a galeria de personagens visível.
Selecionar outro personagem atualiza os ícones; as setas preservam a navegação
da galeria filtrada/paginada existente. Personagens bloqueados permitem prévia.
O desbloqueio de El Fuego continua dependendo do
Modo História. A escolha de prévia é lembrada por personagem durante o painel.

Esta entrega segue a etapa de **prévia** solicitada: não inventa posse, preço ou
compra de variações, nem aplica uma escolha local a partidas online. Emotes e
reações continuam em abas separadas. O produto de dança continua indisponível
até chegar o movimento real aprovado. Equipar o personagem original permanece
no fluxo existente de Skins.

Recursos: `scripts/skins/skin_variations.gd` e `variation_palette.gdshader`.
Os materiais são exclusivos da instância de prévia e reutilizados ao alternar
paletas. Original restaura os materiais anteriores; nenhum FBX, OBJ ou textura
original foi alterado. As miniaturas usam um único palco temporário e cache de
imagens estáticas. Nenhuma imagem foi gerada por IA nesta entrega.

A prévia estática renderiza sob demanda ao selecionar paleta, girar ou aproximar
a câmera. Ao abrir Reações/Emotes, o palco volta a renderizar continuamente para
reproduzir o movimento. O flag é exclusivo do palco de prévia; não reativa
viewports intencionalmente pausados de outros lugares do jogo.

A loja é separada. Tem prévia do movimento, preço de **100 moedas** e confirmação
de compra. O saldo, o débito e a posse vêm do GAME; o cliente não escreve saldos.
Uma resposta perdida reutiliza o identificador da compra. Posse já confirmada
impede uma segunda cobrança, inclusive com outro identificador de requisição.
O histórico da carteira identifica o lançamento como compra de emote.

A dancinha atual é uma animação original demonstrativa feita em GDScript sobre
os ossos dos modelos existentes. Não foi extraída do YouTube. As imagens e o
vídeo foram capturados no Godot, sem geração de imagens por IA. As miniaturas
usam um palco temporário e ficam em cache como texturas estáticas.

O movimento real será anexado pelo dono. O produto `dance_01` foi registrado no
GAME por 100 moedas, mas **continua inativo e sem asset aprovado**. A demonstração
não está à venda. A compra só é habilitada com disponibilidade no servidor e
movimento correspondente carregado no cliente. Os exemplos de lobby/vitória/
derrota não são vendidos como dancinhas. A interface permanece apenas na branch.

[Contrato, implantação e testes da compra](../backend/EMOTE_SHOP.md).
[Capturas e gravação atuais](../../evidence/skin-emotes/examples-shop/README.md).
