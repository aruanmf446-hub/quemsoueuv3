# QUEM SOU EU V3 · T28 — Novidades e resgates oficiais

**Estado da implementação:** backend GAME aplicado em `20261103013140`. Interface Godot em branch `work/recompensas-oficiais-novidades-t28`, sujeita aos testes do PR.

## Experiência aprovada / intenção

- Referência de linguagem visual: vitrines de atualizações e recompensas de jogos como Fortnite e eFootball, sem copiar marcas ou assets.
- Entrada única no lobby: **NOVIDADES**. Abre uma central com arte de destaque, campanha, decks, skins e botões contextualizados.
- Campanha inicial: **NOVOS DECKS OFICIAIS — 4 coleções · 37 cartas**, criados pela equipe Quem Sou Eu. Todos os quatro decks são gratuitos e não têm prazo de expiração.
- Resgate manual: **RESGATAR GRÁTIS** > confirmação do GAME > **RESGATADO** e seção **Meus Decks**. Nunca descontar moedas ou gemas.
- Nenhum resgate automático ou falso: catálogo público pode continuar navegável antes de resgatar, mas o selo de posse só aparece depois da confirmação do servidor.
- Uma campanha nova pode abrir automaticamente **uma vez por conta** quando a sessão, o perfil e o lobby estiverem prontos; registrar leitura em `qse_news_seen` ao abrir. Após a leitura, apenas o acesso manual. Troca de dispositivo não repete campanha já vista com conexão saudável. Falhas de rede não inventam sucesso.
- Não interromper login, recuperação de senha, convites, cadastro de nickname, gameplay ou telas internas.
- O carrossel anterior de notícias continua acessível pela nova central.

## Contrato GAME

- `public.qse_reward_campaigns`: campanhas oficiais, título, subtítulo, descrição, vigência e prioridade.
- `public.qse_reward_offers`: itens `deck` ou `skin`, gratuitos (preço zero), ordem e campanha.
- `public.qse_reward_claims`: posse individual, PK `(user_id,offer_id)`, nunca mutável pelo cliente.
- `public.qse_news_seen`: recibo de campanha visto por conta, PK `(user_id,campaign_id)`.
- `public.qse_rewards_feed()`: campanha ativa + ofertas + flag de resgate e de visualização só para `auth.uid()`.
- `public.qse_rewards_claim(p_offer_id)`: verifica sessão, oferta ativa, gratuidade, deck existente e idempotência; nunca confia em user_id recebido.
- `public.qse_rewards_mark_seen(p_campaign_id)`: registra abertura autenticada e campanha ativa.
- RLS ligada nas quatro tabelas. Sem acesso direto para `anon`/`authenticated`; somente as RPCs autenticadas e controladas pelo servidor.
- Migrado no GAME e versionado no repo: `supabase/game/migrations/20261103013140_qse_official_rewards_campaign_claims_20261102.sql`.
- Não alterar CATALOG nem os rascunhos dos jogadores para registrar posse. Não usar R2.

## Importante — skins

A estrutura aceita futuras ofertas do tipo `skin`, mas **nenhuma skin foi anunciada nem disponibilizada**. A função de claim rejeita o tipo `skin` (`skin_claim_not_enabled`) até existir um fluxo completo no protocolo GAME de desbloqueios. A regra atual do `PlayerContracts.valid_snapshot` aceita somente o elenco inicial e El Fuego por conquista; nunca contornar isso só alterando a UI ou uma tabela. **El Fuego permanece exclusivo do Modo História.**

## Limitação explícita atual

A posse de deck é persistida no GAME e aparece em Meus Decks, mas a exploração pública das cartas e os pools do Duelo ainda usam o catálogo compartilhado. Para criar exclusividade de uso por propriedade, atualizar a criação de salas e a validação do servidor; não apresentar essa restrição como pronta. Para estas coleções gratuitas, permitir a visualização pública é intencional.

## Testes de aceitação

1. Usuário A resgata um deck, vê `RESGATADO` e aparece em `Meus Decks`; usuário B não herda posse.
2. Repetir RPC de resgate retorna `already_claimed` e não cria outra linha.
3. Recarregar navegador / mudar de dispositivo mantém posse no Supabase.
4. Novidades aparecem automaticamente no máximo uma vez para a mesma campanha e usuário; o botão manual sempre abre.
5. Sem sessão, não há resgate nem vazamento de estado entre contas.
6. Sem conexão, mostrar erro; nunca marcar o item como resgatado.
7. Nenhuma skin ou El Fuego desbloqueado sem mecanismo de progresso autorizado.
8. Godot headless, Web landscape e Android landscape, telas compactas 640×360 e 844×390.
