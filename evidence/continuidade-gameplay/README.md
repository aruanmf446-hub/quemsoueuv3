# Continuidade e variedade da campanha

**Atualização posterior:** o dono reprovou o uso de personagens jogáveis como cidadãos
do fundo. Essa parte das capturas é histórica. Não regenerar esses figurantes pelos
modelos dos heróis; seguir [a direção atual](../../docs/desert/NPCS_CIDADAOS.md).

Base: `66b2ea4`. Motor: Godot 4.7.2, Compatibility. Fases 01–09.

## O que muda para jogar

- Sair e voltar conserva o último ponto seguro, checkpoint, vidas, as cinco cargas,
  itens recolhidos, inimigos vencidos e Tasks completas ou feitas pela metade.
- A conta recebe essa partida. Diferenças entre visitante, conta e outro aparelho
  são resolvidas automaticamente, sem perguntar qual progresso substituir.
  Cargas não são somadas. Uma resposta antiga não recria recursos gastos nem
  apaga a partida preparada para a fase seguinte.
- O escudo protege pela frente. Um golpe pelas costas causa dano e encerra a defesa.
- A saída exige as Tasks obrigatórias da fase; chegar ao fim não as contorna.
- As nove fases possuem perfis diferentes de alturas, intervalos e conjuntos de
  obstáculos apoiados. Existem degraus de rua, telhados, balcões, troncos, colunas
  caídas e cargas. As duas primeiras intervenções de cada região usam pontos de
  operação separados, com ações próprias do cenário; o primeiro portão continua
  simples para apresentar o comando. O botão contextual continua sendo TASK.

Morte e recomeço mantêm as penalidades já aprovadas. A fase 10 conserva sua arena,
Malagueta e seus recursos. Nenhuma recompensa econômica é concedida pelo salvamento.

## Ajustes adicionais pedidos pelo dono

- O horizonte distante permanece estável ao voltar; as camadas próximas e os NPCs
  continuam pertencendo ao mundo. Não há paralaxe horizontal de palácios/muralhas.
- J ataca, K defende, Shift permanece alternativa. K foi removido do ataque herdado
  do protótipo; a indicação de defesa e a primeira explicação foram atualizadas.
- O segundo salto emite areia macia a partir dos ossos dos pés, sem consumir habilidade.
- Marcos de checkpoint maiores mostram CHECKPOINT e o número; após ativação, SALVO.
  O aviso foi encurtado, e os registros anteriores não são apagados.
- Sobre uma lona, os soldados do chão patrulham lateralmente. A perseguição fica
  suspensa enquanto o jogador está nesse apoio; o modelo não gira para o fundo.
- Lanceiros: fase 1: 3; fase 4: 2; fase 5: 2; fase 6: 3; fase 7: 2;
  fase 8: 4; fase 9: 3. Fases 2/3 permanecem sem lanceiros. As estações cobrem
  começo, meio e fim e conservam a regra de perseguir só após acertar corpo/escudo.
- Civis e guardas decorativos usam sprites renderizados dos modelos oficiais,
  sem corpo de física, dano ou skeleton adicional. Saem junto com os trechos.
- Socos, dano, defesa e passos usam um banco PCM preparado de efeitos CC0 da Kenney.
  Areia/vento foram preparados antes do jogo. Volume, variações e prioridade evitam
  sons repetidos idênticos e impedem um passo de cortar uma defesa. Não há síntese
  por clique nem alteração da música do menu.

Capturas desses pontos: `feedback/`. Fontes e licença dos sons:
`assets/audio/desert_sfx/`; origem das pessoas: `assets/desert/city_people/`.

## Causa das pendências corrigidas

O salvamento anterior guardava o maior número de fases concluídas e o inventário
na entrada da próxima fase, sem a partida corrente. O caminho antigo de checkpoints
usava um contrato de dois pontos, enquanto o mapa possui sete. O novo registro é
separado dos contratos assinados de recompensas, possui revisão e é isolado por conta.

A defesa verificava apenas o estado de escudo, sem a direção do golpe. A saída não
verificava as Tasks. O relevo e os obstáculos reutilizavam o mesmo padrão entre regiões.

## Arquivos principais

- `scripts/desert/t15d/campaign_run.gd`: registro local e cópia Web, conflitos e migração.
- `scripts/services/story_progress_service.gd`: envio e recuperação por conta.
- `scripts/desert/t15d/phase.gd`: retomada, checkpoints, itens, Tasks e saída.
- `scripts/desert/t15d/player.gd` e `cactus_spear.gd`: direção da defesa e da lança.
- `scripts/desert/t15d/campaign_layout.gd` e `earth_bridge.gd`: percursos e mecanismos.
- `first_use_tutorial.gd` e `scripts/ui/screens/story_screen.gd`: apresentações já vistas
  e botão CONTINUAR PARTIDA, sem redesenhar o menu.
- `supabase/game/migrations/20261107150000_story_run_resume.sql`: registro privado e RPC.

A migração foi aplicada ao projeto GAME correspondente à configuração do jogo.
Auditoria executada em transação com rollback: inventário exato, sete checkpoints,
conflitos, carga gasta, isolamento entre contas e recusa de anônimos. Nenhuma partida
real foi alterada pela auditoria. Ver `backend-audit.json` e `backend-anonymous.json`.
Autenticação, economia, catálogo, música e seus contratos não foram alterados.

## Capturas reais

- `mobile/`: nove fases, três pontos por fase, 844×390 no Godot com a exceção iPhone.
- `parkour/`: apoio nos novos obstáculos e as duas etapas de uma Task.
- `web-844/`: Chromium WebGL, iPhone emulado, DPR 3; teclado real, areia e reabertura.
- `web-640/` e `web-desktop/`: versão final em 640×360/DPR 3 e 1672×941.
- `web-nine/`: conferência Web das nove composições, antes da rodada adicional de NPCs.
- Antes: [revisão anterior](../campanha-revisao-09/). As capturas de cenário
  usam as mesmas posições e enquadramento do roteiro anterior.

As fixtures de captura posicionam atores explicitamente; não são provas de percurso.
Os percursos completos usam comandos reais e física de 60 Hz, sem teletransporte.

## Conferência

`validation.json` reúne os resultados finais, incluindo as nove travessias completas com os novos lanceiros,
colisões sólidas, lonas, Tasks nas duas margens, retorno ao checkpoint, recursos,
conflitos e navegação. `run-resume.log` e `run-cloud.log` detalham a continuidade.

O smoke completo teve 29 de 31 etapas aprovadas. As duas falhas restantes foram
reproduzidas na base intocada: `actual_malagueta_model` em `functional` e oito
verificações de `battle_presentation`. Não foram removidas nem tratadas como aprovação;
ver `smoke-results.json` e `baseline-comparison.json`. As fixtures com áudio agora encerram as cenas e aguardam 90 ms de tempo real para
o mixer Dummy liberar seus buffers; `--fixed-fps` acelera a física, não o mixer.
Esse cuidado fica apenas nos roteiros, sem espera adicional na navegação do jogo.
Não se afirma ausência geral de vazamentos a partir desses casos.

Chromium usa SwiftShader. As contas do navegador são simuladas; o contrato real GAME
foi conferido separadamente por SQL e privilégios. Não houve validação em Safari,
aparelho físico ou duas contas autenticadas reais no navegador, nem medição de FPS
em GPU física.

Reprodução local:

```sh
LP_NUM_THREADS=2 python3 tests/desert_night/run.py --godot /caminho/Godot4.7.2 \
  --only run-resume run-cloud account-merge story-transitions story-platforms \
  parkour-revision solid-obstacles spears spear-intro checkpoints \
  route-01 route-02 route-03 route-04 route-05 route-06 route-07 route-08 route-09 \
  --orders 1 2 3 4 5 6 7 8 9
python3 tools/player_ui/check_design.py
python3 tests/desert_night/scope_test.py --base 66b2ea4 --story-continuity
```

`--story-continuity` libera somente o serviço e a migração explicitamente autorizados
nesta tarefa; os demais caminhos protegidos continuam sendo verificados.

Assets de obstáculos: reaproveitados do projeto (`obstacle_art.gd`, `task_art.gd`
e módulos existentes). Figurantes: quatro texturas renderizadas no Godot a partir
de Lana, Rodrigo, Michelly e Cacto existentes, sem criar novos modelos/personagens.
Sons: 23 WAV preparados, licença CC0 e hashes em `assets/audio/desert_sfx/sources.json`.
O mirror foi comparado byte a byte com o ZIP oficial. As camadas de vento são originais.
