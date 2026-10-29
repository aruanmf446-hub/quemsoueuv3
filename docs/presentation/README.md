# Abertura, transições e novidades

Esta branch adiciona uma apresentação do jogo antes do lobby. O Godot abre
`scenes/menu/menu_boot.tscn`: a primeira imagem aparece antes de ler a cena do
menu. Três cartões com arte do projeto e legenda em caixa inferior deslizam
automaticamente. O botão **Pular abertura** entra no menu assim que a cena está
pronta. Sem interação, a abertura dura cerca de seis segundos; não há espera
artificial depois que a sequência termina.

O botão **Novidades** no lobby abre uma galeria editorial independente. Os
cartões avançam a cada cinco segundos; setas permitem navegar manualmente e
**Fechar** ou Esc retorna ao lobby. Textos e imagens estão em
`data/ui/presentation.json`, para que a equipe possa atualizar notícias sem
alterar código. As mensagens atuais tratam apenas de conteúdo já disponível ou
identificam explicitamente o que ainda está em desenvolvimento.

A música licenciada só acompanha o lobby visível: a abertura e as fases ficam
silenciosas quanto a esse catálogo. Ao retornar ao lobby, a reprodução do menu
volta a seguir as preferências do jogador.

Ao iniciar uma fase e ao avançar para a seguinte, a mesma apresentação cobre a
leitura da cena. Essa transição usa arte e frases da cidade noturna, sem mostrar
nomes de arquivos ou porcentagens ao jogador. Se a cena falhar, aparecem
**Tentar novamente** e **Voltar**. O carregamento de PackedScene ocorre na
thread principal depois de dois quadros desenhados: neste projeto, o carregador
em thread falha ao resolver `preload()` de cenas aninhadas no Godot 4.7.2.
A sequência mantém o último cartão na tela durante qualquer pausa nessa leitura.

Validação: `tests/presentation/flow.gd` percorre abertura, notícias e entrada na
fase no Godot 4.7.2. Capturas reais em `evidence/presentation/` foram geradas em
1920×1080, 1280×720 e 844×390. O teste de navegação da campanha agora espera a
transição visual antes de verificar a fase seguinte. `tests/presentation/failure.gd`
confere tentativa novamente, retorno e pulo da abertura; ele solicita uma cena
inexistente de propósito, por isso seu log contém erros esperados de recurso.
O smoke geral passou nas 22 etapas. É preciso ainda medir tempo
de carga e desempenho em Android físico e navegador Web.
