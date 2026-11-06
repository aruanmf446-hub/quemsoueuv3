# Venda de moedas

Modelo comercial: dinheiro compra pacotes de moedas; moedas compram skins,
emotes, mochilas e outros itens. Os itens não recebem preço em reais. A compra
de emote já usa `price_coins`, com o preço confirmado de 100 moedas.

A carteira tem a entrada Comprar moedas. A confirmação do emote também leva a
essa seção, inclusive com saldo insuficiente, sem realizar a compra do item.
O retorno da entrada direta volta à loja anterior. Entrar na seção de recarga
não credita nem debita moedas. A carteira continua sendo lida do GAME.

Para conectar pagamentos reais ainda faltam definições do dono:

- Quantidade de moedas e preço em reais de cada pacote.
- Serviço de pagamento/conta comercial.

Não há pacotes ou preços inventados, checkout nem recebimento de pagamentos
implantados nesta etapa. A tela informa que os pacotes estarão disponíveis em
breve. Depois das definições, o pagamento precisa ser verificado pelo servidor
antes do crédito, com deduplicação da transação. Retorno de navegador ou um
botão no cliente não podem aprovar o pagamento nem aumentar o saldo.

Validação: oito verificações de navegação/saldo no Godot 4.7.2, regressão de
14 verificações da compra de emotes e capturas reais Web em 1672×941, 844×390
(DPR3/iPhone UA) e 640×360 (DPR3/iPhone UA). Design check OK. As capturas usam
saldo de fixture; não houve pagamentos nem teste em aparelho físico.

Branch: `work/skin-variations-emotes`. Evidências em `evidence/coin-store`.
