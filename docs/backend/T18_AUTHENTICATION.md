# T18 — Autenticacao GAME e tela de conta

## Escopo e isolamento
- Auth: somente \`shuzporktifgiotvnpbz\` (GAME).
- CHAT continua validando o JWT de GAME; nao recebe cadastro independente.
- CATALOG nao foi modificado.
- O cliente armazena o JWT apenas em memoria. Fragmentos Web de retorno Auth sao removidos via history.replaceState e usados somente apos verificacao com /auth/v1/user.
- T17 ?invite= preservado; ao usar um link de recuperacao, conclui primeiro a alteracao de senha, depois a navegacao ao Duelo.
- O perfil GAME nao deve ser criado por insercao manual: public.qse_profile_self chama qse_v3.ensure_player com o UID autenticado.

## Diagnostico fundamentado
- Antes da implementacao, no GAME havia 0 usuarios em auth.users e 0 perfis em qse_v3.player_profiles.
- auth_logs reais continham weak_password (422), validation_failed (400), invalid_credentials (400) e anonymous_provider_disabled (422).
- A implementacao antiga traduzia qualquer resposta nao-2xx de /auth/* para invalid_credentials. Isso ocultava a causa de falhas de cadastro.
- O retorno do signup com confirmacao de e-mail nao traz access_token e deve aparecer como confirmacao pendente, nao sessao logada.
- Renovacoes de JWT anteriores invocavam changed e resetavam dados de perfis, progresso, amizades e chat mesmo para o mesmo UID.

## Correcoes no cliente
- Validacao local, erro oficial GoTrue, mensagem distinta por codigo e sinalizacao de limites.
- /auth/v1/signup; /auth/v1/token?grant_type=password; /auth/v1/recover; /auth/v1/resend; /auth/v1/user (update de senha); /auth/v1/logout.
- Retorno Web de confirmacao/recovery/OAuth, /auth/v1/user para validar token antes de aceitar.
- Refresh de token rotacionado sem limpar o estado do jogador do mesmo UID; perda de rede ou rate limit agenda nova tentativa, nao logout artificial.
- /auth/v1/settings habilita Google, Apple e Discord somente se o provedor estiver de fato ativo; Steam nunca se apresenta como pronto. O fluxo OAuth atual e Web; Android requer deep link/PKCE para aprovacao.
- Backdrop do jogo e logo oficial continuam arquivos separados; componentes reais Godot com clique/toque/foco/hover, responsividade landscape. A referencia enviada continua sujeita a aprovacao visual.

## Configuracoes manuais no Supabase GAME
1. Authentication → Providers → Email: permitir signup e MANTER confirmacao de e-mail.
2. Authentication → URL Configuration: ajustar Site URL para https://aruanmf446-hub.github.io/quemsoueuv3/ e permitir como Redirect URL. Adicionar qualquer ambiente de teste explicito, nao destinos desconhecidos; o link Web usa redirect_to apontando para a mesma origem/path, podendo preservar o parametro invite.
3. Authentication → SMTP: para entrega real confiavel configurar SMTP de dominio remetente verificado (servico padrao tem limites baixos); verificar SPF, DKIM e provedores/caixa de entrada/spam. Nao alterar limites sem diagnostico.
4. Authentication → Email Templates: Confirm sign up e Reset password devem usar URLs reais de confirmacao/recovery (variaveis GoTrue). Se a template foi customizada, conferir o uso de RedirectTo.
5. Authentication → Logs / audit: verificar o evento verdadeiro e seu error_code, nunca registrar senhas/JWT.
6. Social: para Google, Apple e Discord cadastrar app/client_id/client_secret no provedor oficial e configurar callback https://shuzporktifgiotvnpbz.supabase.co/auth/v1/callback; verificar redirect do site e ativar cada provedor individualmente no GAME.
7. Steam: nao e um provider social oficial de primeira classe do Supabase Auth. Exige comprovacao de identidade Steam/OpenID no servidor com troca segura por sessao GAME, antes de ativar um controle.

## Testes e bloqueadores
- CI Godot 4.7.2 inclui smoke completo, regressao T17 e fixtures T18 de entradas validas/invalidas, pending confirmation, recuperacao, login, logout e refresh. NENHUM desses testes cria usuario real.
- Capturas de cena real 1920x1080 / 844x390 / 640x360 sao geradas em Actions com xvfb-run e anexadas como artefato t18-auth-real-interface-screenshots.
- Obrigatorio antes do merge: testador autorizado criar uma conta de teste no GAME com e-mail real proprio, confirmar link recebido, efetuar login, logout, recuperar senha, repetir com convite Web, verificar perfil automatico e duas contas no Duelo/CHAT.
- Tambem requer revisar design e configuracao de provedores no Dashboard. Sem essa validacao real, nao declarar cadastro definitivamente resolvido.

## Android
- Email/senha e comunicacao REST usam os mesmos endpoints do GAME, mas testes em dispositivo/SDK Android nao foram executados neste PR.
- Login social Google/Apple/Discord e recuperação via deep link Android nao foram habilitados: exige registro de package name, esquema/intent filter e validacao PKCE para retorno nativo seguro.
