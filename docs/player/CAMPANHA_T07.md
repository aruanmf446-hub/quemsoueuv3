# Tarefa 07 — preparação da campanha do Deserto

Branch `codex/campanha-deserto-07`, base `16d7823`. Godot e Blender não executados. Nenhuma fase declarada jogável ou aprovada.

## Implementação real

Dez cenas `scenes/desert/phase_01.tscn` a `phase_10.tscn` e dez configurações correspondentes em `data/desert/`. Todas usam o controlador existente `scripts/desert/phase_01.gd`, agora parametrizado por `phase_path`. Mantêm iluminação noturna e plano lateral XY. El Fuego e Cactus conservam modelos existentes; Malagueta usa seu FBX com malha e os arquivos de animação disponíveis, sem substitutos genéricos.

O controlador monta colisões, personagem, inimigos, câmera, saída e checkpoints. Checkpoints usam os IDs canônicos e alteram somente a posição de reinício da sessão. Morte e queda acionam reinício; a câmera usa interpolação dependente do tempo. Vitória local interrompe controle e oferece Próxima fase mantendo o wrapper de retorno ao menu. Na fase 10, a saída exige o sinal de derrota da instância Malagueta. Reiniciar o protagonista limpa temporizadores de combate e salto. Controles não duplicam eventos ao carregar outra fase e liberam ações de toque ao sair.

Malagueta reutiliza a máquina de estados de Cactus com parâmetros próprios e os modelos/animações reais; não há uma IA especial completa de chefe, projéteis ou combate avançado implementados. Esses itens dependem de desenvolvimento posterior, não apenas de teste.

## Estado de cada fase

| Fase | Conteúdo implementado | Limite |
| --- | --- | --- |
| 1 Entrada do Deserto | Protótipo reaproveitado, checkpoints e transição | Mantém os blocos visuais legados; requer teste |
| 2 Dunas Perdidas | Cena/configuração, percurso derivado, Cactus e checkpoints | Cenário visual e design próprio pendentes |
| 3 Oásis da Meia-Noite | Idem, com configuração independente | Sem assets de oásis disponíveis |
| 4 Ruínas Esquecidas | Idem | Sem assets de ruínas disponíveis |
| 5 Pontes do Abismo | Idem | Sem assets de pontes disponíveis |
| 6 Tempestade de Areia | Idem | Tempestade não implementada |
| 7 Fortaleza dos Cactus | Idem | Fortaleza não implementada |
| 8 Cavernas de Cristal | Idem | Cavernas/cristais não implementados |
| 9 Laboratório Proibido | Idem | Laboratório não implementado |
| 10 Confronto com Malagueta | Instância do chefe, combate básico e saída condicionada | IA específica, arena visual e teste pendentes |

As fases 2–10 são estruturas executáveis em código, **não nove fases finalizadas ou percursos validados**. Reutilizam a geometria de colisão da fase 1 com pequenas variações de plataformas. Não existem assets de cenário do Deserto no inventário: as novas cenas não desenham cubos substitutos; portanto, seus pisos de colisão ainda não têm apresentação visual. A geometria de caixa já existente na fase 1 foi preservada como legado, não criada como arte nova. Esse é um bloqueio real para avaliar e concluir o cenário. Não há efeitos ou obstáculos temáticos fictícios apresentados como implementados.

## Progresso e preservação

Vitória/checkpoint/transição são locais à sessão. Não escrevem Supabase, conquistas, economia ou desbloqueios. A derrota de Malagueta local não equivale a prova autoritativa online. El Fuego permanece bloqueado no lobby até as dez conclusões verificadas conforme contrato v2. Telas da T06, serviços, migrations e catálogo de skins permanecem byte a byte intactos.

O menu História foi preservado e continua oferecendo seu protótipo da fase 1. As próximas fases são acessadas pelo botão da sessão após conclusão, ou abertas diretamente pelo editor. A integração de seleção de fases com o menu concluído não foi alterada nesta tarefa.

## Arquivos e testes

Alterados: `scripts/desert/phase_01.gd`, `side_player.gd`, `cactus_enemy.gd`, `touch_controls.gd`, `data/desert/phase_01.json`, `data/desert_enemies.json`.

Novos: nove cenas, nove configurações, `tools/desert/test_campaign.py` e este relatório. 85 testes aprovados: cinco de estrutura/sintaxe/preservação e 80 da progressão v2. Verificam dez IDs, ordem, checkpoints, referências aos modelos reais, sintaxe GDScript e hashes fora do escopo. Não comprovam compilação do motor, colisões, animações, alcance de saltos ou combate.

```bash
python -B -m unittest tools.desert.test_campaign tools.progression.tests.test_engine tools.progression.tests.test_migration tools.progression.tests.test_sync -v
```

Usar dependências de `tools/player_ui/requirements.txt`. Os gates de imutabilidade anteriores continuam históricos e não foram alterados para aprovar mudanças de gameplay agora autorizadas.

## Claude + Godot — roteiro curto

1. Na branch, seguir AGENTS.md: consultar status/project_info, importar FBX e rodar fase 1, ler erros de tipos/APIs e importação. Não aplicar migrations nem tentar login.
2. Verificar movimento XY, colisão cápsula/piso, câmera lateral noturna, salto/duplo salto, ataque e intervalo entre ataques. Testar Cactus com personagem vivo, morto e ausente.
3. Ativar checkpoints e morrer por dano/queda: reiniciar uma vez, no checkpoint, com vida e temporizadores restaurados. Conferir que o ponto de retorno está apoiado no piso e que inimigos não prendem o jogador.
4. Concluir e transitar por cada cena, voltando ao menu com o wrapper. Conferir que toques não ficam pressionados e bindings não se multiplicam. Nas fases sem arte, usar visualização de colisões do editor; não confundir isso com cenário final.
5. Na fase 10, conferir importação/retarget, proporção e ataques de Malagueta; saída deve recusar antes da derrota e aceitar depois. Verificar que o lobby continua bloqueando El Fuego e que nada foi creditado online.
6. Registrar resultado por fase, capturas e erros. Preparar assets de cenário e level design próprio antes de chamar as dez fases de completas. Ajustar parâmetros de combate e plataformas somente após medir no motor.
