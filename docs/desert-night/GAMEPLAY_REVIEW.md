# Revisão de jogabilidade — fases 01–09 (cidade noturna no deserto)

Branch `codex/gameplay-t15d`. Escopo limitado aos scripts da campanha
(`scripts/desert/t15d/`) e aos testes de `tests/desert_night/`. Fase 10, main,
Supabase, lobby, Personagens, Configurações e Músicas não foram alterados.

## Como a revisão foi feita

Godot oficial `4.7.2.stable.official.ed1daf0bf`, renderizador Compatibility,
em Xvfb (Mesa/llvmpipe). Antes de editar, a base passou nos testes existentes e
foi inspecionada por capturas do framebuffer e por folhas de quadros de cada
clipe (`tests/desert_night/anim_sheet.gd`) e de cada ação em jogo
(`tests/desert_night/inspect.gd`).

## Problemas encontrados e correções

### Animações (`actor_slot.gd`, `player.gd`, `cactus.gd`)

| Problema visto | Correção |
| --- | --- |
| O FBX `ataque` é um combo (passo, investida e mortal para trás) espremido em 0,42 s: o personagem chegava a ficar deitado no ar e voltava de repente à guarda. | Clipe `golpe` recortado só da investida (0,42–0,76 s da fonte), com o braço estendido no quadro do impacto (`STRIKE_TIME` 0,16 s). Volta à guarda com mistura de 0,18 s. |
| A virada girava o modelo 180° em um quadro. | Giro visual de ~0,12 s passando pela frente do modelo; o colisor continua virando na hora. Cactus também giram suavemente. |
| Ao sair de uma borda andando, o clipe de corrida continuava no ar; depois do pulo, o último quadro ficava congelado. | Pose de `queda` derivada do próprio clipe de pulo (pernas procurando o chão), usada na descida e ao sair de bordas. |
| A aterrissagem tocava o FBX `retorno`, que é um recuo para trás: cada pouso parecia levar um golpe. | `aterrissagem` usa o agachamento de amortecimento do clipe de pulo. O `retorno` virou a reação de `dano`. |
| Dano só piscava a cor; o corpo ficava rígido durante o recuo. | Clipe de recuo, véu vermelho curto na tela, som e piscar durante a invulnerabilidade. |
| Corrida com cadência fixa: pés deslizando na aceleração e na frenagem. | Velocidade do clipe acompanha `|velocity.x|` (45–100%). |
| O impacto do Cactus vinha antes do braço chegar à frente. | Clipe de ataque do Cactus a 1,25× para coincidir com o fim da preparação de 0,36 s. |

### Combate e comandos

- Rastro curto do golpe mostra o alcance real (1,7 m), que o braço sozinho não
  cobre.
- Sons sintetizados em memória (`combat_sfx.gd`): golpe, impacto, dano,
  bloqueio, coleta, ação sem carga, preparação do Cactus e queda, no barramento
  `SFX` das Configurações. Não há arquivos de áudio novos.
- A defesa ganhou buffer de 0,2 s, como o ataque e o pulo: apertar pouco antes
  de pousar não se perde mais.
- Regras mantidas: vida 3/3, ataque 1/1 e defesa 1/1; contato com Cactus causa
  dano; ataque e defesa consomem carga; carga cheia não consome a reposição;
  itens coletados não reaparecem ao voltar pelo mapa.

### Buracos, morte e reinício (`phase.gd`, `campaign_hud.gd`)

- O vão mostrava o panorama da cidade através do chão e parecia uma janela. Agora
  há um poço escuro com gradiente e fundo de fenda, frisos âmbar nas duas bordas e
  uma faixa marcada antes de cada borda, nos dois sentidos.
- A câmera antecipa 2,4 m na direção da corrida (antes 1,4 m), e o quadro
  ficou um pouco mais próximo (7,0 em vez de 7,6 no desktop e 6,0 em vez de 6,9
  no celular). Um vão aparece cerca de 1,5 s antes da borda em velocidade máxima.
- Em 844×390 os botões de toque da direita cobriam a borda do próximo vão. Em
  telas baixas o chão sobe para cerca de 60% da altura e os botões ficam sobre a
  parede de terra.
- A morte escurece a tela, toca a queda e reinicia a fase inteira (vida,
  cargas, inimigos e itens). O véu é removido e nenhuma ação fica presa.

### Cena, HUD e conclusão

- Luz de recorte quente acompanha El Fuego: o traje escuro não some diante da
  muralha.
- No celular, o HUD encolhe 20% e esconde a linha secundária.
- O texto "PRÓXIMO DISTRITO" era cortado pelas colunas do arco de saída; agora
  fica acima do arco e sem teste de profundidade.

## Validação

`python3 tests/desert_night/run.py --godot <Godot 4.7.2> --output <pasta>`

- `layout`, `legacy10`, `progress`: estrutura dos nove mapas, isolamento da
  fase 10 e desbloqueio sequencial (concluir libera apenas a seguinte).
- `rules-*`, `navigation-*`: regras, teclado, multitoque, pausa e navegação em
  janelas reais de 1920×1080 e 844×390.
- `feel-01/05/09` (novo, `feel_test.gd`): cadência da corrida, virada gradual,
  pulo/queda/aterrissagem, queda pela borda, poço e frisos nos dois lados,
  travessia de ida e volta pelo mesmo vão, golpe recortado e rastro, impacto no
  quadro do braço estendido, dano com recuo/véu/piscar, véu removido e
  nenhuma ação presa depois da morte.
- `route-01`…`route-09`: percurso completo de cada fase somente por entradas
  (mover, pular, atacar), sem teleporte depois do spawn, com passo físico fixo.
- `window-route`, `mobile-route`: o mesmo percurso da fase 01 em janela gráfica.

Resultado da rodada final (código do commit desta revisão): **23 de 23 etapas
aprovadas**. Foram 42 verificações de regras em cada resolução, 23 de sensação
em cada uma das fases 01, 05 e 09, e as nove fases concluídas por entradas sem
morte, em 210,5–214,5 s de física cada, com todos os Cactus derrotados (14–20 por
fase). O percurso gráfico da fase 01 chegou à saída em 1920×1080 e em 844×390.

Capturas e resultados: `evidence/desert-night-gameplay/` (ver o README da pasta).

## Limites

- Render por software (llvmpipe) em Linux. Não houve GPU real, aparelho Android
  ou navegador. Desempenho e toque em hardware real não foram medidos.
- O piloto automático joga melhor que uma pessoa: os 210–214 s por fase medem a
  distância mínima percorrida, não a duração de um jogador.
- As capturas de `inspect.gd` reposicionam o jogador para chegar a cada situação
  (combate, borda, queda, conclusão). Elas avaliam aparência, não percurso. A
  sequência do golpe é capturada em câmera lenta (`time_scale` 0,2), porque o
  rastro dura 0,16 s e o render por software desenha poucos quadros.
- Os sons foram verificados como gerados e tocados (driver de áudio Dummy). O
  timbre não foi ouvido nesta máquina.
- Os clipes continuam sendo os FBX Mixamo existentes. A revisão recorta e
  sincroniza esses clipes, mas não cria animações novas, como uma corrida de
  frenagem dedicada.
