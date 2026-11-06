# Pontes e guindastes sem bandeiras repetidas

Correção focada no feedback do dono: a repetição vinha das próprias artes `desert_timber_bridge` e `desert_mining_gantry`, não principalmente dos checkpoints.

- [Ponte antes](ponte_antes.jpg) / [depois](ponte_depois.jpg).
- [Guindaste antes](guindaste_antes.jpg) / [depois](guindaste_depois.jpg).
- As fotos são renderizações reais do Godot. A galeria aproxima o jogador por fixture e usa a câmera e os mecanismos do jogo. Não é imagem gerada.

O acabamento retira os estandartes das treliças, do pilar e do carrinho de minério. Mantém cordas, postes, lanternas, ferragens, carrinho, carga, fundações e proporções. As travessas que estavam ocultas pelo pano continuam inteiras; os espaços vazados mostram o fundo.

As duas texturas originais foram preservadas. Dois materiais compartilhados aplicam o acabamento aos sprites completos e aos recortes do catálogo; por isso a mesma correção alcança Tasks, fachadas, objetos e fundos. Não há novas imagens, luzes, colisores, processamento por quadro em GDScript ou mudanças na movimentação/ativação das Tasks. Não há redução de resolução.

Arquivos do produto: `industrial_finish.gd`, `industrial_finish.gdshader` e a aplicação no construtor de sprites de `city_props.gd`.

Validação: 22 verificações gráficas com os assets reais (retirada do pano, transparência dos vãos, presença do pilar/carrinho e preservação de pontos fora da correção), Tasks (182) e composição/streaming (110). Capturas em 844×390, 1920×1080 e 640×360. O teste `web_scenario_probe.cjs` mantém as três fases padrão e aceita `QSE_SCENARIO_ORDERS` para repetir uma fase específica.

O export Web final passou no Chromium com a fase 7: ativação por toque com cargas zeradas e travessia nos dois sentidos, sem erros JavaScript ou do motor. [Capturas e relatório](web). As 19 Tasks foram novamente fotografadas no render nativo, antes e depois. O teste completo de três mecanismos também passou durante o refinamento; o relatório final de Web refere-se especificamente ao acabamento final da ponte e do guindaste da fase 7.

Comando do teste gráfico:

```sh
DISPLAY=:104 godot --audio-driver Dummy --path . \
  --script tests/desert_night/industrial_finish_render.gd -- /tmp/industrial-finish
```

Capturas nativas usam Mesa llvmpipe; Web usa Chromium/WebGL2 e SwiftShader, iPhone emulado 844×390/DPR 3. Não é teste em Safari/aparelho físico nem medição de FPS em GPU real. Relatórios acompanham as imagens.
