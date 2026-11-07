# Confirmações de compra — revisão visual

Componente PlayerUI.shop_confirmation aplicado a checkout de moedas/créditos,
emotes e variações. Arte/miniatura, preço e ações são controles nativos. Os
serviços, as cotações, os bloqueios e as regras de compra não foram alterados.
Não houve mudança do GAME, ativação de pagamento ou publicação no Pages.

Capturas: Godot 4.7.2 Web em Chromium, com transporte de teste sem rede externa.
Valores como 500 moedas/R$ 9,90 e Dancinha/100 moedas pertencem às fixtures
históricas de QA e não alteram os exemplos nem os produtos da loja real.
O teste de emote usa clipes base existentes para verificar a vinculação; não
substitui nem altera os recursos da Samba aprovada.

Desktop 1672×941, UA iPhone/DPR 3 em 844×390 e 640×360. Não são capturas de
aparelho físico/Safari. Checkout: clique/toque, painel, URL segura por gesto
explícito, voltar e saldo preservado nas três resoluções. Emotes: confirmação,
compra uma única vez e uso em Cowboy/El Fuego/Halloween sem recompra nas três
resoluções. Scripts: tests/coin_store/web.cjs e
 tests/skin_emotes/universal_web.cjs (a captura foi adicionada ao teste existente).
Regressões nativas: carteira 16 e compra de emote 14, zero falhas.
Verificação de design e diff-check sem falhas.
