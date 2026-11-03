# QUEM SOU EU V3 · T29 — Presentes para todas as contas

## Objetivo

Todas as contas GAME, **existentes e futuras**, recebem um pacote oficial gratuito. A primeira entrada elegível apresenta uma vitrine cinematográfica de resgate em **Novidades**. Depois de abrir, o jogador não recebe novo pedido de resgate e o pacote continua na conta, mesmo após sair, trocar de aparelho ou autenticar novamente. A campanha pode ser reaberta manualmente pelo menu de Novidades.

## Pacote desta campanha

**4 decks oficiais:** Lendas Urbanas, Nostalgia Web, Sol Nascente e Pinturas (37 cartas).
**7 skins iniciais:** Cowboy, Michelly, Rodrigo, Lorena, Gus, Lana, Halloween.

As sete skins já faziam parte do conjunto inicial, sem bloqueio de gameplay. T29 **registra a posse/recebimento dessas skins no catálogo de recompensas**, sem alterar os IDs ou criar skins fictícias. **El Fuego não está incluído**: sua obtenção permanece atrelada à conquista da História.

## Comportamento

1. O servidor atribui, automaticamente e com idempotência, os **11 itens** a todos os usuários existentes (retroativo) e a novos usuários (trigger em `auth.users`). Chave primária `(user_id,offer_id)` impede duplicação.
2. `public.qse_rewards_feed()` retorna `claimed=true` e `revealed=false` para as contas que receberam o pacote mas nunca abriram a apresentação.
3. Na primeira abertura da central, a campanha é registrada como vista (`qse_news_seen`). A tela mostra **RESGATAR PRESENTES** (abertura/celebração do pacote, não segunda concessão). Essa ação chama `public.qse_rewards_reveal(p_campaign_id)` e registra `qse_reward_reveals` por conta e campanha.
4. Após confirmar, a UI passa a mostrar **RESGATADO**. O botão de resgate do pacote some permanentemente e o anúncio não aparece automaticamente em logins posteriores. Mesmo quando o jogador fecha a vitrine antes de confirmar, não há reabertura automática repetitiva; pode concluir manualmente no botão **Novidades**.
5. Em troca de conta, o cache de recompensas é apagado e o usuário seguinte recebe apenas sua própria situação. Falha de rede nunca simula sucesso.
6. A Biblioteca continua exibindo decks públicos e exibe posse permanente em **Meus Decks**, sem misturar os dados de usuários.

## Supabase GAME

Migração versionada: `supabase/game/migrations/20261103030000_qse_t29_universal_free_gifts.sql`.

- `qse_reward_offers.auto_grant`: autoriza distribuição automática apenas de itens validados.
- `qse_reward_seed_user(uuid)` + trigger `qse_reward_new_account_grants`: concessão no cadastro.
- `qse_reward_reveals`: recibo permanente de abertura, protegido por RLS, sem acesso direto do cliente.
- `qse_rewards_feed`: expõe `revealed` e `claim_enabled`; não modifica tabelas.
- `qse_rewards_reveal`: idempotente, autenticada, grava o recibo de abertura e marca a notícia como vista.
- `qse_rewards_claim`: decks e skins iniciais existentes com verificação no GAME; para qualquer skin fora do elenco inicial, retorna `skin_claim_not_enabled` até uma integração real de inventário/progressão.

**Validação executada no GAME:** 9 contas x 11 ofertas = 99 concessões; teste transacional de conta nova (11/11 no cadastro) e teste de recibo + consulta + resgate repetido (ambos com rollback). Nenhum usuário de teste permaneceu cadastrado.

## Skins novas no futuro

**Não basta adicionar uma imagem ou criar uma oferta** para liberar skins novas. A validação de `PlayerContracts.valid_snapshot` e o protocolo `qse_progression_snapshot` seguem elenco fechado. A extensão futura deverá ampliar o inventário seguro do GAME, suas permissões e os snapshots. Só depois permitir resgates de novos IDs — sem conceder El Fuego e sem transformar skins não aprovadas em presentes. Novas campanhas devem ter ID próprio para o recibo não se confundir com a campanha atual.

## Aceitação

- Contas antigas e novas recebem a mesma coleção, sem inserir duplicatas.
- A primeira visita destaca o pacote e oferece a ação única de resgate/abertura.
- A segunda visita mostra apenas a posse já confirmada, sem solicitar resgate.
- Contas A e B não compartilham recibos nem estado.
- Offline e sessão inválida não permitem alterar posse localmente.
- El Fuego continua bloqueado pela História.
- Godot 4.7.2 headless e UI landscape.
