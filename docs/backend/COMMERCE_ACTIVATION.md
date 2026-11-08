# Comércio real — preparado e desligado

Não existe loja simulada na produção. A carteira, o preço, o débito, a posse,
o equipamento e os créditos vêm do Supabase GAME. As fixtures em tests/commerce
são somente testes de transporte/UI e não entram na exportação de produção.

## Nome exibido da segunda unidade

O dono definiu **Carta de criação** no lugar do diamante/gema da interface.
**1 carta = 1 deck.** O contador lê o saldo real de `deck_credits`, separado
das moedas. O identificador técnico `deck_credits` permanece no contrato.
Saldos antigos de gems não são convertidos, apagados ou usados como cartas.
A exigência de consumo continua desligada até a ativação autorizada.

## Estado entregue

- GAME: pagamentos `enabled=false`, `live_mode=false`.
- GAME: `cosmetics_enabled=false`, `deck_credits_required=false`.
- Pacotes e itens estão inativos. Não foram cobrados pagamentos Stripe.
- A prévia da Samba e das variações continua funcionando. Itens já adquiridos
  permanecem da conta e podem ser usados com as vendas desligadas.
- Novos decks continuam gratuitos. Se a cobrança for ativada, o primeiro INSERT
  do deck na conta consome um crédito; editar, reenviar e corrigir o mesmo ID
  não consome outro. Rascunhos locais não consomem créditos. A cobrança é feita
  pelo servidor, inclusive contra INSERT REST direto. Falha do INSERT reverte
  o consumo. Uma falha posterior de upload permite retomar o mesmo deck/ID.
- Excluir um deck não devolve o crédito. IDs excluídos que já consumiram crédito
  não podem ser reutilizados para burlar a cobrança.

Valores dados como exemplos pelo dono, gravados como cotações INATIVAS:

| Pacote | Valor provisório |
|---|---:|
| 100 moedas | R$ 10 |
| 250 moedas | R$ 20 |
| 400 moedas | R$ 30 |
| 1 crédito de deck | R$ 10 |
| Variação | 100 moedas |
| Samba | 50 moedas |

Nova skin: referência de 200 moedas, sem produto vendável criado. Os sete
personagens gratuitos e El Fuego (campanha) permanecem protegidos contra venda.
Uma futura skin nova precisa de modelo e inclusão no catálogo/contrato de
progressão, hoje fechado nos oito personagens; não basta colocar um ID na loja.
Os preços são por produto, não uma regra fixa para todo item da categoria.

## Backend instalado — não reaplicar

Migrações registradas no GAME:

- `20261107220000_commerce_catalog_credits`
- `20261107221500_commerce_availability`
- `20261107223000_commerce_package_identity`
- `20261107230000_ability_refills`

RPCs de conta: `qse_cosmetic_shop()`,
`qse_cosmetic_purchase(p_product,p_request,p_expected_price)` e
`qse_variation_equip(p_character,p_style)`.
O emote universal continua com `qse_emote_shop`/`qse_emote_purchase`.
As tabelas de produtos, posses, equipamento e créditos são privadas com RLS,
sem escrita direta de jogadores. Compras bloqueiam a carteira e usam o ledger
existente na mesma transação da concessão. Repetir compra não cobra duas vezes.
Preços e identidade não são aceitos do cliente como autoridade.

`coin_packages.reward_kind` e `coin_orders.reward_kind` distinguem moedas de
créditos. O campo legado `coins` contém a quantidade da unidade do pedido.
O webhook usa o tipo do pedido salvo no GAME, nunca o corpo enviado pelo jogador.
Um pedido de créditos pago em produção cria um recibo único e aumenta somente
o saldo de créditos. Sandbox vira `test_paid`, sem crédito real de moedas OU
créditos. Reentregas são idempotentes. Refund/dispute bloqueia consumo até revisão.
Os tipos de pacotes com pedidos existentes são imutáveis.

As duas Edge Functions foram atualizadas para versão 3, mantendo validação de
JWT no handler, assinatura no webhook, consulta canônica Stripe e URL fixa.
CATALOG e CHAT não foram modificados por esta entrega.

## Próxima ativação

A infraestrutura já existe; não recriar serviços nem migrações.

1. Confirmar os preços finais. Os valores acima ainda são exemplos.
2. GAME → Edge Functions → Secrets: completar `STRIPE_SECRET_KEY` e
   `STRIPE_WEBHOOK_SECRET`, ambos do MESMO ambiente Stripe. A inspeção encontrou
   somente o segundo nome; nenhum segredo foi lido ou copiado.
3. Fazer checkout Sandbox real, retorno, webhook e reentrega, mantendo
   `live_mode=false`. O teste não deve financiar a carteira de produção.
4. Para o teste autorizado, ativar os pacotes selecionados e
   `coin_store_settings.enabled=true`, com `live_mode=false`.
   Para vender itens por moedas, ativar os produtos escolhidos e
   `commerce_settings.cosmetics_enabled=true`. Não ativar skins existentes.
5. O uso obrigatório de créditos é independente:
   `commerce_settings.deck_credits_required=true`. Avisar os jogadores antes
   de trocar a criação gratuita pela cobrança. Decks existentes não são cobrados.
6. Só depois dos testes e da autorização do dono, usar segredos de produção,
   definir `live_mode=true` e verificar pagamento controlado/crédito único.
   Não inferir pagamento pelo retorno da página. As chaves não vão para o jogo.

As chaves sozinhas NÃO habilitam vendas. As flags/preços vêm do servidor; os
itens já preparados não precisam de outra publicação do cliente para mudar de
indisponível para comprável. Novos modelos/animações exigem publicar os assets.

Status seguro: `python3 tools/payments/commerce.py`.
Desligamento completo: `python3 tools/payments/commerce.py --disable`.
Esse comando preserva saldos, posses, equipamento e decks; volta à criação grátis.

## Validação e limites

Testes SQL executaram as funções reais e os débitos/concessões em transações
revertidas, com usuários temporários: ACL, bloqueios, saldo insuficiente,
preço, compra repetida, posse/equipamento, isolamento, crédito em Sandbox sem
concessão real, crédito de produção com notificação canônica simulada, webhook
repetido e consumo único do deck. Não foram pagamentos Stripe reais.

Node testa handlers/assinaturas com transporte simulado. Godot e Web testam o
cliente e as telas nas resoluções 1672×941, 844×390 e 640×360. As duas últimas
usam UA de iPhone/DPR 3 em Chromium, não aparelho físico/Safari.

Limite externo atual: `STRIPE_SECRET_KEY` ausente. Checkout/assinatura com
sessão Stripe real, cartão, concorrência simultânea de clientes e pagamento
real ainda precisam ser testados após configurar a chave correta.
Evidências: `evidence/commerce-live/`.

## Recargas de habilidades

[ABILITY_REFILLS.md](ABILITY_REFILLS.md) descreve o consumível real de **10 moedas**
por recarga completa de uma habilidade até 3/3, guardado na conta e usado apenas
em Pausa → Configurações. A venda continua inativa. Sua configuração específica
é `ability_refill_settings.active`; a compra também respeita o bloqueio global
da loja. Não confundir uma recarga guardada com três itens/recargas parciais.

## Versão gratuita — decisão de 08/11/2026

A implementação permanece na main, porém inativa no cliente. O ponto de controle
é `scripts/ui/release_features.gd`:

- `COMMERCE_ENABLED = false`: oculta Moedas/carteira e links para comprar cartas
  de criação; bloqueia checkout e compras de cosméticos, emotes e recargas antes
  de qualquer requisição de compra, mesmo se o catálogo remoto vier habilitado.
- `COSMETIC_EXTRAS_ENABLED = false`: oculta o atalho Emotes, abas Reações/Emotes e
  os seletores de variação. Uma abertura antiga de Emotes leva às Skins normais.

Equipar skins originais, prévias dos personagens, favoritos e as reações reais
já usadas no lobby/partidas continuam preservados. Não se apagam assets,
animações, itens possuídos, saldos ou equipamento da conta. Não há concessão
fictícia de itens pagos. O editor de decks permanece disponível sem link de
compra de créditos; `deck_credits_required` no GAME deve continuar **false**.
A política local não altera nem substitui essa regra autoritativa do servidor.

Para ativação futura autorizada, revise os dois flags e siga os passos de backend
acima, com preços e testes reais; não basta revelar botões ou somente ligar Stripe.
Nenhuma migration ou Edge Function deve ser reaplicada para ocultar a interface.

Validação da versão gratuita: `tests/free_release/client.gd`,
`tests/free_release/web.cjs`, `tests/hero_carousel/flow_test.gd`,
`tests/decks_t21/flow_test.gd` e `tests/commerce/client.gd`.
Os roteiros históricos de prévia/compra habilitada em `tests/commerce_entrypoints`
e `tests/skin_emotes` continuam preservados para o futuro build de ativação;
suas expectativas visuais de loja aberta não representam esta versão gratuita.
