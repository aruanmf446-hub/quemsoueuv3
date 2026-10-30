# Menus na direção limpa aprovada

A composição e a nitidez do lobby aprovadas pelo usuário foram estendidas às dez
rotas do jogador, às vistas do Duelo/batalha e aos menus da campanha. O estilo está
centralizado no PlayerUI: superfícies discretas, fonte MSDF, filtragem linear,
foco visível e acento nas ações e seleções. O lobby permanece como referência.

As capturas abaixo são frames reais do Godot. Não houve composição de imagens.
Elas aguardam avaliação estética do usuário; os testes não substituem essa revisão.

| Tela | Desktop 1280×800 | Compacto 844×390 | Compacto 640×360 |
| --- | --- | --- | --- |
| Personagens | [abrir](desktop/skins.png) | [abrir](mobile/skins.png) | [abrir](small/skins.png) |
| Configurações / áudio | [abrir](desktop/settings.png) | [abrir](mobile/settings.png) | [abrir](small/settings.png) |
| História | [abrir](desktop/story.png) | [abrir](mobile/story.png) | [abrir](small/story.png) |
| Perfil | [abrir](desktop/profile.png) | [abrir](mobile/profile.png) | [abrir](small/profile.png) |
| Perfil público — fixture | [abrir](desktop/public_profile-fixture.png) | [abrir](mobile/public_profile-fixture.png) | [abrir](small/public_profile-fixture.png) |
| Amizades | [abrir](desktop/friends.png) | [abrir](mobile/friends.png) | [abrir](small/friends.png) |
| Carteira | [abrir](desktop/wallet.png) | [abrir](mobile/wallet.png) | [abrir](small/wallet.png) |
| Conta | [abrir](desktop/account.png) | [abrir](mobile/account.png) | [abrir](small/account.png) |
| Música | [abrir](desktop/music.png) | [abrir](mobile/music.png) | [abrir](small/music.png) |
| Duelo / entrada | [abrir](desktop/duel.png) | [abrir](mobile/duel.png) | [abrir](small/duel.png) |
| Criar sala — fixture | [abrir](desktop/duel-create-fixture.png) | [abrir](mobile/duel-create-fixture.png) | [abrir](small/duel-create-fixture.png) |
| Sala — fixture | [abrir](desktop/duel-room-fixture.png) | [abrir](mobile/duel-room-fixture.png) | [abrir](small/duel-room-fixture.png) |
| Seleção de cartas — fixture | [abrir](desktop/duel-selection-fixture.png) | [abrir](mobile/duel-selection-fixture.png) | [abrir](small/duel-selection-fixture.png) |
| Contagem — fixture | [abrir](desktop/duel-countdown-fixture.png) | [abrir](mobile/duel-countdown-fixture.png) | [abrir](small/duel-countdown-fixture.png) |
| Batalha / turnos — fixture | [abrir](desktop/duel-turns-fixture.png) | [abrir](mobile/duel-turns-fixture.png) | [abrir](small/duel-turns-fixture.png) |
| Confirmar eliminação — fixture | [abrir](desktop/duel-confirm-fixture.png) | [abrir](mobile/duel-confirm-fixture.png) | [abrir](small/duel-confirm-fixture.png) |
| Revelação — fixture | [abrir](desktop/duel-reveal-fixture.png) | [abrir](mobile/duel-reveal-fixture.png) | [abrir](small/duel-reveal-fixture.png) |
| Campeão — fixture | [abrir](desktop/duel-finished-fixture.png) | [abrir](mobile/duel-finished-fixture.png) | [abrir](small/duel-finished-fixture.png) |
| Pausa da campanha | [abrir](desktop/campaign-pause.png) | [abrir](mobile/campaign-pause.png) | [abrir](small/campaign-pause.png) |
| Derrota da campanha | [abrir](desktop/campaign-defeat.png) | [abrir](mobile/campaign-defeat.png) | [abrir](small/campaign-defeat.png) |
| Conclusão da campanha | [abrir](desktop/campaign-complete.png) | [abrir](mobile/campaign-complete.png) | [abrir](small/campaign-complete.png) |

Outras capturas:

- Configurações em 640×360: [gráficos](settings-categories/compact_1.png),
  [controles](settings-categories/compact_2.png), [idioma](settings-categories/compact_3.png)
  e [áudio com rolagem](settings-categories/compact_audio_scrolled.png).
- Densidade 3×, 2532×1170 pixels para 844×390 pontos:
  [configurações](retina/settings.png), [seleção](retina/duel-selection-fixture.png),
  [batalha](retina/duel-turns-fixture.png), [revelação](retina/duel-reveal-fixture.png)
  e [campeão](retina/duel-finished-fixture.png).
- [Aviso de orientação em 390×844](mobile/orientation.png). O jogo mantém o uso
  horizontal; menus internos em retrato não são um modo de jogo suportado.

## O que mudou

- O tema é aplicado também em telas isoladas, HUD e overlays da campanha. Os
  seletores recebem filtragem linear; o Nearest Mipmap global não afeta seus textos.
- Os retratos em cache passam de 360 para 720 px, com arquivo e chave próprios,
  para não reutilizar a cópia antiga em telas de alta densidade.
- Perfis usam personagem direto sobre o cenário. Campos, selos e foco continuam
  identificáveis. Estados offline e dados ausentes continuam verdadeiros.
- Os filtros de Personagens ocupam duas linhas; ações de sala podem quebrar de
  linha. Margens são reajustadas quando o mínimo diminui após o layout do texto.
- Na batalha, cartas têm nome legível e grade adaptada à largura. A confirmação
  da seleção fica antes do baralho. Cartas privadas ficam abaixo da área pública.
- Contagem regressiva tem largura própria. Confirmação, revelação e campeão
  respeitam a densidade e permitem rolagem se o conteúdo não couber.
- Pausa, derrota e conclusão usam os componentes compartilhados. Os sinais,
  regras de combate, RPCs, inventário e progressão não foram alterados.

## Verificações

Executadas com Godot **4.6.3.stable.official.7d41c59c4**, Compatibility, Mesa llvmpipe
em Xvfb; áudio Dummy nas capturas. Não houve export Web/APK nem teste em aparelho
físico ou navegador móvel. O workflow declara outra versão do motor; não se afirma
CI remoto aprovado ou igualdade de desempenho entre plataformas.

- Capturas e verificações de margens/cabeçalhos: as três rodadas completas
  terminaram com `MENU_SUITE_FAILURES 0`. Os estados adicionais de batalha,
  História, orientação e densidade 3× também passaram nas rodadas correspondentes.
- Fixtures de seleção de cartas verificam confirmação desativada antes da escolha,
  seleção de duas cartas, confirmação habilitada, uma ação despachada e limpeza
  da seleção local. A ação é interceptada no teste: **nenhum RPC é enviado**.
- Personagens: **32 verificações** aprovadas, incluindo busca, favoritos,
  bloqueios, equipamento, rotação e layout compacto.
- Configurações: **28 verificações** aprovadas.
- Música: **28 verificações** aprovadas.
- Sessão da campanha: **15 verificações** aprovadas com display, incluindo pausa,
  derrota, retomada, reinício e regressões já existentes de combate.
- Navegação: **25 verificações** aprovadas em cada uma de 1672×941, 844×390 e 640×360.
- Guard `tools/player_ui/check_design.py` e `git diff --check`: aprovados.

Os logs estão em [logs](logs). Há avisos de V-Sync e algumas instâncias ao encerrar
certos testes; eles não equivalem a validação completa de gameplay ou desempenho.

## Fixtures e limites da evidência

As páginas públicas usam o estado local disponível. Perfil público e os estados
de sala/partida têm dados **locais de teste**, identificados nos nomes dos arquivos.
As imagens de cartas são os assets reais do deck `lendas_urbanas`. As fixtures não
criam usuários/salas, não enviam mensagens nem validam autenticação, multiplayer,
privacidade no servidor, economia ou persistência remota. As telas da campanha
foram capturadas isoladamente; a sessão foi verificada separadamente com sua fase.

Reprodução (use user data isolado para os testes que gravam preferências):

```sh
godot --path . -s tools/godot/capture_menu_suite.gd -- /tmp/menus 844x390
godot --path . -s tools/godot/capture_menu_suite.gd -- /tmp/menus3x 2532x1170 --ui-scale=3 --only=duel,settings
python3 tools/player_ui/check_design.py
```
