# Continuidade do Modo História

A campanha conserva o maior avanço entre visitante, conta e aparelhos. O login não pede para escolher qual progresso substituir. Uma diferença gera somente um aviso informativo.

| Antes do login | Conta | Resultado |
|---|---|---|
| 5 fases concluídas como visitante | 2 concluídas | 5 concluídas, fase 6 liberada |
| Visitante na fase 2 (1 concluída) | Conta na fase 5 (4 concluídas) | Continua com a fase 5 liberada |
| Avanço local maior, sem internet | Último avanço remoto menor | Mantém a cópia local e sincroniza novamente ao recuperar a conexão |
| Troca da conta A para B | Progresso de cada dono | Cópias locais separadas e descarte da resposta atrasada de A |

## GAME

Migration `20261106210000_story_progress_merge.sql`, instalada e registrada no histórico do GAME. Acrescenta `qse_v3.story_progress` e `public.qse_story_progress_sync(p_completed integer)`.

- Identidade vem de `auth.uid()` via `qse_v3.require_user()`. Não existe parâmetro para gravar em outro usuário.
- A atualização usa `GREATEST` no UPSERT: uma gravação atrasada ou concorrente não reduz o maior avanço.
- Conclusões contíguas já verificadas e a fase ativa do contrato anterior são consideradas na leitura.
- RLS habilitado, sem leitura/gravação direta por `authenticated`; execução da RPC somente por `authenticated`, recusada para `anon`.
- Conquistas, recompensas, moeda, inventário econômico e `phase_completions` verificadas continuam com seus contratos atuais. Importar a campanha local não concede esses benefícios.

O teste SQL usa dois UIDs existentes dentro de uma transação e encerra com `ROLLBACK`. Não cria contas nem deixa progresso de teste salvo. A chamada HTTP pública sem sessão foi recusada com `401 / 42501`, confirmando que o endpoint existe e exige autenticação.

## Cliente

`StoryProgressService` é composto por `PlayerServices`. Ao mudar a conta, importa o avanço visitante elegível, conserva o cache daquele dono e sincroniza. O maior valor recebido é persistido localmente. Falha de rede não apaga esse cache; uma nova vitória, o poller com jogo em foco ou o retorno do foco tenta sincronizar de novo.

O arquivo visitante antigo e seu backup Web são preservados. O marcador `highest_claimed` evita importar repetidamente o mesmo avanço para outras contas. Avanços novos feitos como visitante continuam elegíveis. Tutoriais já aprendidos também são importados, preservando a descoberta dos poderes mesmo com carga zero.

O Modo História e o Perfil mostram o avanço conciliado. Um aviso curto informa a diferença sem modal de escolha e sem interceptar toque. O aviso temporário não é duplicado na tela que já apresenta esse texto.

As cargas de ataque, defesa, âmbar, relâmpago e ruptura são guardadas por dono no aparelho ao concluir uma fase. A fase seguinte recebe os valores exatos, inclusive zero, respeitando capacidade e desbloqueio. Reabrir a fase seguinte pelo menu ou após reload recupera a mesma entrada. As penalidades de reinício/checkpoint seguem as regras anteriores.

O estado sincronizado no GAME é o avanço entre fases. As cargas de combate desta entrega são persistidas no aparelho e transferidas entre fases; posição dentro da fase continua sob os checkpoints existentes.

## Carregamento e apoios

A capa passa a mostrar “Carregando fase”. A barra acompanha a leitura real dos recursos da cena, modelos, animações e arte. Não há porcentagem textual simulada, espera mínima nova nem atraso criado para exibir a barra. A história continua disponível e pode ser pulada. Erro mantém Tentar novamente/Voltar.

Aquecimento dos shaders agora usa callback do próprio objeto, evitando retomar coroutine de uma fase já liberada. O avanço também impede abrir duas transições por cliques repetidos.

Rochas próximas recebem apoios nas superfícies planas e as caixas do posto de controle passam a aceitar aterrissagem. A exclusão geral da fase 2 foi removida dos objetos opcionais; seus telhados físicos existentes são preservados. Objetos de fundo e vãos de Tasks continuam sem pisos adicionais. Apoios permitem atravessar de baixo para cima e são removidos com o trecho.

## Verificação

Resultados e capturas: [evidence/story-continuity](../../evidence/story-continuity/README.md).

```sh
python3 tests/desert_night/run.py --godot /caminho/godot --only account-merge story-transitions story-platforms
```

O Web usa uma fixture com RPC simulada para exercitar o cliente, persistência e passagem real entre cenas, sem criar usuários ou atingir o backend no navegador. O contrato SQL foi testado separadamente no GAME real. Isso não representa um novo teste de login Google/Discord em aparelho físico.
