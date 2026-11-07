# Moedas e cartas de criação

Decisão do dono: manter a moeda e substituir o diamante por uma carta;
uma carta representa um crédito para criar um deck.

Ícone vetorial de carta criado no repositório, sem nova imagem gerada. O slot
legado GemPill foi reaproveitado por compatibilidade de cena, agora lendo o
saldo real de deck_credits. Nenhum saldo de gems foi convertido ou apagado.
A visibilidade original do contador no lobby foi preservada; carteira/loja e
criador exibem cartas e a regra 1 carta = 1 deck. O atalho do contador e do
criador abre a categoria de cartas. Sair/trocar conta não herda o saldo.

Vendas/consumo obrigatório permanecem desligados; criação gratuita permanece.
Não houve alteração de backend, preço ou dados. Backend usa os identificadores
técnicos existentes para evitar migrações desnecessárias.

Godot 4.7.2: 14 verificações de serviço/atalho, zero falhas; smoke abre o menu e
suas rotas. Web real em Chromium: 1672×941, UA iPhone/DPR 3 em 844×390 e 640×360.
As capturas usam transporte de teste; não são aparelho físico nem sessões de
compra reais. Design checker e diff-check passaram. Sem publicação no Pages.
