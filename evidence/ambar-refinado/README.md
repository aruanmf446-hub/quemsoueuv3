# Refinamento do congelamento de Âmbar

Continuação do PR #102, sobre `9138820`. O efeito anterior usava três cones translúcidos sobrepostos. Agora há um único casulo facetado ajustado ao Cactus, com formação dos pés à cabeça em 0,18 s, superfície de resina, reflexos na silhueta, fissuras ao final e doze lascas na quebra (0,38 s). Mantém a identidade de Âmbar.

Apenas o acabamento mudou: o comando continua gastando uma carga, imobiliza por 3,5 s os inimigos atrás do jogador em até 8 m e permite a retomada da animação ao acabar. Sem novos sons, luzes, colisores, texturas externas ou alterações de dificuldade. A superfície do modelo é uma sobreposição temporária; materiais/texturas originais permanecem intactos.

A geometria do casulo e das lascas é compartilhada. Fragmentos usam MultiMesh. A animação encerra seu processamento ao terminar; reaplicar não acumula casulos nem reinicia a formação enquanto já está congelado. Lascas permanecem no ponto de descongelamento. Reciclagem e morte limpam o estado visual.

## Capturas reais do Godot

| Resolução | No jogo | Detalhe do acabamento | Quebra |
|---|---|---|---|
| 844×390, perfil iPhone | [jogo](844x390/03_congelado_no_jogo.jpg) | [detalhe](844x390/04_detalhe.jpg) | [quebra](844x390/06_quebrando.jpg) |
| 1920×1080 | [jogo](1920x1080/03_congelado_no_jogo.jpg) | [detalhe](1920x1080/04_detalhe.jpg) | [quebra](1920x1080/06_quebrando.jpg) |
| 640×360 | [jogo](640x360/03_congelado_no_jogo.jpg) | [detalhe](640x360/04_detalhe.jpg) | [quebra](640x360/06_quebrando.jpg) |

Fixture de apresentação identificada: aproxima atores reais e mantém a cena no ponto de teste. A captura “detalhe” usa aproximação de câmera somente para avaliar o efeito; a câmera de gameplay não foi alterada. Não são percursos nem testes em aparelho físico.

## Verificações

- 19 verificações em cada uma das três janelas: consumo real, duração, lado/alcance, pose parada, reuso, compatibilidade com flash de dano, materiais restaurados, fragmentos no local, término do processamento, reciclagem e morte; seis capturas reais por janela. [Resultados](results.json).
- Mesmas 13 verificações de regras sem capturas em modo headless: passaram. [Log](rules-headless.log). Este teste não é aprovação estética.
- Regressão Reino v3: passou, incluindo combate, imobilização, ruptura, perseguição e streaming. [Log](reino-v3.log).
- Design PlayerUI, escopo comparado a `9138820` e `git diff --check`: passaram.
- Ilustração da lição de Âmbar refeita com o mesmo efeito real; Relâmpago e Ruptura preservados. Baker agora aceita filtrar o poder, evitando refazer as outras imagens.
- Web: export WASM em servidor isolado, Chromium/WebGL2 SwiftShader, viewport 844×390, DPR 3. O probe exercita primeira coleta, lição, uso real por toque e persistência após reload. A amostra visual Web mantém um Cactus em pose por fixture para conferir os shaders. Resultados e capturas em `web/`.

Não houve validação em iPhone/Safari físico nem medição de FPS em GPU real. A aprovação visual continua com o dono.

## Reprodução

```bash
GODOT=/caminho/Godot_v4.7.2-stable_linux.x86_64
QSE_TEST_IPHONE=1 "$GODOT" --path . --script tests/desert_night/amber_freeze_render.gd -- /tmp/amber 844x390 --touch-controls
"$GODOT" --path . --script tests/desert_night/bake_power_lessons.gd -- amber
# Web: export de staging iphone_layout_fixture, servidor local na porta 8135:
QSE_POWER_WEB_KINDS=amber QSE_FREEZE_SHOWCASE=1 node tests/desert_night/web_power_introductions_probe.cjs
```

Web final: teste passou, sem exceções JavaScript, erros Godot ou requisições externas. [Cristalização no Web](web/amber_showcase.jpg), [lição atualizada](web/amber_lesson.jpg), [relatório](web/report.json).

CI geral anterior ao refinamento: iPhone passou; smoke mantém as falhas já registradas na main (`transition_01` a `transition_09`, `functional`, `battle_presentation`). Não equivale a um smoke completo aprovado.
