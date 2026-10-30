# Arquivos da Tarefa 03

**57 novos e 9 alterados**, na branch `codex/telas-sistemas-jogador-03`, sobre `d90dcb5`. Nenhum arquivo anterior foi removido. Os 82 arquivos das tarefas offline 01/02 permanecem intactos.

## Alterações anteriores justificadas

| Arquivo | Motivo |
| --- | --- |
| [data/characters.json](../../data/characters.json) | Troca da autorização legada de El Fuego pela conquista canônica, preservando IDs/modelos/alturas/animações. |
| [project.godot](../../project.godot) | Orientação landscape; cena principal, renderer e física preservados. |
| [scenes/menu/main_menu.tscn](../../scenes/menu/main_menu.tscn) | Mantém arte e composição; remove dados fictícios e conecta serviços/navegação/orientação. |
| [scenes/skins/skins_panel.tscn](../../scenes/skins/skins_panel.tscn) | O mesmo painel passa a usar o estilo discreto e o layout responsivo compartilhados. |
| [scripts/lobby/lobby_area.gd](../../scripts/lobby/lobby_area.gd) | Consulta e equipa pela fonte única, sem sobrescrever o save legado. |
| [scripts/lobby/lobby_stage.gd](../../scripts/lobby/lobby_stage.gd) | Inscrição no grupo de prévias e aplicação da preferência gráfica existente. |
| [scripts/menu/main_menu.gd](../../scripts/menu/main_menu.gd) | Liga botões, perfil, carteira e amizades às fontes compartilhadas. |
| [scripts/progress/player_progress.gd](../../scripts/progress/player_progress.gd) | Fachada compatível; nenhuma flag local concede desbloqueios. |
| [scripts/skins/skins_panel.gd](../../scripts/skins/skins_panel.gd) | Conserva catálogo/miniaturas/palco, acrescenta equipamento v2 e prévia integrada. |

## Arquivos novos

| Arquivo |
| --- |
| [build/.gitignore](../../build/.gitignore) |
| [data/backend/client.json](../../data/backend/client.json) |
| [data/ui/api.json](../../data/ui/api.json) |
| [data/ui/en.json](../../data/ui/en.json) |
| [data/ui/routes.json](../../data/ui/routes.json) |
| [data/ui/services.schema.json](../../data/ui/services.schema.json) |
| [docs/player/ARQUIVOS.md](../../docs/player/ARQUIVOS.md) |
| [docs/player/BACKEND.md](../../docs/player/BACKEND.md) |
| [docs/player/README.md](../../docs/player/README.md) |
| [docs/player/TESTES_GODOT.md](../../docs/player/TESTES_GODOT.md) |
| [docs/player/VALIDACAO.json](../../docs/player/VALIDACAO.json) |
| [docs/player/VALIDACAO.md](../../docs/player/VALIDACAO.md) |
| [export_presets.cfg](../../export_presets.cfg) |
| [scenes/player/account.tscn](../../scenes/player/account.tscn) |
| [scenes/player/components/screen_frame.tscn](../../scenes/player/components/screen_frame.tscn) |
| [scenes/player/friends.tscn](../../scenes/player/friends.tscn) |
| [scenes/player/profile.tscn](../../scenes/player/profile.tscn) |
| [scenes/player/public_profile.tscn](../../scenes/player/public_profile.tscn) |
| [scenes/player/settings.tscn](../../scenes/player/settings.tscn) |
| [scenes/player/story.tscn](../../scenes/player/story.tscn) |
| [scenes/player/wallet.tscn](../../scenes/player/wallet.tscn) |
| [scripts/services/device_preferences.gd](../../scripts/services/device_preferences.gd) |
| [scripts/services/friend_presence.gd](../../scripts/services/friend_presence.gd) |
| [scripts/services/friends_service.gd](../../scripts/services/friends_service.gd) |
| [scripts/services/inventory_service.gd](../../scripts/services/inventory_service.gd) |
| [scripts/services/player_contracts.gd](../../scripts/services/player_contracts.gd) |
| [scripts/services/player_services.gd](../../scripts/services/player_services.gd) |
| [scripts/services/profile_service.gd](../../scripts/services/profile_service.gd) |
| [scripts/services/progression_service.gd](../../scripts/services/progression_service.gd) |
| [scripts/services/remote_data_service.gd](../../scripts/services/remote_data_service.gd) |
| [scripts/services/service_result.gd](../../scripts/services/service_result.gd) |
| [scripts/services/session_service.gd](../../scripts/services/session_service.gd) |
| [scripts/services/supabase_client.gd](../../scripts/services/supabase_client.gd) |
| [scripts/services/wallet_service.gd](../../scripts/services/wallet_service.gd) |
| [scripts/ui/navigation_manager.gd](../../scripts/ui/navigation_manager.gd) |
| [scripts/ui/orientation_guard.gd](../../scripts/ui/orientation_guard.gd) |
| [scripts/ui/player_screen.gd](../../scripts/ui/player_screen.gd) |
| [scripts/ui/player_ui.gd](../../scripts/ui/player_ui.gd) |
| [scripts/ui/prototype_return_overlay.gd](../../scripts/ui/prototype_return_overlay.gd) |
| [scripts/ui/screens/account_screen.gd](../../scripts/ui/screens/account_screen.gd) |
| [scripts/ui/screens/friends_screen.gd](../../scripts/ui/screens/friends_screen.gd) |
| [scripts/ui/screens/profile_screen.gd](../../scripts/ui/screens/profile_screen.gd) |
| [scripts/ui/screens/public_profile_screen.gd](../../scripts/ui/screens/public_profile_screen.gd) |
| [scripts/ui/screens/settings_screen.gd](../../scripts/ui/screens/settings_screen.gd) |
| [scripts/ui/screens/story_screen.gd](../../scripts/ui/screens/story_screen.gd) |
| [scripts/ui/screens/wallet_screen.gd](../../scripts/ui/screens/wallet_screen.gd) |
| [scripts/ui/state_banner.gd](../../scripts/ui/state_banner.gd) |
| [supabase/migrations/202610280001_player_foundation.sql](../../supabase/migrations/202610280001_player_foundation.sql) |
| [supabase/migrations/202610280002_player_api.sql](../../supabase/migrations/202610280002_player_api.sql) |
| [supabase/migrations/202610280003_private_presence.sql](../../supabase/migrations/202610280003_private_presence.sql) |
| [supabase/preflight.sql](../../supabase/preflight.sql) |
| [supabase/tests/bootstrap_local.sql](../../supabase/tests/bootstrap_local.sql) |
| [tools/player_ui/.gitignore](../../tools/player_ui/.gitignore) |
| [tools/player_ui/check.py](../../tools/player_ui/check.py) |
| [tools/player_ui/requirements.txt](../../tools/player_ui/requirements.txt) |
| [tools/player_ui/test_database.py](../../tools/player_ui/test_database.py) |
| [tools/player_ui/test_static.py](../../tools/player_ui/test_static.py) |

Os testes e fixtures em `supabase/tests` são exclusivos do banco descartável local. Nenhum arquivo de teste é fonte de dados das telas. Consulte [README](README.md), [contratos de backend](BACKEND.md), [validação](VALIDACAO.md) e [roteiro MCP](TESTES_GODOT.md).
