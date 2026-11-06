# Compra de emotes — GAME

Preço confirmado pelo dono: **100 coins (moedas comuns)**. Não utiliza gemas,
R2, outro provedor, serviço de pagamento ou acesso ao projeto CHAT/CATALOG.

## Contrato

`qse_emote_shop()` retorna `coins` como string e `items` com `id`, `name`,
`price_coins`, `animation_key`, `available` e `owned` da própria conta.

`qse_emote_purchase(p_emote text, p_request uuid, p_expected_price bigint)`
valida sessão e preço, bloqueia a carteira, usa o lançamento privado existente
`qse_v3.post_wallet_entry` e concede a posse na mesma transação. O retorno
confirmado tem `owned`, `already_owned`, `emote_id`, `coins_after` e
`transaction_id`. Não recebe identidade, saldo, moeda ou valor de débito do cliente.

Tabelas privadas `qse_v3.emote_products` e `qse_v3.player_emotes`, com RLS e
sem leitura, escrita ou TRUNCATE por jogadores. O cliente só usa as RPCs.
Preço adulterado, saldo insuficiente, emote indisponível e reaproveitamento de
uma chave para outro produto são recusados. Carteira bloqueada e chave de posse
única impedem cobranças repetidas. A falha na concessão reverte o débito.

## Implantação

Migration `20261106215000_emote_shop.sql` **já aplicada uma vez no GAME** e
registrada no histórico com o hash do arquivo. **Não reaplicar manualmente.**

Produto `dance_01`: 100 moedas, `animation_key=emote_dance_01`, `active=false`,
`asset_ready=false`. A verificação de produção encontrou zero posses. A implantação
não debitou carteiras nem concedeu o exemplo a contas reais. CHAT e CATALOG não
foram alterados. O cliente continua na branch de prévia; não houve deploy Pages.

Antes de liberar a venda: receber o movimento real, importar/retargetear para os
modelos suportados, vincular o alias e as miniaturas, validar movimento e uso,
publicar o cliente correspondente e só então aprovar/ativar o item no GAME.
Variações de skins e acionamento manual em lobby/sala/partida seguem como escopos
posteriores; o que existe agora é a prévia na coleção e a compra/persistência.

## Validação executada

- PostgreSQL real, dados sintéticos com BEGIN/ROLLBACK: compra, preço de 100,
  saldo insuficiente, gemas intactas, isolamento, idempotência, ACL/RLS,
  exclusão de conta e reversão atômica quando a entrega falha.
- HTTP real sem sessão: ambas as RPCs recusam com 401 / `42501`.
- Godot 4.7.2: 19 verificações dos contextos/loja, 32 de movimento nos oito
  modelos, 14 de compra/repetição/resposta perdida/sessão e 26 de regressão
  dos decks comunitários, sem falhas. Design check: OK.
- Godot Web/Chromium em 1672×941, iPhone UA/DPR3 em 844×390 e 640×360:
  três exemplos, dança, confirmação por 100 moedas, saldo 250→150, item
  adquirido e fechamento da confirmação, sem erros de script.

O teste Web usa um catálogo e uma carteira de fixture, com movimento marcado
como disponível exclusivamente para testar o fluxo. Não é uma compra em conta
real. A transação real foi exercitada no PostgreSQL e revertida. Não houve teste
HTTP positivo com conta real, concorrência simultânea em dois clientes nem teste
em iPhone físico. O bloqueio por linha e as restrições estão no código do servidor.

[Evidências](../../evidence/skin-emotes/examples-shop/README.md).
