# Prévia dos emotes originais

Godot Web 4.7.2 real, assets FBX originais, fixture isolada sem conexão ao backend.
A fixture libera somente os sete personagens iniciais para testar os controles.

- `640x360_emotes.png`: Chromium, user agent de iPhone e DPR 3.
- `844x390_emotes.png`: Chromium, user agent de iPhone e DPR 3.
- `1672x941_emotes.png`: Chromium desktop.
- `results.json`: toque/clique inicia a animação, controles cabem no viewport e
  o término restaura a pose; nenhum erro de script.
- `native-test.log`: 26 verificações no motor, incluindo restauração dos ossos.
- `avatar-regression.log`: 69 verificações das reações automáticas existentes.

Não houve validação em aparelho físico. Esta etapa é a prévia na tela
Personagens. Estilos alternativos e uso compartilhado de emotes continuam
pendentes de definição em `docs/characters/SKIN_VARIATIONS_EMOTES.md`.
