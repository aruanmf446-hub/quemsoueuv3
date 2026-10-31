# T19 — evidências

[Relatório e auditoria](../../docs/performance/T19.md) · [Resumo numérico](summary.json) ·
[Smoke 31 grupos](smoke.json) · [T19 56 verificações](web_responsiveness.log) ·
[Testes adicionais](extra-tests.json) · [Comparação de pixels](visual-comparison.json).

| Caso | Antes | Depois |
|---|---|---|
| 844×390 | [JSON](before-844x390.json), [captura](before-844x390.png) | [JSON isolado](after-844x390.json), [captura](after-844x390.png) |
| 1920×1080 | [JSON](before-1920x1080.json), [captura](before-1920x1080.png) | [JSON](after-1920x1080.json), [captura](after-1920x1080.png) |
| 640×360 | [JSON](before-640x360.json), [captura](before-640x360.png) | [JSON](after-640x360.json), [captura](after-640x360.png) |

Ensaio prolongado: [614,9 segundos, música e navegação](soak-844x390.json),
[captura de Controles ao final](soak-844x390.png). Não é aprovação por teste headless:
houve renderização real WebGL2 e eventos reais de mouse/toque/teclado do navegador.

O baseline corresponde à lógica da main em 63de2cc com instrumentação.
Depois: streaming de áudio, chunks/deadline, cache e navegação corrigidos. A guarda
adicional de fim de faixa durante um download foi coberta pela regressão e pela
repetição Web final após esse ensaio prolongado; não altera o caminho de entrada
em Ajustes ou o modo de decodificação medidos.

Ambiente: Chromium 154, GPU **por software** SwiftShader. HTTP de backend simulado,
sem credenciais reais; erros HTTP 503 de fixture não são falhas da produção. Não se
mede GPU física, VRAM ou OAuth real. Heap do Chrome não é RAM total/WASM/VRAM.
Veja limites e interpretação dos tempos no relatório, inclusive a latência alta
em desktop por software. Os MP3s e os pixels da UI foram preservados.
