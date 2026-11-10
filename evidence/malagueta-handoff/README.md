# Serra por vez, com antecipação da próxima

Pedido: uma serra atravessa a arena; a próxima aparece um pouco antes da saída
para permitir saltar entre elas. Sem cinco serras simultâneas/paradas.

- Janela de transferência: 3,6 s; no máximo duas serras consecutivas.
- Alturas: 1,2 / 3,1 / 5,0 / 6,9 / 8,8 m; dentes mais rasos, com folga
  acima da cabeça do jogador parado no apoio inferior.
- Espera sem malha, piso ou monitoramento de dano.
- Frasco preso pelo gargalo entre indicador e polegar do rig real.
- Rocha sem esticar a textura, repetição espelhada e tons menos amarelados.

`web/`: Godot Web 4.7.2 no Chromium/SwiftShader, 1672×941, 1920×1080,
844×390/DPR3 e 640×360/DPR3. UA iPhone e toque nos perfis móveis.
Não é Safari nem aparelho físico. A fixture congela o tempo em uma passagem
solo e numa transferência, posicionando o jogador invulnerável para inspeção.
As imagens não representam uma partida completa. `results.json` registra
contagens de serras visíveis e sólidas; `console.log` preserva o console.
As respostas 404 de recursos auxiliares da página estão registradas; os testes
verificam ausência de erros de script/runtime, não ausência de todo aviso HTTP.

`validation/`: percurso natural com comandos de salto e pulo duplo pelos cinco
níveis até o patamar fixo, com três vidas; sequência em dois ciclos; folga dos
dentes; cactos sobem, descem e respeitam limite; arena/combate/ações e pegada;
checkpoint e reação final. O teste de percurso aguarda cada transferência,
não teletransporta entre plataformas. Os avisos de recursos ao encerrar alguns
runners foram mantidos nos logs; não foi comprovada ausência de vazamentos.
`grip-native.png` é uma captura nativa aproximada do movimento de caminhada,
com câmera/clipe pausados somente na inspeção.

Alteração salva na branch codex/malagueta-motion-blade, sem publicação.
A proteção dos seis FBX já enviados à main continua pendente; não foi alterada.
