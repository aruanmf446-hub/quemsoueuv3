# Água do oásis — fase 5

A água anterior usava faixas senoidais contínuas. Agora o rio e a água junto ao
caminho da fase 5 compartilham uma textura própria de ondulações, com duas camadas
animadas em coordenadas mundiais, variação de profundidade, reflexos fragmentados
e transição suave nas margens. O canal da fase 4 conserva seu material.

Asset novo: `assets/desert/modular/oasis_water_surface.png`, 1254×1254, gerado para
este projeto com image_gen em 07/11/2026. O original gerado foi preservado no
workspace. Importação sem perdas, mipmaps e amostragem anisotrópica. A textura é
aquecida pelo carregamento real somente na fase 5; o material é compartilhado
entre os trechos. Não usa refração de tela, SSR, partículas ou malhas adicionais.
Os modelos, dimensões do rio, colisões e parâmetros da gameplay foram preservados.

- [Antes](844x390/antes.jpg) / [depois](844x390/depois.jpg), capturas reais do Godot.
- Também conferido em 640×360 e 1920×1080; logs nas respectivas pastas.
- [WebGL real no Chromium](web/fase_05_agua.jpg), 844×390, DPR 3, iPhone emulado,
  GPU SwiftShader: [relatório aprovado](web/report.json), sem erros de shader,
  motor ou navegador e sem requisições externas ao backend.
- `regional_context_test.gd`: **72 verificações aprovadas**, incluindo fases 1–10,
  streaming e materiais compartilhados.
- Design, escopo, importação/exportação e sintaxe do teste Web aprovados.

As capturas usam fixture de cenário, removendo encontros e estabilizando o ator.
Não representam percurso completo nem validação em aparelho físico ou medição
de FPS. A publicação passa a permitir 20 minutos para o Pages sincronizar arquivos;
as tentativas anteriores excediam o limite padrão de 10 minutos. O limite maior
não é prova de que o serviço de publicação deixou de falhar: é preciso confirmar
o resultado do deploy e a versão entregue pelo site.
