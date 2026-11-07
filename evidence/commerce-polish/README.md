# Correção visual — para revisão do dono

Aplica .agents/skills/qse-design/SKILL.md, sem alterar pagamentos, Supabase,
preços, posse ou regras. Nova composição ainda não aprovada pelo dono.

Carteira separa moedas/créditos, elimina texto duplicado e apresenta quantidade,
ícone existente, preço e ação. Personagens reúne controles, libera altura ao
avatar e mantém seletores quadrados junto ao personagem. Não há aba de variações.

Capturas reais: Godot 4.7.2 Web em Chromium. UI usa fixtures identificadas apenas
nos testes. Desktop 1672×941 e UA iPhone/DPR 3 em 844×390 e 640×360; não é Safari
nem iPhone físico. A carteira teve segunda conferência após corrigir corte dos
botões; os arquivos finais substituem as capturas iniciais da carteira.

Teste Web: categorias, moedas, crédito, Samba, variação e bloqueios em três
resoluções; ver logs. Carteira final verifica os botões dentro do quadro.
Regressões nativas: cliente Stripe 16 e galeria 19 verificações, zero falhas.
Design checker e diff-check passaram. Não houve alteração do backend.
