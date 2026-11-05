# Revisão de parkour e apoio dos telhados

Branch: `codex/parkour-telhados`, continuação da revisão de muralhas/palácios. **Não publicada na produção.** A versão aprovada anterior continua na main, `129f031`.

## Mudanças para o jogador

- Postes de aviso apoiados na borda real: antes estavam em z=-3,8, fora do piso de 4m; agora estão em z=-1,72, dentro da superfície física.
- Fase 2: cobertura ligada diretamente à fachada, sem faixa vazia entre teto e laje jogável. Patamares de alvenaria integram os prédios.
- Fases 1–9: sequências de subida, patamar e descida com diferença total de 2,75m; transições entre módulos de no máximo 0,55m. Oito conjuntos de cinco patamares por fase oferecem saltos e aterrissagens. Nos tetos curtos, há área livre para aterrissar antes do próximo vão.
- Duas pontes frágeis por fase, próximas de 30% e 70% do percurso: aviso ao se aproximar, 0,85s entre pisar e cair, perda real da colisão e recomposição 2,5s depois. Os vãos continuam saltáveis quando a ponte está caída.
- **Uma tarefa de cenário**, na fase 4: “Montar ponte”. Botão de toque ou F aparece perto dessa passagem e desaparece após a conclusão. A peça de terra gira até virar piso, usando a textura já utilizada pela defesa. Não usa Defesa, não consome carga, não adiciona poder ou botão permanente. A montagem segura o personagem por 0,8s para evitar correr no vazio antes da conclusão.
- A ponte construída permanece ao descarregar/recarregar o trecho. Reiniciar limpa o estado; voltar ao checkpoint permite refazer a tarefa caso necessário, sem depender de recursos consumíveis.

Os módulos, composições, dunas, muralhas e palácios aprovados foram mantidos. Não houve novos assets externos, mudanças em movimentação, força de salto, personagens, combate, progressão de habilidades ou na fase 10. Sem acesso a Supabase, autenticação, economia ou música.

## Capturas reais

Godot 4.7.2, Compatibility, Mesa/llvmpipe. São inspeções com posicionamento por fixture; não são prova de percurso. JPGs convertidos dos PNGs, sem recorte.

- [Postes apoiados — fase 1](iphone/fase_01_borda.jpg).
- [Teto e fachada unidos — fase 2](iphone/fase_02_borda.jpg).
- [Patamares de alvenaria](iphone/fase_02_patamares.jpg).
- [Descida entre telhados](iphone/telhado_descida.jpg).
- [Ponte frágil caindo](iphone/ponte_fragil_caindo.jpg).
- [Tarefa contextual](iphone/tarefa_ponte_botao.jpg).
- [Ponte montada](iphone/tarefa_ponte_03.jpg).

16 capturas em cada perfil: desktop 1672×941, iPhone emulado 844×390 e layout padrão 640×360. `steps-captures.json` substitui as três entradas de patamares do manifesto original, após o refinamento de alvenaria e enquadramento.

## Validação

- `parkour_revision_test.gd`: **52/52**. Alturas, patamares, pontes frágeis e tarefa única; montagem sem cargas; avanço segurado durante montagem; piso físico; ida/volta; unload/reload sem duplicação; queda e recomposição; limpeza ao sair.
- `skyline_roofs_test.gd`: **74/74**, preservação do fundo e vãos reais.
- `reino10`, `layout`, `checkpoints`: **PASS**.
- Percursos completos por entradas reais das fases **1–9: PASS**, zero mortes, sete checkpoints e saída alcançada; duração física de 247,2 a 254,7s. Sem teleporte ou invulnerabilidade no percurso. A primeira tentativa da fase 2 revelou aterrissagem curta depois dos patamares; o espaço foi corrigido e o teste completo repetido com sucesso. `results.json` agrega os resultados finais; logs e JSONs por fase preservados.
- `check_design.py`, `scope_test.py`, `git diff --check`: **PASS**.
- Web: ver `web/report.json` e `web/probe.log`. Chromium, 844×390, DPR 3, toque real da emulação, WebAssembly exportado. Fixture aproxima o jogador da tarefa; toque no botão, avanço segurado durante montagem e caminhada nos dois sentidos usam entradas reais, com zero cargas de ataque/defesa. Navegação externa bloqueada.

## Limitações

- Não testado em iPhone físico, Safari real ou APK. GPU de software não mede desempenho no aparelho. Os tempos de quadros headless nos logs são diagnóstico técnico, não aprovação estética ou promessa de FPS Web.
- Alguns testes encerram com avisos ObjectDB. O diagnóstico `--verbose` do teste focado identifica AudioStreamWAV/AudioStreamPlaybackWAV ainda ativos no encerramento; os grupos de pontes e tarefas ficam vazios após sair. Esses avisos estão preservados nos logs, sem mudança no sistema de áudio.
- O smoke geral da main já tinha falhas em `transition_01`–`transition_09` e `functional`, documentadas em `../muralhas-telhados/README.md`; esta rodada não declara essa suíte corrigida nem remove verificações.

## Reproduzir

`python3 tests/desert_night/run.py --godot <Godot4.7.2> --only reino10 layout checkpoints route-01 route-02 route-03 route-04 route-05 route-06 route-07 route-08 route-09`

`<Godot4.7.2> --headless --fixed-fps 60 --path . --script tests/desert_night/parkour_revision_test.gd`

`DISPLAY=:104 <Godot4.7.2> --audio-driver Dummy --max-fps 30 --path . --script tests/desert_night/parkour_revision_gallery.gd -- /tmp/gallery 1672x941`

Para Web, exportar um staging isolado com `tests/desert_night/web_fixture.tscn` como cena principal, servir em `http://127.0.0.1:8135/quemsoueuv3/` e executar `node tests/desert_night/web_parkour_probe.cjs`. Não exportar essa fixture como jogo de produção.
