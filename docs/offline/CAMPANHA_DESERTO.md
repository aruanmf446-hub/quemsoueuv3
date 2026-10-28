# Dez fases do Reino do Deserto — planejamento offline

Proposta editorial e de configuração; os arquivos em `data/planning/desert/` não são carregados pelo jogo. A cena, o layout, a física, a câmera e o combate existentes da fase 1 foram preservados.

El Fuego protagoniza as dez fases. Cactus é a tropa inimiga. Malagueta aparece como chefe final da fase 10. Dificuldade e obstáculos são intenções de design, ainda sem playtest, novas coordenadas ou alterações de balanceamento.

| Ordem | ID estável | Nome | Dificuldade planejada |
| --- | --- | --- | --- |
| 1 | `desert_phase_01` | Entrada do Deserto | introdutória |
| 2 | `desert_phase_02` | Dunas Perdidas | fácil |
| 3 | `desert_phase_03` | Oásis da Meia-Noite | fácil a moderada |
| 4 | `desert_phase_04` | Ruínas Esquecidas | moderada |
| 5 | `desert_phase_05` | Pontes do Abismo | moderada |
| 6 | `desert_phase_06` | Tempestade de Areia | moderada a alta |
| 7 | `desert_phase_07` | Fortaleza dos Cactus | alta |
| 8 | `desert_phase_08` | Cavernas de Cristal | alta |
| 9 | `desert_phase_09` | Laboratório Proibido | muito alta |
| 10 | `desert_phase_10` | Confronto com Malagueta | clímax |

## Regra de campanha

Fases sequenciais; cada fase exige a conclusão da anterior. Checkpoints representam retomada dentro de uma tentativa e não concluem fases. As fases 1–9 registram progresso e liberam acesso à próxima fase. Só a fase 10, com Malagueta derrotado e o encerramento validado, completa a campanha, concede `desert_campaign_completed` e desbloqueia `el_fuego` no lobby. A conquista requer as dez conclusões verificadas.

Os recursos e dependências têm IDs próprios nos registros `resource_requirements.json` e `implementation_dependencies.json`. Estados `missing` e `not_implemented` são pendências explícitas, sem caminhos inventados para arquivos inexistentes.

## 1. Entrada do Deserto

Configuração: [phase_01.json](../../data/planning/desert/phase_01.json). ID: `desert_phase_01`.

El Fuego cruza os marcos de entrada e descobre patrulhas Cactus bloqueando a rota para o interior.

**Ambientação:** Borda rochosa do reino, caminhos abertos e sinalização de orientação.
**Dificuldade:** introdutória (posição 1/10; sem balanceamento validado).
**Obstáculos planejados:** `small_gaps`, `low_ledges`, `double_jump_teaching`.
**Inimigos:** tropas Cactus; posicionamento e quantidades ainda não definidos.

**Checkpoints planejados:**

- `desert_phase_01_checkpoint_01`: Depois do primeiro conjunto de saltos.
- `desert_phase_01_checkpoint_02`: Antes da patrulha que guarda a saída.

**Condição de conclusão:** alcançar a saída planejada; registrar a conclusão validada, sem conceder a conquista de campanha.

**Recompensas futuras:** registro de conclusão da fase e acesso à próxima fase. Não foram definidos valores econômicos.

**Recursos necessários:**

- `el_fuego_model`: Malha-base e oito FBXs de El Fuego.
- `cactus_model`: Tropa Cactus, malha-base e animações.
- `checkpoint_presentation`: Marcador visual/sonoro de checkpoint.
- `desert_audio`: Ambientes, ações, música e créditos/licenças.
- `desert_story_text`: Textos revisados e localizáveis da campanha.
- `desert_entrance`: Entrada, rochas e sinalização do Deserto.

**Dependências de implementação:**

- `campaign_navigation`: Navegação do menu para campanha e seleção de fase.
- `level_builder`: Instanciação futura do planejamento sem substituir o layout da fase 1.
- `checkpoint_system`: Registro e restauração de checkpoints por tentativa.
- `phase_progression`: Pré-requisitos e conclusão das dez fases.
- `cactus_reuse`: Reutilizar o Cactus atual; balanceamento futuro separado.
- `asset_import_validation`: Verificar importação, materiais, trilhas e sockets no Godot.
- `playtest_and_accessibility`: Percurso, câmera, dificuldade e controles em dispositivos-alvo.

**Situação da versão jogável:** existe um protótipo separado em `data/desert/phase_01.json` e `scenes/desert/phase_01.tscn`; o planejamento acima não o substitui.

## 2. Dunas Perdidas

Configuração: [phase_02.json](../../data/planning/desert/phase_02.json). ID: `desert_phase_02`.

As trilhas desaparecem entre dunas; El Fuego segue marcos antigos para reencontrar o caminho.

**Ambientação:** Dunas escalonadas, rochas expostas e horizonte com marcos visuais.
**Dificuldade:** fácil (posição 2/10; sem balanceamento validado).
**Obstáculos planejados:** `staggered_ledges`, `alternating_gaps`, `route_landmarks`.
**Inimigos:** tropas Cactus; posicionamento e quantidades ainda não definidos.

**Checkpoints planejados:**

- `desert_phase_02_checkpoint_01`: Na chegada ao primeiro marco estável.
- `desert_phase_02_checkpoint_02`: Depois da travessia central de dunas.

**Condição de conclusão:** alcançar a saída planejada; registrar a conclusão validada, sem conceder a conquista de campanha.

**Recompensas futuras:** registro de conclusão da fase e acesso à próxima fase. Não foram definidos valores econômicos.

**Recursos necessários:**

- `el_fuego_model`: Malha-base e oito FBXs de El Fuego.
- `cactus_model`: Tropa Cactus, malha-base e animações.
- `checkpoint_presentation`: Marcador visual/sonoro de checkpoint.
- `desert_audio`: Ambientes, ações, música e créditos/licenças.
- `desert_story_text`: Textos revisados e localizáveis da campanha.
- `desert_dunes`: Dunas e marcos de orientação.

**Dependências de implementação:**

- `campaign_navigation`: Navegação do menu para campanha e seleção de fase.
- `level_builder`: Instanciação futura do planejamento sem substituir o layout da fase 1.
- `checkpoint_system`: Registro e restauração de checkpoints por tentativa.
- `phase_progression`: Pré-requisitos e conclusão das dez fases.
- `cactus_reuse`: Reutilizar o Cactus atual; balanceamento futuro separado.
- `asset_import_validation`: Verificar importação, materiais, trilhas e sockets no Godot.
- `playtest_and_accessibility`: Percurso, câmera, dificuldade e controles em dispositivos-alvo.

**Situação da versão jogável:** não há cena jogável correspondente nesta base; este arquivo não implementa a fase.

## 3. Oásis da Meia-Noite

Configuração: [phase_03.json](../../data/planning/desert/phase_03.json). ID: `desert_phase_03`.

No oásis, El Fuego encontra indícios de que as patrulhas recebem ordens de uma fortaleza.

**Ambientação:** Água noturna, reflexos contidos e plataformas nas margens.
**Dificuldade:** fácil a moderada (posição 3/10; sem balanceamento validado).
**Obstáculos planejados:** `shore_gaps`, `narrow_safe_paths`, `patrol_crossings`.
**Inimigos:** tropas Cactus; posicionamento e quantidades ainda não definidos.

**Checkpoints planejados:**

- `desert_phase_03_checkpoint_01`: Na margem segura do oásis.
- `desert_phase_03_checkpoint_02`: Após a rota sobre as ilhas.

**Condição de conclusão:** alcançar a saída planejada; registrar a conclusão validada, sem conceder a conquista de campanha.

**Recompensas futuras:** registro de conclusão da fase e acesso à próxima fase. Não foram definidos valores econômicos.

**Recursos necessários:**

- `el_fuego_model`: Malha-base e oito FBXs de El Fuego.
- `cactus_model`: Tropa Cactus, malha-base e animações.
- `checkpoint_presentation`: Marcador visual/sonoro de checkpoint.
- `desert_audio`: Ambientes, ações, música e créditos/licenças.
- `desert_story_text`: Textos revisados e localizáveis da campanha.
- `desert_oasis`: Oásis noturno, água e vegetação.

**Dependências de implementação:**

- `campaign_navigation`: Navegação do menu para campanha e seleção de fase.
- `level_builder`: Instanciação futura do planejamento sem substituir o layout da fase 1.
- `checkpoint_system`: Registro e restauração de checkpoints por tentativa.
- `phase_progression`: Pré-requisitos e conclusão das dez fases.
- `cactus_reuse`: Reutilizar o Cactus atual; balanceamento futuro separado.
- `asset_import_validation`: Verificar importação, materiais, trilhas e sockets no Godot.
- `playtest_and_accessibility`: Percurso, câmera, dificuldade e controles em dispositivos-alvo.

**Situação da versão jogável:** não há cena jogável correspondente nesta base; este arquivo não implementa a fase.

## 4. Ruínas Esquecidas

Configuração: [phase_04.json](../../data/planning/desert/phase_04.json). ID: `desert_phase_04`.

Inscrições nas ruínas revelam uma passagem antiga usada para abastecer os Cactus.

**Ambientação:** Arcos e terraços de pedra, corredores parcialmente desabados.
**Dificuldade:** moderada (posição 4/10; sem balanceamento validado).
**Obstáculos planejados:** `vertical_routes`, `broken_stairs`, `planned_moving_platforms`.
**Inimigos:** tropas Cactus; posicionamento e quantidades ainda não definidos.

**Checkpoints planejados:**

- `desert_phase_04_checkpoint_01`: No pátio de entrada.
- `desert_phase_04_checkpoint_02`: Após o trecho vertical das ruínas.

**Condição de conclusão:** alcançar a saída planejada; registrar a conclusão validada, sem conceder a conquista de campanha.

**Recompensas futuras:** registro de conclusão da fase e acesso à próxima fase. Não foram definidos valores econômicos.

**Recursos necessários:**

- `el_fuego_model`: Malha-base e oito FBXs de El Fuego.
- `cactus_model`: Tropa Cactus, malha-base e animações.
- `checkpoint_presentation`: Marcador visual/sonoro de checkpoint.
- `desert_audio`: Ambientes, ações, música e créditos/licenças.
- `desert_story_text`: Textos revisados e localizáveis da campanha.
- `desert_ruins`: Ruínas e módulos de pedra.

**Dependências de implementação:**

- `campaign_navigation`: Navegação do menu para campanha e seleção de fase.
- `level_builder`: Instanciação futura do planejamento sem substituir o layout da fase 1.
- `checkpoint_system`: Registro e restauração de checkpoints por tentativa.
- `phase_progression`: Pré-requisitos e conclusão das dez fases.
- `cactus_reuse`: Reutilizar o Cactus atual; balanceamento futuro separado.
- `asset_import_validation`: Verificar importação, materiais, trilhas e sockets no Godot.
- `playtest_and_accessibility`: Percurso, câmera, dificuldade e controles em dispositivos-alvo.
- `moving_platforms`: Plataformas móveis, trajetórias e colisões.

**Situação da versão jogável:** não há cena jogável correspondente nesta base; este arquivo não implementa a fase.

## 5. Pontes do Abismo

Configuração: [phase_05.json](../../data/planning/desert/phase_05.json). ID: `desert_phase_05`.

El Fuego atravessa um desfiladeiro que separa as ruínas dos acessos à fortaleza.

**Ambientação:** Pontes suspensas e apoios de pedra com leitura clara dos vãos.
**Dificuldade:** moderada (posição 5/10; sem balanceamento validado).
**Obstáculos planejados:** `bridge_gaps`, `moving_supports`, `timed_crossings`.
**Inimigos:** tropas Cactus; posicionamento e quantidades ainda não definidos.

**Checkpoints planejados:**

- `desert_phase_05_checkpoint_01`: Na primeira margem protegida.
- `desert_phase_05_checkpoint_02`: No apoio central do desfiladeiro.

**Condição de conclusão:** alcançar a saída planejada; registrar a conclusão validada, sem conceder a conquista de campanha.

**Recompensas futuras:** registro de conclusão da fase e acesso à próxima fase. Não foram definidos valores econômicos.

**Recursos necessários:**

- `el_fuego_model`: Malha-base e oito FBXs de El Fuego.
- `cactus_model`: Tropa Cactus, malha-base e animações.
- `checkpoint_presentation`: Marcador visual/sonoro de checkpoint.
- `desert_audio`: Ambientes, ações, música e créditos/licenças.
- `desert_story_text`: Textos revisados e localizáveis da campanha.
- `desert_bridges`: Pontes, suportes e desfiladeiro.

**Dependências de implementação:**

- `campaign_navigation`: Navegação do menu para campanha e seleção de fase.
- `level_builder`: Instanciação futura do planejamento sem substituir o layout da fase 1.
- `checkpoint_system`: Registro e restauração de checkpoints por tentativa.
- `phase_progression`: Pré-requisitos e conclusão das dez fases.
- `cactus_reuse`: Reutilizar o Cactus atual; balanceamento futuro separado.
- `asset_import_validation`: Verificar importação, materiais, trilhas e sockets no Godot.
- `playtest_and_accessibility`: Percurso, câmera, dificuldade e controles em dispositivos-alvo.
- `moving_platforms`: Plataformas móveis, trajetórias e colisões.

**Situação da versão jogável:** não há cena jogável correspondente nesta base; este arquivo não implementa a fase.

## 6. Tempestade de Areia

Configuração: [phase_06.json](../../data/planning/desert/phase_06.json). ID: `desert_phase_06`.

Uma tempestade encobre a aproximação da fortaleza; abrigos e marcos guiam El Fuego.

**Ambientação:** Areia em movimento, abrigos rochosos e contraste suficiente para orientação.
**Dificuldade:** moderada a alta (posição 6/10; sem balanceamento validado).
**Obstáculos planejados:** `shelter_routes`, `reduced_visibility_with_markers`, `wind_windows_planned`.
**Inimigos:** tropas Cactus; posicionamento e quantidades ainda não definidos.

**Checkpoints planejados:**

- `desert_phase_06_checkpoint_01`: No abrigo antes da área aberta.
- `desert_phase_06_checkpoint_02`: Depois do principal corredor da tempestade.

**Condição de conclusão:** alcançar a saída planejada; registrar a conclusão validada, sem conceder a conquista de campanha.

**Recompensas futuras:** registro de conclusão da fase e acesso à próxima fase. Não foram definidos valores econômicos.

**Recursos necessários:**

- `el_fuego_model`: Malha-base e oito FBXs de El Fuego.
- `cactus_model`: Tropa Cactus, malha-base e animações.
- `checkpoint_presentation`: Marcador visual/sonoro de checkpoint.
- `desert_audio`: Ambientes, ações, música e créditos/licenças.
- `desert_story_text`: Textos revisados e localizáveis da campanha.
- `desert_sandstorm`: Areia e vento com leitura de obstáculos preservada.
- `desert_dunes`: Dunas e marcos de orientação.

**Dependências de implementação:**

- `campaign_navigation`: Navegação do menu para campanha e seleção de fase.
- `level_builder`: Instanciação futura do planejamento sem substituir o layout da fase 1.
- `checkpoint_system`: Registro e restauração de checkpoints por tentativa.
- `phase_progression`: Pré-requisitos e conclusão das dez fases.
- `cactus_reuse`: Reutilizar o Cactus atual; balanceamento futuro separado.
- `asset_import_validation`: Verificar importação, materiais, trilhas e sockets no Godot.
- `playtest_and_accessibility`: Percurso, câmera, dificuldade e controles em dispositivos-alvo.
- `sandstorm_effect`: Vento/areia e acessibilidade visual, sem definir física nesta tarefa.

**Situação da versão jogável:** não há cena jogável correspondente nesta base; este arquivo não implementa a fase.

## 7. Fortaleza dos Cactus

Configuração: [phase_07.json](../../data/planning/desert/phase_07.json). ID: `desert_phase_07`.

El Fuego entra na fortaleza e descobre que Malagueta mantém um laboratório além das galerias subterrâneas.

**Ambientação:** Muralhas, pátios e passagens internas da tropa Cactus.
**Dificuldade:** alta (posição 7/10; sem balanceamento validado).
**Obstáculos planejados:** `guarded_gates`, `patrol_sequences`, `elevated_platforms`.
**Inimigos:** tropas Cactus; posicionamento e quantidades ainda não definidos.

**Checkpoints planejados:**

- `desert_phase_07_checkpoint_01`: Após os portões externos.
- `desert_phase_07_checkpoint_02`: No pátio anterior à saída subterrânea.

**Condição de conclusão:** alcançar a saída planejada; registrar a conclusão validada, sem conceder a conquista de campanha.

**Recompensas futuras:** registro de conclusão da fase e acesso à próxima fase. Não foram definidos valores econômicos.

**Recursos necessários:**

- `el_fuego_model`: Malha-base e oito FBXs de El Fuego.
- `cactus_model`: Tropa Cactus, malha-base e animações.
- `checkpoint_presentation`: Marcador visual/sonoro de checkpoint.
- `desert_audio`: Ambientes, ações, música e créditos/licenças.
- `desert_story_text`: Textos revisados e localizáveis da campanha.
- `cactus_fortress`: Fortaleza e insígnias Cactus.

**Dependências de implementação:**

- `campaign_navigation`: Navegação do menu para campanha e seleção de fase.
- `level_builder`: Instanciação futura do planejamento sem substituir o layout da fase 1.
- `checkpoint_system`: Registro e restauração de checkpoints por tentativa.
- `phase_progression`: Pré-requisitos e conclusão das dez fases.
- `cactus_reuse`: Reutilizar o Cactus atual; balanceamento futuro separado.
- `asset_import_validation`: Verificar importação, materiais, trilhas e sockets no Godot.
- `playtest_and_accessibility`: Percurso, câmera, dificuldade e controles em dispositivos-alvo.

**Situação da versão jogável:** não há cena jogável correspondente nesta base; este arquivo não implementa a fase.

## 8. Cavernas de Cristal

Configuração: [phase_08.json](../../data/planning/desert/phase_08.json). ID: `desert_phase_08`.

Uma rota de cristais conduz El Fuego sob a fortaleza, revelando a origem da energia do laboratório.

**Ambientação:** Galerias subterrâneas e cristais com sinalização de profundidade.
**Dificuldade:** alta (posição 8/10; sem balanceamento validado).
**Obstáculos planejados:** `narrow_ledges`, `vertical_crystal_routes`, `planned_moving_platforms`.
**Inimigos:** tropas Cactus; posicionamento e quantidades ainda não definidos.

**Checkpoints planejados:**

- `desert_phase_08_checkpoint_01`: Na galeria de entrada.
- `desert_phase_08_checkpoint_02`: Após a câmara de travessia vertical.

**Condição de conclusão:** alcançar a saída planejada; registrar a conclusão validada, sem conceder a conquista de campanha.

**Recompensas futuras:** registro de conclusão da fase e acesso à próxima fase. Não foram definidos valores econômicos.

**Recursos necessários:**

- `el_fuego_model`: Malha-base e oito FBXs de El Fuego.
- `cactus_model`: Tropa Cactus, malha-base e animações.
- `checkpoint_presentation`: Marcador visual/sonoro de checkpoint.
- `desert_audio`: Ambientes, ações, música e créditos/licenças.
- `desert_story_text`: Textos revisados e localizáveis da campanha.
- `desert_crystals`: Caverna e cristais legíveis em movimento.

**Dependências de implementação:**

- `campaign_navigation`: Navegação do menu para campanha e seleção de fase.
- `level_builder`: Instanciação futura do planejamento sem substituir o layout da fase 1.
- `checkpoint_system`: Registro e restauração de checkpoints por tentativa.
- `phase_progression`: Pré-requisitos e conclusão das dez fases.
- `cactus_reuse`: Reutilizar o Cactus atual; balanceamento futuro separado.
- `asset_import_validation`: Verificar importação, materiais, trilhas e sockets no Godot.
- `playtest_and_accessibility`: Percurso, câmera, dificuldade e controles em dispositivos-alvo.
- `moving_platforms`: Plataformas móveis, trajetórias e colisões.

**Situação da versão jogável:** não há cena jogável correspondente nesta base; este arquivo não implementa a fase.

## 9. Laboratório Proibido

Configuração: [phase_09.json](../../data/planning/desert/phase_09.json). ID: `desert_phase_09`.

El Fuego interrompe a rota de abastecimento e alcança o acesso ao refúgio de Malagueta.

**Ambientação:** Máquinas, condutos e pistas narrativas ligando laboratório e chefe.
**Dificuldade:** muito alta (posição 9/10; sem balanceamento validado).
**Obstáculos planejados:** `telegraphed_hazards_planned`, `mechanism_routes`, `guarded_exit`.
**Inimigos:** tropas Cactus; posicionamento e quantidades ainda não definidos.

**Checkpoints planejados:**

- `desert_phase_09_checkpoint_01`: Após a zona de contenção.
- `desert_phase_09_checkpoint_02`: Antes do último mecanismo de acesso.

**Condição de conclusão:** alcançar a saída planejada; registrar a conclusão validada, sem conceder a conquista de campanha.

**Recompensas futuras:** registro de conclusão da fase e acesso à próxima fase. Não foram definidos valores econômicos.

**Recursos necessários:**

- `el_fuego_model`: Malha-base e oito FBXs de El Fuego.
- `cactus_model`: Tropa Cactus, malha-base e animações.
- `checkpoint_presentation`: Marcador visual/sonoro de checkpoint.
- `desert_audio`: Ambientes, ações, música e créditos/licenças.
- `desert_story_text`: Textos revisados e localizáveis da campanha.
- `desert_laboratory`: Laboratório e pistas da ligação com Malagueta.

**Dependências de implementação:**

- `campaign_navigation`: Navegação do menu para campanha e seleção de fase.
- `level_builder`: Instanciação futura do planejamento sem substituir o layout da fase 1.
- `checkpoint_system`: Registro e restauração de checkpoints por tentativa.
- `phase_progression`: Pré-requisitos e conclusão das dez fases.
- `cactus_reuse`: Reutilizar o Cactus atual; balanceamento futuro separado.
- `asset_import_validation`: Verificar importação, materiais, trilhas e sockets no Godot.
- `playtest_and_accessibility`: Percurso, câmera, dificuldade e controles em dispositivos-alvo.
- `laboratory_hazards`: Telegráficos e estados dos mecanismos do laboratório.

**Situação da versão jogável:** não há cena jogável correspondente nesta base; este arquivo não implementa a fase.

## 10. Confronto com Malagueta

Configuração: [phase_10.json](../../data/planning/desert/phase_10.json). ID: `desert_phase_10`.

El Fuego enfrenta Malagueta e encerra a campanha do Reino do Deserto.

**Ambientação:** Arena final com área de preparação, limites legíveis e saída narrativa.
**Dificuldade:** clímax (posição 10/10; sem balanceamento validado).
**Obstáculos planejados:** `boss_telegraphs_planned`, `arena_safe_routes`, `final_exit_after_boss`.
**Inimigos:** tropas Cactus; posicionamento e quantidades ainda não definidos. **Chefe final: Malagueta.**

**Checkpoints planejados:**

- `desert_phase_10_checkpoint_01`: Na entrada segura da arena, antes do confronto.

**Condição de conclusão:** derrotar Malagueta e alcançar a saída narrativa, com validação do serviço de progresso futuro.

**Recompensas futuras:** registro da fase, conclusão da campanha, conquista `desert_campaign_completed` e desbloqueio de El Fuego. Não foram definidos valores econômicos.

**Recursos necessários:**

- `el_fuego_model`: Malha-base e oito FBXs de El Fuego.
- `cactus_model`: Tropa Cactus, malha-base e animações.
- `checkpoint_presentation`: Marcador visual/sonoro de checkpoint.
- `desert_audio`: Ambientes, ações, música e créditos/licenças.
- `desert_story_text`: Textos revisados e localizáveis da campanha.
- `malagueta_model`: Base skinned de Malagueta e quatro clips sem malha.
- `malagueta_arena`: Arena final, entrada e saída narrativa.
- `campaign_completion_ui`: Conclusão, conquista e desbloqueio de El Fuego.

**Dependências de implementação:**

- `campaign_navigation`: Navegação do menu para campanha e seleção de fase.
- `level_builder`: Instanciação futura do planejamento sem substituir o layout da fase 1.
- `checkpoint_system`: Registro e restauração de checkpoints por tentativa.
- `phase_progression`: Pré-requisitos e conclusão das dez fases.
- `cactus_reuse`: Reutilizar o Cactus atual; balanceamento futuro separado.
- `asset_import_validation`: Verificar importação, materiais, trilhas e sockets no Godot.
- `playtest_and_accessibility`: Percurso, câmera, dificuldade e controles em dispositivos-alvo.
- `malagueta_encounter`: Comportamento e condições do chefe final.
- `verified_progress_service`: Conclusões autoritativas e idempotentes no servidor.
- `unlock_migration`: Migrar flag antiga sem liberar El Fuego por progresso incompleto.

**Situação da versão jogável:** não há cena jogável correspondente nesta base; este arquivo não implementa a fase.

## Decisões que continuam abertas

- Medidas finais dos percursos, colocação de obstáculos e checkpoints, duração e balanceamento.
- Arte, áudio, acessibilidade, narrativa final e orçamento de desempenho.
- Comportamento e telegráficos de Malagueta; este planejamento não cria combate.
- Nenhuma fase está declarada pronta ou testada no Godot por existir um JSON.
