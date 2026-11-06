# Prévia visual de skins e emotes

Branch: `work/skin-variations-emotes`.

Personagens possui abas Skins e Emotes. A aba Emotes mostra três cartões com
poses capturadas do modelo real. Tocar/clicar no cartão reproduz o movimento
no personagem maior, à direita. Mouse, toque e foco por teclado usam botões
nativos e o estilo existente de PlayerUI.

Os clipes são os FBX originais: Apresentação (`2.fbx`), Comemoração (`4.fbx`) e
Reação de derrota (`3.fbx`), nos sete personagens iniciais. El Fuego mantém o
estado sem emotes disponíveis. Cada prévia toca uma vez e restaura a pose ou
animação anterior. As reações automáticas continuam tendo prioridade.

Um palco temporário captura três miniaturas da skin selecionada, enquadrando
os ossos da pose. Depois é liberado. Os cartões usam texturas estáticas em cache;
o personagem maior é o único que continua animado. Não há imagem gerada por IA:
as miniaturas e capturas foram renderizadas pelo Godot com os assets existentes.

O escopo atual é uma prévia na coleção. Estilos alternativos de roupa/cor,
seleção salva na conta e emotes compartilhados no lobby/sala/partida continuam
como próximas etapas, dependentes da definição dos visuais e do uso desejado.

Validação no Godot oficial 4.7.2: dez verificações da galeria visual, 26 do
controle dos emotes e 69 de regressão das reações automáticas, sem falhas.
`tools/player_ui/check_design.py`: OK. Godot Web/Chromium aprovado em desktop
1672×941 e iPhone UA/DPR3 em 844×390 e 640×360: três miniaturas carregadas com
altura visível, cartões dentro da tela, clique/toque, reprodução e retorno à
pose, sem erros de script. O ajuste de altura preserva o tamanho dos cartões
sem aplicar a regra dos retratos de skins a eles.

Capturas em `evidence/skin-emotes`. São fixtures isoladas, sem acesso ao backend.
Não houve teste em iPhone físico; o ambiente não possui Xvfb.
