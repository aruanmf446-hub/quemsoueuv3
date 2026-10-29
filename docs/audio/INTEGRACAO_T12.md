# T12 — Lobby aprovado + músicas do menu

Base: `work/lobby-visual-09a`, commit `42430b2e209e68e6405237c4cc373d23d5a69cab`.
Integração do commit `7cedc57bb0728715fbfd0d1a62a4be1822c75ec6` da T11.
Branch: `codex/t12-lobby-menu-music`; sem merge na main.

## Preservação

O `project.godot` foi combinado sobre a versão do lobby: somente a seção de quatro
linhas do autoload MenuMusic foi acrescentada. A configuração de fallback
`internationalization/locale/fallback="pt_BR"` e a orientação
`display/window/handheld/orientation=0` foram preservadas. Nenhuma versão completa
substituiu a outra. A aplicação da alteração foi resolvida automaticamente pelo Git,
sem marcadores de conflito.

Todos os arquivos da base do Claude, exceto essa adição ao `project.godot`, permanecem
idênticos. Não foram alterados cenas, composição, iluminação, Skins, Configurações,
menu, serviços, gameplay, economia ou Supabase. O nó local MenuMusic que o lobby
reservava continua sem stream e sem autoplay; o controlador real é o autoload
`/root/MenuMusic`. O teste de integração comprova que não há reprodução concorrente.

O catálogo continua vazio. Não há músicas de terceiros ou músicas fictícias. A API,
os atalhos e as regras de licença da T11 estão em `MENU_MUSIC.md`.

## Validação real

Motor oficial `4.7.2.stable.official.ed1daf0bf`, import completo com saída 0, sem
SCRIPT ERROR ou ERROR. Godot MCP não está disponível na sessão; foi usado o binário
oficial diretamente. Não houve regressão de produto que exigisse alterar arquivos
do lobby ou o player. O novo harness de integração teve suas anotações de tipo
ajustadas durante a preparação antes da execução final aprovada.

| Suite | Verificações aprovadas | Saída |
| --- | ---: | ---: |
| Músicas, projeto temporário e PCM zerado | 23 | 0 |
| menu_flow, cliques e navegação reais | 25 | 0 |
| screens_flow, Skins, configurações e três resoluções | 78 | 0 |
| touch_flow, entrada de toque real | 11 | 0 |
| Integração T12, autoload e lobby real | 24 | 0 |
| Total | 161 | 0 |

A integração verifica configuração, slider e barramento Music, mudo, atalhos,
identidade da instância de preferências, saída imediata do menu e retorno com pausa
manual preservada. O contexto fora do menu é um Node técnico com caminho de cena de
fase; não executa nem modifica gameplay. A suíte isolada testa os streams reais do
motor usando apenas silêncio técnico temporário, incluindo crossfade e licenças.

Para reproduzir, defina `GODOT` com o caminho do binário 4.7.2 e execute na raiz:

```bash
"$GODOT" --headless --path . --editor --import --quit
python3 tests/audio/run.py --godot "$GODOT"
XDG_DATA_HOME=/tmp/qse-t12-menu "$GODOT" --headless --path . --rendering-method gl_compatibility -s res://tools/godot/menu_flow.gd
XDG_DATA_HOME=/tmp/qse-t12-screens "$GODOT" --headless --path . --rendering-method gl_compatibility -s res://tools/godot/screens_flow.gd
XDG_DATA_HOME=/tmp/qse-t12-touch "$GODOT" --headless --path . --rendering-method gl_compatibility -s res://tools/godot/touch_flow.gd
XDG_DATA_HOME=/tmp/qse-t12-integration "$GODOT" --headless --path . --rendering-method gl_compatibility -s res://tests/integration_t12/menu_music_flow.gd
```

Os diretórios XDG isolam preferências de teste no Linux. As evidências finais e os
identificadores de base estão em `tests/integration_t12/results.json`.
A validação foi headless: não representa nova aprovação visual por captura de tela
nem escuta de faixas licenciadas. A preservação visual foi verificada por identidade
dos arquivos da base e pelos testes de layout/interação já existentes.
