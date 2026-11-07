# Cidadãos do reino — direção definida pelo dono

As posições dos figurantes foram aprovadas. O uso de imagens dos personagens
jogáveis e do soldado Cacto como cidadãos foi explicitamente reprovado.

O dono pediu pessoas **e** cidadãos-cacto inéditos. Usar roupas civis e silhuetas
próprias, sem copiar retratos, renderizar skins do catálogo ou alterar a cor de
um personagem equipável para fingir que é outro NPC.

Assets atuais: `assets/desert/npc_citizens/`. Dois atlas RGBA originais de 4×4,
com oito cidadãos por espécie e duas poses por cidadão. A origem e os hashes
estão registrados nesse diretório. Os desenhos não foram aprovados pelo dono
apenas por terem sido gerados; as capturas do jogo servem para revisão.

Distribuição: grupos espaçados com intervalos variados por região. Mercadores e
clientes em grupos de três/quatro junto às lojas; famílias nos jardins; pessoas
sozinhas ou conversando; artesãos e vigias nos trechos correspondentes. Não pôr
uma família aleatória numa ruína ou no meio da área industrial.

Comportamento: ficam no cenário, alguns ignoram a corrida e outros reagem com
uma pose breve de susto. Não usam o comportamento de perseguição nem a animação
de corrida dos soldados. Sem colisão, dano, recarga ou grupo de inimigos.

Os sprites e suas reações pertencem ao trecho carregado e desaparecem ao
sair dele. Os pés permanecem alinhados ao trocar de pose. Não alterar a pista,
a aparência dos heróis ou a lógica de combate para acomodar figurantes.
