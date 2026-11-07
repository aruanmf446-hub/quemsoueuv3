---
name: qse-design
description: Criar e revisar o visual do Quem Sou Eu V3 com referências aprovadas e validação real. Aplicar a interfaces, UI/UX, cenários, assets, materiais, efeitos, enquadramento e responsividade; revisar também o impacto visual de mudanças funcionais.
---

# Design do Quem Sou Eu V3

Use esta habilidade nas mudanças com impacto visual deste repositório. O pedido atual
do dono tem prioridade. Não prometa qualidade apenas porque os testes passaram.

## Antes de desenhar

1. Leia `AGENTS.md`, `docs/referencias/README.md` e
   `docs/layout/README_IPHONE.md`. Abra a referência atualmente aprovada.
2. Abra uma captura real da tela existente. Identifique a ação principal, o
   conteúdo protagonista e o problema concreto; não redesenhe sistemas fora do pedido.
3. Se a referência ou a crítica for ambígua, faça uma pergunta curta. Continue
   a inspeção independente. Não infira aprovação de uma resposta vaga.

## Composição

- Estilo e componentes vêm de `scripts/ui/player_ui.gd`. Evolua esse sistema
  quando faltar um componente; não crie um tema paralelo.
- Preserve os personagens, modelos e artes oficiais. Fundo sólido nas telas
  internas; não use arte do lobby como fundo de todas as telas.
- Defina uma ação principal visível e uma hierarquia clara entre título,
  conteúdo, preço/estado e ação. Dourado indica prioridade ou seleção.
- Personagens são protagonistas: reserve espaço real ao corpo, cabeça e
  movimento. Não diminua o avatar para acomodar linhas redundantes de botões.
- Variações ficam junto ao personagem selecionado. Prévia, reação e posse
  precisam ser distinguíveis sem multiplicar abas e legendas.
- Pacotes e produtos precisam ser reconhecíveis visualmente. Use arte ou ícones
  adequados e quantidade/preço legíveis, sem repetir a mesma informação em
  título, descrição e botão. Não substitua apresentação de produto por um formulário.
- Evite barras enormes com uma miniatura pequena, espaços vazios sem função,
  cartões idênticos para conteúdos diferentes e controles com texto cortado.
- Prefira poucos grupos bem organizados a uma sucessão de caixas e avisos.
  Não tente corrigir composição ruim adicionando brilhos, bordas ou decoração.
- Use controles nativos para textos, preços, botões, seletores e navegação.
  Arte ilustrativa não contém botões falsos nem texto duplicado.
- Mostre somente informações úteis ao jogador. Mantenha bloqueios e estados
  reais claros, sem expor detalhes de backend no fluxo normal.

## Implementação e custo

- Preserve sinais, rotas, autenticação, música e regras de compra. Refatoração
  visual não pode ativar pagamentos ou alterar dados/posse para parecer funcional.
- Reutilize assets e componentes existentes. Gere arte nova quando ela resolver
  uma necessidade concreta; registre sua origem e não chame um mockup de captura.
- Mantenha a base 1672×941. Só `UIScale.is_iphone()` usa a exceção 1200×675 e a
  área segura. Não introduza escala por densidade nem modo compacto geral.
- Faça primeiro a composição representativa da tela afetada. Não propague uma
  nova direção para várias telas sem conferir uma captura dela.
- Agrupe leituras e verificações independentes. Evite exportar repetidamente
  sem uma mudança relevante ou repetir testes que já passaram sem motivo.

## Cenários, materiais e efeitos

- Preserve o deserto noturno e o contexto de cada fase. Assente os elementos em
  superfícies coerentes; evite bases flutuando, bordas cortadas, repetições
  evidentes e fundos aparecendo por baixo de uma sustentação rasa.
- Preserve buracos reais, telhados jogáveis e aberturas intencionais das pontes.
  Em polimento visual, mantenha movimentação, saltos, combate, cargas e progressão.
- Localize o elemento e a camada apontados: interface, sprite, material, chão,
  fundo, câmera ou colisão. Testar apenas um objeto parecido que já funciona
  não reproduz a reclamação. Confira outros usos de componentes compartilhados.
- Preserve proporção, enquadramento e nitidez dos assets; use mipmaps e filtragem
  adequados. Não invente personagens/cartas nem use conteúdo sem licença.
- Efeitos devem ser legíveis sem cobrir personagem, inimigos, obstáculos ou
  controles. Shaders precisam funcionar em Compatibility e no export Web.
- Prefira materiais compartilhados, lotes e carregamento por trechos. Evite
  reconstrução por quadro, decodificação pesada em cliques e carregamento antecipado
  de assets grandes sem necessidade. Não reduza resolução, modelos, texturas ou
  antisserrilhado indiscriminadamente para esconder gargalos: meça a causa.

## Conferência obrigatória

Exporte e execute o Godot Web 4.7.2; use o roteiro existente em
`tests/iphone_deck/export_fixture.py` quando uma fixture for necessária.
Fixtures ficam em testes e fora do build de produção.

Confira desktop 1672×941, iPhone UA 844×390/DPR 3 e 640×360/DPR 3. Capturas
de Chromium não provam funcionamento em Safari ou iPhone físico.

Antes de considerar a tela pronta, abra as capturas e corrija:

- título, preço ou ação cortados, sobrepostos ou fora da área segura;
- personagem pequeno demais, cabeça/pés cortados ou movimento saindo do quadro;
- informação repetida, texto desnecessário ou aviso dominando o produto;
- botão sem hierarquia, ícone sem significado ou estado de bloqueio confuso;
- galeria desproporcional ou controles consumindo a área principal;
- diferença material em relação à direção aprovada ou ao pedido atual.

Compare antes/depois com câmera, posição e tamanho equivalentes. Para cenários,
confira também 1920×1080 e use testes de streaming quando pertinente. Reaproveite
motor, navegador e workflows disponíveis. Se uma ferramenta faltar, tente a CLI
ou outro meio existente e registre a limitação sem inventar capturas ou aprovações.
Não alegue FPS de aparelho real usando GPU emulada. Não remova ou enfraqueça
verificações para aprovar a entrega; documente falhas preexistentes com evidência.

Execute `python3 tools/player_ui/check_design.py` e os testes de interação
afetados. Teste clique/toque, navegação por teclado, voltar, seleção e estados
disponível/bloqueado/erro conforme o fluxo. Não escreva testes que só espelham CSS.

## Entrega e continuidade

Mostre as capturas reais no chat, sobretudo quando o dono estiver no celular.
Informe exatamente o que foi implementado, testado e publicado. Não declare
aprovação visual pelo dono nem qualidade garantida a partir de testes automáticos.
Se a direção foi reprovada, apresente a correção concreta antes de propagar o
mesmo desenho para outras telas. Respeite a autorização de publicação atual;
esta habilidade não cria uma nova exigência de permissão nem autoriza deploy.

Guarde evidências e uma nota curta da decisão visual na documentação do projeto.
Novas aprovações explícitas do dono devem atualizar a referência vigente para
que a próxima IA não restaure um desenho reprovado.

Ao publicar dentro da autorização existente, acompanhe o deploy e confira
`qseBuild` no HTML e o identificador no `sw.js`. Commit na main ou CI verde,
isoladamente, não provam que o Pages atualizou. Se falhar, informe o erro e a
versão ainda servida; não apague dados/cache de progresso do jogador. Preserve
alterações de outros agentes, não use force push nem bypass de proteção.
Esta habilidade não autoriza acesso ao backend, compras ou publicação.
