---
name: qse-web-design
description: Criar e revisar as páginas HTML do Quem Sou Eu (página inicial de quemsoueu.cards, downloads, SEO, páginas fora do motor) no mesmo padrão visual aprovado do jogo. Use junto com qse-visual-polish sempre que mexer em web/site, web/shell.html ou qualquer página pública.
---

# Design das páginas web do Quem Sou Eu

As páginas web são a porta de entrada do jogo. Elas seguem **o lobby atual do jogo**,
não uma identidade nova. Atenção: `docs/referencias/menu/DIRECAO_CLEAN_APROVADA.png`
está **desatualizada** (o dono avisou em 2026-11-07). A referência é sempre a captura
real mais recente do lobby — hoje `docs/evidence/proporcoes-controles/lobby_1920x1080.png`
(navegação HISTÓRIA · MATA-MATA · PERSONAGENS · BIBLIOTECA · AMIZADES · AJUSTES). Na
dúvida, gere uma captura nova com `tests/responsive/capture_all.gd`. O pedido atual do dono prevalece; esta habilidade padroniza
qualidade e evidências.

## Antes de mexer

1. Leia `AGENTS.md`, `docs/referencias/README.md` e a habilidade
   [`qse-visual-polish`](../qse-visual-polish/SKILL.md).
2. Abra a captura mais recente do lobby e uma captura atual da página que vai mudar.
3. Se a referência ou o pedido estiver ambíguo, pergunte antes. Não infira aprovação.

## Fonte única dos tokens

Os valores vêm de `scripts/ui/player_ui.gd`. Na web eles ficam **só** em
`web/site/site.css` (`:root`). Se um valor mudar no jogo, mude nos dois lugares.

| Token CSS | Origem em `PlayerUI` | Valor |
|---|---|---|
| `--bg` | `INTERIOR_BG` | `#111820` |
| `--gold` | `GOLD` | `#e9b975` |
| `--gold-bright` | `GOLD_BRIGHT` | `#f2cd94` |
| `--text` | `TEXT` / `TITLE_GOLD` | `#f6f3e9` |
| `--muted` | `MUTED` | `#a9b1bb` |
| `--ink` | `INK` (texto sobre dourado) | `#151e25` |
| `--panel` | `PANEL_BG` | `rgba(9,13,17,.82)` |
| `--border` | `PANEL_BORDER` | `#28323c` |
| `--surface` / `--surface-hover` | `SURFACE` / `SURFACE_HOVER` | `rgba(23,29,36,.78)` / `rgba(36,42,48,.9)` |
| `--field-border` | `FIELD_BORDER` | `#3a444d` |
| `--radius` | `style_button` | `6px` (painéis `8px`) |

Fonte: `interface.woff2`, subconjunto latino da mesma `interface.ttf` (DejaVu, licença
em `assets/desert/phase01/FONT_LICENSE.txt`). Gere de novo com fontTools quando faltar
um caractere. Não use fontes externas.

## Composição (igual ao lobby)

- **Uma ação principal**: botão dourado sólido, texto em `--ink`, caixa alta, ícone à
  esquerda (como **JOGAR** no lobby). Ações secundárias usam `--surface` com borda
  `--border`; dourado só indica prioridade ou seleção.
- Hierarquia do lobby: rótulo pequeno em dourado e caixa alta (ex.: "MODO HISTÓRIA"),
  título grande claro em caixa alta, texto de apoio em `--muted`.
- A arte oficial (`bg_lobby_fantasia`, logo, personagens) é protagonista **só na
  página inicial**. Seções internas e páginas secundárias usam fundo sólido `--bg`,
  como as telas internas do jogo. Não aplique véu translúcido sobre tudo.
- Navegação leve no topo: logo à esquerda, poucos links em caixa alta.
- Nada de brilhos, filetes, sombras ornamentais, gradientes chamativos ou caixas dentro
  de caixas. Não corrija composição ruim com decoração.
- Ícones de plataforma (Windows, Android, Apple, navegadores) são SVG monocromáticos
  inline em `currentColor`, todos no mesmo tamanho e espessura visual. Não use os logos
  coloridos das marcas nem imagens remotas.
- Estado indisponível ("Em breve") é desativado de verdade (`aria-disabled`, sem link),
  com o selo discreto em `--muted`. Nunca simule um download que não existe.

## Regras técnicas

- **A página inicial não carrega o motor.** Nada de `index.js`, `.wasm`, `.pck` ou
  service worker do jogo fora de `/jogar/`. O jogo só começa quando a pessoa entra.
- Caminhos **relativos** (`jogar/`, `img/...`), para funcionar tanto em
  `aruanmf446-hub.github.io/quemsoueuv3/` quanto em `quemsoueu.cards/`.
  URLs absolutas só em `canonical`, `og:*`, JSON-LD e `sitemap.xml`
  (`https://quemsoueu.cards/`).
- SEO: `title` e `description` únicos, `canonical`, Open Graph/Twitter com `img/og.jpg`
  (1200×630), JSON-LD `VideoGame`, `lang="pt-BR"`, um único `h1`, texto real em HTML
  (não em imagem), `robots.txt` e `sitemap.xml` atualizados.
- Sem bibliotecas nem CDN. CSS em `site.css`, JS mínimo e opcional: a página precisa
  funcionar com JS desligado.
- Imagens em WebP com `width`/`height` definidos; a arte de fundo tem versão 960px para
  telas pequenas. Mantenha a página inicial abaixo de ~600 KB na primeira carga.
- Acessibilidade: contraste AA, foco visível em dourado (`outline` 2px como o foco do
  jogo), `alt` nas imagens, alvos de toque ≥ 44px.
- Links de convite antigos (`/?invite=...`) são encaminhados para `jogar/?invite=...`.

## Verificação antes de entregar

1. `python3 tools/web/check_site.py web/site` (estrutura, SEO, ausência do motor).
2. `python3 tools/web/check_pwa.py <build>/jogar` quando o build mudar.
3. Capturas reais com Playwright em **1672×941**, **844×390**, **640×360** e retrato
   **390×844**, sem rolagem horizontal nem texto cortado. Compare lado a lado com a
   captura mais recente do lobby.
4. Não declare validação em aparelho físico a partir de captura de navegador headless.
