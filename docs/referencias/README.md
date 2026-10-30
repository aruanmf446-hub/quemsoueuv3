# Direção visual dos menus

O usuário aprovou a composição limpa e a nitidez do lobby e pediu que esse
tratamento fosse aplicado aos demais menus, incluindo batalha.
A referência atual é [DIRECAO_CLEAN_APROVADA.png](menu/DIRECAO_CLEAN_APROVADA.png).
Ela preserva a identidade do jogo, com navegação leve, personagem em destaque,
hierarquia clara e uma ação principal dourada. As referências de organização
continuam sendo Fortnite, Call of Duty e PES.

## Aplicação nas telas internas

O sistema está centralizado em `scripts/ui/player_ui.gd`:

- `apply_theme`: fonte MSDF e filtragem linear com mipmaps, inclusive na entrada
  direta das telas; o filtro global Nearest Mipmap não deve chegar aos glifos.
- `style_button`, `style_row`, `style_back`, `style_field`: ações, navegação,
  seleção e campos. O dourado destaca a ação principal ou um estado selecionado.
- `plate`, `frame_panel`, `pill`: superfícies discretas, sem brilho ornamental,
  bordas espessas ou caixas repetidas. Os estados continuam distinguíveis.
- `split`, `flow`, `unit`: distribuição que respeita a largura e a densidade da
  janela, com campos e ações legíveis em telas horizontais compactas.

As telas usam texto claro, cores contidas, espaço entre grupos e personagem direto
sobre o cenário onde houver prévia. Campos editáveis, foco, bloqueio e erros devem
continuar reconhecíveis. Pausa, derrota e conclusão preservam suas ações reais.

As capturas da aplicação nas telas internas estão em
[evidence/menu-polish](../../evidence/menu-polish/README.md), para revisão visual.
A aprovação do lobby não deve ser confundida com aprovação automática de cada
nova captura.

## Arquivos anteriores

`menu/REFERENCIA_MENU.png` e `personagens/REFERENCIA_APROVADA.png` permanecem como
histórico. Seus cartões ornamentais, caixas e brilhos não substituem a direção
limpa aprovada nesta sessão. Não restaurar esses tratamentos para implementar uma
funcionalidade ou corrigir um bug.

`python3 tools/player_ui/check_design.py` continua impedindo imagens como moldura
nas telas do jogador. A verificação funcional não substitui a conferência visual.
