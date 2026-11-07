# Mesmo FBX de samba, oito personagens

Capturas reais do Godot **4.7.2**, export Web/Chromium. Dois grupos sincronizados:

- Grupo 1: Cowboy, El Fuego, Halloween e Lana.
- Grupo 2: Michelly, Rodrigo, Lorena e Gus.

`samba-grupo-1.gif` e `samba-grupo-2.gif` exibem seis segundos, 60 frames por
grupo a 10 fps. Os MP4 preservam 1280×720. Os GIFs foram reduzidos para 1000 px
de largura para o chat. Cada sequência tem 60 imagens distintas renderizadas
pelo motor, amostrando tempos consecutivos do mesmo clipe FBX.

O movimento vem de **Samba Dancing.fbx**, exemplo público do Three.js, clipe
`mixamo_com` (18,2 s). URL, checksum e reprodução estão em
`tests/fbx_dance/README.md`. Não criamos nem reivindicamos a autoria dessa dança.
O arquivo fonte e o personagem doador não foram redistribuídos no repositório.

O bake offline transfere a animação para os rigs originais sem copiar as
proporções do doador. Todos os ossos dos oito rigs encontraram correspondência:
Cowboy 41/41, Michelly 41/41, Rodrigo 33/33, Lorena 65/65, Gus 65/65, Lana 65/65,
Halloween 65/65 e El Fuego 41/41. O apoio dos pés foi verificado em todos os
samples. Detalhes numéricos em `bake-report.json` e `bake.log`.

`render-results.json` registra os dois grupos, 120 frames e zero erros de script
na captura final. O design check passou. Os quadros de referência `grupo-1.png`
e `grupo-2.png` correspondem a 1,5 segundo.

É um teste de adaptação visual, não aprovação de um produto de dança. A venda
permanece inativa. Não houve alterações em Supabase, economia, autenticação,
partidas ou modelos originais. Não houve teste em aparelho físico nem deploy
main/Pages. Os renders usam luzes originais do palco com MSAA 2× e sombras
desligadas para a captura simultânea; não alteram os perfis de produção.
