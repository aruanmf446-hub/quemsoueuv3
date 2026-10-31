# T18C — Google e Discord OAuth auditado (31/10/2026)

## Fonte de verdade e preservação
- GAME: shuzporktifgiotvnpbz, URL https://shuzporktifgiotvnpbz.supabase.co. A URL no código coincide com o projeto ativo.
- CHAT: wurkpjgnbqklivjhcvxk; CATALOG: bsxicvlngphazesuzaee. Nenhuma alteração nem migração.
- O proprietário informa Google e Discord ENABLED, com Client ID/Secret e callbacks configurados. Conector Supabase não expõe Auth provider config/redirect allowlist; não confundir esta informação com confirmação independente.
- Leitura SQL GAME (31/10): 0 auth.users, 0 identidades Google, 0 Discord, 0 perfis. Eventos /auth/v1/callback observados nos logs, mas não comprovam uma sessão válida.

## Web — implementação feita nesta branch
- Google e Discord: ambos usam GoTrue /auth/v1/authorize com PKCE S256 e verifier criptográfico por Crypto.generate_random_bytes(32).
- O verifier fica no sessionStorage **da mesma aba** durante a autorização (JSON: provider, verifier, created; TTL de 10 minutos). O código OAuth nunca entra em logs e é removido da URL antes da troca por tokens.
- GoTrue recebe /auth/v1/token?grant_type=pkce (auth_code + code_verifier); identidade obtida exclusivamente por /auth/v1/user no GAME antes de estabelecer a sessão. Integração existente do lobby/convite/game services permanece.
- Erro de consentimento, expirado, ausência de verifier, navegador sem armazenamento, rede e callback inválido geram mensagens próprias; outro código recebido fora da aba não é aceito.
- A sessão Web passa a armazenar somente o refresh token rotativo (localStorage de origem do jogo, chave qse-v3:game:refresh), nunca access token. Em recarregamento retorna pelo grant refresh_token, repõe a sessão GAME e atualiza token rotativo no armazenamento. Logout remove o registro local imediatamente, invalidando no GAME quando online.
- Atenção: localStorage não é proteção criptográfica contra XSS. Revisar CSP, scripts terceiros, política de origem e segurança do site antes de declarar uma sessão Web persistida como imune a ataques. Não se aplica à persistência Android/Windows.
- Não migra identidades de projetos antigos nem tenta unir contas com mesmo e-mail automaticamente; são decisões de account linking distintas.
- O fluxo legacy implicit de recovery/confirm-email foi preservado, com validação de /auth/v1/user.

## Configuração manual dos provedores
1. Google Cloud Web Application: authorized redirect URI https://shuzporktifgiotvnpbz.supabase.co/auth/v1/callback; Testing/test users conforme política do Google.
2. Discord Developer Portal OAuth2: redirect URI igual ao callback GAME acima; perfil Discord deve ter e-mail disponível conforme provider/scopes configurados.
3. Supabase GAME Authentication / URL Configuration: Site URL https://aruanmf446-hub.github.io/quemsoueuv3/ e Redirect URLs permitindo essa origem/path com query invite para convite.
4. Supabase GAME Authentication / Providers: verificar Google+Discord ENABLED, sem copiar ou substituir os segredos preexistentes.
5. Teste manual autorizado: Web abrir jogo, Google, consentir, voltar ao lobby, identificar sessão GAME, nickname, carteira/skins/duelo; sair, repetir Discord; reload preserva login; convite ?invite=; saída total; testes de cancelamento.

## Android APK — mecanismo preparado, export ainda não habilitado
- OAuth browser usa OS.shell_open; retorno é via quemsoueuv3://oauth/callback com code ou error, verificador mantido em RAM e trocado com PKCE. O cliente tenta ler o intent recebido via AndroidRuntime ao recuperar foco.
- É **indispensável** adicionar ao Manifest real do APK um intent-filter BROWSABLE/DEFAULT ACTION_VIEW para scheme=quemsoueuv3 host=oauth path=/callback, com launchMode adequado e entrega do novo intent ao Activity (getIntent atualizado). Godot 4.7.2 pode requerer Gradle build e/ou plugin Kotlin para onNewIntent; esta branch não contém plugin Android assinado nem APK exportado.
- Só depois de validar manifesto+AndroidRuntime e URL allowlist do GAME, alterar data/backend/client.json oauth_android_deeplink_ready para true. Antes disso o botão social permanece desabilitado no APK.
- Atenção: custom scheme não é exclusivo do app e pode ser capturado por outros apps; para produção preferir Android App Links verificados com assetlinks.json e host HTTPS sob domínio controlado, com plano de PKCE completo.

## Windows EXE — mecanismo preparado, export ainda não habilitado
- OAuth browser usa OS.shell_open; retorno escuta HTTP em 127.0.0.1:49173/oauth/callback, com host/path exatos, timeout de 180 segundos, limite de requisição, resposta CSP e sem revelar tokens; PKCE protege contra injection.
- Supabase GAME deve permitir especificamente http://127.0.0.1:49173/oauth/callback na Redirect URLs. Verificar restrições do Windows Firewall/antivírus e a porta local.
- Depois da allowlist e teste real no EXE, definir oauth_windows_loopback_ready=true. Até lá botões sociais desabilitados no EXE; nenhum teste Windows nativo foi realizado.

## Persistência multiplataforma
- Web: refresh token rotativo em localStorage (config persist_session=true); logout remove a chave. Web são credenciais sensíveis, política de CSP e XSS continuam necessárias.
- Android: não há Android Keystore implementado; se o sistema matar o processo, exige novo login. Não salvar user://backend.cfg em texto puro.
- Windows: não há Windows Credential Manager/DPAPI implementado; reiniciar o EXE exige novo login. Preparar mecanismo seguro antes de guardar credenciais em disco.

## Resultado e critérios de aprovação
- Godot 4.7.2 smoke/PKCE offline/RFC7636/testes de convite e interface; nenhuma conta real criada ou usada automaticamente.
- Não foi possível auditar listas de allowlist e secrets pelo conector, nem executar testes OAuth com pessoa real, APK assinado, Windows EXE.
- PR exclusivo a partir de main; não fazer merge sem revisão e validações acima.