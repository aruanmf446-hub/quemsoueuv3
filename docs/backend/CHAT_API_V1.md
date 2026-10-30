# QUEM SOU EU V3 — API CHAT v1 (T16A)

**Status:** gateway **v3 implantado** no projeto CHAT `wurkpjgnbqklivjhcvxk`.
**Fonte de verdade:** `supabase/chat/functions/qse-chat-gateway/index.ts`, migrations GAME e CHAT nesta branch.
**Uso no Godot:** **DESATIVADO** até a Tarefa 16B. Este arquivo é somente o contrato de backend; não altera UI.

## Endpoint e autenticação

```http
POST https://wurkpjgnbqklivjhcvxk.supabase.co/functions/v1/qse-chat-gateway
Content-Type: application/json
apikey: <CHAT_PUBLISHABLE_KEY>
Authorization: Bearer <GAME_ACCESS_TOKEN>
```

O `Authorization` **sempre** contém o access token de sessão autenticada do Supabase **GAME** (`shuzporktifgiotvnpbz`). Nunca usar token emitido pelo projeto CHAT; nunca enviar chave administrativa no app.

O backend verifica JWT assimétrico RS256/ES256 usando JWKS do GAME (issuer `https://shuzporktifgiotvnpbz.supabase.co/auth/v1`, audience e role `authenticated`). Para JWT HS256 legado, consulta `GET /auth/v1/user` no GAME. O ID do remetente vem exclusivamente do token verificado. Qualquer `sender_game_user_id`, `user_id` ou nickname fornecido no JSON **não autoriza** identidade.

`OPTIONS` retorna 204 (CORS). Apenas `POST` aceita ações. Requisições maiores que **8192 bytes**, inclusive sem `Content-Length`, recebem HTTP 413. Respostas são JSON com `Cache-Control: no-store`. Nenhum recurso depende de Realtime atualmente. `Verify JWT` do gateway está OFF **porque a função valida o token do GAME por conta própria**.

## Ações implementadas

### 1. `open_direct`

Cria ou reutiliza uma conversa **direta** e registra dois membros, com ID determinístico baseado no par; não cria usuários no CHAT.

```json
{"action":"open_direct","peer_id":"<UUID_DO_AMIGO_NO_GAME>"}
```

Resposta HTTP 200:
```json
{"conversation_id":"<UUID_DA_CONVERSA>"}
```

Requer amizade ativa no GAME e ausência de bloqueio entre os participantes. Usar o UUID do destinatário já obtido no serviço de amizades GAME, não um nickname. Chamadas repetidas para o mesmo par retornam o mesmo ID.

### 2. `list`

Lista metadados de até **50 conversas** das quais o usuário autenticado é membro. Não inclui mensagens nem nicknames. Ordenação decrescente por `created_at`.

```json
{"action":"list"}
```

Resposta HTTP 200:
```json
{"conversations":[{"id":"<UUID>","kind":"direct","created_at":"2026-10-30T16:00:00Z"}]}
```

Se vazio, `{"conversations":[]}`. Conversas historicamente registradas podem aparecer até a limpeza; participação **não** permite ler/enviar após remoção de amizade ou bloqueio.

### 3. `messages`

Últimas **50** mensagens da conversa, ordenadas da mais recente para a mais antiga; só retorna mensagens ainda válidas.

```json
{"action":"messages","conversation_id":"<UUID_DA_CONVERSA>"}
```

Resposta HTTP 200:
```json
{"messages":[
  {"id":"<UUID>","sender_game_user_id":"<UUID_DO_GAME>","body":"Oi!","sent_at":"2026-10-30T16:10:00+00:00"}
]}
```

O gateway valida participação (exatamente dois membros), amizade e bloqueios no GAME. A RPC `qse_chat_read` valida participação novamente no banco e aplica `sent_at > now() - interval '24 hours'` **antes** da limpeza física. A API **não possui** `since`, `cursor`, `before`, paginação nem WebSocket nesta versão; o cliente descarta IDs repetidos e mantém no máximo 50 itens retornados por leitura.

### 4. `send`

Envia mensagem de texto e protege contra duplicação em retries. **`request_id` UUID obrigatório**, novo por intenção de envio. Em retry por falha de rede, reutilizar exatamente o mesmo `request_id`, conversa e corpo.

```json
{
  "action":"send",
  "conversation_id":"<UUID_DA_CONVERSA>",
  "request_id":"<UUID_ALEATORIO_DA_INTENCAO>",
  "body":"Oi!"
}
```

Resposta HTTP 200 (primeiro envio):
```json
{"message":{"id":"<UUID_DA_MENSAGEM>","sent_at":"2026-10-30T16:10:00+00:00"},"duplicate":false}
```

Resposta HTTP 200 (reenvio idempotente):
```json
{"message":{"id":"<MESMO_UUID>","sent_at":"<MESMO_TIMESTAMP>"},"duplicate":true}
```

`body` é recortado nas extremidades (`trim`); precisa ter de **1 a 2000 caracteres Unicode** após recorte. Envio requer exatamente dois membros, amizade atual e ausência de bloqueio. Rate limit: **20 mensagens por remetente por janela deslizante de 60 s**, com bloqueio transacional por remetente no PostgreSQL. Não há consulta de nickname ao enviar. O banco usa chave única `(sender_game_user_id,client_request_id)`.

## Erros (JSON `{"error":"codigo"}`)

| HTTP | Código | Quando |
| --- | --- | --- |
| 400 | `invalid_json` / `invalid_action` | JSON inválido, ação ausente ou desconhecida |
| 400 | `invalid_peer` | ID do destinatário inválido ou é o próprio usuário |
| 400 | `invalid_conversation` | ID da conversa inválido |
| 400 | `invalid_request_id` | UUID de idempotência ausente/inválido |
| 400 | `invalid_body` / `invalid_message` | Mensagem vazia, maior que 2000, ou parâmetros inválidos |
| 400 | `expired_request` | Reenvio antigo expirado detectado ainda no banco |
| 401 | `unauthorized` | Access token GAME ausente/inválido/expirado |
| 403 | `forbidden` | Não participa da conversa ou conversa inválida para envio |
| 403 | `friend_required` | Amizade inexistente/removida ou bloqueio ativo |
| 405 | `method_not_allowed` | Método diferente de POST/OPTIONS |
| 409 | `idempotency_conflict` | Mesmo request_id com outro corpo ou conversa |
| 413 | `payload_too_large` | JSON maior que 8192 bytes |
| 429 | `rate_limited` | Limite de envios atingido |
| 503 | `game_unavailable` | Falha na validação pontual com GAME |
| 503 | `backend_unavailable` | Falha interna do banco CHAT |

Falhas devem ser tratadas sem exibir token, SQL, stack trace ou dados de outros jogadores. `429` não deve disparar retry imediato. `503` pode ser repetido com backoff, preservando `request_id`.

## Expiração e atualização

- **Retenção do banco:** mensagens ficam consultáveis por **menos de 24 h** (`sent_at > now() - 24h`); ao completar 24 h, desaparecem das leituras mesmo antes do job.
- **Exclusão física:** cron `qse-chat-ttl-24h` a cada 1 minuto. Exclui até 2000 mensagens e até 250 conversas antigas vazias por execução (em lotes, `SKIP LOCKED`). Registros de membros são excluídos por FK `ON DELETE CASCADE` quando uma conversa é removida.
- **Cache local Godot:** atual TTL de 15 minutos serve apenas para memória da UI; **não é** regra de retenção do banco.
- **Estratégia recomendada de atualização na 16B:** ao abrir uma conversa, fazer `messages`; durante a tela de conversa aberta e com app em foco, **polling moderado de 10–15 segundos**, mais atualização imediata após um envio e ao voltar ao foco. Pausar polling ao sair/ocultar conversa, suspender durante ausência de rede e aplicar backoff em 429/503. Deduplicar por `id`. Evitar polling por conversa fechada. Este polling **não está implementado no Godot** nesta T16A.
- **Ainda NÃO implementado:** chat em grupo, push, Realtime, mensagens não lidas, cursor/paginação, edição/apagamento individual, nicknames retornados pelo CHAT, anexo, indicadores de digitando e entrega/leitura.

## Custos e segurança

- `open_direct`: 1 chamada GAME `qse_chat_can_message` + até 2 gravações CHAT.
- `list`: 0 consultas GAME, até 2 consultas CHAT.
- `messages`: 1 validação GAME + leitura de membros CHAT + 1 RPC CHAT de leitura/TTL.
- `send`: 1 validação GAME + leitura de membros CHAT + **1 RPC CHAT atômica** para idempotência, rate limit e gravação. **Não há cache positivo de amizade**, para evitar que remoção ou bloqueio permitam envio no intervalo de cache. O ganho atual é por consulta GAME direcionada e redução de operações CHAT, não por eliminação completa da chamada GAME.
- O CHAT não contém contas paralelas nem conhece o nickname; amizade e bloqueios pertencem ao GAME. A tabela `qse_v3.chat_blocks` e as RPCs `qse_chat_can_message`, `qse_chat_block` ficam no GAME.
- Tabelas CHAT têm RLS ativo **sem policies diretas para anon/authenticated**; RPCs especiais aceitam somente `service_role` injetada no gateway, nunca no aplicativo.
- Este contrato descreve o **código implantado**; cobertura de testes de rede e múltiplos usuários deve ser lida no relatório `docs/backend/T16A_TESTES.md` (não presumir aprovação sem evidência).


### Uso técnico com o adaptador HTTP existente (sem alterar o Godot na 16A)

O cliente `SupabaseClient` atual aceita `request(path, method, body, authenticated, token_override)`.
Na implementação 16B, configurar `chat_client.connection = "chat"` e usar a chamada **sem sessão CHAT**:

```gdscript
var result = await chat_client.request(
    "/functions/v1/qse-chat-gateway",
    HTTPClient.METHOD_POST,
    {"action": "list"},
    false,
    game_access_token
)
```

O parâmetro `false` evita procurar sessão no CHAT; `token_override` envia o JWT válido **GAME** no cabeçalho Authorization. `apikey` é a chave **publicável CHAT** já configurada no adaptador. O trecho é **exemplo documental**, NÃO código integrado nem aprovado em Godot. `request_id` é obrigatório nas chamadas de envio.

## Orientação para Claude / Tarefa 16B

Usar **somente** estas 4 ações e o formato acima. Utilizar o JWT de sessão GAME já obtido pelo jogo; não criar sessão CHAT, não enviar `sender` no request, não armazenar JWT no disco. O gateway CHAT substitui acesso direto a qualquer `qse_chat_*` da Data API. Manter o chat visualmente desligado até o usuário aprovar a 16B.
