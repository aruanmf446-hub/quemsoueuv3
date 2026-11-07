# NPCs visíveis durante a partida

O Pages anterior (`81315a7`) realmente continha os assets e scripts. Isso não
comprovava a visibilidade no jogo: dois defeitos de posicionamento permaneciam.

1. A distribuição deixava a entrada das dez fases sem cidadãos. Na fase 1,
   o primeiro encontro ficava depois de aproximadamente 6% do caminho; existiam
   longos intervalos vazios. Na fase 10, a distribuição excluía todos os cidadãos.
2. A profundidade colocava figurantes atrás dos planos opacos da arte 2,5D.
   No oásis, os nós passavam na checagem de frustum e presença, mas eram cobertos
   pelo cenário. Nos telhados, a parede escondia suas pernas. As capturas
   `antes/` mostram o problema, inclusive o oásis com os NPCs contados e invisíveis.

Correção: cidadãos na entrada das fases e dos distritos/checkpoints, preservando
os encontros já existentes. Humanos e cactos originais ficam no lado visível do
cenário, à frente das fachadas pintadas e atrás do jogador. Na mina, trabalhadores
aparecem antes da sala de abastecimento e da arena final. Não há alteração de
colisões, poderes, controles, saves, autenticação, backend ou artes jogáveis.
Nenhum novo asset foi gerado; os dois atlas originais foram reaproveitados.

## Conferência

- Entrada normal: 0/10 antes; 10/10 depois, com ambas as espécies no campo de visão.
- Retomada pelos saves reais: os 70 checkpoints das dez fases mostram cidadãos.
- Sem teleporte do ator, desativação da física/câmera ou drenagem manual da fila.
- Regressões dos cidadãos 8/8, feedback e percurso físico completo da fase 1 aprovados.
- Smoke completo 29/31: modelo Malagueta e apresentação de batalha continuam com
  as mesmas falhas anteriores, registradas na entrega precedente. Não foram removidas
  asserções nem alterados os testes desses sistemas.
- Design e proteção de escopo preservados.

As fotos em `antes/` e `depois/` são capturas do motor 4.7.2 no mesmo viewport
844×390. O início vazio da fase 1 vem de `81315a7`. As reproduções das fases 2 e 5
isolam a oclusão: os grupos já haviam sido antecipados, mas ainda usavam as profundidades
antigas e continuavam encobertos. A comparação mantém suas posições e o enquadramento. A fixture apenas dispensa lições já vistas e usa arquivos locais isolados.
As cenas e seu carregamento são os mesmos da campanha.

A conferência Web usa Chromium/SwiftShader com iPhone UA 844×390/DPR 3,
640×360/DPR 3, desktop 1672×941 e 1920×1080. Não é teste em Safari ou telefone físico.
Além de contar nós, o roteiro compara capturas reais ocultando/exibindo um figurante:
corpo e pés precisam modificar a imagem renderizada. Essa pausa fotográfica é
exclusiva da fixture e não muda o cenário, o enquadramento ou a fila de carregamento.
As capturas A/B são diagnóstico; as imagens normais mostram a fase em funcionamento.

Reprodução: `tests/citizen_visibility/startup.gd`, `resume.gd` e `web.cjs`.
O export de diagnóstico é criado somente em uma cópia de staging com
`make_stage.gd` e a feature `citizen_visibility_fixture`; fica fora da produção.

Resultado Web final: matriz de viewports aprovada (`web_matriz.json`) e pixels reais
do oásis/telhados aprovados (`pixels_medidos.json`, logs originais ao lado).
As capturas A/B em `pixels/` são PNGs sem compressão com perdas. Não são mockups.
