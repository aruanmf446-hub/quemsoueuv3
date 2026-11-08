# Versão gratuita: comércio e prévias extras ocultos

Decisão do dono em 08/11/2026: manter todo código na main, sem expor Moedas,
compras, Reações/Emotes ou variações até a comercialização.

Controle central em scripts/ui/release_features.gd: COMMERCE_ENABLED=false e
COSMETIC_EXTRAS_ENABLED=false. UI e navegação bloqueiam carteira, a aba antiga
normaliza para Skins e compras são recusadas antes de qualquer requisição, mesmo
com produto remoto disponível. Não foram excluídos assets, animações, serviços,
rotas, posses ou equipamento. Reações reais de lobby/partida permanecem.

O editor de decks continua funcionando sem o link/contador de créditos pagos.
A configuração de backend documentada deck_credits_required=false não foi
alterada; não houve acesso ao Supabase, cobrança ou implantação de backend.

## Testes executados

Godot 4.7.2: Free Release 16 verificações; carrossel/rotas 69; decks 51;
comércio 14. Todos com failures=0. check_design.py e git diff --check passaram.
Os testes de compra habilitada continuam preservados para ativação futura;
as expectativas de loja visível não são usadas para aprovar esta versão.

Web exportado em Chromium: 1672×941, 844×390 e 640×360; nos dois últimos,
iPhone UA/DPR 3. Nenhum atalho/aba/variação de compra visível, antiga abertura
de Emotes permanece em Skins, clique/toque troca personagem, botão de equipar
e editor de decks permanecem acessíveis, sem chamada de checkout ou compra.
Capturas e resultados em web/. Contas e saldos são fixtures locais identificadas,
rede externa bloqueada. Os personagens bloqueados nessas capturas refletem a
fixture, não mudança nos desbloqueios reais do jogo. Nenhuma arte nova gerada.

Não foi testado em iPhone físico/Safari, nem pagamentos reais. A infraestrutura
financeira fica preservada e desligada; consulte docs/backend/COMMERCE_ACTIVATION.md
antes de reativar os flags e o backend por autorização do dono.
