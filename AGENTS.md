<!-- BEGIN:godot-mcp -->
## Godot (managed by godot-mcp; edit outside these markers)

- This is a Godot 4.7 project. Your training data may be older: use Godot 4 APIs and GDScript 2.0 syntax, never Godot 3.
- Use the `godot_*` MCP tools. Start with `godot_status`, then `godot_project_info` for the main scene, autoloads and input actions.
- Change scenes with the scene/node tools, not by hand-editing `.tscn` text. If the editor is open, edits there are undoable; save with `godot_scene_save`.
- Don't edit `.godot/` (generated cache). Keep `*.uid` and `*.import` files next to their resources when moving files.
- Check your work: `godot_run_start` (mode "process"), then `godot_run_output` with level "error".
<!-- END:godot-mcp -->

## Design dos menus (aprovado pelo dono do projeto — não alterar sem pedido explícito)

- **O modelo visual está em [`docs/referencias/README.md`](docs/referencias/README.md).** Telas do jogador (Personagens, Configurações, Amigos, Música, Duelo, Perfil, Carteira, História) seguem `docs/referencias/personagens/REFERENCIA_APROVADA.png`; o menu principal/lobby segue `docs/referencias/menu/REFERENCIA_MENU.png`. Abra essas imagens antes de mexer em interface.
- Os valores do modelo estão em `scripts/ui/player_ui.gd` (`PlayerUI`: cores e componentes `style_button`, `style_row`, `style_field`, `pill`, `plate`, `frame_panel`). Telas novas usam esses componentes; não definem cores nem estilos próprios.
- **Reprovado:** molduras e placas de imagem azul/douradas com brilho e cantos de cristal (`assets/ui/*`, `assets/ui/kit/*`, `assets/processed/frames/frame_painel_brasao.png`, texturas de `assets/processed/textures/`, `NinePatchRect`/`StyleBoxTexture` nessas telas). Não reintroduzir, nem "para combinar com o resto do jogo".
- Ao implementar uma função nova, reutilize o modelo. Mudança visual só quando o pedido for visual.
- Referências de organização e navegação (não de ornamento): menus de Fortnite, Call of Duty e PES — hierarquia clara, poucas cores, foco no conteúdo.
- `python3 tools/player_ui/check_design.py` (roda no CI) falha se o visual reprovado voltar às telas do jogador.
