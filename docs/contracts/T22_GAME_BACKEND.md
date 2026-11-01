# T22 — Contrato GAME implantado (Configurações + Amizades)

Projeto **GAME**: \`shuzporktifgiotvnpbz\`. Nunca implantar no CHAT ou CATALOG.
A API existente de perfis mantém **exatamente cinco chaves**:
\`user_id\`, \`public_id\`, \`nickname\`, \`equipped_character_id\`, \`level\`.
Os campos da T22 aparecem FORA dos objetos de perfil. Todas as RPCs usam o JWT do GAME,
papel \`authenticated\`; em ausência de sessão, \`qse_v3.require_user()\` lança \`not_authenticated\` (SQLSTATE 42501).

## RPCs de amizades

| RPC | Parâmetros | Resposta JSON / erros |
|---|---|---|
| \`qse_friend_action\` (legada) | \`p_action text,p_target uuid,p_request_id uuid\` | **Idêntica à T05**, encaminha para a assinatura nova com mensagem nula; \`{"status":"applied"|"noop"}\` ou \`{"error":"invalid_friend_request"|"player_not_found"|"incoming_request_exists"|"rate_limit"|"request_not_found"|"idempotency_conflict"}\` |
| \`qse_friend_action\` (T22) | \`p_action text,p_target uuid,p_request_id uuid,p_message text\` (opcional no **cliente**, enviar null se ausente; assinatura de quatro parâmetros **sem DEFAULT**) | Mesmos resultados + \`invalid_message\` (mensagem até 140 caracteres, apenas em \`send\`). Mensagem não vazia é parte da chave de idempotência. |
| \`qse_friends\` | sem parâmetros | \`{"friends":[<perfil-5>],"incoming":[<perfil-5>],"outgoing":[<perfil-5>],"requests":{"<outro-user_id>":{"message":null|"texto","requested_at":"ISO"}},"presence":{"<amigo-user_id>":{"status":"offline"|"online"|"in_match","last_seen_at":null|"ISO"}}}\`. Perfis internos não são modificados. |
| \`qse_mutual_friends\` | \`p_target uuid\` | \`{"count":N,"players":[<perfil-5>,…]}\` no máximo cinco; \`invalid_player\`, \`player_not_found\` se alvo inacessível/não descobrível. |
| \`qse_player_suggestions\` | \`p_limit int DEFAULT 10\` (1–20) | \`{"players":[<perfil-5>,…],"mutual_counts":{"<user_id>":N}}\`. Somente amigos de amigos descobríveis, exclui conexões/pedidos existentes; \`invalid_limit\`. |
| \`qse_recent_matches_with\` | \`p_player uuid,p_limit int DEFAULT 10\` (1–20) | \`{"count":N,"matches":[{"match_id":"uuid","room_id":"uuid","played_at":"ISO"},…]}\`; conta apenas partidas **finalizadas** compartilhadas e limitadas a \`p_limit\`; \`invalid_player\`, \`player_not_found\`, \`invalid_limit\`. |
| \`qse_friend_stats\` | \`p_friend uuid\` | \`{"matches_together":N,"last_played_at":null|"ISO"}\`, dados entre amigos aceitos; \`invalid_player\`, \`not_friends\`. Sem estatísticas de vitória inventadas. |
| \`qse_presence_heartbeat\` | sem parâmetros | \`{"status":"online"|"in_match","last_seen_at":"ISO"}\`. Atualiza apenas a própria preferência por \`auth.uid()\`. \`in_match\` calculado pelo servidor, não confiado ao usuário. |

A presença do \`qse_friends\` é **legível somente para amigos confirmados**.
Status \`offline\` se último heartbeat exceder 90 segundos. Para presença
**Realtime** (\`online\` e \`in_match\`), o Godot ainda deve publicar os estados
em um canal Supabase Presence privado/adequadamente autorizado e manter o
heartbeat econômico (não a cada frame). A existência da coluna/RPC NÃO significa
que a publicação em Presence pelo cliente esteja implementada. Nenhum dado fictício.

## Convites entre amigos

| RPC | Parâmetros | Resposta / erros |
|---|---|---|
| \`qse_duel_invite_send\` | \`p_room uuid,p_friend uuid\` | Só ADMIN da sala ainda aberta, só amizade confirmada, valida kicks e membro admin. \`{"status":"sent","room_id":"uuid","expires_at":"ISO"}\`; erros \`invalid_invite\`, \`not_friends\`, \`forbidden\`. **Não retorna token ao remetente.** |
| \`qse_duel_invites_between\` | \`p_friend uuid\` | Array \`[{"room_id":"uuid","room_name":"nome","sent_by":"uuid","created_at":"ISO","expires_at":"ISO","token":"hex-48"}]\`. Chave \`token\` aparece **somente** quando o chamador é o DESTINATÁRIO. Para o remetente a chave é omitida. Erros \`invalid_player\`, \`not_friends\`. Mostra só convites válidos e de sala aberta. |
| \`qse_duel_invite_join\` | \`p_token text\` | Compatível com token global T16D e agora com token privado T22. Token privado só autentica o usuário convidado, com amizade e admin válidos; após verificação chama \`qse_duel_join\` e retorna o snapshot original do Duelo; \`invalid_invite\` ou erros existentes de entrada (\`kicked\`,\`room_full\`,\`room_closed\`). |
| \`qse_duel_invite_create\` | \`p_room uuid,p_minutes int DEFAULT 60\` | **Sem modificações:** link global de sala do administrador continua funcionando. |

Tokens privados são armazenados em \`qse_v3.duel_friend_invites\` (schema interno),
RLS ativo, sem concessões de SELECT/UPDATE/INSERT diretos a \`anon\` ou
\`authenticated\`, vencimento de 60 minutos. Gerar novo convite para o mesmo
par sala/destinatário substitui o antigo. Nunca colocar o token em logs.

## Conta e segurança — MFA TOTP

Conforme [documentação oficial Supabase](https://supabase.com/docs/guides/auth/auth-mfa/totp),
a API de TOTP é suportada por padrão no Supabase Auth. **O backend não precisa
de tabela nem migration de MFA**. A autenticação pertence APENAS ao Auth do GAME.

O cliente Godot ainda precisa integrar os endpoints oficiais de fatores do
Supabase Auth sob JWT do usuário:
1. \`enroll\` com \`factor_type:"totp"\` → \`factor_id\`, QR e segredo, mostrar apenas
   ao próprio usuário (não salvar ou registrar);
2. \`challenge\` sobre o \`factor_id\` → \`challenge_id\`;
3. \`verify\` com \`challenge_id\` e código TOTP → sessão AAL2;
4. Em logins futuros, \`listFactors\`/AAL e novo \`challenge\`+\`verify\`;
5. Gerenciar fatores com \`unenroll\` mediante sessão AAL2.

Verificar no dashboard **GAME > Authentication > Multi-Factor Authentication** que
Enrollment e Verification não estejam desabilitados. Nenhuma chave de Auth ou
\`service_role\` vai para Godot. Alteração de senha por \`updateUser\` permanece só
para conta de e-mail, após a reautenticação exigida pelo provedor.
**Sem autenticação real e interface TOTP não declarar MFA "testado".**

## T21 — auditoria estrutural do GAME

- \`public.qse_creator_cards\` possui \`deck_id\` (FK composta para deck+owner),
  \`position\` (inteiro 0–29) e \`id\` UUID chave primária. Aceita UUID enviado no INSERT,
  e o \`ON CONFLICT (id)\` possui alvo válido. Controle de dono via RLS SELECT/INSERT/UPDATE.
- \`qse_deck_favorites\`: UNIQUE PRIMARY KEY \`(user_id,deck_ref)\`; INSERT,
  SELECT e **UPDATE RLS** disponíveis após esta T22 para \`on_conflict=user_id,deck_ref\`.
  Referências de deck creator são restritas a decks próprios.
- \`qse_user_music_selection\`: PRIMARY KEY \`(user_id)\`; INSERT+SELECT+UPDATE
  por dono, suporta \`on_conflict=user_id\`.
- Bucket privado \`qse-deck-originals\`: MIME \`image/png\`, \`image/jpeg\`,
  \`image/webp\`, arquivo até 12 MiB. Políticas permitem
  \`<user_id>/<deck_id>/<card_uuid>_original.png|jpg|jpeg|webp\` e derivados
  \`_library.png\`, \`_duel.png\`. Storage upsert dispõe de SELECT+INSERT+UPDATE.
- São verificações de esquema/políticas. Upload real do Android e upsert com JWT
  de usuário precisam de teste ponta a ponta — não foram simulados como sucesso.

## Verificações e limites

- GAME: RLS habilitado, assinatura antiga da amizade preservada, funções novas
  com \`EXECUTE\` a authenticated e não a anon, nova tabela privada sem acesso direto.
- CHAT e CATALOG: **não alterados**.
- Segurança: migrations novas de T22 usam \`SECURITY DEFINER\` em RPCs que validam
  a identidade pelo GAME e restrições explícitas; revisar periodicamente os
  avisos do linter. [Linter para funções privilegiadas](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable).
- **Pendente:** testes HTTP com duas sessões reais, e UI/rede de presença/MFA.
