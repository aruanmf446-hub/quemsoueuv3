# Recargas por habilidade

Direção solicitada: um cartão ilustrado por poder, carga atual e botão de uso.
As artes são recursos originais reutilizados do tutorial e o retrato do El Fuego;
nenhuma imagem nova foi gerada. A aprovação visual final permanece com o dono.

As capturas são do Godot Web 4.7.2 em Chromium: desktop 1672×941 e iPhone
simulado 844×390 e 640×360, DPR 3. Não representam Safari ou aparelho físico.
O cenário de teste usa o painel de produção e transporte controlado de teste;
não mostra uma compra financeira real. A integração com a fase 05 real foi
exercitada separadamente no teste nativo de pausa.

Resultados: cliente 19 verificações, pausa 8, ciclo de vida PASS, regressões de
carteira 16 e emotes 14, todos sem falhas. Web passou nas três resoluções.
Os testes SQL do GAME passaram em transação revertida, incluindo débito,
repetição, estoque, recuperação e isolamento. Não houve cobrança real nem teste
HTTP com uma sessão de comprador real.

A migration 20261107230000 já foi aplicada e registrada no GAME; não reaplicar.
Preço configurado: 10 moedas por uma recarga que completa um poder até 3/3.
Vendas de recargas e pagamentos continuam desativados. Estoque comprado fica
somente em Pausa → Configurações → Recargas compradas. Um poder cheio bloqueia
o uso sem consumir estoque. Limites de recuperação estão em
../../docs/backend/ABILITY_REFILLS.md.
