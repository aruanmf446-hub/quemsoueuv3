# Menus sem o kit ornamental reprovado

Capturas reais via Godot/OpenGL em Xvfb, sem composição de imagens. Ambiente local:
Godot **4.6.3.stable.official.7d41c59c4**, Compatibility/Mesa llvmpipe e áudio Dummy.
O projeto/workflow declara 4.7.2; essa versão não foi executada nesta sessão.
Não houve export Web/APK nem teste em aparelho físico.

## Aparência

- [Configurações 1280×800](settings-1280x800.png)
- [Configurações 844×390](settings-844x390_0.png) e [áudio rolado](settings-844x390_audio_scrolled.png)
- [Personagens 1280×800](skins-1280x800.png)
- [Personagens 844×390](skins-844x390.png)
- [Lobby 1280×800](lobby-1280x800.png) e [844×390](lobby-844x390.png)

A composição do lobby segue em `lobby_composition.gd`. Foram removidas as
referências antigas persistidas nas cenas, inclusive as que o script ocultava ou
substituía em runtime. O Godot salvou as cenas pela API de recursos; a serialização
também reordenou propriedades e adicionou identificadores locais.

## Verificações

- `python3 tools/check_menu_design.py`: aprovado. Uma fixture temporária confirmou
  que referências novas em script e cena são rejeitadas e que o HUD da campanha
  fica fora do escopo.
- `tests/skins/visual.gd`: 32 verificações de interação/layout. A primeira tentativa
  revelou uma escala compacta fixa de 2×, corrigida usando a unidade do viewport.
- `tests/settings_t14b/verify.gd`: 28 verificações aprovadas.
- `tools/godot/menu_flow.gd`: 25 verificações aprovadas.
- `git diff --check`: aprovado.

Os logs estão em [logs](logs). As capturas adicionais do teste de Personagens
registram 1280×720, 960×540 e 800×450, com a galeria rolada até o fim.

## Limitações e resultados adicionais

`tools/godot/screens_flow.gd` terminou com **oito falhas** em
`skins_equip_button_present_*`: ele procura um botão de equipamento em cada cartão,
enquanto a galeria atual concentra a ação na prévia lateral. Esse teste não foi
alterado para esconder o resultado. O teste específico `tests/skins/visual.gd`
verifica a ação real, os estados equipado/bloqueado e o serviço de inventário.

As capturas de lobby emitiram avisos do verificador sobre largura da barra e
posição do status oculto. Os logs de saída também registram avisos de V-Sync e
algumas instâncias remanescentes ao encerrar os testes. Não se afirma smoke
completo ou CI remoto aprovado. A aprovação estética cabe ao usuário.
