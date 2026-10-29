# T14B — Configurações

Branch `work/settings-redesign-t14b`, base exata `82a399a1028ecc2821ed14982130dffb3f7877e1`. Sem merge automático.

Tela Godot real, com quatro categorias, painel rolável independente, seleção/foco/hover, valores percentuais e feedback de gravação. O layout compacto aplica escala apenas aos controles desta tela; não altera viewport, orientação ou lobby. Android usa apresentação compacta também em telas de alta resolução.

- Áudio: Master, Music, SFX e mudo persistente sem perder os volumes; compatível com o arquivo de preferências anterior.
- Gráficos: perfis reais existentes do palco 3D (resolução, sombras e MSAA). Não apresenta configurações fictícias nem altera o combate.
- Controles: remapeamento das teclas de confirmar/voltar dos menus, rejeição de duplicatas, orientações de mouse/toque/teclado. Comandos de gameplay preservados.
- Idioma: português e inglês; novas mensagens desta tela traduzidas. Conteúdo geral sem tradução continua com fallback português. Acesso à conta e privacidade existentes mantidos.

Arquivos de implementação alterados: `scripts/ui/screens/settings_screen.gd`, `scripts/services/device_preferences.gd` e `data/ui/en.json`. Nenhuma alteração em lobby, Skins, Supabase, gameplay, MenuMusic, cenas compartilhadas ou assets.

## Evidências

Godot **4.7.2.stable.official.ed1daf0bf**:

- 28 verificações funcionais de preferências, compatibilidade do arquivo antigo, recarga, áudio real, perfis 3D reais, remapeamento e categorias: `functional.log`.
- 23 verificações da suíte existente de áudio: `audio.log`.
- 24 verificações da integração existente lobby → configurações → gameplay → retorno: `menu_music_integration.log`.
- 22 execuções existentes de importação, dez fases, nove transições, funcional e lobby: `smoke.json` e `smoke/`.
- Capturas renderizadas por OpenGL/Mesa, sem composição: `captures/desktop_0..3.png` (1920×1080), `captures/english_0..3.png` (1280×720), `captures/mobile_0..3.png` e `mobile_audio_scrolled.png` (844×390). Ordem: áudio, gráficos, controles, idioma. Verificação dos limites das categorias e feedback no script de captura.

A janela de 844×390 verifica apresentação móvel horizontal, não substitui teste em aparelho Android físico. A música segue exclusivamente no contexto do menu; o catálogo não contém faixas aprovadas, portanto a reprodução audível não é simulada. A suíte de áudio utiliza apenas PCM silencioso técnico.

## Reproduzir

Com Godot 4.7.2 e dados de teste isolados (`XDG_DATA_HOME` em Linux):

```sh
godot --headless --path . --script tests/settings_t14b/verify.gd
python3 tests/audio/run.py --godot /caminho/godot
godot --headless --path . --script tests/integration_t12/menu_music_flow.gd
python3 tools/godot/run_smoke.py --godot /caminho/godot --output /tmp/qse-smoke
godot --path . --audio-driver Dummy --script tools/godot/capture_settings.gd -- /tmp/config 1920x1080
godot --path . --audio-driver Dummy --script tools/godot/capture_settings.gd -- /tmp/config-mobile 844x390
godot --path . --audio-driver Dummy --script tools/godot/capture_settings.gd -- /tmp/config-en 1280x720 en
```

MCP Godot não está disponível neste ambiente; execução, importação e captura foram feitas pelo binário oficial, sem editar `.tscn`.
