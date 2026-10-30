# Correção de desempenho da campanha

Base final: `main` em `b4cdccf` (inclui os modelos leves das entregas #21/#22).
As primeiras medições abaixo foram feitas antes dessa atualização e são referência
histórica; não atribuem à presente branch o ganho dos modelos leves.

A correção atua no processamento local; os assets continuam no projeto. Mover os
mesmos modelos para Cloudflare R2 pode mudar o tempo de transferência, mas não
reduz geometria, animação, memória de renderização nem geração de cenário.

- A fila do mapa valida o ID do trecho antes de executar cada tarefa. Tarefas de
  trechos removidos ao avançar/voltar são descartadas sem acessar nós liberados.
- Fachadas e lanternas são preparadas por unidade; a malha final mantém o mesmo
  agrupamento por material. Trechos distantes entram na fila também no spawn.
- Cactus reutilizam a biblioteca de animações já processada antes da etapa que
  instanciava novamente os FBX de cada animação.
- Web/mobile/viewport compacto usam os LODs importados mais cedo, sem sombras
  dos personagens/lua e sem MSAA. Luzes, texturas, colisões e regras permanecem.
- O palco do lobby/Skins tem teto de 520 mil pixels no Web/celular, sem MSAA ou
  sombra dinâmica. Desktop mantém o perfil escolhido.

## Medidas e reprodução

Godot 4.7.2 Compatibility, ambiente Linux com renderização por software; não é
um teste em iPhone/Android físico. As rotinas `tests/performance/actor_cost.gd`,
`stream_cost.gd`, `model_cost.gd` e `mobile_render.gd` imprimem medidas, não
limites universais de aprovação. O cenário de 844×390 é capturado pelo último.

A malha de corrida original de El Fuego tem 358.824 vértices. No mesmo quadro
nativo em 844×390, o monitor de primitivas caiu de 26.046 (LOD anterior) para
10.312 (LOD móvel). O microteste de decoração mediu pico de 18,193 ms para o
bloco síncrono e 2,679 ms por tarefa distribuída, com as mesmas contagens de
prédios/lanternas. Isso não estabelece um limite de 33 ms para o quadro inteiro.

Com os PackedScenes mantidos em cache, como na fase, instâncias repetidas do
Cactus custaram cerca de 1,8 ms antes e 0,6–1,1 ms depois. A medição inicial de
61–75 ms não mantinha o cache de recursos da fase; representa carregamento frio
e não deve ser usada como custo repetido durante a corrida.

O navegador de teste usa Chromium/SwiftShader. A meta de 45–60 FPS precisa de
medição em aparelho físico; não há evidência para declarar essa meta atingida.
As cenas ainda fazem a leitura inicial de recursos na thread principal. O
carregamento inicial pode pausar, mesmo com a melhoria dos trechos em corrida.

O carregador antecipa os FBX dinâmicos de El Fuego/Cactus um recurso por quadro
antes de liberar a história da fase. O PackedScene mantém as referências até a
instanciação, evitando refazer a leitura ao tocar em Começar/Pular. A carga de
um único recurso ainda pode bloquear esse quadro; não foi introduzido um worker
para PackedScenes, pois os preloads aninhados falham no Godot 4.7.2 do projeto.

O export Web omite dez texturas de origem sem dependências de FBX/cenas/código
(em geral JPGs usados apenas nos OBJ já excluídos do Web). Nenhum arquivo fonte
foi removido. O pacote local caiu de 76.824.616 para 66.544.780 bytes. Esse valor é da rodada anterior à integração de #21/#22. O export final
com os modelos leves da main tem **35.379.616 bytes**, abaixo de 60 MB.

Na amostra de 4 segundos da mesma cena parada em Web 844×390, Chromium com
SwiftShader por software registrou 5,24 FPS no build publicado e 8,53 FPS no
candidato local. A amostra não mede corrida, nem comprova 33 ms por quadro de
troca de trecho. URLs/origem de rede diferentes e ausência de GPU/aparelho real
limitam a comparação. Valores brutos estão em `evidence/performance/measurements.json`.

O shell Web agora limita o canvas móvel a DPR 1,25 e 700 mil pixels. Em
844×390/DPR 3, o teste Chromium com toque abriu a fase com canvas1055×487
em vez de 2532×1170 (cerca de 83% menos pixels). `UIScale` lê os pontos CSS
da janela para preservar tamanho e posições dos controles. A captura Web é
dessa emulação; não é uma captura de iPhone físico.
