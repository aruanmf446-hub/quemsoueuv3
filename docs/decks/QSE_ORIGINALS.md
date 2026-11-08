# QSE Originals

QSE Originals é um selo editorial adicional ao rótulo OFICIAL, aplicado somente
quando o dono indicar um deck. Atualmente somente `lado_sombrio` possui o selo.
Os cinco decks anteriores permanecem oficiais, sem se tornarem Originals.

A autorização do selo usa ID local curado (`QSE_ORIGINAL_IDS`) e a marca
`qse_original` do deck.json; não é inferida pelo nome, autor ou conteúdo de usuário.
Nenhuma coleção comunitária recebe o selo por imitar o título.

## Lado Sombrio

Artes originais enviadas pelo dono em assets/duel/decks/oficial/lado_sombrio.
As dez imagens foram preservadas sem geração, substituição, renomeação ou corte.
Nomes, UUIDs e descrições completas estão em `deck.json`. Nomes/título têm exibição
nos seis idiomas; descrições permanecem como o texto original fornecido em português.

| Personagem | UUID |
|---|---|
| Construtor | 0DDAFCC2-A4B3-4517-8C32-9FE398AE36ED |
| Presidente Bolhas | 32845652-37FD-439B-AF87-EA313F81E26F |
| Linna | 69D90FC2-8763-48B4-B4BA-C3EE6310B9CF |
| Priya | 87EDBC3E-D04B-4750-B075-695E22EB46A2 |
| FH | 8DB59DBB-3ECB-4D86-B6EB-D95C87587329 |
| Guadalupe | AD7AE492-2699-439E-AB72-228408049B5F |
| Pishacha | BBE1237A-5315-4BF6-8E1C-6998B34D75CF |
| Galack | F074887D-54D7-4407-ACE3-5FEF839787A0 |
| Milene | 90CFE00B-A415-49BB-AA13-2A444EC4A442 |
| Tahnm | A06F4A32-DF09-46E2-8DA3-92D6D79DA2CB |

O servidor local e o scanner de decks aceitam UUIDs completos além dos IDs
simples existentes. A regra dos IDs das pastas não mudou. Biblioteca, leitor e
partida local foram exercitados; há 6 decks e 57 cartas no catálogo local.

## Integração online

Adicionar arquivos no GitHub não insere um registro em `qse_v3.duel_decks` no
GAME nem em campanhas de resgate/CATALOG. Esta entrega não acessa nem modifica
Supabase. Não declarar disponibilidade desse novo deck em salas online ou
resgate da conta sem verificar/sincronizar o catálogo autoritativo no servidor.
O scanner `tools/duel/sync_decks.py` já entende os UUIDs e pode preparar o UPSERT
para revisão do responsável pelo backend; nenhum SQL foi executado nesta entrega.

## El Fuego em Personagens

A galeria, busca, contagens, setas e prévia direta omitem El Fuego quando
`InventoryService.is_unlocked("el_fuego")` é false. Esse é o desbloqueio existente
associado a `desert_campaign_completed`, sem concessão local fictícia. Assim que o
progresso confirmar o desbloqueio, ele aparece e pode ser selecionado/equipado.
O modelo, animações e entrada do catálogo global foram preservados para campanha,
partidas, perfis e quem já tem a recompensa. Não foram criadas skins 3D para as
novas cartas: os dez personagens acima são as imagens do deck fornecido pelo dono.
