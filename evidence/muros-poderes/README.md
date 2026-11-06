# Muros contínuos e introdução dos poderes

Correção sobre a main `eef55ed`, sem alterar movimentação, combate, dificuldade, modelos, música ou serviços.

- Muralha distante estendida para baixo da tela; pool, paralaxe e número de primitivas preservados.
- Coletas atualizam contadores e som, sem a faixa central “Fogo +1”. Avisos excepcionais ficam pequenos à esquerda.
- Âmbar (fase 3), Relâmpago (4) e Ruptura (5): zero cargas ao entrar; ocultos até a primeira recarga real. A primeira coleta pausa, mostra uma ilustração do efeito real e explica comando, custo e finalidade. Confirmar libera os comandos. O botão permanece visível com zero, inclusive após reiniciar/reabrir, respeitando o capítulo de desbloqueio.
- A confirmação da lição é salva por perfil. Flags antigas de descoberta automática não fazem os botões aparecer antes da primeira coleta. Saves de campanha não são apagados.
- As três ilustrações são renders do próprio Godot, com personagens, cenários e efeitos existentes. Nenhum asset externo ou imagem gerada por IA. Baker: `tests/desert_night/bake_power_lessons.gd`; originais em `assets/desert/tutorial/source/`, texturas com mipmaps `.res`. Pré-carregadas pela tela de preparação da fase.

## Capturas reais

Capturas arquivadas em JPEG para reduzir o tamanho do repositório; scripts reproduzem os PNGs originais. Teleporte de fixture somente para aproximar dos pontos de teste. Não são prova de aparelho físico.

| Janela | Muralha | Primeira recarga | Botão sem carga |
|---|---|---|---|
| 844×390, perfil iPhone | [muro](844x390/skyline_depth_render/muro_ate_embaixo.jpg) | [Âmbar](844x390/power_introductions_test/amber_primeira_recarga_licao.jpg), [Relâmpago](844x390/power_introductions_test/dash_primeira_recarga_licao.jpg), [Ruptura](844x390/power_introductions_test/rupture_primeira_recarga_licao.jpg) | [zero](844x390/power_introductions_test/amber_usado_botao_zero.jpg) |
| 640×360, padrão | [muro](640x360/skyline_depth_render/muro_ate_embaixo.jpg) | [Âmbar](640x360/power_introductions_test/amber_primeira_recarga_licao.jpg) | [zero](640x360/power_introductions_test/amber_usado_botao_zero.jpg) |
| 1920×1080, padrão | [muro](1920x1080/skyline_depth_render/muro_ate_embaixo.jpg) | [Âmbar](1920x1080/power_introductions_test/amber_primeira_recarga_licao.jpg) | [zero](1920x1080/power_introductions_test/amber_usado_botao_zero.jpg) |
| Web Chromium, 844×390, DPR 3 | — | [Âmbar](web/amber_lesson.jpg), [Relâmpago](web/dash_lesson.jpg), [Ruptura](web/rupture_lesson.jpg) | [Âmbar](web/amber_zero.jpg), [Relâmpago](web/dash_zero.jpg), [Ruptura](web/rupture_zero.jpg) |

## Validação

Resultado consolidado: [results.json](results.json). Godot 4.7.2 oficial, Compatibility.

- 40 verificações dos poderes + 5 do muro, em cada uma das três janelas: passaram.
- Dez percursos físicos completos, sem mortes e sem teleporte: passaram. Simulação de jogador experiente evita modais nos percursos; testes novos validam os modais separadamente. Sem cargas especiais automáticas.
- Reino v3, Reino10, checkpoints, 79 verificações de pedestais, 182 das Tasks, 72 de composição regional e 21 das lições originais: passaram.
- `python3 tools/player_ui/check_design.py`, `python3 tests/desert_night/scope_test.py --base eef55ed` e `git diff --check`: passaram.
- Web real: export WASM isolado, Chromium/WebGL2 SwiftShader, 844×390, DPR 3. Coleta por colisão real após aproximação de fixture; Continuar e uso por toque real; carga zero e persistência após reload. Sem exceções JavaScript/Godot e sem chamadas externas. Uma requisição opcional `loading/list.json` ausente no servidor da fixture devolveu 404; o shell documenta fallback para o fundo. Não houve erro de runtime.
- Não validado em Safari/iPhone físico nem medido FPS de GPU real; emulação usa GPU por software. Capturas headless de regras não são aprovação visual.

### Ajustes necessários nas fixtures

A primeira rodada está preservada nos logs, inclusive falhas antes dos ajustes dos testes. `pedestal_test` agora usa o perfil experiente: a nova pausa da lição impedia a montagem dos próximos chunks daquela fixture. Nenhuma verificação de pedestal foi removida; todas as seis categorias são exercitadas. `reino_v3_test` passa a verificar ausência de carga inicial conforme o pedido e compara as identidades de todos os perseguidores ainda vivos antes/depois do streaming, em vez de presumir que os oito iniciais sobreviveram à simulação anterior. O limite de oito continua testado. Nenhuma regra de inimigos foi alterada.

### Reprodução

```bash
GODOT=/caminho/Godot_v4.7.2-stable_linux.x86_64
QSE_TEST_IPHONE=1 "$GODOT" --path . --script tests/desert_night/power_introductions_test.gd -- /tmp/powers 844x390 --touch-controls
QSE_TEST_IPHONE=1 "$GODOT" --path . --script tests/desert_night/skyline_depth_render.gd -- /tmp/wall 844x390 --touch-controls
python3 tests/desert_night/run.py --godot "$GODOT" --only reino-v3 reino10 checkpoints route-01 route-02 route-03 route-04 route-05 route-06 route-07 route-08 route-09 route-10
# Web: export de staging com main tests/desert_night/web_fixture.tscn e feature iphone_layout_fixture;
# servidor http://127.0.0.1:8135/quemsoueuv3/; nunca usar a fixture no export de produção.
node tests/desert_night/web_power_introductions_probe.cjs
```
