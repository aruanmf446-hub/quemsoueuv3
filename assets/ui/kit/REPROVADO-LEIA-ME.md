# REPROVADO — não usar como referência nem nas telas do jogador

As imagens desta pasta (molduras e placas azul/douradas com brilho, cantos de cristal e
texturas coloridas) foram **reprovadas** pelo dono do projeto para os menus.
Elas continuam aqui apenas porque o HUD da campanha do Deserto usa os anéis de recurso
(`assets/ui/kit/ring*.png`).

O modelo visual aprovado está em [`docs/referencias/README.md`](../../../docs/referencias/README.md)
(referência: `docs/referencias/personagens/REFERENCIA_APROVADA.png`) e em
`scripts/ui/player_ui.gd`. O CI (`tools/player_ui/check_design.py`) falha se estas imagens
forem usadas nas telas do jogador.
