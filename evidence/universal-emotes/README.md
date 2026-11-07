# Emote universal da conta

Uma compra pertence ao UUID da conta GAME, sem personagem/skin/variante na
chave. O painel passa a oferecer Usar emote e usa a mesma posse ao trocar de
avatar. O adaptador recebe o movimento preparado para o rig selecionado.

Validação:

- `audit.json`: consulta read-only real no GAME, confirmando PK usuário/emote,
  RPC autenticada, sem INSERT direto e `dance_01` ainda inativo/sem asset pronto.
  O acesso GAME configurado foi suficiente, sem novas chaves.
- `backend.json`: SQL executado no GAME com produto e usuários sintéticos,
  todos revertidos por ROLLBACK. Uma compra/um débito, recuperação da conta,
  isolamento e posse preservada após desativação.
- `native.log`: Godot 4.7.2, 45 verificações, failures=0. Inclui os oito rigs,
  uso sem recompra/consulta HTTP, recuperação em nova instância, isolamento,
  alvo cancelado, ossos incompatíveis e remoção de trilhas de método.
- `purchase.log`: 14 verificações de regressão, failures=0.
- `web/results.json`: nove combinações de Cowboy, El Fuego e Halloween em
  1672×941, 844×390 e 640×360 no export WASM real/Chromium. Toque com iPhone
  UA/DPR 3 nas menores. Uma compra de fixture, saldo 250→150 e mesmo item
  usado em três avatares, sem outra cobrança ou erros de script.
- Design check: OK.

As imagens são capturas reais do motor. O título identifica teste. Os movimentos
originais usados como fixture validam binding/posse; **não são uma dancinha nova
aprovada para venda**. Não houve cobrança real, emote concedido a conta real ou
alteração persistente do GAME. Não houve sessão HTTP de comprador real, teste
simultâneo em dois aparelhos ou Safari/iPhone físico.

`data/emotes.json` deixa os clipes reais vazios até o dono anexar o movimento.
A demonstração não foi ativada para venda. Nenhuma migration/Edge Function foi
alterada nesta entrega. Main/Pages não foram publicados.
