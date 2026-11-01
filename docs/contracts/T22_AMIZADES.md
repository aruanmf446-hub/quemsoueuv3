# T22 — Pendências de backend para o ChatGPT (GAME)

O cliente Godot já mostra estas áreas com estado **indisponível** (sem dados inventados).
Quando o backend existir, basta preencher os campos abaixo; nenhum layout precisa mudar.
Regras: só `auth.uid()`, RLS por dono, nunca `service_role` no cliente.

## A. Amizades (tela T22)

Hoje `qse_friends` devolve `{friends, incoming, outgoing}` com perfis públicos de 5 campos
(`user_id, public_id, nickname, equipped_character_id, level`). Pedidos:

| Recurso na tela | O que falta | Sugestão de contrato |
|---|---|---|
| Recebidas → **Mensagem do pedido** | texto opcional no pedido | `qse_friend_action('send', target, request_id, p_message text ≤ 140)`; em `incoming`/`outgoing` incluir `request_message` e `requested_at` |
| Enviadas → **Detalhes do envio** ("enviada há 1 h") | data do pedido | `requested_at timestamptz` em `incoming`/`outgoing` |
| Recebidas/Buscar → **Amigos em comum** | contagem e lista | RPC `qse_mutual_friends(p_target uuid)` → `{count, players[≤5]}` (só perfis públicos já visíveis) |
| Amigos → **Convites pendentes** | convites de partida entre os dois | RPC `qse_duel_invites_between(p_friend uuid)` → `[{room_id, room_name, sent_by, created_at, token?}]` (token só para o destinatário) e envio direcionado `qse_duel_invite_send(p_room, p_friend)` |
| Presença **"Em partida"** e **"Offline há X min"** | estado e último visto | no canal de presença (Realtime) incluir `status: online|in_match` e uma coluna `last_seen_at` legível só por amigos |
| Buscar → **Jogaram recentemente** | histórico de partidas compartilhadas | RPC `qse_recent_matches_with(p_player uuid, limit)` |
| Buscar/Enviadas → **Jogadores parecidos / Sugestões** | motor de sugestão | RPC `qse_player_suggestions(limit)` (ex.: amigos de amigos), opt-out pelo `discoverable` |
| Amigos → **Ver estatísticas / partidas em que jogaram** | estatísticas entre os dois | RPC `qse_friend_stats(p_friend uuid)` |
| "Personagem favorito" das referências | não existe; hoje mostramos o **equipado** | se desejado: `favorite_character_id` no perfil público |

O cliente já faz de verdade: aceitar, recusar, cancelar, remover (com confirmação), adicionar,
buscar (`qse_find_players`), copiar ID público, abrir chat privado (só amigos) e **Convidar**
(gera o convite real da sala online do jogador com `qse_duel_invite_create` e envia o link pela conversa).

## B. Configurações (T22 anterior)

| Item da referência | Situação | Pedido |
|---|---|---|
| Verificação em duas etapas | indisponível | habilitar MFA (TOTP) no Auth do GAME e expor fluxo de enrolamento/desafio |
| Alterar senha | só contas de e-mail (`update_password`) | ok; Google/Discord continuam gerenciados pelo provedor |
| Cenas e diálogos (volume) | não existe áudio de diálogo no jogo | — (conteúdo, não backend) |
| Sensibilidade / inversão de eixos | o jogo não usa câmera livre | — |

## C. Decks (T21, já enviado em `T21_DECKS.md`)

Confirmar: colunas `deck_id`/`position` em `qse_creator_cards`; `id` gerado pelo cliente aceito
em insert/upsert; extensão real do original (`png/jpg/webp`) aceita no bucket. Publicação pública
continua desabilitada até moderação.
