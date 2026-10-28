# Próximas tarefas sem Godot

O planejamento atual preserva a versão jogável. As atividades abaixo podem continuar em branch de trabalho, com revisão de alterações remotas antes de qualquer integração na main.

1. **Revisar a campanha editorialmente.** Aprovar narrativa, transições, linguagem de checkpoints e dificuldade qualitativa das dez fases; manter El Fuego, Cactus e Malagueta nos papéis definidos. Não inventar economia para preencher campos.
2. **Organizar requisitos de arte e áudio.** Produzir briefings por `resource_requirements.json`, apontar referências/licenças/autoria e definir critérios de aceitação, sem substituir assets originais.
3. **Preparar a migração de progresso.** Revisar checks/FKs/políticas e cenários transacionais do contrato Supabase; detalhar evidência de conclusão que não dependa da palavra do cliente. Não executar migrações remotas nesta etapa.
4. **Definir a compatibilidade dos saves antigos.** Especificar quando existe prova suficiente de conclusão, como tratar flag DEV sem prova e como manter o formato esperado por `CharacterCatalog`. Não conceder a conquista automaticamente.
5. **Preparar o pipeline de distribuição.** Escolher derivados para a versão exportada do Godot, fechar contrato de release/bootstrap confiável e casos de cache, retentativa, corrupção e recuperação. Fontes FBX/OBJ não são prontas para download e carregamento automático como PackedScene.
6. **Ampliar inspeções offline dos assets.** Comparar poses de repouso e pesos, detectar duplicação de conteúdo/texturas e documentar prioridades de otimização. Não nomear `1.fbx`–`4.fbx` como idle/dança sem evidência verificável; não alterar nem converter os originais.
7. **Preparar cenários de QA.** Criar checklists de bloqueio de lobby versus acesso à campanha, conclusão sequencial, morte/retomada, chefes, estados de rede e propriedade de dados. São especificações de teste, sem nova cena jogável ou combate.

## Depende de outra etapa com o motor

Conectar a navegação de História, criar cenas das fases 2–10, implementar checkpoints/chefe, migrar os consumidores de progresso, importar/converter modelos, avaliar as animações, ajustar física/câmera/controladores e medir desempenho exigem autorização de escopo e validação no Godot. Não fazem parte da preparação offline entregue.
