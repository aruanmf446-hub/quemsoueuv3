# Contexto das regiões do deserto

Continuação sobre `4d7a022`, na branch `codex/composicao-fases-tasks`. Objetivo: reconhecer cidade, água e mineração pelo ambiente, preservando a campanha aprovada.

As capturas são do Godot4.7.2 Compatibility, com câmera, HUD e personagens reais. A fixture aproxima o jogador para inspecionar a região; não é prova de travessia. Os percursos físicos foram executados separadamente. Não há simulação de aparelho físico.

## Capturas

- [Visão geral das dez fases](contexto-das-dez-fases.jpg).
- [Cidade e comércio](iphone/fase_03_regiao_09.jpg).
- [Margem do rio](iphone/fase_05_regiao_38.jpg).
- [Aqueduto](iphone/fase_04_regiao_09.jpg).
- [Mineração](iphone/fase_10_regiao_10.jpg).
- [1920×1080](desktop), [844×390](iphone), [640×360](standard) e [Web emulado](web).

## Resultados

491 verificações pertinentes aprovadas: contexto (72), composição (110), Tasks (182), parkour (52) e skyline/telhados (75). Percursos físicos completos das fases4/5/7/10 aprovados, sem mortes/respawn. São21 capturas nativas, todas com o personagem apoiado; não foram usados testes headless como aprovação estética.

Web exportado: fases3/5/7, Tasks acionadas por toque com cargas zeradas e passagens percorridas nos dois sentidos. Sem erros JavaScript ou do motor; relatório em `web/report.json`. Check de design, escopo e diff aprovados. Não se declara o smoke geral aprovado; o histórico anterior de verificações legadas está preservado em `evidence/composicao-fases-tasks/validacao/`.

## O que mudou

| Região | Contexto |
| --- | --- |
| Capital e bazar (1/3) | Pátios pavimentados que apoiam o casario; cerâmicas, tâmaras, tecidos e caixas junto às áreas comerciais. |
| Telhados (2) | Preservados os tetos das próprias casas e a altura do percurso. |
| Aqueduto (4) | Canal mais legível entre margens de alvenaria; vegetação pontual nas aproximações do oásis. |
| Oásis (5) | Água entre duas margens, pedras, vegetação baixa e jardins em profundidades distintas. |
| Ruínas (6) | Terreno, pequenos escombros e cerâmica parcialmente enterrada junto aos monumentos. |
| Estrada e pátio da mineração (7/9) | Terreno de apoio, trilhos, dormentes e carrinhos de minério extraídos da arte aprovada. Portal da mineradora continua só no final. |
| Posto de controle (8) | Pátio e caixas de abastecimento junto à arquitetura militar existente. |
| Interior da mina (10) | Trilhos e carrinhos nas galerias, madeira texturizada nos apoios; minerais ilustrados substituem as antigas formas laranjas simples. A arena não recebe os novos complementos. |

## Assets

Novos: `riverbank_context.res` (1024×211) e `city_supplies_context.res` (1024×353), com transparência e mipmaps, cerca de1,8MiB somados em disco. Fontes geradas com `image_gen` usando a biblioteca aprovada como referência; originais preservados, hashes e recortes em [PROVENANCE.md](../../assets/desert/modular/PROVENANCE.md) e `context_assets.json`.

Reaproveitados: os quinze módulos anteriores, materiais de alvenaria/arenito e madeira da ponte. O carrinho é um recorte do guindaste existente, com o acabamento sem bandeiras. Os assets de personagem não foram alterados.

## Montagem e limites

As novas malhas são reunidas por material no mesmo chunk, com até três lotes adicionais por construtor e ilustrações limitadas por laje. Materiais/texturas são compartilhados. Não há nova luz, colisor ou processamento contínuo em GDScript; a água usa um material compartilhado animado no GPU. Não houve redução de resolução ou mudança em gameplay, controles, progressão, áudio, menus ou backend.

As peças ficam atrás da linha de corrida; o teste verifica profundidade, apoio das ilustrações, limites laterais, aquecimento por região, ausência de duplicação e descarregamento. Não se apresenta contagem de lotes como medição de FPS em celular.

Validação e capturas em `iphone/`, `desktop/`, `standard/` e `validacao/`. Navegador: Chromium com WebGL2/SwiftShader, iPhone emulado 844×390/DPR3; não equivale a Safari nem a aparelho físico. Não foram testados serviços online. Avisos de recursos ObjectDB no encerramento constam nos logs; não se afirma ausência de vazamentos.

Reprodução da galeria:

```sh
QSE_TEST_IPHONE=1 DISPLAY=:104 godot --audio-driver Dummy --path . \
  --script tests/desert_night/regional_context_gallery.gd -- /tmp/regioes 844x390 \
  1:2,2:3,3:8,4:9,4:38,5:8,5:38,6:12,7:8,8:9,9:35,10:10 --touch-controls
```
