# T30 · Novidades e Resgatar Presentes — redesign aprovado

**Status:** implementação em `work/novidades-presentes-redesign-t30`. **Não fazer merge na main sem aprovação.**

## Interface Godot

A tela `NewsOverlay` foi recriada como modal responsivo sobre o **lobby real**. O cenário permanece visível acima e abaixo da janela; a camada externa translúcida bloqueia cliques na home, mas não reinicia o menu. Fechamento único pelo X, além de Escape e Voltar do Android.

Identidade: marinho/grafite, dourado, branco e cinza, reutilizando `PlayerUI.apply_theme`, `DeckCatalog` e `PlayerUI.portrait_texture`. Nenhuma imagem da referência foi usada como fundo do jogo.

Blocos: cabeçalho com presente, separador, novidades e X; banner real com imagem do deck ativo e gradiente; abas **Decks Grátis (N)** e **Skins (N)**; grid de 1 a 4 colunas; cards com imagem, tipo, título, contagem do catálogo, descrição, estado seguro. **Mais recentes/Mais antigos** só quando houver timestamp real para as ofertas. Rodapé com revelação única `OfficialRewardsService.reveal()` e carrossel legado `PresentationCarousel`.

Estados idempotentes: `INCLUSO NO PACOTE`, `RESGATADO`, `RESGATAR GRÁTIS`, `EM BREVE`. O servidor é autoridade de posse. Não há débito de moeda, desbloqueios locais, resgates falsos nem oferta do El Fuego.

## Leitura de recompensas de campanhas anteriores

**Necessidade técnica comprovada:** `public.qse_rewards_feed()` entrega somente a campanha de maior prioridade — Diva Pop — mas o GAME já associa aos usuários os quatro decks e as sete skins da T29. Sem uma consulta adicional, a interface mostraria apenas um deck e nenhuma skin, contrariando o inventário do jogador.

Por isso foi acrescentado **somente** `public.qse_rewards_inventory()`: RPC de **leitura**, vinculada estritamente a `auth.uid()`, com execução permitida a `authenticated` e revogada a `anon`/`PUBLIC`. Ela lê os registros de posse existentes e seus timestamps, sem alterar tabelas, RLS, triggers, campanhas, claims ou saldos. Versão SQL: `supabase/game/migrations/20261103042500_t30_readonly_rewards_inventory.sql`.

`OfficialRewardsService.refresh()` combina o feed ativo com o inventário, deduplicando pelos IDs das ofertas; se a leitura histórica falhar, apresenta apenas o feed atual com aviso, **nunca inventa posse**. Os recibos antigos são exibidos como propriedade confirmada; a ação única de revelar continua valendo apenas para a campanha atual.

**Teste backend:** duas contas distintas retornaram 12 ofertas cada (5 decks, 7 skins); sem JWT, a função nega acesso. Permissões: `authenticated=true`, `anon=false`, `PUBLIC=false`. O teste foi revertido em transação e não alterou usuários.

## Arquivos

- `scripts/ui/news_overlay.gd` — interface responsiva
- `scripts/services/official_rewards_service.gd` — agregação somente leitura
- `assets/icons/vector/icon_reward_gift.svg`, `icon_reward_deck.svg`, `icon_reward_skin.svg` — ícones autorais
- `tests/rewards_t30/flow_test.gd` — UI offline, 5 resoluções, estados, categorias, ordenação, carrossel, ausência de vazamento
- `tests/rewards_t30/capture.gd` — capturas reais do renderer com fixtures identificadas
- `.github/workflows/godot-smoke.yml` — Godot headless e artefato das imagens
- `tests/decks/library_flow.gd` — correção de expectativa após o quinto deck Diva Pop entrar na ordem A–Z, **sem eliminar as verificações**

## Evidências e restrições

O primeiro teste da nova tela passou 37 verificações com Godot 4.7.2 e gerou 8 imagens reais em `news-t30-godot-real-screens`, incluindo 1920×1080, 1672×941, 1280×720, 844×390 e 640×360. A primeira CI completa ainda falhou no teste legado da Biblioteca porque `decks[0]` passou a ser Diva Pop; foi corrigido sem remover testes, e a nova CI precisa confirmar o resultado.

As capturas utilizam **fixtures locais sem JWT**, sobre a cena real `scenes/menu/main_menu.tscn` — não equivalem a um teste de ponta a ponta com login real. Dados de produção continuam preservados.
