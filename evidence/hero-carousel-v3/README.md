# Capturas reais do hero V3

Geradas no Godot 4.7.2 oficial, renderizador GL Compatibility/Mesa llvmpipe.
JPEGs são apenas compressões dos frames PNG do motor, sem montagem ou sobreposição.
Os originais e logs da sessão estão em `/workspace/.runtime/evidence/`.

| Estado | Desktop 1672×941 | iPhone mini: área útil 712×338 | Padrão 640×360 |
|---|---|---|---|
| História | [captura](desktop/slide_0.jpg) | [captura](iphone-mini/slide_0.jpg) | [captura](android-640x360/slide_0.jpg) |
| Mata-Mata | [captura](desktop/slide_1.jpg) | [captura](iphone-mini/slide_1.jpg) | [captura](android-640x360/slide_1.jpg) |
| Biblioteca | [captura](desktop/slide_2.jpg) | [captura](iphone-mini/slide_2.jpg) | [captura](android-640x360/slide_2.jpg) |

A música exibida usa o catálogo e o transporte existentes. Não há contas reais de
usuários nas capturas. O perfil iPhone simula a área útil; não é Safari/aparelho físico.

## Resultados

- Importação e design: sem erros de scripts/cenas; `check_design.py` aprovado.
- Hero: **69 verificações aprovadas no renderizador real**, incluindo player por mouse/teclado; 66 no headless.
- iPhone: 64 verificações de interação aprovadas em 712×338; capturas dos três slides sem sobreposição de controles.
- Todas as **11 rotas** abertas e fechadas no smoke test existente.
- Sete regressões aprovadas: auth (20), persistência (11), sessão/música (15), convites (12), biblioteca (66), duelo local e startup (12).
- Captura de responsividade existente: seis telas em 844×390, `--ui-scale=3`.
- PWA: falha já isolada na expectativa de worker `waiting`; [log](logs/pwa-system.log). Nenhum teste completo do jogo exportado para Web foi executado.
- OAuth com contas reais, aparelhos físicos e EXE Windows não foram validados. Serviços online bloqueados pela política de rede inicial.

[Resultados estruturados](results.json) e [logs](logs/) distinguem os testes aprovados das limitações.
Alguns harnesses existentes emitem aviso de dois objetos restantes na saída; isso não foi tratado como erro de script nem como validação de ausência de vazamentos.
