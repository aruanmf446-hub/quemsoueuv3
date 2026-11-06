# Progresso contínuo, cargas, carregamento e apoios

## Resultado

- Visitante com 5 fases concluídas + conta com 2: preserva as 5 e libera a fase 6 automaticamente.
- Conta mais avançada: recupera o avanço maior; diferença recebe aviso, sem pergunta de substituição.
- Troca de contas e resposta atrasada não misturam os arquivos. Offline mantém o avanço local e envia depois.
- Cargas guardadas chegam à próxima fase; leitura pelo menu/reload também preserva a entrada. Os poderes já aprendidos não são esquecidos durante a importação do visitante.
- Carregamento acompanha recursos reais. Apoios nas demais fases passaram em saltos físicos, inclusive as caixas do posto e pedras próximas.

## Capturas reais do motor

| Tamanho | Progresso conciliado | Carregamento |
|---|---|---|
| 1920×1080 | [Ver](1920x1080/progresso_conciliado.jpg) | [Ver](1920x1080/carregamento_real.jpg) |
| 844×390, perfil iPhone | [Ver](844x390/progresso_conciliado.jpg) | [Ver](844x390/carregamento_real.jpg) |
| 640×360 | [Ver](640x360/progresso_conciliado.jpg) | [Ver](640x360/carregamento_real.jpg) |

Apoios: [fase 4](844x390/apoio_fase_04.jpg), [fase 6](844x390/apoio_fase_06.jpg), [fase 8](844x390/apoio_fase_08.jpg), [fase 9](844x390/apoio_fase_09.jpg).

A captura do aviso usa login/RPC simulados, declarados em `tests/story_continuity/capture.gd`. As telas são reais. O carregamento lê os arquivos reais da fase. Os apoios usam aproximação por fixture e saltos/aterrissagens reais. Não são capturas de aparelho físico nem aprovação estética automática.

## Testes

- `account_merge.gd`: 19 verificações, incluindo ambos os sentidos de conflito, offline/retry, resposta atrasada, isolamento, tutoriais e descarte do aviso.
- `transitions.gd`: passagens reais 1→2, 3→4 e 5→6, com os cinco tipos de recargas; persistência ao fechar/reabrir a cena, zero preservado e poder novo sem carga inventada.
- `platforms.gd`: 30 verificações nas dez fases, subida sem prender a cabeça, aterrissagem e limpeza.
- Regressão de apoios existente: 135 verificações. Progresso local legado: 30.
- Percursos físicos completos das dez fases: todos passaram, sem mortes do piloto de teste. Ver `routes/`.
- Login T18, persistência, sessão/música, primeiras lições, lança e contexto regional: todos passaram. Ver `related/`.
- WebAssembly/WebGL2 real em Chromium, 844×390, DPR 3, UA de iPhone: conflito nos dois sentidos, troca de conta, capa real, passagem 1→2 com 2 ataques/3 defesas e recuperação após reload. Sem erros JavaScript/Godot ou chamadas externas. As RPCs desse navegador são simuladas; o SQL real foi validado separadamente no GAME. Ver `web/report.json`.
- SQL no GAME: migration registrada, RLS ativo, RPC somente autenticada, sem SELECT/UPDATE direto. Testes de merge, isolamento e autorização finalizaram em ROLLBACK. A requisição HTTP anônima foi recusada, sem criar dados. Ver `backend/`.
- `check_design.py`, sintaxe do probe e `git diff --check`: passaram.

## Smoke geral e limites

A execução inicial do smoke encontrou nove verificações legadas de transição que esperavam somente `PhaseStory` e pelo menos dois cartões. O fluxo atual apresenta a história na capa; as fases 2–10 têm um cartão. O teste passou a acionar a história realmente exibida e comparar **todo o conteúdo** com o catálogo, mantendo a verificação de substituição real da fase. As nove transições passaram na reexecução, em `transition-smoke/`.

Restam duas falhas gerais também reproduzidas na versão anterior `0d0cb90`: `functional` (`actual_malagueta_model`) e `battle_presentation` (8 verificações). Elas não foram apagadas nem relaxadas. Logs das duas versões em `smoke/`; portanto, o smoke geral não está inteiramente verde. A navegação final pelos onze menus passou.

O motor nativo usa llvmpipe e o Chromium usa SwiftShader. Não se trata de medição de FPS em GPU real, de Safari/iPhone físico ou de uma autenticação Google/Discord real refeita nesta rodada. Modelos, arte aprovada, áudio, providers de login e economia foram preservados.

O GAME já recebeu a mudança aditiva de backend. A publicação do cliente é acompanhada pelo PR desta branch; estas evidências não afirmam que o Pages já foi atualizado.
