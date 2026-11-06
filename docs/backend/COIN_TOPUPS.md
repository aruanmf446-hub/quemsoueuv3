# Venda de moedas

Modelo comercial: dinheiro compra pacotes de moedas; moedas compram skins,
emotes, mochilas e outros itens. Os itens não recebem preço em reais. A compra
de emote já usa `price_coins`, com o preço confirmado de 100 moedas.

A carteira tem a entrada Comprar moedas. A confirmação do emote também leva a
essa seção, inclusive com saldo insuficiente, sem realizar a compra do item.
O retorno da entrada direta volta à loja anterior. Entrar na seção de recarga
não credita nem debita moedas. A carteira continua sendo lida do GAME.

## Stripe escolhida

O dono escolheu Stripe. A implementação usa Checkout hospedado, em reais,
somente para pacotes de moedas. A confirmação dos itens continua em moedas.
Ainda faltam **quantidade e preço dos pacotes**, além da configuração comercial
da conta Stripe. Nenhum valor foi inventado no catálogo real.

### Situação da implantação

- GAME: migration `20261107100000_stripe_coins.sql` aplicada e registrada uma
  única vez. Não reaplicar. Catálogo vazio; `enabled=false`, `live_mode=false`.
- GAME: `qse-coin-checkout` e `qse-stripe-webhook` implantadas, versão 1,
  `verify_jwt=false`. A primeira valida o JWT diretamente em `/auth/v1/user`;
  a segunda exige assinatura Stripe do corpo bruto e consulta a API da Stripe.
- Nenhum segredo Stripe foi criado por esta entrega. Nenhuma cobrança foi feita.
- Cliente: branch `work/skin-variations-emotes`; **sem publicação de main/Pages**.
- CATALOG e CHAT não participam dos pagamentos e não foram alterados.

### Fluxo

`qse_coin_store()` retorna pacotes ativos, configuração e até dez pedidos da
própria conta. Todos os preços, quantidades e moedas vêm do GAME.
Selecionar um pacote prepara o pedido e abre um painel com o total. O botão
Continuar na Stripe abre o checkout por gesto direto, evitando bloqueio de
pop-up após HTTP no Safari/PWA. Nenhum cartão é digitado no jogo.

O serviço guarda somente UUIDs de tentativa em `user://coin_checkout.cfg`,
separados por conta, pacote, valor, quantidade e modo. Uma falha/repetição usa a
mesma intenção. Um pedido finalizado permite comprar novamente o mesmo pacote.
O servidor limita a criação a cinco pedidos por conta por hora e preserva a
cotação por uma hora. Depois de 30 minutos uma tentativa não inicia/reabre um
checkout; o jogador recebe orientação para escolher novamente.

A Stripe recebe uma chave de idempotência derivada do UUID do pedido. O
webhook confere HMAC SHA-256, tolerância de 300 segundos, evento, sessão
canônica paga, modo, moeda, valor e vinculação ao pedido. O GAME bloqueia o
pedido, usa o UUID como nonce do ledger existente e credita as moedas na mesma
transação. Reentregas não creditam de novo. Falha de gravação reverte o crédito.

O retorno `?coin_order=UUID` abre a carteira após login e nickname, respeitando
recovery/convites; não comprova pagamento. Um UUID em sessionStorage preserva
essa navegação durante OAuth, sem guardar dados do pagamento. A carteira
consulta o servidor ao abrir, ao recuperar foco e ao tocar Atualizar pagamentos
e saldo. O histórico exibe Compra de moedas e o status dos próprios pedidos.
Se o webhook ainda não chegou, o status continua aguardando confirmação.

**Modo teste:** pedidos podem chegar a `test_paid`, mas nunca creditam moedas
na carteira de produção. Chave, configuração e sessão precisam concordar sobre
teste/produção. Testes com cartão fictício não devem financiar uma conta real.

**Reembolsos/contestações:** o webhook consulta Charge/PaymentIntent/Dispute
canônicos. Pedidos relacionados entram em `payment_review`; despesas de moedas
e novas recargas dessa conta ficam bloqueadas até revisão manual. O mecanismo
não inventa saldo negativo nem desfaz automaticamente itens já adquiridos.
Disputa ganha não remove automaticamente uma pendência já aberta. A resolução
financeira pelo responsável é necessária, com registro externo do atendimento.

### Contrato do servidor

- Público autenticado: `qse_coin_store()`.
- Somente service_role: `qse_coin_order_prepare`, `qse_coin_order_bind`,
  `qse_coin_order_complete`, `qse_coin_order_review`.
- Tabelas privadas/RLS: `coin_store_settings`, `coin_packages`, `coin_orders`.
- Preços BRL em centavos inteiros; quantidade de moedas como string JSON.
- URL de pagamento só em `https://checkout.stripe.com/c/…`; retorno fixo ao Pages.
- Chaves secretas e webhook secret ficam exclusivamente no GAME Edge Secrets.
- O deployment reproduzível está em `tools/payments/deploy_stripe.py`; ele não
  altera segredos nem habilita pagamentos. `--bundle-dir` só gera bundles locais;
  `--update` exige inspeção prévia das funções existentes.

### Configuração manual pelo dono — ainda pendente

1. Informar os pacotes: quantidade de moedas e preço em reais. O catálogo só
   será preenchido com os valores aprovados pelo dono.
2. Criar/ativar a conta Stripe e completar os dados comerciais pedidos por ela.
3. Começar em **Sandbox/teste**. No **Supabase GAME**
   (`shuzporktifgiotvnpbz`) → Edge Functions → Secrets, cadastrar
   `STRIPE_SECRET_KEY` com a chave secreta de teste. Não usar chave publicável,
   não colocar no GitHub/cliente e não colar chaves neste chat.
4. Na Stripe, criar destino de webhook para
   `https://shuzporktifgiotvnpbz.supabase.co/functions/v1/qse-stripe-webhook`,
   com estes eventos: `checkout.session.completed`,
   `checkout.session.async_payment_succeeded`, `charge.refunded`,
   `charge.dispute.created`, `charge.dispute.funds_withdrawn`,
   `charge.dispute.closed`. Copiar o signing secret desse destino para
   `STRIPE_WEBHOOK_SECRET` no **mesmo GAME Edge Secrets**. São duas chaves
   diferentes; não substituir por anon public ou Management API token.
5. Com os pacotes aprovados, habilitar `coin_store_settings.enabled=true`,
   mantendo `live_mode=false`, e publicar o cliente quando autorizado. Testar
   checkout, retorno, reentrega e ausência de crédito real usando Sandbox.
6. Só após os testes reais, configurar a chave/endpoint **de produção**, atualizar
   os dois segredos para os correspondentes de produção e definir
   `live_mode=true`. Desabilitar o endpoint de teste anterior para evitar
   retentativas com a assinatura errada. Fazer um pagamento real controlado e
   confirmar um único crédito, histórico, suporte e tratamento de reembolso.

O backend está preparado, mas **não está liberado para receber dinheiro**.
Esta etapa não configurou a conta do comerciante nem validou pagamento real.

### Validação executada

- 15 testes Node offline das funções Stripe (fetch simulado): assinatura,
  cotação, identidade, retry, URL, modo, indisponibilidade, refund/dispute.
- SQL no GAME com dados sintéticos e `ROLLBACK`: cotação, ACL/RLS, duplicidade,
  crédito repetido, modo teste sem crédito, compra consumível repetida,
  reembolso, isolamento entre contas, exclusão de conta e falha atômica.
- Godot 4.7.2: 16 verificações do cliente Stripe; regressões de navegação da
  recarga (8), compra de emotes (14), abertura/login (12) e retorno do checkout
  com prioridades de login/nickname/recovery/convite (6).
- Export Web 4.7.2 e Chromium: pacotes, mouse/toque, painel, abertura de URL
  externa e saldo intacto em 1672×941, 844×390 e 640×360. iPhone UA/DPR 3 nas
  duas últimas. Preços das capturas são **fixtures de teste**, não oferta real.
- PWA: 31 verificações, failures=0, usando o Chromium instalado.
- HTTP no GAME: duas funções respondem `payments_unavailable` (503) sem
  configuração Stripe; catálogo e RPC de crédito recusam anon com 401/42501.
- Design check OK. Evidências em `evidence/stripe-coins`.

Não houve teste de pagamento pela API real da Stripe, sessão de comprador real,
concorrência simultânea de dois clientes ou teste em Safari/iPhone físico.
