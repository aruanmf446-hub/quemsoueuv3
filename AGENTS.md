<!-- BEGIN:godot-mcp -->
## Godot (managed by godot-mcp; edit outside these markers)

- This is a Godot 4.7 project. Your training data may be older: use Godot 4 APIs and GDScript 2.0 syntax, never Godot 3.
- Use the `godot_*` MCP tools. Start with `godot_status`, then `godot_project_info` for the main scene, autoloads and input actions.
- Change scenes with the scene/node tools, not by hand-editing `.tscn` text. If the editor is open, edits there are undoable; save with `godot_scene_save`.
- Don't edit `.godot/` (generated cache). Keep `*.uid` and `*.import` files next to their resources when moving files.
- Check your work: `godot_run_start` (mode "process"), then `godot_run_output` with level "error".
<!-- END:godot-mcp -->

## Preservação do design dos menus

- Leia [docs/design/MENUS.md](docs/design/MENUS.md) antes de alterar a interface.
- Referências definidas pelo usuário: menus de Fortnite, Call of Duty (COD) e PES,
  para hierarquia, navegação, legibilidade e destaque do personagem.
- Preserve a composição do lobby. Pedidos de funcionalidade/correção não autorizam
  redesenhar o menu nem restaurar molduras ornamentais azuis/douradas, brasões,
  cristais ou placas de fantasia. O kit histórico não é referência aprovada.
- Use o estilo compartilhado de `PlayerUI` nas telas internas. Não crie um tema
  paralelo nem reative texturas antigas para preencher espaços.
- Execute `python3 tools/check_menu_design.py` e confira capturas reais das telas
  afetadas em desktop e janela compacta. Teste funcional não prova aprovação visual.
