# Skins e emotes — desenvolvimento

Branch: `work/skin-variations-emotes`.

A primeira etapa acrescenta um seletor de prévia em Personagens, reutilizando os
FBX existentes: Apresentação (`2.fbx`), Comemoração (`4.fbx`) e Reação de derrota
(`3.fbx`). São três animações por personagem inicial. El Fuego não recebe emotes
inventados a partir dos ataques e ações de plataforma.

Cada prévia toca uma vez e restaura a pose ou o loop anterior. Uma reação
automática interrompe a prévia e cancela o retorno pendente. Repetir/trocar o
emote e liberar o modelo também limpa esse estado. Nenhum modelo, textura ou
animação original foi substituído; não há novos assets, cobrança ou alterações
de autenticação/backend nesta etapa.

O catálogo atual não contém estilos de cor/roupa alternativos. Foram perguntados
ao dono o tipo de variação (novas cores ou modelos/texturas já prontos) e o alcance
dos emotes (lobby/sala ou também partida). Essas escolhas seguem pendentes.
Ainda não há estilos alternativos equipáveis, seleção de emote salva na conta
ou transmissão de emotes para os demais jogadores. A interface implementada
nesta etapa é uma prévia na coleção, não a conclusão de todo esse fluxo.

Validação: Godot oficial 4.7.2, teste `tests/skin_emotes/preview.gd` com 26
verificações e regressão `tests/duel_avatars/animations.gd` com 69, sem falhas.
`tools/player_ui/check_design.py`: OK. O ambiente não possui Xvfb; a conferência
visual usa uma exportação real do Godot Web com fixtures isoladas e rede externa
bloqueada. Não se trata de teste em iPhone físico.

Web: aprovado em 1672×941, 844×390/DPR3 e 640×360/DPR3, com clique/toque,
reprodução e retorno à pose sem erros. O primeiro teste em 640×360 identificou
um excesso de largura; seletor com texto recortável e botão curto corrigiram
o encaixe sem reduzir as fontes. Capturas em `evidence/skin-emotes`.
