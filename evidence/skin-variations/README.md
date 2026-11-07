# Variações — capturas reais do Godot

Original e duas paletas para os oito avatares, em aba própria. São 16 variações
de cores sobre os modelos existentes, não novas roupas/modelos. As capturas
mostram miniaturas do motor e a prévia selecionada. Nenhuma imagem gerada por IA.

Validação executada no Godot 4.7.2 oficial:

- `tests/skin_emotes/variations.gd`: 55 verificações, failures=0. Cobre os oito
  modelos, aplicação/restauração, seleção, setas, memória por personagem,
  renderização sob demanda e retorno à reação de vitória animada.
- `tests/skin_emotes/purchase.gd`: regressão de 14 verificações, failures=0.
- `python3 tools/player_ui/check_design.py`: OK.
- Export Web oficial + Chromium: oito personagens em 1672×941; Cowboy,
  El Fuego, Halloween, Michelly e Lana também em 844×390 e 640×360,
  com iPhone UA/DPR 3. Três estilos selecionados por personagem, miniaturas
  prontas, controles dentro da tela e setas funcionais. Zero erros de script.
  `results.json` reúne as 18 combinações de personagem/resolução. Os dois
  relatórios de execução preservam a cobertura geral e o refinamento das
  paletas de Halloween, Michelly e Lana.

As capturas terminadas em `style_2.png` mostram o violeta/carmesim selecionado
e os três estilos nos cartões. Não representam compras ou novos desbloqueios;
o inventário das capturas usa fixtures, sem rede externa ou contas reais.

Original mantém o material anterior. O shader trabalha em materiais da
instância da prévia; não altera FBX/OBJ/texturas, autenticação, Supabase,
economia ou equipamento sincronizado. A seleção não é vendida nesta etapa de
prévia. O desbloqueio original de El Fuego continua preservado.

Não foi validado em Safari/iPhone físico. Main/Pages não foram publicados.
