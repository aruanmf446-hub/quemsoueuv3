# Revisão funcional e visual das fases 1–9

Base: `876e7c9`. Correções concretas do piso e das lonas, com revisão das recargas
e da conservação de cargas. Artes, texturas, modelos e controles aprovados foram
reaproveitados. Não foram gerados assets novos nem alterados serviços online.

## Problemas encontrados e corrigidos

1. **Piso com aspecto torto:** os topos físicos eram planos, mas suas normais eram
   suavizadas junto às laterais das caixas. Isso inclinava a iluminação e produzia
   manchas diferentes entre peças. As caixas agora têm faces planas; superfícies
   curvas continuam suavizadas. Não houve mudança na altura ou colisão do piso.
   [Antes](before/fase_04_844x390.jpg) / [depois](mobile/fase_04_x0035.jpg).
2. **Duas alturas para o mesmo toldo:** as casas de comerciante e de varanda
   próximas tinham um apoio antigo acima do apoio correto da lona. Removida essa
   duplicação, preservando teto, varanda e balcão distintos.
3. **Tenda parecida que não funcionava:** a tenda junto ao mecanismo do portão da
   fase 3 era criada por `TaskArt`, fora da composição normal, e não recebia
   apoio. Agora usa o mesmo apoio atravessável das outras tendas. Foi recuada na
   aproximação para não permitir saltar por cima do portão sem executar a Task.
4. **Cargas entre fases:** a implementação existente passou na conferência
   ampliada. Os cinco recursos preservam exatamente as quantidades ao avançar e
   ao reabrir a próxima fase, inclusive zero e capacidade cheia. Não foi preciso
   alterar inventário ou persistência para esse resultado.

## Cobertura das lonas

A auditoria percorre todos os chunks das nove fases, escolhe objetos pela arte
visível e confere apoio único, referências e descarregamento. Saltos de baixo,
aterrissagem e caminhada são exercitados por entradas reais em cada variante
próxima/de fachada e na tenda do mecanismo.

| Fase | Lonas jogáveis verificadas | Fachadas da rua inferior |
|---|---:|---:|
| 1 | 113 | 0 |
| 2 | 0 | 310 |
| 3 | 222 | 0 |
| 4–7 | 0 | 0 |
| 8 | 92 | 0 |
| 9 | 0 | 0 |

Na **fase 2**, a rota continua sobre os telhados das casas. As lonas da rua
inferior ficam abaixo do percurso e continuam sendo cenário; não foram criadas
plataformas inferiores que prendam o jogador após uma queda. O contato real dos
pés com os tetos foi conferido parado, correndo nos dois sentidos, na borda e
saltando: [30 verificações gráficas aprovadas](roof-contact/report.json).

## Resultados

- **9/9 travessias completas**, por comandos, sem teleporte após o spawn, sem
  invulnerabilidade, sem mortes ou respawn; saídas e sete checkpoints alcançados.
- **71 verificações da auditoria**, zero falhas: lonas, piso, todos os pontos de
  recarga e progressão dos poderes; texturas do catálogo com mipmaps, até 1024 e
  sem atlas aninhado. [Relatório](qa/surface-after.json).
- A mesma auditoria sobre o código anterior detectou 16 falhas, incluindo as
  lonas duplicadas e a tenda sem apoio. [Controle anterior](qa/surface-before.log).
- **65 verificações de transição**, incluindo todas as passagens 1→2 até 8→9,
  inventário de vitória salvo e reentrada. [Log](qa/suite/story-transitions.log).
- **79 verificações de pedestais/coleta**, nos seis tipos usando o componente
  compartilhado na fase 5: capacidade cheia preserva item, coleta remove só o
  item e a estação permanece; descarregar/revisitar não duplica.
- **52 verificações do parkour atual**: Tasks, pontes e retornos.
- 17 etapas pertinentes da suíte passaram, incluindo obstáculos sólidos,
  checkpoints, progresso, apoios e regras do reino. O resultado bruto também
  conserva a falha do roteiro legado: [resultados](qa/suite/results.json).
- Importação, exportação Web, verificação de design, escopo e sintaxe aprovados.

## Conferência visual

[27 capturas no celular](mobile/painel.jpg), 844×390: início, meio e fim das nove
fases. [9 capturas adicionais](small/fase_03_x0035.jpg), 640×360, nas fases 1/3/4.
[27 capturas de desktop](desktop/painel.jpg), 1920×1080, feitas por último, após
as travessias e a revisão móvel. Arquivos individuais mantêm a resolução original.
As capturas são fixtures de posição, identificadas pelo roteiro
`tests/desert_night/campaign_revision_capture.gd`, não travessias completas.

Três pontos da primeira fixture móvel caíram dentro de vãos reais. A posição de
captura foi corrigida, sem mudar o mapa; as imagens correspondentes foram
substituídas por capturas apoiadas. Logs inicial e corrigido foram preservados.

As lonas próxima da fase 1 e do mecanismo da fase 3 também foram testadas em
Chromium/WebGL 844×390/DPR 3, com dois gestos de toque nativos pelo CDP, novo salto,
caminhada e saída pela borda. Aproximação por fixture; salto por física real.
[Fase 1](web/lona-proxima-01/report.json) / [fase 3](web/lona-mecanismo-03/report.json).
O observador da fixture registra a caminhada por quadro de física, evitando
perder um evento curto entre consultas JS em GPU emulada.

As **nove cenas também passaram no Chromium/WebGL**, em sequência, com zero erros
de shader/script/navegador e zero requisições externas. A fixture libera a cena
anterior ao abrir a próxima. [Capturas Web](web/nove-fases/painel.jpg) e
[relatório](web/nove-fases/report.json). Isso é conferência de renderização e
carregamento da fixture; as travessias completas estão nos testes por comandos.

## Limites e testes antigos

- `layout_test.gd` já falhava em 12 verificações na base: exige que todo vão seja
  saltável mesmo quando depende de uma Task e usa a contagem antiga de guardas.
  [Log da base](qa/layout-legado-baseline.log). Não foi alterado para esconder falhas.
- `parkour_test.gd` procurava `geyser_wall`, removido da campanha aprovada, e
  continuava aberto após um erro de script. Agora falha imediatamente com motivo
  explícito; não foi removido nem convertido em aprovação. O roteiro atual de
  parkour passou separadamente. [Falha explícita](qa/parkour-legado-fail-fast.log).
- Há avisos de instâncias ObjectDB no encerramento de alguns testes headless,
  preservados nos logs. Não foi declarada ausência geral de vazamentos.
- Chromium usa SwiftShader; não representa Safari/iPhone físico, APK, EXE Windows
  ou medição de FPS real. O foco foi 1–9; a travessia do chefe da fase 10 e a suíte
  histórica completa não foram repetidas. Os construtores de arte são compartilhados.
- Nenhum acesso ao Supabase ou teste de conta real. Progresso e sessões de QA usam
  perfis locais isolados; a RPC da fixture Web é simulada e destinos externos são bloqueados.
