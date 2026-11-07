# Samba aprovada — preço/resgate pendente

O dono aprovou a dança mostrada em `evidence/fbx-samba-test` e pediu para guardá-la
para compra/resgate, sem preço definido. As oito animações desse teste foram
preservadas aqui, com seus hashes e os rigs correspondentes em `manifest.json`.
São os mesmos 12 segundos preparados e validados para o teste aprovado; os
vídeos mostraram o trecho de 0 a 6 segundos.

Item universal da conta: `samba`, separado do placeholder `dance_01`.
`price_coins=null`, `purchase_enabled=false`. Não foi inserido preço fictício,
não houve criação/ativação de produto no Supabase nem concessão a usuários.

Decisão confirmada: mostrar no jogo e permitir ver o movimento agora, mantendo
compra/resgate bloqueados até o dono definir o preço. A aba Emotes mostra Samba,
“Preço a definir” e “Ver movimento”; nenhuma concessão gratuita é feita.
O manifesto registra conteúdo; o preço comercial futuro deverá vir do servidor.

Origem: FBX de exemplo Samba Dancing do Three.js; URL e SHA-256 no manifesto.
O FBX bruto e o personagem doador não estão incluídos. Os recursos Animation
foram adaptados aos modelos originais do projeto, conforme os testes e créditos
em `tests/fbx_dance/README.md` e `evidence/fbx-samba-test/README.md`.

Atualização: o GAME agora tem a cotação provisória de 50 moedas para Samba,
INATIVA, conforme o exemplo posterior do dono. O manifesto preserva a aprovação
do movimento e o preço não definitivo; a loja usa a cotação real do servidor.
Vendas continuam bloqueadas. Ver docs/backend/COMMERCE_ACTIVATION.md.
