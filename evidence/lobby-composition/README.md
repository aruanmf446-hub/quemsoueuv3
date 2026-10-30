# Proposta de composição do lobby — em avaliação

O pedido desta revisão é visual: reformular a composição do lobby, preservando a
identidade do jogo. A proposta não substitui as referências aprovadas das outras
telas nem constitui uma aprovação estética do usuário.

- A navegação secundária passa para o cabeçalho, em texto.
- A campanha recebe uma área de apresentação à esquerda e uma ação Jogar.
- O personagem ocupa o lado direito, fora da coluna de controles.
- Um degradê separa o conteúdo do cenário; o fundo e os modelos são os existentes.
- Música, notícias e acesso social ficam no rodapé. Os controles de música têm
  alvos de 44 px na composição em densidade padrão.

Os botões e sinais originais são reaproveitados em um Control, com os mesmos
NodePaths, permitindo a composição livre sem editar cenas. A lista social completa
permanece em Amizades; o lobby mostra seu atalho. O título da campanha descreve
Deserto, sem inventar progresso, fase atual ou recompensas.

## Capturas reais

[Desktop 1280×800](desktop.png) · [Janela compacta 844×390](mobile.png).
As imagens `before-*` preservam o lobby capturado na entrega anterior, para
comparação de composição. As faixas musicais podem diferir por reprodução normal.

Godot 4.6.3, Compatibility/Mesa llvmpipe, Xvfb. Sem composição artificial de
imagens. Capturas compactas no motor não equivalem a teste em navegador móvel.
O problema de pixelização relatado no navegador do celular **não está declarado
resolvido** por esta proposta de layout. Não houve export/deploy Web ou APK.

## Verificação

`tools/godot/menu_flow.gd`: 25 verificações aprovadas em cada resolução, 1672×941 e
844×390. O teste agora aceita `--resolution=844x390` e transforma a posição de
clique do canvas para a janela, para testar corretamente a interface escalada.
Ver os logs `navigation-*`.

`python3 tools/player_ui/check_design.py` e `git diff --check`: aprovados.
Os logs de captura ainda emitem avisos para a antiga coluna lateral e para o
status oculto: esses critérios não correspondem à composição horizontal desta
proposta. A ocupação vertical do personagem é aproximadamente 70% em desktop e
65% na janela compacta. Há avisos de V-Sync e instâncias no encerramento.

Reprodução:

```sh
godot --headless --audio-driver Dummy --path . -s tools/godot/menu_flow.gd
godot --headless --audio-driver Dummy --path . -s tools/godot/menu_flow.gd -- --resolution=844x390
```
