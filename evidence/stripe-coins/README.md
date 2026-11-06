# Recarga Stripe — evidência real da implementação

O cliente foi executado no Godot 4.7.2 oficial. As seis capturas em `web/`
são do export WASM real no Chromium, em desktop 1672×941 e iPhone UA/DPR 3
com 844×390 e 640×360. O catálogo e o saldo das imagens são **fixtures**.
O pacote de 500 moedas/R$9,90 é exclusivamente um exemplo de teste; o dono
ainda não definiu pacotes ou preços reais.

`web/results.json` registra mouse/toque, controles dentro da tela, abertura
da URL externa a partir de gesto direto e ausência de crédito pelo cliente.
As requisições externas nesse teste são bloqueadas; não houve pagamento.

- `native.log`: 16 verificações do cliente, failures=0.
- `return.log`: 6 verificações do retorno e prioridades de navegação, failures=0.
- `emote-regression.log`: 14 verificações, failures=0.
- `startup.log`: 12 verificações, failures=0. Esse smoke registrou aviso de
  duas instâncias ObjectDB no encerramento headless; não erro de script.
- `pwa.log`: 31 verificações, failures=0.
- `preflight.json`: testes SQL executados no GAME, transação revertida,
  incluindo idempotência, separação teste/produção e atomicidade do crédito.
- `production-state.json`: configuração real desativada, zero pacotes,
  zero pedidos e hash da migration aplicada.
- `deployment.jsonl`: as duas novas funções GAME ativas, versão 1 e hash dos
  bundles. Ativa aqui significa endpoint implantado; a cobrança está desativada.
- `http-smoke.json`: bloqueios HTTP reais sem sessão/configuração.

Também passaram 15 testes Node das funções (`tests/coin_store/stripe.test.mjs`),
8 verificações de navegação da recarga (`tests/skin_emotes/coin_store.gd`) e o
design check. O teste Node usa fetch simulado, não a API comercial real.

Não houve pagamento real, teste de duas sessões simultâneas, teste com conta
compradora real ou validação em aparelho físico. Não foi publicado main/Pages.
Configuração e próximos passos: `docs/backend/COIN_TOPUPS.md`.
