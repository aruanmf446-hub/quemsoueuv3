# História de El Fuego e carga das fases

A origem da fase01 usa os oito quadros e as oito falas do roteiro do dono do
projeto, na ordem: minas de Pimento, diamante laranja, sacrifício dos pais,
superfície, homem misterioso, Guanita e Flora, justiceiro e perseguição.
As legendas permanecem em controles Godot, com quebra de linha e navegação
manual. A imagem é um atlas sem textos; `assets/story/ART_PROVENANCE.md` documenta
a referência visual. As capas das fases01..09 correspondem às nove rotas do ZIP,
com os nomes atuais e briefings compatíveis com a geografia da campanha.

O jogador escolhe o tempo de leitura. Próximo avança; Começar fase encerra o
último quadro; Pular história dispensa a sequência. Esc cancela a entrada sem
registrar uma leitura incompleta. Ao concluir ou pular explicitamente, a
preferência de não repetir fica em `user://desert_story_read_v3.cfg`, separada
do progresso e das recompensas. No Web há backup localStorage exclusivo da
origem, com conversão via `UIScale.js_true`. O botão Rever história reabre os
oito quadros, e fases seguintes liberadas oferecem Rever cena na própria capa.
Nada é gravado no Supabase.

A história aparece antes de preparar a fase, em vez de esperar toda a carga para
começar. CampaignLoading mantém a leitura manual aberta enquanto lê modelos e
animações. No nativo, recursos importados sem scripts usam carregamento em
worker; no Web sem threads, uma leitura por quadro permite desenhar e processar
entrada entre recursos. PackedScene com scripts continua na thread principal,
pois o projeto contém preloads que o Godot4.7.2 não resolve no worker. Isso não
elimina o custo final de instanciar a fase, montar o mundo e compilar shaders.
O carregamento pronto não interrompe uma história em andamento. Se a pessoa
terminar antes, a capa permanece até os recursos estarem prontos. Histórias já
lidas mostram apenas a capa de carga e abrem assim que os recursos terminam,
sem temporizador mínimo ou percentual inventado.

No iPhone, ações e setas têm alvos de88unidades (cerca de46px no canvas Web
720×353). A seta Voltar fica acima da legenda; os demais aparelhos mantêm64.
`story_touch_layout.gd` passou15 verificações nas áreas750×353,712×338 e667×359
e5 verificações no padrão640×360, sem sobrepor fala longa ou recortar ações.

As APIs CampaignLoading.begin e PhaseStory.begin foram preservadas para o fluxo
de próxima fase existente. A cena e os dados de gameplay da fase10 permanecem
intactos. Falha de leitura mantém Tentar novamente e Voltar.

## Validação nativa

`tests/presentation/story_v3.gd` exige QSE_TEST_STORY=1 e um user:// isolado.
Executado no Godot4.7.2 em1920×1080,844×390 com--iphone e640×360:
67 verificações por perfil, zero falhas. Cada execução captura os oito quadros
mais a leitura com a fase pronta; verifica a altura das legendas, posição dos
botões, navegação manual, cancelamento sem marcar leitura, pulo, persistência,
revisita automática, replay e aquecimento dos recursos durante a leitura.

Exemplo (substituir GODOT e ajustar DISPLAY):

```bash
QSE_TEST_STORY=1 DISPLAY=:104 XDG_DATA_HOME=/tmp/story-v3-user \
  GODOT --path . --audio-driver Dummy --script res://tests/presentation/story_v3.gd \
  -- /tmp/story-v3 844x390 --iphone
```

Capturas nativas em `evidence/story-v3/`: JPEG codificado das capturas reais sem
recorte nem montagem. Elas não validam navegador ou aparelho físico. Navegação
integrada usa `tests/desert_night/navigation.gd`; flow.gd acompanha o novo fluxo
de história durante a carga. Navegação integrada passou20 verificações em cada
perfil (desktop e mobile). `story_lifecycle.gd` passou4 verificações, incluindo
Esc durante um worker ativo sem deixar referências pendentes. `failure.gd`
passou com zero falhas; seus erros de recurso inexistente são intencionais. A revisão de layout inclui o script
`tools/player_ui/check_design.py`.

Após a correção do timer, os três perfis foram executados novamente:67/0cada.
O teste confirma que o timer anterior da abertura foi interrompido antes da
leitura manual e permanece parado durante os quadros. `flow.gd` foi alinhado
ao boot atual (login primeiro) e passou10 verificações de login/visitante,
acesso ao hero e entrada na fase com leitura durante a carga; não consulta
as ofertas de Novidades, que hoje têm sua própria central e suíte.

O shell PWA oculta o convite de instalação durante a intro e a fase.
O carregador transfere esse estado ao controlador da fase; cancelamento restaura
o convite. O fluxo Web verificado em Chromium com perfil iPhone está em
`evidence/reino-v3/web_final/`; os29 testes PWA incluem ocultação e restauração.
