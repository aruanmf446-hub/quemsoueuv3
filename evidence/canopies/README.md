# Lonas das fachadas

A correção anterior tratava dos blocos de parkour. Esta revisão corrige as lonas
presas às casas e lojas, incluindo as primeiras lonas do percurso.

**Causa:** `prop_landings.gd` tinha apoio para a tenda `capital_market_stall`, mas
não para o tecido de `capital_house`, `capital_merchant` e `capital_balcony_house`.
Além disso, o filtro de profundidade descartava as fachadas em z=-10..-12.
Por isso testar somente a tenda já funcional não reproduzia a reclamação.

Agora cada lona dessas fachadas recebe um apoio alinhado à borda frontal do tecido.
Permite atravessar durante a subida, pousar na descida, andar e saltar novamente.
Não adiciona paredes sólidas às fachadas nem colisão ao skyline distante.
Os limites continuam respeitando o piso de cada trecho e as lacunas das tarefas.
Na fase 2, as fachadas da rua inferior ficam abaixo da rota; seus tetos jogáveis
continuam preservados. Arte, modelos, controles e força do salto não mudaram.

## Evidências

- [Lona da primeira loja — 844×390](844x390/capital_merchant_em_cima_da_lona.jpg).
- [Lona da casa — 844×390](844x390/capital_house_em_cima_da_lona.jpg).
- Capturas reais do Godot também em 1920×1080 e 640×360, com logs das verificações.
  A aproximação do ator é fixture; o salto até a lona usa entradas e física reais.

## Testes

- [Antes](before.log): **7 falhas**, nas sete fachadas examinadas das fases 1, 3 e 8.
  O teste escolhe a lona pela arte, sem depender de já existir um colisor.
- [Depois](facade-canopies.log): **48 verificações aprovadas**. Salto duplo pelo
  tecido, pouso, caminhada e novo salto; fachadas abaixo dos tetos e descarregamento.
- Janelas reais em 844×390 (regra iPhone), 640×360 e 1920×1080: **17 verificações
  aprovadas em cada uma**, usando o mesmo salto real. Logs em cada pasta.
- Regressões: **136** verificações de apoios/lonas, **86** de obstáculos sólidos,
  **30** de apoios das fases e percursos completos das fases afetadas 1, 3 e 8.
  [Resultados](regression-results.json).
- `check_design.py`, `scope_test.py --base 192fa68`, importação do Godot e análise
  de sintaxe do teste Web aprovados. Não foram alterados serviços ou backend.

Não se trata de validação em aparelho físico nem medição de desempenho.
