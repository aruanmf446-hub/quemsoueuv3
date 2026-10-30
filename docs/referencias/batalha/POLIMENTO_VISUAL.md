# Batalha — acabamento sobre a estrutura aprovada

Pedido do usuário em 30/10/2026, acompanhado da imagem de referência na conversa.
A estrutura existente está aprovada: voltar/título, participantes superiores,
instrução, grade pública fixa, coluna direita, chat e mão privada. A aprovação da
estrutura **não significa aprovação estética da versão anterior nem desta revisão**.

Esta rodada refina retratos, materiais, molduras, foco da arte, tipografia,
contraste, estados e ícones. Não autoriza reorganizar as regiões, criar painel
esquerdo, alterar proporção das imagens, adicionar cartas, rolar o tabuleiro,
simular voz/chat de sala nem modificar regras ou backend.

Referência: cartoon premium, grafite/azul-marinho, relevo e sombras leves,
filetes e reflexos dourados controlados; sem restaurar o kit ornamental antigo.
O estilo continua derivado de PlayerUI, restrito aos componentes da batalha.

## Implementação

- Retratos originais de 720px, com recorte de busto e maior presença dentro da
  faixa superior. Pequenos ajustes de espaçamento recuperam área para o retrato,
  preservando as mesmas regiões. O personagem da vez tem realce dourado e escala
  ligeiramente maior; dano usa flash/escala curtos e derrota dessatura o retrato.
  Após revelada a eliminação, o contorno ativo é retirado.
- Superfícies nativas com gradiente grafite, bevel, sombra de contato, reflexos
  de borda e halo âmbar discreto no participante ativo. Fundo opaco com gradientes
  radiais de baixa resolução e diagonais discretas, sem cenário ilustrado novo.
- Cada ilustração mantém a proporção e os pixels originais. Pontos focais corrigem
  o recorte genérico que escondia a cobra e rostos. A geometria da grade permanece
  dinâmica, com todas as opções, sem rolagem nem paginação.
- Cartas: borda/sombra, tarja com padding, foco/seleção dourados e marca de seleção;
  carta eliminada com dessaturação real, arte escurecida e nome ainda legível.
- Fonte existente em MSDF com peso moderado nos títulos, nomes e temporizador.
  Painéis laterais compartilham superfícies e padding; textos de indisponibilidade
  preservam a verdade sobre os serviços reais.
- SVGs com rasterização 4× e mipmaps; ícone de olho alterna conforme a ação.
  Mão oculta usa um verso abstrato, sem expor nem inventar uma carta jogável.
- Avisos pequenos na região lateral, com duração e fade; não cobrem o tabuleiro.

## Assets

Reaproveitados: nove PNGs de `assets/duel/decks/lendas_urbanas`, retratos reais de
`assets/portraits`, fonte `assets/desert/phase01/interface.ttf`, ícones de vida,
cores/tema de PlayerUI e dez SVGs existentes de `assets/ui/battle` (refinados).
Nenhum personagem, ilustração ou textura de terceiro foi introduzido.

Novos: `assets/ui/battle/eye_off.svg` e `private_back.svg`; acabamento vetorial em
`battle_card_finish.gd` e shader leve `battle_illustration.gdshader` (uma amostra de
textura, contraste/saturação discretos e dessaturação). Fundo/molduras são desenho
nativo com gradientes, sem bitmap grande, partículas contínuas ou pós-processamento.

## Arquivos da rodada

- `scripts/ui/screens/duel_match_view.gd`
- `scripts/ui/battle/battle_surface.gd`
- `scripts/ui/battle/battle_style.gd`
- `scripts/ui/battle/battle_card.gd`
- `scripts/ui/battle/battle_chat.gd`
- `scripts/ui/battle/battle_card_finish.gd` (novo)
- `scripts/ui/battle/battle_illustration.gdshader` (novo)
- SVGs e respectivos `.import` em `assets/ui/battle`
- `tests/battle_reference/flow.gd`: pontos de referência da arte, retirada do
  destaque na eliminação e capturas dos estados; verificações anteriores preservadas.
- Documentação e evidências desta revisão.

Não foram modificados serviços de Duelo, gameplay, economia, Supabase, modelos,
perfil gráfico do APK nem a main. Capturas e validação estão em
[evidence/battle-reference/polish-2026-10-30](../../../evidence/battle-reference/polish-2026-10-30/README.md).
Aguardar avaliação visual do dono antes de integrar.
