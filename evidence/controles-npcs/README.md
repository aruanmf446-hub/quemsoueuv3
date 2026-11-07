# Controles funcionais e cidadãos originais — 2026-11-07

Os figurantes anteriores que reutilizavam heróis e o soldado Cacto foram retirados,
inclusive o gerador que os recriava. Os dois novos atlas contêm oito humanos e oito
cidadãos-cacto inéditos, cada um com pose de rotina e susto. Não alteram os modelos
jogáveis. Origem, transparência e alinhamento: `assets/desert/npc_citizens/`.

As posições gerais aprovadas foram preservadas. A distribuição alterna pessoas
sozinhas, conversas, comerciantes/clientes e famílias somente junto aos jardins.
Ficam parados; parte reage à corrida e parte continua sua rotina. Descarregam com
o trecho do cenário. A arte nova ainda depende da avaliação visual do dono.

Em Configurações → Controles e na pausa, o jogador escolhe Automático, Botões na
tela, Somente teclado ou Teclado e botões. A escolha é salva neste aparelho, sem
alterar conta, login ou backend. No modo misto, soltar uma fonte não cancela a outra.
No teclado, as medalhas continuam indicando cargas, sem virarem botões de toque.

## Capturas reais

- `cidadaos/`: Godot 4.7.2 em janela, cenas reais com enquadramentos da fixture.
  `family.jpg` e `conversation.jpg` mostram humanos; `market.jpg`, cidadãos-cacto.
- `844x390/` e `1672x941/`: Configurações, controles e pausa no motor.
- `web/`: export Web real em Chromium; ver relatórios para UA e resolução.

As fixtures não acessam serviços externos nem usam contas reais. São excluídas
do export de produção. As fotos mostram o jogo, não uma montagem de aprovação.

## Conferência

- Modos de controle: 20 verificações aprovadas, incluindo troca na pausa,
  liberação de teclas mantidas, toques curtos entre quadros, toque e teclado
  juntos e preferência persistida.
- Cidadãos: 8 verificações aprovadas, incluindo transparência dos dois atlas,
  pessoas e cactos originais, contexto, reações, pés e descarregamento.
- Regressões de feedback e ações reais aprovadas. Percursos físicos 1, 5 e 9
  aprovados durante esta tarefa; não houve alteração de terreno ou combate.
- Design e proteção de escopo aprovados, com exceção explícita apenas para as
  preferências de controle do dispositivo.
- Chromium Web: listas reais, teclado, toque curto de defesa, ambos os sentidos
  de liberação no modo misto, troca na pausa e persistência após recarregar aprovados.
  Sem erro de script/JavaScript ou acesso externo. Desktop com UA de computador
  1672×941 e emulação iPhone 844×390/DPR 3 e 640×360/DPR 3.
- Smoke completo integrado: 29/31 aprovados. As falhas de `functional` (modelo Malagueta) e
  `battle_presentation` repetem exatamente a base anterior, conforme logs em
  `verificacao/`. Nenhuma asserção foi removida para aprovar esta entrega.

Chromium usa GPU SwiftShader e emulação de iPhone; isso não comprova Safari,
iPhone físico ou desempenho em GPU física. Não houve acesso ao Supabase nesta tarefa.

Reprodução:

```sh
python3 tests/desert_night/run.py --godot /caminho/Godot4.7.2 --only control-modes feedback actions
Godot4.7.2 --headless --path . --script res://tests/control_modes/citizens.gd
python3 tools/player_ui/check_design.py
python3 tests/desert_night/scope_test.py --base 6efe00a --control-modes
```

A fixture Web é criada apenas em cópia de staging por `tests/control_modes/make_stage.gd`,
com a feature `control_modes_fixture`. O roteiro `tests/control_modes/web.cjs` abre
listas reais, usa teclado/toque, troca modo durante a pausa e recarrega o navegador.

Desktop Web com UA real de computador: `node tests/control_modes/desktop_web.cjs`.
