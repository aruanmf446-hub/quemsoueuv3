# Acabamento do canal — fase 4

Base: `a5979c7`. Continuação do polimento visual, sem alterações de percurso,
colisões, câmera, poderes, controles, login ou serviços.

- O canal distante e a lâmina junto ao caminho compartilham o mesmo material.
- A textura já usada no oásis dá detalhe à água do aqueduto; não há asset novo.
- Dois fluxos lentos em coordenadas mundiais evitam reiniciar o padrão por peça.
- As quedas reaproveitam a textura, com fluxo vertical e brilho contido.
- A borda de pedra ganha um chanfro e um tom molhado junto à água.

Mantidos os lotes por trecho, sem novas luzes, malhas ou colisores. O remate
acrescenta dois quads por módulo do canal no lote existente. Há dois materiais de
água para a fase 4, como antes: horizontal compartilhado e queda compartilhada.
A textura é aquecida na entrada das fases 4/5 e reutilizada pelo cache. Não foram
usados reflexos de tela, refração ou redução da qualidade gráfica.

## Capturas e verificações

[Antes](844x390/antes.jpg) / [depois](844x390/depois.jpg), câmera e posição
equivalentes em 844×390. [640×360](640x360/fase_04.jpg) e
[1920×1080](1920x1080/fase_04.jpg) também foram conferidos no Godot 4.7.2.
`capture.gd` é uma fixture de cenário: posiciona o ator em x=35 m e retira encontros
somente durante a captura. Não representa uma travessia jogada.

Reprodução nativa, com perfil XDG isolado e display disponível:

```bash
mkdir -p /tmp/canal-captura
QSE_TEST_IPHONE=1 XDG_DATA_HOME=/tmp/canal-captura/data \
  XDG_CONFIG_HOME=/tmp/canal-captura/config XDG_CACHE_HOME=/tmp/canal-captura/cache \
  "$GODOT" --path . --audio-driver Dummy --max-fps 30 \
  --script "$PWD/evidence/canal-polish/capture.gd" -- 844x390 /tmp/canal-captura
```

[WebGL real](web/fase_04_agua.jpg), Chromium, iPhone emulado 844×390/DPR 3:
[relatório aprovado](web/report.json), zero erros e zero requisições externas ao
backend. Fixture `tests/story_continuity/web_fixture.tscn`; GPU SwiftShader.
O comando `QSE_WATER_PHASE=4 node tests/desert_night/web_water.cjs` usa a mesma
verificação da fase 5, preservando todas as asserções existentes. Requer a fixture
exportada e servida na porta 8135, conforme o roteiro de continuidade existente.

[Ambientes](regional-context.log): 72 verificações aprovadas, fases 1–10,
incluindo descarregamento, limites dos lotes e materiais compartilhados.
Há o aviso de duas instâncias ObjectDB no encerramento headless; não foi tratado
como falha de shader nem como validação de ausência de vazamentos no navegador.
Design, escopo, sintaxe, importação/exportação e links/metadados da habilidade
renomeada passaram. Não houve medição de FPS em aparelho físico, teste Safari
ou execução da suíte histórica completa nesta alteração visual.

## Habilidade renomeada

O nome agora é [qse-visual-polish](../../.agents/skills/qse-visual-polish/SKILL.md).
O conteúdo aprovado permanece compartilhado com Claude Code; `AGENTS.md`,
`CLAUDE.md`, metadados e links foram atualizados. A habilidade anterior foi movida,
sem deixar duas fontes divergentes. É uma habilidade do repositório.
