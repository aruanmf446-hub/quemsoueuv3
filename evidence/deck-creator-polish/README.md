# Criador, revisão e status de decks — adaptação visual

Referências enviadas pelo dono em 06/11/2026: organização em grupos, capa,
metadados, cartas com moldura, ações douradas e motivo da reprovação destacado.
Adaptação da interface nativa existente, mantendo o fundo opaco e sem usar a
referência como imagem da tela. Não houve geração de arte: cartas, capas e
ícones reutilizam recursos existentes.

Os componentes ficam em `scripts/ui/player_ui.gd` (`creator_*`), com a fonte e
os controles já usados pelo jogo. A variação visual é aplicada somente ao
criador/revisão/status. As outras telas e os sistemas de conta, música e backend
não foram alterados.

- Editor: metadados agrupados, contagem real de caracteres, capa opcional,
  capacidade de cartas, prévias enquadradas e ferramentas nativas organizadas.
- Revisão em landscape: resumo com capa e informações à esquerda, prompt em
  faixa compacta e galeria à direita; envio e acompanhamento fixos no rodapé.
- Status: cabeçalho contextual, capa real, selo de situação e motivo em aviso
  próprio, com ação para corrigir e reenviar. Reprovação vermelha e aprovação
  verde preservam o significado dos estados.

Limites e fluxos existentes permanecem iguais, inclusive descrições de deck
até 400 caracteres e de carta até 300, escolha de capa, cópia do prompt,
Storage, revisão manual e reenvio do mesmo deck. A barra conta a capacidade
ocupada (até 30 cartas), sem simular aprovação ou avanço da revisão.

## Validação

Godot 4.7.2: T21_DECKS 51 verificações, zero falhas. Capturas reais do editor,
carta, revisão incompleta e revisão com cinco imagens oficiais em desktop
1672×941 e perfil iPhone 844×390 e 640×360: failures=0. O teste confere o botão
de envio e a cópia do prompt dentro da área visível na revisão completa.

Ciclo de revisão: 29 verificações por resolução, zero falhas, nos mesmos três
tamanhos: reprovação/motivo, correção de imagem e texto, reenvio, outra recusa,
aprovação, rede indisponível e troca de conta. Tudo com backend simulado.
`python3 tools/player_ui/check_design.py`: OK. Export Web isolado com Godot
4.7.2, sem erros de scripts/cenas/importação.

As imagens e os dados identificados por TESTE são fixtures locais. Não representam
decks publicados. As capturas do motor não comprovam teste em iPhone físico.

No Chromium, build Web real com user agent de iPhone, viewport 844×390 e DPR 3:
passaram digitação/apagar/cursor, descrição multilinha/blur, anexar, substituir,
capa, modal, instalação oculta em telas internas, clipboard real no editor e
na revisão, correção e reenvio. As chamadas externas foram bloqueadas antes da
rede. Os testes esperam o input de arquivo correspondente estar preparado antes
de iniciar o prazo do seletor; o relógio não inclui a preparação/rolagem do teste.
Não houve mudança no seletor de arquivos em produção nem acesso ao Supabase.
