# Direção dos menus

As referências indicadas pelo usuário são **Fortnite, Call of Duty (COD) e PES**:
hierarquia clara, navegação direta, boa leitura e personagem em destaque.
A composição atual do lobby é a base de continuidade. Mudanças funcionais devem
preservar essa composição; não há autorização implícita para redesenhá-la.

Telas internas usam superfícies escuras discretas, texto claro, espaço para o
conteúdo e um acento contido para seleção/ação principal. O fundo e a identidade
do jogo permanecem. Não copiar marcas ou interfaces completas das referências.

## Referência reprovada

Molduras brilhantes azuis/douradas, brasões e cantos de cristal das antigas pastas
`assets/ui`, `assets/processed/frames`, `assets/processed/buttons` e
`assets/processed/textures` não devem orientar menus novos ou correções.
Os arquivos são históricos, não um tema ativo. Os anéis do HUD da campanha ainda
têm uso próprio em `resource_icons.gd`; não remover arquivos compartilhados sem
verificar esse uso. Fundos, logos, modelos e artes das cartas não fazem parte da
retirada do kit ornamental.

## Verificação

`python3 tools/check_menu_design.py` bloqueia referências a essas pastas nos
scripts/cenas de menus, telas do jogador, lobby e personagens. A campanha fica
fora desse escopo. Rodar também os fluxos de navegação e interação existentes.

A aparência deve ser conferida por capturas reais de Configurações, Personagens e
lobby em desktop e janela compacta. Manter busca, coleções, favoritos, bloqueios,
equipamento e prévia 3D. O resultado visual depende da avaliação do usuário;
passar no CI não equivale a aprovação estética.
