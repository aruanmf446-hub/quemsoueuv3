# Layouts da cidade noturna — fases 01 a 09

Os mapas são gerados deterministicamente por
`scripts/desert/t15d/campaign_layout.gd`. `metadata(order)` fornece nome, resumo e
identidade do distrito sem construir a geometria; `build(order, minimum_seconds)`
fornece o contrato de plataformas, inimigos, reposições, buracos e progressão.
A Fase 10 não é aceita pelo gerador e continua usando seus próprios arquivos.

Cada mapa publicado tem 1.200 metros entre o spawn e a meta. A velocidade
horizontal máxima é 6 m/s: mesmo descontando 1 metro do alcance antecipado da área
da saída, o limite inferior do percurso é 199,83 segundos. Não há espera na meta
nem um relógio que substitua extensão real. Pedir menos de 180 segundos ao gerador
preserva esse mínimo; pedir mais aumenta a distância em vez de impor uma espera.

Há oito distritos de 150 metros, com temas alternados para os elementos do cenário.
Os layouts variam pátios, degraus baixos/largos, elevações de salto duplo e trechos
abertos. Fases 01–09 têm respectivamente 14, 15, 16, 17, 18, 19, 20, 20 e 20
buracos e o mesmo número de Cactus. Os vãos medem 3,0–3,5 m, os degraus chegam
no máximo a 2,7 m e as aproximações têm pelo menos oito metros livres antes dos
buracos. A geometria aceita travessia nas duas direções, sem superfícies de mão única.

Cada Cactus tem uma reposição de ataque alguns metros depois do encontro, em piso
livre; existem outras três reposições de ataque e doze de defesa por fase.
A primeira carga de ataque vem do inventário inicial. As reposições extras podem
ser alcançadas saltando sobre um inimigo e retornando, se o jogador gastar uma
carga antes do contato. Não existem checkpoints de respawn: morrer reinicia a fase.

Plataformas de chão são divididas em peças de no máximo 24 metros, com limites
`span_start`, `span_end` e indicação `chunk`. Inimigos, itens, buracos, sinais e
marcos têm IDs estáveis para streaming sem reaparecer objetos já consumidos ou
inimigos já derrotados na mesma tentativa. Morrer restaura a tentativa inteira.

O contrato inclui `holes` (vãos reais), `signs` (avisos nos dois sentidos),
`districts` e `landmarks`; a apresentação continua no controlador da campanha.

Validação de geometria: 18 travessias físicas isoladas (ida e volta das nove
fases) passaram no Godot 4.7.2 com cápsula de 1,4 m × raio 0,35 m, velocidade
6 m/s, gravidade 24 m/s², impulsos 9,2 e 8,6 m/s e snap de 0,18 m. Os percursos
levaram 201,53–202,13 segundos simulados. Essa prova não carrega modelos,
inimigos ou arte e não substitui a avaliação visual/funcional da gameplay real.
