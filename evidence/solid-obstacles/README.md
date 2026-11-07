# Obstáculos de parkour com volume sólido

Base: `e745d75`. O bloco de pedra de Portões da Capital e os obstáculos equivalentes
tinham só uma tampa de colisão de 0,20 m, incluída na passagem por baixo das lonas.
Todo o volume desenhado sob a tampa podia ser atravessado andando.

`phase.gd::_build_collision` passa a criar o corpo desde a superfície do chão até o
topo original (1,10 m). A largura, altura de pouso, arte, velocidade e salto não
mudam. Mantém o marcador usado pela IA do cacto para saltar obstáculos. As lonas
e demais apoios explicitamente atravessáveis mantêm seu comportamento original.
Na fase 2 não há esses blocos adicionais: a rota continua sobre os tetos reais.

## Validação

- `solid_obstacles_test.gd`: **86 verificações aprovadas**, fases 1–10. Caminhada e
  agachamento contra as duas laterais, salto/pouso nos dois sentidos, corrida no
  topo, saída pela borda, soldado fora do volume e descarregamento/recarregamento
  sem duplicação. Aproximação por fixture; saltos e contatos usam física real.
- `prop_landings_test.gd`: **135 verificações aprovadas**, incluindo lonas,
  salto por baixo e apoios dos objetos. A antiga expectativa de atravessar
  o balcão sólido foi substituída por bloquear a caminhada e pousar por salto.
- Percursos físicos completos das **dez fases** aprovados, incluindo tarefas:
  [resultados](routes.json). Sem alteração do autopiloto.
- Lanças, apoios do cenário e transições entre fases aprovados. Logs e resultados
  em `regression-*`. Design aprovado e escopo preservado em relação a `e745d75`.
- Capturas reais do Godot em 1920×1080, 844×390 (exceção iPhone) e 640×360.
  A fixture aproxima o jogador, desliga os encontros e fixa a câmera. Não representa
  uma partida inteira nem validação em aparelho físico.
- **WebAssembly real no Chromium**, viewport 844×390, DPR 3 e iPhone emulado:
  caminhada bloqueada nas duas laterais, saltos pelo botão de toque nos dois
  sentidos, apoio no topo e descida pela borda. Nenhum erro do navegador/motor
  ou acesso externo ao backend. [Relatório](web/report.json) e [salto por toque](web/02_salto_por_toque.jpg).
  Aproximação por fixture, corrida por teclado e salto por `touchscreen.tap`;
  GPU SwiftShader em software, sem medição de desempenho ou teste em iPhone físico.

## Limitações conhecidas

O teste legado `parkour_test.gd` foi interrompido após erro na linha 41: ele procura
`geyser_wall`, pedra intermediária e balsa da campanha antiga, que não existem no
layout atual da própria base. O teste e suas verificações foram preservados;
não foi usado como aprovação. As rotas atuais e o teste físico específico cobrem
os obstáculos desta correção. `regression-parkour.log` registra o erro e
`regression-results.json` registra a interrupção.

Avisos do Jolt sobre fila de jobs e de limpeza de objetos no encerramento foram
observados no ambiente headless. Os testes específicos não tiveram erros de script.
Não foram medidas taxas de quadros em aparelho físico nesta revisão.
