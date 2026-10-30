# T16D — Testes, limites e economia

Data: 30/10/2026. **Somente evidências obtidas no Supabase conectado; sem simulações de usuários em produção.**

## Alterações reais

**GAME:** migrations `t16d_duel_room_chat_invites` e `t16d_chat_sender_aliases` aplicadas. A RPC de acesso do CHAT agora devolve tags pseudonimas SHA-256 por sala, `member_id` e nickname apenas aos membros autorizados. O gateway devolve `sender_name`, `sender_member_id`, `is_you` na leitura de ROOM sem expor `sender_game_user_id`. Novas RPCs: `qse_duel_chat_access`, `qse_duel_invite_create`, `qse_duel_invite_join`. Nova tabela RLS `qse_v3.duel_invite_links` (1 convite ativo por sala; token armazenado como hash). **Nenhuma RPC preexistente do Duelo foi substituída.**

**CHAT:** migration `t16d_duel_room_chat` aplicada. `qse_chat_conversations.kind` aceita `room` além de `direct/group`; vínculo único `game_room_id`; RPCs de leitura e envio específicas para room, restritas a service_role. O banco não replica participantes. O `qse-chat-gateway` foi implantado na versão **5**, ACTIVE, mantendo o contrato de mensagens diretas.

**GitHub:** somente SQL aditivo, código da função e documentos, branch `chatgpt/t16d-room-chat-invites`. Nada em Godot, cartas, regras do Duelo ou PR #39.

## Validações executadas

| Teste | Observação | Resultado |
| --- | --- | --- |
| GAME: assinaturas/EXECUTE das 3 novas RPCs | `anon=false`, `authenticated=true` | **PASSOU** |
| GAME: tabela de convites | RLS ativo, 0 policies de acesso direto, 0 registros existentes | **PASSOU** |
| GAME: membership/kicks | Função implantada contém verificações indexadas de `duel_members` e `duel_kicks` | **INSPEÇÃO APROVADA** |
| GAME: reuse `qse_duel_join` | RPC nova invoca RPC de ingresso existente, sem trocar sua implementação | **INSPEÇÃO APROVADA** |
| CHAT: leitura/envio RPCs room | `anon=false`, `authenticated=false`, `service_role=true` | **PASSOU** |
| CHAT: TTL | RPC de leitura room contém filtro de 24 horas | **INSPEÇÃO APROVADA** |
| CHAT: rate limit | RPC de envio room contém `pg_advisory_xact_lock`; utiliza mesma chave de idempotência e contagem do chat privado | **INSPEÇÃO APROVADA** |
| CHAT: limpeza | Cron `qse-chat-ttl-24h` ativo | **PASSOU** |
| CHAT: chamada indevida `qse_chat_room_read(NULL,NULL,50)` | `{"error":"forbidden"}` | **PASSOU** |
| CHAT: chamada indevida `qse_chat_room_send(NULL,NULL,NULL,NULL)` | `{"error":"invalid_message"}` | **PASSOU** |
| GAME: novos apelidos | `anon EXECUTE=false`, `authenticated=true`, `qse_duel_chat_access` valida sala, papel e kick antes de devolver tags pseudonimas e nicknames | **PASSOU (SQL e inspeção)** |
| CHAT: mensagem room sem UUID GAME | Gateway v5 mapeia autores via hash SHA-256 e devolve somente `sender_member_id`, `sender_name`, `is_you` | **PASSOU (inspeção do deploy)**; E2E real ainda pendente |
| Deploy Edge | `qse-chat-gateway` v5, ACTIVE, `verify_jwt=false` com verificação própria do GAME | **PASSOU (deploy/metadata)** |
| HTTP anônimo ou JWT inválido | Ambiente não conseguiu resolver domínio externo do Supabase | **NÃO EXECUTADO** |
| 2 usuários reais: criar sala, conectar, enviar/ler, kick, leave, close | GAME possui 0 salas/membros no momento da inspeção | **PENDENTE** |
| Convite: gerar token, abrir link, entrar, expirar e rotacionar | Requer conta administrativa legítima e sala real | **PENDENTE** |
| Concorrência real e múltiplos envios simultâneos | Sem benchmark ao vivo | **PENDENTE** |
| Android/Web deep links | Não há rota do app preparada nesta tarefa | **PENDENTE, depende do frontend** |

**Atenção:** verificar código e permissões não equivale a testar o fluxo HTTP. Nenhuma conta fictícia, token artificial de jogador ou mensagem legítima foi criada/excluída. Não afirmar e2e aprovado.

## Custo por chamada (contagem estática do caminho normal)

- `open_room`: **1 Edge CHAT**, **1 RPC GAME** específica para confirmar participação, **1 upsert CHAT**.
- `messages` em room: **1 Edge CHAT**, **1 RPC GAME**, **1 leitura da conversa CHAT**, **1 RPC de leitura CHAT**.
- `send` em room: **1 Edge CHAT**, **1 RPC GAME**, **1 leitura de conversa CHAT**, **1 RPC de envio CHAT** (controle de rate/idempotência/inserção).
- `qse_duel_invite_create` / `qse_duel_invite_join`: **1 chamada RPC GAME**, sem consultar o CHAT.
- Em tokens HS256 antigos, cada chamada ao gateway ainda pode exigir **consulta `/auth/v1/user` ao GAME**. Essa chamada adicional não foi incluída nos números acima.
- Sem Realtime nem WebSocket. O nickname vem da mesma RPC de autorização GAME, sem HTTP adicional. Ao fechar a sala, o gateway nega as próximas operações, sem sincronização de membros entre bancos. O polling no Godot **não foi implementado** aqui.

### Riscos restantes
1. **TOCTOU entre bases**: um membro pode ser expulso imediatamente após a validação GAME e antes da gravação CHAT; não existe transação distribuída. Revalidar toda operação sem cache positivo reduz a janela.
2. **Convites são credenciais de ingresso**: compartilhar o token permite que terceiros autenticados entrem até expiração/rotação, respeitando kick e limite da sala. Evitar colocar tokens em logs, erros e analytics.
3. **Expiração do armazenamento**: fechamento da sala nega acesso, mas a remoção física das mensagens só acontece pelo TTL de 24 h. Conexões antigas do cliente devem limpar seu cache na saída.
4. **Escala**: salas movimentadas com polling a cada 10 s aumentam Edge invocations. Economizar pausando polling se o chat estiver fechado.

## Aprovação necessária
Claude só deve ligar o chat da batalha após teste real com **2 jogadores GAME**, incluindo um kick/leave e convite expirado; teste sem rede e rate limit em ambiente seguro. Nenhuma alteração visual foi realizada nesta branch.
