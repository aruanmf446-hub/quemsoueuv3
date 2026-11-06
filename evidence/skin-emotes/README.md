# Prévia visual dos emotes

Capturas reais do Godot Web 4.7.2, com FBX originais e fixture isolada.
O jogador toca no cartão para reproduzir a animação no personagem à direita.
As três miniaturas mostram poses capturadas do mesmo modelo.

- `640x360_emotes.png` e `844x390_emotes.png`: Chromium, iPhone UA, DPR 3.
- `1672x941_emotes.png`: Chromium desktop.
- `results.json`: miniaturas visíveis, toque/clique, animação e retorno à pose.
- `gallery-test.log`: dez verificações da galeria visual.
- `native-test.log`: 26 verificações do controle das animações.
- `avatar-regression.log`: 69 verificações das reações automáticas existentes.

Os retratos distribuídos são reutilizados; a fixture não executa a geração
antiga de retratos, para isolar o teste das novas miniaturas de emotes.
Não houve teste em aparelho físico. Esta é uma prévia na branch separada.
