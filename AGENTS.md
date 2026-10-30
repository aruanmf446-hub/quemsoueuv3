<!-- BEGIN:godot-mcp -->
## Godot (managed by godot-mcp; edit outside these markers)

- This is a Godot 4.7 project. Your training data may be older: use Godot 4 APIs and GDScript 2.0 syntax, never Godot 3.
- Use the `godot_*` MCP tools. Start with `godot_status`, then `godot_project_info` for the main scene, autoloads and input actions.
- Change scenes with the scene/node tools, not by hand-editing `.tscn` text. If the editor is open, edits there are undoable; save with `godot_scene_save`.
- Don't edit `.godot/` (generated cache). Keep `*.uid` and `*.import` files next to their resources when moving files.
- Check your work: `godot_run_start` (mode "process"), then `godot_run_output` with level "error".
<!-- END:godot-mcp -->

## Design dos menus (direção limpa aprovada pelo dono do projeto)

- Leia [`docs/referencias/README.md`](docs/referencias/README.md) e abra [`docs/referencias/menu/DIRECAO_CLEAN_APROVADA.png`](docs/referencias/menu/DIRECAO_CLEAN_APROVADA.png) antes de alterar a interface. O usuário aprovou esse lobby e pediu a continuidade nos demais menus, incluindo batalha.
- A fonte do estilo é `scripts/ui/player_ui.gd`: use `apply_theme`, `style_button`, `style_row`, `style_back`, `style_field`, `pill`, `plate` e `frame_panel`. Evite temas paralelos e repetição de caixas, filetes, brilhos ou sombras ornamentais.
- `apply_theme` fornece fonte MSDF e filtragem linear com mipmaps. Preserve a nitidez em telas isoladas, overlays e seletores; não herde o Nearest Mipmap global nos textos.
- Referências de organização: Fortnite, Call of Duty e PES. Priorize hierarquia, poucos acentos, navegação leve, uma ação principal clara e destaque do personagem.
- As imagens anteriores identificadas como históricas no README não são autorização para restaurar o visual reprovado. Pedidos funcionais preservam a composição aprovada.
- Mantenha sinais, ações, estados de seleção/bloqueio, privacidade dos dados e regras dos modos existentes. Fixtures visuais ficam apenas nos testes, identificadas como tal.
- Execute `python3 tools/player_ui/check_design.py`, os testes de interação pertinentes e confira capturas reais em desktop e janelas horizontais de 844×390 e 640×360. Não declare validação em navegador/aparelho físico a partir de uma captura do motor.
