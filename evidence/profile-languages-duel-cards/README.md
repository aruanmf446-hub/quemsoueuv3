# Perfil, nickname, idiomas e capas do Mata-Mata

## Implementação

- O lobby só oferece cadastro de nickname depois que o perfil da conta retorna
  com sucesso e sem um nickname válido. Carregamento e erro de rede não são
  tratados como cadastro novo. Unicidade e bloqueio de troca permanecem no servidor.
- Busca por jogador: retrato maior, espaço para detalhes, ações que quebram linha,
  ID longo com cópia e limites de largura. Perfil público com personagem 3D original,
  nickname, nível/presença quando disponíveis, pedido de amizade e denúncia.
- Pesquisa autorizada de `aruan` no GAME encontrou `aruan` (Cowboy) e `aruanmf`
  (Lana), ambos descobríveis. Foi somente leitura de campos públicos; nenhuma
  conta foi alterada. As capturas usam transporte simulado e IDs fictícios com o
  mesmo comprimento, baseados na aparência pública de aruan, não sua sessão real.
- Português, inglês, espanhol, francês, japonês, chinês simplificado e russo no
  seletor, sem bandeiras. Seleção com prévia, confirmação e preferência persistida
  no dispositivo. Catálogos iniciais de 169–174 mensagens: a tradução do jogo é
  parcial, e isso aparece na tela. Roteiros e textos ainda não catalogados continuam
  em português; nomes enviados pelos jogadores não são traduzidos.
- Fonte complementar Noto CJK otimizada, com licença e reprodução em assets/fonts
  e tools/i18n/subset_font.py. A fonte original e o estilo PlayerUI são preservados.
- Capas do administrador da sala: duas por página, 190×280 na base padrão e
  160×216 na exceção iPhone, com arte inteira. Paginação, busca, favoritos,
  seleção ✓/✕ e Salvar preservados. A mesma composição atende criar/editar sala;
  o teste de salvamento usa uma sala local, sem alterar partidas online reais.

## Validação

Godot 4.7.2; exportação Web oficial e Chromium com GPU emulada. Mouse no desktop,
input de toque nos perfis móveis. Resoluções: desktop 1672×941, iPhone UA
844×390 e 640×360/DPR 3, Android UA 844×390/DPR 3. Android usa a base padrão,
sem herdar a exceção iPhone. Verificação de largura do layout e dos botões usados.

Testes nativos: nickname 42, idiomas/persistência/glifos 46, perfil público 6,
configurações 17, amizades 23, denúncias 16 e duelo local 85, sem falhas.
PWA: 31 verificações sem falhas. Verificação do sistema de design e diff limpos.

Capturas são da interface executada pelo motor Web, não conceitos gerados por IA.
Não houve validação em aparelhos físicos, Safari, executável Windows ou APK.
Nenhum pagamento foi ativado e nenhuma migration/Edge Function foi modificada.
