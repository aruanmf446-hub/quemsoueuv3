# Variações junto ao personagem — disposição corrigida

A aba Variações foi removida. A galeria de personagens permanece visível.
Selecionar um personagem mostra três botões quadrados de 76×76 com miniaturas
das versões Original, style_1 e style_2, abaixo da prévia 3D. O toque muda a
paleta e o nome ao lado dos ícones. A escolha é lembrada por personagem no
painel. Reações e Emotes ficam separados; o seletor é ocultado nessas abas.

Os oito avatares e as 16 paletas existentes foram preservados. Não foram criados
novos modelos, preços ou direitos de compra. A seleção continua sendo prévia.
Os retratos originais distribuídos preenchem a galeria enquanto o cache de
retratos não está disponível, inclusive no export Web.

Verificações:

- Godot 4.7.2: 55 verificações, failures=0, incluindo os oito modelos,
  ausência da aba, seleção integrada e retorno às reações animadas.
- Compra de emotes: 14 verificações, failures=0.
- Design check: OK.
- Export Web oficial + Chromium: nove combinações de Cowboy/El Fuego/Halloween
  com 1672×941, 844×390 e 640×360. iPhone UA/DPR 3 nos dois últimos tamanhos.
  Três estilos por personagem, botões quadrados ≤90 px de design, mouse/toque,
  setas, miniaturas prontas, controles dentro da tela e zero erros de script.

As imagens são capturas reais do motor, com inventário de fixture e os
retratos originais do projeto. Não houve geração de imagens por IA, alteração
de Supabase/Stripe ou teste em aparelho físico. Main/Pages não foram publicados.

A evidência anterior com a aba fica preservada como histórico em
`../skin-variations`; esta pasta representa a disposição atual.
