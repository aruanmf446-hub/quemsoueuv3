<!-- BEGIN:godot-mcp -->
## Godot (managed by godot-mcp; edit outside these markers)

- This is a Godot 4.7 project. Your training data may be older: use Godot 4 APIs and GDScript 2.0 syntax, never Godot 3.
- Use the `godot_*` MCP tools. Start with `godot_status`, then `godot_project_info` for the main scene, autoloads and input actions.
- Change scenes with the scene/node tools, not by hand-editing `.tscn` text. If the editor is open, edits there are undoable; save with `godot_scene_save`.
- Don't edit `.godot/` (generated cache). Keep `*.uid` and `*.import` files next to their resources when moving files.
- Check your work: `godot_run_start` (mode "process"), then `godot_run_output` with level "error".
<!-- END:godot-mcp -->

## Acabamento visual do projeto

- Em tarefas com impacto visual (design, UI/UX, cenários, assets, materiais,
  efeitos, enquadramento ou responsividade), leia e aplique a habilidade
  [`qse-visual-polish`](.agents/skills/qse-visual-polish/SKILL.md).
- Em mudanças funcionais, preserve o desenho aprovado e confira o impacto visual
  quando existir; não transforme a correção em uma repaginação não solicitada.
- Essa habilidade padroniza a qualidade e as evidências. O escopo e a autorização
  definidos pelo dono continuam prevalecendo, inclusive para publicação.

## Design dos menus (direção limpa aprovada pelo dono do projeto)

- Leia [`docs/referencias/README.md`](docs/referencias/README.md) e abra [`docs/referencias/menu/DIRECAO_CLEAN_APROVADA.png`](docs/referencias/menu/DIRECAO_CLEAN_APROVADA.png) antes de alterar a interface. O usuário aprovou esse lobby e pediu a continuidade nos demais menus, incluindo batalha.
- A fonte do estilo é `scripts/ui/player_ui.gd`: use `apply_theme`, `style_button`, `style_row`, `style_back`, `style_field`, `pill`, `plate` e `frame_panel`. Evite temas paralelos e repetição de caixas, filetes, brilhos ou sombras ornamentais.
- `apply_theme` fornece fonte MSDF e filtragem linear com mipmaps. Preserve a nitidez em telas isoladas, overlays e seletores; não herde o Nearest Mipmap global nos textos.
- Referências de organização: Fortnite, Call of Duty e PES. Priorize hierarquia, poucos acentos, navegação leve, uma ação principal clara e destaque do personagem.
- As imagens anteriores identificadas como históricas no README não são autorização para restaurar o visual reprovado. Pedidos funcionais preservam a composição aprovada.
- Mantenha sinais, ações, estados de seleção/bloqueio, privacidade dos dados e regras dos modos existentes. Fixtures visuais ficam apenas nos testes, identificadas como tal.
- Execute `python3 tools/player_ui/check_design.py`, os testes de interação pertinentes e confira capturas reais em desktop e janelas horizontais de 844×390 e 640×360. Não declare validação em navegador/aparelho físico a partir de uma captura do motor.

- Telas internas (Amizades, Duelo e partida, Configurações, Biblioteca, Perfil e Personagens) usam fundo sólido opaco de `PlayerUI.INTERIOR_BG`. Não reaplicar a imagem do lobby nem um véu translúcido nessas telas. A arte do lobby fica no lobby; artes de cartas e personagens continuam no conteúdo.
- Retratos dos personagens equipáveis são distribuídos em `assets/portraits`; Amizades e Duelo não podem depender de abrir Personagens antes ou de caches de `user://`. Refaça os retratos pelos modelos reais com `tools/godot/bake_portraits.gd` quando necessário.
- **Exceção iPhone (PWA/Safari, decisão do dono):** só no iPhone o jogo fica dentro da área segura (faixas pretas no notch, topo e barrinha), usa a base 1200×675 (`UIScale.IPHONE_BASE`) e um piso de fonte. Ver [`docs/layout/README_IPHONE.md`](docs/layout/README_IPHONE.md). Demais aparelhos seguem a regra abaixo sem mudança.
- **Layout padrão em todas as telas (decisão do dono):** o jogo é desenhado uma vez na base 1672×941 (stretch `canvas_items`/`expand`) e o Godot escala tudo por igual. Não criar layouts "compactos", escalas por densidade (`UIScale.unit_for`/`PlayerUI.unit` são sempre 1) nem fontes/botões diferentes por aparelho. Telas mais largas só mostram mais espaço. `UIScale.is_handheld()` serve apenas para desempenho e toque. Validar com `tests/responsive/capture_all.gd` (inclusive com `--ui-scale=3`).

## Figurantes do cenário (decisão do dono)

- Cidadãos do fundo usam assets inéditos de pessoas e cidadãos-cacto, com roupas civis.
  Não reutilizar imagens, retratos ou renders dos personagens jogáveis nem do soldado
  Cacto de combate como figurantes. As posições gerais foram aprovadas; esse reaproveitamento foi reprovado.
- Usar grupos espaçados e contextualizados: comerciantes/clientes nas bancas, famílias
  nos jardins, trabalhadores e vigias nas áreas correspondentes. Alguns ficam sozinhos.
- Cidadãos ficam parados, mantendo a rotina ou reagindo discretamente à passagem do
  jogador. Evitar corrida em loop, rotação para o fundo e multidões repetidas.
- Fonte atual: `assets/desert/npc_citizens/` e `scripts/desert/t15d/background_people.gd`.
  Ver `docs/desert/NPCS_CIDADAOS.md`. Capturas anteriores com heróis como cidadãos
  são históricas e reprovadas para esse uso.
