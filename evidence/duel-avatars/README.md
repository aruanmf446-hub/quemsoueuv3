# Mata-Mata — evidências de 05/11/2026

Branch `work/duel-avatar-apresentacao`, baseada em `d0ae424`.
Capturas reais do Godot 4.7.2 Compatibility/llvmpipe, sem edição da imagem.
Os participantes são de uma partida local de teste; o teste identifica suas
fixtures de vidas e encerramento para provocar derrota e vitória.

| Verificação | Resultado |
|---|---|
| `tests/duel_avatars/animations.gd` | 69 verificações: 21 clipes/ossos, El Fuego preservado, isolamento de loop e restauração do bus Music |
| `tests/duel_avatars/interactions.gd` | 26 verificações em 1672×941, 844×390 e 640×360; os dois últimos com perfil iPhone |
| `tests/duel_local/flow_test.gd` | 87 verificações; seleção, bots, sequência estável e partida até o resultado |
| `tests/battle_reveal/flow.gd` | 4 revelações reais detectadas durante a execução |
| `tests/iphone/layout_guard.gd --iphone` | 504 verificações, failures=0, nove perfis |
| `tools/player_ui/check_design.py` | OK |
| `tests/web_pwa/sw_test.js` | 29 verificações, failures=0 |
| Exportação Web release oficial 4.7.2 / web_nothreads | Concluída sem erros de importação/scripts/exportação |
| `tests/duel_avatars/web_smoke.cjs` | Build Web real abriu no Chromium com UA iPhone, 844×390, DPR 3; todas as solicitações externas bloqueadas |

O smoke Web registra canvas 2160×1059 e área CSS 720×353 em (62,16), conforme
[web-smoke.json](web-smoke.json), sem erros de JavaScript/GDScript coletados.
O smoke cobre abertura e navegação para convidado; o fluxo completo de batalha
foi exercitado nos testes nativos, não em dois navegadores online.

## Capturas

Cada resolução tem `deck`, `sala`, `selecao`, `ordem`, `suspense`, `derrota`, `galeria` e
`vitoria`. `suspense` mostra a entrada neutra; `galeria` mostra a carta removida.

| Estado | Desktop | iPhone 844×390 | iPhone 640×360 |
|---|---|---|---|
| ✓ / ✕ no deck | [ver](1672x941_deck.png) | [ver](844x390_deck.png) | [ver](640x360_deck.png) |
| Avatar na sala | [ver](1672x941_sala.png) | [ver](844x390_sala.png) | [ver](640x360_sala.png) |
| Seleção de cartas | [ver](1672x941_selecao.png) | [ver](844x390_selecao.png) | [ver](640x360_selecao.png) |
| Apresentação da ordem | [ver](1672x941_ordem.png) | [ver](844x390_ordem.png) | [ver](640x360_ordem.png) |
| Entrada sem resultado antecipado | [ver](1672x941_suspense.png) | [ver](844x390_suspense.png) | [ver](640x360_suspense.png) |
| Derrota | [ver](1672x941_derrota.png) | [ver](844x390_derrota.png) | [ver](640x360_derrota.png) |
| Galeria sem a carta eliminada | [ver](1672x941_galeria.png) | [ver](844x390_galeria.png) | [ver](640x360_galeria.png) |
| Vitória | [ver](1672x941_vitoria.png) | [ver](844x390_vitoria.png) | [ver](640x360_vitoria.png) |

Web real: [abertura](web-iphone-boot.png), [convidado](web-iphone-lobby.png).
Os arquivos `cowboy_anim_2/3/4.png` são quadros reais amostrados dos FBX originais,
não novas animações nem prova automática do significado de cada gesto.

## Limitações

- Sem teste em iPhone físico, Safari real ou partida com dois jogadores online.
- A exportação e o smoke Web não validam o servidor de duelo, Google/Discord ou chat remoto.
- Áudio nativo foi executado com driver Dummy: recursos, roteamento e duck foram
  conferidos por estado; não houve avaliação auditiva em hardware real.
- Renderizadores de software não representam o desempenho de um celular. A
  preparação assíncrona reduz leitura bloqueante; não há promessa de FPS medido em aparelho.
- Alguns clipes originais duram até 8,53 s; a apresentação não prolonga os turnos
  para mostrar cada clipe integralmente.
- Ordem/chat online e ausência de 2/3/4 em El Fuego estão documentados em
  [pendências](../../docs/DUEL_AVATAR_IMPROVEMENTS.md).

Nenhuma modificação de Supabase, assets de personagens, economia ou Modo História.
Publicação na main autorizada pelo dono em 05/11/2026. O resultado do deploy é
verificado pelo workflow `deploy-web.yml`; as limitações online acima permanecem.
