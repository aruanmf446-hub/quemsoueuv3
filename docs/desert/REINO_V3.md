# Reino do Deserto V3

A campanha1–9 aproveita o controlador noturno existente, seus oito distritos, checkpoints, colisões e streaming. A fase10 permanece no controlador original. Base da entrega: `b10be149ba2d332a44cc1dcbb4c1ebe9aaaff3d6`.

## Rotas e cenários

Portões da Capital → Bazar da Meia-Noite → Telhados da Cidade → Muralhas do Palácio → Aquedutos do Reino → Jardins do Oásis → Ruínas da Fronteira → Estrada da Mineração → Entrada da Mineradora. Cada uma tem oito distritos nomeados, três camadas ilustrativas, marcos próximos próprios e variações físicas de parkour. O destino da fase9 é o acesso externo à mineradora.

As artes ilustrativas são os recursos provisórios do ZIP; modelos e FBX oficiais são preservados. A entrada narrativa está documentada em [STORY_V3.md](../presentation/STORY_V3.md).

## Controles e regras

- Fogo/J e Defesa/Shift conservam golpe corpo a corpo, animação e bloqueio; capacidade de três cargas. Vida continua3/3.
- Ruptura/Q: descoberta na fase2; quebra somente uma peça marcada de3m já ultrapassada, sem itens/checkpoints nem personagens sobre ela. Colisor desativado e peça cai; estado permanece durante streaming. Restaura após8s de jogo, adia restauração se o jogador estiver dentro do vão; retry/checkpoint limpam o estado.
- Âmbar/E: descoberta na fase4; imobiliza Cactus próximos por3,5s com cristais transparentes ao redor do modelo original.
- Relâmpago/R: descoberta na fase6; impulso de7,4m/s por1,15s, com colisão normal. Pausa, dano e morte cancelam o impulso.
- Poder não descoberto não deixa botão/moldura. O primeiro desbloqueio é garantido ao alcançar o capítulo2/4/6, com uma carga e tutorial; não depende de pegar um item opcional. Descoberta é salva localmente em `user://desert_abilities_v3.cfg`, sem conceder inventário/recompensa online. Retry zera cargas novas e mantém descoberta; item cheio permanece no mundo.
- Botões de mouse/teclado no desktop; joystick e círculos separados com multitoque. O iPhone usa somente sua exceção de layout existente; demais telas mantêm1672×941.

Tropas usam uma raiz persistente fora dos chunks e uma reserva de oito modelos preparada na entrada. Ondas surgem em solo seguro atrás da câmera, nunca por teletransporte através de obstáculo. Cactus respeitam abismos/muros; salto curto aceita bloco até0,65m e1,25m de largura, com piso contínuo na aterrissagem. Remoção por distância não concede derrota.

O percurso mínimo é calculado com7,4m/s e desconta os vãos de balsa mais margem de saída, mesmo supondo transporte instantâneo. Não há espera por relógio na saída.

## Verificação reproduzível

Use Godot4.7.2. Os testes usam perfis locais isolados; fixtures não entram no export publicado.

```sh
python3 tests/desert_night/run.py --godot /caminho/godot --output /tmp/reino-qa
# Com display virtual :104 disponível para as etapas gráficas.
GODOT=/caminho/godot tests/iphone/capture_models.sh /tmp/iphone-modelos
xvfb-run -a /caminho/godot --path . --script res://tests/iphone/layout_guard.gd
/caminho/godot --headless --fixed-fps 60 --path . --script res://tests/desert_night/reino_v3_test.gd
python3 tools/player_ui/check_design.py
QSE_CHROMIUM_EXECUTABLE=/usr/bin/chromium node tests/web_pwa/sw_test.js
```

`route.gd` percorre fisicamente as fases, sem teletransportar o jogador. Registra intervalos físicos e intervalos entre quadros separadamente: câmera lenta de impacto torna o intervalo físico inadequado como custo de um único quadro. O orçamento é p95 de quadros<33ms; os picos continuam nos JSONs e logs, sem prometer ausência de engasgos ou desempenho em aparelho físico.

`reino_v3_test.gd` exercita cargas, HUD oculto, gelo/liberação, colisão/restauração de ruptura, salto proibido em abismo/muro, oito perseguidores, streaming, distância real do dash e parede.

`reino_v3_gallery.gd` e as capturas de intro são fixtures visuais identificadas; não comprovam travessia nem vitória. `web_desert_fixture.gd` só executa com feature de teste e `web_desert_probe.cjs` bloqueia destinos externos, testa os oito quadros por toque, leitura longa sem avanço automático, dash e preferência de não repetir após reload. Para montar o staging, use a cópia isolada descrita em [WEB_VALIDATION.md](../../tests/iphone/WEB_VALIDATION.md), substituindo apenas o script da fixture por `web_desert_fixture.gd` e mantendo esse conteúdo fora da publicação.

Resultados e capturas finais: [evidence/reino-v3](../../evidence/reino-v3/README.md) e [evidence/story-v3](../../evidence/story-v3/README.md). Chromium com UA de iPhone é validação Web emulada; não representa Safari nem aparelho físico.
