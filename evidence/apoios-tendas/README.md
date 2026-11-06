# Tendas e objetos com apoio por cima

Sobre a main `5ebf63e`, preservando o trabalho paralelo de decks/comunidade. Nenhum asset foi substituído nem criado. Mantém força/quantidade dos saltos, controles, combate, Tasks, cenário e interface.

- As lonas e balcões das tendas agora sustentam o personagem. Superfícies adequadas das lojas próximas, fontes, ruínas, estruturas de mineração, caixas de mantimentos e carrinhos também recebem apoio.
- O personagem atravessa esses apoios ao subir; só colide quando desce com os pés acima do topo. Não bate a cabeça, não fica preso por baixo e pode levantar após agachar sob um balcão. Ao pousar, o Godot reconhece o chão e recupera os saltos normalmente.
- Passarelas dos obstáculos de parkour existentes também recebem a passagem por baixo. Piso principal, telhados aprovados da fase 2, pedras que caem e pontes de Tasks mantêm suas regras.
- Apoios acompanham os limites visuais, o recorte e o espelhamento das imagens. A altura física compensa a projeção da câmera; não há plataformas visíveis adicionadas nem peças flutuantes.
- Só objetos próximos da rota oferecem apoio. Casario distante continua no fundo. Os apoios ficam dentro da laje de origem e nunca fecham os vãos das Tasks.
- Cada apoio é dono da limpeza de suas exceções físicas antes de descarregar. Isso evita referências de corpos removidos no Jolt ao avançar/voltar pelo mapa.

## Capturas reais do Godot

| Janela | Em cima da tenda | Novo salto a partir dela | Em cima da caixa |
|---|---|---|---|
| 844×390, perfil iPhone | [lona](844x390/02_em_cima_da_lona.jpg) | [salto](844x390/03_salto_a_partir_da_lona.jpg) | [caixa](844x390/04_em_cima_da_caixa.jpg) |
| 1920×1080 | [lona](1920x1080/02_em_cima_da_lona.jpg) | [salto](1920x1080/03_salto_a_partir_da_lona.jpg) | [caixa](1920x1080/04_em_cima_da_caixa.jpg) |
| 640×360 | [lona](640x360/02_em_cima_da_lona.jpg) | [salto](640x360/03_salto_a_partir_da_lona.jpg) | [caixa](640x360/04_em_cima_da_caixa.jpg) |

Aproximação dos pontos por fixture identificada. Subida pela lona, aterrissagem, corrida e novo salto usam os controles e a física reais; não há teleporte para simular o pouso na lona. A caixa é verificada por queda física curta de cima. Não são capturas de aparelho físico.

## Verificação

- [Resultado consolidado](results.json). Godot 4.7.2, Compatibility.
- **134 verificações**: passagem por baixo, salto duplo, aterrissagem, corrida na lona, novo salto, saída pelas bordas, levantar sob balcão, apoio real em oito tipos de assets, limites das lajes e descarregamento em dez fases. [Log](rules.log).
- **Dez percursos físicos completos sem mortes**, sem teleporte/invulnerabilidade no autopiloto. [Logs](routes/). Percursos foram repetidos nas fases afetadas pelos apoios de caixas/carrinhos depois desse complemento; os demais exercitam o mesmo código de apoio e limpeza já finalizado.
- Reino v3, checkpoints e **72 verificações** da composição regional: passaram. Design PlayerUI, escopo e diff: passaram.
- Capturas/controles nas três janelas acima passaram. As verificações de agachar/levantar e descarregamento completas estão no teste headless posterior; a validação estética vem das capturas reais.
- **Web real**: Chromium, WebAssembly/WebGL2 com SwiftShader, 844×390, DPR 3, emulação iPhone. Duas entradas de pulo por toque real atravessam a lona e pousam nela; corrida por teclado e novo salto a partir da lona também passaram. Sem erros JavaScript/Godot ou chamadas externas. [Relatório](web/report.json), [na lona](web/02_na_lona.jpg), [novo salto](web/03_novo_salto.jpg).
- O teste Web usa uma pressão curta da seta ao verificar a corrida: esperar o retorno de várias consultas no navegador com GPU por software mantinha a tecla apertada até sair pela borda. A física não foi alterada para esse ajuste de coordenação do teste.

Na primeira rodada de percursos, o Jolt reportou referências a corpos removidos ao ler exceções após descarregar chunks. Corrigido em `one_way_support.gd`, com limpeza em `_exit_tree`. Foram acrescentadas cinquenta verificações específicas de limpeza, além de repetir os percursos. Nenhum teste existente foi apagado ou enfraquecido.

Limites: não validado no Safari/iPhone físico nem medido FPS em GPU real. Não há declaração de smoke geral aprovado; as falhas de navegação já registradas no repositório estão fora deste ajuste.

## Reprodução

```bash
GODOT=/caminho/Godot_v4.7.2-stable_linux.x86_64
"$GODOT" --headless --fixed-fps 60 --path . --script tests/desert_night/prop_landings_test.gd
QSE_TEST_IPHONE=1 "$GODOT" --path . --script tests/desert_night/prop_landings_test.gd -- /tmp/landing 844x390 --captures-only --touch-controls
python3 tests/desert_night/run.py --godot "$GODOT" --only route-01 route-02 route-03 route-04 route-05 route-06 route-07 route-08 route-09 route-10
# Export isolado de staging com feature iphone_layout_fixture, servido na porta 8135:
node tests/desert_night/web_prop_landings_probe.cjs
```
