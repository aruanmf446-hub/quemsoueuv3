# Carregamento e fila do mapa, preservando a qualidade

Base: `main` em `b4cdccf`, incluindo os modelos leves já entregues em #21/#22.
Esta branch não introduz redução gráfica no APK. Sombras, MSAA, LOD e o orçamento
anterior do palco móvel foram restaurados. Os perfis escolhidos pelo jogador
continuam funcionando; o navegador de PC em janela ampla pode usar os parâmetros
de qualidade do desktop, sem receber um limite adicional de celular.

## Mudanças mantidas

- A fila valida o ID do trecho antes de executar uma tarefa. Trabalho de um trecho
  removido ao avançar/voltar é descartado sem acessar nós liberados.
- Fachadas/lanternas são montadas por etapas, com os mesmos materiais e geometria.
  O trecho distante entra na fila também na entrada/reinício.
- Cactus reutilizam a biblioteca já processada antes de instanciar novamente os
  FBX de origem. Regras de ataque, colisão e animações são preservadas.
- O carregador lê os modelos dinâmicos um recurso por quadro durante a capa e
  mantém referências até a instanciação da fase. A leitura individual ainda pode
  bloquear um quadro; não se afirma um limite absoluto de 33 ms.
- O export Web omite dez texturas de origem sem uso pelo jogo, mantendo os arquivos
  no repositório. Isso não altera compressão/resolução das texturas usadas nem
  modifica o preset Android.

Não há limitação nova de DPR/resolução do canvas Web. A proposta anterior de
reduzir gráficos automaticamente foi retirada a pedido do usuário, antes de ser
mesclada na main. Medidas de FPS/geometria dessa proposta foram retiradas da
aceitação da entrega atual.

## Verificação

O teste existente de configurações verifica Baixo/Médio/Alto, sem mudar suas
asserções. Os percursos das nove fases, navegação desktop/celular e smoke usam
Godot 4.7.2 Compatibility. Resultados finais estão em `evidence/performance/`.
`tests/performance/stream_cost.gd` compara montagem síncrona e distribuída com
as mesmas contagens de prédios/lanternas; seus tempos dependem da máquina.

Os testes deste ambiente usam Linux e GPU por software. Não comprovam 45–60 FPS
no celular nem igualdade de FPS entre Web e nativo. Não foi executado um APK em
aparelho físico. O R2 pode mudar a transferência dos arquivos, mas não remove o
custo de execução de malhas, animações e geração de cenário no aparelho.

Na rodada completa, 25 etapas passaram e a fase09 registrou um passo de48,53ms
durante carga concorrente do navegador de teste. A reexecução isolada da fase09
passou com máximo11,46ms e p950,878ms, sem modificar a verificação de33ms. O
relatório inicial e o resultado isolado são preservados nas evidências. Todas
as nove fases terminaram sem mortes; isso não garante um teto de33ms sob toda
carga de sistema/aparelho.
