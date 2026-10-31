# T18B — Auditoria do login Google (31/10/2026)

## Projeto auditado — sem mutações
- GAME: shuzporktifgiotvnpbz; endereço https://shuzporktifgiotvnpbz.supabase.co. Confere com data/backend/client.json e com GAME_URL.
- CHAT/CATALOG não foram alterados. Nenhum usuário fictício ou chave privada criado.
- A captura do proprietário mostra Google ENABLED, mas isso não confirma login real, Client ID, allowlist e callback.
- Consulta SQL em GAME: 0 usuários e 0 identidades Google. Consulta de logs: /settings HTTP 200 e nenhum login Google comprovado.

## Código Web e correção proposta
- Botão Google consulta external.google em GET /auth/v1/settings e só ativa no navegador Web.
- Antes da T18B: fluxo implicit com token no fragmento. O jogo o removia da URL e validava em /auth/v1/user.
- T18B: Google usa PKCE S256 (RFC 7636), verifier criptográfico aleatório no sessionStorage da mesma aba.
- Callback ?code= é removido da URL antes de POST /auth/v1/token?grant_type=pkce com auth_code/code_verifier. O jogo preserva ?invite= e usa a sessão GAME.
- Nenhum Client Secret/Google ID Token no cliente. Não mostra error_description arbitrário de terceiros; erros recebem mensagens locais.
- Outros provedores não foram modificados.

## Verificação manual indispensável
1. Google Cloud Console / Google Auth Platform: Web application; Authorized JavaScript origin https://aruanmf446-hub.github.io e Authorized redirect URI https://shuzporktifgiotvnpbz.supabase.co/auth/v1/callback. Verificar lista de testadores se aplicativo estiver em Testing.
2. Supabase GAME / Authentication / URL Configuration: Site URL https://aruanmf446-hub.github.io/quemsoueuv3/ e Redirect URLs incluindo essa URL e a variação com ?invite=, com padrão estritamente limitado ao caminho do jogo.
3. Supabase GAME / Providers / Google: confirmar ativação e credenciais existentes sem copiar secrets.
4. Com sua própria conta Google autorizada: clicar Google no Pages, concluir consentimento, validar retorno sem code na URL, sessão GAME, criação/consulta de perfil, lobby, convite e logout. Não realizado nesta auditoria.

## APK e EXE
- Ainda não: social_available exige OS.has_feature('web') e o fluxo atual depende de JavaScriptBridge/sessionStorage.
- Android: navegador do sistema, retorno por App Link/deep link nativo, PKCE com armazenamento seguro, validação de sessão e teste APK real; registrar package/deep-link no projeto.
- Windows: navegador padrão OS.shell_open, retorno por loopback localhost protegido ou esquema URI registrado, PKCE e teste EXE real.
- Não embutir segredo Google nos executáveis nem copiar tokens via clipboard.

## Persistência
- data/backend/client.json contém persist_session:false. Access/refresh tokens ficam na RAM e o refresh funciona enquanto o processo está aberto.
- Para sobreviver ao fechamento, precisa de política e implementação por plataforma: Web storage da origem com proteção XSS/CSP e limpeza no logout; Android Keystore; Windows Credential Manager/DPAPI.
- A rotação do refresh token precisa ser persistida atomicamente; na restauração verificar a sessão via Supabase. Evitar texto puro em user://backend.cfg, GitHub ou logs.
- A T18B não alterou persist_session:false; exige aprovação de política de armazenamento antes de habilitar.

## Testes
- Teste offline RFC7636, URI de Google e convite, ausência do verifier no URL, mensagens de erro, não suporte desktop; CI Godot 4.7.2 com smoke e regressões T17/T18/T18A.
- Nenhuma conta real, e nenhuma sessão OAuth completa, foi testada. Não declarar Google Web aprovado até verificação autorizada.
- Branch exclusiva; PR para revisão; sem merge e sem alterações no Supabase.