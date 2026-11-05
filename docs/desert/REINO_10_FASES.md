# Dez fases com os assets aprovados

Godot4.7.2. Implementação revisada na branch `work/reino-deserto-10-fases`.
O dono autorizou a integração na main e publicação no Pages em05/11/2026.
A versão aprovada substitui o cenário anterior; o histórico é preservado no Git.

## O que foi instalado

As cenas `scenes/desert/phase_01.tscn` até `phase_10.tscn` continuam usando o
controlador existente `scripts/desert/t15d/phase.gd`. Cada percurso tem1452m,
oito setores e sete checkpoints. Não são imagens de fase inteira: os pisos,
vãos, ataques, inimigos e personagens continuam físicos e tridimensionais.
As ilustrações são módulos independentes de arquitetura e vegetação.

| Fase | Composição e percurso |
|---|---|
|1 Portões da Capital|Portão com arcada e torres; ruas, casas e setores defensivos.|
|2 Telhados da Capital|Rota inteira em lajes a8m ou mais; fachadas abaixo, varandas e rua distante.|
|3 Bazar da Cidade|Bancas de tecido, casas de comerciantes e praças; congelamento para trás.|
|4 Aqueduto do Deserto|Arcos ilustrados sob o tabuleiro físico, canais e água animada; corrida elétrica.|
|5 Jardins do Oásis|Palmeiras, jardins, fontes e passagem às ruínas; Ruptura atrás do jogador.|
|6 Ruínas Enterradas|Colunas e arcos antigos entre rochas e minérios, sem céu no subterrâneo.|
|7 Estrada da Mineração|Pontes de madeira/pedra, guindastes, cargas e veios minerais.|
|8 Posto de Controle|Torres, casario de apoio, arcadas e portões militares em setores separados.|
|9 Entrada da Mineradora|Pátios de carga e pontes; o portal monumental aparece somente na saída.|
|10 Interior da Mineração|Galerias, trilhos, passarelas, guindastes e cristais; Malagueta original.|

## Estrutura editável

- `kingdom_assets.gd`: catálogo, paletas regionais, cache de texturas e63 âncoras
  resolvidas no mesmo layout da física. Carrega somente recursos das fases usadas.
- `city_props.gd`: composições por laje real, sob responsabilidade de um único
  chunk, com uma camada adicional de casario nas regiões urbanas. Isso evita
  módulos vazios e duplicação nas bordas de carregamento.
- `modular_architecture.gd`: pisos volumétricos, rochas, suportes, trilhos e
  recortes ilustrados de fachadas/aquedutos/pontes. AtlasTexture mantém escala e
  proporção; cada recorte pertence à sua peça física, sem pintar sobre abismos.
- `assets/desert/modular/city_assets.json`: quinze módulos aprovados, escala e
  regiões de conteúdo. Os recortes removem apenas margens transparentes do
  enquadramento; os PNGs de autoria continuam preservados.
- `phase_asset_plan.json`: distribuição por fase e setor, agora instalada.
- `night_scenery.gd`: deserto e cidade distantes com parallax; cavernas sem céu.
  Rochas ficam atrás da decoração, sem esconder os módulos aprovados.

Os recursos.res têm alfa/mipmaps e dimensão máxima1024. A pasta source/.gdignore
preserva a autoria fora do export. Procedência em PROVENANCE.md. Nenhum modelo,
FBX, GLB, animação ou skin de personagem foi substituído.

## Gameplay e continuidade

O percurso existente conserva saltos, obstáculos, perseguição e retorno das
fases. Soldados usam a altura real da laje e saltam os vãos, inclusive nos
telhados. Vida/ataque/defesa e os poderes mantêm capacidade3 e recargas apoiadas.
Congelamento só atinge atrás, disponível desde3; choque desde4; Ruptura desde5.
A peça rompida perde colisão e arte, restaura após8s e espera se estiver ocupada.

A câmera nas fases2/4/7 enquadra melhor as fachadas/arcos abaixo do percurso,
conservando antecipação e acompanhamento suave de saltos. Não há escadas ou
moedas decorativas. O portal9 coincide com a saída; a arena10 só abre após o
chefe. Malagueta conserva modelo/animações, vida20 e dano2 originais.

As oito cenas de origem e o histórico de leitura foram preservados. As capas
são capturas reais atualizadas, não conceitos. Os capítulos2–10 agora descrevem
seus ambientes e a progressão dos poderes. Os recursos da região aquecem durante
a leitura; não se carregam os quinze módulos em todas as entradas.

## Validação

Resultados desta integração em `evidence/ten-approved/README.md`. Capturas
intermediárias são fixtures teleportadas identificadas, distintas das travessias
completas por controles. As dez travessias usam entradas e itens reais, sem
teleporte, invulnerabilidade ou alteração de vida. O piloto da arena foi adaptado
para virar antes do congelamento e usar choque contra guardas, sem mudar o chefe.

Reprodução:

```
python3 tests/desert_night/run.py --godot /caminho/godot --only reino10 layout legacy10 progress variety checkpoints route-01 route-02 route-03 route-04 route-05 route-06 route-07 route-08 route-09 route-10
xvfb-run -a python3 tests/desert_night/capture_reino10.py --godot /caminho/godot --output /tmp/capturas
```

Use Godot4.7.2, templates Web correspondentes e perfis de teste isolados. O teste
Web usa export de fixture separado; testes/evidências/fontes não entram no
pacote de produção. A fixture bloqueia destinos externos, sem login ou backend.

## Limites

Ainda é necessário validar Safari/PWA no iPhone físico, Android e Windows e
avaliar duração/dificuldade com jogadores. O piloto leva cerca de quatro minutos
por fase; não é medida da experiência humana. Picos de processamento em software
são registrados nos logs; não se declara desempenho de aparelho a partir deles.
Não foram testados OAuth ou serviços online. Supabase, autenticação, economia,
menu musical e outros sistemas compartilhados não foram alterados.
