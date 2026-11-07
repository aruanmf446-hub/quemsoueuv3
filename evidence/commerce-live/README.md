# Comércio real, desligado ao entregar

Os RPCs e tabelas reais do GAME estão instalados. Preços provisórios inativos,
vendas bloqueadas, posse e saldo reais preservados. Não existe modo de loja
simulada na produção. Guia e limites em docs/backend/COMMERCE_ACTIVATION.md.

backend-final.json registra testes das funções reais em uma transação com
ROLLBACK. Nenhum dinheiro foi movimentado na Stripe; usuários temporários e
lançamentos do teste foram revertidos. O webhook foi exercitado no banco com
argumentos canônicos sintéticos; os handlers Node usam transporte simulado.

As capturas são do motor Godot 4.7.2 exportado para Web, com fixtures de
transporte identificadas somente em tests/commerce. Não são sessões de compra
reais nem capturas de iPhone físico. Chromium: desktop 1672×941; UA iPhone/DPR 3
em 844×390 e 640×360. Testam disponibilidade, prévia, moedas e créditos separados.
O teste PWA terminou com 31 verificações sem falhas. A exportação de produção
exclui tests e evidence.

Estado externo: STRIPE_WEBHOOK_SECRET configurado pelo nome;
STRIPE_SECRET_KEY ausente. Não foram lidos valores de segredos. Checkout
Sandbox real, compra com cartão, assinatura com evento Stripe real e crédito
por esse evento permanecem pendentes dessa configuração e de teste posterior.

As compras existentes permanecem utilizáveis com vendas desligadas. Novas
skins vendáveis dependem de novos assets e atualização do contrato fechado de
progressão; os personagens gratuitos e El Fuego não foram colocados à venda.
