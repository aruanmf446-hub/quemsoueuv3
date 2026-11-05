# Muralhas, palácios e telhados — revisão visual

## Versão aprovada publicada primeiro

A composição anterior e a correção dos pedestais foram publicadas na **main, 129f031**, antes desta revisão.

- [Deploy concluído](https://github.com/aruanmf446-hub/quemsoueuv3/actions/runs/42051713205).
- [Produção](https://aruanmf446-hub.github.io/quemsoueuv3/): HTTP 200 confirmado após o deploy.
- Evidência anterior: `../ambientes-pedestais/`.

## Nova revisão, separada para avaliação

Branch `codex/muralhas-palacios-telhados`. Não integrada à main nesta rodada.

- Fundo aditivo com muralhas e três complexos palacianos, reutilizando casa, loja, torre e arco existentes. Dunas e composições aprovadas preservadas; a função de agrupamento dos módulos permanece idêntica a 129f031.
- Pool fixo de três trechos de muro e três palácios, sem luzes, sombras dinâmicas ou colisões; paralaxe lenta. Ausente nas fases subterrâneas 6 e 10. A capital se distancia nas fases 7 e 9.
- Fase 2: superfície dos terraços, cornijas, juntas e pequenos acessos com cúpulas, ventilação e toldos atrás da rota. Fachadas existentes mantidas. Inclinação da câmera ajustada somente nessa fase para revelar a cobertura.
- Nenhuma alteração na velocidade, salto, poderes, combate, capacidade, plataformas físicas ou largura dos vãos. Nenhum asset externo ou imagem nova gerada. Materiais e geometria simples procedurais usam recursos existentes.

## Capturas reais

Godot 4.7.2 Compatibility, renderização gráfica Mesa/llvmpipe. Capturas de inspeção: posicionamento do ator e câmera por fixture, não comprovação de percurso. JPGs convertidos dos PNGs sem recorte.

- [Fase 2, início desktop](desktop/telhados_inicio.jpg).
- [Vão entre telhados, iPhone emulado](iphone/telhados_vao_04.jpg).
- [Palácios ao fundo, fase 3](desktop/fase_03_fundo.jpg).
- Pastas `desktop/` (1672×941) e `iphone/` (844×390, perfil UIScale iPhone): nove capturas por perfil e manifesto `captures.json`.

## Verificação

- `skyline_roofs_test.gd`: **74/74**. Pool estável ao avançar/voltar, sem colisões/luzes no fundo, decoração somente na fase 2, limpeza ao sair, raio atravessa o vão e encontra a aterrissagem original.
- `reino10` e percurso real `route-02`: **PASS**. O percurso usa comandos de movimento, sem teleporte nem invulnerabilidade.
- `check_design.py`: **PASS**; `scope_test.py`: **PASS**; `git diff --check`: **PASS**.
- Web: **PASS**, dez fases, história de oito quadros, toque, perseguição nos telhados e coleta preservando pedestal. Sem erros JavaScript/Godot ou requisições externas. Os dois avisos HTTP 404 no console são do favicon ausente. Resultado e capturas no diretório `web/`, Chromium com viewport 844×390, DPR 3 e toque; GPU de software. Não constitui validação em iPhone físico nem medição de desempenho em hardware real.

### Limitações conhecidas da base publicada

O deploy passou, mas o smoke geral da main não está verde: `transition_01`–`transition_09` e `functional` também falham no commit-base d0ae424. Não foram removidos ou enfraquecidos. O teste legado `reino_v3_test.gd` apresenta a mesma falha 83/84 na base e na versão anterior, sobre perseguidores vivos ao descarregar trechos; detalhes em `../ambientes-pedestais/README.md`.

Não houve acesso ao Supabase nem alterações em autenticação, música, economia, menus ou controles.
