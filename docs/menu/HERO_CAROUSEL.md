# Hero cinematográfico do lobby (História / Mata-Mata / Biblioteca)

## Referências aprovadas pelo proprietário
Três ilustrações 16:9 enviadas na conversa em 04/11/2026, cada uma contendo seu próprio menu, logo, descrição, botão principal, setas e arte. Não são três banners empilhados.

## Assets exigidos
Adicionar ao repositório com os **nomes exatos**:
- `assets/menu/hero/hero_historia.webp`
- `assets/menu/hero/hero_mata_mata.webp`
- `assets/menu/hero/hero_biblioteca.webp`

Arquivos fonte: ilustrações aprovadas de 1536×864 (História e Mata-Mata) e 1672×941 (Biblioteca); preparadas como WebP 1536×864. Por limitação do conector de texto, **os arquivos binários não foram anexados a este PR**. O proprietário pode copiar a pasta `assets/menu/hero/` do pacote fornecido na conversa antes de ativar a implementação.

## Comportamento
- Um slide por vez, transição horizontal suave (0,46s), troca automática a cada 10s, setas e swipe.
- Tocar em qualquer região central da arte ou em JOGAR abre `story`, `duel` ou `deck_library`.
- Cabeçalho: História/Mata-Mata/Biblioteca selecionam seus slides; Personagens/Amizades/Ajustes abrem as telas atuais.
- Rodapé: Novidades e Ver amigos continuam funcionando.
- `NowPlaying` real é preservado por cima da arte; autenticação e rotas internas continuam intocadas.
- O palco 3D do lobby não precisa renderizar quando o carrossel está ativo.

## Fallback e validação
Se **qualquer** arte faltar, `HeroCarousel` não altera o lobby antigo: o menu publicado continua funcionando.
- Validar importação WebP no Godot 4.7, desktop 1672×941, iPhone landscape e Android landscape.
- Testar click JOGAR, swipe, setas, header, abrir/voltar de telas, login, convite, música.
- Evitar merge sem as três artes e testes reais.

## Limitação atual
O protótipo usa imagens completas com texto/controles ilustrados e zonas de toque invisíveis. Para localização PT/EN, leitores de tela e responsividade extrema, a etapa seguinte é separar as imagens de fundo e converter texto, botão e abas em controles Godot nativos.