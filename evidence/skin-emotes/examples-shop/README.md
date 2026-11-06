# Exemplos e loja de emotes

Capturas reais do Godot Web 4.7.2, com modelos originais e dados de teste isolados.
Para cada resolução, `lobby`, `victory` e `defeat` mostram os exemplos de reação;
`shop` mostra a loja separada; `purchase` a confirmação de 100 moedas;
`purchased` o item adquirido e saldo atualizado na fixture.

`dance-preview.webm` é a gravação original do canvas desktop. `dance-preview.gif`
é um trecho enquadrado no personagem, convertido para GIF para ver o movimento
no chat. A dancinha é uma demonstração original, aguardando o arquivo real.

- [Dancinha em movimento](dance-preview.gif)
- [Lobby](844x390_lobby.png), [Vitória](844x390_victory.png), [Derrota](844x390_defeat.png)
- [Loja](844x390_shop.png), [Confirmação](844x390_purchase.png), [Adquirido](844x390_purchased.png)
- `results.json`: Web aprovado nos três tamanhos.
- `examples.log`, `dance.log`, `purchase-client.log`, `community-regression.log`: testes no motor.
- `purchase-sql.json`: testes reais no PostgreSQL, integralmente revertidos.
- `production.json`: migration/hash, preço, item inativo e recusa HTTP sem sessão.

A fixture marca o produto como disponível para testar a compra. O item de produção
continua fora de venda e zero contas receberam o exemplo. Não houve teste de
compra HTTP em conta real nem validação em aparelho físico.
