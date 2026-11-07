# Margens naturais do oásis

Base: `2129218`, preservando as alterações de loja e emotes já presentes na main.
O refinamento usa os mesmos assets e materiais aprovados, sem alterar gameplay.

- Curvas calculadas pela posição no mundo, em vez de reiniciar a curva em cada laje.
- Pequena faixa molhada, rampa e terraço seco com tons mais suaves para a noite.
- Largura das margens variada; a margem distante sustenta melhor a vegetação.
- Complementos de vegetação posicionados acompanhando a curva da margem.
- Reflexos e profundidade da água acompanham a mesma curva por interpolação dos
  vértices, sem acrescentar cálculos de curva por pixel ou novos materiais.

São 16 quads adicionais de terra por laje natural, agrupados no material já usado.
Não foram adicionadas malhas separadas, texturas, luzes ou colisões. Os limites do
percurso, buracos, câmera, combate, recargas e o canal da fase 4 foram preservados.

[Antes](844x390/antes.jpg) / [depois](844x390/depois.jpg), capturas reais do Godot
4.7.2 em 844×390. Também conferido em 640×360 e 1920×1080. O posicionamento inicial
em x=35 m é uma fixture; encontros foram retirados para a revisão visual.

`regional_context_test.gd`: **72 verificações aprovadas**, fases 1–10, incluindo
limites dos lotes, materiais compartilhados e descarregamento dos trechos.
Design, escopo contra a base, importação/exportação e sintaxe aprovados.
[Chromium/WebGL real](web/fase_05_agua.jpg), 844×390, DPR 3 e iPhone emulado:
[relatório aprovado](web/report.json), zero erros de shader/script/navegador e
zero acesso externo ao backend. GPU SwiftShader, fixture de cenário. Não há
alegação de teste em aparelho físico, percurso completo ou medição de FPS.

A habilidade reutilizável de qualidade visual fica em
[qse-visual-polish](../../.agents/skills/qse-visual-polish/SKILL.md), com entrada correspondente
para Claude Code e acionamento nas instruções dos dois agentes. É uma habilidade
do repositório; não foi instalada no catálogo global da conta.
