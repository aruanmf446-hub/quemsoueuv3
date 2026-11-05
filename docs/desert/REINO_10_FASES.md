# Reforma das dez fases do Reino do Deserto

Branch: work/reino-deserto-10-fases. Base:967a408. Sem merge/publicação autorizados nesta rodada.

## Organização e recursos

As cenas scenes/desert/phase_01.tscn até phase_10.tscn usam o controlador existente
scripts/desert/t15d/phase.gd. A cena10 foi migrada pelo ResourceSaver, sem editar
texto de cena. campaign_layout.gd define superfícies mundiais, vãos, patrulhas,
recargas, checkpoints e oito setores por região. IDs antigos de fase continuam
compatíveis com o contrato do projeto; nenhum backend é alterado.

Ordem: Portões da Capital; Telhados da Capital; Bazar da Cidade; Aqueduto do Deserto;
Jardins do Oásis; Ruínas Enterradas; Estrada da Mineração; Posto de Controle;
Entrada da Mineradora; Interior da Mineração.

Cada percurso tem pelo menos1452m, sem espera artificial na saída. A fase2 começa
a8m da rua e todo piso jogável pertence às lajes. Fachadas, janelas inferiores,
parapeitos e vãos são geometria3D. A fase9 recebe o portal monumental somente no
fim. A fase10 tem galerias, suportes, trilhos, carrinhos, cristais e Malagueta com
modelos/animações originais, vida20 e saída condicionada à derrota.

A biblioteca modular é modular_architecture.gd + city_props.gd. Materiais de pedra
são compartilhados; rochas volumétricas usam MultiMesh. Luz real é limitada por
chunk; janelas e lanternas mantêm material emissivo. Panorâmicas noturnas aprovadas
ficam exclusivamente distantes. Os planos simplificados do ZIP deixaram de compor
o cenário. Procedência em assets/desert/modular/PROVENANCE.md.

## Gameplay

Soldados são reaproveitados da reserva original, perseguem depois que o jogador
os ultrapassa, saltam vãos com uma laje real de aterrissagem e obstáculos baixos,
e mantêm espaçamento. Ondas verificam o apoio de cada soldado e nascem com intervalo,
sem empilhamento instantâneo. A mesma consulta de piso sustenta inimigos e recargas.

Recargas ocupam pedestais na altura real do piso, em zonas de recuperação após os
saltos; não são moedas decorativas. Capacidades continuam3. Ruptura altera o colisor
de uma peça marcada atrás do jogador, inclusive sob perseguidores, preservando
itens/checkpoints e o protagonista; Âmbar imobiliza temporariamente; Relâmpago
continua com colisão e cancelamento. Corrigido contato que causava dano fora da
janela de ataque, inclusive quando um inimigo estava congelado.

Os recursos aquecem durante a narrativa, incluindo o material novo e os modelos
de Malagueta ao entrar na fase10. Histórico local de leitura é preservado.

## Validação executada — Godot 4.7.2

Evidências: [relatório e painel](../../evidence/reino-10-fases/README.md).

- Dez travessias completas aprovadas por entradas físicas, sem teleporte ou
  invulnerabilidade. A décima inclui derrota de Malagueta e saída. As rotas levaram
  aproximadamente 4min08 a 4min39 de tempo simulado: o alvo de três minutos ainda
  merece balanceamento com jogadores, sem uma espera artificial na saída.
- Runner consolidado: 17 etapas aprovadas. Mecânicas novas: 67/0; layout: 130/0;
  mineração/chefe: 6/0; progresso: 30/0; variedade: 15/0; checkpoints: 21/0;
  controles: 10/0; cada travessia: 11/0.
- Guarda iPhone: 504/0. Intro: 67/0. PWA: 29/0. Design e escopo aprovados.
- 63 capturas reais em 1672×941, 844×390 e 640×360. Pontos intermediários e portal9
  são fixtures teleportadas para inspeção, não provas de travessia.
- Importação normal e export de produção concluídos. A restrição inicial do
  importador foi resolvida após a continuação autorizada pelo dono; não houve
  edição manual de cache. MCP Godot indisponível: CLI oficial e ResourceSaver usados.
- WebAssembly real no Chromium, UA iPhone, viewport844×390, DPR3: oito quadros por
  toque, consumo de carga, persistência após reload e soldado perseguindo sobre
  a laje de8m. Relatório sem erros de página ou scripts do motor. Testes/fixtures,
  evidências e fontes de autoria não entram no pacote de produção.

## Pendências para aprovação

- Revisão artística do dono: as estruturas próximas agora são modulares e jogáveis,
  mas a densidade arquitetônica, vegetação e acabamento de alguns módulos ainda
  ficam abaixo da referência ilustrada. Não declarar fidelidade visual aprovada.
- Balancear duração e dificuldade com jogadores; o piloto automatizado não mede
  a experiência humana e seus tempos não são benchmark de renderização.
- Validar Safari/PWA em iPhone físico, Android e Windows. Chromium emulado e capturas
  nativas não validam esses aparelhos. Não foram testados OAuth ou backend online.
- Alguns testes de encerramento imediato registram avisos de liberação de playback
  WAV; não foram encontrados erros de script/importação nas capturas finais.

Nenhuma autenticação, Supabase, economia, menu musical ou asset de personagem
alterado. Esta rodada é entregue na branch de revisão, sem merge nem Pages.

## Ajuste solicitado após reprovação visual

A revisão de05/11 substitui a progressão anterior: congelamento para trás na fase3,
corrida elétrica na fase4 e Ruptura atrás na fase5. Recargas desses poderes só
aparecem a partir do capítulo correspondente; capítulos anteriores ocultam as
habilidades mesmo quando já descobertas em outro save. Congelamento respeita a
orientação de El Fuego; corrida aplica um choque por inimigo por carga.

Nas fases1/2 os buracos reais permanecem entre superfícies. Telhados agora têm
obstáculos baixos periódicos; soldados ficam depois das zonas de abastecimento,
com apoio e corredor de aproximação, não encostados na primeira aterrissagem.
Vida, ataque e defesa continuam em pedestais apoiados e separados. Pisos marcados
usam o sistema existente de retirada/restauração real de colisão para Ruptura.

As duas imagens em art-approved são conceitos gerados pela ferramenta de imagens,
aprovados pelo dono, sem personagens substitutos. O panorama posterior foi
reprovado e não foi instalado. **A arte aprovada ainda não foi integrada como
camadas/módulos ao cenário jogável**; as alterações desta rodada são de gameplay.
Não confundir os conceitos aprovados com as capturas da versão reprovada.
