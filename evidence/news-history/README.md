# Novidades e histórico de resgates — 08/11/2026

O dono pediu retirar somente o fundo cinza dos botões e usar a ação de outras
notícias para consultar presentes já resgatados. Os botões do hero e as ações
secundárias de Novidades agora têm preenchimento transparente, inclusive em hover,
pressionado e desabilitado. Bordas, foco de teclado, seleção dourada e ações primárias
permanecem. A regra de transparência fica em PlayerUI.

O rodapé abre Histórico de resgates. Os itens vêm exclusivamente de recibos já
retornados pela conta em qse_rewards_inventory/feed; nenhum grant ou registro é criado.
Presentes pendentes continuam em Novidades. O histórico inclui campanhas encerradas,
separa decks/skins, mostra data de resgate quando fornecida e não oferece novo resgate.
Funciona sem campanha ativa e diferencia inventário indisponível de histórico vazio.

Capturas reais do Godot Web 4.7.2 no Chromium/SwiftShader em desktop 1672×941,
844×390 e 640×360 com DPR3 e UA iPhone. É uma fixture OFFLINE de conta/recibos,
com artes reais já existentes e datas sintéticas, não uma conta real, nem aparelho
físico. Os JSONs registram ausência de erros de console.

Validação: design checker, 47 verificações de recompensas T30, 24 verificações de
resgate manual Lado Sombrio e nova fixture de histórico sem campanha, separação
de pendências, datas, erro sem posse falsa e transparência com foco preservado.
Não altera Supabase, autenticação, gameplay, música ou economia.
