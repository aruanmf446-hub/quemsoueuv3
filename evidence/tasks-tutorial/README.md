# Tasks obrigatórias, botão contextual e primeiro uso

Branch de revisão `codex/tasks-obrigatorias-tutorial`, baseada na main aprovada `51d2f18`. **Esta rodada ainda não foi publicada na main.**

## Para o jogador

- El Fuego foi baixado visualmente em 0,06 unidade (aproximadamente 6cm). Não alteramos cápsula, piso físico, velocidade nem força do salto. As casas continuam com o próprio teto como superfície jogável.
- As 19 Tasks passam a ser necessárias: portões de 5,2m bloqueiam o pulo duplo, e as pontes/plataformas cobrem vãos reais de pelo menos 18m. Piso, recargas, inimigos e decoração de primeiro plano foram retirados do vão; não há plataforma escondida permitindo atravessar. Os checkpoints foram preservados.
- TASK é um botão contextual acima do ataque, com a ação escrita acima dele. Aparece ao se aproximar, some ao sair de perto ou concluir. Defesa fica acima do pulo para que os controles não se sobreponham. Teclado F continua funcionando.
- Fase 1 começa com ataque 0 e defesa 0, inclusive ao reiniciar. Outras fases preservam 1/1 inicial. Capacidades e recargas mantidas.
- Ao entrar na fase 1 pela primeira vez, o jogo pausa e explica ataque e recargas. A primeira recarga de defesa pausa e explica o escudo. A primeira Task pausa e explica o botão e a ação disponível. “Entendi · Continuar” retoma o jogo e limpa comandos retidos.
- As três lições são salvas uma vez por perfil no dispositivo, com confirmação apenas ao continuar. Web usa também localStorage para persistir imediatamente após F5. As outras fases não repetem essas explicações. Flags ficam em cache; não lemos arquivo/localStorage a cada quadro.

## Capturas reais

Godot 4.7.2 Compatibility, Mesa/llvmpipe: quatro capturas por perfil em `iphone/` (844×390), `desktop/` (1672×941) e `640/` (640×360). JPGs convertidos dos PNGs sem recorte. Fixtures aproximam o ator de recarga/Task; a coleta e a pausa são reais.

- [Primeiro ataque, recursos zerados](iphone/primeiro_ataque.jpg).
- [Primeira defesa](iphone/primeira_defesa.jpg).
- [Explicação da primeira Task](iphone/primeira_task.jpg).
- [Botão acima do ataque](iphone/botao_task_acima_ataque.jpg).
- [Posição visual mais baixa no teto](pes_no_teto/casa_00.jpg).
- Capturas do WebAssembly real em Chromium emulado como iPhone: `web/`.

## Validação

- `first_use_tutorial_test.gd`: **21/21**. Início 0/0, três pausas reais, relógio e ator parados, botão Continuar responsivo, limpeza de comandos, persistência ao reabrir, custo zero da Task e ausência de repetição em outras fases.
- `task_barriers_test.gd`: **26/26**. Vãos sem piso excedem o alcance do salto. Tentativas físicas com pulo duplo e corrida não ultrapassam portão/vão fechados.
- `scenario_tasks_test.gd`: **177/177**. As 19 Tasks continuam acessíveis, concluem sem recursos e permitem ida/volta depois de abrir.
- `parkour_revision_test.gd`: **52/52**; `skyline_roofs_test.gd`: **75/75**.
- `reino10`, checkpoints e **dez percursos completos: PASS**, sem mortes. Relatórios e logs em `routes/`. O autopiloto agora pousa e interage na margem, em vez de tentar pular o bloqueio obrigatório. Usa entradas reais, sem teleporte ou invulnerabilidade nos percursos.
- Regressões de jogador experiente usam `tutorial_fixture.gd` para marcar as lições como lidas somente no user:// isolado dos testes. Os novos testes de primeiro uso não fazem isso. Verificações de inventário foram atualizadas para o novo 0/0 apenas na fase 1; as condições de vitória/morte e controles foram mantidas.
- Web: **PASS**, Chromium 844×390, DPR 3, toque. Três lições, três pausas, botão TASK acima do ataque e persistência de todas as lições após recarregar a página; inclusive com o arquivo de flags removido pela fixture para verificar o fallback no localStorage. Sem erros JavaScript/Godot ou acessos externos. O primeiro ensaio revelou que a fixture antiga zerava cargas ao aproximar da Task; a fixture de tutorial agora preserva os recursos e o teste passou.
- `check_design.py`, `scope_test.py --base 51d2f18`, `git diff --check`: PASS.

## Limites

Sem teste em iPhone físico, Safari real ou APK, nem promessa de FPS móvel baseada em renderização de software. Alguns testes nativos preservam avisos de recursos de áudio ativos ao encerrar; não há erro de script. O smoke geral legado não foi declarado corrigido nesta rodada.

Sem mudanças de Supabase, autenticação, economia, músicas, modelos, lobby ou skins. Nenhum asset externo novo. Interface usa PlayerUI e a regra existente de UIScale para iPhone.
