# Cidadãos inéditos do deserto

Dois atlas RGBA originais, criados com image_gen em 2026-11-07 para esta tarefa.
Não usam retratos, modelos ou imagens dos personagens jogáveis, nem do soldado Cacto.

- `human_citizens.png`: oito pessoas comuns; mercador, cliente, artesão, funcionário,
  dois adultos de família, criança e idosa.
- `cactus_citizens.png`: oito cidadãos-cacto originais, com papéis equivalentes.
- Cada atlas tem grade 4×4: linha 0 neutros A–D, linha 1 seus sustos;
  linha 2 neutros E–H, linha 3 seus sustos. Não há corrida ou combate.
- `frames.json` registra hashes e alinhamento dos pés lido do canal alpha.
  Os PNG finais foram copiados sem montagem ou edição por script. O atlas humano
  recebeu uma segunda passagem no image_gen para remover o fundo branco que apareceu
  na primeira geração. Os dois PNG finais têm alpha zero fora das silhuetas.

Direção: cartoon de cidade do deserto, roupas civis simples, luz quente de lanternas
com preenchimento frio. Sem armaduras, capas de herói, espadas ou visuais equipáveis.
Os prompts pediram explicitamente cidadãos inéditos, grade regular, fundo transparente,
poses de rotina e susto discreto, com pessoas de idades e aparências variadas.
