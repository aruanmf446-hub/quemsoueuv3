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

## Validação em curso

- Testes novos: reino10_test.gd (abertura das dez cenas, recargas apoiadas/separadas,
  perseguição, salto real entre lajes, cristal, Ruptura elevada e capacidades).
- legacy10_test.gd foi atualizado para o escopo agora autorizado: mineração extensa,
  modelo/vida originais de Malagueta, ataque real e bloqueio da saída enquanto vive.
- progress_test.gd aceita dez conclusões e rejeita fase11; dados locais isolados.
- route.gd usa somente entradas e itens reais. Resultados finais devem incluir todas
  as travessias e a arena, não apenas as provas isoladas. Tentativas que falham não
  são apresentadas como vitória nem validadas em aparelho.
- Capturas nativas: início, setor intermediário e portal final9. Pontos intermediários
  são fixtures teleportadas identificadas e não demonstram travessia.
- Nenhuma autenticação, Supabase, economia, menu musical ou asset de personagem alterado.

A revisão automática bloqueou o editor/importador, alegando conflito com
AGENTS.md:7 sobre .godot/. Foi solicitada autorização ao dono para geração normal
do cache. Não houve edição manual nem importação por caminho indireto. Como alternativa
permitida, o material foi salvo via runtime headless como ImageTexture nativo.res:
não exige importador e conserva PNG de autoria numa pasta.gdignore. A importação
de editor e o exportWeb ainda precisam ser liberados/validados nesta rodada.

Não considerar esta rodada concluída até fechar as regressões finais e a revisão
visual dos dez percursos, especialmente telhados e arena da mineração.
