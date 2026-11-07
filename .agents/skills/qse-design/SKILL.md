---
name: qse-design
description: >-
  Padrão de qualidade visual do Quem Sou Eu V3 em Godot. Use ao criar, corrigir ou
  refinar menus, UI/UX, cenários, materiais, assets, efeitos, enquadramento ou
  responsividade; use também para revisar o impacto visual de mudanças funcionais.
  Preserva referências aprovadas e exige evidência real do resultado.
---

# QSE Design

Transforme o pedido em uma melhoria visível, coerente com o jogo e verificável.
As instruções específicas do dono e da tarefa prevalecem sobre este roteiro.
Esta habilidade não concede autorização para backend, compras ou publicação.

## Começar pelo problema real

1. Leia o [AGENTS.md](../../../AGENTS.md), a
   [direção visual atual](../../../docs/referencias/README.md) e, quando relevante,
   o [layout do iPhone](../../../docs/layout/README_IPHONE.md).
2. Trabalhe a partir da versão atual do repositório, preservando alterações de
   outros agentes. Identifique a versão servida no site quando investigar produção.
3. Observe a tela/trecho apontado antes de editar. Localize o elemento e a camada:
   interface, sprite, material, chão, fundo, câmera ou colisão. Testar apenas um
   objeto parecido que já funciona não reproduz a reclamação.
4. Defina um alvo concreto e pequeno para a rodada. Se a ambiguidade muda a
   implementação, faça uma pergunta curta e continue a investigação independente.

## Preservar o que foi aprovado

- Mantenha identidade, referências atuais, organização aprovada e proporções.
  Uma captura produzida pelo agente não se torna referência aprovada por si só.
- Em correções funcionais, preserve o visual; em polimento visual, preserve
  movimentação, saltos, combate, cargas, progressão, autenticação e economia.
  Amplie o escopo somente quando a tarefa realmente pedir isso.
- Não restaurar molduras ornamentais históricas ou criar um tema paralelo.
  Menus usam `PlayerUI`; consulte as referências específicas das telas.
- Não reduzir resolução, modelos, texturas ou antisserrilhado indiscriminadamente
  para esconder um gargalo. Investigue e registre o que foi medido.

## Critérios visuais

- **Hierarquia:** ação principal clara, textos legíveis, botões confortáveis e
  proporções equilibradas. Evite faixas muito largas e baixas ou elementos minúsculos.
- **Responsividade:** base padrão 1672×941, escala uniforme; exceção iPhone
  1200×675 por `UIScale.is_iphone()`, respeitando área segura e regras existentes.
  Não criar ajustes de zoom ou temas por dispositivo.
- **Cenário:** preserve o deserto noturno e o contexto de cada fase. Assente os
  elementos em superfícies coerentes; evite bases flutuando, bordas cortadas,
  repetições evidentes e fundos aparecendo por baixo de uma sustentação rasa.
  Preserve buracos reais, telhados jogáveis e aberturas intencionais das pontes.
- **Assets:** avalie o catálogo existente antes de gerar algo. Preserve proporção,
  enquadramento e nitidez; use mipmaps e filtragem adequados. Declare procedência
  de assets novos. Não invente personagens/cartas ou use conteúdo sem licença.
- **Materiais e efeitos:** detalhe legível, contraste controlado e animação suave.
  Efeitos não devem cobrir personagem, inimigos, obstáculos ou controles. Shaders
  devem funcionar no renderizador Compatibility e no export Web.
- **Desempenho:** prefira materiais compartilhados, lotes e carregamento por
  trechos. Evite reconstrução por quadro, decodificação pesada em cliques e assets
  grandes carregados antes de serem necessários. Não alegue FPS real usando GPU emulada.

## Verificar o acabamento

1. Valide primeiro um caso representativo. Compare antes/depois com câmera,
   posição e tamanho equivalentes; confira outros usos quando o componente for comum.
2. Inspecione capturas reais em 1920×1080, 844×390 e 640×360. Para Web, tente
   Chromium/WebGL e registre erros de shader, script e navegador quando pertinente.
3. Use verificações proporcionais: importação/compilação para scripts e shaders,
   testes de interação/streaming se afetados e `tools/player_ui/check_design.py`
   para a integridade do design. Só repita a suíte ampla quando houver motivo.
4. Não remova ou enfraqueça testes para aprovar a entrega. Falhas anteriores
   precisam de evidência na base; registre limitações sem chamá-las de aprovação.
5. Uma imagem gerada não substitui captura do jogo. Identifique fixtures e
   emulação; nunca apresente isso como teste em aparelho físico.

Reaproveite o motor, navegador e workflows autorizados já disponíveis. Se uma
ferramenta estiver ausente, tente o motor real pela CLI ou outro meio disponível.
Registre checagens impossíveis e entregue o restante verificável; não invente
capturas nem transforme a ausência de uma ferramenta em pedido automático de aprovação.

## Entregar e publicar

- Entregue o código e uma comparação visual acessível, com links para capturas.
  Explique brevemente o que mudou para o jogador, como verificou e o que ficou pendente.
- Siga o fluxo autorizado na conversa/repositório. Não peça autorização novamente
  quando já foi dada; não invente uma aprovação adicional por causa desta habilidade.
  Não misture arquivos de outros trabalhos nem use force push ou bypass de proteção.
- Quando a publicação estiver autorizada, acompanhe o deploy e confirme a versão
  em produção. Neste projeto, confira `qseBuild` no HTML e o identificador no `sw.js`.
  Commit na main e CI verde, isoladamente, não provam que o Pages atualizou.
- Se a publicação falhar, informe o erro observado e a versão ainda servida.
  Não declare o site atualizado nem apague dados/cache de progresso do jogador.

Pronto significa: o problema apontado melhorou de forma visível, o desenho
aprovado permanece coerente, o escopo protegido foi respeitado e há evidência real.
