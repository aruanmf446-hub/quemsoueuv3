# Quem Sou Eu V3 — CHAT das salas online / convite temporário — contrato v1 (T16D)

**Escopo:** somente backend. **Implantado no Supabase:** GAME `shuzporktifgiotvnpbz` e CHAT `wurkpjgnbqklivjhcvxk`. **Nenhuma tela Godot foi modificada nesta tarefa.** Base do chat privado: [CHAT_API_V1.md](CHAT_API_V1.md).

## 1. CHAT — Edge Function existente (v5)

`POST https://wurkpjgnbqklivjhcvxk.supabase.co/functions/v1/qse-chat-gateway`

Cabeçalhos:
```http
Content-Type: application/json
apikey: <CHAVE_PUBLICAVEL_CHAT>
Authorization: Bearer <ACCESS_TOKEN_DE_SESSAO_GAME>
```

A identidade é extraída pelo gateway **somente** do JWT válido do GAME. `verify_jwt=false` na configuração de implantação porque a função valida o JWT do GAME. Não criar usuários/contas no CHAT; não enviar `sender_game_user_id` para autenticação. Payload máximo **8192 bytes**. `OPTIONS` tem CORS e retorna 204.

### `open_room` — abrir chat da sala existente no GAME

```json
{"action":"open_room","room_id":"<UUID_INTERNO_DA_SALA_GAME>"}
```
HTTP 200:
```json
{"conversation_id":"<UUID_DO_CHAT_DA_SALA>"}
```

O gateway chama a RPC do GAME `qse_duel_chat_access(p_room)` usando o token autenticado. Somente jogadores e espectadores **atualmente presentes** em `qse_v3.duel_members`, não expulsos e com `duel_rooms.status` igual a `lobby` ou `in_match`, são autorizados. Nunca aceitar apenas o ID informado pelo cliente como prova de participação.

O CHAT cria/reutiliza **uma única** conversa `kind='room'` com `game_room_id` referenciando logicamente o UUID do GAME. Não cria cópia da tabela `duel_members` e não grava membros em `qse_chat_members` para conversas room.

### `messages` — mesma ação existente, agora para direct e room

```json
{"action":"messages","conversation_id":"<UUID_DO_CHAT_DA_SALA>"}
```
HTTP 200:
```json
{"messages":[{"id":"<UUID>","sender_member_id":"<UUID_PUBLICO_DE_MEMBRO>","sender_name":"Jogador","is_you":false,"body":"Boa partida!","sent_at":"2026-10-30T20:00:00+00:00"}]}
```

**Identidade dos remetentes da sala (gateway v5):** `sender_member_id` corresponde a `room.members[].member_id` no snapshot do Duelo, e `sender_name` é o nickname atual do participante. `is_you` identifica mensagens do usuário autenticado. Nenhum `sender_game_user_id` é retornado para chats de sala. Se o autor saiu da sala, `sender_member_id=null` e `sender_name="Ex-participante"`. Os IDs privados do GAME são usados apenas internamente no gateway. O CHAT privado de Amigos conserva o contrato v1 e não foi alterado.

O GAME devolve ao gateway uma lista de participantes autorizados usando **tags SHA-256 por sala**, `member_id` e nickname. A resposta da RPC `qse_duel_chat_access` não entrega `user_id` aos jogadores. A associação dos remetentes é feita somente no gateway, sem segunda consulta ao GAME.

Para `kind='room'`, o gateway consulta novamente o GAME antes de chamar `qse_chat_room_read`. Máximo de 50 mensagens, mais recentes primeiro. O banco exclui **do resultado** qualquer mensagem enviada há 24 horas ou mais, mesmo se o cron ainda não tiver apagado fisicamente. Se o membro sair, for expulso ou a sala fechar, a leitura passa a ser recusada na próxima requisição. Espectadores autorizados possuem as mesmas permissões de chat.

### `send` — mesma ação existente, agora para direct e room

```json
{
  "action":"send",
  "conversation_id":"<UUID_DO_CHAT_DA_SALA>",
  "request_id":"<UUID_UNICO_DA_INTENCAO_DE_ENVIO>",
  "body":"Boa partida!"
}
```

HTTP 200:
```json
{"message":{"id":"<UUID>","sent_at":"2026-10-30T20:00:00+00:00"},"duplicate":false}
```

Mesma autorização AO VIVO no GAME antes de chamar `qse_chat_room_send`. Texto entre 1 e 2000 caracteres após trim. Limite **global por remetente**: 20 mensagens em 60 segundos, somando mensagens diretas e salas. A chave de idempotência `(sender_game_user_id,client_request_id)` é única entre os dois tipos, e a transação usa bloqueio por usuário. Em retry, manter exatamente o mesmo `request_id`, conversa e corpo; `duplicate=true` se já persistido.

### `list` — preservado

`{"action":"list"}` continua listando **somente conversas privadas diretas**. Salas de Duelo NÃO são incluídas em `list`. Abrir o chat da sala ativa com `open_room` após o GAME informar o identificador interno da sala.

### Erros adicionais de sala

| HTTP | Código | Significado |
| --- | --- | --- |
| 400 | `invalid_room` | `room_id` ausente/não UUID |
| 403 | `room_access_denied` | Não membro, expulso, saiu, sala fechada ou inexistente |
| 503 | `game_unavailable` | Não foi possível validar participação no GAME |
| 403 | `forbidden` | Conversa room inexistente/inválida no CHAT |

As demais respostas e os erros `unauthorized`, `invalid_request_id`, `invalid_body`, `rate_limited`, `idempotency_conflict` e `backend_unavailable` seguem [CHAT_API_V1.md](CHAT_API_V1.md). Nenhuma mensagem, nickname ou metadado de outra sala é revelado nas recusas.

## 2. GAME — Convites com token (RPCs ADITIVAS, sem modificar qse_duel_* atuais)

Endpoint GAME: `POST https://shuzporktifgiotvnpbz.supabase.co/rest/v1/rpc/<FUNCAO>`

Usar `apikey: <CHAVE_PUBLICAVEL_GAME>`, `Authorization: Bearer <JWT_GAME>` e `Content-Type: application/json`.

**Criar convite** (`qse_duel_invite_create`):

```http
POST /rest/v1/rpc/qse_duel_invite_create
```
```json
{"p_room":"<UUID_DA_SALA>","p_minutes":60}
```
Sucesso HTTP 200:
```json
{"token":"<48_CARACTERES_HEXADECIMAIS>","expires_at":"<TIMESTAMP_UTC>"}
```

Somente **administrador atual e membro não expulso** da sala ativa pode criar convite. `p_minutes` opcional: padrão 60, mínimo 5 e máximo 1440 (24h). Token secreto aleatório de **192 bits**, armazenado no GAME só como SHA-256. Gerar convite novo **invalida o anterior** na mesma sala. Não expor token em logs/analytics. A resposta contém o token apenas na geração e é responsabilidade do cliente construir o link.

**Entrar por convite** (`qse_duel_invite_join`):

```http
POST /rest/v1/rpc/qse_duel_invite_join
```
```json
{"p_token":"<TOKEN_DO_LINK>"}
```

Sucesso retorna o **mesmo snapshot** já retornado pela RPC existente `qse_duel_join(p_code)`, pois o backend delega a ela após validar o token. Também preserva as regras de sala fechada, expulso, cheia, entrada como espectador durante partida, equipamento e mudança de sala.

Respostas de erro (HTTP pode ser 200 com `{"error":"..."}`, como nas RPCs existentes):
- `invalid_invite`: token inválido, malformado, antigo/rotacionado ou expirado.
- `forbidden`: quem tenta criar não é administrador válido.
- `room_closed`, `room_full`, `kicked` e demais códigos de `qse_duel_join` quando o token era válido, mas a entrada não é permitida.

### Formato de link / URL amigável

**NÃO existe rota universal/deep-link implantada pelo backend.** O GAME entrega apenas o token; a camada web/app deverá definir uma origem oficial e uma rota de ingresso, por exemplo `https://<ORIGEM_OFICIAL>/join?invite=<TOKEN>`, que chama `qse_duel_invite_join` após login. **Nunca** incluir o UUID da sala na URL de convite. O exemplo não deve ser publicado como URL real antes de configurar o roteamento no Godot/Web/Android. O código curto legado `qse_duel_join(p_code)` continua funcionando, sem alteração.

## 3. Autorização, ciclo de vida e atualização

- O GAME é fonte única de autenticação, membros atuais, expulsões e status da sala.
- O CHAT armazena somente `game_room_id` (referência lógica), mensagens e metadados. Sem acesso direto pelo Godot às tabelas CHAT; RLS permanece habilitado e RPCs internas só para `service_role`.
- Revalidar no GAME em **toda** abertura, leitura e envio de chat da sala, sem cache positivo de participação; o banco CHAT não consegue manter transação atômica entre projetos. Há uma janela de corrida entre verificação GAME e gravação CHAT, a ser considerada nos testes de integração. Nenhuma garantia de revogação instantânea entre dois bancos.
- Uma sala fechada passa a **negar novas leituras/envios** mesmo que mensagens antigas ainda estejam no armazenamento; dados são excluídos por retenção de 24h através do cron existente `qse-chat-ttl-24h`.
- Para atualizar o painel da batalha: fazer `open_room` ao entrar numa sala válida, chamar `messages` uma vez, depois polling **10–15 segundos somente enquanto o painel estiver aberto e o app no foco**, e atualizar após `send`. Suspender fora da sala. Deduplicar por `id`. Não há Realtime, push, `since`, indicador de digitando nem mensagens não lidas nesta versão.
- Se receber `room_access_denied`, ocultar conteúdo em memória e interromper polling imediatamente; ao sair da sala, limpar cache da conversa. Não salvar histórico em disco.

## 4. Estado de implantação e testes

Migrations GAME/CHAT aplicadas e gateway CHAT v5 implantado; novo mapeamento de remetentes foi implantado no GAME e no gateway. Somente verificações de SQL/metadata estão confirmadas; **não houve teste HTTP com dois jogadores reais** neste ambiente. Ver relatório [T16D_TESTES.md](T16D_TESTES.md). **Não ativar a interface para jogadores antes desses testes.**
