# T16A — Verificações reais, métricas de código e limitações (30/10/2026)

## Implantação verificada

- **GAME** `shuzporktifgiotvnpbz`: migration `t16a_chat_authorization_game` aplicada. `qse_v3.chat_blocks`, RPCs `qse_chat_can_message(p_peer)` e `qse_chat_block(p_peer,p_block)` presentes. Anon **sem EXECUTE**, authenticated **com EXECUTE**. Autoridade de usuário continua no GAME, não há usuário paralelo no CHAT.
- **CHAT** `wurkpjgnbqklivjhcvxk`: migration `t16a_chat_ttl_retention` aplicada. Funções `qse_chat_read`, `qse_chat_send`, `qse_chat_cleanup`, três índices adicionais, `client_request_id` e `pg_cron 1.6.4` confirmados. Exatamente **1** job ativo `qse-chat-ttl-24h` com `* * * * *`.
- **Edge CHAT**: `qse-chat-gateway` v3 com `verify_jwt=false` (verificação própria do GAME), confirmado pelo retorno do deploy **ACTIVE**. Código versionado; a API HTTP com sessão real não foi exercitada.
- **CATALOG** `bsxicvlngphazesuzaee`: consultado inicialmente (8 personagens, 1 deck, 9 cartas), nenhuma modificação feita. Godot igualmente não foi alterado.
- Estado inicial do CHAT: **0 conversas / 0 membros / 0 mensagens**, auditado por consulta direta.

## Evidências específicas coletadas no PostgreSQL

| Verificação | Resultado |
| --- | --- |
| Job `qse-chat-ttl-24h` presente e ativo | **PASSOU** |
| Execuções do cron | **5 execuções sucessivas** reportaram `succeeded`, sem erros |
| Filtro de leitura `sent_at > now() - 24h` na RPC | **PASSOU (inspeção do código implantado)** |
| `qse_chat_read(NULL,NULL,50)` | **PASSOU:** `{"error":"forbidden"}` |
| `qse_chat_send(NULL,NULL,NULL,NULL)` | **PASSOU:** `{"error":"invalid_message"}` |
| `qse_chat_cleanup(5,5)` com banco vazio | **PASSOU:** `messages_deleted=0`, `rooms_deleted=0`; tabelas permanecem vazias |
| Proteção das três tabelas por RLS | **PASSOU:** RLS ativo; 0 policies para cada tabela |
| Execução de `qse_chat_read`, `qse_chat_send`, `qse_chat_cleanup` | **PASSOU:** `anon` e `authenticated` sem permissão EXECUTE |
| Bloqueio transacional na RPC de envio | **PASSOU (inspeção do código):** `pg_advisory_xact_lock` |
| Índices novos de expiração, rate e idempotência | **PASSOU:** 3 índices presentes |
| GAME `qse_chat_can_message` e `qse_chat_block` | **PASSOU:** existem; anon sem EXECUTE; authenticated com EXECUTE |
| Endpoint sem Authorization / token inválido via HTTP | **PENDENTE:** ambiente atual não conseguiu invocar URL externa |
| Envio/recepção entre duas contas reais | **PENDENTE:** não havia duas contas amigas reais para teste |
| Remoção de amizade/bloqueio e tentativa de envio real | **PENDENTE** |
| Retry real, concorrência e janela de rate limit | **PENDENTE:** desenho transacional implantado, sem benchmark dinâmico |
| Retenção de uma mensagem verdadeira após 24h | **PENDENTE:** cron e filtro confirmados, nenhuma mensagem disponível para ensaio completo |
| Renderização/testes do Godot 16B | **FORA DO ESCOPO desta tarefa** |

**Não afirmar que o gateway está aprovado em produção com dois usuários:** o deploy e o banco estão validados estruturalmente, mas o HTTP integrado com GAME aguarda duas sessões reais e rede disponível.

## Antes/depois por ação (contagem de operações no código)

| Ação | Antes: GAME / CHAT | Agora: GAME / CHAT | Observação |
| --- | --- | --- | --- |
| `open_direct` | 1 RPC `qse_friends` / até 2 escritas | 1 RPC **pontual** / até 2 escritas | Evita carregar perfis e listas completas |
| `list` | 0 / até 2 consultas | 0 / até 2 consultas | Sem mudança |
| `messages` | 0 / 2 consultas | **1** RPC pontual / 2 consultas | Verifica amizade e bloqueio em toda leitura |
| `send` | 1 RPC `qse_friends` / **4** operações | 1 RPC pontual / **2** operações | Rate e insert atômicos; idempotência |

Números acima são contagem **estática** dos caminhos normais do código, NÃO métricas de produção nem benchmark. JWT **HS256** legado acrescenta **1 consulta `/auth/v1/user` do GAME por chamada**; RS256/ES256 com JWKS validado geralmente evita essa consulta por requisição (sem considerar renovação do cache JWKS).

**Importante:** a quantidade de chamadas cruzadas GAME/CHAT por `send` continua **1**. Não foi aplicado cache positivo de amizade para não manter permissões após remoção ou bloqueio. O custo da validação é agora menor porque consulta apenas índices `friendships`/`chat_blocks`.

## Estimativa de consumo (simulação, não medição)

Premissas escolhidas: cada jogador ativo por semana usa o CHAT em **3 dias da semana**, envia **10 mensagens por dia ativo**, mantém conversa aberta por **5 minutos** (polling a cada 15s = **20 leituras** por dia ativo), abre a lista **1 vez** e chama `open_direct` **0,5 vez** em média por dia ativo. Um envio = uma invocação Edge; uma leitura = uma invocação Edge; `list` e `open_direct` também contam 1 cada. A chamada GAME por leitura/envio/open_direct é 1 (JWT assimétrico); tamanho de armazenamento estimado **800 bytes por mensagem** com índices e overhead. Valores arredondados, sem retries, autenticação HS256, cache de borda, WAL ou picos.

| Jogadores ativos/semana | Mensagens/dia | Edge invocações/dia | Consultas cruzadas GAME/dia | Dados de 24h (MB aprox.) |
| ---: | ---: | ---: | ---: | ---: |
| 100 | 429 | 1.350 | 1.307 | 0,3 |
| 1.000 | 4.286 | 13.500 | 13.071 | 3,4 |
| 10.000 | 42.857 | 135.000 | 130.714 | 34,3 |
| 50.000 | 214.286 | 675.000 | 653.571 | 171,4 |
| 100.000 | 428.571 | 1.350.000 | 1.307.143 | 342,9 |
| 150.000 | 642.857 | 2.025.000 | 1.960.714 | 514,3 |

No cenário de 150 mil jogadores ativos semanais, a simulação equivale a ~**60,75 milhões de invocações Edge por mês** (30 dias). **Não há garantia de caber no plano gratuito.** A capacidade teórica do cron de 2.000 mensagens/minuto = **2,88 milhões/dia** supondo que cada ciclo consiga processar o lote. Em picos maiores a limpeza física pode atrasar, mas o TTL de leitura impede retorno de mensagens com 24h ou mais. Para reduzir custo na 16B, suspender polling fora do chat e ajustar intervalo adaptativamente.

## Banco e manutenção

`DELETE` não devolve imediatamente espaço ao sistema: PostgreSQL marca tuplas como mortas, e o **autovacuum** normal ajuda a reutilizá-lo. Monitorar `pg_stat_user_tables.n_dead_tup`, autovacuum, tamanho de tabela/índices e duração dos jobs. Não executar `VACUUM FULL` em produção sem manutenção programada; ele bloqueia tabelas. Sem necessidade de agendamento manual de VACUUM agora.

## Pendências reais para 16B

1. Fazer teste HTTP com dois jogadores legítimos já cadastrados no GAME e amizade válida: `open_direct` → `list` → `send` → `messages`, comparar respostas com o contrato.
2. Reenviar `send` com **mesmo UUID** e depois com UUID novo para testar idempotência, e testar envio após `qse_chat_block`/remoção de amizade.
3. Confirmar JWT real RS/ES ou HS, tempo de expiração e comportamento de revogação de sessão (assinatura válida não equivale necessariamente a sessão instantaneamente revogada).
4. Configurar polling adaptativo somente quando uma conversa está aberta. Cliente CHAT do Godot permanece **desativado** na T16A.
5. Auditar limites em testes de carga num ambiente de teste antes de lançamento viral, sem inundar produção.

Este relatório não declara sucesso de testes HTTP não realizados.
