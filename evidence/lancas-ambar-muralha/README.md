# Lanceiros, primeira defesa, âmbar e muralha

Entrega para avaliação visual. Main/Pages não foram alterados nesta rodada.

## O que muda no jogo

- Na primeira recarga de defesa da fase 1, o jogo pausa e mostra uma ilustração do encontro real. O soldado espera essa coleta antes de arremessar.
- O cacto usa sua animação de ataque existente para lançar uma lança com haste de madeira, ponta metálica e ferragens. O jogador pode bloquear, pular ou agachar. Acerto tira uma vida; a última vida abre a derrota e permite recomeçar.
- Errou a lança: o soldado tenta novamente. Acertou jogador ou escudo: começa a perseguição. Há um encontro na fase 1 e dois nas fases 6 e 8; as outras fases não recebem lanceiros.
- O âmbar conserva o dourado, com facetas transparentes ajustadas à pose, rachaduras perto do final e quebra curta. Não troca modelos, animações, alcance nem duração da habilidade.
- O fundo da fase 2 acompanha apenas parte da subida da câmera. As fundações dos palácios continuam até abaixo do enquadramento; o muro mantém sua base contínua.
- Corrigido um contato antigo entregue pela física ao reiniciar: ele podia consumir uma recarga distante e devolver defesa indevida no início da fase 1.

## Capturas

As pastas `1920x1080`, `844x390` e `640x360` contêm capturas reais do Godot Compatibility. O perfil de iPhone é usado somente em `844x390`.

- [Explicação da primeira defesa](844x390/primeira_defesa_lanca.jpg)
- [Lança em voo](844x390/02_lanca_no_ar.jpg)
- [Bloqueio](844x390/03_impacto_no_escudo.jpg)
- [Desvio agachado](844x390/05_desvio_agachado.jpg)
- [Salto](844x390/06_desvio_pulo.jpg)
- [Âmbar em detalhe](844x390/04_detalhe.jpg)
- [Muralha com o personagem no teto](844x390/p02_slot12_high0.jpg)
- [Muralha durante salto real](844x390/p02_slot12_high3.jpg)
- [Explicação no navegador](web/01_explicacao.jpg)
- [Resultado do bloqueio por toque no navegador](web/02_escudo_toque.jpg)
- [Âmbar no WebGL2](web/04_ambar_web.jpg)

As fixtures aproximam o personagem dos encontros. Lançamento, colisão, coleta, dano, defesa, salto, morte e reinício são reais. Capturas de impacto congelam um quadro; o detalhe do âmbar usa câmera aproximada. O teste do muro posiciona o personagem em cinco trechos, assenta-o pela física e executa saltos duplos reais. São capturas de pontos do mapa, não provas de percurso completo.

## Validação

- Regras da lança: 30 verificações; nova explicação e migração do save antigo: 8; primeiras lições existentes: 21.
- Âmbar: 13 verificações funcionais, mais capturas de formação, imobilização, fissuras e quebra.
- Pedestais: 79; contexto regional: 72; apoios nas tendas/objetos: 134.
- Percursos físicos completos das dez fases: todos passaram. Logs e resultados em `routes/`.
- Muro: 75 verificações por janela, incluindo apoio real, salto, paralaxe e base dos três muros e três palácios abaixo da tela. A primeira fixture foi corrigida para não partir de um módulo cujo piso é retirado por uma Task.
- Web: export real, Chromium com viewport 844×390, DPR 3, UA de iPhone e toque. Coleta, pausa ilustrada, botão Continuar, bloqueio por toque, perseguição e persistência após reload passaram sem erros JavaScript/Godot ou chamadas de backend. Resultado completo em `web/report.json`.
- `check_design.py`, verificação de escopo contra `5ebf63e` e `git diff --check` executados. Não há mudança de menus, áudio, autenticação, backend, modelos ou regras de movimento.

O navegador usa SwiftShader; o motor nativo usa llvmpipe. Isso valida o funcionamento e a renderização, não FPS em GPU real nem Safari/iPhone físico. A aprovação estética continua sendo do proprietário. O smoke geral do projeto não foi reexecutado nesta rodada; esta entrega usa as regressões dirigidas acima.

## Assets

Reaproveitados: cacto, protagonista, animação `ataque`, parede de defesa, arquitetura e cenários aprovados. Novo: `assets/desert/weapons/cactus_spear.res`, malha original gerada por `tools/godot/bake_cactus_spear.gd`. Nova ilustração `assets/desert/tutorial/defense.res` capturada do jogo; `amber.res` foi atualizado. Os PNGs fonte ficam em `assets/desert/tutorial/source/`.

## Reproduzir

```sh
python3 tests/desert_night/run.py --godot /caminho/godot --only spears spear-intro
# Cada execução gráfica precisa de um user:// isolado e de display/Xvfb.
godot --path . --audio-driver Dummy --script tests/desert_night/spear_encounter_test.gd -- /tmp/spears 844x390
godot --path . --audio-driver Dummy --script tests/desert_night/spear_intro_test.gd -- /tmp/intro 844x390
godot --path . --audio-driver Dummy --script tests/desert_night/wall_context_render.gd -- /tmp/walls 844x390
# Export isolado: web_fixture.tscn + feature iphone_layout_fixture; servidor local :8135/quemsoueuv3/.
node tests/desert_night/web_spear_probe.cjs
```
