# Recarga completa — 10 moedas, inicialmente inativa

Uma compra concede **uma recarga guardada na conta**, não três itens nem uma
habilidade nova. O jogador escolhe onde usá-la em
**Pausa → Configurações → Recargas compradas**. A habilidade escolhida passa
de 0/3, 1/3 ou 2/3 para 3/3. As outras habilidades não mudam.

Habilidade cheia: o botão indica `Está cheia`, fica bloqueado e a validação
local recusa o uso antes de qualquer RPC. A mensagem identifica a habilidade:
`Sua habilidade Defesa está cheia (3/3). Nenhuma recarga foi gasta.`
Também bloqueia uso morto, fora da pausa/conta/fase original, ou antes da
liberação e descoberta do poder. Não recarrega vida nem desbloqueia poderes.

A apresentação usa um cartão ilustrado por poder, com arte já existente no
jogo, carga numérica, barra de três níveis e botão de uso. Cartões cheios
permanecem ilustrados e exibem 3/3 em verde, com uso bloqueado.

O estoque comprado não foi adicionado ao HUD, aos controles de combate nem ao
centro da tela enquanto se joga. A pausa abre a tela de inventário; continuar
fecha essa tela. Os indicadores normais de ataque/defesa/poderes mostram as
cargas normais de gameplay, como antes. Pickups de fase e regras de morte/
checkpoint foram preservados. A carga aplicada entra no snapshot normal entre fases.

## Backend GAME real — instalado, não reaplicar

Migration `20261107230000_ability_refills` registrada no GAME.
`ability_refill_settings.price_coins=10`, `active=false`; o bloqueio global
`commerce_settings.cosmetics_enabled=false` também permanece desligado.
CATALOG/CHAT e Stripe não foram alterados nesta etapa.

- `qse_ability_refills()`: preço/disponibilidade, estoque e entregas pendentes da conta.
- `qse_ability_refill_buy(p_request,p_expected_price)`: carteira + débito + estoque
  na mesma transação. Um UUID de tentativa não cobra nem concede duas vezes.
- `qse_ability_refill_reserve(p_request,p_ability)`: reserva uma unidade já comprada,
  vinculada à habilidade. Serializa pela carteira e deixa um recibo recuperável.
- `qse_ability_refill_ack(p_receipt)`: confirma o recibo da própria conta; é idempotente.

Tabelas privadas com RLS e sem escrita/TRUNCATE de jogadores. A identidade vem
exclusivamente do JWT GAME; não existe parâmetro de jogador nas RPCs.
Habilidades aceitas: ataque, defesa, congelamento, corrida elétrica e ruptura.
Uma entrega pendente continua disponível para a mesma habilidade em caso de
resposta perdida, saída ou troca de conta. Não deduz outra unidade na retomada.

O cliente guarda UUIDs de tentativa e marcadores de entrega por conta, sem JWTs.
Um recibo já aplicado não aplica outra carga se sua confirmação falhar.
O inventário exibido exclui recibos localmente aplicados ainda não confirmados.
HTTPRequest processa durante a pausa, sem retomar a física do jogo.

## Limite de autoridade

Carteira, compra, estoque e recibos são do servidor. O estado da corrida e o
3/3 continuam locais, como a campanha existente. A proteção de habilidade cheia
é aplicada ao jogador real antes da reserva e novamente antes da aplicação.
Não alegar que essa validação local é anticheat de servidor nem que arquivo local
é impossível de apagar/adulterar. Também não há transação única entre banco,
memória do motor e disco do aparelho; o marcador local reduz reaplicações em
falhas de confirmação, mas não prova entrega atômica diante de qualquer crash.
Uma campanha totalmente autoritativa exigiria trabalho separado, fora deste pedido.

## Ativação futura

Não ativada agora. Depois da autorização do dono e validações comerciais,
ativar `ability_refill_settings.active` junto ao bloqueio global da loja de
itens. O preço de 10 moedas já está no GAME; não usar Stripe diretamente para
comprar a recarga. Moedas compradas/ganhas ficam na carteira existente.
`tools/payments/commerce.py --disable` também desativa a venda das recargas,
sem remover o estoque comprado. Usar estoque existente não depende de vendas ativas.

## Verificação executada

- SQL real em transações revertidas: preço, saldo, duplicidade, estoque, reserva,
  retomada, isolamento de contas e confirmação. Sem concessões persistentes.
- 19 verificações nativas do jogador/serviço: cheia sem RPC/gasto, 0/3, 1/3 e 2/3 para
  3/3, poderes bloqueados, sem estoque, perda de resposta, confirmação pendente,
  troca de conta, compra repetida e execução pausada.
- 8 verificações na fase 5 real: pausa/configuração, aplicar, bloquear cheia,
  continuidade do snapshot, ausência no HUD e retorno ao jogo.
- Web Godot 4.7.2 em Chromium: compra por 10 moedas, estoque e uso no mesmo
  cliente de teste; mouse/toque, cheia, parcial, retorno e ocultação do estoque.
  1672×941; UA iPhone/DPR 3 em 844×390 e 640×360. O fundo de teste é identificado;
  o overlay e as regras do jogador são os mesmos do jogo. Não é iPhone físico.
- Regressões: carteira 16 e emotes 14 verificações; design checker/diff-check.

A compra Web usa transporte de teste. Não foi feita compra financeira real com
sessão HTTP de usuário no GAME nem teste de falha por encerramento forçado do
navegador entre cada instrução. Evidências em `evidence/ability-refills/`.
