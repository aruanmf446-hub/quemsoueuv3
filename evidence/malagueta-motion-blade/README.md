# Malagueta — movimentos e lâminas

Capturas do Godot Web 4.7.2 executado em Chromium/SwiftShader. Perfis móveis
usam UA iPhone, toque e DPR 3; não representam Safari nem aparelho físico.

`web/`: arena nas quatro resoluções; estado combinado nos perfis móveis. A fixture prepara
a fase 10 localmente, suspende o início e deixa o jogador invulnerável para
inspeção. Nenhuma conta/backend é acessada.

`motions/`: prévia aproximada dos sete clipes, com o modelo de Idle. A câmera
e a seleção manual dos movimentos existem somente na fixture. O vídeo inclui
o carregamento inicial. A ligação aos estados reais foi conferida em
`tests/malagueta/actions.gd`, não inferida dessa prévia.

`validation/`: verificações nativas. O percurso vulnerável terminou com três
vidas; tentativas anteriores motivaram o espaçamento entre níveis e a navegação
do teste com pulo duplo aos 30 quadros, sem mudar a física do jogador.

Químicos: verde/vermelho coexistiram após as solturas animadas, mantiveram
trajetórias distintas e foram removidos pelo atordoamento (três verificações).
Design dos menus: `python3 tools/player_ui/check_design.py` aprovado.

Não publicado. Os seis FBX enviados à main já estão bloqueados pelo Approved
scope guard; a política e a variável de autorização não foram alteradas.
