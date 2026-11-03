# QSE — Editor de Conteúdo (T32)

## Entrada
- **Editor:** `https://aruanmf446-hub.github.io/quemsoueuv3/bots/editor/`
- **Monitoramento:** `/bots/` (protegido por PIN de conveniência, **não autoriza escrita**).
- **Autenticação do editor:** Supabase **GAME**, conta autorizada em `public.qse_editor_admins`. Google ID Token e e-mail/senha. A escrita é bloqueada por RLS até confirmar uma conta autorizada.

## Onde os dados são salvos
- Novidades e personalização dos decks oficiais: `GAME.public.qse_editor_content`.
- Imagens: bucket público `GAME.storage.qse-editor-media`, pasta `covers/<uuid>.webp|png|jpg`. **Não usar para conteúdo privado.**
- A lista original de decks e seus textos permanece no `CATALOG.public.qse_catalog_decks`; o editor **sobrepõe** título, descrição, subtítulo/categoria e capa somente quando uma linha `deck:<id>` está publicada.
- O GitHub recebe somente o **código do editor e do jogo**, não cada edição de conteúdo. O build Pages precisa ocorrer apenas quando o código muda.

## Fluxo do jogador
1. Ao iniciar ou reabrir a Biblioteca, `EditorContentService` lê dados publicados por GET anônimo ao GAME e renova após TTL de 45 s.
2. `DeckLibraryCatalog` compõe **local → CATALOG → GAME editorial**. Uma personalização desligada deixa os dados originais intactos. A biblioteca mostra capa remota nos cards e no banner; ao faltar rede ou imagem, preserva a arte local.
3. Novidades ativas aparecem no carrossel `Ver outras notícias do jogo` de `NewsOverlay`. Capas remotas são baixadas no Godot, com validação de caminho, tamanho e extensão; o carrossel tem imagens locais de fallback se estiver offline.
4. Publicações com IDs `news:<campaign_id>` também podem personalizar o texto e a capa do banner da campanha ativa **sem modificar** seus resgates.
5. O editor nunca altera `qse_reward_claims`, `qse_reward_offers`, `qse_news_seen` ou o inventário do jogador.

## Modelo
`qse_editor_content`: `id`, `kind` (news/deck), `title`, `subtitle`, `description`, `cover_path`, `active`, `priority`, `starts_at`, `ends_at`, `updated_at`, `updated_by`.

- `active=false`: a notícia desaparece; a personalização de deck deixa de ser aplicada, **mas o deck continua no catálogo**.
- O editor pode criar notícias, editar títulos/descrições e trocar capas. Todas as alterações exigem **Salvar e publicar**.
- Datas limitam a janela de publicação no banco (RLS). A prioridade ordena notícias.
- Tamanho máximo da capa: **8 MiB**, JPG/PNG/WebP.
- Não há crop/zoom persistido nesta versão; o Godot usa recorte central `KEEP_ASPECT_COVERED`.
- Apagar o conteúdo do bucket não faz parte do fluxo de edição; imagens antigas não são eliminadas automaticamente.
- O carrossel e a Biblioteca não fazem streaming de mudanças durante a partida; reler a tela ou reiniciar o jogo atualiza os dados, normalmente com até 45 segundos de cache.

## Segurança
- O **PIN** de `/bots/` (verificador PBKDF2 no Pages estático) não é autenticação de administrador.
- O editor usa a sessão GAME e verifica uma linha própria em `qse_editor_admins`; RLS recusa escrita de contas comuns.
- Os projetos GAME e CATALOG usam publishable keys diferentes e **não** trocam JWT.
- Não publicar `service_role`, `sb_secret_...` ou qualquer senha/token no JS ou no GitHub Pages.
- O banco GAME recebeu as migrações `qse_editor_content_admins_and_media` e `fix_editor_cover_path_validation`. O dono do projeto é identificado por conta GAME previamente verificada; não por username/PIN público.
- Para adicionar outro editor, utilizar o painel administrativo do Supabase com uma autorização explícita (UUID verificado) em `qse_editor_admins`. **Nunca** liberar qualquer usuário autenticado.
- O Google ID Token depende de a origem do Pages estar na lista de origens autorizadas no cliente OAuth Google já configurado para o jogo.

## Testes
- `python3 tools/bots/test_dashboard.py` e `node --check web/bots/editor/editor.js`.
- `godot --headless --path . --script res://tests/editor_content/verify.gd`.
- `Godot real headless smoke` testa a integração antes do merge.
- Em produção: autenticar como administrador, editar notícia, publicar, reabrir novidades no jogo, alternar visibilidade, trocar uma capa e validar fallback com rede desligada.

## Limites conhecidos
- Não confundir ocultar anúncio com desativar o **resgate**: as ofertas de presentes continuam sendo controladas pelas funções seguras existentes do GAME.
- O CATALOG mantém os dados originais dos decks; o editor não escreve nele para evitar conflito de identidades de dois projetos.
- O editor controla **metadados e capa do deck**, não as cartas internas, miniaturas de personagens ou as imagens originais do acervo.
