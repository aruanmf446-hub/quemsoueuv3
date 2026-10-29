# T15D — Fase 01 do Deserto

Branch `codex/gameplay-t15d`, criada a partir da `origin/main` em `1f7c4b0`.

## Integração seletiva e escopo

A main já incorporava os commits do Claude `1dbc7a5` e `19c53d0` pelo squash/PR #11. Os scripts e dados correspondentes foram comparados com `origin/work/fase01-gameplay-2_5d`: eram idênticos. Não foi feito merge integral nem cherry-pick duplicado. Foram mantidos os topos/vãos das plataformas e os dados de spawns, saltos, coyote time, buffer, defesa, agachar, checkpoints e lógica de retorno, substituindo somente a apresentação e os componentes da Fase 01.

As dez cenas usam um controlador compartilhado. Por isso T15D cria subclasses exclusivas em `scripts/desert/t15d/`, e apenas a cena Fase 01 aponta para a nova subclasse. A alteração da cena foi salva pela API `PackedScene`/`ResourceSaver` do Godot, com o UID original preservado. As cenas/scripts/dados das outras nove fases e os sistemas de lobby, Personagens, Configurações, Músicas, Supabase e social não receberam alterações. Os ajustes em testes compartilhados ficaram limitados ao combate: `tools/godot/functional.gd` agora exige preparação, dano no contato e dois golpes, em vez de esperar morte instantânea em dois ticks. O bot de `phase01_scenario.gd` se aproxima até o alcance válido e vira pelo input antes de bater, pois T15D não permite entrar no corpo do alvo. Nenhuma asserção de conclusão, morte, respawn ou defesa foi desativada.

## Correções verificadas

- A raiz Mixamo da corrida deslocava o visual mais de um metro à frente da cápsula. As animações são duplicadas por instância e as trilhas horizontais dos quadris ficam em posição local neutra. As originais/cache de outras fases não são alteradas. No teste em corrida, o erro horizontal máximo da raiz foi 0,0293 m.
- Repouso em guarda, derivado do primeiro quadro do clipe de ataque, com respiração discreta; sem congelar uma pose de corrida. Cadência de corrida, transições curtas, alinhamento dos pés por clipe e duração do gesto de ataque ajustados ao movimento físico.
- Aceleração/frenagem responsivas, controle no ar, pulo duplo, coyote time e buffer preservados. Agachar não permite levantar através de um teto. Os atores não viram piso nem empurram o protagonista para falsos estados de aterrissagem. A separação lateral impede interpenetração no combate sem reintroduzir colisores que funcionem como plataformas.
- Golpe com 0,18 s de preparação e um único impacto. Cactus da Fase 01 exigem dois golpes, anunciam o ataque por 0,36 s, sofrem interrupção/recuo e reconhecem bordas. A defesa funciona durante a preparação. Os valores das outras fases não mudaram.
- Câmera ortográfica acompanha o avanço, mantém o chão visível em saltos comuns e sobe quando o protagonista chega perto do teto do quadro. Respawn reposiciona a câmera. HUD compacto com fonte MSDF e alvos de toque de aproximadamente 52 pixels físicos. Multitoque permite manter direção e saltar duas vezes; mouse também aciona os controles virtuais.
- Fundo original gerado para esta tarefa, ruínas/arenito e superfícies 3D com vãos reais, topo alinhado aos colisores, estratos irregulares, pedras e sombras de contato. Arte/procedência em `assets/desert/phase01/ART_PROVENANCE.md`.

## Reproduzir

Requer Godot oficial `4.7.2.stable.official.ed1daf0bf` e um display OpenGL real/virtual. Foi usado Xvfb `:101`, Mesa/llvmpipe e Compatibility. Cada etapa do runner isola `user://`, preserva saída/erros do motor e reprova erros mesmo com exit code zero.

```sh
DISPLAY=:101 python3 tests/gameplay_t15d/run.py \
  --godot /workspace/.setup/quemsoueuv3/godot/Godot_v4.7.2-stable_linux.x86_64 \
  --output /tmp/t15d-validation
```

Etapas: importação, verificações adicionais em janela com teclado/multitoque/mouse, percurso completo do Claude em janela nas duas resoluções, capturas em **1920×1080** e **844×390**, smoke das dez fases e das rotas do menu. As capturas do runner são do framebuffer real, sem montagem. A sequência de captura de combate posiciona o jogador no trecho do primeiro checkpoint para avaliar os atores; isso está explícito em `capture.gd`. O percurso completo e a demonstração contínua usam somente ações de entrada, sem posicionamento artificial após o spawn.

`verify.gd` verifica também os cenários ausentes nos 19 checks antigos: visual junto da cápsula, repouso, frenagem, salto por tecla física, buffer na aterrissagem, teto baixo, camadas de colisão, preparação/contato único do golpe, reação defensiva, bordas, multitoque e liberação de ações. Os eventos sintéticos de teclado têm a fila explicitamente entregue antes do passo físico; os eventos de toque usam coordenadas locais do viewport, inclusive sob stretch.

## Evidências

Em `evidence/`: logs/resultados da rodada final, capturas antes/depois e estados de salto/combate nas duas resoluções. O percurso completou os 19 checks e a Fase 01 até a saída nas duas resoluções, incluindo morte proposital e retorno ao checkpoint. Na vitória, o progresso é fechado em 100% e os controles de gameplay são recolhidos. O smoke continua exercitando as outras nove fases e o menu.

`trecho-continuo.mp4` é uma gravação de 7 segundos do próprio Godot Movie Maker, incluindo corrida, travessia do primeiro vão, defesa e golpes, sem teleporte (`demo.gd`). A origem foi 1672×941 a 30 fps; o MP4 adiciona uma única linha inferior para compatibilidade YUV420p, ficando 1672×942. Não houve interpolação de quadros, criação de gameplay por IA ou edição da cena gravada. A arte de fundo foi gerada, mas os personagens e a movimentação vistos na gravação são renderizados pelo Godot.

## Limites

A validação gráfica foi feita em Linux por software, não em GPU/aparelho Android ou navegador Web. Movie Maker produz quadros com passo fixo; o vídeo não é medição de FPS em tempo real. Não há afirmação de desempenho em hardware final. O visual está implementado para revisão, sem presumir aprovação artística definitiva. A conversa externa “Criar imagem” não estava acessível; foi usada a ferramenta de geração disponível nesta sessão. Nenhum merge na main foi realizado.

Rodada aprovada: 36 checks adicionais; 19 checks de percurso em 1920×1080 e os mesmos 19 em 844×390; 22 etapas do smoke. Capturas de revisão identificaram e levaram a correções de cor/normais do terreno, painéis esticados, pés abaixo do piso, borrão no HUD, câmera subindo demais no salto e interpenetração de atores.

## Continuação — percurso fechado e cenário

A continuação em `codex/gameplay-t15d` mantém a Fase 01 isolada e acrescenta:

- Panorâmica original do cânion com paralaxe horizontal e vertical limitada. A primeira
  tentativa dissolvia duas arquiteturas e foi rejeitada na revisão das capturas por
  produzir torres transparentes. A versão final usa um único horizonte coerente.
- Material original de arenito, mipmaps, areia separada no piso, arcos em blocos,
  pedras/vegetação seca e suportes dos checkpoints. Não muda a superfície dos
  colisores, os vãos, os dados de mapa ou os spawns.
- Preparação e três indicadores de vida dos Cactus próximos, retorno à guarda entre
  golpes, recuperação após impacto e bloqueio de golpes por paredes nos dois sentidos.
  A animação de repouso dos Cactus também deriva de seu próprio clipe de ataque.
- Pausa por botão, Esc ou notificação Voltar, com continuar, retomar checkpoint,
  recomeçar e retornar aos reinos. Perda de foco libera o multitoque e pausa.
  Timers de respawn, checkpoint, efeitos e remoção do Cactus respeitam a pausa.
  Reiniciar cancela callbacks de morte antigos.
- Conclusão com tempo/derrotas reais da sessão, replay completo e avanço para a
  próxima cena existente. A política Voltar do aplicativo é restaurada ao sair.
  Nenhuma recompensa ou conclusão online é gravada.

O único ajuste de código de produção fora de `scripts/desert/t15d/` é a integração de navegação em
`story_screen.gd`: conecta o retorno oferecido pela fase e recolhe o wrapper antigo
que sobrepunha seu HUD. Ao avançar para uma fase legada, esse wrapper reaparece.
Não muda a composição do lobby, Personagens, Configurações, Músicas, serviços,
Supabase, gameplay compartilhado ou as outras fases.

O runner agora também executa `session_checks.gd` e `journey.gd` nas duas resoluções.
O primeiro isola pausa durante morte, cancelamento de respawn, perda de foco,
notificação Voltar, ataque através de parede, recuperação e remoção de cadáver.
O segundo usa a tela atual do Modo História: seleciona a fase 01, avança os
cartões ilustrados, inicia a partida, verifica vida/cargas e movimento, testa
queda e recomeço, então apresenta a história da fase 02 antes de pulá-la. A
conclusão da fase 01 é acionada como fixture para testar essa navegação; os
percursos completos das fases 01–09 são verificados em `tests/desert_night/route.gd`.

`route_movie.gd` grava exclusivamente o percurso completo até a primeira vitória,
sem menu, teleporte, callback de vitória antecipado ou respawn forçado. O vídeo é
produzido pelo Movie Maker do Godot e codificado em H.264, sem interpolação.
As imagens em `evidence/continuation/` são framebuffers nativos, incluindo entrada
pelo menu, trecho intermediário, combate, pausa e conclusão. Os logs e JSON da
rodada correspondente acompanham as capturas. A evidência anterior permanece
preservada em `evidence/` para comparação.

O escopo desta continuação é a **Fase 01** do início à conclusão, conforme a T15D.
O botão Próxima fase abre a Fase 02 original; não significa que as nove fases
seguintes receberam este acabamento. A validação continua em Linux/llvmpipe,
sem medição de desempenho em Android físico ou Web.

Rodada final da continuação: **36** verificações adicionais de controles/animação,
**14** de sessão/combate, **24** de fluxo completo em cada resolução (mouse em
1920×1080 e toque em 844×390), os **19** checks anteriores de percurso em ambas e
**22** etapas de smoke. Todos passaram no Godot 4.7.2. As duas jornadas pelo menu
chegaram à saída com **zero mortes**, sem reposicionamento após o spawn.


A gravação final `evidence/continuation/travessia-completa.mp4` contém **487 quadros**,
**16,23 s a 30 fps**: spawn, saltos, combate, degrau alto e saída, com **zero mortes**,
**vida 4/5** e **dois Cactus derrotados**. Fonte nativa Movie Maker 1672×941;
o MP4 tem 1672×942 apenas para acomodar YUV420p, com uma linha inferior adicionada.
Sem áudio, cortes, aceleração ou interpolação. O log original `continuous-route.log`
inclui o resultado e o tempo de renderização por software; não é um benchmark de FPS.
As capturas PNG exigidas continuam em suas resoluções nativas 1920×1080 e 844×390.
