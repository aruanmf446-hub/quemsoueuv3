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

As telas internas usam fundo sólido opaco (`PlayerUI.INTERIOR_BG`), texto claro,
cores contidas e espaço entre grupos. O cenário ilustrado é exclusivo do lobby.
Personagens e cartas aparecem como conteúdo, sem a imagem do lobby por trás.
Os retratos reais distribuídos em `assets/portraits` funcionam desde a primeira
abertura, inclusive no Duelo e em Amizades, sem cache anterior. Campos editáveis, foco, bloqueio e erros devem
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

## Criador e acompanhamento de decks — referência de composição de 06/11/2026

O dono enviou novas referências específicas para Criar deck, Revisar deck e
Status dos decks, pedindo adaptação da interface existente. Nessas telas,
`PlayerUI.creator_*` agrupa metadados e cartas em superfícies azul-violeta,
com molduras discretas, capa real, ícones e acentos dourados. O motivo da
reprovação tem destaque próprio; reprovado usa vermelho, aprovado usa verde.
A revisão se organiza para a tela deitada, com resumo e prompt ao lado das
cartas, e ações persistentes no rodapé. Fontes, limites reais, controles nativos,
identidade da conta e fluxos existentes permanecem os mesmos.

A arte de referência não vira fundo/hotspots; não há tema paralelo nem
alteração global nas demais telas. Capturas e validação em
[evidence/deck-creator-polish](../../evidence/deck-creator-polish/README.md).
