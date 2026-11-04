# Quem Sou Eu V3 — passagem de trabalho

## Estado em 2026-11-04

**Trabalho incompleto, entregue para outra IA continuar. Não fazer merge/publicação sem terminar a validação final.**

Branch: `work/reino-deserto-v3`. Base: `b10be149ba2d332a44cc1dcbb4c1ebe9aaaff3d6` (main já publicada anteriormente, incluindo heroPR97). Commits iniciais: `0ee699d` (fases/poderes) e `28d9a4d` (intro). O commit de handoff reúne refinamentos e provas restantes.

O usuário confirmou escopo **tudo** do pacote e depois pediu, em paralelo, intro/roteiro/legendas/carregamento durante leitura. Sua última instrução foi colocar tudo na PR e deixar pendências neste README para continuação. **Não confundir a publicação anterior do hero com a reforma atual; esta branch ainda não foi integrada à main.**

## Implementado

- Nove fases,nomes/distritos do pacote,três camadas ilustrativas por fase e arquitetura próxima específica. Mantida câmera lateral ortográfica,personagens/modelos/FBX/animações originais. Fase10 e seu controlador original preservados.
- Tropas persistentes fora dos chunks,pool de oito Cactus,ondas atrás da câmera,salto baixo com aterrissagem validada,parada em abismos/muros.
- Capacidade3 para fogo,defesa e novos poderes. Ruptura física de peça marcada de3m atrás do jogador,restauração8s/reset,proteção de itens/checkpoints/personagens; Âmbar3,5s; Relâmpago7,4m/s por1,15s,colisão e cancelamento. Descobertas locais persistentes,garantidas nos capítulos2/4/6; recargas separadas sem sobreposição. Limite mínimo180s recalculado com margem para balsas.
- HUD limpo,ações circulares nativas no desktop,joystick/círculos no toque. Poder desconhecido não deixa moldura. Estilos centralizados em PlayerUI. Último ajuste evita que foco de clique no HUD roube o pulo por Espaço.
- Intro com8cenas e roteiro exato solicitado,atlas ilustrado,legendas nativas,capas próprias9fases,Rever história/Rever cena. Leitura/skip persistidos localmente,sem repetição automática. Recursos aquecem durante leitura; Web sem threads lê um recurso por quadro. Corrigido timer herdado que avançava quadro sozinho.

Detalhes: [ReinoV3](docs/desert/REINO_V3.md),[Intro](docs/presentation/STORY_V3.md),[provasdasfases](evidence/reino-v3/README.md),[provasdaintro](evidence/story-v3/README.md).

## Validação já executada — limites importantes

- Godot **4.7.2.stable.official.ed1daf0bf** real. Mecânicas:73/73; última guarda iPhone:504verificações,0falhas;108capturas de todos os modelos geradas.
- Intro:67verificações em cada perfil(desktop,iPhone844×390,640×360),todas0falhas;20de geometria; navegação20+20; cancelamento4; fluxo10. Ver logs e contagens em evidence/story-v3.
- Nove travessias completas sem morte/respawn passaram, **antes** do último refinamento da distribuição de itens/partição do chão e controles. Não declarar validadas no commit final sem repetir.
- WebAssembly de staging passou8quadros por toque,leitura sem timer,dash e reload sem repetir. **Anterior** aos últimos refinamentos. A nova asserção de persistência das habilidades no reload ainda não foi rodada.
- PWA28/28 e designchecker passaram. Regressões de layout,legado10,progresso,variedade,parkour,checkpoints,mouse/toque passaram em rodadas anteriores; repetir as pertinentes ao estado final.
- O novo `tests/desert_night/action_controls.gd` testa mouse,Enter e Espaço. A primeira versão do teste usava push_input para teclado,que não atualiza Input global; foi corrigida para parse_input_event. **Última execução:5verificações,0falhas**, incluindo clique,Enter e pulo após clique.
- Nenhum teste representa aparelho físico ou Safari real. Os fundos do ZIP são artes provisórias; a galeria desktop antiga não representa o último HUD.

## Pendências para a próxima IA

1. Preservar a regressão de `action_controls.gd` (5/5aprovada); repeti-la se houver novos ajustes no HUD/foco.
2. Reexecutar73testes de mecânica e toda a campanha01–09 sobre o estado final,incluindo progressão/retorno/checkpoints e fase10. Integrar os testes novos ao runner se conveniente.
3. Gerar galeria **final** de todas as fases em desktop1672×941,iPhone844×390 e padrão640×360. `reino_v3_gallery.gd` já gera spawn+meio da fase por fixture explicitamente teleportada. Inspecionar arte/personagens,controles circulares,legibilidade e enquadramento. Não apresentar fotos antigas como finais.
4. Fazer export Web final e executar `web_desert_probe.cjs` incluindo a nova asserção de habilidades descobertas após reload. Avaliar necessidade de backup localStorage dos desbloqueios se IndexedDB não sincronizar imediatamente; não há prova dessa falha ainda. Validar safe area e botões sem cortes.
5. Rodar regressões de duelo/batalha pertinentes (`tests/duel_local/flow_test.gd`,`tests/battle_reveal/flow.gd`) e captura obrigatória de batalha iPhone. Não foram repetidas nesta entrega após os últimos ajustes.
6. Inspecionar/otimizar picos de processamento. `route.gd` mantém máximos e p95,mede quadros separadamente do intervalo físico do hit-stop; aprovação de p95 não prova ausência de engasgos.
7. Atualizar resultados/evidências e descrição da PR,concluir a revisão,então seguir a autorização de publicação do dono somente após fechar pendências. Confirmar sucesso de deploy-web.yml e pedir para fechar/reabrir o PWA.

## GitHub / PR

Branch publicada. A sessão permite Git mas **api.github.com está fora da allowlist de rede**; tanto GraphQL(`gh pr`) quanto REST retornaram Forbidden. Não foi possível abrir PR por essa API. Link de criação: https://github.com/aruanmf446-hub/quemsoueuv3/pull/new/work/reino-deserto-v3 . Não afirmar que existe PR numerada sem confirmar.

## Ambiente para continuar

- Repositório local `/workspace/quemsoueuv3`.
- Godot correto: `/workspace/.tools/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64`; o binário global pode ser4.6.3.
- `XDG_DATA_HOME=/workspace/.runtime/data` contém templates4.7.2(Web sem threads). Para testes,use perfis XDG separados. `LP_NUM_THREADS=2` ajuda no renderer software.
- Xvfb local: `/workspace/.tools/x11/usr/bin`; display:104 foi iniciado. Wrapper `/workspace/setup/iphone-capture-godot` adiciona áudioDummy e30FPS.
- Imports/exports CLI: acrescente `-- --godot-mcp-no-bridge` para não abrir ponte do editor. Não editar .tscn à mão nem .godot.
- Staging de Web usado: `/workspace/.runtime/iphone-web-fixture`,marcado `.iphone_web_fixture_stage`,main de teste efeature iphone_layout_fixture. NUNCA publicar esse staging como jogo. Copiar mudanças desde a base b10, não apenas diff do HEAD, pois há commits locais novos.
- Staging teve seu `tests/iphone/web_fixture.gd` substituído **somente na cópia** por `tests/desert_night/web_desert_fixture.gd`; cena gerada por `make_web_fixture.gd` via ResourceSaver. Output `/workspace/.runtime/desert-v3-web/quemsoueuv3`,servidor8135. Fixtures ficam excluídas do export de produção.
- Logs brutos e capturas adicionais em `/workspace/.runtime/desert-v3-*`; essenciais já copiados para evidence.

## Regras persistentes do dono

**Sem Supabase,banco,credenciais,Edge Functions ou migrations.** Não houve alteração/publicação desses sistemas. Se surgir dependência de backend,descrever para o ChatGPT.

Ler AGENTS.md,docs/layout/README_IPHONE.md,docs/referencias/README.md. Estilo só PlayerUI. Exceção de escala/layout só iPhone; demais1672×941,sem compact/densidade. Preservar login,sessão,música,navegação,convites e modos existentes. Não substituir modelos/skins/FBX. Não declarar validação física a partir de captura do motor.
