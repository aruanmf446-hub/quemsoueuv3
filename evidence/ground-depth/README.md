# Prévia: sustentação do terreno até fora da tela

Interpretação do pedido: a base abaixo do caminho é curta, deixa sua borda inferior
aparecer e revela o cenário atrás dela. Esta prévia trata dessa base em primeiro
plano; não reposiciona o cenário distante.

Na capital a base tinha 1,50 m de altura. No oásis e nas partes de pedra da mineração
havia apenas a laje superior; o muro e até palácios distantes apareciam abaixo dela.
Agora a sustentação de pedra desce 8 m, terminando fora do enquadramento. A superfície
pisável conserva sua altura. A textura mantém o tamanho dos tijolos por coordenadas
mundiais; não foi esticada nem foram empilhados pisos adicionais.

Os vãos reais, as estruturas abertas das pontes de madeira, o aqueduto, as casas
da fase 2 e as cavernas foram preservados. Nenhuma colisão, regra de queda, câmera,
movimento, modelo ou asset foi alterado. A mudança usa as malhas e o material de
pedra existentes e fica em `modular_architecture.gd`.

## Capturas reais do Godot 4.7.2

- Capital: [antes](844x390/before_fase_01.jpg) / [depois](844x390/after_fase_01.jpg).
- Oásis: [antes](844x390/before_fase_05.jpg) / [depois](844x390/after_fase_05.jpg).
- Também foram conferidas janelas de 1920×1080 e 640×360, nas duas fases.

Posicionamento inicial por fixture em x=35 m, sobre o piso real, seguido de vinte
passos físicos. Inimigos foram retirados da captura e a câmera foi estabilizada;
as imagens não representam um percurso completo. Rendering Compatibility, Xvfb e
llvmpipe. Sem validação em aparelho físico ou navegador nesta prévia.

Verificação: execuções gráficas sem erros de script; `check_design.py`,
`scope_test.py --base 25f69d4` e `git diff --check` aprovados. Não foi repetida a
suíte completa de gameplay, pois a alteração é somente visual e os arquivos de
colisão/layout continuam iguais à base.
