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

## Resgate obrigatório (2026-11-08)

`lado_sombrio` exige recibo real de `qse_rewards_claim` da conta GAME.
A presença das imagens, abrir Novidades, marcar como visto e revelar um pacote
não liberam esse deck. Antes do resgate ele aparece somente como oferta em
**Novidades → Resgatar grátis**, sem entrar em buscas, Biblioteca, leitor,
referências do criador de decks ou seleção local/online do Mata-Mata.

O contador **+N acima de Novidades** conta ofertas ainda pendentes. Abrir e
ignorar não o limpa. Após confirmação do resgate, Biblioteca e jogo local são
atualizados; trocar de conta remove o acesso da conta anterior. Os presentes
antigos concedidos automaticamente mantêm o comportamento existente.

### GAME

Migração `supabase/game/migrations/20261108220000_lado_sombrio_manual_claim.sql`
**aplicada e registrada no GAME** em 2026-11-08. Não reaplicar.

- Campanha `lado_sombrio_2026`, oferta `deck_lado_sombrio`, preço zero,
  `auto_grant=false`; nenhum backfill nem recibo criado para usuários reais.
- Dez cartas registradas em `qse_v3.duel_decks`, preservando UUIDs e imagens.
- Catálogo online, configuração, entrada e início da partida exigem recibo;
  iniciar exige resgate de todos os participantes humanos, inclusive espectadores.
- Pendências manuais de campanhas anteriores continuam no feed enquanto ativas.
- Nenhuma mudança no CATALOG, CHAT, pagamentos ou permissões de contas.

A conferência após aplicação encontrou **zero resgates do Lado Sombrio**.
Testes SQL com duas identidades temporárias exercitaram a implementação real no
PostgreSQL e terminaram em ROLLBACK; não equivalem a sessões HTTP de contas reais.
Validação do cliente e limitações em `evidence/lado-sombrio-resgate/README.md`.

## El Fuego em Personagens

A galeria, busca, contagens, setas e prévia direta omitem El Fuego quando
`InventoryService.is_unlocked("el_fuego")` é false. Esse é o desbloqueio existente
associado a `desert_campaign_completed`, sem concessão local fictícia. Assim que o
progresso confirmar o desbloqueio, ele aparece e pode ser selecionado/equipado.
O modelo, animações e entrada do catálogo global foram preservados para campanha,
partidas, perfis e quem já tem a recompensa. Não foram criadas skins 3D para as
novas cartas: os dez personagens acima são as imagens do deck fornecido pelo dono.
