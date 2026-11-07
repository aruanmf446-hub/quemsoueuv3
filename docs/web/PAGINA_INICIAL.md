# Página inicial e domínio quemsoueu.cards

- `web/site/` é a página inicial (SEO, plataformas, perguntas). Ela **não carrega o motor**.
- O jogo é exportado em `/jogar/` (`deploy-web.yml`), com o PWA (`manifest` com `start_url`/`scope` relativos `./`).
- Convites (`?invite=`), retorno de pagamento (`?coin_order=`), retorno de login (`#access_token=`)
  e o PWA antigo instalado na raiz são encaminhados para `jogar/`.
- Padrão visual: habilidade `.agents/skills/qse-web-design`. Verificação: `python3 tools/web/check_site.py web/site`.
- Windows (.exe) e Android (.apk) aparecem como "Em breve" até existir build publicado.

## Ativar o domínio (quando o DNS estiver pronto)

1. No registrador de `quemsoueu.cards`:
   - `A` @ → `185.199.108.153`, `185.199.109.153`, `185.199.110.153`, `185.199.111.153`
   - `AAAA` @ → `2606:50c0:8000::153`, `2606:50c0:8001::153`, `2606:50c0:8002::153`, `2606:50c0:8003::153`
   - `CNAME` www → `aruanmf446-hub.github.io`
2. GitHub → Settings → Pages → Custom domain: `quemsoueu.cards` → Save → marcar **Enforce HTTPS**.
   (Com Pages por Actions, o domínio é configurado aí; um arquivo `CNAME` no build é ignorado.)
3. Supabase GAME → Auth → URL Configuration: adicionar `https://quemsoueu.cards/**` às Redirect URLs
   e, se quiser, trocar o Site URL para `https://quemsoueu.cards/jogar/`.
4. Pagamentos: `GAME_ORIGIN`/`GAME_RETURN` em `supabase/game/functions/_shared/stripe.js`
   apontam para o github.io; atualizar para `https://quemsoueu.cards/jogar/` (sessão de pagamentos).
5. Google Search Console: verificar o domínio e enviar `https://quemsoueu.cards/sitemap.xml`.
