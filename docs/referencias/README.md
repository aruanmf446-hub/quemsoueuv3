# Referências visuais — qual é o modelo

Esta pasta é a **única fonte de verdade** da aparência das telas. Antes de mexer em
qualquer interface, abra estas imagens. Agentes (Claude, Codex) devem seguir estas
referências e **não** criar outro estilo "para combinar com o resto do jogo".

## Modelo aprovado

| Referência | Vale para | O que copiar |
| --- | --- | --- |
| [`personagens/REFERENCIA_APROVADA.png`](personagens/REFERENCIA_APROVADA.png) | **Todas as telas do jogador**: Personagens, Configurações, Amigos, Música, Duelo, Perfil, Carteira, História | Superfícies azul-noite translúcidas sobre o cenário; filete fino frio; cantos de 8–10 px; títulos de seção em dourado claro; item selecionado com fundo âmbar escuro e filete dourado; cartões com selo de estado em largura total; ação principal dourada com texto escuro; palco do personagem direto sobre o cenário, sem caixa. |
| [`menu/REFERENCIA_MENU.png`](menu/REFERENCIA_MENU.png) | Menu principal / lobby | Botões grandes de modo com arte, painel de amizades, perfil e moedas no topo. |

Organização e navegação: menus de **Fortnite, Call of Duty e PES** (hierarquia clara,
poucas cores, foco no conteúdo). São referência de organização, não de ornamento.

## Como o modelo vira código

Os valores da referência estão em [`scripts/ui/player_ui.gd`](../../scripts/ui/player_ui.gd)
(`PlayerUI`): `PANEL_BG`, `SURFACE`, `FIELD_BORDER`, `GOLD`, `TITLE_GOLD`, `SELECTED_BG`,
`TEXT`, `MUTED` e os componentes `style_button` (principal / secundário / selecionado),
`style_row` (linhas de lista), `style_field` (pesquisa e seletores), `pill` (selo
EQUIPADO / DISPONÍVEL / BLOQUEADO), `plate` (cartões) e `frame_panel` (painéis).
Telas novas usam esses componentes; não definem cores próprias.

Painéis, botões e cartões são desenhados com `StyleBoxFlat` (cor, filete e cantos). Telas do
jogador não usam imagens como moldura (`NinePatchRect` / `StyleBoxTexture`);
`python3 tools/player_ui/check_design.py` (CI) confere isso.
