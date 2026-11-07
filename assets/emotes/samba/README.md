# Samba aprovada — preço/resgate pendente

O dono aprovou a dança mostrada em `evidence/fbx-samba-test` e pediu para guardá-la
para compra/resgate, sem preço definido. As oito animações desse teste foram
preservadas aqui, com seus hashes e os rigs correspondentes em `manifest.json`.
São os mesmos 12 segundos preparados e validados para o teste aprovado; os
vídeos mostraram o trecho de 0 a 6 segundos.

Item universal da conta: `samba`, separado do placeholder `dance_01`.
`price_coins=null`, `purchase_enabled=false`. Não foi inserido preço fictício,
não houve criação/ativação de produto no Supabase nem concessão a usuários.

Pendente esclarecer a frase “sem preço … resgatar com preço”: resgate gratuito
ou resgate bloqueado até definir um preço. Não assumir 0 nem reutilizar as
100 moedas do placeholder. O registro comercial só deve ser conectado depois
dessa definição. O manifesto nesta pasta é um registro de conteúdo, não uma
autorização de compra nem a fonte de preços do servidor.

Origem: FBX de exemplo Samba Dancing do Three.js; URL e SHA-256 no manifesto.
O FBX bruto e o personagem doador não estão incluídos. Os recursos Animation
foram adaptados aos modelos originais do projeto, conforme os testes e créditos
em `tests/fbx_dance/README.md` e `evidence/fbx-samba-test/README.md`.
