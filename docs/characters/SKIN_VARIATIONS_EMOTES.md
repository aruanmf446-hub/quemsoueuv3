# Skins, reações e emotes — prévia

Branch `work/skin-variations-emotes`.

As abas separam Skins, Reações e Emotes. Os exemplos gratuitos de reação são
Lobby (`anim_2`), Vitória (`anim_4`) e Derrota (`anim_3`). Os cartões reproduzem
cada contexto no personagem maior, sem alterar partidas ou resultados reais.

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
